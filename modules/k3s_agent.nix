{ config, lib, pkgs, ... }:
let
  nodeIp = (lib.head config.networking.interfaces.eth0.ipv4.addresses).address;
in
{
  # nixpkgs.config.permittedInsecurePackages = [
  #   "k3s-1.30.14+k3s1"
  # ];

  services.k3s = {
    enable = true;
    role = "agent";
    package = pkgs.k3s_1_33;
    tokenFile = "/run/agenix/k3s-token";
    serverAddr = "https://192.168.2.2:6443";
    clusterInit = false;
    extraFlags = "--flannel-iface=eth0 --node-ip=${nodeIp}";
    extraKubeletConfig = {
      seccompDefault = true;
    };
    gracefulNodeShutdown.enable = true;
  };

  virtualisation.containerd.enable = true;

  environment.systemPackages = with pkgs; [ kubectl nfs-utils openiscsi jq dig gperftools util-linux ];

  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost";
  };

  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
  ];

  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true;
}

