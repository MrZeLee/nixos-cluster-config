{
  lib,
  pkgs,
  name,
  ...
}:

let
  # Stable onboard NIC name. n5pro overrides the cluster-wide
  # usePredictableInterfaceNames = false (see below) so this resolves to a
  # real interface; if `eno1` turns out wrong after deploy, check
  # `ip -br link` and adjust (likely `enpXsY`).
  networkInterface = "eno1";
in
{
  imports = [
    ../../hardware/${name}.nix
    ../../modules/base.nix
    ../../modules/builder.nix
    ../../modules/users.nix
    ../../modules/networking.nix
    ../../modules/k3s_agent.nix
    ../../modules/tailscale.nix
    ../../modules/zfs-storage.nix
    ./zfs-pool.nix
    ../../secrets.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = name;
  networking.hostId = "1de34942"; # Replace: run `head -c4 /dev/urandom | od -A none -t x4 | tr -d ' \n'` on n5pro

  # Allow unfree packages (claude-code)
  nixpkgs.config.allowUnfree = true;

  # Pass network interface to modules
  _module.args.networkInterface = networkInterface;

  # n5pro is x86 with onboard NIC; use stable kernel names so the static IP
  # binds reliably across reboots. Overrides modules/networking.nix.
  networking.usePredictableInterfaceNames = lib.mkForce true;

  # Configure specific IP for n5pro
  networking.interfaces.${networkInterface} = {
    ipv4.addresses = [
      {
        address = "192.168.1.109";
        prefixLength = 24;
      }
    ];
    ipv6.addresses = [
      {
        address = "fdab:cd12:ef34::109";
        prefixLength = 64;
      }
    ];
  };

  # Time zone (keeping from original configuration)
  time.timeZone = "Europe/Lisbon";

  # Locale settings (keeping from original configuration)
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_PT.UTF-8";
    LC_IDENTIFICATION = "pt_PT.UTF-8";
    LC_MEASUREMENT = "pt_PT.UTF-8";
    LC_MONETARY = "pt_PT.UTF-8";
    LC_NAME = "pt_PT.UTF-8";
    LC_NUMERIC = "pt_PT.UTF-8";
    LC_PAPER = "pt_PT.UTF-8";
    LC_TELEPHONE = "pt_PT.UTF-8";
    LC_TIME = "pt_PT.UTF-8";
  };

  # Console keymap (keeping from original configuration)
  console.keyMap = "us-acentos";

  # System packages (claude-code from original configuration)
  environment.systemPackages = with pkgs; [
    claude-code
  ];
}
