# Runbook: docs/services/caddy.md
# Caddy reverse proxy: TLS termination, forward auth, virtual host routing
_: {
  flake.nixosModules.caddy =
    {
      config,
      options,
      lib,
      pkgs,
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
      # Split-horizon alias domain (brainstorming 2026-09-30): every home.lan
      # vHost is mirrored under this zone; dnsblockd resolves it on LAN + VPN,
      # it never appears in public DNS. Hosts without the networking.local
      # option set (VM tests) keep single-domain behavior.
      cloudDomain =
        if builtins.hasAttr "local" options.networking && options.networking.local ? cloudDomain then
          config.networking.local.cloudDomain
        else
          null;
      mintedCert = "/run/dnsblockd-certs/server.crt";
      mintedKey = "/run/dnsblockd-certs/server.key";
      # Dual-zone leaf minted from the dnsblockd CA at boot (dnsblockd-cert-mint
      # below) covers home.lan AND the cloud zone with one cert — same CA the
      # clients already trust, SAN superset, so home.lan behavior is unchanged.
      # Without the cloud option, hosts fall back to the static sops'd cert.
      activeCert = if cloudDomain != null then mintedCert else serverCert;
      activeKey = if cloudDomain != null then mintedKey else serverKey;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
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
        tls ${activeCert} ${activeKey} {
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

      proxyTo =
        port:
        {
          # Rewrite the upstream Host (bank-sync's DNS-rebinding guard 403s
          # any non-localhost Host on its loopback bind).
          hostOverride ? null,
        }:
        ''
          reverse_proxy localhost:${toString port} {
            header_up X-Real-IP {remote_host}
            ${lib.optionalString (hostOverride != null) "header_up Host ${hostOverride}"}
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

      protectedVHost = port: hostOverride: {
        extraConfig = ''
          ${tlsConfig}
          ${commonConfig}
          @external not remote_ip 127.0.0.1/8 ${lanSubnet}
          handle @external {
            ${forwardAuth}
            ${proxyTo port { inherit hostOverride; }}
          }
          handle {
            ${proxyTo port { inherit hostOverride; }}
          }
        '';
      };

      plainVHost = port: hostOverride: {
        extraConfig = ''
          ${tlsConfig}
          ${commonConfig}
          ${proxyTo port { inherit hostOverride; }}
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
          protectedVHost v.port v.hostOverride
        else
          plainVHost v.port v.hostOverride;

      dnsLocalSubdomains = (import ../../../platforms/common/dns-local.nix).localSubdomains;
      # Deliberate exemptions: voice/whisper are hand-written vHosts (below)
      # whose subdomains are deliberately NOT in dns-local — voice-agents is
      # not enabled on any host and supplies its own zone data.
      dnsExemptSubdomains = [
        "voice"
        "whisper"
      ];
      # vHost subdomains derived from the rendered set (single source of
      # truth — registry fan-out and hand-written entries alike; catch-alls
      # and the :80 listener excluded via the "*"/suffix filters).
      vhostSubdomains = builtins.filter (s: s != "") (
        builtins.map (k: lib.removeSuffix ".${domain}" k) (
          builtins.filter (k: lib.hasSuffix ".${domain}" k && !lib.hasInfix "*" k) (
            builtins.attrNames config.services.caddy.virtualHosts
          )
        )
      );
      # Registry subdomains (regardless of enable — a disabled service's
      # dns-local entry is pending work, not a ghost).
      registrySubdomains =
        if options ? services.integration then
          builtins.map (e: e.subdomain) (
            builtins.filter (e: e.subdomain != null) (builtins.attrValues config.services.integration)
          )
        else
          [ ];
      ghostSubdomains =
        # ghostAliases: deliberate dns-local names with no vHost of their
        # own — `alerts` is the legacy PapDashboard alias the catch-all
        # redirects to dash (DNS must keep resolving it).
        let
          ghostAliases = [ "alerts" ];
        in
        builtins.filter (
          s:
          !builtins.elem s vhostSubdomains
          && !builtins.elem s registrySubdomains
          && !builtins.elem s ghostAliases
        ) dnsLocalSubdomains;
      # Protected/plain classification for the post-deploy smoke: a vHost is
      # "protected" iff its rendered extraConfig carries forward_auth — the
      # one marker that cannot drift between the helpers and reality. The
      # third column is the vHost's first proxy target ("-" for static
      # roots) so the smoke can SKIP backends that are not running instead
      # of false-FAILing enable-gated-but-undeployed services.
      vhostLayerLines = lib.sort (a: b: a < b) (
        lib.unique (
          builtins.map
            (
              k:
              let
                vhost = config.services.caddy.virtualHosts.${k};
                layer = if lib.hasInfix "forward_auth" vhost.extraConfig then "protected" else "plain";
                proxyLine = lib.findFirst (l: lib.hasInfix "localhost:" l) null (
                  lib.splitString "\n" vhost.extraConfig
                );
                portMatch = if proxyLine == null then null else builtins.match ".*localhost:([0-9]+).*" proxyLine;
              in
              "${layer} ${lib.removeSuffix ".${domain}" k} ${
                if portMatch == null then "-" else builtins.head portMatch
              }"
            )
            (
              builtins.filter (k: lib.hasSuffix ".${domain}" k && !lib.hasInfix "*" k) (
                builtins.attrNames config.services.caddy.virtualHosts
              )
            )
        )
      );
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
        # Hand-written vHost subdomains MUST exist in the shared DNS truth —
        # a typo'd name would serve a hostname dnsblockd never resolves
        # (registry entries are already asserted by integration.nix; this
        # closes the hand-written half).
        assertions = [
          {
            assertion = lib.all (s: lib.elem s (dnsExemptSubdomains ++ dnsLocalSubdomains)) vhostSubdomains;
            message =
              "caddy: vHost subdomain(s) missing from platforms/common/dns-local.nix (name would never resolve): "
              + lib.concatStringsSep ", " (
                builtins.filter (s: !lib.elem s (dnsExemptSubdomains ++ dnsLocalSubdomains)) vhostSubdomains
              );
          }
        ];

        # Derived vHost layer map for scripts/post-deploy-check.sh: one
        # "protected <sub>" / "plain <sub>" line per home.lan vHost, computed
        # from the SAME rendered set as the actual proxy (the smoke's
        # hand-maintained list was the hand-copy-of-registry-data drift
        # class). home.lan zone only — cloud mirrors share the same backend.
        # The ghost-entry sweep rides this file's forcing: dns-local names
        # that nothing serves. Enable-gated services keep their registry
        # entry, so they never ghost; a NEW ghost = a dns-local addition with
        # no consumer vHost anywhere.
        environment.etc."caddy/vhost-layers".text =
          lib.warnIf (ghostSubdomains != [ ])
            "caddy: dns-local subdomain(s) with no vHost and no registry entry (ghost entries): ${lib.concatStringsSep ", " ghostSubdomains}"
            (lib.concatStringsSep "\n" vhostLayerLines + "\n");

        services.caddy = {
          # logFormat is wrapped by the NixOS module as `log { ${logFormat} }`
          # in globalConfig — do NOT add a separate `log {}` block there (collision)
          #
          # Logging map (verified against the rendered Caddyfile + the live log
          # dir 2026-09-30): this global block configures the DEFAULT logger —
          # caddy runtime logs plus any site WITHOUT its own log block. Every
          # vHost also gets the nixpkgs per-host default `log { output file
          # access-<host>.log }` in its site block, so each request lands in
          # exactly ONE file (no double-logging); per-host files use Caddy's
          # file-output defaults (roll 100MiB, keep 10 — bounded per file,
          # aggregate grows with vHost count). geometrikks tails BOTH surfaces
          # by design (its per-vhost path derivation matches the nixpkgs
          # default).
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
            # Bind to the LAN IP only, never 0.0.0.0 (f43a28a3: the original
            # `bind` inside servers {} was invalid Caddy syntax; default_bind
            # is the global-option form). Live-verified 2026-09-30: dnsblockd
            # serves its block page on the blockIP :80/:443, so a wildcard
            # caddy bind would collide with it. The NetBird VPN needs no extra
            # bind either: the client routes the whole LAN subnet through the
            # tunnel and traffic arrives AT the LAN IP (net-vpn brainstorm,
            # 2026-09-30).
            ${lib.optionalString (bindAddress != null) "default_bind ${bindAddress}"}
            servers {
              strict_sni_host on
            }
            metrics
          '';

          virtualHosts =
            let
              homeLanVHosts = {
                ":80" = {
                  extraConfig = ''
                    @subdomains host *.${domain}${lib.optionalString (cloudDomain != null) " *.${cloudDomain}"}
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
                      ${proxyTo proxyPort { hostOverride = null; }}
                    }
                    handle {
                      ${proxyTo authPort { hostOverride = null; }}
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
                      ${proxyTo config.services.paperless.port { hostOverride = null; }}
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
                "tasks.${domain}" = protectedVHost config.services.taskchampion-sync-server.port null;
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
                      ${proxyTo config.services.openseo.port { hostOverride = null; }}
                    }
                    @external not remote_ip 127.0.0.1/8 ${lanSubnet}
                    handle @external {
                      ${forwardAuth}
                      ${proxyTo config.services.openseo.port { hostOverride = null; }}
                    }
                    handle {
                      ${proxyTo config.services.openseo.port { hostOverride = null; }}
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
                    ${proxyTo config.services.dns-blocker.statsPort { hostOverride = null; }}
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
                "voice.${domain}" = protectedVHost config.services.livekit.settings.port null;
                "whisper.${domain}" = protectedVHost config.services.voice-agents.whisperPort null;
              }
              //
                lib.optionalAttrs
                  (
                    (config.services.monitor365.enable or false) || (config.services.monitor365-server.enable or false)
                  )
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

                            ${proxyTo ports.monitor365-server { hostOverride = null; }}
                          '';
                        }
                      else
                        protectedVHost ports.monitor365-server null;
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
            in
            homeLanVHosts
            // (lib.optionalAttrs (cloudDomain != null) (
              # Split-horizon aliases (brainstorming 2026-09-30): every
              # home.lan vHost mirrored under the cloud domain — identical
              # extraConfig (same dual-zone cert, same backends). Auth
              # redirects stay on auth.<home.lan> by design: VPN clients
              # resolve both zones, and the oauth2-proxy whitelist covers
              # the cloud domain for post-login redirects.
              (lib.mapAttrs' (
                k: v: lib.nameValuePair (lib.replaceStrings [ "${domain}" ] [ "${cloudDomain}" ] k) v
              ) (lib.filterAttrs (k: _: lib.hasInfix "${domain}" k && k != "https://*.${domain}") homeLanVHosts))
              // {
                # Cloud catch-all: unknown *.cloud names redirect to the
                # cloud dashboard (mirror of the home.lan catch-all).
                "https://*.${cloudDomain}" = {
                  extraConfig = ''
                    ${tlsConfig}
                    ${commonConfig}
                    redir * https://dash.${cloudDomain} permanent
                  '';
                };
              }
            ));
        };

        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        # Mint the dual-zone leaf cert (home.lan + cloud domain) from the
        # dnsblockd CA at every boot into /run (tmpfs — reminted fresh, 365d
        # validity). Same CA the clients already trust, SAN superset of the
        # old static cert, so home.lan TLS behavior is unchanged. Reads the
        # CA via the existing sops secrets (root-readable at activation).
        # Fail-closed: if minting fails, Caddy never starts with a stale or
        # missing cert (After+Requires below).
        systemd.services.dnsblockd-cert-mint = lib.mkIf (cloudDomain != null) {
          description = "Mint dual-zone TLS leaf from dnsblockd CA for Caddy";
          wantedBy = [ "multi-user.target" ];
          before = [ "caddy.service" ];
          after = [ "sops-nix.service" ];
          wants = [ "sops-nix.service" ];
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              RemainAfterExit = true;
              # RuntimeDirectory is what makes ReadWritePaths viable: it
              # creates /run/dnsblockd-certs BEFORE systemd sets up the
              # mount namespace. Without it the unit dies at NAMESPACE
              # setup (226/NAMESPACE, caught by tests/test-caddy-mint.nix —
              # the script's own install -d runs INSIDE the namespace and
              # is too late).
              RuntimeDirectory = "dnsblockd-certs";
              ReadWritePaths = [ "/run/dnsblockd-certs" ];
            }
          ];
          script =
            # Absolute store paths, NOT ambient PATH (defect d1, status
            # report 2026-09-30): openssl/coreutils on the system path is
            # generation-dependent luck; a missing binary fails minting and
            # the fail-closed ordering then blocks caddy — the whole web
            # stack — at boot.
            let
              opensslBin = "${pkgs.openssl.bin}/bin/openssl";
              gnugrepBin = "${pkgs.gnugrep}/bin/grep";
              installBin = "${pkgs.coreutils}/bin/install";
              mktempBin = "${pkgs.coreutils}/bin/mktemp";
              rmBin = "${pkgs.coreutils}/bin/rm";
            in
            ''
              set -euo pipefail
              ${installBin} -d -m 0750 -o caddy -g caddy /run/dnsblockd-certs
              tmp=$(${mktempBin} -d)
              trap '${rmBin} -rf "$tmp"' EXIT
              ${opensslBin} req -newkey rsa:2048 -nodes \
                -keyout "$tmp/server.key" -out "$tmp/server.csr" \
                -subj "/CN=${domain}/O=DNS Blocker"
              printf 'subjectAltName=DNS:${domain},DNS:*.${domain},DNS:${cloudDomain},DNS:*.${cloudDomain}\n' > "$tmp/san.ext"
              ${opensslBin} x509 -req -in "$tmp/server.csr" \
                -CA ${config.sops.secrets.dnsblockd_ca_cert.path} \
                -CAkey ${config.sops.secrets.dnsblockd_ca_key.path} \
                -set_serial "0x$(${opensslBin} rand -hex 16)" \
                -days 365 -sha256 -extfile "$tmp/san.ext" \
                -out "$tmp/server.crt"
              # Fail the MINT unit (OnFailure → Discord) instead of the first
              # failed TLS handshake hours later: assert the signed leaf
              # really carries all four SANs before installing it.
              sans=$(${opensslBin} x509 -in "$tmp/server.crt" -noout -ext subjectAltName)
              for name in '${domain}' '*.${domain}' '${cloudDomain}' '*.${cloudDomain}'; do
                printf '%s\n' "$sans" | ${gnugrepBin} -qF "DNS:$name" || {
                  echo "minted cert is missing SAN DNS:$name; got: $sans" >&2
                  exit 1
                }
              done
              ${installBin} -m 0444 -o caddy -g caddy "$tmp/server.crt" ${mintedCert}
              ${installBin} -m 0400 -o caddy -g caddy "$tmp/server.key" ${mintedKey}
            '';
        };

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
          # Requires (not just wants) is what makes the fail-closed claim in
          # the mint comment above literal: a dead mint unit blocks the caddy
          # start itself, instead of relying on the missing-cert parse error
          # downstream. After= still provides the ordering (Requires alone
          # does not order).
          requires = lib.optional (cloudDomain != null) "dnsblockd-cert-mint.service";
          after =
            lib.optional (cloudDomain != null) "dnsblockd-cert-mint.service"
            ++ [
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
              # CAP_NET_BIND_SERVICE is the only capability caddy needs
              # (:80/:443 TCP + :443/UDP QUIC). The old CAP_NET_ADMIN came
              # from da147df6's "Let's Encrypt DNS challenge" rationale —
              # dead since auto_https off (sops/minted certs, no DNS
              # provider, no interface manipulation). Upstream caddy's unit
              # ships NET_ADMIN too, but nothing in an offline-cert setup
              # exercises it. Proof gate: checks.caddy-mint boots caddy and
              # does real TLS handshakes on both zones without it.
              CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
            })
            (serviceDefaults { })
            {
              ReadWritePaths = lib.mkForce [
                "/var/lib/caddy"
                "/var/log/caddy"
              ];
              OOMScoreAdjust = lib.mkForce (-500);
              # Ambient caps were DESIGNED to work under NoNewPrivileges=true
              # (inheritable without any setuid/setgid exec — da147df6's
              # premise that caddy calls setuid/setgid was wrong; caddy never
              # does). Dropping the old NNP=false mkForce restores the
              # nixpkgs/harden default (true) with the ambient bind cap
              # intact.
              AmbientCapabilities = "CAP_NET_BIND_SERVICE";
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
