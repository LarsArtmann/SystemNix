# Runbook: docs/services/dnsblockd.md
# DNS blocker: dnsblockd (embedded recursive resolver) + blocklists + block page + stats API
#
# dnsblockd is the sole DNS resolver on :53 with an embedded recursive resolver
# (IANA root hints + DNSSEC), local zones, LAN ACLs, DoT/DoH forwarding, and
# blocklist matching.
# The block-page HTTP server runs on the block IP (:80/:443). It also hosts the
# scoped filter proxy (ADR-0018): opted-in domains resolve to the block IP and
# the L7 proxy serves the real upstream with the classifier script injected.
#
# Blocklist files are fetched at eval time (pkgs.fetchurl) and passed directly
# to dnsblockd via the dns_blocklists config key — dnsblockd parses them natively
# at startup and hot-reloads them on interval. The dnsblockd process subcommand
# runs at build time to generate mapping.json (domain → source → category)
# used by the HTTP block page for category display. The unbound.conf output is
# a required positional argument of `dnsblockd process` but is unused at runtime.
_: {
  flake.nixosModules.dns-blocker =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.dns-blocker;
      inherit (lib) mkEnableOption mkOption types;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        mkStateDir
        ports
        ;

      categoriesJSON = pkgs.writeText "dnsblockd-categories.json" (builtins.toJSON cfg.categories);

      # Idempotent helper to attach the block IP to the configured interface.
      # Runs as a systemd oneshot ordered after the interface .device unit so
      # dnsblockd never starts before its listen address exists.
      attachIPScript = pkgs.writeShellApplication {
        name = "dnsblockd-attach-ip";
        runtimeInputs = [
          pkgs.iproute2
          pkgs.gnugrep
        ];
        text = ''
          if ip addr show "${cfg.blockInterface}" | grep -qF "${cfg.blockIP}/${toString cfg.blockIPPrefix}"; then
            echo "IP ${cfg.blockIP} already attached to ${cfg.blockInterface}"
            exit 0
          fi
          exec ip addr add "${cfg.blockIP}/${toString cfg.blockIPPrefix}" dev "${cfg.blockInterface}"
        '';
      };

      # Fetch each blocklist file at eval time (fast - just metadata lookup)
      fetchedRawBlocklists = map (bl: {
        inherit (bl) name;
        file = pkgs.fetchurl {
          inherit (bl) url;
          inherit (bl) hash;
          name = "${bl.name}-raw";
        };
      }) cfg.blocklists;

      # Filter out whitelisted domains (and their subdomains) from each blocklist
      # at eval time. dnsblockd's runtime blocklist matcher walks up the dot
      # hierarchy, so a whitelisted `discord.com` must also strip `*.discord.com`
      # entries — otherwise `foo.discord.com` still matches its own blocklist
      # row. This complements the build-time processor whitelist (which only
      # affects mapping.json) by making the allowlist effective at runtime.
      whitelistFileForFilter = pkgs.writeText "dns-blocker-filter-whitelist.txt" (
        lib.concatLines cfg.whitelist
      );

      filterScript = pkgs.writeText "dns-blocker-filter.py" ''
        import sys, os

        whitelist_path = os.environ["WHITELIST_FILE"]
        src_path = os.environ["SRC_FILE"]
        dst_path = os.environ["DST_FILE"]

        def normalize(d):
            d = d.strip().rstrip(".").lower()
            return d

        whitelist = set()
        with open(whitelist_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                norm = normalize(line)
                if norm:
                    whitelist.add(norm)

        def is_whitelisted(domain):
            if not domain:
                return False
            d = normalize(domain)
            if d in whitelist:
                return True
            # Walk up parent domains: foo.bar.discord.com is covered by
            # whitelist entry "discord.com" or "bar.discord.com".
            parts = d.split(".")
            for i in range(1, len(parts)):
                parent = ".".join(parts[i:])
                if parent in whitelist:
                    return True
            return False

        def extract_domain(line):
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("!"):
                return ""
            if s.startswith("address=/") or s.startswith("local=/"):
                rest = s[len("address=/"):] if s.startswith("address=/") else s[len("local=/"):]
                return rest.rstrip("/")
            if s.startswith("||"):
                rest = s[2:]
                if "^" in rest:
                    rest = rest[:rest.index("^")]
                return rest
            fields = s.split()
            if len(fields) >= 2:
                return fields[1]
            if len(fields) == 1:
                return fields[0]
            return ""

        kept = 0
        skipped = 0
        with open(src_path) as src, open(dst_path, "w") as dst:
            for line in src:
                original = line.rstrip("\n")
                domain = extract_domain(original)
                if is_whitelisted(domain):
                    skipped += 1
                    continue
                dst.write(original + "\n")
                kept += 1

        print(f"kept={kept} skipped={skipped}", file=sys.stderr)
      '';

      filterBlocklist =
        name: srcPath:
        pkgs.runCommand "${name}-filtered" { } ''
          mkdir -p $out
          WHITELIST_FILE=${whitelistFileForFilter} \
          SRC_FILE=${srcPath} \
          DST_FILE=$out/${name} \
            ${pkgs.python3}/bin/python3 ${filterScript}
        '';

      # Apply the whitelist filter to every fetched blocklist.
      # The runtime DNS engine and the build-time processor both consume these.
      fetchedBlocklists = map (bl: {
        inherit (bl) name;
        file = filterBlocklist bl.name (toString bl.file);
      }) fetchedRawBlocklists;

      # extraDomains → a synthetic hosts-format blocklist, appended AFTER the
      # fetched lists. dns_blocklists order is load-bearing for source
      # attribution (the first list containing a domain wins the dedup), so
      # fetched sources keep attribution for overlaps — reddit.com is already
      # in StevenBlack-everything. The option fed NOTHING before 2026-09-30
      # (declared, never rendered — the phantom-config class): the documented
      # 2026-09-16 owner decision to block us.i.posthog.com at DNS level was
      # silently NOT in effect (mapping.json-verified: reddit incidentally
      # covered, posthog not). The same whitelist filter as the fetched lists
      # keeps allow semantics uniform across every source.
      extraDomainsBlocklist = lib.optional (cfg.extraDomains != [ ]) {
        name = "systemnix-extra";
        file = filterBlocklist "systemnix-extra" (
          toString (
            pkgs.writeText "dns-blocker-extra-domains" (
              lib.concatLines (map (d: "0.0.0.0 ${d}") (lib.unique cfg.extraDomains))
            )
          )
        );
      };

      allBlocklists = fetchedBlocklists ++ extraDomainsBlocklist;

      # Whitelist file (used by dnsblockd process for mapping.json generation)
      whitelistFile = pkgs.writeText "dns-blocker-whitelist.txt" (lib.concatLines cfg.whitelist);

      # Build processor arguments: blocklist-file name pairs.
      # NOTE: bl.file is the derivation OUTPUT (a directory) from filterBlocklist;
      # the actual hosts file lives at $out/${name} inside it. Pointing at the
      # directory silently yielded 0 entries (dnsblockd could not read a dir as a
      # hosts file), so mapping.json came out empty {} and runtime blocking was
      # inactive. Always reference the file inside the dir.
      processorArgs = lib.concatStringsSep " " (
        lib.concatMap (bl: [
          (toString "${bl.file}/${bl.name}")
          bl.name
        ]) allBlocklists
      );

      # Run processor at build time to generate mapping.json (domain → source → category).
      # unbound.conf is a required CLI positional argument but unused at runtime.
      processedBlocklist =
        pkgs.runCommand "dns-blocker-processed"
          {
            nativeBuildInputs = [ pkgs.dnsblockd ];
          }
          ''
            mkdir -p $out
            dnsblockd process \
              ${cfg.blockIP} \
              ${whitelistFile} \
              $out/unbound.conf \
              $out/mapping.json \
              ${processorArgs}

            # Fail the build if mapping.json is empty — this catches the
            # blocklist-dir-vs-file path bug and any future regression where
            # dnsblockd silently reads 0 entries. An empty mapping.json means
            # ZERO domains are blocked at runtime.
            MAPPING_SIZE=$(wc -c < $out/mapping.json)
            if [ "$MAPPING_SIZE" -lt 10 ]; then
              echo "ERROR: mapping.json is only $MAPPING_SIZE bytes — blocklist processing produced no entries." >&2
              echo "Check that processorArgs reference files inside filterBlocklist dirs (\''${bl.file}/\''${bl.name}), not the dirs themselves." >&2
              exit 1
            fi
            echo "mapping.json: $MAPPING_SIZE bytes — blocklist processing OK"
          '';

      # Blocklist file paths for dnsblockd's native DNS blocklist loader.
      # When tempAllowAll is true, pass an empty list so nothing is blocked.
      # Reference the file INSIDE the filtered derivation dir (see processorArgs
      # note above) — passing the dir itself loads 0 entries.
      blocklistPaths =
        if cfg.tempAllowAll then [ ] else map (bl: toString "${bl.file}/${bl.name}") allBlocklists;

      # Sops secret paths and generated YAML config — in outer scope so that
      # restartTriggers can reference the config file, forcing a service restart
      # whenever the binary, config, or blocklists change.
      # Without restartTriggers, switch-to-configuration may not detect unit-file
      # changes on certain deploys (observed during the unbound→dnsblockd migration:
      # the running process kept old config while unbound was stopped, leaving :53 unbound).
      # OIDC client-secret env file, written by the dnsblockd-oidc-secret
      # oneshot (StateDirectory-scoped, separate from dnsblockd's own state).
      oidcEnvFile = "/var/lib/dnsblockd-oidc/client-secret.env";
      caCert = config.sops.secrets.dnsblockd_ca_cert.path;
      caKey = config.sops.secrets.dnsblockd_ca_key.path;
      dnsblockdConfigFile = pkgs.writeText "dnsblockd-config.yaml" (
        lib.generators.toYAML { } (
          {
            listen_addr = cfg.blockIP;
            port = cfg.blockPort;
            tls_port = cfg.blockTLSPort;
            # HTTP/3 (QUIC) on the same port number as tls_port (upstream
            # errH3RequiresTLSPort rejects tls_h3_enabled with tls_port <= 0 —
            # asserted below). Inert: false matches the upstream default.
            tls_h3_enabled = cfg.tlsH3Enabled;
            stats_addr = "127.0.0.1";
            stats_port = cfg.statsPort;
            # OTLP trace export to the local SigNoz collector (Go
            # otlptracehttp: bare host:port, no scheme — dnsblockd strips an
            # optional http:// itself, internal/otel/otel.go:97). Full
            # instrumentation exists upstream (tracking.Dispatch /
            # tracking.batchFlush + stats-API handler spans) but was dark
            # until this key was set (2026-08-31 coverage audit). Metrics
            # cardinality concerns do NOT apply to spans — span attributes
            # never create unbounded metric series.
            otlp_endpoint = "localhost:${toString ports.signoz-otlp-http}";
            ca_cert_file = "${caCert}";
            ca_key_file = "${caKey}";
            blocklist_mapping_file = "${processedBlocklist}/mapping.json";
            temp_allowlist_path = "/var/lib/dnsblockd/temp-allowlist";
            # Permanent allowlist persistence. Without this key the dashboard's
            # "Always allow" verdicts and POST /api/allowlist entries live in
            # memory ONLY — every restart (and restartTriggers restarts the
            # unit on every deploy) wipes them, so the same false positives
            # must be re-allowed over and over (deep-dive 2026-09-30, finding
            # #1: the only gap in the config that actively loses data, daily).
            allowlist_path = "/var/lib/dnsblockd/allowlist";
            tracking_mode = "METADATA_ONLY";
            tracking_db_path = "/var/lib/dnsblockd/tracking.db";
            # Operator WAL (CQRS journal) — owner-enabled 2026-10-07 (the
            # evo-x2 enablement decision from the 2026-10-06 WAL landing's
            # open questions, dnsblockd TODO T354): append-only Command+
            # Events+Queries journal riding BESIDE the tracking tables.
            # audit_entries stays the evidence doctrine; nothing serves
            # analytics reads from the WAL. Engine/durability/query-log/
            # retention ride upstream defaults (sqlite, normal, off, 30d).
            # The DSN is absolute: the koanf default is CWD-relative.
            # Inspect: `dnsblockd journal status|replay|verify -c <this
            # file>` (read-only open, safe against the live DB).
            journal_enabled = true;
            journal_dsn = "/var/lib/dnsblockd/journal.db";
            # Journal-flood control: the first 500 messages per message+level
            # pass unsampled, then 1-in-100. Guards the blocked-domain burst
            # class — a client hammering blocked domains emits one log line
            # per query straight into the journal (→ SigNoz) otherwise.
            log_sampling_threshold = 500;
            log_sampling_rate = 100;

            # ── Reverse proxy for temp-allowed domains ──
            proxy_enabled = cfg.proxyEnabled;
            proxy_tls_passthrough = cfg.proxyTLSPassthrough;
            proxy_connect_timeout = cfg.proxyConnectTimeout;
            # CSP stripping applies only to injected filter-proxy responses;
            # rendered unconditionally so the deployed config stays explicit.
            proxy_inject_strip_csp = cfg.proxyInjectStripCSP;

            # Double-submit CSRF protection for the dashboard's action forms
            # (allow/report/bulk). Requires dnsblockd >= v0.9.3 (T300 fixed the
            # token-login 403 that made csrf+API-tokens mutually exclusive —
            # the lock is past it). csrf_cookie_secure stays at its default
            # true: the dashboard is served HTTPS via Caddy, and the DMS widget
            # authenticates with a Bearer token, not cookies, so both flows
            # coexist with csrf on.
            csrf_enabled = true;

            # ── Embedded DNS resolver ──
            dns_enabled = true;
            dns_exit_on_failure = true;
            dns_listen_addr = "0.0.0.0";
            dns_port = 53;
            dns_block_ip = cfg.blockIP;
            dns_block_response = cfg.dnsBlockResponse;
            dns_blocklists = blocklistPaths;
            dns_dnssec_enabled = cfg.enableDNSSEC;
            dns_ipv6_enabled = cfg.dnsIPv6Enabled;
            dns_ecs_enabled = cfg.dnsEcsEnabled;
            dns_reload_interval = cfg.dnsReloadInterval;
            dns_block_ttl = cfg.dnsBlockTTL;
            dns_resolve_timeout = cfg.dnsResolveTimeout;
            dns_restart_backoff = cfg.dnsRestartBackoff;
            dns_rate_limit_per_sec = cfg.dnsRateLimitPerSec;
            dns_rate_limit_burst = cfg.dnsRateLimitBurst;
            dns_rate_limit_max_clients = cfg.dnsRateLimitMaxClients;
          }
          // lib.optionalAttrs (cfg.blocklistTrialUrls != [ ]) {
            dns_blocklist_trial_urls = cfg.blocklistTrialUrls;
          }
          // lib.optionalAttrs (cfg.blocklistCacheDir != "") {
            # Persistent URL-blocklist cache. Defaulted (not optional) —
            # see the blocklistCacheDir option: an unset dir silently means
            # os.TempDir(), which PrivateTmp wipes on every restart.
            dns_blocklist_cache_dir = cfg.blocklistCacheDir;
          }
          // lib.optionalAttrs (cfg.dnsEcsIpv4PrefixLen != 0) {
            dns_ecs_ipv4_prefix_len = cfg.dnsEcsIpv4PrefixLen;
          }
          // lib.optionalAttrs (cfg.dnsEcsIpv6PrefixLen != 0) {
            dns_ecs_ipv6_prefix_len = cfg.dnsEcsIpv6PrefixLen;
          }
          // lib.optionalAttrs cfg.dnsTLSEnabled {
            dns_tls_enabled = true;
            dns_tls_port = cfg.dnsTLSPort;
          }
          // lib.optionalAttrs cfg.dnsDOHEnabled {
            dns_doh_enabled = true;
            dns_doh_port = cfg.dnsDOHPort;
            dns_doh_path = cfg.dnsDOHPath;
          }
          // lib.optionalAttrs (cfg.trustedProxies != [ ]) {
            trusted_proxies = cfg.trustedProxies;
          }
          // lib.optionalAttrs (cfg.dnsDOHTrustedProxies != [ ]) {
            dns_doh_trusted_proxies = cfg.dnsDOHTrustedProxies;
          }
          // lib.optionalAttrs (cfg.proxyUpstreamDNS != [ ]) {
            proxy_upstream_dns = cfg.proxyUpstreamDNS;
          }
          // lib.optionalAttrs (cfg.proxyFilterDomains != [ ]) {
            proxy_filter_domains = cfg.proxyFilterDomains;
          }
          // lib.optionalAttrs (cfg.dnsForwarders != [ ]) {
            dns_forwarders = cfg.dnsForwarders;
          }
          // lib.optionalAttrs (cfg.localRecords != { }) {
            dns_local_records = cfg.localRecords;
          }
          // lib.optionalAttrs (cfg.localZones != [ ]) {
            dns_local_zones = cfg.localZones;
          }
          // lib.optionalAttrs (cfg.allowedNetworks != [ ]) {
            dns_allowed_networks = cfg.allowedNetworks;
          }
          // lib.optionalAttrs (cfg.categories != { }) {
            categories_file = "${categoriesJSON}";
          }
          // lib.optionalAttrs (cfg.oidcIssuerURL != "") {
            # OIDC single sign-on for the dashboard (Pocket ID). The client
            # secret rides the DNSBLOCKD_OIDC_CLIENT_SECRET env var, bridged
            # from Pocket ID's client-secrets provisioning by the
            # dnsblockd-oidc-secret oneshot below.
            oidc_enabled = true;
            oidc_issuer_url = cfg.oidcIssuerURL;
            oidc_client_id = cfg.oidcClientID;
            oidc_redirect_url = cfg.oidcRedirectURL;
            oidc_scopes = [
              "openid"
              "profile"
              "email"
            ];
            oidc_session_ttl = "12h";
          }
          // lib.optionalAttrs (cfg.oidcButtonText != "") {
            # Provider-specific SSO button label (dnsblockd ≥ this version
            # falls back to "Sign in with SSO" when unset).
            oidc_button_text = cfg.oidcButtonText;
          }
          // lib.optionalAttrs (cfg.devices != [ ]) {
            # Household device registry (see the devices option). group is
            # omitted entirely when null — dnsblockd treats an empty-string
            # group differently from an absent one.
            devices = map (
              d:
              {
                inherit (d) id name ips;
              }
              // lib.optionalAttrs (d.group != null) { inherit (d) group; }
            ) cfg.devices;
          }
          // lib.optionalAttrs (cfg.users != [ ]) {
            inherit (cfg) users;
          }
          // lib.optionalAttrs (cfg.policies != [ ]) {
            # Per-device/group policies (see the policies option). Rendered
            # verbatim — the submodule defaults already drop empty lists
            # only via cfg-level omission; per-policy empty arcs stay []
            # which upstream treats as "no entries".
            inherit (cfg) policies;
          }
        )
      );
    in
    {
      options.services.dns-blocker = {
        enable = mkEnableOption "DNS blocker with embedded resolver + block page";

        blockInterface = mkOption {
          type = types.str;
          default = "lo";
          description = "Network interface for block IP address";
        };

        blockIPPrefix = mkOption {
          type = types.int;
          default = 8;
          description = "Network prefix length for block IP";
        };

        blockIP = mkOption {
          type = types.str;
          default = "127.0.0.2";
          description = "IP address for blocked domains (dnsblockd listens here)";
        };

        blockPort = mkOption {
          type = types.port;
          default = 80;
          description = "Port for dnsblockd HTTP server";
        };

        blockTLSPort = mkOption {
          type = types.port;
          default = 443;
          description = "Port for dnsblockd HTTPS server (self-signed cert)";
        };

        statsPort = mkOption {
          type = types.port;
          default = ports.dns-blocker-stats;
          description = "Port for dnsblockd stats API (localhost only)";
        };

        trustedProxies = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Proxy IPs/CIDRs whose X-Forwarded-For / X-Real-IP headers dnsblockd
            trusts for client-IP attribution (audit log, rate limiting).
            Only set this for proxies that cannot be bypassed — the stats API
            binds to 127.0.0.1, so listing 127.0.0.1 (Caddy) is spoof-safe.
          '';
        };

        blocklists = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                name = mkOption {
                  type = types.str;
                  description = "Blocklist name";
                };
                url = mkOption {
                  type = types.str;
                  description = "URL to fetch hosts file";
                };
                hash = mkOption {
                  type = types.str;
                  description = "SHA256 hash of fetched file";
                };
              };
            }
          );
          default = [ ];
          description = "Blocklists to fetch (hosts format)";
        };

        whitelist = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Domains to never block (whitelist)";
        };

        extraDomains = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional domains to block (not in blocklists)";
        };

        blocklistTrialUrls = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt" ];
          description = ''
            TRIAL blocklist sources (upstream T197 — shadow evaluation
            only): fetched into a separate blocklist that feeds ONLY
            request_tracks.would_block with source prefix "trial:", never
            enforcing blocks. Observe verdicts on the dashboard before
            promoting a list into extraDomains or a fetched blocklist.

            Entries must be http(s) URLs with a host (the fetcher speaks
            nothing else); mirrors upstream's dns_blocklist_urls
            validation at eval time.
          '';
        };

        blocklistCacheDir = mkOption {
          type = types.str;
          default = "/var/lib/dnsblockd/blocklist-cache";
          description = ''
            Persistent home for the URL-blocklist last-known-good cache
            (dns_blocklist_cache_dir). The default lives under the unit's
            StateDirectory: a reboot combined with an upstream outage
            then still boots the CACHED blocklist instead of an empty one
            (PrivateTmp eats /tmp, so upstream's default cache location
            never survives a restart). Set to "" to restore upstream's
            os.TempDir() behavior. Must be absolute when set.
          '';
        };

        categories = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Domain suffix -> category for block page";
        };

        tempAllowAll = mkOption {
          type = types.bool;
          default = false;
          description = "Temporarily allow all DNS queries (skip blocklist loading). When true, dnsblockd resolves all queries without blocking.";
        };

        # ── DNS resolver options ──

        enableDNSSEC = mkOption {
          type = types.bool;
          default = true;
          description = "Enable DNSSEC validation in the embedded resolver";
        };

        dnsForwarders = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Upstream DNS forwarders (tls://, https://, or host:port format).
            When empty (default), the embedded resolver performs full root recursion
            using IANA root hints and DNSSEC — no third-party dependency, maximum privacy.

            Set to forward through a trusted resolver when:
            - Behind a VPN/firewall that blocks port 53
            - ISP injects fake DNS responses
            - You want the speed of a caching forwarder

            Example: ["tls://194.242.2.2" "tls://9.9.9.9"]
          '';
        };

        localRecords = mkOption {
          type = types.attrsOf types.str;
          default = { };
          example = {
            "forgejo.home.lan." = "192.168.1.150";
          };
          description = "Static DNS A/AAAA records (domain → IP). Answered before blocklist or resolver lookup.";
        };

        localZones = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "home.lan." ];
          description = "Local zone boundaries — returns NXDOMAIN for unknown names within these zones (like Unbound local-zone static). Prevents internal naming from leaking upstream.";
        };

        allowedNetworks = mkOption {
          type = types.listOf types.str;
          default = [ "127.0.0.0/8" ];
          description = "CIDR networks allowed to query the DNS resolver. Prevents open-resolver abuse.";
        };

        dnsIPv6Enabled = mkOption {
          type = types.bool;
          default = true;
          description = "Enable IPv6 upstream DNS resolution. Set to false on networks without global IPv6 (matches Unbound's do-ip6 = false).";
        };

        dnsEcsEnabled = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Attach an EDNS Client Subnet (ECS) option to forwarded queries,
            masked to the configured prefix length (upstream never forwards
            the client's full IP). INERT by default (owner nod 2026-09-30):
            enabling trades privacy for CDN geo-routing accuracy — the
            forwarder (or authoritative server) learns the client's /24
            (IPv4) or /56 (IPv6) network locality instead of the resolver's
            address. Only worth enabling when recursive answers visibly
            geo-miss (e.g. CDN nodes continents away).
          '';
        };

        dnsEcsIpv4PrefixLen = mkOption {
          type = types.int;
          default = 0;
          description = ''
            IPv4 ECS prefix length. 0 (default) keeps upstream's /24 —
            the RFC 7871 sweet spot: one more bit would pin the client
            to a single address; fewer bits blur geo-routing gains.
          '';
        };

        dnsEcsIpv6PrefixLen = mkOption {
          type = types.int;
          default = 0;
          description = ''
            IPv6 ECS prefix length. 0 (default) keeps upstream's /56 —
            a typical end-site allocation (RFC 6177), matching the /24
            IPv4 choice in specificity.
          '';
        };

        tlsH3Enabled = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Serve dnsblockd's own HTTP surfaces (block page, dashboard)
            over HTTP/3 (QUIC) in addition to HTTP/2, on the SAME port
            number as blockTLSPort (upstream koanf key tls_h3_enabled).
            INERT by default (owner-gated 2026-09-30): QUIC advertisement
            mainly helps high-latency links; on LAN the TCP block page is
            already sub-millisecond. Enabling adds a UDP listener on
            <blockTLSPort> — at the default 443 that port is already open
            host-wide (caddy h3 precedent; dropping UDP/443 once sent
            Alt-Svc-following clients into a blackhole), and the block
            page binds the SPECIFIC blockIP (192.168.1.200), so it
            coexists with caddy's wildcard UDP/443 bind. A non-default
            blockTLSPort needs <port>/udp opened in networking.firewall
            for off-LAN clients (LAN rides the trusted interface).
          '';
        };

        dnsReloadInterval = mkOption {
          type = types.str;
          default = "1h";
          description = "Blocklist hot-reload interval (Go duration format).";
        };

        dnsBlockResponse = mkOption {
          type = types.enum [
            "zero_ip"
            "nxdomain"
          ];
          default = "zero_ip";
          description = ''
            DNS response type for blocked domains.
            `zero_ip` returns the block IP (allows block-page HTTP serving).
            `nxdomain` returns NXDOMAIN (faster, but no block page).
          '';
        };

        dnsBlockTTL = mkOption {
          type = types.ints.positive;
          default = 60;
          description = "TTL (seconds) for block response DNS records. Lower values propagate policy changes faster at the cost of more client re-queries.";
        };

        dnsResolveTimeout = mkOption {
          type = types.str;
          default = "10s";
          description = "Per-query resolver timeout (Go duration). A SERVFAIL is sent to the client if no upstream response arrives in time. Increase for slow links.";
        };

        dnsRestartBackoff = mkOption {
          type = types.str;
          default = "1s";
          description = "Initial restart backoff after a DNS listener crash (Go duration). Doubles per failed attempt up to 10s, with ±20% jitter.";
        };

        dnsRateLimitPerSec = mkOption {
          type = types.ints.unsigned;
          default = 0;
          description = ''
            Maximum DNS queries per second per client IP (DoS protection).
            0 = disabled (default, matches upstream). Clients exceeding the limit
            receive REFUSED. Enable on any resolver reachable beyond a single
            trusted host.
          '';
        };

        dnsRateLimitBurst = mkOption {
          type = types.ints.unsigned;
          default = 0;
          description = ''
            Burst allowance for DNS rate limiting. 0 = disabled (default, matches upstream).
            Must be set when dnsRateLimitPerSec > 0.
          '';
        };

        dnsRateLimitMaxClients = mkOption {
          type = types.ints.positive;
          default = 10000;
          description = "Maximum tracked client IPs for rate limiting. Oldest entries are evicted when the table fills.";
        };

        # ── DNS-over-TLS (DoT) ──

        dnsTLSEnabled = mkOption {
          type = types.bool;
          default = false;
          description = "Enable DNS-over-TLS (DoT) listener on port 853. Requires ca_cert_file/ca_key_file (wired automatically via sops).";
        };

        dnsTLSPort = mkOption {
          type = types.port;
          default = 853;
          description = "Port for DNS-over-TLS listener.";
        };

        # ── DNS-over-HTTPS (DoH, RFC 8484) ──

        dnsDOHEnabled = mkOption {
          type = types.bool;
          default = false;
          description = "Enable DNS-over-HTTPS (DoH) listener. Requires ca_cert_file/ca_key_file (wired automatically via sops).";
        };

        dnsDOHPort = mkOption {
          type = types.port;
          default = 8443;
          description = "Port for DNS-over-HTTPS listener (must differ from tls_port and dnsTLSPort).";
        };

        dnsDOHPath = mkOption {
          type = types.str;
          default = "/dns-query";
          description = "URL path for DoH queries (RFC 8484 default).";
        };

        dnsDOHTrustedProxies = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            CIDR ranges trusted to set X-Forwarded-For for DoH ACL evaluation.
            Empty = never trust XFF (all queries appear to come from the proxy IP).
            Set when behind a known reverse proxy (e.g. ["10.0.0.0/8"]).
          '';
        };

        # ── Reverse proxy for temp-allowed domains ──

        proxyEnabled = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Reverse-proxy temp-allowed domains to their real backend.
            Browsers cache the block IP, so after temp-allowing a domain the user
            often cannot reach the real site. The proxy fetches content transparently
            so the "Continue to site" link works immediately. SSRF-protected (blocks
            RFC1918, loopback, link-local, and CGNAT IPs); response body capped at 10MB.
          '';
        };

        oidcIssuerURL = mkOption {
          type = types.str;
          default = "";
          description = ''
            OIDC issuer URL for dashboard single sign-on (e.g.
            "https://auth.example.com"). Empty disables SSO; the auth token
            stays the only gate. The client secret is bridged from Pocket ID
            client-secrets provisioning (requires pocket-id-config.provision).
          '';
        };

        oidcClientID = mkOption {
          type = types.str;
          default = "dnsblockd";
          description = "OIDC client ID registered at the provider";
        };

        oidcRedirectURL = mkOption {
          type = types.str;
          default = "";
          description = ''
            External SSO callback URL, e.g.
            "https://dnsblock.example.com/auth/oidc/callback" (required when
            oidcIssuerURL is set).
          '';
        };

        oidcButtonText = mkOption {
          type = types.str;
          default = "";
          description = ''
            Optional provider-specific label for the SSO login button (e.g.
            "Sign in with Pocket ID"). Empty uses dnsblockd's generic
            "Sign in with SSO" default.
          '';
        };

        proxyConnectTimeout = mkOption {
          type = types.str;
          default = "10s";
          description = "Timeout for connecting to the real backend through the proxy (Go duration).";
        };

        proxyUpstreamDNS = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            DNS servers used by the proxy to resolve real backend IPs.
            Must bypass dnsblockd's own resolver to prevent loops.
            When empty, dnsblockd uses its compiled-in defaults (Cloudflare, Google, Quad9).
            Example: ["1.1.1.1:53" "8.8.8.8:53"]
          '';
        };

        proxyTLSPassthrough = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Splice HTTPS connections for temp-allowed domains to the real backend
            at the TCP layer (SNI routing), so browsers get the backend's real
            certificate without trusting the dnsblockd CA. Filter domains
            (proxyFilterDomains) never splice regardless — their TLS must
            terminate on the operator CA for script injection (ADR-0018).
          '';
        };

        # ── Scoped filter proxy (ADR-0018) ──

        proxyFilterDomains = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Registrable-domain suffixes answered with the block IP so the L7
            proxy can serve the real upstream and inject the classifier script
            (ADR-0018 scoped DNS lie). TLS for these domains always terminates
            on the operator CA — devices must trust the dnsblockd CA. Empty =
            feature off. Precedence: allowlist > filter > block. Requires
            dnsBlockResponse "zero_ip" (a lie needs an address; upstream
            rejects the NXDOMAIN combination at startup). The filter set is
            read at startup — changes restart the service (blocklist feeds
            keep their own hot reload).
          '';
        };

        proxyInjectScriptURL = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Script injected into strict text/html 200 responses (<=2MB) on
            filter domains — typically the nsfw-classifier's
            http://<host>:<port>/inject/filter.js. Empty disables injection
            (zero-touch passthrough). Passed via the DNSBLOCKD_PROXY_INJECT_SCRIPT_URL
            env var, NOT the YAML: the config file lands world-readable in the
            Nix store and the URL can carry a sensitive host:port (same rule
            as upstream's auth_token).
          '';
        };

        proxyInjectStripCSP = mkOption {
          type = types.bool;
          default = true;
          description = "Strip upstream Content-Security-Policy headers on injected filter-proxy responses only (inert while proxyInjectScriptURL is null).";
        };

        # ── Device + user registry (household attribution) ──

        devices = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                id = mkOption {
                  # Upstream cap: lowercase-slug ids, max 256 devices.
                  type = types.strMatching "[a-z0-9]([a-z0-9-]*[a-z0-9])?";
                  description = "Stable device id (lowercase slug). Only the id is persisted in tracking rows; name/group are config-owned display data.";
                };
                name = mkOption {
                  type = types.str;
                  description = "Display name shown in the dashboard Top Clients table.";
                };
                group = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Optional group tag (e.g. \"kids\") addressable by policies.";
                };
                ips = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = "Stable IP addresses or CIDRs of this device (max 16; merged into one dashboard row).";
                };
              };
            }
          );
          default = [ ];
          description = ''
            Device registry for per-device attribution. DNS and HTTP tracking
            rows carry the device id so the dashboard can answer "which device
            queried it"; declaring devices also enables per-device pause and
            device-scoped temp-allows. Requires dnsblockd >= v0.9.3 (T309: a
            configured device's block-page Allow never unblocked it before).
            DHCP-lease discovery: GET /api/devices/candidates lists active
            leases not yet covered here.
          '';
        };

        users = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                name = mkOption {
                  type = types.str;
                  description = "Owner display name (max 64 chars, PII — redacted below METADATA_AND_DNS like device names).";
                };
                devices = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = "Device ids owned by this user (must resolve to declared devices; each device at most one owner).";
                };
              };
            }
          );
          default = [ ];
          description = "Static users: persons who own declared devices. Renders an owner chip next to devices in Top Clients / Device Activity.";
        };

        policies = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                name = mkOption {
                  # Upstream policy.ValidSlug: 1-64 chars of a-z, 0-9, dashes.
                  type = types.strMatching "[a-z0-9-]{1,64}";
                  description = "Unique policy name (lowercase slug).";
                };
                groups = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = "Device group tags the policy targets (each must be the group value of at least one declared device).";
                };
                devices = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = "Device ids the policy targets (must resolve to declared devices).";
                };
                allow = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = "Domains always allowed for the targets while the schedule is active (max 512, upstream cap).";
                };
                block = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = "Domains always blocked for the targets while the schedule is active (max 512, upstream cap).";
                };
                schedule = mkOption {
                  type = types.str;
                  default = "";
                  description = ''
                    Active window(s), comma-separated HH:MM-HH:MM
                    ("22:00-07:00,12:00-13:00"; max 16 windows, zero-padded
                    clock form). Empty = always active; outside the window
                    the policy is inert.
                  '';
                };
              };
            }
          );
          default = [ ];
          description = ''
            Per-device/group policies: scheduled allow/block lists layered
            over the global blocklists. Policies in config are enforced on
            their targets within the schedule (no separate enabled flag
            upstream — remove a policy to stop enforcing it). Tuning:
            GET /api/policies/shadow (Bearer token, same as the dashboard
            API) aggregates would-have-blocked verdicts on allowed queries
            per source; GET /api/policies/shadow/impact aggregates verdict
            deltas — measure coverage before/after tightening a policy.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.allowedNetworks != [ ];
            message = "services.dns-blocker.allowedNetworks must not be empty — an empty ACL makes dnsblockd an open resolver.";
          }
          {
            assertion = cfg.localZones != [ ] || cfg.localRecords == { };
            message = "services.dns-blocker.localZones must be set when localRecords has entries — without zone boundaries, unknown names in local zones leak upstream.";
          }
          {
            # Upstream NewHandler rejects filter domains under NXDOMAIN block
            # mode (ErrFilterNeedsAddressResponse): the scoped DNS lie needs an
            # address to answer with. Fail at eval instead of crash-looping
            # the sole LAN resolver at boot.
            assertion = cfg.proxyFilterDomains == [ ] || cfg.dnsBlockResponse == "zero_ip";
            message = "services.dns-blocker.proxyFilterDomains requires dnsBlockResponse \"zero_ip\" (upstream ErrFilterNeedsAddressResponse: a DNS lie needs an address).";
          }
          {
            assertion = !(cfg.dnsRateLimitPerSec > 0) || cfg.dnsRateLimitBurst > 0;
            message = "services.dns-blocker.dnsRateLimitBurst must be > 0 when dnsRateLimitPerSec is enabled.";
          }
          {
            assertion = !cfg.dnsTLSEnabled || cfg.dnsTLSPort != cfg.dnsDOHPort || !cfg.dnsDOHEnabled;
            message = "services.dns-blocker.dnsTLSPort and dnsDOHPort must differ to avoid bind conflict.";
          }
          {
            assertion = !cfg.dnsDOHEnabled || cfg.dnsDOHPort != cfg.blockTLSPort;
            message = "services.dns-blocker.dnsDOHPort must differ from blockTLSPort to avoid bind conflict.";
          }
          {
            # Upstream hard-caps (config load fails beyond them) — fail at
            # eval instead of at boot, where the sole DNS resolver would die.
            assertion =
              builtins.length cfg.devices <= 256 && builtins.all (d: builtins.length d.ips <= 16) cfg.devices;
            message = "services.dns-blocker.devices exceeds upstream caps (256 devices, 16 IPs each).";
          }
          {
            assertion = lib.unique (map (d: d.id) cfg.devices) == map (d: d.id) cfg.devices;
            message = "services.dns-blocker.devices has duplicate ids.";
          }
          {
            # Overlapping exact IPs/CIDRs across devices would race the
            # attribution walk; identical strings are always wrong, subnet
            # overlap is the config author's judgment.
            assertion =
              lib.unique (lib.concatMap (d: d.ips) cfg.devices) == lib.concatMap (d: d.ips) cfg.devices;
            message = "services.dns-blocker.devices has duplicate IPs across devices.";
          }
          {
            assertion =
              let
                declared = map (d: d.id) cfg.devices;
                dangling = lib.subtractLists declared (lib.concatMap (u: u.devices) cfg.users);
              in
              dangling == [ ];
            message = "services.dns-blocker.users references undeclared devices.";
          }
          {
            # Upstream: each device has at most one owner.
            assertion =
              lib.unique (lib.concatMap (u: u.devices) cfg.users) == lib.concatMap (u: u.devices) cfg.users;
            message = "services.dns-blocker.users assigns a device to more than one owner.";
          }
          {
            # Upstream policy caps (policy.MaxPolicies 64, MaxDomainsPerArc
            # 512, MaxWindows 16) — config load fails beyond them; fail at
            # eval instead of at boot, where the sole DNS resolver would die.
            assertion =
              builtins.length cfg.policies <= 64
              && builtins.all (
                p:
                builtins.length p.allow <= 512
                && builtins.length p.block <= 512
                && (p.schedule == "" || builtins.length (lib.splitString "," p.schedule) <= 16)
              ) cfg.policies;
            message = "services.dns-blocker.policies exceeds upstream caps (64 policies, 512 domains per allow/block list, 16 schedule windows).";
          }
          {
            # Upstream ErrDuplicateName.
            assertion = lib.unique (map (p: p.name) cfg.policies) == map (p: p.name) cfg.policies;
            message = "services.dns-blocker.policies has duplicate names.";
          }
          {
            # Upstream ErrNoTargets: a policy without devices or groups is
            # dead config (never applies to anyone).
            assertion = builtins.all (p: p.devices != [ ] || p.groups != [ ]) cfg.policies;
            message = "services.dns-blocker.policies: every policy must target at least one device or group.";
          }
          {
            assertion =
              let
                declared = map (d: d.id) cfg.devices;
                dangling = lib.subtractLists declared (lib.concatMap (p: p.devices) cfg.policies);
              in
              dangling == [ ];
            message = "services.dns-blocker.policies references undeclared devices.";
          }
          {
            assertion =
              let
                knownGroups = lib.filter (g: g != null) (map (d: d.group) cfg.devices);
                dangling = lib.subtractLists knownGroups (lib.concatMap (p: p.groups) cfg.policies);
              in
              dangling == [ ];
            message = "services.dns-blocker.policies references device groups that no declared device carries.";
          }
          {
            # Upstream ParseWindows accepts zero-padded HH:MM-HH:MM windows
            # (Atoi also takes unpadded forms; the wrapper pins the canonical
            # padded form so configs stay uniform).
            assertion = builtins.all (
              p:
              p.schedule == ""
              || builtins.all (
                w: builtins.match "([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]" w != null
              ) (lib.splitString "," p.schedule)
            ) cfg.policies;
            message = "services.dns-blocker.policies schedule must be comma-separated zero-padded HH:MM-HH:MM windows (e.g. \"22:00-07:00\").";
          }
          {
            # Upstream errInvalidBlocklistURL applies to dns_blocklist_urls;
            # trial URLs ride the SAME fetcher — reject unloadable entries
            # at eval instead of at first reload.
            assertion = builtins.all (u: builtins.match "https?://[^/]+.*" u != null) cfg.blocklistTrialUrls;
            message = "services.dns-blocker.blocklistTrialUrls entries must be http(s) URLs with a host (the upstream fetcher speaks nothing else).";
          }
          {
            # Upstream errInvalidBlocklistCacheDir.
            assertion = cfg.blocklistCacheDir == "" || lib.hasPrefix "/" cfg.blocklistCacheDir;
            message = "services.dns-blocker.blocklistCacheDir must be an absolute path (a relative path would silently land outside persisted storage).";
          }
          {
            # Upstream ecs.go masks client IPs to the prefix length; a
            # prefix past the address family's bit length is nonsense
            # config (ipv4BitLength 32 / ipv6BitLength 128). No
            # config-level validation upstream — fail at eval instead.
            assertion =
              (cfg.dnsEcsIpv4PrefixLen == 0 || (cfg.dnsEcsIpv4PrefixLen >= 1 && cfg.dnsEcsIpv4PrefixLen <= 32))
              && (
                cfg.dnsEcsIpv6PrefixLen == 0 || (cfg.dnsEcsIpv6PrefixLen >= 1 && cfg.dnsEcsIpv6PrefixLen <= 128)
              );
            message = "services.dns-blocker ECS prefix lengths must be 0 (upstream default) or within the address family (IPv4 1-32, IPv6 1-128).";
          }
          {
            # Upstream errH3RequiresTLSPort (validation.go
            # tls_h3_requires_tls_port): HTTP/3 terminates QUIC on the same
            # port number as the HTTPS block page listener — h3 without a
            # TLS port is rejected at startup, so fail at eval instead.
            assertion = !cfg.tlsH3Enabled || cfg.blockTLSPort > 0;
            message = "services.dns-blocker.tlsH3Enabled requires blockTLSPort > 0 (upstream: HTTP/3 terminates QUIC on the same port number as the HTTPS block page listener).";
          }
        ];

        systemd = {
          services = {
            # Bridges the Pocket ID client secret into an env file dnsblockd
            # can consume (LoadCredential pattern — mirrors browser-history).
            # When the secret is missing the unit exits 0 WITHOUT writing the
            # env file, so SSO stays off instead of crash-looping the DNS
            # path.
            dnsblockd-oidc-secret =
              lib.mkIf (cfg.oidcIssuerURL != "" && (config.services.pocket-id-config.provision.enable or false))
                {
                  description = "dnsblockd — Pocket ID OIDC client secret provisioning";
                  after = [ "pocket-id-provision.service" ];
                  wants = [ "pocket-id-provision.service" ];
                  before = [ "dnsblockd.service" ];
                  wantedBy = [ "dnsblockd.service" ];
                  startLimitBurst = 5;
                  startLimitIntervalSec = 300;

                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    StateDirectory = "dnsblockd-oidc";
                    LoadCredential = [
                      "pocket-id-secret:${
                        config.services.pocket-id.dataDir or "/var/lib/pocket-id"
                      }/client-secrets/${cfg.oidcClientID}"
                    ];
                  };

                  path = [ pkgs.coreutils ];

                  script = ''
                    SECRET_FILE="$CREDENTIALS_DIRECTORY/pocket-id-secret"

                    if [ ! -s "$SECRET_FILE" ]; then
                      echo "dnsblockd-oidc-secret: Pocket ID secret not found — removing env file so SSO stays off"
                      rm -f "${oidcEnvFile}"
                      exit 0
                    fi

                    install -d -m 0755 "$(dirname "${oidcEnvFile}")"
                    echo "DNSBLOCKD_OIDC_CLIENT_SECRET=$(cat "$SECRET_FILE")" > "${oidcEnvFile}"
                    chmod 600 "${oidcEnvFile}"
                    echo "dnsblockd-oidc-secret: Pocket ID client secret written"
                  '';
                };

            dnsblockd-attach-ip = {
              description = "Attach dnsblockd block IP to ${cfg.blockInterface}";
              wantedBy = [ "multi-user.target" ];
              after = [
                "sys-subsystem-net-devices-${cfg.blockInterface}.device"
                "network-online.target"
              ];
              wants = [
                "sys-subsystem-net-devices-${cfg.blockInterface}.device"
                "network-online.target"
              ];
              inherit onFailure;
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              restartTriggers = [ (lib.getExe attachIPScript) ];
              serviceConfig = lib.mkMerge [
                {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = lib.getExe attachIPScript;
                }
                (harden {
                  ProtectHome = false;
                  CapabilityBoundingSet = "CAP_NET_ADMIN";
                  NoNewPrivileges = false;
                })
                (serviceOneshotDefaults { })
              ];
            };

            dnsblockd = {
              description = "DNS Block Page Server + Embedded Resolver";
              after = [
                "dnsblockd-attach-ip.service"
                "sops-nix.service"
              ]
              ++ lib.optionals (cfg.oidcIssuerURL != "") [ "dnsblockd-oidc-secret.service" ];
              wants = [
                "dnsblockd-attach-ip.service"
                "sops-nix.service"
              ]
              ++ lib.optionals (cfg.oidcIssuerURL != "") [ "dnsblockd-oidc-secret.service" ];
              wantedBy = [ "multi-user.target" ];
              inherit onFailure;
              restartTriggers = [
                dnsblockdConfigFile
                pkgs.dnsblockd
              ];
              unitConfig = {
                StartLimitBurst = 10;
                StartLimitIntervalSec = 120;
              };

              serviceConfig =
                let
                  initScript = pkgs.writeShellApplication {
                    name = "dnsblockd-init";
                    runtimeInputs = [ pkgs.coreutils ];
                    text = ''
                      install -d /var/lib/dnsblockd
                    '';
                  };
                  secretCheck = pkgs.writeShellApplication {
                    name = "dnsblockd-wait-secrets";
                    runtimeInputs = [ pkgs.coreutils ];
                    text = ''
                      for _ in $(seq 1 30); do
                        if [ -s "${caCert}" ] && [ -s "${caKey}" ]; then
                          exit 0
                        fi
                        sleep 1
                      done
                      echo "ERROR: sops secrets not available after 30s: ${caCert}, ${caKey}" >&2
                      exit 1
                    '';
                  };
                in
                lib.mkMerge [
                  (harden {
                    MemoryMax = "4G";
                    ProtectSystem = "strict";
                    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
                    AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
                  })
                  (serviceDefaults { RestartSec = "3s"; })
                  {
                    Type = "simple";
                    # OOM-kill immunity for the sole DNS resolver. dnsblockd was
                    # oomd-killed 730x/day at the old 50%/20s threshold (2026-08-04
                    # root cause); the 60%/30s threshold + MemoryMax=4G +
                    # GOMEMLIMIT below tamed it, but under /system.slice PSI
                    # >60%/30s oomd still ranks it by memory.current. Killing DNS
                    # cascades: local *.home.lan zones die, deploys block on
                    # cache.home.lan resolution (2026-09-02 class), and
                    # sev1/Discord alerting goes blind with the resolver down.
                    #   ManagedOOMPreference = "omit": oomd NEVER selects this
                    #     unit as a kill candidate (nix-daemon + PMA precedent;
                    #     the directive DEFAULT "auto" means oomd WILL kill).
                    #   OOMScoreAdjust = -1000: the kernel global-OOM killer
                    #     picks it last (nix-daemon doctrine). A kernel kill
                    #     costs ~2min of DNS while the 3.9M-entry blocklist
                    #     reloads, and a kill loop hits StartLimitBurst →
                    #     start-limit-hit → dead sole resolver.
                    ManagedOOMPreference = "omit";
                    OOMScoreAdjust = -1000;
                    # GOMEMLIMIT forces Go GC to run aggressively before MemoryMax.
                    # dnsblockd's METRICS cardinality was fixed upstream (2026-08):
                    # the unbounded dns_domain/http_path/proxy_domain labels were
                    # dropped and domains bucketed into domain_category; a
                    # regression test (internal/server/cardinality_regression_test.go)
                    # guards it. Span attributes are exempt (never create metric
                    # series). The SQLite tracking-write pressure remains: without
                    # GOMEMLIMIT, Go's default GOGC=100 doesn't trigger GC until
                    # heap doubles (~1.2G from 600M base), but MemoryMax kills first.
                    Environment = [
                      "GOMEMLIMIT=3GiB"
                      # Full goroutine dump on SIGQUIT (kill -QUIT) — the
                      # 2026-08-27 stats-API wedge healed before a dump could
                      # be taken; "all" ensures every goroutine's stack lands
                      # in the journal when the runbook fires it (default
                      # GOTRACEBACK=single shows only the signal-handling
                      # goroutine, which says nothing about a mutex deadlock).
                      "GOTRACEBACK=all"
                    ] ++ lib.optionals (cfg.proxyInjectScriptURL != null) [
                      # proxy_inject_script_url rides the env, never the YAML:
                      # the config file is world-readable in the Nix store and
                      # the URL can carry a sensitive host:port (same rule as
                      # upstream's auth_token). Koanf's flat env mapping turns
                      # DNSBLOCKD_PROXY_INJECT_SCRIPT_URL into the
                      # proxy_inject_script_url config key.
                      "DNSBLOCKD_PROXY_INJECT_SCRIPT_URL=${cfg.proxyInjectScriptURL}"
                    ];
                    EnvironmentFile = lib.optionals (cfg.oidcIssuerURL != "") [ oidcEnvFile ];
                    ExecStartPre = [
                      "+-${lib.getExe initScript}"
                      "${lib.getExe secretCheck}"
                    ];
                    TimeoutStartSec = "3min";
                    ExecStart = "${lib.getExe pkgs.dnsblockd} serve -c ${dnsblockdConfigFile}";
                    StateDirectory = "dnsblockd";
                    WorkingDirectory = "/var/lib/dnsblockd";
                    RestrictAddressFamilies = [
                      "AF_INET"
                      "AF_INET6"
                      "AF_NETLINK"
                    ];
                  }
                ];
            };
          };

          tmpfiles.rules = [
            (mkStateDir "/var/lib/dnsblockd" "0755" "root" "root")
          ];
        };

        # Service-integration registry entry: unit-state monitoring + the Pocket
        # ID OIDC client (native OIDC in dnsblockd itself —
        # authorization-code + PKCE S256). The dnsblock/dnsblockd vHosts
        # stay hand-written in caddy.nix (redirect pair), and the stats
        # API health check stays in gatus-config.nix's DNS section.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          dnsblockd = {
            inherit (cfg) enable;
            vHost.layer = "none";
            monitored = true;
            oidc = {
              name = "dnsblockd";
              clientId = "dnsblockd";
              launchURL = "https://dnsblock.${config.networking.domain}";
              callbackURLs = [ "https://dnsblock.${config.networking.domain}/auth/oidc/callback" ];
              pkceEnabled = true;
            };
          };
        };
      };
    };
}
