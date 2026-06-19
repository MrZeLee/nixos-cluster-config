{
  config,
  lib,
  ...
}:
let
  cfg = config.myCluster.headscale;
  baseDomain = lib.concatStringsSep "." (lib.tail (lib.splitString "." cfg.domain));
in
{
  options.myCluster.headscale = {
    domain = lib.mkOption {
      type = lib.types.str;
      description = "FQDN of the headscale server (e.g. headscale.example.com).";
    };
    email = lib.mkOption {
      type = lib.types.str;
      description = "Email address for ACME certificate registration.";
    };
  };

  config = {
    services.headscale = {
      enable = true;
      address = "127.0.0.1";
      port = 8080;
      settings = {
        server_url = "https://${cfg.domain}";
        metrics_listen_addr = "127.0.0.1:9090";
        log.level = "info";
        logtail.enabled = false;
        dns = {
          base_domain = baseDomain;
          magic_dns = true;
          nameservers.global = [
            "1.1.1.1"
            "8.8.8.8"
          ];
        };
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain} = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8080";
          proxyWebsockets = true;
          extraConfig = "proxy_buffering off;";
        };
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = cfg.email;
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    networking.firewall.allowedUDPPorts = [
      3478
      41641
    ];
  };
}
