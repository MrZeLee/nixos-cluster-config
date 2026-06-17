{
  pkgs,
  ...
}:

{
  # Enable ZFS support
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;

  # Generic ZFS maintenance services
  services.zfs = {
    # Auto-scrubbing for data integrity
    autoScrub = {
      enable = true;
      interval = "weekly";
    };

    # TRIM support for SSDs
    trim.enable = true;
  };

  # ZED (ZFS Event Daemon) configuration for notifications
  services.zfs.zed = {
    enableMail = false;
    settings = {
      ZED_NOTIFY_VERBOSE = "1";
      ZED_USE_ENCLOSURE_LEDS = "1"; # Blink disk LEDs if available
      ZED_SCRUB_AFTER_RESILVER = "1";
    };
  };

  # SMART monitoring for physical disks
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.wall.enable = true;
  };

  # ZFS utilities
  environment.systemPackages = with pkgs; [
    zfs
    zfs-prune-snapshots
    smartmontools # For disk health monitoring
  ];
}
