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
  in {
    imports = [pmaModule];

    config = lib.mkIf cfg.enable {
      services.projects-management-automation = {
        package = inputs.projects-management-automation.packages.${pkgs.stdenv.hostPlatform.system}.default;
        user = primaryUser;
        group = "users";
        home = "/home/${primaryUser}";
        environmentFile = sopsEnvPath;
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
      #   MemoryHigh=6G: kernel starts throttling PMA's allocations at 6G
      #     via direct reclaim. PMA slows down but doesn't die. This is the
      #     primary defense — it prevents the exponential page-cache growth
      #     that caused the death-loop.
      #   MemoryMax=8G: hard ceiling. If PMA somehow exceeds 8G (e.g. a
      #     memory leak in the LLM client), the cgroup OOM killer fires
      #     and systemd restarts the service cleanly.
      #   MemorySwapMax=0: PMA has only 370 MB anon — swapping is
      #     counterproductive and risks swap-thrashing.
      #   CPUQuota=200%: caps PMA at 2 cores. Without this, the death-loop
      #     consumed 91% of all CPU, starving everything else.
      systemd.services.projects-management-automation.serviceConfig = lib.mkMerge [
        {
          Type = lib.mkForce "exec";
          WatchdogSec = lib.mkForce "0";
          MemoryMax = lib.mkForce "8G";
          MemoryHigh = lib.mkForce "6G";
          MemorySwapMax = lib.mkForce "0";
          CPUQuota = lib.mkForce "200%";
          Environment = ["GOMEMLIMIT=6144MiB"];
        }
        ioTier.build
      ];
    };
  };
}
