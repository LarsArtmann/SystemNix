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
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      cfg = config.services.tq-agent-pool;
      primaryUser = config.users.primaryUser or "lars";
      tqPkg = inputs.go-taskqueue.packages.${pkgs.stdenv.hostPlatform.system}.default;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        ports
        ioTier
        ;
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
            task-timeout = "45m";
            max-per-tick = "3";
            daily-budget = "30";
            repo-interval = "go-taskqueue=10m";
            dlq-backoff = "30m";
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
              Environment = [ "TQ_DB=${toString cfg.dbPath}" ];
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
          after = [ "tq-storage-dir.service" ];
          wants = [ "tq-storage-dir.service" ];
          # AGENTS.md rule 5: start-limit bounds + onFailure on every service.
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          # PapDashboard bridge key — systemd reads this as PID 1, so the
          # root-owned 0400 template stays unreadable to the pool process
          # tree except through the injected env (deliberately a DEDICATED
          # template: agent payloads inherit the environment).
          serviceConfig = lib.mkMerge [
            {
              EnvironmentFile = [ config.sops.templates."tq-agent-pool-env".path ];
              # The pool's children are LLM agents + builds: generous memory
              # ceiling (2 concurrent agents) and CPU headroom beyond the
              # harden{} 200% default, lowest-but-one BFQ tier like the other
              # build machinery.
              MemoryMax = "8G";
              CPUQuota = "400%";
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
      };
    };
}
