# Runbook: docs/services/crowdsec.md
# CrowdSec security engine — agent + LAPI on the pinned nixpkgs module
# (services.crowdsec, crowdsec 1.8.1). Stage 1 of the staged adoption
# (docs/planning/2026-10-14_20-25_crowdsec-nixos-study.md): detection +
# decisions + metrics + monitoring; stage 2 (geometrikks bouncer identity)
# is DECLARATIVE here since 2026-10-16 (crowdsec-bouncer-register, below);
# stage 3 (firewall-bouncer ENFORCEMENT) is still NOT enabled (banning is
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
#   - /var/log/caddy is 0750 caddy:caddy with 0600 files. CORRECTION
#     (2026-10-16 live verification): the rendered unit carries
#     PrivateUsers=true, and capabilities held inside a user namespace are
#     INERT for host inodes — the ambient CAP_DAC_READ_SEARCH below grants
#     nothing there (file acquisition logged "No matching files for
#     pattern /var/log/caddy/*.log", zero file-source hits in /metrics).
#     The geometrikks 2026-10-07 lesson does not transfer: that unit has
#     no PrivateUsers, so its ambient cap genuinely works. Fix (landed
#     in-tree 2026-10-16, verify-pending deploy): crowdsec member of the
#     caddy group — systemd maps auxiliary gids through the userns and
#     the DAC group check needs no capability. The ambient cap below is
#     KEPT until the group fix is proven live in /metrics (drop candidate
#     then).
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
        harden
        serviceOneshotDefaults
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

      # PR #1943 patch-apply (2026-10-16, owner ask "patch-apply our #1943 PR
      # via nix"): the hub's sshd-success-logs parser still filters
      # `program == 'sshd'`, so OpenSSH >= 9.8 "sshd-session" Accepted lines
      # never parse into auth_success events (runbook acquis CAVEAT a).
      # Until the PR merges upstream and ships via a hub update, pin the
      # PR's patched parser (fork branch head 99985ff6, byte-verified against
      # the local hubtest-green clone) and overwrite the hub item's install
      # symlink with it (tmpfiles rule below). The content mismatch marks the
      # item TAINTED, and cscli never overwrites tainted items on
      # install/upgrade without --force (pkg/cwhub sync.go setVersionState —
      # source-verified v1.8.1), so the override survives the unconditional
      # `hub update` + `collections install` at every agent start, and every
      # activation re-asserts the L+ link. REMOVE this entry once PR #1943
      # merges — the next cscli install then restores the hub file.
      pr1943Parser = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/LarsArtmann/hub/99985ff655a62dbb5b174441ae2295f19d02b2be/parsers/s01-parse/crowdsecurity/sshd-success-logs.yaml";
        hash = "sha256-DDx0NhuWLhz1a6FrmmtW0YlUgAFiJkBxliwNjkOb3gQ=";
      };

      # Group-read re-assert for caddy access logs (crowdsec acquis tails).
      # caddy's mode 0640 applies at CREATE only — open(2) never re-modes
      # existing files, so pre-override 0600 files stay unreadable to the
      # tails until re-moded. Shared by the 5-min timer and crowdsec's
      # +-privileged ExecStartPre (chmod needs file owner or root; crowdsec
      # is neither on caddy:caddy files). ExecStart must interpolate the
      # bin/ EXECUTABLE — the bare derivation is a directory (203/EXEC,
      # live 2026-10-16).
      caddyLogsGroupRead = pkgs.writeShellApplication {
        name = "caddy-logs-group-read";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          chmod g+r /var/log/caddy/*.log 2>/dev/null || true
        '';
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

      # Stage-2 declarative bouncer registration (2026-10-16, owner ask
      # "make it nix managed"): the geometrikks bouncer key lives in sops
      # (geometrikks_crowdsec_bouncer_api_key) and this converger makes the
      # LAPI DB match it on every boot — delete+add so the stored hash ALWAYS
      # equals the sops value (rotation-safe; an identical-key re-register
      # keeps live bouncer sessions valid since only the hash is stored).
      # No human ever sees the key: replaces the old print-once owner flow.
      # Flags verified against cmd/crowdsec-cli/clibouncer/{add,delete}.go
      # v1.8.1; add echoes the key to stdout EVEN WITH --key, hence the
      # redirect. Graceful-skip while the sops secret does not exist yet —
      # the unit converges silently once the owner-facing step is done.
      bouncerRegister = pkgs.writeShellApplication {
        name = "crowdsec-bouncer-register";
        runtimeInputs = [ ];
        text = ''
          if [ -z "''${CROWDSEC_BOUNCER_API_KEY:-}" ]; then
            echo "crowdsec-bouncer-register: no bouncer key rendered (sops secret not created yet) — skipping; converges when it exists" >&2
            exit 0
          fi
          ${lib.getExe' config.services.crowdsec.package "cscli"} \
            -c ${repairConfig} bouncers delete geometrikks --ignore-missing
          ${lib.getExe' config.services.crowdsec.package "cscli"} \
            -c ${repairConfig} bouncers add geometrikks --key "$CROWDSEC_BOUNCER_API_KEY" > /dev/null
          echo "crowdsec-bouncer-register: bouncer 'geometrikks' converged from sops"
        '';
      };

      # Stage-1 counts collector (2026-10-16, wave T14.3): the :6061 metrics
      # surface has NO decision/alert-count gauges (probed live — only LAPI
      # request counters), so SigNoz and the weekly alert-review cadence
      # cannot see active-ban pressure. cscli (as the crowdsec user, same
      # repairConfig as the register unit) is the sanctioned reader; both
      # lists are BOUNDED (cscli page limits — 50 alerts default) and
      # saturation is itself the alarm. Fail-closed per the textfile
      # doctrine: scrape_errors 1, value metrics held back, timeout inside
      # the script AND on the unit.
      crowdsecCounts = pkgs.writeShellApplication {
        name = "crowdsec-counts-collector";
        runtimeInputs = [ pkgs.jq ];
        text = ''
          OUT="/var/lib/prometheus-node-exporter/textfile_collectors/crowdsec-counts.prom"
          TMP="$(mktemp "$OUT.XXXXXX")"
          trap 'rm -f "$TMP"' EXIT
          errors=0
          decisions=$(${lib.getExe' config.services.crowdsec.package "cscli"} -c ${repairConfig} decisions list -o json 2>/dev/null | jq 'length') || errors=1
          alerts=$(${lib.getExe' config.services.crowdsec.package "cscli"} -c ${repairConfig} alerts list --since 24h -o json 2>/dev/null | jq 'length') || errors=1
          bouncer=$(${lib.getExe' config.services.crowdsec.package "cscli"} -c ${repairConfig} bouncers list -o json 2>/dev/null | jq '[.[] | select(.name == "geometrikks" and .revoked == false)] | length') || errors=1
          if [ "$errors" -eq 1 ] || [ -z "''${decisions:-}" ] || [ -z "''${alerts:-}" ] || [ -z "''${bouncer:-}" ]; then
            echo "crowdsec_collector_scrape_errors 1" > "$TMP"
          else
            {
              echo "crowdsec_decisions_active $decisions"
              echo "crowdsec_alerts_24h $alerts"
              echo "crowdsec_bouncer_geometrikks_registered $bouncer"
              echo "crowdsec_collector_scrape_errors 0"
            } > "$TMP"
          fi
          # mktemp creates 0600; node-exporter (its own user, live-verified
          # 2026-10-16) must READ the prom — every sibling collector ships
          # 0644 (the first live run shipped 0600 and exported NOTHING).
          chmod 0644 "$TMP"
          mv "$TMP" "$OUT"
        '';
      };

      # The bouncer key is declared by the geometrikks module's sops block
      # (mkIf geometrikks.enable) — eval-guard the whole registration on
      # option existence (VM-test co-import pattern) + enable state, so a
      # crowdsec-without-geometrikks eval never forces an undeclared secret.
      bouncerInScope =
        (options.services ? geometrikks)
        && ((config.services.geometrikks or { }).enable or false)
        && (options ? sops)
        && (options.sops ? templates);
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
            description = "CrowdSec engine: log-based threat detection + LAPI (stage-2 bouncer registration declarative; enforcement still pending)";
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

        # Caddy acquis fix (2026-10-16, verify-pending deploy): upstream
        # PrivateUsers=true wraps the engine in a user namespace where
        # capabilities do NOT reach host inodes, so the ambient
        # CAP_DAC_READ_SEARCH below cannot open /var/log/caddy (0750
        # caddy:caddy, 0600 files) and the file acquisition globs zero
        # files ("No matching files for pattern" at every start, stage-1
        # battery 2026-10-16). Supplementary-group membership is the
        # working fix: systemd maps auxiliary gids through the userns and
        # the DAC GROUP check needs no capability. Guarded on
        # caddy.enable — without Caddy the group is undeclared and the
        # acquis glob has nothing to read anyway. Upstream already
        # declares extraGroups ([ "systemd-journal" ],
        # nixos/modules/services/security/crowdsec.nix); list options
        # concatenate across modules, no override needed.
        users.users.${config.services.crowdsec.user}.extraGroups = lib.mkIf config.services.caddy.enable [
          "caddy"
        ];

        # PR #1943 patch-apply (see pr1943Parser above): re-assert the install
        # symlink at every engine start. switch-to-configuration does NOT run
        # systemd-tmpfiles (live-proven 2026-10-16: zero tmpfiles invocations
        # in the switch binary; the deploy script heals /run entries only),
        # so the first-boot-only L+ variant of this override never applied
        # post-deploy. mkAfter lands after the upstream setup's " "-reset
        # ExecStartPre list — setup's cscli install runs FIRST (a hub
        # version change may rewrite the link; ours wins), then the engine
        # loads the override at that same start (restartTriggers forces the
        # restart on content change). Runs as the unit's User=crowdsec — the
        # parsers dir is crowdsec-owned 0750, no capability needed. REMOVE
        # this + pr1943Parser when PR #1943 merges (cscli's install then
        # keeps the hub file).
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

        # Gate + repair CANNOT ride crowdsec.service's ExecStartPre: upstream
        # (nixos/modules/services/security/crowdsec.nix) opens that list with
        # the " " reset marker, so systemd DISCARDS every entry merged before
        # it — proven live 2026-10-15 04:46: the repair never ran, setup's
        # `machines add` hit "user already exist" (the pre-fix generation's
        # orphan row survived), the start failed, and the nh switch exited 4
        # BEFORE the system profile was updated. They run as a separate
        # late-applications (2026-10-26 ordering-cycle class fix; mkForce
        # over the nixpkgs crowdsec module's multi-user default): crowdsec
        # chains after crowdsec-prereq's DNS gate — a multi-user membership
        # would put the 180s DNS wait back on the boot critical chain (the
        # pre-fix After=multi-user edge on prereq armed the gen-954
        # deleted-start-job cycle instead).
        systemd.services.crowdsec.wantedBy = lib.mkForce [ "late-applications.target" ];

        # oneshot ordered before crowdsec.service instead: requires+before
        # keeps the gate FATAL (a failed DNS wait must hold crowdsec back or
        # hub update burns the restart budget) and a fresh oneshot re-runs on
        # every crowdsec restart.
        systemd.services.crowdsec-prereq = {
          description = "CrowdSec pre-start: DNS gate + orphan-machine repair";
          inherit (dnsGate) after wants;
          before = [ "crowdsec.service" ];
          serviceConfig = {
            Type = "oneshot";
            User = config.services.crowdsec.user;
            Group = config.services.crowdsec.group;
            ExecStart = [
              (lib.removePrefix "+" (builtins.head dnsGate.serviceConfig.ExecStartPre))
              (lib.getExe machineRepair)
            ];
            # 180s gate budget + margin (gate-timeout-audit floor is 4min).
            TimeoutStartSec = "4min";
          };
        };

        systemd.services.crowdsec = {
          # House convention (start-limit-audit wants them OUTSIDE serviceConfig).
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          requires = [ "crowdsec-prereq.service" ];

          # PR #1943 patch-apply (see pr1943Parser above): reload the parser
          # on deploy — parsers load at agent start only. The group-read
          # script rides along: a script change must restart the tails,
          # not just the timer.
          restartTriggers = [
            pr1943Parser
            caddyLogsGroupRead
          ];

          serviceConfig = lib.mkMerge [
            {
              # 180s gate budget + setup (hub update + installs) — the
              # manager default of 3min is too tight on a cold boot.
              TimeoutStartSec = "6min";

              # Parse memory ceiling. MemoryHigh ≥ 50% of MemoryMax
              # (memory-watermark-audit); 75% here.
              MemoryMax = "1G";
              MemoryHigh = "768M";

              # Read /var/log/caddy (0750 caddy:caddy dir, 0600 files).
              # Upstream bounding set is ["", "CAP_SYSLOG"] — list merge
              # appends ours. INERT under upstream PrivateUsers=true
              # (caps held inside a userns do not apply to host inodes —
              # live-proven 2026-10-16, zero files globbed); the working
              # access path is the caddy group membership above. KEPT
              # until that fix is proven live, then a drop candidate.
              AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
              CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
            }
            {
              # PR #1943 patch-apply (see pr1943Parser above): re-assert the
              # install symlink at every engine start. switch-to-configuration
              # does NOT run systemd-tmpfiles (live-proven 2026-10-16: zero
              # tmpfiles invocations in the switch binary; the deploy script
              # heals /run entries only), so a boot-only L+ rule never
              # applied post-deploy. mkAfter lands after the upstream setup's
              # " "-reset ExecStartPre list — setup's cscli install runs
              # FIRST (a hub version change may rewrite the link; ours wins),
              # then the engine loads the override at that same start
              # (restartTriggers above forces the restart on content change).
              # Runs as the unit's User=crowdsec — the parsers dir is
              # crowdsec-owned 0750, no capability needed. REMOVE this +
              # pr1943Parser when PR #1943 merges (cscli's install then
              # keeps the hub file).
              ExecStartPre = lib.mkAfter [
                # Absolute store path: the hardened unit's PATH has no
                # coreutils — bare `ln` failed EXEC at the 08:07 start
                # (live 2026-10-16).
                "${pkgs.coreutils}/bin/ln -sfn ${pr1943Parser} /etc/crowdsec/parsers/s01-parse/sshd-success-logs.yaml"
                # Re-mode pre-override 0600 caddy logs BEFORE the tails
                # open them — a failed tail setup DROPS the caddy source
                # for the process lifetime (no retry until restart,
                # live 2026-10-16). "+" = run as root: crowdsec is neither
                # owner nor privileged on caddy:caddy files.
                "+${caddyLogsGroupRead}/bin/caddy-logs-group-read"
              ];
            }
          ];
        };

        # Stage-2 declarative bouncer registration — sops-rendered key env
        # for the converger + the unit itself. Template restartUnits handle
        # rotation (content changes touch no secret file — geometrikks-env
        # precedent).
        sops.templates."crowdsec-bouncer-geometrikks-env" = lib.mkIf bouncerInScope {
          # root:root 0400 (geometrikks-env precedent + sops-key-audit):
          # systemd's manager itself reads EnvironmentFile and injects the
          # var — the crowdsec DynamicUser process never opens the file.
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = [ "crowdsec-bouncer-register.service" ];
          content = ''
            CROWDSEC_BOUNCER_API_KEY=${config.sops.placeholder.geometrikks_crowdsec_bouncer_api_key}
          '';
        };

        systemd.services.crowdsec-bouncer-register = lib.mkIf bouncerInScope {
          description = "CrowdSec declarative bouncer registration (geometrikks)";
          after = [ "crowdsec.service" ];
          wants = [ "crowdsec.service" ];
          # Converge before geo starts pulling (its poll would 401 meanwhile)
          before = [ "geometrikks.service" ];
          # late-applications (2026-10-26 ordering-cycle class fix): this
          # oneshot chains after crowdsec (a late member) — a multi-user
          # membership would drag crowdsec's DNS-gated start back into the
          # boot transaction and re-arm the deleted-start-job cycle.
          wantedBy = [ "late-applications.target" ];
          serviceConfig = {
            Type = "oneshot";
            # Same DB access pattern as crowdsec-prereq (sqlite via
            # repairConfig's db_config, live-proven by the repair leg).
            User = config.services.crowdsec.user;
            Group = config.services.crowdsec.group;
            EnvironmentFile = [ config.sops.templates."crowdsec-bouncer-geometrikks-env".path ];
            ExecStart = lib.getExe bouncerRegister;
            TimeoutStartSec = "2min";
          };
        };

        # Counts collector (see crowdsecCounts above): 5-min textfile feed
        # for SigNoz (scrape of node-exporter) + the weekly alert-review
        # cadence. Fail-closed; bounded lists (cscli page limits).
        systemd.services.crowdsec-counts = {
          description = "CrowdSec decisions/alerts counts (textfile collector)";
          after = [ "crowdsec.service" ];
          wants = [ "crowdsec.service" ];
          serviceConfig = lib.mkMerge [
            (harden {
              # Same-user rename into the 1777 textfile dir; no foreign
              # owner possible (this unit is the only writer).
              ReadWritePaths = [
                "/var/lib/prometheus-node-exporter/textfile_collectors"
              ];
            })
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              User = config.services.crowdsec.user;
              Group = config.services.crowdsec.group;
              ExecStart = lib.getExe crowdsecCounts;
              TimeoutStartSec = "1min";
            }
          ];
        };
        systemd.timers.crowdsec-counts = {
          description = "Collect CrowdSec decisions/alerts counts every 5 minutes";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "5min";
          };
        };

        # Caddy log group-read enforcement (companion to the caddy.nix vhost
        # logFormat `mode 0640` override, live root cause 2026-10-16): caddy
        # applies output-file option changes on RESTART only, and open(2)
        # never re-modes EXISTING files — until every live access-<host>.log
        # has rolled over under the new mode, the 0600 originals stay
        # unreadable to the caddy group and the acquis tail errors per file
        # ("Error setting up tail ... permission denied"). This 5-min timer
        # keeps the group-read bit asserted (idempotent chmod; no-op cost)
        # and closes roll-created 0600 windows within one tick.
        systemd.services.crowdsec-caddy-logs-readable = lib.mkIf config.services.caddy.enable {
          description = "Re-assert group-read on caddy access logs (crowdsec acquis)";
          after = [ "caddy.service" ];
          wants = [ "caddy.service" ];
          serviceConfig = lib.mkMerge [
            (harden { })
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              ReadWritePaths = [ "/var/log/caddy" ];
              ExecStart = "${caddyLogsGroupRead}/bin/caddy-logs-group-read";
              TimeoutStartSec = "1min";
            }
          ];
        };
        systemd.timers.crowdsec-caddy-logs-readable = lib.mkIf config.services.caddy.enable {
          description = "Re-assert caddy log group-read every 5 minutes";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "5min";
          };
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
                # Health leg (monitoring.md: liveness alone gives false
                # greens): the body must carry a real cs_ counter, not just
                # any HTTP 200. cs_parser_hits_total is live-verified on the
                # :6061 surface (2026-10-16 probe).
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*cs_parser_hits_total*)"
                ];
                alert = "CrowdSec metrics down — engine may be dead: systemctl status crowdsec, journalctl -u crowdsec";
              }
            ];
          };
        };
      };
    };
}
