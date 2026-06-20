_: {
  # tank is encrypted — do NOT auto-import at boot (blocks SSH).
  # After every reboot, manually run:
  #   sudo zpool import tank
  #   sudo zfs load-key tank
  #   sudo zfs mount -a
  #   sudo mount /mnt/longhorn-hdd-ext4
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
}
