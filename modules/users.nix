{ ... }: {
  users.users.mrzelee = {
    isNormalUser = true;
    home = "/home/mrzelee";
    extraGroups = [ "wheel" "networkmanager" "gpio" "audio" "video" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxGPJr0yZ9d+SOYqmEBP2GPejrfbAc45Ijsvk3PWYEP mrzelee404@gmail.com"
    ];
  };

  security.sudo = {
    enable = true;
    execWheelOnly = true;
    wheelNeedsPassword = false;
  };

  # don't require password for sudo
  security.sudo.extraRules = [{
    users = [ "mrzelee" ];
    commands = [{
      command = "ALL";
      options = [ "NOPASSWD" ];
    }];
  }];

  services.sshd.enable = true;
  # And expose via SSH
  programs.ssh.startAgent = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  services.timesyncd.enable = true;
}

