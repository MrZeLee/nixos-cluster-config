{config, lib, ...}:
{
  # Enable Tailscale VPN
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraSetFlags = ["--advertise-exit-node"];
  };

  networking.nameservers = lib.mkBefore ["100.100.100.100"];
  networking.search = ["tailc09c73.ts.net"];
}
