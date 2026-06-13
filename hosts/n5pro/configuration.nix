{
  pkgs,
  name,
  ...
}:

let
  # Network interface for this host - adjust if needed
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
    ../../secrets.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = name;

  # Allow unfree packages (claude-code)
  nixpkgs.config.allowUnfree = true;

  # Pass network interface to modules
  _module.args.networkInterface = networkInterface;

  # Configure specific IP for n5pro
  networking.interfaces.${networkInterface}.ipv4.addresses = [
    {
      address = "192.168.1.109";  # Adjust this IP as needed
      prefixLength = 24;
    }
  ];

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
