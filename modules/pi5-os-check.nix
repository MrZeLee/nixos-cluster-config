{ lib, ... }:
{
  # Only affects image builds (sdImage), safe to import on Pi 5 host.
  sdImage.populateFirmwareCommands = lib.mkAfter ''
    # Ensure we can write to config.txt (it may be read-only after copy)
    if [ -e firmware/config.txt ]; then
      chmod u+w firmware/config.txt || true
    else
      touch firmware/config.txt
    fi
    if ! grep -q '^os_check=0$' firmware/config.txt 2>/dev/null; then
      printf '\nos_check=0\n' >> firmware/config.txt
    fi
  '';
}
