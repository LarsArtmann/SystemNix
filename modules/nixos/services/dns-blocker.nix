_: {
  flake.nixosModules.dns-blocker = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.dns-blocker;
    inherit (lib) mkEnableOption mkOption types;

    categoriesJSON = pkgs.writeText "dnsblockd-categories.json" (builtins.toJSON cfg.categories);

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
      pkgs.runCommand "dns-blocker-processed" {
        nativeBuildInputs = [pkgs.dnsblockd];
      } ''
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
        default = 9090;
        description = "Port for dnsblockd stats API (localhost only)";
      };

      blocklists = mkOption {
        type = types.listOf (types.submodule {
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
        });
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
            interface = ["0.0.0.0" "::0"];
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

            # DNS-over-QUIC (DoQ) — RFC 9250
            # DISABLED: unbound not compiled with ngtcp2; setting quic-port causes fatal warning
            # quic-port = cfg.doqPort;

            root-hints = "${pkgs.dns-root-data}/root.hints";

            local-zone =
              map (d: ''"${d}." transparent'') cfg.whitelist
              ++ map (d: ''"${d}." always_nxdomain'') cfg.extraDomains;
          };

          remote-control = {
            control-enable = true;
            control-interface = "/run/unbound/unbound.ctl";
          };
        };
      };

      networking.localCommands = ''
        ${pkgs.iproute2}/bin/ip addr add ${cfg.blockIP}/32 dev ${cfg.blockInterface} 2>/dev/null || true
      '';

      programs.firefox.policies = {
        DNSOverHTTPS = {
          Enabled = false;
          Locked = true;
        };
        Certificates = {
          Install = [config.sops.secrets.dnsblockd_ca_cert.path];
        };
        Preferences = {
          "browser.shell.checkDefaultBrowser" = {
            Value = false;
            Status = "locked";
          };
          "widget.disable-swipe-tracker" = {
            Value = true;
            Status = "locked";
          };
          "browser.gesture.swipe.left" = {
            Value = "";
            Status = "locked";
          };
          "browser.gesture.swipe.right" = {
            Value = "";
            Status = "locked";
          };
          "browser.gesture.swipe.up" = {
            Value = "";
            Status = "locked";
          };
          "browser.gesture.swipe.down" = {
            Value = "";
            Status = "locked";
          };
          "browser.autofocus" = {
            Value = false;
            Status = "locked";
          };
        };
      };

      systemd = {
        services.unbound.reloadIfChanged = true;

        tmpfiles.rules =
          [
            "d /var/lib/dnsblockd 0755 root root -"
          ]
          ++ lib.optional (!cfg.tempAllowAll) ''f /var/lib/dnsblockd/temp-allowlist.conf 0644 root root - # dnsblockd temp allowlist placeholder''
          ++ lib.optional cfg.tempAllowAll ''            f /var/lib/dnsblockd/temp-allowlist.conf 0644 root root - local-zone: "." transparent
          '';

        services.dnsblockd = {
          description = "DNS Block Page Server";
          after = ["network-online.target" "unbound.service" "sops-nix.service"];
          wants = ["network-online.target" "sops-nix.service" "unbound.service"];
          wantedBy = ["multi-user.target"];
          unitConfig = {
            StartLimitBurst = 5;
            StartLimitIntervalSec = 60;
          };

          serviceConfig = let
            initScript = pkgs.writeShellScript "dnsblockd-init" ''
              install -d /var/lib/dnsblockd
              ${
                if cfg.tempAllowAll
                then "printf 'local-zone: \".\" transparent\\n' > /var/lib/dnsblockd/temp-allowlist.conf"
                else "[ -f /var/lib/dnsblockd/temp-allowlist.conf ] || printf '# dnsblockd temp allowlist\\n' > /var/lib/dnsblockd/temp-allowlist.conf"
              }
            '';
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
            dnsblockdWrapper = pkgs.writeShellScript "dnsblockd-start" ''
              set -euo pipefail

              for i in $(${pkgs.coreutils}/bin/seq 1 60); do
                if [ -s "${caCert}" ] && [ -s "${caKey}" ]; then
                  break
                fi
                if [ "$i" -eq 60 ]; then
                  echo "ERROR: sops secrets not available after 60s" >&2
                  exit 1
                fi
                sleep 1
              done

              exec ${pkgs.dnsblockd}/bin/dnsblockd serve -c ${dnsblockdConfigFile}
            '';
          in {
            Type = "simple";
            ExecStartPre = "+-${initScript}";
            ExecStart = "${dnsblockdWrapper}";
            StateDirectory = "dnsblockd";
            Restart = "always";
            RestartSec = "3s";

            SupplementaryGroups = ["unbound"];
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_NETLINK"];
            AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
            CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];
          };
        };

        user.services.dnsblockd-cert-import = {
          description = "Import dnsblockd CA cert into NSS database";
          wantedBy = ["graphical-session.target"];
          after = ["sops-nix.service" "graphical-session.target"];
          partOf = ["graphical-session.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [pkgs.nss];
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
