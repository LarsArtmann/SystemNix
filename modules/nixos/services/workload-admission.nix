# Workload admission control — bounding aggregate heavy-job demand.
#
# The 2026-08-22 double kernel freeze census (OOM dump 04:58) counted 10
# concurrent nix builds + 12 QEMU VMs (8 cross-arch aarch64) + ~72 compile
# + 22 golangci-lint processes + 12 crush sessions (52 crush + 50 bun
# procs) against 94 GB RAM with 28 GB zram as the ONLY swap. Every
# protection that existed reacted AFTER pressure formed; nothing bounded
# aggregate demand.
#
# This module provides the cooperative layer of admission control (user
# decision 2026-08-22: "full enforcement" for builds + VM tests, crush
# sessions monitor-only):
#
#   1. `heavy-job` wrapper (environment.systemPackages): slot-counting
#      flock queue — at most maxConcurrentHeavyJobs heavy commands run at
#      once; further invocations WAIT for a free slot (they never fail).
#      Intended for NixOS VM tests (qemu drivers) and long local builds
#      invoked interactively. nix builds that go through the daemon are
#      additionally hard-bounded by nix-daemon MemoryHigh (networking.nix)
#      regardless of this queue.
#   2. Crush session census lives in system-health (metric
#      `system_crush_sessions` + Gatus alert) — monitor-only by decision.
#
# Deploys via `nix run .#deploy` BYPASS the queue by design: deploys are
# already serialized by the switch-to-configuration lock, and deploy.sh
# gained a pre-switch pressure gate (PSI/zram/MemAvailable) instead.
_: {
  flake.nixosModules.workload-admission = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.workload-admission;

    heavyJob = pkgs.writeShellApplication {
      name = "heavy-job";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.util-linux
      ];
      text = ''
        set -euo pipefail

        # Slot-counting queue: N lock files, try each non-blocking, hold
        # the first free one for the duration of the command. Concurrent
        # invocations beyond N block in flock until a slot frees (they
        # never fail, never lose their place — flock queues them).
        SLOTS="''${HEAVY_JOB_SLOTS:-${toString cfg.maxConcurrentHeavyJobs}}"
        SLOTS_DIR="''${HEAVY_SLOTS_DIR:-/run/lock/systemnix-heavy}"

        mkdir -p "$SLOTS_DIR"
        chmod 0777 "$SLOTS_DIR" 2>/dev/null || true

        if [ "$#" -eq 0 ]; then
          echo "usage: heavy-job <command> [args…]" >&2
          echo "  Runs a command under the heavy-job admission queue" >&2
          echo "  (max $SLOTS concurrent; further invocations wait)." >&2
          echo "  env: HEAVY_JOB_SLOTS=N override, HEAVY_SLOTS_DIR=dir bypass" >&2
          exit 64
        fi

        # Try slots 1..SLOTS-1 non-blocking via a HELD fd (exec 9> opens,
        # flock -n 9 acquires, the fd survives `exec "$@"` so the lock is
        # held for the command's whole lifetime and releases on exit).
        # The last slot BLOCKS with a timeout — waiting jobs never fail,
        # they queue in flock.
        i=1
        while [ "$i" -lt "$SLOTS" ]; do
          exec 9>"$SLOTS_DIR/slot.$i.lock"
          if flock -n 9; then
            exec "$@"
          fi
          i=$((i + 1))
        done

        exec 9>"$SLOTS_DIR/slot.$SLOTS.lock"
        if ! flock -w "''${HEAVY_JOB_WAIT:-86400}" 9; then
          echo "heavy-job: timed out waiting for a free slot (HEAVY_JOB_WAIT)" >&2
          exit 75
        fi
        exec "$@"
      '';
    };
  in {
    options.services.workload-admission = {
      enable = lib.mkEnableOption "Workload admission control: heavy-job flock queue for VM tests + long builds (the 2026-08-22 freeze class; build memory is separately bounded via nix-daemon MemoryHigh)";

      maxConcurrentHeavyJobs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3;
        description = "Maximum simultaneously running commands under the heavy-job queue (builds + VM tests combined). Census night ran 10 builds + 12 VMs and froze the machine; 3 leaves ample headroom (user decision 2026-08-22)";
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [heavyJob];

      # The slot dir is runtime state under /run/lock (tmpfs) — nothing
      # persists across boots, no cleanup needed.
      systemd.tmpfiles.rules = [
        "d /run/lock/systemnix-heavy 0777 root root -"
      ];
    };
  };
}
