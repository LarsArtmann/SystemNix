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
    authPort = config.services.pocket-id-config.port;
    proxyPort = config.services.oauth2-proxy-config.port;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure ports;

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
      forward_auth localhost:${toString proxyPort} {
        uri /oauth2/auth
        copy_headers X-Auth-Request-User X-Auth-Request-Email

        @unauth status 401
        handle_response @unauth {
          redir * https://auth.${domain}/oauth2/sign_in?rd={scheme}://{host}{uri}
        }
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

        virtualHosts =
          {
            "auth.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                handle /oauth2/* {
                  reverse_proxy localhost:${toString proxyPort}
                }
                handle {
                  reverse_proxy localhost:${toString authPort}
                }
              '';
            };

            "immich.${domain}" = protectedVHost "immich" config.services.immich.port;
            "forgejo.${domain}" = protectedVHost "forgejo" config.services.forgejo.settings.server.HTTP_PORT;
            "dash.${domain}" = protectedVHost "dash" config.services.homepage.port;
            "signoz.${domain}" = protectedVHost "signoz" config.services.signoz.settings.queryService.port;
            "crm.${domain}" = protectedVHost "crm" config.services.twenty.port;
            "tasks.${domain}" = protectedVHost "tasks" config.services.taskchampion-sync-server.port;
            "manifest.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                reverse_proxy localhost:${toString config.services.manifest.port}
              '';
            };
            "status.${domain}" = protectedVHost "status" config.services.gatus-config.port;
            "seo.${domain}" = protectedVHost "seo" config.services.openseo.port;
            "daily.${domain}" = protectedVHost "daily" config.services.crush-daily.port;
          }
          // lib.optionalAttrs config.services.voice-agents.enable {
            "voice.${domain}" = protectedVHost "voice" config.services.livekit.settings.port;
            "whisper.${domain}" = protectedVHost "whisper" config.services.voice-agents.whisperPort;
          }
          // lib.optionalAttrs (config.virtualisation.oci-containers.containers ? dozzle) {
            "logs.${domain}" = protectedVHost "logs" ports.dozzle;
          }
          // lib.optionalAttrs config.services.monitor365.enable {
            "monitor.${domain}" = protectedVHost "monitor" ports.monitor365-server;
          };
      };

      networking.firewall.allowedTCPPorts = [80 443];

      systemd.services.caddy = {
        after = ["pocket-id.service" "oauth2-proxy.service"];
        wants = ["pocket-id.service" "oauth2-proxy.service"];
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
          };
      };
    };
  };
}
