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
# sops wiring landed 2026-11-10 as the flip scaffold (audible-sync
# precedent): platforms/nixos/secrets/pim-sync.yaml + the guarded
# declarations hold PLACEHOLDER values, so sops-key-audit passes while the
# enable=false posture stays inert. The unit's config-check ExecStartPre
# fails loudly with the go-live checklist while any placeholder remains.
# Wire-up: DAV env via sops template, OAuth client JSON via secretFile,
# token seeds via per-secret paths (tokenSeedDir = /var/lib/pim-sync-seed;
# upstream seeds into writable state only-into-empty-slots, then owns the
# rotation). Path contract: ~/projects/pim-sync docs/oauth-setup.md.
{ inputs, ... }: {
  flake.nixosModules.pim-sync =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib) onFailure;
      cfg = config.services.pim-sync;

      # Fail fast with an actionable message while the sops scaffold still
      # holds PLACEHOLDER values (the module ships disabled for exactly
      # this reason) and sanity-check the pasted shapes — otherwise the
      # oneshot buries the cause in OAuth/API errors every 5 min
      # (audible-sync config-check pattern). Runs after the upstream seed
      # script (module-system list concatenation).
      configCheck = pkgs.writeShellApplication {
        name = "pim-sync-config-check";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.jq
        ];
        text = ''
          set -euo pipefail
          shopt -s nullglob

          clientSecret=${config.sops.secrets.pim_sync_oauth_client_secret.path}
          davEnv=${config.sops.templates."pim-sync-dav-env".path}

          fail_missing () {
            echo "pim-sync: sops material MISSING: $1" >&2
            echo "pim-sync: (the sops-nix render did not produce this path — check the sops decls and the boot decrypt log)" >&2
            exit 1
          }

          fail_placeholder () {
            echo "pim-sync: sops material still PLACEHOLDER: $1" >&2
            echo "pim-sync: Go-live checklist (docs/services/pim-sync.md):" >&2
            echo "pim-sync:   1. Owner: GCP project -> People API + OAuth Desktop client, publishing status IN PRODUCTION (~/projects/pim-sync docs/oauth-setup.md)" >&2
            echo "pim-sync:   2. Owner: paste the client secret JSON into platforms/nixos/secrets/pim-sync.yaml key pim_sync_oauth_client_secret (sops editor, never a command line)" >&2
            echo "pim-sync:   3. Owner: dedicated Stalwart DAV account for bot:pim-sync on pbx.artmann.tech -> pim_sync_stalwart_dav_user / pim_sync_stalwart_dav_pass" >&2
            echo "pim-sync:   4. Owner: consents (pim-sync auth --account personal|work [--calendar]) -> paste token JSONs into pim_sync_token_*" >&2
            echo "pim-sync:   5. Redeploy (nix run .#deploy); dry-run timer first, then live=true + maxChanges cap." >&2
            exit 1
          }

          for f in "$clientSecret" "$davEnv" ${cfg.tokenSeedDir}/*.json; do
            [ -f "$f" ] || fail_missing "$f"
            grep -q PLACEHOLDER "$f" && fail_placeholder "$f"
          done

          jq -e '.installed.client_id != null' "$clientSecret" > /dev/null || {
            echo "pim-sync: $clientSecret is not a GCP Desktop OAuth client JSON (missing .installed.client_id)" >&2
            exit 1
          }
          for f in ${cfg.tokenSeedDir}/*.json; do
            jq -e '.refresh_token != null' "$f" > /dev/null || {
              echo "pim-sync: $f is not a Google OAuth token JSON (missing .refresh_token)" >&2
              exit 1
            }
          done
        '';
      };
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
          # sops materialization (flip scaffold, 2026-11-10): the rendered
          # values are PLACEHOLDER until the owner paste — the config-check
          # ExecStartPre below turns that into a loud, actionable failure
          # instead of buried OAuth errors (audible-sync pattern).
          sops.templates."pim-sync-dav-env" = {
            owner = "pim-sync";
            group = "pim-sync";
            mode = "0400";
            restartUnits = [ "pim-sync.service" ];
            content = lib.generators.toKeyValue { } {
              PIMSYNC_DAV_USER = config.sops.placeholder.pim_sync_stalwart_dav_user;
              PIMSYNC_DAV_PASS = config.sops.placeholder.pim_sync_stalwart_dav_pass;
            };
          };

          # Single-source the seed dir (2026-11-10): the seed paths AND
          # tokenSeedDir live HERE together — one rename flips them
          # together instead of silently apart across two files.
          sops.secrets = {
            pim_sync_token_personal.path = "/var/lib/pim-sync-seed/personal.json";
            pim_sync_token_work.path = "/var/lib/pim-sync-seed/work.json";
            pim_sync_token_personal_calendar.path = "/var/lib/pim-sync-seed/personal-calendar.json";
            pim_sync_token_work_calendar.path = "/var/lib/pim-sync-seed/work-calendar.json";
          };

          services.pim-sync = {
            environmentFile = config.sops.templates."pim-sync-dav-env".path;
            secretFile = config.sops.secrets.pim_sync_oauth_client_secret.path;
            tokenSeedDir = "/var/lib/pim-sync-seed";
            # Append-only run receipts (mesh invariant 5: auditability
            # comes from receipts, never from last_report). Live runs
            # append one 0600 JSONL line each; dry runs never write.
            # Under dataDir so the upstream StateDirectory picks it up.
            receiptsDir = "/var/lib/pim-sync/receipts";
          };

          # docs/agents/integration-registry.md step 5: OnFailure Discord
          # routing (upstream sets the start-limit bounds itself).
          systemd.services.pim-sync = {
            inherit onFailure;
            serviceConfig.ExecStartPre = [ (lib.getExe configCheck) ];
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
