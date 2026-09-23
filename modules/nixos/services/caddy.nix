# Caddy reverse proxy: TLS termination, forward auth, virtual host routing
_: {
  flake.nixosModules.caddy =
    {
      config,
      options,
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
      registryVHosts = config.services.caddy-config.extraVHosts;
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

      staticVHost = root: {
        extraConfig = ''
          ${tlsConfig}
          ${commonConfig}
          root * ${root}
          file_server
        '';
      };

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

      plainVHost = port: {
        extraConfig = ''
          ${tlsConfig}
          ${commonConfig}
          ${proxyTo port}
        '';
      };

      renderVHost =
        v:
        # Static-root entries (registry vHost.root): serve a directory tree
        # via file_server instead of proxying. Layer semantics still apply —
        # "protected" wraps the file_server in the external forward-auth /
        # LAN-bypass split, "plain" serves TLS-only (timers vHost precedent).
        if v.root != null then
          (
            if v.layer == "protected" then
              {
                extraConfig = ''
                  ${tlsConfig}
                  ${commonConfig}
                  @external not remote_ip 127.0.0.1/8 ${lanSubnet}
                  handle @external {
                    ${forwardAuth}
                    root * ${v.root}
                    file_server
                  }
                  handle {
                    root * ${v.root}
                    file_server
                  }
                '';
              }
            else
              staticVHost v.root
          )
        else if v.layer == "protected" then
          protectedVHost null v.port
        else
          plainVHost v.port;
    in
    {
      options.services.caddy-config = {
        # Extension seam for services.integration registry fan-out: entries
        # render through the SAME tlsConfig/commonConfig/forwardAuth helpers
        # as the hand-written vHosts below — no second source of truth for
        # the Caddyfile building blocks.
        extraVHosts = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                port = lib.mkOption {
                  type = lib.types.nullOr lib.types.port;
                  default = null;
                  description = ''
                    Backend port to proxy to (from lib/ports.nix). Null for
                    static-root entries (set `root` instead) — at least one of
                    port/root must be set for a non-"none" layer.
                  '';
                };
                root = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Static file root served via file_server instead of a
                    reverse_proxy (Layer 2 still applies: external clients hit
                    forward-auth, LAN bypasses). Use for prebuilt static sites
                    whose content is converged by a sync unit (architecture-
                    catalog precedent). The path must be readable by the caddy
                    user at request time.
                  '';
                };
                layer = lib.mkOption {
                  type = lib.types.enum [
                    "plain"
                    "protected"
                  ];
                  default = "protected";
                  description = ''
                    "protected" = Layer 2 (oauth2-proxy forward-auth for external, LAN bypass) —
                    for apps without their own auth. "plain" = Layer 0/1 direct
                    reverse_proxy — for LAN-only UIs and apps with native OIDC
                    (forward-auth would double-auth them).
                  '';
                };
              };
            }
          );
          default = { };
          description = "Registry-managed vHosts, keyed by subdomain (rendered as <subdomain>.<domain>)";
        };
      };

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

            # Immich vHost moved to the registry (services.integration.immich,
            # Layer 2 protected). Paperless: native OIDC via Pocket ID
            # (django-allauth) — Layer 1, plain reverse_proxy like
            # Forgejo/Gatus. protectedVHost would double-auth (forward-auth
            # + the app's own login). SSO-ONLY: password login is disabled
            # via the paperless-oidc-setup env file (auto-break-glass
            # restores it if the bridge degrades). /admin/* stays
            # hard-blocked: PAPERLESS_DISABLE_REGULAR_LOGIN does NOT cover
            # the Django admin login (documented), and nobody uses it here —
            # paperless-manage covers admin operations. The exact-match
            # handle /admin (2026-09-02) kills the bare /admin → /admin/ 301
            # hop that used to leak through to the app.
            "paperless.${domain}" = {
              extraConfig = ''
                ${tlsConfig}
                ${commonConfig}
                handle /admin/* {
                  respond 403
                }
                handle /admin {
                  respond 403
                }
                handle {
                  ${proxyTo config.services.paperless.port}
                }
              '';
            };
            # Forgejo / crm / tasks / manifest / status vHosts:
            # forgejo+crm+manifest+status moved to the registry
            # (services.integration.<name>, plain/protected per entry). dash
            # joined them (services.integration.papdashboard, subdomain =
            # "dash" — the dashboard itself). tasks stays hand-written
            # (taskchampion has no registry entry).
            # The old alerts.<domain> PapDashboard alias is covered by the
            # catch-all below (unknown *.home.lan → redirect to dash).
            "tasks.${domain}" = protectedVHost "tasks" config.services.taskchampion-sync-server.port;
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
            # daily vHost moved to the registry (services.integration.crush-daily,
            # Layer 2 protected).

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
          // lib.optionalAttrs config.services.voice-agents.enable {
            # voice/whisper vHosts stay hand-written: those subdomains are
            # not in the shared dns-local list (voice-agents is not enabled
            # on any current host), so registry entries for them would fail
            # the DNS-consistency assertion.
            "voice.${domain}" = protectedVHost "voice" config.services.livekit.settings.port;
            "whisper.${domain}" = protectedVHost "whisper" config.services.voice-agents.whisperPort;
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
          # DiscordSync / Browser History / Attic / renamer / search / graph /
          # overview vHosts moved to the registry (services.integration
          # entries in their owning modules). systemd-timer-monitor stays
          # hand-written below: it is a file_server over the state dir, not
          # a proxy.
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
          }
          # Registry fan-out (services.integration.<name>.vHost) — rendered
          # through the same helpers as every hand-written vHost above.
          // (lib.mapAttrs' (sub: v: lib.nameValuePair "${sub}.${domain}" (renderVHost v)) registryVHosts);
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

        # Service-integration registry entry: unit-state monitoring for the
        # proxy itself (no tile/vHost/checks — Caddy OWNS those surfaces;
        # a self-referential vHost would be circular).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          caddy = {
            enable = config.services.caddy.enable;
            vHost.layer = "none";
            monitored = true;
          };
        };
      };
    };
}
