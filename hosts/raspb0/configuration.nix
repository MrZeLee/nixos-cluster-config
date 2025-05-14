{ config, pkgs, lib, name, ... }:

{
  imports = [
    ../../hardware/${name}.nix
    ../../modules/base.nix
    ../../modules/builder.nix
    ../../modules/users.nix
    ../../modules/networking.nix
    ../../modules/k3s.nix
    ../../secrets.nix
  ];

  networking.hostName = name;

  # Optional: if you want to override IP per-host
  networking.interfaces.eth0.ipv4.addresses = [{
    address = "192.168.2.100";
    prefixLength = 23;
  }];
}

