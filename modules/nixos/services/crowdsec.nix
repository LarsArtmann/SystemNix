# Runbook: docs/services/crowdsec.md
# CrowdSec security engine — agent + LAPI on the pinned nixpkgs module
# (services.crowdsec, crowdsec 1.8.1). Stage 1 of the staged adoption
# (docs/planning/2026-10-14_20-25_crowdsec-nixos-study.md): detection +
# decisions + metrics + monitoring, NO bouncer/enforcement yet (the
# firewall bouncer is stage 3, after a week of alert review — banning is
# deferred because Caddy acquisition sees LAN clients).
#
# The upstream module owns crowdsec.service's unit text wholesale
# (hardening, ExecStartPre setup incl. the UNCONDITIONAL `cscli hub update`
# — nixpkgs #520206, network+DNS needed at every start). This file only
# layers SystemNix specifics onto it:
#   - ports: LAPI 8082 (8080 is SigNoz's), metrics 6061 (upstream default
#     6060 is taken by an unidentified Go pprof listener on *:6060,
#     live-probed 2026-10-14 — see ports.nix comment)
#   - acquisitions: sshd via journald + Caddy access logs (glob — covers
#     access.log AND per-vhost access-<host>.log)
#   - LAN whitelist: RFC1918/loopback never become alerts — household
#     clients must be un-bannable before the enforcement stage exists
#   - boot gate: mkDnsGate prepended (mkBefore) to the upstream
#     ExecStartPre list — dnsblockd needs ~2min at boot before DNS answers
#   - CAP_DAC_READ_SEARCH: /var/log/caddy is 0750 caddy:caddy with 0600
#     files (geometrikks 2026-10-07 lesson — group membership is NOT
#     enough, the ambient capability is what grants the read)
_: {
  flake.nixosModules.crowdsec =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        ports
        mkDnsGate
        ;

      # The gate hostname is the hub index host `cscli hub update` fetches
      # (runtime download — the nixpkgs package does NOT vendor the hub).
      # Resolution-ready is the gate's job; blocklist reachability of
      # www.crowdsec.net under HaGeZi is verified live post-deploy (ipify
      # precedent) — see the runbook.
      dnsGate = mkDnsGate {
        inherit pkgs;
        serviceName = "crowdsec";
        hostname = "www.crowdsec.net";
      };

      lapiCredentialsFile = "/var/lib/crowdsec/lapi.yaml";

      yaml = pkgs.formats.yaml { };
      # Same content as the upstream module's own configFile (generated from
      # the MERGED settings.general, defaults included) — cscli must see the
      # identical db_config/paths or the repair could touch the wrong DB.
      repairConfig = yaml.generate "crowdsec-repair-cscli.yaml" config.services.crowdsec.settings.general;

      # Upstream gap (live 2026-10-14): `machine add --auto` writes the DB row
      # FIRST and the credentials file SECOND — when the file write fails, the
      # DB keeps an orphan machine and every later start fails with
      # "user already exist" forever. If the credentials file is missing,
      # delete the orphan so setup's machine add can succeed. --ignore-missing
      # makes it a no-op on healthy boots (verified cmd/crowdsec-cli/climachine/
      # delete.go v1.8.1: no confirmation prompt, errors return nil).
      machineRepair = pkgs.writeShellApplication {
        name = "crowdsec-machine-repair";
        runtimeInputs = [ ];
        text = ''
          if [ ! -s ${lapiCredentialsFile} ]; then
            echo "crowdsec-machine-repair: credentials file missing — deleting orphan DB machine"
            ${lib.getExe' config.services.crowdsec.package "cscli"} \
              -c ${repairConfig} machines delete ${config.services.crowdsec.name} --ignore-missing || true
          fi
        '';
      };
    in
    {
      # Platform-truth catalog entry (ADR-008): unconditional inline-imports
      # module — nixosModules.catalog must be co-imported by any host/VM
      # importing this module (loud eval failure otherwise, by design).
      imports = [
        {
          services.catalog.crowdsec = {
            subdomain = null; # loopback service — no DNS presence, no vHost
            port = ports.crowdsec-lapi;
            owner = "lars";
            description = "CrowdSec engine: log-based threat detection + LAPI (bouncer stage pending)";
            healthPath = null;
          };
        }
      ];

      config = lib.mkIf config.services.crowdsec.enable {
        # Upstream tmpfiles list creates stateDir/hubDir/confDir but NOT
        # rootDir (/var/lib/crowdsec) itself — live 2026-10-14 it materialized
        # root:root 0755 (boot-time side effect) and the LAPI credentials
        # write EACCES'd. 'd' entries also re-chown existing dirs, healing
        # the already-created root-owned dir on the next activation.
        systemd.tmpfiles.settings."20-crowdsec-root" = {
          "/var/lib/crowdsec".d = {
            user = "crowdsec";
            group = "crowdsec";
            mode = "0750";
          };
        };

        # Stage 1 has NO bouncer: the bouncer module's register oneshot still
        # activates (its enable defaults to crowdsec.enable) and its
        # `StateDirectory = … crowdsec` lets systemd re-own /var/lib/crowdsec
        # to a DynamicUser — re-breaking the ownership the tmpfiles rule fixes.
        # Stage 3 re-enables it deliberately together with the bouncer.
        services.crowdsec-firewall-bouncer.registerBouncer.enable = false;

        services.crowdsec = {
          # LAPI on loopback (upstream default 8080 collides with SigNoz).
          settings.general = {
            api.server = {
              enable = true;
              listen_uri = "127.0.0.1:${toString ports.crowdsec-lapi}";
            };
            prometheus.listen_port = ports.crowdsec-metrics;
          };
          # REQUIRED once the LAPI server is enabled: the upstream setup
          # script interpolates this path (machine add --auto writes it) —
          # null is an eval-time failure. Lives under ReadWritePaths.
          settings.lapi.credentialsFile = lapiCredentialsFile;

          hub.collections = [
            "crowdsecurity/linux" # syslog + geoip + sshd scenarios
            "crowdsecurity/caddy" # caddy-logs parser + base-http-scenarios
          ];

          localConfig = {
            acquisitions = [
              {
                source = "journalctl";
                journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
                labels.type = "syslog";
              }
              {
                # Glob covers access.log AND every access-<host>.log the
                # caddy module derives per vHost. Caddy writes JSON lines;
                # runtime (non-request) lines simply fail to parse.
                filenames = [ "/var/log/caddy/*.log" ];
                labels.type = "caddy";
              }
            ];

            parsers.s02Enrich = [
              {
                name = "systemnix/lan-whitelist";
                description = "Household/LAN clients never become alerts (bouncer-stage safety — study §4)";
                whitelist = {
                  reason = "LAN client — house device, not an attacker";
                  ip = [
                    "127.0.0.1"
                    "::1"
                  ];
                  cidr = [
                    "192.168.0.0/16"
                    "10.0.0.0/8"
                    "172.16.0.0/12"
                  ];
                };
              }
            ];
          };
        };

        systemd.services.crowdsec = {
          # House convention (start-limit-audit wants them OUTSIDE serviceConfig).
          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          after = dnsGate.after;
          wants = dnsGate.wants;

          serviceConfig = lib.mkMerge [
            {
              # Prepend (mkBefore) so the DNS wait runs BEFORE the upstream
              # setup script's `cscli hub update` (which hard-fails without
              # DNS and would otherwise burn restarts through the ~2min
              # dnsblockd boot window), and the orphan-machine repair runs
              # BEFORE setup's `machine add --auto`.
              ExecStartPre = lib.mkBefore [
                dnsGate.serviceConfig.ExecStartPre
                (lib.getExe machineRepair)
              ];
              # 180s gate budget + setup (hub update + installs) — the
              # manager default of 3min is too tight on a cold boot.
              TimeoutStartSec = "6min";

              # Parse memory ceiling. MemoryHigh ≥ 50% of MemoryMax
              # (memory-watermark-audit); 75% here.
              MemoryMax = "1G";
              MemoryHigh = "768M";

              # Read /var/log/caddy (0750 caddy:caddy dir, 0600 files).
              # Upstream bounding set is ["", "CAP_SYSLOG"] — list merge
              # appends ours. Ambient is what GRANTS to the non-root
              # DynamicUser (geometrikks 2026-10-07 mail-relay lesson).
              AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
              CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
            }
          ];
        };

        # The options?-guard (NOT leaf mkIf) — VM tests must co-import
        # modules/nixos/services/integration.nix or this evaluates as the
        # empty attrset (flake-check-proven 2026-09-15 pattern).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          crowdsec = {
            subdomain = null; # loopback service — no vHost, no tile href
            port = ports.crowdsec-metrics;
            vHost.layer = "none";
            monitored = true;
            checks = [
              {
                name = "CrowdSec";
                group = "Security";
                path = "/metrics";
                interval = "1m";
                conditions = [ "[STATUS] == 200" ];
                alert = "CrowdSec metrics down — engine may be dead: systemctl status crowdsec, journalctl -u crowdsec";
              }
            ];
          };
        };
      };
    };
}
