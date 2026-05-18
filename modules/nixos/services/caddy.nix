# Caddy reverse proxy: TLS termination, forward auth, virtual host routing
_: {
  flake.nixosModules.caddy = {
    config,
    lib,
    ...
  }: let
    inherit (config.networking) domain;
    lanSubnet = config.networking.local.subnet;
    serverCert = config.sops.secrets.dnsblockd_server_cert.path;
    serverKey = config.sops.secrets.dnsblockd_server_key.path;
    authPort = config.services.authelia-config.port;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure;

    bindAddress =
      if config.services.dns-blocker.enable && config.services.dns-blocker.blockInterface != "lo"
      then let
        addrs = config.networking.interfaces.${config.services.dns-blocker.blockInterface}.ipv4.addresses;
      in
        if addrs != []
        then (builtins.head addrs).address
        else null
      else null;

    tlsConfig = ''
      tls ${serverCert} ${serverKey}
    '';

    forwardAuth = ''
      forward_auth localhost:${toString authPort} {
        uri /api/authz/forward-auth
        copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
      }
    '';

    protectedVHost = _subdomain: port: {
      extraConfig = ''
        ${tlsConfig}
        @external not remote_ip 127.0.0.1/8 ${lanSubnet}
        handle @external {
          ${forwardAuth}
          reverse_proxy localhost:${toString port}
        }
        handle {
          reverse_proxy localhost:${toString port}
        }
      '';
    };
  in {
    config = lib.mkIf config.services.caddy.enable {
      services.caddy = {
        globalConfig = ''
          auto_https off
          ${lib.optionalString (bindAddress != null) "default_bind ${bindAddress}"}
          metrics
        '';

        virtualHosts = {
          "auth.${domain}" = {
            extraConfig = ''
              ${tlsConfig}
              reverse_proxy localhost:${toString authPort}
            '';
          };

          "immich.${domain}" = protectedVHost "immich" config.services.immich.port;
          "gitea.${domain}" = protectedVHost "forgejo" config.services.forgejo.settings.server.HTTP_PORT;
          "dash.${domain}" = protectedVHost "dash" config.services.homepage.port;
          "signoz.${domain}" = protectedVHost "signoz" config.services.signoz.settings.queryService.port;
          "crm.${domain}" = protectedVHost "crm" config.services.twenty.port;
          "tasks.${domain}" = {
            extraConfig = ''
              ${tlsConfig}
              reverse_proxy localhost:${toString config.services.taskchampion-sync-server.port}
            '';
          };
          "manifest.${domain}" = protectedVHost "manifest" config.services.manifest.port;
          "status.${domain}" = protectedVHost "status" config.services.gatus-config.port;
          "seo.${domain}" = protectedVHost "seo" config.services.openseo.port;
        };
      };

      networking.firewall.allowedTCPPorts = [80 443];

      systemd.services.caddy = {
        after = ["authelia-main.service"];
        wants = ["authelia-main.service"];
        inherit onFailure;
        unitConfig = {
          StartLimitBurst = lib.mkForce 3;
          StartLimitIntervalSec = lib.mkForce 300;
        };
        serviceConfig =
          harden {
            NoNewPrivileges = lib.mkForce false;
            CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
          }
          // serviceDefaults {}
          // {
            ReadWritePaths = lib.mkForce ["/var/lib/caddy" "/var/log/caddy"];
            OOMScoreAdjust = lib.mkForce (-500);
            AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
            WatchdogSec = "30";
          };
      };
    };
  };
}
