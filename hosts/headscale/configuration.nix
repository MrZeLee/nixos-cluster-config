{ name, ... }:
{
  imports = [
    ../../hardware/headscale.nix
    ../../modules/base.nix
    ../../modules/users.nix
    ../../modules/headscale.nix
    ../../secrets.nix
  ];

  networking.hostName = name;
}
