# github-auto-assign — periodic GitHub issue/PR self-assignment.
#
# Every 6 hours, finds every OPEN issue and PR with NO assignee across ALL
# repos owned by the configured GitHub owner (gh search --owner) and assigns
# them to the authenticated account ("@me"). Forked repos are SKIPPED by
# default (excludeForks — a fork carries the upstream tracker, so
# self-assignment there is noise in the assigned-to-me view). Idempotent: a
# second run finds nothing to do because everything is now assigned.
#
#   - Runs as the primary user and reads the user's EXISTING gh CLI auth
#     (~/.config/gh/hosts.yml, 0600) — no new secret to provision. That is why
#     ProtectHome must be "read-only", not the harden{} default `true`.
#   - Backfill shape: the GitHub search API caps a single search at 1000
#     results. If the backlog exceeds that (1000 issues + 339 PRs at
#     bring-up, 2026-09-17), one run assigns what it sees and the NEXT run
#     picks up the remainder — self-converging by design.
#   - Failure paging is thresholded: OnFailure (Discord) fires only on
#     SYSTEMIC failure (search/fork-list fetch failed, ALL assignments
#     failed, or >=50% of a substantial run failed). Individual item
#     failures are WARN-logged and retried on the next tick — one
#     permanently-weird item must not page every 6h forever.
#   - No HTTP endpoint, so no Gatus check: failure alerting rides OnFailure
#     (Discord) + the system-health monitoredServices metric, per the
#     daemon-less-unit doctrine (cv-scan / backup-timer pattern).
_: {
  flake.nixosModules.github-auto-assign =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.github-auto-assign;
      primaryUser = config.users.primaryUser or "lars";
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ioTier
        ;

      script = pkgs.writeShellApplication {
        name = "github-auto-assign";
        runtimeInputs = [
          pkgs.gh
          pkgs.coreutils
        ];
        text = ''
          owner="''${GITHUB_AUTO_ASSIGN_OWNER:?GITHUB_AUTO_ASSIGN_OWNER is required}"
          limit="''${GITHUB_AUTO_ASSIGN_LIMIT:-1000}"
          dry_run="''${GITHUB_AUTO_ASSIGN_DRY_RUN:-}"
          exclude_forks="''${GITHUB_AUTO_ASSIGN_EXCLUDE_FORKS:-1}"

          assigned=0
          failed=0
          skipped=0

          fork_file=""
          cleanup() {
            if [ -n "$fork_file" ]; then
              rm -f "$fork_file"
            fi
          }
          trap cleanup EXIT

          if [ "$exclude_forks" = "1" ]; then
            fork_file="$(mktemp)" || exit 1
            if ! gh repo list "$owner" --fork --limit 1000 \
                --json nameWithOwner --jq '.[].nameWithOwner' > "$fork_file"; then
              echo "ERROR: gh repo list --fork failed (cannot honor excludeForks)" >&2
              exit 1
            fi
            echo "fork exclusion on: $(wc -l < "$fork_file") forked repos will be skipped"
          fi

          for kind in issue pr; do
            plural="''${kind}s"
            if ! urls="$(gh search "$plural" --owner "$owner" --state open \
                --no-assignee --archived=false --limit "$limit" \
                --json url --jq '.[].url' | sort)"; then
              echo "ERROR: gh search $plural failed" >&2
              exit 1
            fi
            if [ -z "$urls" ]; then
              echo "no unassigned open $plural in $owner's repos"
              continue
            fi
            count="$(printf '%s\n' "$urls" | wc -l)"
            echo "found $count unassigned open $plural"
            while IFS= read -r url; do
              [ -z "$url" ] && continue
              if [ -n "$fork_file" ]; then
                repo="$(printf '%s' "$url" | cut -d/ -f4-5)"
                if grep -qxF "$repo" "$fork_file"; then
                  skipped=$((skipped + 1))
                  continue
                fi
              fi
              if [ -n "$dry_run" ]; then
                echo "DRY-RUN would assign $kind: $url"
                assigned=$((assigned + 1))
                continue
              fi
              if gh "$kind" edit "$url" --add-assignee "@me" >/dev/null; then
                echo "assigned $kind: $url"
                assigned=$((assigned + 1))
              else
                echo "WARN: failed to assign $kind: $url" >&2
                failed=$((failed + 1))
              fi
              sleep 0.5
            done <<< "$urls"
          done

          echo "done: assigned=$assigned failed=$failed skipped-forks=$skipped"

          # OnFailure (Discord) pages only on SYSTEMIC failure: a failed
          # search/fork-list fetch (exits above), ALL assignments failing,
          # or >=50% of a substantial run failing. Individual failures are
          # WARN-logged and retried on the next timer tick.
          attempts=$((assigned + failed))
          if [ "$attempts" -gt 0 ] && [ "$assigned" -eq 0 ]; then
            echo "ERROR: all $attempts assignment attempts failed (systemic)" >&2
            exit 1
          fi
          if [ "$attempts" -ge 10 ] && [ "$failed" -ge $((attempts / 2)) ]; then
            echo "ERROR: $failed of $attempts assignments failed (>=50%, systemic)" >&2
            exit 1
          fi
        '';
      };
    in
    {
      options.services.github-auto-assign = {
        enable = lib.mkEnableOption "periodic self-assignment of unassigned GitHub issues/PRs";

        owner = lib.mkOption {
          type = lib.types.str;
          default = "LarsArtmann";
          description = "GitHub account whose OWNED repos are scanned.";
        };

        schedule = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 00/6:00:00";
          description = "OnCalendar schedule (default: every 6 hours).";
        };

        searchLimit = lib.mkOption {
          type = lib.types.ints.between 1 1000;
          default = 1000;
          description = "Per-kind search cap (GitHub API maximum is 1000).";
        };

        excludeForks = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Skip issues/PRs on forked repositories. A fork carries the
            UPSTREAM tracker, so self-assignment there is noise in the
            assigned-to-me view. Only stops FUTURE assignments —
            already-assigned fork items are left untouched.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.github-auto-assign = {
          description = "Assign unassigned open GitHub issues/PRs to ${cfg.owner}";
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = primaryUser;
              Group = "users";
              ExecStart = lib.getExe script;
              # First backfill run assigned ~1300 items at ~1s each (API
              # latency + politeness sleep) — far beyond the 3min manager
              # default (timeout-audit doctrine).
              TimeoutStartSec = "45min";
              Environment = [
                "GITHUB_AUTO_ASSIGN_OWNER=${cfg.owner}"
                "GITHUB_AUTO_ASSIGN_LIMIT=${toString cfg.searchLimit}"
                "GITHUB_AUTO_ASSIGN_EXCLUDE_FORKS=${if cfg.excludeForks then "1" else "0"}"
                "GH_NO_UPDATE_NOTIFIER=1"
                "GH_PROMPT_DISABLED=1"
              ];
            }
            (harden {
              # gh reads the user's 0600 ~/.config/gh/hosts.yml (existing gh
              # CLI auth — no new secret). Read-only keeps that one-way.
              ProtectHome = "read-only";
              MemoryMax = "256M";
            })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        systemd.timers.github-auto-assign = {
          description = "Every 6h: self-assign unassigned open GitHub issues/PRs";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.schedule;
            RandomizedDelaySec = "10min";
            # Catch up missed windows across reboots (btrbk doctrine).
            Persistent = true;
          };
        };

        # Daemon-less unit: no HTTP endpoint to probe, so monitoring is
        # OnFailure (Discord) + the system-health state metrics.
        services.system-health.extraMonitoredServices = lib.mkAfter [
          "github-auto-assign"
        ];
      };
    };
}
