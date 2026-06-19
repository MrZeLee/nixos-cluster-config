_: {
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

  # Generates /run/headscale/env from agenix secrets before headscale starts,
  # same pattern as fleet-github-secret in k3s_server_fleet.nix.
  systemd.services.headscale-env = {
    description = "Generate headscale environment file from agenix secrets";
    wantedBy = [ "headscale.service" ];
    before = [ "headscale.service" ];
    after = [ "agenix.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /run/headscale
      DOMAIN=$(cat /run/agenix/headscale-domain)
      BASE=$(echo "$DOMAIN" | cut -d. -f2-)
      printf 'HEADSCALE_SERVER_URL=https://%s\nHEADSCALE_TLS_LETSENCRYPT_HOSTNAME=%s\nHEADSCALE_DNS_BASE_DOMAIN=%s\n' \
        "$DOMAIN" "$DOMAIN" "$BASE" > /run/headscale/env
      chmod 400 /run/headscale/env
    '';
  };

  systemd.services.headscale.after = [ "headscale-env.service" ];
  systemd.services.headscale.requires = [ "headscale-env.service" ];
  systemd.services.headscale.serviceConfig.EnvironmentFile = "/run/headscale/env";

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [
    3478
    41641
  ];
}
