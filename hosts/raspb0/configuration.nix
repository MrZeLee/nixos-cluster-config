{ config, pkgs, lib, name, nixos-raspberrypi, ... }:

let
  # Network interface for this host
  networkInterface = "eth0";
in
{
  imports = [
    ../../hardware/${name}.nix
    # ../../modules/pi5-os-check.nix
    ../../modules/base.nix
    ../../modules/builder.nix
    ../../modules/users.nix
    ../../modules/networking.nix
    ../../modules/k3s_server.nix
    ../../secrets.nix
  ] ++ (with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
  ]);

  networking.hostName = name;

  # Pass network interface to modules
  _module.args.networkInterface = networkInterface;

  # Optional: if you want to override IP per-host
  networking.interfaces.${networkInterface}.ipv4.addresses = [{
    address = "192.168.2.100";
    prefixLength = 23;
  }];

  services.k3s.clusterInit = lib.mkForce true;

  # Set temporary password for user mrzelee
  users.users.mrzelee.initialPassword = "temporary123";
}
