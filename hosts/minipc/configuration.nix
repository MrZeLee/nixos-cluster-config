{ config, pkgs, lib, name, ... }:

let
  # Network interface for this host
  networkInterface = "eth0";
in
{
  imports = [
    ../../hardware/${name}.nix
    ../../modules/base.nix
    ../../modules/builder.nix
    ../../modules/users.nix
    ../../modules/networking.nix
    ../../modules/k3s_agent.nix
    ../../secrets.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = name;

  # Enable graphics support for AMD integrated GPU
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      amdvlk        # Vulkan driver
      rocm-opencl-icd # OpenCL support
    ];
  };

  # Enable ROCm for AMD GPU compute workloads
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocm-runtime}"
  ];

  # AMD GPU device access for containers
  hardware.graphics.extraPackages = with pkgs; [
    rocm-opencl-icd
    rocm-runtime
  ];

  # Pass network interface to modules
  _module.args.networkInterface = networkInterface;

  # Optional: if you want to override IP per-host
  networking.interfaces.${networkInterface}.ipv4.addresses = [{
    address = "192.168.2.108";
    prefixLength = 23;
  }];
}


