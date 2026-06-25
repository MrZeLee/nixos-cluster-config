{ lib, config, ... }:
let
  routing = config.services.tailscale.useRoutingFeatures;
  isExitNode = routing == "server" || routing == "both";
in
{
  # Enable Tailscale VPN. Default role is plain "client"; set
  # `services.tailscale.useRoutingFeatures = "server"` (or "both") in a host
  # to act as an exit node (adds --advertise-exit-node, uses MagicDNS).
  services.tailscale = {
    enable = true;
    # Use a non-default interface name so the host daemon does not claim
    # `tailscale0`. That name is left free for the in-cluster headscale-router
    # pod (hostNetwork + kernel TUN), so it can schedule onto a Tailscale-host
    # node (e.g. server) without a "TUN device busy" collision.
    interfaceName = "tailscale-host";
    useRoutingFeatures = lib.mkDefault "client";
    # Never let Tailscale's MagicDNS take over the host resolv.conf. With
    # "Override Local DNS" on, Tailscale forces resolv.conf to *only*
    # 100.100.100.100, so a broken MagicDNS upstream wipes out all host DNS
    # with no public fallback. Keeping it off means networking.nameservers
    # (below) stays authoritative, with 8.8.8.8 as a working fallback.
    extraSetFlags = [ "--accept-dns=false" ] ++ lib.optionals isExitNode [ "--advertise-exit-node" ];
  };

  networking.nameservers = lib.mkBefore (
    if isExitNode then
      [ "100.100.100.100" ]
    else
      [
        "100.100.100.100"
        "8.8.8.8"
        "1.1.1.1"
      ]
  );
  networking.search = [ "tailc09c73.ts.net" ];
}
