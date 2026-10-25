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

      # Branded 404 page served by the catch-all vHosts below for unknown
      # *.home.lan / *.cloud hosts. Store-served (immutable, world-readable),
      # fully self-contained: inline CSS plus one inline script that echoes
      # the requested host, no external assets (LAN-offline safe). Hexes are
      # Catppuccin Mocha (theme.nix base/text/subtext0/surface0/lavender/
      # mauve), hardcoded so the server config does not depend on the
      # desktop theme file.
      notFoundRoot = pkgs.linkFarm "caddy-notfound-root" [
        {
          name = "index.html";
          path = pkgs.writeText "caddy-notfound-index.html" ''
            <!doctype html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>404 - Nothing here</title>
            <style>
            :root { color-scheme: dark; }
            * { margin: 0; box-sizing: border-box; }
            body {
              min-height: 100vh;
              display: grid;
              place-items: center;
              background: #1e1e2e;
              color: #cdd6f4;
              font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
              padding: 2rem;
            }
            main { text-align: center; max-width: 34rem; }
            .code {
              font-size: clamp(5rem, 18vw, 9rem);
              font-weight: 800;
              letter-spacing: 0.05em;
              color: #b4befe;
              line-height: 1;
            }
            h1 { font-size: 1.4rem; font-weight: 600; margin: 1.25rem 0 0.5rem; }
            p { color: #a6adc8; line-height: 1.65; }
            code {
              background: #313244;
              border-radius: 0.4rem;
              padding: 0.15rem 0.5rem;
              font-family: ui-monospace, "JetBrains Mono", monospace;
              font-size: 0.95em;
              word-break: break-all;
            }
            a {
              display: inline-block;
              margin-top: 2rem;
              padding: 0.7rem 1.5rem;
              border-radius: 0.6rem;
              background: #b4befe;
              color: #1e1e2e;
              font-weight: 600;
              text-decoration: none;
            }
            a:hover { background: #cba6f7; }
            footer { margin-top: 2.5rem; font-size: 0.85rem; color: #6c7086; }
            </style>
            </head>
            <body>
            <main>
            <div class="code">404</div>
            <h1>No service at this address</h1>
            <p>Nothing runs at <code id="host">this hostname</code>.</p>
            <p>Check the address for a typo, or head back to the dashboard.</p>
            <a href="https://dash.${domain}">Go to the dashboard</a>
            <footer>${domain} private network</footer>
            </main>
            <script>document.getElementById("host").textContent = window.location.host;</script>
            </body>
            </html>
          '';
        }
      ];

      # Branded server-error pages (502/503/504) — sibling of notFoundRoot,
      # served by the helpers' handle_errors routes (deep dive finding 2,
      # 2026-10-25: a dead backend used to surface as caddy's plain-text
      # error page, or the catch-alls' 404 page). One file per status so
      # the served page always names the real code; {err.status_code} in
      # the route below picks the file. Same Catppuccin Mocha hexes as
      # notFoundRoot; store-served, self-contained, LAN-offline safe.
      serverErrorRoot =
        let
          errPage = code: title: explanation: ''
            <!doctype html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>${code} - ${title}</title>
            <style>
            :root { color-scheme: dark; }
            * { margin: 0; box-sizing: border-box; }
            body {
              min-height: 100vh;
              display: grid;
              place-items: center;
              background: #1e1e2e;
              color: #cdd6f4;
              font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
              padding: 2rem;
            }
            main { text-align: center; max-width: 34rem; }
            .code {
              font-size: clamp(5rem, 18vw, 9rem);
              font-weight: 800;
              letter-spacing: 0.05em;
              color: #f38ba8;
              line-height: 1;
            }
            h1 { font-size: 1.4rem; font-weight: 600; margin: 1.25rem 0 0.5rem; }
            p { color: #a6adc8; line-height: 1.65; }
            code {
              background: #313244;
              border-radius: 0.4rem;
              padding: 0.15rem 0.5rem;
              font-family: ui-monospace, "JetBrains Mono", monospace;
              font-size: 0.95em;
              word-break: break-all;
            }
            a {
              display: inline-block;
              margin-top: 2rem;
              padding: 0.7rem 1.5rem;
              border-radius: 0.6rem;
              background: #b4befe;
              color: #1e1e2e;
              font-weight: 600;
              text-decoration: none;
            }
            a:hover { background: #cba6f7; }
            footer { margin-top: 2.5rem; font-size: 0.85rem; color: #6c7086; }
            </style>
            </head>
            <body>
            <main>
            <div class="code">${code}</div>
            <h1>${title}</h1>
            <p>${explanation} <code id="host">this hostname</code>.</p>
            <p>The service may be restarting or down. Try again shortly.</p>
            <a href="https://dash.${domain}">Go to the dashboard</a>
            <footer>${domain} private network</footer>
            </main>
            <script>document.getElementById("host").textContent = window.location.host;</script>
            </body>
            </html>
          '';
        in
        pkgs.linkFarm "caddy-servererror-root" [
          {
            name = "502.html";
            path = pkgs.writeText "caddy-502.html" (
              errPage "502" "Service not responding" "The service behind"
            );
          }
          {
            name = "503.html";
            path = pkgs.writeText "caddy-503.html" (errPage "503" "Service unavailable" "The service behind");
          }
          {
            name = "504.html";
            path = pkgs.writeText "caddy-504.html" (errPage "504" "Service timed out" "The service behind");
          }
        ];

      # Server-error route shared by every upstream-bearing vHost (proxy
      # helpers, hand-written proxy vHosts, catch-alls). Static and
      # redirect-only vHosts cannot 502 (no upstream) and don't carry it.
      # file_server keeps the ORIGINAL error status after the rewrite —
      # the same mechanism the catch-all 404 page relies on (sandbox-proven
      # 2026-10-07 against the then-deployed caddy).
      serverErrorRoute = ''
        handle_errors 502 503 504 {
          root * ${serverErrorRoot}
          rewrite * /{err.status_code}.html
          file_server
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

          # Fail-closed arm (the 2026-10-16 pbx-artmann lens-burn class):
          # a gate answering 5xx must NEVER fall through to the backend —
          # the client gets an honest 503, never protected content.
          @gatefail status 5xx
          handle_response @gatefail {
            respond "auth gateway unavailable" 503
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
        # Probe endpoints bypass ACCESS LOGGING only (M21): gatus/post-deploy
        # probes were ~80 req/min of log noise into crowdsec + geometrikks.
        # Responses are untouched — a dead check still alerts the same way.
        @probe path /health /healthz /metrics /ping /up /api/healthz /api/server/ping /actuator/health
        log_skip @probe
        # Edge-level OTel spans for EVERY vHost (hand-written, registry
        # fan-out, static roots, catch-alls and the cloud mirrors — they all
        # render through this block). Spans carry the OTel HTTP semantic
        # attributes (method/route/status/duration/client); the span name is
        # the requested host, keeping SigNoz spanmetrics cardinality bounded
        # by the vHost count. Exporter: gRPC → the local SigNoz collector via
        # the unit env below; audit rails: otel-endpoint-audit "grpc-url" +
        # signoz-coverage "caddy" (wiring env, 26h request-driven budget).
        # Caddy cannot continue trace context INTO the backends (they carry
        # no client-side instrumentation), so these are edge spans only.
        tracing {
          span {http.request.host}
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
          # proxy-port:-
          root * ${root}
          file_server
        '';
      };

      protectedVHost = port: hostOverride: {
        extraConfig = ''
          ${tlsConfig}
          ${commonConfig}
          # proxy-port:${toString port}
          @external not remote_ip 127.0.0.1/8 ${lanSubnet}
          handle @external {
            ${forwardAuth}
            ${proxyTo port { inherit hostOverride; }}
          }
          handle {
            ${proxyTo port { inherit hostOverride; }}
          }
          ${serverErrorRoute}
        '';
      };

      plainVHost = port: hostOverride: {
        extraConfig = ''
          ${tlsConfig}
          ${commonConfig}
          # proxy-port:${toString port}
          ${proxyTo port { inherit hostOverride; }}
          ${serverErrorRoute}
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
                  # proxy-port:-
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
      # Deliberate exemptions: (none live — the former voice/whisper
      # hand-written vHost exemptions died with voice-agents, 2026-10-08).
      dnsExemptSubdomains = [ ];
      # vHosts with NO services.integration entry — invisible to the
      # tile-coverage, gatus-coverage and OIDC fan-outs, which all key off
      # the registry (the 2026-10-25 blind-spot audit class). Every name
      # here needs a justification; REGISTRATION is the preferred fix.
      #   alerts — redirect/alias infrastructure AND removal candidate: it
      #     exists only for pre-dash bookmarks; if owner bookmarks are gone
      #     (check fish_history hit-rate before removing), drop the vHost +
      #     this blind row together.
      #   logs — redirect/alias infrastructure (SigNoz logs-explorer
      #     redirect), no service behind it.
      #   dnsblockd — dns-blocker's DoH/DoT endpoint vHost; the DASHBOARD-
      #     facing "dnsblock" subdomain registered 2026-10-25 (§g.2 owner
      #     answer: subdomain ⇒ dashboard), leaving only the endpoint
      #     pair-mate blind.
      #   paperless — deliberately hand-written (native OIDC via Pocket ID,
      #     django-allauth Layer 1; protectedVHost would double-auth — see
      #     the vHost block below). Added 2026-10-25 when the parallel
      #     session's integration rework left it firing the blind-spot
      #     assertion in non-evo-x2 caddy contexts (caddy-mint VM); delete
      #     this row if/when it moves to the registry.
      #   (auth/seo/tasks/dnsblock un-blinded 2026-10-25: pocket-id,
      #     openseo, taskchampion-sync-server and dns-blocker entries gained
      #     subdomains per the §g.2/§g.3 owner answers.)
      registryBlindSubdomains = [
        "alerts"
        "logs"
        "dnsblockd"
        "paperless"
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
        # own. Empty since 2026-10-07: alerts (the legacy PapDashboard
        # alias) became an explicit redirect vHost when the catch-all
        # stopped redirecting to dash.
        let
          ghostAliases = [ ];
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
                # M26 (2026-10-25 caddy edge plan): the port comes from the
                # helper-stamped `# proxy-port:` line, NOT the old "first
                # localhost: line" regex — that heuristic grabbed the
                # forward_auth dial (oauth2-proxy :4180) on every protected
                # vHost, so the smoke's backend-down SKIP never fired for
                # Layer 2 and dead backends mislabeled as auth-gateway
                # failures. Static/redirect-only vHosts carry
                # `# proxy-port:-`. Hand-written proxy vHosts stamp their
                # primary backend port inline.
                portLine = lib.findFirst (l: lib.hasInfix "# proxy-port:" l) null (
                  lib.splitString "\n" vhost.extraConfig
                );
                # splitString+last: stamps inside handle blocks keep their
                # render indentation — split on the marker, not hasPrefix.
                port = if portLine == null then "-" else lib.last (lib.splitString "# proxy-port:" portLine);
              in
              "${layer} ${lib.removeSuffix ".${domain}" k} ${port}"
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
                hostOverride = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Rewrite the upstream Host header to this value (bank-sync
                    DNS-rebinding-guard class: loopback apps that 403 any
                    non-localhost Host).
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
          # vHost⇒registry (2026-10-25 blind-spot audit): a named vHost with
          # no registry entry is invisible to every fan-out — unmonitored,
          # tile-less, OIDC-less — exactly how pocket-id/openseo/
          # taskchampion/dnsblockd stayed off the dashboard. Register the
          # service (preferred) or extend registryBlindSubdomains with a
          # justification.
          {
            assertion = lib.all (s: lib.elem s (registryBlindSubdomains ++ registrySubdomains)) vhostSubdomains;
            message =
              "caddy: vHost subdomain(s) with no services.integration entry (invisible to tile/gatus/OIDC fan-out): "
              + lib.concatStringsSep ", " (
                builtins.filter (s: !lib.elem s (registryBlindSubdomains ++ registrySubdomains)) vhostSubdomains
              );
          }
          # Mint SAN coverage (2026-10-25 caddy edge plan M25): the boot-minted
          # leaf carries exactly the two dns-local zones. A vHost keyed under
          # any OTHER domain passes every existing check, gets cert0 anyway,
          # and fails its FIRST real TLS handshake hours later — fail eval
          # instead. Negative-tested: scripts/negative-test-lints.sh group
          # `caddy` leg mint-third-zone.
          {
            assertion =
              let
                stripScheme = k: lib.last (lib.splitString "://" k);
                dottedHosts = builtins.filter (h: lib.hasInfix "." h) (
                  map stripScheme (builtins.attrNames config.services.caddy.virtualHosts)
                );
                foreignHosts = builtins.filter (
                  h: !(lib.hasSuffix ".${domain}" h || (cloudDomain != null && lib.hasSuffix ".${cloudDomain}" h))
                ) dottedHosts;
              in
              foreignHosts == [ ];
            message =
              "caddy mint SAN coverage: vHost(s) outside the two minted zones (${domain}${
                lib.optionalString (cloudDomain != null) ", ${cloudDomain}"
              }) — the minted leaf would not cover them and TLS fails at first handshake: "
              + lib.concatStringsSep ", " (
                let
                  stripScheme = k: lib.last (lib.splitString "://" k);
                  dottedHosts = builtins.filter (h: lib.hasInfix "." h) (
                    map stripScheme (builtins.attrNames config.services.caddy.virtualHosts)
                  );
                in
                builtins.filter (
                  h: !(lib.hasSuffix ".${domain}" h || (cloudDomain != null && lib.hasSuffix ".${cloudDomain}" h))
                ) dottedHosts
              )
              + ". Extend the mint SAN list (dnsblockd-cert-mint script) or move the vHost into a minted zone.";
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
          # Logging map (M9 + M21 of the 2026-10-25 caddy edge plan): this
          # global block configures the DEFAULT logger — caddy RUNTIME logs
          # only (journal now, see below). Every vHost also gets a per-host
          # `log { output file access-<host>.log }` block (map below), so
          # each access record lands in exactly ONE file; runtime lines land
          # ONLY in the journal. geometrikks tails the per-vHost files;
          # crowdsec's glob covers them; SigNoz ingests runtime lines from
          # the journald receiver as service "caddy".
          logFormat = ''
            # Runtime logs go to the journal (deep dive finding 3, 2026-10-25):
            # stdout under systemd + the journald encoder (2.11.3+) emits
            # priority-tagged lines the SigNoz journald receiver ingests as
            # service "caddy" — caddy's own errors (reload/TLS/upstream-dial)
            # were invisible to SigNoz while they only landed in the global
            # access.log file, which is now GONE. Per-vHost access-*.log files
            # (map below) are unchanged for crowdsec + geometrikks. Syntax
            # validated against the built 2.11.7 via caddy adapt.
            output stdout
            format journald {
              wrap json
            }
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
              timeouts {
                # Bounds slow-upload (slowloris-class) request-body stalls;
                # 15m covers a 10GB upload at ~10Mbps with headroom (the
                # 10GB cap itself is the per-vHost request_body max_size
                # in commonConfig — deliberate, Immich-class uploads).
                read_body 15m
              }
            }
            # per_host (deep dive finding 1, 2026-10-25): request/error/
            # duration series carry a host label so dashboards and alerts
            # can slice per vHost. Cardinality is bounded by the registry
            # fan-out (~80 vHosts), verified live after enable (F12).
            metrics {
              per_host
            }
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
                # Catch-all HTTPS for unknown *.home.lan: every request gets
                # a real 404 with a branded page (was: permanent redirect to
                # dash; flipped 2026-10-07 so a typo names itself instead of
                # silently landing on the dashboard). error + handle_errors
                # serves the page WITH the 404 status (proven in the sandbox
                # against the deployed caddy 2.11.4).
                "https://*.${domain}" = {
                  extraConfig = ''
                    ${tlsConfig}
                    ${commonConfig}
                    root * ${notFoundRoot}
                    error 404
                    ${serverErrorRoute}
                    handle_errors 404 {
                      rewrite * /index.html
                      file_server
                    }
                  '';
                };

                # Legacy PapDashboard alias: alerts.<domain> pre-dates the
                # dash rename and relied on the old catch-all redirect. Now
                # an explicit vHost with the SAME redirect semantics (drop
                # the URI), kept for old bookmarks/tiles. The cloud mirror
                # comes free via the mirror map below.
                "alerts.${domain}" = {
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
                      # proxy-port:${toString authPort}
                      ${proxyTo authPort { hostOverride = null; }}
                    }
                    ${serverErrorRoute}
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
                      # proxy-port:${toString config.services.paperless.port}
                      ${proxyTo config.services.paperless.port { hostOverride = null; }}
                    }
                    ${serverErrorRoute}
                  '';
                };
                # Forgejo / crm / tasks / manifest / status vHosts:
                # forgejo+crm+manifest+status moved to the registry
                # (services.integration.<name>, plain/protected per entry). dash
                # joined them (services.integration.papdashboard, subdomain =
                # "dash" — the dashboard itself). tasks stays hand-written
                # (taskchampion has no registry entry).
                # The old alerts.<domain> PapDashboard alias has its own
                # redirect vHost above (kept when the catch-all became a
                # 404 page).
                "tasks.${domain}" = protectedVHost config.services.taskchampion-sync-server.port null;
                # OpenSEO: Layer 2 (oauth2-proxy forward-auth). The GSC OAuth callback
                # (/api/gsc/oauth/callback) is exempt from forward-auth — OAuth callback
                # endpoints should be directly reachable to prevent cookie-expiry edge
                # cases and SameSite policy regressions. The callback is browser-initiated
                # (the browser carries the _oauth2_proxy cookie), so forward-auth would
                # pass anyway, but exempting it makes the flow deterministic.
                # Watch-note (2026-10-25 caddy edge plan): keep this vHost
                # HAND-ROLLED — folding it into registry protectedVHost would
                # lose the callback exemption shape (deep dive §f.31).
                "seo.${domain}" = {
                  extraConfig = ''
                    ${tlsConfig}
                    ${commonConfig}
                    @gsc_callback path /api/gsc/oauth/callback
                    handle @gsc_callback {
                      # proxy-port:${toString config.services.openseo.port}
                      ${proxyTo config.services.openseo.port { hostOverride = null; }}
                    }
                    @external not remote_ip 127.0.0.1/8 ${lanSubnet}
                    handle @external {
                      ${forwardAuth}
                      # proxy-port:${toString config.services.openseo.port}
                      ${proxyTo config.services.openseo.port { hostOverride = null; }}
                    }
                    handle {
                      # proxy-port:${toString config.services.openseo.port}
                      ${proxyTo config.services.openseo.port { hostOverride = null; }}
                    }
                    ${serverErrorRoute}
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
                    # proxy-port:${toString config.services.dns-blocker.statsPort}
                    ${proxyTo config.services.dns-blocker.statsPort { hostOverride = null; }}
                    ${serverErrorRoute}
                  '';
                };
                "dnsblockd.${domain}" = {
                  extraConfig = ''
                    ${tlsConfig}
                    ${commonConfig}
                    redir * https://dnsblock.${domain}{uri} permanent
                  '';
                };
                # logs.<domain> — Dozzle's old home. Docker removal 2026-10-08
                # retired Dozzle; logs live in SigNoz (whole-journal journald
                # ingestion + live tail), so the subdomain redirects to the
                # SigNoz logs explorer instead of growing a new service.
                "logs.${domain}" = {
                  extraConfig = ''
                    ${tlsConfig}
                    ${commonConfig}
                    redir * https://signoz.${domain}/logs{uri} permanent
                  '';
                };
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
                            # The upstream server now sends identical headers itself;
                            # this block is redundant once that rev is deployed —
                            # removal tracked in docs/todo/services.md.
                            @noCache path /ui /ui/ /ui/index.html /ui/bootstrap.js
                            header @noCache Cache-Control "no-cache, no-store, must-revalidate"

                            # proxy-port:${toString ports.monitor365-server}
                            ${proxyTo ports.monitor365-server { hostOverride = null; }}
                            ${serverErrorRoute}
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
            # Log-file mode override: caddy's file writer defaults to 0600
            # (caddyserver.com/docs/caddyfile/directives/log, verified
            # 2026-10-16), which leaves NO group access — the crowdsec
            # caddy-group acquis fix could traverse the 0750 dir but still
            # cannot OPEN the files (live-proven 2026-10-16: "Error setting
            # up tail ... permission denied" per file, zero file-source hits
            # even with the group live). mode 0640 = caddy rw + group r.
            # Two caddy caveats (docs, same page): a server RESTART (not a
            # reload) applies output-file option changes, and open(2) never
            # re-modes EXISTING files — the crowdsec-caddy-logs-readable
            # timer (crowdsec.nix) re-chmods the live files per tick until
            # every file has rolled over under the new mode.
            lib.mapAttrs
              (
                host: opts:
                opts
                // {
                  logFormat = ''
                    output file /var/log/caddy/access-${lib.replaceStrings [ "/" " " ] [ "_" "_" ] host}.log {
                      mode 0640
                      # Bounded rolls (M21): keep 3 x 100MiB, 168h, zstd on
                      # roll (syntax validated against 2.11.7 adapt).
                      roll_size 100MiB
                      roll_keep 3
                      roll_keep_for 168h
                      roll_compression zstd
                    }
                  '';
                }
              )
              (
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
                    # Cloud catch-all: same 404 page as the home.lan catch-all
                    # (mirror semantics). Unknown cloud names NXDOMAIN in DNS
                    # (explicit records only, sdns ignores wildcards), so only
                    # explicit-record names without a vHost land here. The
                    # page's dashboard link stays on dash.home.lan by design
                    # (auth-redirect doctrine: VPN clients resolve both zones).
                    "https://*.${cloudDomain}" = {
                      extraConfig = ''
                        ${tlsConfig}
                        ${commonConfig}
                        root * ${notFoundRoot}
                        error 404
                        ${serverErrorRoute}
                        handle_errors 404 {
                          rewrite * /index.html
                          file_server
                        }
                      '';
                    };
                  }
                ))
              );
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
          environment = {
            # Edge tracing exporter (commonConfig `tracing` directive): gRPC
            # to the local SigNoz collector. Scheme REQUIRED — caddy's
            # exporter is otel-go otlptracegrpc, a URL parser (the 2026-08-14
            # schemeless-endpoint startup-hang class; grpc-url expectation in
            # otel-endpoint-audit enforces this at eval).
            OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:${toString ports.signoz-otlp-grpc}";
            OTEL_SERVICE_NAME = "caddy";
          };
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
