{
  description = "Declarative NixOS Cluster Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixlib.follows = "nixpkgs";
    };
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi";
      # Use the flake's own pinned nixpkgs to match its modules
      # (following our nixpkgs causes an option conflict on 25.05).
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    agenix,
    nixos-generators,
    nixos-raspberrypi,
    ...
  }@inputs:
  let
    # Mapping of hostnames to architectures
    hosts = {
      raspb0 = { system = "aarch64-linux"; format = "sd-aarch64"; };
      raspb1 = { system = "aarch64-linux"; format = "sd-aarch64-installer"; };
      raspb2 = { system = "aarch64-linux"; format = "sd-aarch64-installer"; };
      raspb3 = { system = "aarch64-linux"; format = "sd-aarch64-installer"; };
      raspb4 = { system = "aarch64-linux"; format = "sd-aarch64-installer"; };
      raspb5 = { system = "aarch64-linux"; format = "sd-aarch64-installer"; };
      raspb6 = { system = "aarch64-linux"; format = "sd-aarch64-installer"; };
      server = { system = "x86_64-linux"; format = "sd-x86_64-installer"; };
      minipc = { system = "x86_64-linux"; format = "sd-x86_64-installer"; };
    };

    mkHost = name: attrs: 
      if name == "raspb0" then
        nixos-raspberrypi.lib.nixosSystem {
          specialArgs = inputs // { inherit name; };
          modules = [
            ./hosts/${name}/configuration.nix
            agenix.nixosModules.default
          ];
        }
      else
        nixpkgs.lib.nixosSystem {
          inherit (attrs) system;
          specialArgs = {
            inherit nixos-hardware name;
          };
          modules = [
            ({config, pkgs, ...}: { nixpkgs.overlays = overlays; })
            ./hosts/${name}/configuration.nix
            agenix.nixosModules.default
          ];
        };

    overlays = [
      (final: super: {
        makeModulesClosure = x:
        super.makeModulesClosure (x // {allowMissing = true; });
      })
      (final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          inherit (prev.stdenv.hostPlatform) system;
          config.allowUnfree = true;
        };
      })
    ];

    mkImage = name: attrs: nixos-generators.nixosGenerate {
      system = attrs.system;
      format = attrs.format;
      specialArgs = {
        inherit nixos-hardware name inputs;
      };
      modules = [
        ({config, pkgs, inputs, ...}: { nixpkgs.overlays = overlays; })
        ./hosts/${name}/configuration.nix
        agenix.nixosModules.default
      ];
    };
  in {
    nixosConfigurations = builtins.mapAttrs mkHost hosts;
    packages = {
      aarch64-linux = (builtins.listToAttrs (
        map (n: {
          name  = "sd-image-${n}";
          value = mkImage n hosts.${n};
        }) (builtins.attrNames (nixpkgs.lib.filterAttrs (_: v: v.system == "aarch64-linux") hosts))
      )) // {
        # Upstream Raspberry Pi 5 installer image exposed via this flake
        # Note: nixos-raspberrypi exposes installer images at the top-level
        # `installerImages` attribute set (not under `packages`).
        raspb0-installer = nixos-raspberrypi.installerImages.rpi5;
      };
      x86_64-linux = builtins.listToAttrs (
        map (n: {
          name  = "sd-image-${n}";
          value = mkImage n hosts.${n};
        }) (builtins.attrNames (nixpkgs.lib.filterAttrs (_: v: v.system == "x86_64-linux") hosts))
      );
    };
  };
}
