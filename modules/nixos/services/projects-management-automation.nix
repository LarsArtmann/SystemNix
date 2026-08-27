# Projects Management Automation — thin wiring into SystemNix
# The actual NixOS module lives in the PMA flake (nixosModules.default).
# This file passes SystemNix-specific config: sops secrets, primary user.
{inputs, ...}: {
  flake.nixosModules.projects-management-automation = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.projects-management-automation;
    primaryUser = config.users.primaryUser;
    pmaModule = inputs.projects-management-automation.nixosModules.default;
    sopsEnvPath = config.sops.templates."pma-env".path;
    inherit (import ../../../lib/default.nix lib) ports ioTier;

    # PMA's discovery daemon starves when the cgroup hits MemoryHigh and
    # enters page-cache direct reclaim: the unix socket keeps accepting
    # connections but never answers (observed twice on 2026-08-14 — the
    # 21h Overview-503 outage and a blocked deploy were both this). The
    # process stays "active", so only active probing catches it. Two
    # failed probes 30s apart → restart. Root cause needs an upstream fix
    # (memory-bounded scan starving the daemon goroutine); this bounds the
    # outage to ~5 min instead of hours.
    pmaDaemonWatchdog = pkgs.writeShellApplication {
      name = "pma-daemon-watchdog";
      runtimeInputs = [
        pkgs.curl
        pkgs.systemd
      ];
      text = ''
        set -u
        sock=/run/project-discovery/daemon.sock
        probe() {
          curl -sf --max-time 5 --unix-socket "$sock" http://localhost/v1/health >/dev/null 2>&1
        }
        if probe; then exit 0; fi
        sleep 30
        if probe; then exit 0; fi
        echo "pma daemon unresponsive on $sock (2 probes 30s apart) — restarting projects-management-automation"
        systemctl restart projects-management-automation.service
      '';
    };
  in {
    imports = [pmaModule];

    config = lib.mkIf cfg.enable {
      services.projects-management-automation = {
        package = inputs.projects-management-automation.packages.${pkgs.stdenv.hostPlatform.system}.default;
        user = primaryUser;
        group = "users";
        home = "/home/${primaryUser}";
        environmentFile = sopsEnvPath;
        # FastFlowLM (NPU LLM) is the desired local provider. The OpenAI
        # chain (DefaultChainFromEnv) reads OPENAI_BASE_URL + OPENAI_MODEL
        # from its environment — support landed in go-commit v0.8.0, which
        # PMA's own flake.lock pins (7321133, since master 7aff6aa6).
        # NOTE (2026-08-27): PMA's flake input no longer follows our
        # nixpkgs/go-commit/go-nix-helpers — its vendorHash is validated
        # against its OWN lock (DiscordSync/bank-sync/qmd precedent);
        # following drifts the vendored module set and breaks the FOD.
        extraEnvironment = [
          "OPENAI_API_KEY=local"
          "OPENAI_BASE_URL=http://127.0.0.1:${toString ports.fastflowlm}/v1"
          "OPENAI_MODEL=qwen3.6-moe:35b-a3b"
        ];
      };

      # OTel traces → local SigNoz OTLP/HTTP collector. Uses raw OTel SDK
      # (no go-cqrs-lite). Noop tracer when unset (zero overhead).
      # PMA_COMMITTER_WORKERS=2: each worker drives a git subprocess + LLM
      # API call concurrently. 4 workers on 260 repos was enough to generate
      # sustained 91% CPU and 16G page-cache pressure (see crash-analysis
      # 2026-08-09). 2 workers halves the concurrent pressure while still
      # keeping commit latency acceptable for a background daemon.
      systemd.services.projects-management-automation.environment = {
        OTEL_EXPORTER_OTLP_ENDPOINT = lib.mkDefault "localhost:${toString ports.signoz-otlp-http}";
        PMA_COMMITTER_WORKERS = lib.mkDefault "2";
        # 8 discovery workers (default min(GOMAXPROCS,8)) fault page cache
        # fast enough to push the cgroup into MemoryHigh direct reclaim,
        # starving the daemon goroutine — socket hangs observed 3x on
        # 2026-08-14 (21h, 9min, 5min after restart). 2 workers spread the
        # same IO over time; discovery is a background cache, latency is OK.
        # Remove if PMA bounds scan memory per-worker upstream.
        PMA_DISCOVERY_WORKERS = lib.mkDefault "2";
      };

      # The upstream NixOS module sets Type=notify + WatchdogSec=30s (commit
      # 6cdf05e5 "enable systemd notify"), but the Go binary never calls
      # sd_notify(READY=1). Result: systemd waits the full TimeoutStartSec
      # (90s), times out, kills the service, Restart=on-failure cycles it
      # forever. Override to Type=exec so systemd considers it started once
      # execve succeeds. WatchdogSec is inert without READY=1, zeroed for
      # clarity. Remove this override once upstream adds sd_notify support.
      #
      # ── Death-loop prevention (2026-08-09 crash) ──
      # PMA's anonymous memory (actual heap) is only ~370 MB, but reading
      # 260+ git repos during discovery charges ~16 GB of page cache to the
      # cgroup. The upstream module set NO MemoryHigh, NO CPUQuota, and
      # MemoryMax=16G. Result: page cache filled to 16G → kernel reclaimed
      # pages → PMA immediately re-read them → thrash loop with 91% CPU.
      # The kernel never OOM-killed (page cache is reclaimable), so the
      # thrashing ran indefinitely until system-wide memory pressure hit
      # 95% → kernel freeze → hardware watchdog reset.
      #
      # Fix: layered cgroup containment.
      #   MemoryHigh=12G / MemoryMax=16G: the scan working set of 260+ repos
      #     grew beyond the original 6G ceiling (2026-08-14: memory pinned at
      #     6.2-6.4G in permanent direct reclaim on every restart, daemon
      #     goroutine starved — socket hung 3x in one day, watchdog flapped
      #     PMA every ~5 min). Pre-incident config ran scans fine under a 16G
      #     max, so 12G high gives the scan headroom while 16G max keeps the
      #     hard bound that prevents the 2026-08-09 system freeze (16G of
      #     110G RAM cannot exhaust the machine alone).
      #   ManagedOOMPreference=omit: exempts PMA from systemd-oomd's
      #     memory-pressure killer. Discovery of 260+ repos legitimately
      #     causes >50% pressure for >20s (oomd's DefaultMemoryPressureLimit
      #     and DefaultMemoryPressureDurationSec), which oomd interprets as a
      #     runaway process and kills. Discovery is a burst, not a leak — it
      #     settles to ~250 MB after the scan completes.
      #     NOTE: ManagedOOMMemoryPressure has NO "off" value — "auto" is the
      #     DEFAULT (oomd will kill), and "kill" makes it more aggressive.
      #     The correct exemption directive is ManagedOOMPreference = "omit".
      #   MemorySwapMax=0: PMA has only ~370 MB anon — swapping is
      #     counterproductive and risks swap-thrashing.
      #   CPUQuota=200%: caps PMA at 2 cores.
      systemd.services.projects-management-automation.serviceConfig = lib.mkMerge [
        {
          Type = lib.mkForce "exec";
          WatchdogSec = lib.mkForce "0";
          MemoryMax = lib.mkForce "16G";
          MemoryHigh = lib.mkForce "12G";
          MemorySwapMax = lib.mkForce "0";
          CPUQuota = lib.mkForce "200%";
          ManagedOOMPreference = "omit";
          # The daemon commits across 260+ repos whose pre-commit hooks
          # require repo-specific toolchains (bash, nix, gitleaks,
          # golangci-lint, dprint, ...) that no service PATH can carry.
          # Its PATH (pma, git, coreutils, findutils, grep, sed, systemd)
          # lacks even bash, so every "#!/usr/bin/env bash" hook fails to
          # exec and each `git commit` exits 1 — the daemon then regenerates
          # commit messages via LLM and retries forever (live 2026-08-19,
          # PMA ce0f638). Env-config (GIT_CONFIG_*) beats repo and global
          # config files, so pointing core.hooksPath at an empty directory
          # disables repo hooks FOR THE DAEMON ONLY; interactive commits
          # keep full hooks. Secret-safety backstop: GitHub push protection
          # + secret-history-scan CI gate every push.
          # Root fix belongs upstream (PMA committer should skip hooks
          # explicitly); the identity entries are mkAfter so they win the
          # systemd Environment= later-wins ordering over upstream's raw,
          # space-broken "GIT_AUTHOR_NAME=Lars Artmann" items.
          Environment = lib.mkAfter [
            ''"GIT_AUTHOR_NAME=Lars Artmann"''
            ''"GIT_AUTHOR_EMAIL=git@lars.software"''
            ''"GIT_COMMITTER_NAME=Lars Artmann"''
            ''"GIT_COMMITTER_EMAIL=git@lars.software"''
            "GIT_CONFIG_COUNT=1"
            "GIT_CONFIG_KEY_0=core.hooksPath"
            "GIT_CONFIG_VALUE_0=/var/empty"
          ];
        }
        ioTier.build
      ];

      systemd.services.pma-daemon-watchdog = {
        description = "Restart PMA when its discovery daemon hangs (responsive-socket probe)";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe pmaDaemonWatchdog;
        };
      };

      systemd.timers.pma-daemon-watchdog = {
        description = "Probe the PMA discovery daemon every 5 minutes";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "5min";
          AccuracySec = "1min";
        };
      };
    };
  };
}
