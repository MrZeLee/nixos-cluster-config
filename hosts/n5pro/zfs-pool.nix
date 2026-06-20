_: {
  # tank is encrypted — do NOT auto-import at boot (blocks SSH).
  # After every reboot, manually run:
  #   sudo zpool import tank
  #   sudo zfs load-key tank
  #   sudo zfs mount -a
}
