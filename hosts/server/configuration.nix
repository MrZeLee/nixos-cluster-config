{ config, pkgs, lib, name, unstable, ... }:

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

  # Allow unfree packages for NVIDIA drivers
  nixpkgs.config.allowUnfree = true;

  # NVIDIA GPU support for headless compute
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false; # Use proprietary driver
    nvidiaSettings = false; # No GUI needed
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    nvidiaPersistenced = true;
  };

  # NVIDIA Container Toolkit for K8s/Docker workloads
  hardware.nvidia-container-toolkit = {
    enable = true;
    package = unstable.nvidia-container-toolkit;
  };

  # Load NVIDIA driver explicitly for headless
  boot.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  environment.systemPackages = [
    unstable.nvidia-container-toolkit
  ];

  services.k3s.containerdConfigTemplate = ''
    # Base K3s config
    {{ template "base" . }}

    # Add NVIDIA runtime
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes."nvidia"]
      runtime_type = "io.containerd.runc.v2"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes."nvidia".options]
      BinaryName = "${pkgs.nvidia-container-toolkit.tools}/bin/nvidia-container-runtime"
  '';

  # Pass network interface to modules
  _module.args.networkInterface = networkInterface;

  # Optional: if you want to override IP per-host
  networking.interfaces.${networkInterface}.ipv4.addresses = [{
    address = "192.168.2.107";
    prefixLength = 23;
  }];
}


