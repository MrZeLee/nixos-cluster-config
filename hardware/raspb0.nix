# Hardware configuration for Raspberry Pi 5 using nixos-raspberrypi
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  fileSystems = {
    "/boot/firmware" = {
      device = "/dev/disk/by-uuid/2175-794E";
      fsType = "vfat";
      options = [
        "noatime"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=1min"
      ];
    };
    "/" = {
      device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  # Other hardware-specific configurations can go here
  hardware.enableRedistributableFirmware = true;

  boot = {
    tmp.useTmpfs = true;
    tmp.tmpfsSize = "50%"; # Depends on the size of your storage.
    blacklistedKernelModules = [ "sun4i-drm" "drm" "drm_kms_helper" ];
    initrd.availableKernelModules = [ "xhci_pci" "uas" ];
    initrd.kernelModules = [ ];
    kernelModules = [ "br_netfilter"
                      "ip_conntrack"
                      "ip_vs"
                      "ip_vs_rr"
                      "ip_vs_wrr"
                      "ip_vs_sh"
                      "overlay"
                      "nfs"
                      "iscsi_tcp" ];
    extraModulePackages = [ ];

    # Add kernel parameters to enable cgroup v2
    kernelParams = [
      "systemd.unified_cgroup_hierarchy=1"
      "cgroup_enable=memory"
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
    ];
    kernel.sysctl = {
      "net.bridge-nf-call-ip6tables" = 1;
      "net.bridge-nf-call-iptables" = 1;
      "net.ipv4.ip_forward" = 1;
    };

  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
