# DNS blocker: dnsblockd (embedded recursive resolver) + blocklists + block page + stats API
#
# dnsblockd is the sole DNS resolver on :53 with an embedded recursive resolver
# (IANA root hints + DNSSEC), local zones, LAN ACLs, DoT/DoH forwarding, and
# blocklist matching.
# The block-page HTTP server runs on the block IP (:80/:443).
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
        ]) fetchedBlocklists
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
        if cfg.tempAllowAll then [ ] else map (bl: toString "${bl.file}/${bl.name}") fetchedBlocklists;

      # Sops secret paths and generated YAML config — in outer scope so that
      # restartTriggers can reference the config file, forcing a service restart
      # whenever the binary, config, or blocklists change.
      # Without restartTriggers, switch-to-configuration may not detect unit-file
      # changes on certain deploys (observed during the unbound→dnsblockd migration:
      # the running process kept old config while unbound was stopped, leaving :53 unbound).
      caCert = config.sops.secrets.dnsblockd_ca_cert.path;
      caKey = config.sops.secrets.dnsblockd_ca_key.path;
      dnsblockdConfigFile = pkgs.writeText "dnsblockd-config.yaml" (
        lib.generators.toYAML { } (
          {
            listen_addr = cfg.blockIP;
            port = cfg.blockPort;
            tls_port = cfg.blockTLSPort;
            stats_addr = "127.0.0.1";
            stats_port = cfg.statsPort;
            ca_cert_file = "${caCert}";
            ca_key_file = "${caKey}";
            blocklist_mapping_file = "${processedBlocklist}/mapping.json";
            temp_allowlist_path = "/var/lib/dnsblockd/temp-allowlist";
            tracking_mode = "METADATA_ONLY";
            tracking_db_path = "/var/lib/dnsblockd/tracking.db";

            # ── Reverse proxy for temp-allowed domains ──
            proxy_enabled = cfg.proxyEnabled;
            proxy_connect_timeout = cfg.proxyConnectTimeout;

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
            dns_reload_interval = cfg.dnsReloadInterval;
            dns_block_ttl = cfg.dnsBlockTTL;
            dns_resolve_timeout = cfg.dnsResolveTimeout;
            dns_restart_backoff = cfg.dnsRestartBackoff;
            dns_rate_limit_per_sec = cfg.dnsRateLimitPerSec;
            dns_rate_limit_burst = cfg.dnsRateLimitBurst;
            dns_rate_limit_max_clients = cfg.dnsRateLimitMaxClients;
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
          // lib.optionalAttrs (cfg.dnsDOHTrustedProxies != [ ]) {
            dns_doh_trusted_proxies = cfg.dnsDOHTrustedProxies;
          }
          // lib.optionalAttrs (cfg.proxyUpstreamDNS != [ ]) {
            proxy_upstream_dns = cfg.proxyUpstreamDNS;
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
        ];

        systemd = {
          services = {
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
              ];
              wants = [
                "dnsblockd-attach-ip.service"
                "sops-nix.service"
              ];
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
                    MemoryMax = "1G";
                    ProtectSystem = "strict";
                    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
                    AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
                  })
                  (serviceDefaults { RestartSec = "3s"; })
                  {
                    Type = "simple";
                    ExecStartPre = [
                      "+-${lib.getExe initScript}"
                      "${lib.getExe secretCheck}"
                    ];
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
      };
    };
}
