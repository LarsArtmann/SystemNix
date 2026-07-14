# DNS blocker: dnsblockd (embedded sdns resolver) + blocklists + block page + stats API
#
# dnsblockd is the sole DNS resolver on :53 with an embedded recursive resolver
# (sdns), DNSSEC, local zones, LAN ACLs, DoT forwarding, and blocklist matching.
# The block-page HTTP server runs on the block IP (:80/:443).
#
# Blocklist files are fetched at eval time (pkgs.fetchurl) and passed directly
# to dnsblockd via the dns_blocklists config key — dnsblockd parses them natively
# at startup and hot-reloads them on interval. The dnsblockd process subcommand
# still runs at build time to generate mapping.json (domain → source → category)
# used by the HTTP block page for category display.
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
      fetchedBlocklists = map (bl: {
        inherit (bl) name;
        file = pkgs.fetchurl {
          inherit (bl) url;
          inherit (bl) hash;
          name = "${bl.name}-raw";
        };
      }) cfg.blocklists;

      # Whitelist file (used by dnsblockd process for mapping.json generation)
      whitelistFile = pkgs.writeText "dns-blocker-whitelist.txt" (lib.concatLines cfg.whitelist);

      # Build processor arguments: blocklist-file name pairs
      processorArgs = lib.concatStringsSep " " (
        lib.concatMap (bl: [
          (toString bl.file)
          bl.name
        ]) fetchedBlocklists
      );

      # Run processor at build time to generate mapping.json (domain → source → category).
      # The unbound.conf output is no longer used but the subcommand requires the arg.
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
          '';

      # Blocklist file paths for dnsblockd's native DNS blocklist loader.
      # When tempAllowAll is true, pass an empty list so nothing is blocked.
      blocklistPaths = if cfg.tempAllowAll then [ ] else map (bl: toString bl.file) fetchedBlocklists;

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

            # ── Embedded DNS resolver ──
            dns_enabled = true;
            dns_listen_addr = "0.0.0.0";
            dns_port = 53;
            dns_block_ip = cfg.blockIP;
            dns_block_response = "zero_ip";
            dns_blocklists = blocklistPaths;
            dns_dnssec_enabled = cfg.enableDNSSEC;
            dns_ipv6_enabled = cfg.dnsIPv6Enabled;
            dns_reload_interval = cfg.dnsReloadInterval;
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

        # ── DNS resolver options (embedded sdns) ──

        enableDNSSEC = mkOption {
          type = types.bool;
          default = true;
          description = "Enable DNSSEC validation in the embedded resolver";
        };

        dnsForwarders = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Upstream DNS forwarders (sdns format).
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
