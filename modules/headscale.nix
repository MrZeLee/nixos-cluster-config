{
  lib,
  pkgs,
  ...
}:
{
  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 443;
    settings = {
      server_url = "https://placeholder";
      metrics_listen_addr = "127.0.0.1:9090";
      log.level = "info";
      logtail.enabled = false;
      tls_letsencrypt_hostname = "placeholder";
      tls_letsencrypt_cache_dir = "/var/lib/headscale/cache";
      tls_letsencrypt_challenge_type = "HTTP-01";
      tls_letsencrypt_listen = ":80";
      dns = {
        base_domain = "placeholder";
        magic_dns = true;
        nameservers.global = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
    };
  };

  # Overrides placeholder settings at runtime using agenix secrets,
  # same pattern as tokenFile = "/run/agenix/k3s-token" in k3s modules.
  systemd.services.headscale.serviceConfig = {
    ExecStartPre = lib.mkBefore [
      (pkgs.writeShellScript "headscale-env" ''
        mkdir -p /run/headscale
        DOMAIN=$(cat /run/agenix/headscale-domain)
        BASE=$(echo "$DOMAIN" | cut -d. -f2-)
        printf 'HEADSCALE_SERVER_URL=https://%s\nHEADSCALE_TLS_LETSENCRYPT_HOSTNAME=%s\nHEADSCALE_DNS_BASE_DOMAIN=%s\n' \
          "$DOMAIN" "$DOMAIN" "$BASE" > /run/headscale/env
        chmod 400 /run/headscale/env
      '')
    ];
    EnvironmentFile = "/run/headscale/env";
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [
    3478
    41641
  ];
}
