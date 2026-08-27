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
          # Default to no-cache only when the backend didn't set Cache-Control
          # itself. The ? prefix means "set if not already present" so that
          # apps serving immutable content-addressed media
          # (Cache-Control: public, max-age=31536000, immutable) keep their
          # long-lived browser cache instead of being clobbered to no-cache.
          ?Cache-Control "no-cache"
        }
        encode zstd gzip
        request_body {
          max_size 10GB
        }
      '';

      proxyTo = port: ''
        reverse_proxy localhost:${toString port} {
          header_up X-Real-IP {remote_host}
        }
      '';

      protectedVHost = _subdomain: port: {
        extraConfig = ''
          ${tlsConfig}
          ${commonConfig}
          @external not remote_ip 127.0.0.1/8 ${lanSubnet}
          handle @external {
            ${forwardAuth}
            ${proxyTo port}
          }
          handle {
            ${proxyTo port}
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
                  ${proxyTo proxyPort}
                }
                handle {
                  ${proxyTo authPort}
                }
              '';
            };

            "immich.${domain}" = protectedVHost "immich" config.services.immich.port;
            # Paperless keeps its own Django login behind the forward-auth gate
            # (no remote-user passthrough: the LAN-bypass path would let LAN
            # clients spoof auth headers). Layer 2 SSO = the house default.
            "paperless.${domain}" = protectedVHost "paperless" config.services.paperless.port;
            "forgejo.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                ${proxyTo config.services.forgejo.settings.server.HTTP_PORT}
              '';
            };
            "dash.${domain}" = protectedVHost "dash" config.services.homepage.port;
            # CV server — resume site + Typst PDF export + pipeline dashboard.
            # LAN bypass direct proxy; external via forward-auth. The pipeline
            # dashboard's mutating routes are additionally guarded by
            # CV_API_KEY inside the app.
            "cv.${domain}" = protectedVHost "cv" ports.cv;
            # SigNoz runs in impersonation mode (no internal auth — every request
            # is root admin). Layer 2: LAN bypass (direct proxy, no auth) + external
            # forward-auth via oauth2-proxy. The previous unconditional forward-auth
            # (no LAN bypass) caused 500 errors for ALL users when oauth2-proxy
            # hiccuped. protectedVHost fixes this: LAN requests never touch oauth2-proxy.
            "signoz.${domain}" = protectedVHost "signoz" config.services.signoz.settings.queryService.port;
            "crm.${domain}" = protectedVHost "crm" config.services.twenty.port;
            "tasks.${domain}" = protectedVHost "tasks" config.services.taskchampion-sync-server.port;
            "manifest.${domain}" = protectedVHost "manifest" config.services.manifest.port;
            # status uses NATIVE OIDC (Gatus security.oidc), not oauth2-proxy
            # forward-auth — plain reverse_proxy like Forgejo to avoid double-auth.
            "status.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                ${proxyTo config.services.gatus-config.port}
              '';
            };
            # OpenSEO: Layer 2 (oauth2-proxy forward-auth). The GSC OAuth callback
            # (/api/gsc/oauth/callback) is exempt from forward-auth — OAuth callback
            # endpoints should be directly reachable to prevent cookie-expiry edge
            # cases and SameSite policy regressions. The callback is browser-initiated
            # (the browser carries the _oauth2_proxy cookie), so forward-auth would
            # pass anyway, but exempting it makes the flow deterministic.
            "seo.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                @gsc_callback path /api/gsc/oauth/callback
                handle @gsc_callback {
                  ${proxyTo config.services.openseo.port}
                }
                @external not remote_ip 127.0.0.1/8 ${lanSubnet}
                handle @external {
                  ${forwardAuth}
                  ${proxyTo config.services.openseo.port}
                }
                handle {
                  ${proxyTo config.services.openseo.port}
                }
              '';
            };
            "daily.${domain}" = protectedVHost "daily" config.services.crush-daily.port;

            # dnsblockd has NATIVE OIDC auth since the SSO feature (Pocket ID,
            # authorization-code + PKCE) — plain TLS proxy like Forgejo/Gatus;
            # oauth2-proxy forward-auth would fight the OIDC callback flow.
            # dnsblockd's own token gate remains the inner defense layer.
            "dnsblock.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                ${proxyTo config.services.dns-blocker.statsPort}
              '';
            };
            "dnsblockd.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                redir * https://dnsblock.${domain}{uri} permanent
              '';
            };
          }
          // lib.optionalAttrs config.services.searx.enable {
            "search.${domain}" = protectedVHost "search" config.services.searx.settings.server.port;
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

                        ${proxyTo ports.monitor365-server}
                      '';
                    }
                  else
                    protectedVHost "monitor" ports.monitor365-server;
              }
          // lib.optionalAttrs config.services.discordsync.enable {
            "discordsync.${domain}" = protectedVHost "discordsync" ports.discordsync-api;
          }
          # PapDashboard — alert hub UI. Layer 2: the app itself has no UI auth
          # (only the ingest API is key-gated); Gatus posts to the localhost port
          # directly and never traverses Caddy.
          // lib.optionalAttrs config.services.papdashboard.enable {
            "alerts.${domain}" = protectedVHost "alerts" ports.papdashboard;
          }
          # bank-sync dashboard — read-only financial data with no built-in
          # auth: protectedVHost (LAN bypass + external oauth2 forward-auth)
          # is the minimum acceptable exposure for money data. Gated with the
          # `or false` trick because services.bank-sync options come from the
          # upstream flake module (imported on evo-x2 only).
          // lib.optionalAttrs (config.services.bank-sync.enable or false) {
            "banksync.${domain}" = protectedVHost "banksync" ports.bank-sync;
          }
          // lib.optionalAttrs config.services.overview.enable {
            "overview.${domain}" = protectedVHost "overview" ports.overview;
          }
          // lib.optionalAttrs config.services.file-and-image-renamer.enable {
            "renamer.${domain}" = protectedVHost "renamer" ports.file-and-image-renamer-health;
          }
          # Browser History — direct TLS proxy (NOT protectedVHost).
          # browser-history has native WebAuthn/Passkey auth AND OAuth2/OIDC via
          # Pocket ID. Forward-auth would intercept WebAuthn and OAuth2 callback
          # API calls and break registration/login.
          // lib.optionalAttrs config.services.browser-history.enable {
            "history.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                ${proxyTo ports.browser-history}
              '';
            };
          }
          # Attic binary cache — plain reverse proxy (no forward-auth).
          # Nix substituters need unauthenticated read access; push requires
          # a valid Attic token.
          // lib.optionalAttrs (config.services.attic-config.enable or false) {
            "cache.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                ${proxyTo ports.attic}
              '';
            };
          }
          # systemd-graph — LAN-bypass plain reverse_proxy (review-only tool).
          # No auth: the D-Bus-derived graph is read-only public information.
          // lib.optionalAttrs (config.services.systemd-graph.enable or false) {
            "graph.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                ${proxyTo ports.systemd-graph}
              '';
            };
          }
          # systemd-timer-monitor — static HTML/JSON served by file_server
          # (no upstream daemon, the audit timer writes files into the state dir).
          // lib.optionalAttrs (config.services.systemd-timer-monitor.enable or false) {
            "timers.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                root * /var/lib/systemd-timer-monitor
                file_server
                # The audit script always writes report.html + status.json
                # together; serve them by their canonical names so curl users
                # and the homepage link both land on the HTML report.
                @report path / /index.html /report.html /report
                handle @report {
                  rewrite * /report.html
                  file_server
                }
              '';
            };
          };
        };

        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        # oauth2-proxy is deliberately NOT ordered here: its ExecStartPre OIDC
        # gate probes https://auth.<domain>/... which is served BY Caddy.
        # Ordering Caddy after oauth2-proxy deadlocks that gate for its full
        # 120s timeout on EVERY boot, guarantees a first-start failure of
        # oauth2-proxy/gatus/browser-history (OnFailure alerts included), and
        # delays the whole web stack by 2 minutes (observed 2026-08-22 boot:
        # Caddy "Started" 2min05s in, one second after the gates gave up).
        # Cost of the removed ordering: a few seconds of 502s on external
        # forward-auth paths at boot; LAN bypass is unaffected.
        systemd.services.caddy = {
          after = [
            "pocket-id.service"
            "sops-nix.service"
          ]
          ++ lib.optional (config.services.attic-config.enable or false) "atticd.service";
          wants = [
            "pocket-id.service"
            "sops-nix.service"
          ]
          ++ lib.optional (config.services.attic-config.enable or false) "atticd.service";
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
