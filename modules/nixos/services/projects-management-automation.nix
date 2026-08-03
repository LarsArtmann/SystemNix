# Projects Management Automation — thin wiring into SystemNix
# The actual NixOS module lives in the PMA flake (nixosModules.default).
# This file passes SystemNix-specific config: sops secrets, primary user.
{ inputs, ... }: {
  flake.nixosModules.projects-management-automation =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.projects-management-automation;
      primaryUser = config.users.primaryUser;
      pmaModule = inputs.projects-management-automation.nixosModules.default;
      sopsEnvPath = config.sops.templates."pma-env".path;
      inherit (import ../../../lib/default.nix lib) ports;
    in
    {
      imports = [ pmaModule ];

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
        # PMA_COMMITTER_WORKERS=4 reduces concurrent git+LLM operations from
        # the default 8 to 4, halving IO/memory spikes during batch processing.
        systemd.services.projects-management-automation.environment = {
          OTEL_EXPORTER_OTLP_ENDPOINT = lib.mkDefault "localhost:${toString ports.signoz-otlp-http}";
          PMA_COMMITTER_WORKERS = lib.mkDefault "4";
        };

        # The upstream NixOS module sets Type=notify + WatchdogSec=30s (commit
        # 6cdf05e5 "enable systemd notify"), but the Go binary never calls
        # sd_notify(READY=1). Result: systemd waits the full TimeoutStartSec
        # (90s), times out, kills the service, Restart=on-failure cycles it
        # forever. Override to Type=exec so systemd considers it started once
        # execve succeeds. WatchdogSec is inert without READY=1, zeroed for
        # clarity. Remove this override once upstream adds sd_notify support.
        #
        # MemoryMax=16G: the process RSS is only ~367 MB, but cgroup v2
        # charges page cache (from reading 260 git repos during discovery)
        # against the limit. The upstream 8G default and previous 12G override
        # were too low — page-cache exhaustion caused EOF errors in go-git
        # file operations, which cascaded into commit failures and CPU
        # death-loops. 16G gives sufficient headroom for page cache while
        # keeping an OOM guardrail.
        systemd.services.projects-management-automation.serviceConfig = {
          Type = lib.mkForce "exec";
          WatchdogSec = lib.mkForce "0";
          MemoryMax = lib.mkForce "16G";
        };
      };
    };
}
