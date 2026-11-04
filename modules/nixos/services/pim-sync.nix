# Runbook: docs/services/pim-sync.md
# pim-sync — SystemNix wrapper around the upstream LarsArtmann/pim-sync
# flake (PRIVATE, git+ssh; Google People ↔ Stalwart CardDAV contacts
# sync; Stalwart is the single truth, Google a sync edge).
#
# Upstream (inputs.pim-sync.nixosModules.default) owns everything product:
#   services.pim-sync — pim-sync.service oneshot + pim-sync.timer (5min,
#                       2min jitter), dry-run by default (--live gates
#                       writes, --max-changes caps per-leg), hardening,
#                       GOMEMLIMIT 384MiB, MemoryMax 512M, TimeoutStartSec
#                       10min, start-limit 5/300.
#
# This file layers ONLY the SystemNix-specific concerns: the explicit
# package pin (upstream's package option has NO default — bank-sync/index
# pattern), onFailure Discord routing, and the integration-registry +
# catalog entries (headless: subdomain/port null, vHost.layer "none").
#
# DEPLOYMENT STATE (2026-11-04): flip-ready DISABLED (enable = false in
# configuration.nix). Upstream has NO idle no-op: discoverAccounts ERRORS
# on an empty tokensDir (cmd/pim-sync/sync.go:359), so enabling without
# secrets = failed oneshot every 5min + OnFailure alert storm + the
# failed-unit exit-4 deploy trap (dmarc-monitor class).
#
# sops wiring is INTENTIONALLY ABSENT until the owner provides values
# (sops-key-audit throws on declared-but-missing keys). At flip time wire:
#   environmentFile → sops-rendered env (PIMSYNC_DAV_USER/PIMSYNC_DAV_PASS)
#   secretFile      → OAuth client secret JSON (publishing mode "In
#                     production" — testing-mode tokens die after 7 days,
#                     the InboxClean lesson)
#   tokenSeedDir    → per-account consent tokens (<account>.json; seeded
#                     ONLY into empty slots — state owns them after first
#                     refresh, the 7-day-rotation lesson)
# Path contract: ~/projects/pim-sync docs/oauth-setup.md.
{ inputs, ... }: {
  flake.nixosModules.pim-sync =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib) onFailure;
      cfg = config.services.pim-sync;
    in
    {
      imports = [
        inputs.pim-sync.nixosModules.default
        {
          # Unconditional catalog entry (ADR-008): "what exists" — declared
          # and pre-wired here but runs nowhere until the owner-gated flip.
          services.catalog.pim-sync = {
            subdomain = null;
            description = "Google People ↔ Stalwart CardDAV contacts sync (dry-run timer; Stalwart single truth)";
          };
        }
      ];

      config = lib.mkMerge [
        {
          # Explicit package pin (bank-sync/index pattern): upstream's
          # package option has NO default and SystemNix's nixpkgs carries
          # no pim-sync attr. Lazy: with enable=false nothing demands the
          # drv — it enters the closure only at the flip.
          services.pim-sync.package = inputs.pim-sync.packages.x86_64-linux.default;
        }

        (lib.mkIf cfg.enable {
          # docs/agents/integration-registry.md step 5: OnFailure Discord
          # routing (upstream sets the start-limit bounds itself).
          systemd.services.pim-sync = {
            inherit onFailure;
          };

          # Registry fan-out: no vHost/subdomain/port (no HTTP surface —
          # outbound Google + Stalwart DAV calls only), so the tile
          # coverage assertion is N/A and no DNS entry is needed. Health
          # signals: unit state via system-health (monitored) now;
          # metricsFile + a Gatus freshness check on
          # pimsync_leg_last_success_unix land at the live flip (dry-run
          # never settles last_success — 0 = never — so a freshness check
          # would red permanently under the dry-run posture).
          services.integration = lib.optionalAttrs (options ? services.integration) {
            pim-sync = {
              unit = "pim-sync.service";
              subdomain = null;
              port = null;
              vHost.layer = "none";
              checks = [ ];
              monitored = true;
            };
          };
        })
      ];
    };
}
