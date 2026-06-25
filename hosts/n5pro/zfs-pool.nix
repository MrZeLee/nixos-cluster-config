{
  lib,
  utils,
  ...
}:
{
  # tank is encrypted — do NOT auto-import at boot (blocks SSH).
  # After every reboot, manually run:
  #   sudo zpool import tank
  #   sudo zfs load-key tank
  #   sudo zfs mount -a
  #   sudo systemctl start /mnt/longhorn-hdd-ext4   # mounts + starts K3s (see below)
  #
  # One-time zvol provisioning (already done):
  #   sudo zfs create -V 20T tank/longhorn-block
  #   sudo mkfs.ext4 /dev/zvol/tank/longhorn-block

  fileSystems."/mnt/longhorn-hdd-ext4" = {
    device = "/dev/zvol/tank/longhorn-block";
    fsType = "ext4";
    options = [
      "nofail"
      "noauto"
    ];
  };

  # Bind K3s's lifecycle to the Longhorn disk so Longhorn never runs without it.
  # - RequiresMountsFor adds Requires= + After= on the mount unit: K3s won't
  #   start before the encrypted pool is unlocked + mounted, and is stopped
  #   before the disk unmounts at shutdown — closing the boot/shutdown windows
  #   where Longhorn could write replicas to a missing disk and corrupt them.
  # - wantedBy the mount unit (replacing the default multi-user.target) makes
  #   starting the mount pull K3s up, so scripts/unlock-storage.sh just runs
  #   `systemctl start /mnt/longhorn-hdd-ext4` and K3s follows automatically.
  systemd.services.k3s = {
    unitConfig.RequiresMountsFor = "/mnt/longhorn-hdd-ext4";
    wantedBy = lib.mkForce [ "${utils.escapeSystemdPath "/mnt/longhorn-hdd-ext4"}.mount" ];
  };
}
