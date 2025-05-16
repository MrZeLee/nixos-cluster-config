{
  description = "Declarative NixOS Cluster Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, agenix, ... }:
    let
      # Mapping of hostnames to architectures
      hosts = {
        rasp0  = "aarch64-linux";
        raspb1 = "aarch64-linux";
        raspb2 = "aarch64-linux";
        raspb3 = "aarch64-linux";
        raspb4 = "aarch64-linux";
        raspb5 = "aarch64-linux";
        raspb6 = "aarch64-linux";
        server = "x86_64-linux";
        minipc = "x86_64-linux";
      };

      mkHost = name: system: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit nixos-hardware;
          name = name;
        };
        modules = [
          ./hosts/${name}/configuration.nix
          agenix.nixosModules.default
        ];
      };
    in {
      nixosConfigurations = builtins.mapAttrs mkHost hosts;
    };
}
