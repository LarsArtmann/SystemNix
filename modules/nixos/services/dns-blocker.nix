# DNS blocker: Unbound + blocklists + dnsblockd block page + stats API
_: {
  flake.nixosModules.dns-blocker = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.dns-blocker;
    inherit (lib) mkEnableOption mkOption types;
    inherit
      (import ../../../lib/default.nix lib)
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
    fetchedBlocklists =
      map (bl: {
        inherit (bl) name;
        file = pkgs.fetchurl {
          inherit (bl) url;
          inherit (bl) hash;
          name = "${bl.name}-raw";
        };
      })
      cfg.blocklists;

    # Whitelist file
    whitelistFile = pkgs.writeText "dns-blocker-whitelist.txt" (
      lib.concatStringsSep "\n" cfg.whitelist
    );

    # Build processor arguments: blocklist-file name pairs
    processorArgs = lib.concatStringsSep " " (
      lib.concatMap (bl: [
        (toString bl.file)
        bl.name
      ])
      fetchedBlocklists
    );

    # Run processor at build time — dnsblockd process subcommand
    processedBlocklist =
      pkgs.runCommand "dns-blocker-processed"
      {
        nativeBuildInputs = [pkgs.dnsblockd];
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

    # Unbound include file: temp-allowlist BEFORE blocklist so transparent zones win
    unboundIncludeFile = pkgs.writeText "dns-blocker-unbound.conf" ''
      include: /var/lib/dnsblockd/temp-allowlist.conf
      include: ${processedBlocklist}/unbound.conf
    '';
  in {
    options.services.dns-blocker = {
      enable = mkEnableOption "DNS blocker with unbound + block page";

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
        default = [];
        description = "Blocklists to fetch (hosts format)";
      };

      whitelist = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Domains to never block (whitelist)";
      };

      extraDomains = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional domains to block (not in blocklists)";
      };

      enableDNSSEC = mkOption {
        type = types.bool;
        default = true;
        description = "Enable DNSSEC validation";
      };

      categories = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Domain suffix -> category for block page";
      };

      tempAllowAll = mkOption {
        type = types.bool;
        default = false;
        description = "Temporarily allow all DNS queries (disable blocking). Write 'local-zone: \".\" transparent' to temp-allowlist.conf";
      };

      doqPort = mkOption {
        type = types.port;
        default = 853;
        description = "Port for DNS-over-QUIC (DoQ) server. QUIC transport handles encryption natively — no TLS certificates needed.";
      };
    };

    config = lib.mkIf cfg.enable {
      services.unbound = {
        enable = true;
        resolveLocalQueries = true;
        enableRootTrustAnchor = cfg.enableDNSSEC;

        settings = {
          server = {
            interface = [
              "0.0.0.0"
              "::0"
            ];
            do-ip6 = false;
            access-control = [
              "127.0.0.0/8 allow"
              "::1/128 allow"
              "${config.networking.local.subnet} allow"
            ];

            num-threads = 2;
            msg-cache-size = "64m";
            rrset-cache-size = "128m";
            prefetch = true;
            prefetch-key = true;

            qname-minimisation = true;
            hide-identity = true;
            hide-version = true;

            harden-glue = true;
            harden-dnssec-stripped = cfg.enableDNSSEC;
            harden-below-nxdomain = true;
            harden-referral-path = true;

            include = toString unboundIncludeFile;

            local-zone =
              map (d: ''"${d}." transparent'') cfg.whitelist
              ++ map (d: ''"${d}." always_nxdomain'') cfg.extraDomains;
          };

          # DNS-over-TLS forwarding — works through VPN firewalls (port 853, not 53)
          forward-zone = [
            {
              name = ".";
              forward-tls-upstream = "yes";
              forward-addr = [
                "194.242.2.2@853#dns.mullvad.net"
                "9.9.9.9@853#dns.quad9.net"
              ];
            }
          ];

          remote-control = {
            control-enable = true;
            control-interface = "/run/unbound/unbound.ctl";
          };
        };
      };

      programs.firefox.policies = {
        DNSOverHTTPS = {
          Enabled = false;
          Locked = true;
        };
        Certificates = {
          Install = [config.sops.secrets.dnsblockd_ca_cert.path];
        };
      };

      systemd = {
        services = {
          unbound = {
            reloadIfChanged = true;

            # Skip unbound-anchor network fetch on every boot — certs are cached in
            # /var/lib/unbound/ and root key updates happen via RFC 5011 auto-trust.
            # Saves ~4s per boot.
            preStart = lib.mkForce ''
              ${config.services.unbound.package}/bin/unbound-control-setup -d /var/lib/unbound
            '';
          };

          dnsblockd-attach-ip = {
            description = "Attach dnsblockd block IP to ${cfg.blockInterface}";
            wantedBy = ["multi-user.target"];
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
            serviceConfig =
              {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = lib.getExe attachIPScript;
              }
              // harden {
                ProtectHome = false;
                CapabilityBoundingSet = "CAP_NET_ADMIN";
                NoNewPrivileges = false;
              }
              // serviceOneshotDefaults {};
          };

          dnsblockd = {
            description = "DNS Block Page Server";
            after = [
              "dnsblockd-attach-ip.service"
              "unbound.service"
              "sops-nix.service"
            ];
            wants = [
              "dnsblockd-attach-ip.service"
              "sops-nix.service"
              "unbound.service"
            ];
            wantedBy = ["multi-user.target"];
            inherit onFailure;
            unitConfig = {
              StartLimitBurst = 10;
              StartLimitIntervalSec = 120;
            };

            serviceConfig = let
              initScript = pkgs.writeShellApplication {
                name = "dnsblockd-init";
                runtimeInputs = [pkgs.coreutils];
                text = ''
                  install -d /var/lib/dnsblockd
                  ${
                    if cfg.tempAllowAll
                    then ''printf 'local-zone: "." transparent\n' > /var/lib/dnsblockd/temp-allowlist.conf''
                    else "[ -f /var/lib/dnsblockd/temp-allowlist.conf ] || printf '# dnsblockd temp allowlist\\n' > /var/lib/dnsblockd/temp-allowlist.conf"
                  }
                '';
              };
              caCert = config.sops.secrets.dnsblockd_ca_cert.path;
              caKey = config.sops.secrets.dnsblockd_ca_key.path;
              dnsblockdConfigFile = pkgs.writeText "dnsblockd-config.yaml" (
                lib.generators.toYAML {} {
                  listen_addr = cfg.blockIP;
                  port = cfg.blockPort;
                  tls_port = cfg.blockTLSPort;
                  stats_addr = "127.0.0.1";
                  stats_port = cfg.statsPort;
                  ca_cert_file = "${caCert}";
                  ca_key_file = "${caKey}";
                  blocklist_mapping_file = "${processedBlocklist}/mapping.json";
                  unbound_control = "${config.services.unbound.package}/bin/unbound-control";
                  temp_allowlist_path = "/var/lib/dnsblockd/temp-allowlist";
                  tracking_mode = "METADATA_ONLY";
                  tracking_db_path = "/var/lib/dnsblockd/tracking.db";
                }
                + lib.optionalString (cfg.categories != {}) "\ncategories_file: ${categoriesJSON}"
              );
              dnsblockdWrapper = pkgs.writeShellApplication {
                name = "dnsblockd-start";
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.dnsblockd
                ];
                text = ''
                  for i in $(seq 1 60); do
                    if [ -s "${caCert}" ] && [ -s "${caKey}" ]; then
                      break
                    fi
                    if [ "$i" -eq 60 ]; then
                      echo "ERROR: sops secrets not available after 60s" >&2
                      exit 1
                    fi
                    sleep 1
                  done

                  exec dnsblockd serve -c ${dnsblockdConfigFile}
                '';
              };
            in
              harden {
                MemoryMax = "1G";
                ProtectSystem = "strict";
                CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];
                AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
              }
              // serviceDefaults {RestartSec = "3s";}
              // {
                Type = "simple";
                ExecStartPre = "+-${lib.getExe initScript}";
                ExecStart = "${lib.getExe dnsblockdWrapper}";
                StateDirectory = "dnsblockd";
                WorkingDirectory = "/var/lib/dnsblockd";
                SupplementaryGroups = ["unbound"];
                RestrictAddressFamilies = [
                  "AF_INET"
                  "AF_INET6"
                  "AF_NETLINK"
                ];
              };
          };
        };

        tmpfiles.rules =
          [
            (mkStateDir "/var/lib/dnsblockd" "0755" "root" "root")
          ]
          ++ lib.optional (!cfg.tempAllowAll) "f /var/lib/dnsblockd/temp-allowlist.conf 0644 root root - # dnsblockd temp allowlist placeholder"
          ++ lib.optional cfg.tempAllowAll ''
            f /var/lib/dnsblockd/temp-allowlist.conf 0644 root root - local-zone: "." transparent
          '';

        user.services.dnsblockd-cert-import = {
          description = "Import dnsblockd CA cert into NSS database";
          wantedBy = ["graphical-session.target"];
          after = [
            "sops-nix.service"
            "graphical-session.target"
          ];
          partOf = ["graphical-session.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [
            pkgs.nss.tools
            pkgs.coreutils
          ];
          script = ''
            CA_CERT="${config.sops.secrets.dnsblockd_ca_cert.path}"
            while [ ! -s "$CA_CERT" ]; do sleep 1; done
            mkdir -p $HOME/.pki/nssdb
            certutil -d sql:$HOME/.pki/nssdb -N --empty-password 2>/dev/null || true
            certutil -d sql:$HOME/.pki/nssdb -D -n dnsblockd-ca 2>/dev/null || true
            certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n dnsblockd-ca -i "$CA_CERT"
          '';
        };
      };
    };
  };
}
