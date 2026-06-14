{
  lib,
  gateway,
  networkInterface ? "eth0",
  ...
}:
{
  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.wireless.enable = false;
  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
    "2001:4860:4860::8888"
    "2001:4860:4860::8844"
  ];
  networking.firewall.enable = false;

  networking.defaultGateway = lib.mkDefault {
    address = gateway;
    interface = networkInterface;
  };

  # accept_ra=2 because K3s enables IPv6 forwarding; without it the kernel
  # would ignore Router Advertisements and skip SLAAC for the public GUA.
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.accept_ra" = 2;
    "net.ipv6.conf.default.accept_ra" = 2;
    "net.ipv6.conf.${networkInterface}.accept_ra" = 2;
    "net.ipv6.conf.${networkInterface}.autoconf" = 1;
  };

  networking.interfaces.${networkInterface}.tempAddress = "disabled";
}
