{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Import the "tank" pool at boot
  boot.zfs.extraPools = [ "tank" ];

  # Snapshot policy for the Longhorn datasets
  services.sanoid = {
    enable = true;

    datasets = {
      # Unencrypted Longhorn volumes (auto-mounts on boot, survives reboots)
      "tank/longhorn" = {
        use_template = [ "production" ];
        recursive = true;
      };
      # Encrypted Longhorn volumes (stays locked on boot until unlocked manually).
      # Snapshots still work while locked; they capture the raw encrypted blocks.
      "tank/longhorn-secure" = {
        use_template = [ "production" ];
        recursive = true;
      };
    };

    templates = {
      production = {
        frequently = 4;
        hourly = 24;
        daily = 7;
        weekly = 4;
        monthly = 12;
        yearly = 2;
        autosnap = true;
        autoprune = true;
      };

      media = {
        frequently = 0;
        hourly = 0;
        daily = 7;
        weekly = 4;
        monthly = 6;
        yearly = 1;
        autosnap = true;
        autoprune = true;
      };
    };
  };

  # System activation script to create datasets with proper settings
  # This runs on every nixos-rebuild but is idempotent
  system.activationScripts.zfsSetup = lib.stringAfter [ "specialfs" ] ''
    # Check if tank pool exists
    if ${pkgs.zfs}/bin/zpool list tank >/dev/null 2>&1; then
      echo "Configuring ZFS datasets..."

      # Create main Longhorn dataset with optimized settings for mixed workloads
      # 16K recordsize is a good balance for databases, media, and general storage
      ${pkgs.zfs}/bin/zfs list tank/longhorn >/dev/null 2>&1 || \
        ${pkgs.zfs}/bin/zfs create -o recordsize=16K \
                    -o logbias=latency \
                    -o redundant_metadata=most \
                    -o mountpoint=/mnt/longhorn \
                    tank/longhorn

      # Create subdatasets for different workload types (optional organization)
      # Longhorn will manage the actual volumes, these are just for organization
      ${pkgs.zfs}/bin/zfs list tank/longhorn/databases >/dev/null 2>&1 || \
        ${pkgs.zfs}/bin/zfs create -o recordsize=8K \
                    -o primarycache=metadata \
                    tank/longhorn/databases

      ${pkgs.zfs}/bin/zfs list tank/longhorn/media >/dev/null 2>&1 || \
        ${pkgs.zfs}/bin/zfs create -o recordsize=1M \
                    -o logbias=throughput \
                    tank/longhorn/media

      ${pkgs.zfs}/bin/zfs list tank/longhorn/general >/dev/null 2>&1 || \
        ${pkgs.zfs}/bin/zfs create -o recordsize=128K \
                    tank/longhorn/general

      chmod 755 /mnt/longhorn 2>/dev/null || true
    else
      echo "ZFS pool 'tank' not found. Skipping dataset configuration."
    fi
  '';

  # Encrypted Longhorn dataset (passphrase) — created MANUALLY, ONCE.
  # It is NOT created by the activation script above because keylocation=prompt
  # needs the passphrase typed interactively, which an activation script cannot do.
  #
  #   sudo zfs create \
  #     -o encryption=aes-256-gcm \
  #     -o keyformat=passphrase \
  #     -o keylocation=prompt \
  #     -o recordsize=16K \
  #     -o logbias=latency \
  #     -o mountpoint=/mnt/longhorn-secure \
  #     tank/longhorn-secure
  #   sudo chmod 755 /mnt/longhorn-secure
  #
  # On every reboot this dataset stays LOCKED and unmounted (the unencrypted
  # tank/longhorn auto-mounts and keeps serving its PVCs). To bring the encrypted
  # volumes online, SSH in and run:
  #
  #   sudo zfs load-key tank/longhorn-secure   # prompts for the passphrase
  #   sudo zfs mount tank/longhorn-secure
  #
  # While locked, /mnt/longhorn-secure has no longhorn-disk.cfg, so Longhorn marks
  # that disk NotReady and will not write to it — safe. After unlock+mount Longhorn
  # re-detects the disk (~1 min) and the encrypted PVCs come back.

  # ZFS health monitoring script
  environment.etc."zfs-health-check.sh" = {
    text = ''
      #!/bin/sh

      # Load Telegram credentials from secrets
      BOT_TOKEN=$(cat ${config.age.secrets.telegram-bot-token.path} 2>/dev/null)
      CHAT_ID=$(cat ${config.age.secrets.telegram-chat-id.path} 2>/dev/null)

      # Function to send Telegram message
      send_telegram() {
        local message="$1"
        local priority="$2"

        if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
          echo "Telegram not configured. Please set up telegram-bot-token and telegram-chat-id secrets"
          return
        fi

        # Add emoji based on priority
        case "$priority" in
          critical) icon="🚨" ;;
          warning)  icon="⚠️" ;;
          info)     icon="ℹ️" ;;
          *)        icon="📊" ;;
        esac

        # Send message via Telegram Bot API
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
          -d "chat_id=$CHAT_ID" \
          -d "parse_mode=HTML" \
          -d "text=$icon <b>ZFS Alert - n5pro</b>%0A%0A$message" \
          > /dev/null 2>&1
      }

      # Check pool health
      POOL_STATUS=$(zpool status -x tank 2>/dev/null)

      if [ "$?" -ne 0 ]; then
        exit 0  # Pool doesn't exist yet
      fi

      if [ "$POOL_STATUS" != "pool 'tank' is healthy" ]; then
        echo "WARNING: ZFS pool issue detected!"
        echo "$POOL_STATUS"

        # Log to systemd journal
        echo "$POOL_STATUS" | logger -t zfs-health -p warning

        # Send Telegram notification
        send_telegram "Pool issue detected:%0A%0A$(echo "$POOL_STATUS" | sed 's/ /%20/g' | tr '\n' '%' | sed 's/%/%0A/g')" "warning"
      fi

      # Check for disk errors
      if zpool status tank | grep -E "(DEGRADED|FAULTED|OFFLINE|UNAVAIL|REMOVED)"; then
        echo "CRITICAL: Disk failure detected in ZFS pool!"
        logger -t zfs-health -p crit "Disk failure detected in ZFS pool tank"

        # Get detailed status for Telegram
        DETAILED_STATUS=$(zpool status tank | head -20)

        # Send critical Telegram notification
        send_telegram "DISK FAILURE DETECTED!%0A%0A$(echo "$DETAILED_STATUS" | sed 's/ /%20/g' | tr '\n' '%' | sed 's/%/%0A/g')" "critical"
      fi

      # Check SMART status for predictive failures
      for disk in sda sdb sdc sdd sde; do
        if smartctl -H /dev/$disk 2>/dev/null | grep -q "FAILED"; then
          send_telegram "SMART failure predicted on /dev/$disk - Replace soon!" "warning"
          logger -t zfs-health -p warning "SMART failure predicted on /dev/$disk"
        fi
      done
    '';
    mode = "0755";
  };

  # Systemd timer for regular health checks
  systemd.services.zfs-health-check = {
    description = "Check ZFS pool health";
    after = [ "zfs-import-tank.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/etc/zfs-health-check.sh";
    };
  };

  systemd.timers.zfs-health-check = {
    description = "Regular ZFS health check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "10min"; # Check every 10 minutes
    };
  };

  # One-time pool creation command
  # Run this ONLY ONCE to create the initial pool.
  #
  # Use stable /dev/disk/by-id/ paths (NOT /dev/sdX, which can change across
  # reboots). List your drives first to find their by-id names:
  #   ls -l /dev/disk/by-id/ | grep -v part
  #
  # Then create the pool (replace DISK1..DISK5 with the by-id names):
  #   sudo zpool create -f -o ashift=12 -o autoexpand=on -o autoreplace=on \
  #     -O compression=lz4 -O atime=off -O xattr=sa -O normalization=formD \
  #     tank \
  #     mirror /dev/disk/by-id/DISK1 /dev/disk/by-id/DISK2 \
  #     mirror /dev/disk/by-id/DISK3 /dev/disk/by-id/DISK4 \
  #     spare  /dev/disk/by-id/DISK5

  # After pool creation, run nixos-rebuild to create and configure datasets:
  # sudo nixos-rebuild switch
}
