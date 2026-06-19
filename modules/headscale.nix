_: {
  services.headscale = {
    enable = true;
    address = "127.0.0.1";
    port = 8443;
    settings = {
      server_url = "https://placeholder";
      metrics_listen_addr = "127.0.0.1:9090";
      log.level = "info";
      logtail.enabled = false;
      tls_letsencrypt_hostname = "placeholder";
      tls_letsencrypt_challenge_type = "HTTP-01";
      tls_letsencrypt_listen = "127.0.0.1:8080";
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

  # Tailscale client so this machine is itself a node in its own headscale network.
  # After deploy: tailscale up --login-server https://<headscale-domain>
  services.tailscale.enable = true;

  services.nginx = {
    enable = true;
    # TCP stream: SNI routing on 443.
    # headscale.* stays local; everything else goes to K8s Traefik via headscale WireGuard.
    streamConfig = ''
      map $ssl_preread_server_name $upstream {
        ~^headscale\.  127.0.0.1:8443;
        default        192.168.1.10:443;
      }
      server {
        listen 443;
        proxy_pass $upstream;
        ssl_preread on;
      }
    '';
    # HTTP: proxy ACME challenge to headscale, redirect everything else to HTTPS.
    appendHttpConfig = ''
      server {
        listen 80 default_server;
        location /.well-known/acme-challenge/ {
          proxy_pass http://127.0.0.1:8080;
        }
        location / {
          return 301 https://$host$request_uri;
        }
      }
    '';
  };

  # Generates /run/headscale-env/env from agenix secrets before headscale starts,
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
      mkdir -p /run/headscale-env
      DOMAIN=$(cat /run/agenix/headscale-domain)
      BASE="ts.$(echo "$DOMAIN" | cut -d. -f2-)"
      printf 'HEADSCALE_SERVER_URL=https://%s\nHEADSCALE_TLS_LETSENCRYPT_HOSTNAME=%s\nHEADSCALE_DNS_BASE_DOMAIN=%s\n' \
        "$DOMAIN" "$DOMAIN" "$BASE" > /run/headscale-env/env
      chmod 400 /run/headscale-env/env
    '';
  };

  systemd.services.headscale.after = [ "headscale-env.service" ];
  systemd.services.headscale.requires = [ "headscale-env.service" ];
  systemd.services.headscale.serviceConfig.EnvironmentFile = "/run/headscale-env/env";

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [
    3478
    41641
  ];
}
