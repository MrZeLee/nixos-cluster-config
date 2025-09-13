{ pkgs, lib, ... }: {
  system.stateVersion = "24.05";

  zramSwap.enable = true;
  zramSwap.memoryPercent = 150;

  # Global Nix cache settings (usable outside flakes as well)
  nix.settings = {
    substituters = lib.mkAfter [
      "https://nixos-raspberrypi.cachix.org"
    ];
    trusted-public-keys = lib.mkAfter [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  environment.systemPackages = with pkgs; [
    neovim
    vim
    git
  ];
}
