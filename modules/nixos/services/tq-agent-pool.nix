# Runbook: docs/services/tq.md
# tq agent-pool — SystemNix deployment overlay for go-taskqueue
#
# Upstream module (inputs.go-taskqueue.nixosModules.default, imported in
# systems/evo-x2.nix next to bank-sync) declares services.tq-agent-pool
# options + the two systemd units (pool + read-only dashboard). SystemNix
# adds the house wiring:
#
#   - Runs as the PRIMARY USER (lars): headless crush agents write and
#     commit inside ~/projects and need that user's git identity, ssh
#     credentials and crush config (crushrc + sops-rendered provider keys)
#   - SQLite journal on the mirrored HDD pool (/mnt/pool/services/tq,
#     btrbk-pool snapshotted subvolume) — bank-sync/atticd placement class
#   - Dashboard (tq serve) binds 127.0.0.1:<ports.tq>; Caddy vHost
#     tq.<domain> (protectedVHost: LAN bypass + external forward-auth) is
#     the sole external entry point — the dashboard renders task payloads
#     and error tails, hence SSO, never Layer 0
#   - tq-bootstrap oneshot seeds the dogfood rails per repo (.tq-verify +
#     .crushrc managed block pinning model zai/glm-5.3-flash + autonomy,
#     committed locally, never pushed) — idempotent, runs at deploy
#   - Dead letters + budget exhaustion alert via the PapDashboard bridge
#     (TQ_PAP_API_KEY from the shared papdashboard sops key, dedicated
#     root-owned template so arbitrary agent payloads never see other
#     services' secrets)
#   - Pool knobs calibrated from the live round-9 dogfood window
#     (concurrency 2, budget 30/day, max-per-tick 3, review on)
#
# NO house harden{} on the pool unit — deliberate: upstream pins
# ProtectSystem=full and NO ProtectHome restriction because agents must
# write/commit inside $HOME repos; harden{}'s ProtectHome=read-only +
# ProtectSystem=strict would break every agent task at first write.
_: {
  flake.nixosModules.tq-agent-pool =
    {
      config,
      options,
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      cfg = config.services.tq-agent-pool;
      primaryUser = config.users.primaryUser or "lars";
      domain = config.networking.domain;
      # Same git-in-sandbox override as the `tq` entry in
      # lib/lars-packages.nix: the upstream checkPhase test suite shells
      # out to git (TestDoctorTreeGofmt, 2026-10-02) and the go-standard
      # sandbox ships none. Drop both when upstream's flake adds git to
      # nativeBuildInputs. vendorHash shim DROPPED 2026-10-07 (class comment
      # at lib/lars-packages.nix): upstream's own flake carries the hash.
      # doCheck gated off 2026-10-05: upstream's TestAgentsDocSizeGuard is red at
      # the locked rev (AGENTS.md 17102 B > the repo's own 15400 B budget);
      # drop the gate when upstream prunes/resets and the lock moves past.
      tqPkg =
        inputs.go-taskqueue.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
          (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.git ];
            doCheck = false;
          });
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        ports
        ioTier
        mkStateDir
        ;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      # Freeze-25 IO discipline (2026-10-14 task queue): the pool's 3 yolo
      # agents read ~864 GB across five zone-6 trip windows in one morning
      # (guard io.stat: +191/+128/+90/+272/+183 GB). Two legs:
      #   1. PSI entry gate — refuse the unit start while io-PSI some avg10
      #      >= 30% (the same band the migrate-_ entry gates use): starting
      #      a harvest/agent battery into a storm is the crash-loop
      #      amplifier class (freezes #20-#22, six post-crash re-fires).
      #      2026-10-17 (M10): the inline tq-pool-psi-gate script was folded
      #      into the SHARED pkgs.maintenance-entry-gate (dedup; same PSI
      #      band, trip-window deliberately 0 — enabling the 60-min guard
      #      trip window would need the startLimitBurst re-sized for the
      #      longer refusal tail).
      #   2. tq-pool-io-metrics (below) — cumulative cgroup read/write
      #      accounting + per-device io.stat + live agent count + newest
      #      task log, so the next "~864 GB" morning answers WHICH agent
      #      on WHICH disk in ONE Prom query.

      tqPoolIoMetrics = pkgs.writeShellApplication {
        name = "tq-pool-io-metrics";
        runtimeInputs = [
          pkgs.systemd
          pkgs.coreutils
          pkgs.gawk
          pkgs.findutils
          pkgs.gnugrep
        ];
        text = ''
          OUT="${textfileDir}/tq_agent_pool_io.prom"
          # Unique tmp per run (mktemp): the sticky 1777 textfile dir holds
          # stale foreign-owned leftovers (mail-relay 2026-09-02 class).
          mkdir -p "${textfileDir}"
          TMP="$(mktemp "${textfileDir}/tq_agent_pool_io.prom.XXXXXX")"
          chmod 644 "$TMP"
          trap 'rm -f "$TMP"' EXIT

          values=$(systemctl show tq-agent-pool.service -p IOReadBytes -p IOWriteBytes --value 2>/dev/null) || true
          # systemctl --value prints "[not set]" (or empty) when IOAccounting
          # is off or the unit has no cgroup yet — unguarded writes poison
          # the textfile and node_exporter rejects the whole file
          # (system-health nrestarts="[not" incident, 2026-09-20).
          read_bytes=$(printf '%s\n' "$values" | head -n 1)
          write_bytes=$(printf '%s\n' "$values" | tail -n 1)
          case "$read_bytes" in '''|*[!0-9]*) read_bytes=0 ;; esac
          case "$write_bytes" in '''|*[!0-9]*) write_bytes=0 ;; esac

          # Live agent count: crush processes inside the pool cgroup only
          # (never the whole user session tree — the owner's interactive
          # fleet is out of scope by ruling, 2026-10-07).
          cgroup="/sys/fs/cgroup/system.slice/tq-agent-pool.service"
          agents=0
          if [ -r "$cgroup/cgroup.procs" ]; then
            while read -r pid; do
              comm=$(cat "/proc/$pid/comm" 2>/dev/null) || continue
              case "$comm" in crush*) agents=$((agents + 1)) ;; esac
            done <"$cgroup/cgroup.procs"
          fi

          # Newest per-task log (which agent last touched work, and when):
          # the freeze-25 attribution ask "which agent, which phase".
          log_dir="/home/${primaryUser}/.local/state/tq/logs"
          latest_line=$(find "$log_dir" -maxdepth 1 -type f -printf '%T@ %f\n' 2>/dev/null | sort -nr | head -n 1 || true)
          latest_task=$(printf '%s' "$latest_line" | cut -d' ' -f2-)
          latest_mtime=$(printf '%s' "$latest_line" | cut -d' ' -f1 | cut -d. -f1)
          case "$latest_mtime" in '''|*[!0-9]*) latest_mtime=0 ;; esac
          # Prom label safety: drop anything outside a conservative charset.
          latest_task=$(printf '%s' "$latest_task" | tr -dc 'A-Za-z0-9._-')

          {
            echo "# HELP tq_pool_unit_io_read_bytes Cumulative disk read bytes of the tq-agent-pool unit cgroup (systemd IOAccounting; resets on unit restart)"
            echo "# TYPE tq_pool_unit_io_read_bytes counter"
            echo "tq_pool_unit_io_read_bytes $read_bytes"
            echo "# HELP tq_pool_unit_io_write_bytes Cumulative disk write bytes of the tq-agent-pool unit cgroup (systemd IOAccounting; resets on unit restart)"
            echo "# TYPE tq_pool_unit_io_write_bytes counter"
            echo "tq_pool_unit_io_write_bytes $write_bytes"
            echo "# HELP tq_pool_agents_active crush agent processes live in the tq-agent-pool cgroup right now"
            echo "# TYPE tq_pool_agents_active gauge"
            echo "tq_pool_agents_active $agents"
            echo "# HELP tq_pool_task_log_latest_mtime_seconds mtime of the newest per-task tq log file"
            echo "# TYPE tq_pool_task_log_latest_mtime_seconds gauge"
            echo "tq_pool_task_log_latest_mtime_seconds{task=\"$latest_task\"} $latest_mtime"
            echo "# HELP tq_pool_device_io_read_bytes_total Per-device cumulative read bytes of the tq-agent-pool cgroup (io.stat major:minor device)"
            echo "# TYPE tq_pool_device_io_read_bytes_total counter"
            echo "# HELP tq_pool_device_io_write_bytes_total Per-device cumulative write bytes of the tq-agent-pool cgroup (io.stat major:minor device)"
            echo "# TYPE tq_pool_device_io_write_bytes_total counter"
          } >"$TMP"
          if [ -r "$cgroup/io.stat" ]; then
            awk '{
              dev=$1
              for (i=2; i<=NF; i++) {
                split($i, kv, "=")
                if (kv[1] == "rbytes") print "tq_pool_device_io_read_bytes_total{device=\"" dev "\"} " kv[2]
                if (kv[1] == "wbytes") print "tq_pool_device_io_write_bytes_total{device=\"" dev "\"} " kv[2]
              }
            }' "$cgroup/io.stat" >>"$TMP"
          fi
          mv "$TMP" "$OUT"
        '';
      };

      # Entry-gate band: io-PSI some avg10 at or above this refuses the
      # pool start. 30% matches the migrate-_ entry-gate row (the storm is
      # already self-sustaining at that band; freeze-25's plateau sat at
      # ~34 under a wedged sdb1).
      psiGatePercent = 30;
    in
    {
      config = lib.mkIf cfg.enable {
        services.tq-agent-pool = {
          package = lib.mkDefault tqPkg;

          # The pool execs agents that commit as this user; the synthetic
          # upstream "tq" user would have no repos, git identity or crush
          # config. Browser-history-agent precedent (User = primaryUser).
          user = lib.mkDefault primaryUser;
          group = lib.mkDefault "users";

          # Journal on the mirrored HDD pool, snapshotted nightly by
          # btrbk-pool (subvolume created by tq-storage-dir below).
          dbPath = lib.mkDefault "/mnt/pool/services/tq/tq.db";

          # Calibrated from the live round-9 dogfood window (2026-09-08):
          # the manually-run pool that validated review/status semantics.
          # Model comes from each repo's .crushrc managed block (pinned by
          # the bootstrap oneshot) — a pool-level --model would reset
          # reasoning effort (bootstrap.go comment).
          poolSettings = lib.mkDefault {
            projects-dir = "/home/${primaryUser}/projects";
            repos = "CV,SystemNix,go-taskqueue";
            # 3 = one agent per repo in parallel (project-exclusive still
            # paces each repo to one in-flight task; GLM-5.3-Flash is
            # cheap, daily-budget remains the real spend cap)
            concurrency = "3";
            interval = "5m";
            # 90m, raised from 45m (2026-10-15): the worker applies ONLY this
            # pool-level cap (worker.go runCtx WithTimeout) and ignores the
            # harvest's per-batch payload timeout_minutes — every 3-item
            # batch is sized 90m by the harvest, so 45m dead-lettered
            # 000001a13d2037332 at the wall on its only real run (3 attempts,
            # zero landed items; the 45m ceiling also forced the completed
            # 000001a1385cefde batch to skip its heavy build legs).
            task-timeout = "90m";
            max-per-tick = "3";
            daily-budget = "30";
            repo-interval = "go-taskqueue=10m";
            dlq-backoff = "30m";
            # DLQ repair loop (2026-10-01 queue-health plan M3): without it,
            # dead letters landfill with zero autopsies — 317 dead across
            # 676 tasks, 167 the gitignored-vendor gofmt class whose
            # auto-dismiss never ran. dlqfix mints ONE autopsy per dead
            # agent task (dedup forever) and auto-dismisses gate-artifact
            # deaths with shipped proof.
            "dlq-fix" = "true";
            # NO done-preflight key here yet: the claim-time done gate is
            # implemented in go-taskqueue master but UNPUSHED (ahead 13 —
            # docs/todo/upstream.md), and tq FAILS FAST on unknown settings
            # keys, so this key crash-looped the pool on locked 0.3.1
            # (2026-10-07 deploy). Re-add `"done-preflight" = "true";` at the
            # post-push consumption step (TODO_LIST.md → upstream.md).
            # Owner-session park (2026-10-12, C15.3 two-writer policy):
            # repos holding a LIVE owner crush session park their pending
            # tasks for 15m instead of claiming into the owner's worktree
            # (claim/conflict/requeue churn → visible, attempt-free parks).
            # The flag is DEFAULT-ON upstream from the 2026-10-12 commit,
            # so the policy activates at the next `nix flake update
            # go-taskqueue`; add `"owner-session-park" = "true";` at that
            # same consumption step to pin it explicitly (before the lock
            # moves, the key would fail-fast the pool like done-preflight).
            yolo = "true";
            "project-exclusive" = "true";
            review = "true";
            # Close the Flash-workforce loop (proposed 2026-09-10):
            # request_changes verdicts mint fix tasks, and every 5
            # completions per repo mint a done-prompt status report that
            # appends next TODO items — the pool keeps feeding itself.
            "review-autofix" = "true";
            "status-every" = "5";
            # Second conversation turn per task: the brutal self-review +
            # per-task status report (2026-09-10 loops).
            "task-closeout" = "true";
            "log-dir" = "/home/${primaryUser}/.local/state/tq/logs";
            "log-dir-max-age" = "168h";
            # Dead letters + budget exhaustion → PapDashboard (raw Gatus
            # pairs get LLM insight enrichment there; key rides the
            # tq-agent-pool-env sops template).
            "alert-url" = "http://127.0.0.1:${toString ports.papdashboard}";
          };

          serve = {
            enable = lib.mkDefault true;
            addr = lib.mkDefault "127.0.0.1:${toString ports.tq}";
          };
        };

        # tq CLI on PATH for the operator (tq stats / dlq / tail / rescue)
        # — TQ_DB session var for lars points it at the pool journal.
        environment.systemPackages = [ cfg.package ];

        # The pool mounts nofail — systemd-tmpfiles could create the dir on
        # the ROOT filesystem under the /mnt/pool mountpoint before the pool
        # is up (contaminating the NVMe). This oneshot runs only while the
        # pool is actually mounted (RequiresMountsFor fails loudly on a
        # detached DAS) and creates the subvolume with the primary-user
        # ownership both units need (bank-sync-storage-dir pattern).
        systemd.services.tq-storage-dir = {
          description = "Create tq journal directory on the HDD pool";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ "/mnt/pool/services/tq" ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            (harden {
              # subvolume create needs CAP_SYS_ADMIN, chown CAP_CHOWN, and
              # the re-run chmod on an already-chowned dir CAP_FOWNER;
              # harden{}'s empty bounding set would EPERM all of them.
              CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
              ReadWritePaths = [ "/mnt/pool/services" ];
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            dir=/mnt/pool/services/tq
            if [ ! -e "$dir" ]; then
              # Subvolume (not plain dir) so btrbk-pool can snapshot it —
              # mirrors the atticd/bank-sync pool placement. Falls back to
              # a plain dir only on non-btrfs filesystems.
              if ! ${pkgs.btrfs-progs}/bin/btrfs subvolume create "$dir"; then
                mkdir -p "$dir"
              fi
            else
              mkdir -p "$dir"
            fi
            chmod 0770 "$dir"
            chown ${primaryUser}:users "$dir"
          '';
        };

        # Seed/enforce the dogfood rails: .tq-verify (verify gate) + the
        # .crushrc managed block (autonomy + model pin) in every harvested
        # repo, committed as the primary user (never pushed). Idempotent —
        # re-runs converge. --no-run = ensure + report, the pool runs as
        # its own unit. SystemNix gets an explicit verify gate; repos
        # without one complete tasks without proof (bootstrap WARN).
        systemd.services.tq-bootstrap = {
          description = "tq bootstrap — ensure dogfood rails (.tq-verify, .crushrc) in harvested repos";
          # Purely local (TODO_LIST parse + git commits in $HOME repos) — no
          # network-online dependency. Failure tolerance is deliberate: the
          # pool does NOT depend on this unit (a failed bootstrap costs
          # verify rails, not the pool), failures alert via onFailure, and
          # the deploy.sh provisioner loop re-runs it every deploy
          # (idempotent --no-run; no RemainAfterExit so restart = re-run).
          after = [ "tq-storage-dir.service" ];
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ "/mnt/pool/services/tq" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = primaryUser;
              Group = "users";
              Environment = [
                "TQ_DB=${toString cfg.dbPath}"
                # Verify gate + agent-run go commands inherit THIS env (not the
                # fish session): jsonv2-requiring repos dead-letter without it
                # (tq facts 2903/2987/2996-3001). Mirrors home.nix
                # sessionVariables for the systemd context.
                "GOEXPERIMENT=jsonv2"
              ];
              ExecStart = lib.escapeShellArgs [
                (lib.getExe' cfg.package "tq")
                "bootstrap"
                "CV"
                "SystemNix"
                "go-taskqueue"
                "--projects-dir"
                "/home/${primaryUser}/projects"
                "--model"
                "zai/glm-5.3-flash"
                "--verify"
                "SystemNix=nix flake check --no-build"
                "--no-run"
              ];
              # Rails are repo-local git commits; read/write inside $HOME
              # is the point (upstream pool hardening class).
              NoNewPrivileges = true;
              ProtectSystem = "full";
              ProtectKernelTunables = true;
              ProtectKernelModules = true;
              ProtectKernelLogs = true;
            }
            (serviceOneshotDefaults { })
          ];
        };

        systemd.services.tq-agent-pool = {
          after = [
            "tq-storage-dir.service"
            "multi-user.target"
            # Boot-transaction bound (2026-10-19, stability trio item 1):
            # boot 0 (2026-10-18) held the boot ~2min because the PSI entry
            # gate REFUSED into the upstream Restart=on-failure contract
            # (RestartSec=30s refire ×5 until a refusal passed) and each
            # auto-restart kept this unit "activating" INSIDE
            # multi-user.target's wait set. After=multi-user.target moves
            # the pool PAST the transaction (llama-chat 2026-10-17 /
            # netbird-evox2-login 2026-10-17 pattern): wantedBy stays
            # upstream (deploy restart coverage unchanged), the gate still
            # refuses storm entries at EVERY start attempt (boot, deploy,
            # manual), and the refuse-and-refire churn now runs outside the
            # boot — bounded by the startLimitBurst headroom below with
            # OnFailure on terminal give-up. Rejected alternatives:
            # RestartSec backoff holds the transaction LONGER (gaps
            # overshoot the calm window) and delays pool start;
            # ExecCondition-skip silently skips deploy-time storm entries
            # (losing the retry-until-calm the freeze-19/20/21 protection
            # rides) and strands a boot-pulled unit DOWN until the next
            # deploy unless a re-pull leg is built (more machinery, worse
            # deploy-under-storm behavior, no gain over post-gate).
          ];
          wants = [ "tq-storage-dir.service" ];
          # docs/agents/integration-registry.md step 5: start-limit bounds + onFailure on every service.
          # Sized for the PSI entry gate contract below: at RestartSec=30s,
          # burst 5 / 300s (upstream's) exhausted in one 2.5-min PSI storm and
          # left the pool dead until the next deploy (live 2026-10-14 12:41).
          # 40 retries / 30 min ≈ 20 min of gate-retry headroom, still bounded
          # for a genuine crash-loop (OnFailure alerts fire either way).
          # Upstream ALSO sets serviceConfig.startLimitBurst — systemd ignores
          # keys in [Service] (journal "Unknown key" warnings); [Unit] wins.
          startLimitBurst = 40;
          startLimitIntervalSec = 1800;
          inherit onFailure;
          # PapDashboard bridge key — systemd reads this as PID 1, so the
          # root-owned 0400 template stays unreadable to the pool process
          # tree except through the injected env (deliberately a DEDICATED
          # template: agent payloads inherit the environment).
          serviceConfig = lib.mkMerge [
            {
              EnvironmentFile = [ config.sops.templates."tq-agent-pool-env".path ];
              # GOEXPERIMENT must match the interactive session (home.nix):
              # the verify gate and agent-run go commands inherit THIS env
              # (jsonv2 build-constraint dead-letter class).
              Environment = [ "GOEXPERIMENT=jsonv2" ];
              # The pool's children are LLM agents + builds: generous memory
              # ceiling (2 concurrent agents) and CPU headroom beyond the
              # harden{} 200% default, lowest-but-one BFQ tier like the other
              # build machinery.
              MemoryMax = "8G";
              CPUQuota = "400%";
              # Freeze-25 IO discipline: cumulative cgroup accounting feeds
              # tq-pool-io-metrics; the SHARED entry gate refuses starts into
              # a live io-PSI storm (crash-loop amplifier class). Behavior-
              # preserving consolidation 2026-10-17: same band (30), trip
              # window off — flip --trip-window-min to 60 only together with
              # a startLimitBurst re-size (see the header comment).
              IOAccounting = true;
              ExecStartPre = [
                "${lib.getExe pkgs.maintenance-entry-gate} --name tq-agent-pool --psi-max ${toString psiGatePercent} --trip-window-min 0"
              ];
            }
            ioTier.build
          ];
        };

        systemd.services.tq-serve = {
          after = [ "tq-storage-dir.service" ];
          wants = [ "tq-storage-dir.service" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            # WAL/SHM siblings need write access to the DB dir even for a
            # read-only dashboard process.
            { ReadWritePaths = [ "/mnt/pool/services/tq" ]; }
            (harden { MemoryMax = "512M"; })
            (serviceDefaults { })
            ioTier.background
          ];
        };

        # IO-attribution collector for the pool cgroup (discordsync-io-metrics
        # pattern): 60s oneshot writing tq_agent_pool_io.prom so a repeat of
        # the freeze-25 ~864 GB morning is attributable in one Prom query
        # (which unit, which device, how many live agents, newest task).
        systemd.services.tq-pool-io-metrics = {
          description = "tq-agent-pool disk-I/O textfile collector for node_exporter";
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "64M";
              # Sticky-dir rename over a foreign-owned prom (mail-relay class).
              CapabilityBoundingSet = "CAP_FOWNER";
            })
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              ExecStart = lib.getExe tqPoolIoMetrics;
              ReadWritePaths = [ textfileDir ];
            }
          ];
        };

        systemd.timers.tq-pool-io-metrics = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "45s";
            OnUnitActiveSec = "60s";
          };
        };

        # The shared textfile dir exists only while a module creates it —
        # the pool alone must not depend on discordsync/thermal-guard being
        # enabled (same sticky-dir tmpfiles rule, idempotent).
        systemd.tmpfiles.rules = [
          (mkStateDir textfileDir "1777" "nobody" "nogroup")
        ];

        # Service-integration registry entries: the pool liveness check +
        # the tq Dashboard check (serve-gated) + the homepage tile + the
        # tq vHost (Layer 2, gated on serve.enable) + system-health
        # monitoring of all three units. Replaces rows in caddy.nix /
        # gatus-config.nix / homepage.nix.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          tq-agent-pool = {
            inherit (cfg) enable;
            vHost.layer = "none";
            monitored = true;
            checks = [
              # Pool liveness from the system-health collector: the pool has
              # no HTTP surface by design (same shape as postfix/fastflowlm).
              # Dead letters + budget exhaustion alert separately through the
              # PapDashboard bridge (alert-url in poolSettings).
              {
                name = "tq Agent Pool Service";
                group = "Development";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "2m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*system_service_state_failed{service=\"tq-agent-pool\"} 0*)"
                ];
                alert = "tq agent-pool unit failed — TODO_LIST harvest + agent execution halted (dashboard keeps serving from the journal). Check: systemctl status tq-agent-pool, journalctl -u tq-agent-pool -n 100.";
              }
            ];
            homepage = {
              name = "tq Agent Pool";
              group = "AI";
              href = "https://tq.${domain}";
              description = "TODO_LIST Harvest + Headless Crush Agents";
              icon = "opencode.png";
            };
          };
          tq-serve = {
            enable = cfg.serve.enable;
            subdomain = "tq";
            port = ports.tq;
            vHost.layer = "protected";
            monitored = true;
            # No homepage tile here on purpose: the tq dashboard's tile is
            # the tq-agent-pool entry above (same https://tq.<domain> href)
            # — exempted in integration.nix's tileExemptions.
            checks = [
              # Functional, not just liveness: the constant meta
              # description of the real dashboard shell (live-verified
              # against tq serve; the <title> carries a dynamic count).
              {
                name = "tq Dashboard";
                group = "Development";
                url = "http://localhost:${toString ports.tq}/";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 2000"
                  "[BODY] == pat(*Live, read-only projection of the tq task-queue journal*)"
                ];
                alert = "tq dashboard down — the agent-pool journal view at tq.home.lan is unreachable. Check: systemctl status tq-serve, journalctl -u tq-serve.";
              }
            ];
          };
          tq-bootstrap = {
            inherit (cfg) enable;
            vHost.layer = "none";
            monitored = true;
          };
        };
      };
    };
}
