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
# DEPLOYMENT STATE (2026-11-27): ENABLED in tree, DRY-RUN only
# (enable = true, live = false in configuration.nix). The Google-side
# sops keys are still PLACEHOLDER, so the unit carries an ExecCondition
# gate (secretGate below): while any material is a placeholder the unit
# is SKIPPED (systemd "condition failed" — inactive, no failure state,
# no OnFailure), which is what makes the unconditional enable safe.
# Upstream has NO idle no-op: discoverAccounts ERRORS on an empty
# tokensDir (cmd/pim-sync/sync.go:359), so a gate-less enable would fail
# every 5min, ride OnFailure into an alert storm, and trip the
# failed-unit exit-4 deploy trap (dmarc-monitor class).
#
# sops wiring landed 2026-11-10 as the flip scaffold (audible-sync
# precedent): platforms/nixos/secrets/pim-sync.yaml + the guarded
# declarations. REAL today: the Stalwart DAV pair (2026-11-18) and the
# dashboard bearer token (2026-11-27); the OAuth client JSON + the four
# consent tokens are the owner's console/browser steps
# (docs/services/pim-sync.md). The config-check ExecStartPre still fails
# loudly on malformed material — it only runs once the gate passes.
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
      inherit (import ../../../lib/default.nix lib) ioTier onFailure;
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
            echo "pim-sync:   6. Dashboard token: openssl rand -hex 32 into sops key pim_sync_ui_token (editor, never a command line); redeploy — the restart re-reads it (ruling 2026-11-19)." >&2
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

      # Dashboard bearer-token guard (fleet rows 2026-11-19): pim-sync-ui
      # starts at BOOT (multi-user.target) — before any sync-side
      # config-check could catch it — so a PLACEHOLDER token would become
      # a weak bearer password on a mesh-visible bind. Fail closed: the ui
      # unit refuses to start until the owner pastes the real
      # `openssl rand -hex 32` value. Rotation flow (ruling 2026-11-19):
      # paste + redeploy; the sops restartUnits bounce re-reads the file.
      uiTokenCheck = pkgs.writeShellApplication {
        name = "pim-sync-ui-token-check";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
        text = ''
          set -euo pipefail
          f=${toString cfg.dashboard.authTokenFile}
          [ -s "$f" ] || {
            echo "pim-sync: ui token file MISSING/empty: $f" >&2
            exit 1
          }
          if grep -q PLACEHOLDER "$f"; then
            echo "pim-sync: ui token still PLACEHOLDER: $f" >&2
            echo "pim-sync: Owner: openssl rand -hex 32 into sops key pim_sync_ui_token (editor, never a command line), then redeploy — the restart re-reads it (ruling 2026-11-19)." >&2
            exit 1
          fi
        '';
      };

      # Secret gate (2026-11-27) — the reason enable=true is safe while
      # the Google-side keys are still PLACEHOLDER. systemd ExecCondition
      # semantics are the skip channel: exit 0 = run, 1-254 = unit
      # SKIPPED (inactive, no failure state, OnFailure does NOT fire),
      # 255+ = real failure. So a placeholder SKIPS quietly (the 5min
      # timer keeps proving the sops paths render) while a MISSING
      # rendered file FAILS — a sops-nix render defect must never be
      # mistaken for "waiting for the owner". The shape check stays in
      # configCheck (ExecStartPre), which only runs once this passes.
      # The unit hands the gate its file list as arguments, so the built
      # gate runs against fixtures (checks.pim-sync-secret-gate-selftest).
      # Every path is checked for existence BEFORE any placeholder is
      # read: a render defect hiding behind a pending placeholder must
      # still fail loudly.
      gateFiles = [
        config.sops.secrets.pim_sync_oauth_client_secret.path
        config.sops.templates."pim-sync-dav-env".path
        config.sops.secrets.pim_sync_token_personal.path
        config.sops.secrets.pim_sync_token_work.path
        config.sops.secrets.pim_sync_token_personal_calendar.path
        config.sops.secrets.pim_sync_token_work_calendar.path
      ];
      secretGate = pkgs.writeShellApplication {
        name = "pim-sync-secret-gate";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
        text = ''
          set -euo pipefail
          missing=0
          for f in "$@"; do
            if [ ! -f "$f" ]; then
              echo "pim-sync: sops material MISSING: $f (render defect, not an owner gate)" >&2
              missing=1
            fi
          done
          [ "$missing" -eq 0 ] || exit 255
          for f in "$@"; do
            if grep -q PLACEHOLDER "$f"; then
              echo "pim-sync: owner material pending ($f is PLACEHOLDER) — skipping this run"
              exit 1
            fi
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
            # Dashboard bearer token (fleet rows 2026-11-19): the RUNBOOK
            # path, read by pim-sync-ui at boot; rotation = sops redeploy
            # restart (ruling 2026-11-19 — restartUnits in sops.nix).
            pim_sync_ui_token.path = "/run/secrets/pim-sync/ui-token";
          };

          services.pim-sync = {
            environmentFile = config.sops.templates."pim-sync-dav-env".path;
            secretFile = config.sops.secrets.pim_sync_oauth_client_secret.path;
            tokenSeedDir = "/var/lib/pim-sync-seed";
            # Append-only run receipts (mesh invariant 5); upstream option
            # pinned since pim-sync 74bf91a. Receipts write only on real
            # sync runs - a dry-run writes nothing (upstream e2e pin).
            receiptsDir = "/var/lib/pim-sync/receipts";
          };

          # docs/agents/integration-registry.md step 5: OnFailure Discord
          # routing (upstream sets the start-limit bounds itself).
          systemd.services.pim-sync = {
            inherit onFailure;
            serviceConfig = {
              # Order matters: the ExecCondition gate runs FIRST (skip
              # while placeholders remain), then seed, then the shape
              # check (which only passes once real material exists).
              ExecCondition = [ "${lib.getExe secretGate} ${lib.concatStringsSep " " gateFiles}" ];
              # mkAfter, not a plain definition: this file's config sorts
              # BEFORE the module it imports, so a plain list lands the
              # shape check ahead of upstream's seed script (caught by
              # checks.pim-sync-secret-gate-selftest).
              ExecStartPre = lib.mkAfter [ (lib.getExe configCheck) ];
              # Dry-run cap aborts (exit 3) are INFORMATIONAL: the guard
              # stops before any write and the run's whole value is its
              # projected-change report. The flag default is 50 and a
              # first projection against a fresh book exceeds it by
              # design, so without this the dry-run window would alert
              # every 5 minutes. Live keeps exit 3 a FAILURE (a cap abort
              # there means writes were refused).
              SuccessExitStatus = lib.mkIf (!cfg.live) [ 3 ];
            };
          };

          # The ui unit is the upstream module's; this layer ONLY adds the
          # placeholder-token ExecStartPre guard. Gated on dashboard.enable
          # TOO (not just the token file): the dormant shape must not
          # synthesize an ExecStart-less unit shell. authTokenFile != null
          # is guaranteed for every non-loopback bind by the upstream
          # assertion, and loopback+token binds opt into the guard too —
          # a placeholder is a weak password on ANY bind.
          systemd.services.pim-sync-ui =
            lib.mkIf (cfg.dashboard.enable && cfg.dashboard.authTokenFile != null)
              {
                # ioTier.background (BE/6): the ui unit is boot-gated
                # (multi-user.target), so io-tier-coverage-audit demands a
                # fragment — the dashboard reads small textfiles on 15s pollers,
                # textbook background class.
                # Bind address is the NetBird IP: start after the daemon so
                # the first start does not fail on a missing address and lean
                # on Restart=on-failure. wants (not requires): a detached
                # NetBird degrades to bind retries, never a dead dependency.
                after = [ "netbird-evox2.service" ];
                wants = [ "netbird-evox2.service" ];
                serviceConfig = lib.mkMerge [
                  ioTier.background
                  { ExecStartPre = [ (lib.getExe uiTokenCheck) ]; }
                ];
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
