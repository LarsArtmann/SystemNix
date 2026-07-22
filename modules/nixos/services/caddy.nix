# Caddy reverse proxy: TLS termination, forward auth, virtual host routing
_: {
  flake.nixosModules.caddy =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (config.networking) domain;
      lanSubnet = config.networking.local.subnet;
      serverCert = config.sops.secrets.dnsblockd_server_cert.path;
      serverKey = config.sops.secrets.dnsblockd_server_key.path;
      authPort = config.services.pocket-id-config.port;
      proxyPort = config.services.oauth2-proxy-config.port;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailure
        ports
        ;

      bindAddress =
        if config.services.dns-blocker.enable && config.services.dns-blocker.blockInterface != "lo" then
          let
            addrs = config.networking.interfaces.${config.services.dns-blocker.blockInterface}.ipv4.addresses;
          in
          if addrs != [ ] then (builtins.head addrs).address else null
        else
          null;

      tlsConfig = ''
        tls ${serverCert} ${serverKey} {
          protocols tls1.2 tls1.3
        }
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

      commonConfig = ''
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          Referrer-Policy "strict-origin-when-cross-origin"
          Permissions-Policy "geolocation=(), microphone=(), camera=()"
          -Server
          # Always revalidate HTML documents to prevent stale cached pages
          # referencing chunk hashes from a previous deploy
          Cache-Control "no-cache"
        }
        encode zstd gzip
        request_body {
          max_size 10GB
        }
      '';

      protectedVHost = _subdomain: port: {
        extraConfig = ''
          ${tlsConfig}
          ${commonConfig}
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
    in
    {
      config = lib.mkIf config.services.caddy.enable {
        services.caddy = {
          # logFormat is wrapped by the NixOS module as `log { ${logFormat} }`
          # in globalConfig — do NOT add a separate `log {}` block there (collision)
          logFormat = ''
            output file /var/log/caddy/access.log {
              roll_size 100MB
              roll_keep 3
              roll_keep_for 168h
            }
            format json
          '';
          globalConfig = ''
            auto_https off
            ${lib.optionalString (bindAddress != null) "default_bind ${bindAddress}"}
            servers {
              strict_sni_host on
            }
            metrics
          '';

          virtualHosts = {
            ":80" = {
              extraConfig = ''
                @subdomains host *.${domain}
                redir @subdomains https://{host}{uri} permanent
                redir https://dash.${domain} permanent
              '';
            };
            # Catch-all HTTPS for unknown *.home.lan — redirect to dashboard
            # so typos/unknown subdomains never fall through to browser search
            "https://*.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                redir * https://dash.${domain} permanent
              '';
            };

            "auth.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                handle /oauth2/* {
                  reverse_proxy localhost:${toString proxyPort}
                }
                handle {
                  reverse_proxy localhost:${toString authPort}
                }
              '';
            };

            "immich.${domain}" = protectedVHost "immich" config.services.immich.port;
            "forgejo.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                reverse_proxy localhost:${toString config.services.forgejo.settings.server.HTTP_PORT}
              '';
            };
            "dash.${domain}" = protectedVHost "dash" config.services.homepage.port;
            # SigNoz runs in impersonation mode (no internal auth) — ALL requests
            # must pass through Pocket ID via oauth2-proxy. No LAN bypass.
            "signoz.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                ${forwardAuth}
                reverse_proxy localhost:${toString config.services.signoz.settings.queryService.port}
              '';
            };
            "crm.${domain}" = protectedVHost "crm" config.services.twenty.port;
            "tasks.${domain}" = protectedVHost "tasks" config.services.taskchampion-sync-server.port;
            "manifest.${domain}" = protectedVHost "manifest" config.services.manifest.port;
            # status uses NATIVE OIDC (Gatus security.oidc), not oauth2-proxy
            # forward-auth — plain reverse_proxy like Forgejo to avoid double-auth.
            "status.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                reverse_proxy localhost:${toString config.services.gatus-config.port}
              '';
            };
            "seo.${domain}" = protectedVHost "seo" config.services.openseo.port;
            "daily.${domain}" = protectedVHost "daily" config.services.crush-daily.port;

            "dnsblockd.${domain}" = protectedVHost "dnsblockd" config.services.dns-blocker.statsPort;
            "dnsblock.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                redir * https://dnsblockd.${domain}{uri} permanent
              '';
            };
          }
          // lib.optionalAttrs config.services.voice-agents.enable {
            "voice.${domain}" = protectedVHost "voice" config.services.livekit.settings.port;
            "whisper.${domain}" = protectedVHost "whisper" config.services.voice-agents.whisperPort;
          }
          // lib.optionalAttrs (config.virtualisation.oci-containers.containers ? dozzle) {
            "logs.${domain}" = protectedVHost "logs" ports.dozzle;
          }
          //
            lib.optionalAttrs
              (config.services.monitor365.enable || config.services.monitor365-server.enable or false)
              {
                # When SSO is enabled, Monitor365 uses native OIDC via Pocket ID.
                # Plain reverse_proxy (like Forgejo/Gatus) avoids oauth2-proxy
                # forward-auth interfering with the SSO callback flow.
                "monitor.${domain}" =
                  if (config.services.monitor365-server.sso.enable or false) then
                    {
                      extraConfig = ''
                        ${tlsConfig}
                        ${commonConfig}

                        # Prevent browser from caching entry-point files that reference
                        # content-hashed assets. Without this, a stale cached
                        # bootstrap.js references old hashes → SPA fallback returns
                        # index.html (text/html) for missing .js files → MIME error.
                        @noCache path /ui /ui/ /ui/index.html /ui/bootstrap.js
                        header @noCache Cache-Control "no-cache, no-store, must-revalidate"

                        reverse_proxy localhost:${toString ports.monitor365-server}
                      '';
                    }
                  else
                    protectedVHost "monitor" ports.monitor365-server;
              }
          // lib.optionalAttrs config.services.discordsync.enable {
            "discordsync.${domain}" = protectedVHost "discordsync" ports.discordsync-api;
          }
          // lib.optionalAttrs config.services.overview.enable {
            "overview.${domain}" = protectedVHost "overview" ports.overview;
          }
          // lib.optionalAttrs config.services.file-and-image-renamer.enable {
            "renamer.${domain}" = protectedVHost "renamer" ports.file-and-image-renamer-health;
          };
        };

        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        systemd.services.caddy = {
          after = [
            "pocket-id.service"
            "oauth2-proxy.service"
            "sops-nix.service"
          ];
          wants = [
            "pocket-id.service"
            "oauth2-proxy.service"
            "sops-nix.service"
          ];
          inherit onFailure;
          unitConfig = {
            StartLimitBurst = lib.mkForce 3;
            StartLimitIntervalSec = lib.mkForce 300;
          };
          serviceConfig = lib.mkMerge [
            (harden {
              NoNewPrivileges = lib.mkForce false;
              CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
            })
            (serviceDefaults { })
            {
              ReadWritePaths = lib.mkForce [
                "/var/lib/caddy"
                "/var/log/caddy"
              ];
              OOMScoreAdjust = lib.mkForce (-500);
              AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
            }
          ];
        };
      };
    };
}
