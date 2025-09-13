{ config, pkgs, lib, name, nixos-raspberrypi, ... }:

{
  imports = [
    ../../hardware/${name}.nix
    ../../modules/pi5-os-check.nix
    ../../modules/base.nix
    ../../modules/builder.nix
    ../../modules/users.nix
    ../../modules/networking.nix
    ../../modules/k3s_server.nix
    ../../secrets.nix
  ] ++ (with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.bluetooth
  ]);

  networking.hostName = name;

  # Optional: if you want to override IP per-host
  networking.interfaces.eth0.ipv4.addresses = [{
    address = "192.168.2.100";
    prefixLength = 23;
  }];

  services.k3s.clusterInit = lib.mkForce true;
}
