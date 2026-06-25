{ pkgs, lib, ... }:
{
  imports = [ ./telegram-notify.nix ];

  system.stateVersion = "24.05";

  # K3s nodes run many containers that each consume inotify instances/watches.
  # The kernel defaults (128 instances) are easily exhausted, which crashes
  # apps that use file watchers (e.g. Jellyfin's .NET FileSystemWatcher).
  boot.kernel.sysctl = {
    "fs.inotify.max_user_instances" = 8192;
    "fs.inotify.max_user_watches" = 1048576;
  };

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
    fastfetch
    tmux
  ];
}
