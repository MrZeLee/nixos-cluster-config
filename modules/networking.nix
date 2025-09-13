{ config, lib, pkgs, networkInterface ? "eth0", ... }: {
  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.wireless.enable = false;
  networking.nameservers = [ "8.8.8.8" "8.8.4.4" ];
  networking.firewall.enable = false;

  # Default gateway can be overridden per-host
  networking.defaultGateway = lib.mkDefault {
    address = "192.168.2.1";
    interface = networkInterface;
  };
}

