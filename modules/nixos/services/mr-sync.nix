# Runbook: docs/services/mr-sync.md
# mr-sync — read-only repo-portfolio web dashboard.
#
# The mr-sync CLI ships on PATH via mkLarsPackages (pure CLI, source-only
# flake input). This module deploys its OTHER surface: `mr-sync dashboard`,
# a read-only HTTP server (templ + SSE) that shows the repo portfolio,
# disk status of local clones, and recommended sync actions.
#
#   - Binds 127.0.0.1:${ports.mr-sync} (the tool's default port 7331).
#     No --token: the bearer token is only REQUIRED for non-localhost binds
#     (upstream errTokenRequired), and the vHost is Layer 2 protectedVHost —
#     oauth2-proxy gates external access via Pocket ID; LAN bypass mirrors
#     the tq-serve / Homepage posture.
#   - Runs as the primary user: the dashboard reads ~/.mrconfig,
#     ~/.config/mr-sync/config.json (the user's LIVE config — mrconfig_path,
#     scan_dirs, exclude_repos, path_overrides), and fully walks
#     ~/projects + ~/forks for per-repo disk sizes. /home/lars is 0700, so
#     any other user could not traverse (browser-history-agent / tq-serve
#     precedent: run as primaryUser). ProtectHome=read-only keeps that
#     access one-way; the dashboard is documented read-only upstream.
#   - GITHUB_TOKEN comes from sops (env-file format). Upstream hard-requires
#     it for the GitHub fetch; until a real PAT is pasted the dashboard
#     degrades gracefully (FetchError banner, data filled from .mrconfig +
#     local scan only — verified in dashboard_data.go fillFromMrconfig).
#   - Data collection is cached (60s TTL, 5s on fetch errors, single-flight)
#     — the Gatus probe interval is sized so probes usually hit the cache
#     instead of re-paying a full repo walk on the QLC NVMe.
{ inputs, ... }: {
  flake.nixosModules.mr-sync =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.mr-sync-dashboard;
      primaryUser = config.users.primaryUser or "lars";
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailure
        ioTier
        ports
        ;
    in
    {
      options.services.mr-sync-dashboard = {
        enable = lib.mkEnableOption "mr-sync repo-portfolio web dashboard";

        package = lib.mkOption {
          type = lib.types.package;
          # Same source the PATH CLI rides (lib/lars-packages.nix flakePkg) —
          # lars packages are flake outputs, NOT pkgs attributes.
          # TEMPORARY vendorHash shim DROPPED (2026-10-15 fleet wave →
          # 2026-10-17 drop): upstream flake.nix:126 at tip 71d6b0d4 bakes
          # the shim's own KaDlWefE… value (lock == tip, bit-neutral
          # override; lars-packages surface dropped in the same pass).
          # Re-add ONLY via nix-hash-fix evidence, never by hand.
          # RE-ADDED 2026-10-19 wave: keep-going toplevel enumeration
          # (/tmp/toplevel-build-20261019.log) mismatched upstream-baked
          # KaDlWefE… at locked rev d409f9f; got yB73mr06… (same value as
          # the re-pinned lars-packages surface).
          # RE-STALE 2026-10-26 lock float: spec yB73mr06, got TENDT6NZ
          # (float-proof-20261026-174429.log — the 16:10 enumeration's
          # module surface; the PATH surface rode the same value).
          default = inputs.mr-sync.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs {
            vendorHash = "sha256-TENDT6NZlwuX5d2MDuiE3498zU04Bsen698Ih4S5RN4=";
          };
          defaultText = lib.literalExpression "inputs.mr-sync.packages.${pkgs.stdenv.hostPlatform.system}.default";
          description = "The mr-sync package (github:LarsArtmann/mr-sync).";
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets.mr_sync_github_token = {
          sopsFile = ../../../platforms/nixos/secrets/mr-sync.yaml;
          # Root-owned 0400: systemd (PID 1) reads EnvironmentFile as root and
          # injects GITHUB_TOKEN into the primary-user process — the dashboard
          # itself never needs file access.
          restartUnits = [ "mr-sync-dashboard.service" ];
        };

        systemd.services.mr-sync-dashboard = {
          description = "mr-sync repo-portfolio web dashboard";
          inherit onFailure;
          wantedBy = [ "multi-user.target" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "simple";
              User = primaryUser;
              Group = "users";
              ExecStart = "${lib.getExe cfg.package} dashboard --host 127.0.0.1 --port ${toString ports.mr-sync} --no-open";
              # Env-file format (GITHUB_TOKEN=...); sops rotation restarts us.
              EnvironmentFile = config.sops.secrets.mr_sync_github_token.path;
            }
            (harden {
              MemoryMax = "512M";
              # Read ~/.mrconfig + ~/.config/mr-sync/config.json + walk
              # ~/projects, ~/forks. One-way: the dashboard never writes.
              ProtectHome = "read-only";
            })
            (serviceDefaults { })
            ioTier.background
          ];
        };

        # Service-integration registry entry (modules/nixos/services/
        # integration.nix): ONE declaration fans out to the Caddy vHost
        # (Layer 2 protected), the Gatus check, the homepage tile, and
        # system-health monitoring. Replaces rows in caddy.nix /
        # gatus-config.nix / homepage.nix / system-health.nix. No backup
        # (read-only, no state), no OIDC (bearer-token-capable but the
        # protected layer owns external auth), no OTel (binary has none —
        # miniflux doctrine).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          mr-sync-dashboard = {
            subdomain = "mr-sync";
            port = ports.mr-sync;
            vHost.layer = "protected";
            checks = [
              {
                # Liveness + functional pair: 200 AND the page actually
                # renders HTML (a wedged/half-dead server fails the body pat).
                name = "mr-sync Dashboard";
                group = "Development";
                path = "/";
                # 5m so probes usually ride the 60s data cache set by the
                # user's own browsing instead of re-paying the full
                # computeDirSize walk over ~/projects + ~/forks.
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*<html*)"
                  # Cold collects du-walk every repo — generous bound, still
                  # catches a wedged process. Must stay under the client
                  # timeout below.
                  "[RESPONSE_TIME] < 15000"
                ];
                client = {
                  timeout = "20s";
                };
                alert = "mr-sync dashboard down — the repo portfolio at mr-sync.home.lan is unreachable. Check: systemctl status mr-sync-dashboard, journalctl -u mr-sync-dashboard -n 100.";
              }
            ];
            homepage = {
              name = "mr-sync";
              group = "Development";
              description = "Repo Portfolio Dashboard";
              icon = "git.png";
            };
            monitored = true;
          };
        };
      };
    };
}
