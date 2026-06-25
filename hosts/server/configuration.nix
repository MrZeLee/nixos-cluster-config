{
  config,
  lib,
  pkgs,
  utils,
  name,
  ...
}:

let
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
    ../../modules/tailscale.nix
    ../../secrets.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ASUS G20CB firmware hangs on warm reboot and won't re-POST (board has
  # required a manual power-cycle). Force a PCI reset path on reboot.
  boot.kernelParams = [ "reboot=pci" ];

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
    package = pkgs.unstable.nvidia-container-toolkit;
  };

  # Load NVIDIA driver explicitly for headless
  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];

  environment.systemPackages = with pkgs; [
    unstable.nvidia-container-toolkit
    unstable.libnvidia-container
    cryptsetup # manual unlock of the encrypted RAID0 Longhorn disk
  ];

  environment.etc."nvidia-container-runtime/config.toml".text = ''
    disable-require = true
    supported-driver-capabilities = "compat32,compute,display,graphics,ngx,utility,video"

    [nvidia-container-cli]
    environment = []
    ldconfig = "@${pkgs.glibc.bin}/bin/ldconfig"
    load-kmods = true
    no-cgroups = false
    path = "${pkgs.unstable.libnvidia-container}/bin/nvidia-container-cli"

    [nvidia-container-runtime]
    mode = "legacy"
    runtimes = ["runc"]

    [nvidia-container-runtime-hook]
    path = "${pkgs.unstable.nvidia-container-toolkit.tools}/bin/nvidia-container-runtime-hook"
    skip-mode-detection = false

    [nvidia-ctk]
    path = "${pkgs.unstable.nvidia-container-toolkit}/bin/nvidia-ctk"
  '';

  services.k3s.containerdConfigTemplate = ''
    # Base K3s config
    {{ template "base" . }}

    # Add NVIDIA runtime
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes."nvidia"]
      runtime_type = "io.containerd.runc.v2"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes."nvidia".options]
      BinaryName = "${pkgs.unstable.nvidia-container-toolkit.tools}/bin/nvidia-container-runtime.legacy"
  '';

  # Pass network interface to modules
  _module.args.networkInterface = networkInterface;

  # Bind K3s's lifecycle to the encrypted RAID0 Longhorn disk so Longhorn never
  # runs without it (mount defined in hardware/server.nix).
  # - RequiresMountsFor adds Requires= + After= on the mount unit: K3s won't
  #   start before the disk is unlocked + mounted, and is stopped before it
  #   unmounts at shutdown — closing the boot/shutdown windows where Longhorn
  #   could write replicas to a missing disk and corrupt them.
  # - wantedBy the mount unit (replacing the default multi-user.target) makes
  #   starting the mount pull K3s up, so scripts/unlock-storage.sh just runs
  #   `systemctl start /mnt/longhorn-server-raid0` and K3s follows automatically.
  systemd.services.k3s = {
    unitConfig.RequiresMountsFor = "/mnt/longhorn-server-raid0";
    wantedBy = lib.mkForce [ "${utils.escapeSystemdPath "/mnt/longhorn-server-raid0"}.mount" ];
  };

  # Act as Tailscale exit node for the cluster
  services.tailscale.useRoutingFeatures = "server";

  # Optional: if you want to override IP per-host
  networking.interfaces.${networkInterface} = {
    ipv4.addresses = [
      {
        address = "192.168.1.107";
        prefixLength = 24;
      }
    ];
    ipv6.addresses = [
      {
        address = "fdab:cd12:ef34::107";
        prefixLength = 64;
      }
    ];
  };
}
