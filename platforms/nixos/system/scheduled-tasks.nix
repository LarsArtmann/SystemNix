# Scheduled tasks for NixOS using systemd timers
{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (config.users) primaryUser;
  uid = builtins.toString config.users.users.${primaryUser}.uid;
  inherit (import ../../../lib/default.nix lib) harden onFailure;

  # tmp-cleanup script text — hoisted here (NOT inline in the unit) so the
  # eval-time assertion below can prove the systemd-private-* exclusion
  # survives refactors. A store-path ExecStart is invisible to cross-module
  # audits (tmp-cleaner-audit.nix); this text is the one thing eval CAN see.
  tmpCleanupText = ''
    THRESHOLD_MIN=240 # 4 hours — active builds touch files constantly

    # -x prevents crossing into bind-mounted filesystems under /tmp
    before_kb=$(du -skx /tmp 2>/dev/null | cut -f1 || true)
    before_kb=''${before_kb:-0}

    removed=0
    # Only top-level non-dotfile entries — dotfiles (.X11-unix, .font-unix,
    # lock files) are protected. Per-entry descendant check prevents
    # removing dirs that contain recently-touched files (active builds
    # writing into a dir created hours ago: dir mtime stays old but file
    # mtimes are fresh). This is MORE conservative than cleanOnBoot (which
    # wipes everything on reboot). -xdev prevents find from descending
    # into mount points on other filesystems (defense-in-depth).
    for entry in /tmp/*; do
      [ -e "$entry" ] || continue
      [ -L "$entry" ] && continue  # never follow symlinks
      [ -S "$entry" ] && continue  # skip sockets
      [ -p "$entry" ] && continue  # skip named pipes
      case "$entry" in
        # systemd-managed PrivateTmp instance dirs are live service
        # infrastructure, not stale tmp: deleting the backing dir
        # invalidates the private /tmp mount inside the unit's
        # namespace, and forgejo then failed EVERY mirror sync for
        # 12 days with "open /tmp/forgejo-clone-credentials-N: no
        # such file or directory" (2026-08-18..30). systemd's own
        # tmpfiles-clean excludes them; this script must too. The
        # mtime check below cannot protect them — an idle or
        # already-broken service writes nothing into its private
        # tmp for hours, which is exactly the stale profile this
        # script targets.
        /tmp/systemd-private-*) continue ;;
      esac
      # If ANY descendant was touched in the last THRESHOLD_MIN, the
      # entry is active — skip it.
      if find "$entry" -xdev -mmin "-$THRESHOLD_MIN" -print -quit 2>/dev/null | grep -q .; then
        continue
      fi
      # rm errors are non-fatal, but NEVER silent (2026-10-01 class: root
      # without CAP_DAC_OVERRIDE cannot unlink inside foreign-owned
      # non-writable dirs, and the old `2>/dev/null || true` suppressed
      # every EACCES — stale root/nixbld residue stood while /tmp hit
      # 100%). A failed removal now logs a WARN naming the entry, so the
      # residue class is journal-visible (StandardError=journal) instead of
      # discoverable only at ENOSPC.
      if rm -rf --one-file-system -- "$entry" 2>/dev/null; then
        removed=$((removed + 1))
      else
        echo "tmp-cleanup WARN: could not remove $entry (permission/IO — foreign-owned residue class; unit needs CAP_DAC_OVERRIDE+CAP_FOWNER, see docs/todo/services.md tmp-cleanup row)" >&2
      fi
    done

    after_kb=$(du -skx /tmp 2>/dev/null | cut -f1 || true)
    after_kb=''${after_kb:-0}
    freed_kb=$((before_kb - after_kb))
    freed_human=$(numfmt --to=iec --suffix=B "$((freed_kb * 1024))" 2>/dev/null || echo "''${freed_kb}KB")
    echo "tmp-cleanup: removed $removed stale entries, freed $freed_human from /tmp"
  '';
in
{
  # Eval-time self-check on the hoisted text above: removing the exclusion
  # must fail `nix flake check`, not wait for the next 12-day outage
  # (2026-08-18..30: forgejo 16,318 mirror errors, discordsync 550 attachment
  # download failures, paperless celery, immich-ml — full story in
  # modules/nixos/services/tmp-cleaner-audit.nix).
  assertions = [
    {
      assertion = lib.hasInfix "systemd-private-*) continue" tmpCleanupText;
      message = ''
        tmp-cleanup guard: the systemd-private-* exclusion was removed from
        the tmp-cleanup script text (platforms/nixos/system/scheduled-tasks.nix).
        Those dirs are systemd PrivateTmp backing infrastructure: deleting one
        unlinks the bind-mount source, and every file creation inside the
        unit's private /tmp then fails ENOENT — self-perpetuating, because a
        broken service writes nothing and its dir always profiles as stale.
        Restore the case-arm exclusion (tests/test-tmp-cleanup.nix asserts the
        behavior). See docs/agents/systemd.md "NEVER let any /tmp cleaner touch
        systemd-private-*".
      '';
    }
  ];

  # tmpfiles-clean CANTCREAT diagnosis (2026-10-23, task queue): the
  # 2026-10-20 15:13 run (15 min after the incident-era 14:58 boot) failed
  # status=73/CANTCREAT with NO failing line at the default log level and
  # has NOT recurred (10-21/22/23 runs all green), so a manual verbose
  # rerun today would pass and prove nothing. Instead the NEXT failure
  # captures its own evidence: OnFailure triggers a debug-level rerun of
  # the identical clean pass, and systemd-tmpfiles at debug level logs
  # every rule/path it processes - the journal then names the exact
  # un-creatable path (the ask of the original diagnosis row).
  # systemd-tmpfiles-clean is upstream-shipped (not a config.systemd.services
  # entry), so the OnFailure arms via a DROP-IN — see the
  # systemd.services.systemd-tmpfiles-clean block below for why
  # environment.etc."systemd/system/…" must NOT be used (2026-10-23: it was a
  # silent no-op, then a hard build failure).
  systemd = {
    # NOT environment.etc."systemd/system/…": /etc/systemd/system is a symlink
    # to /etc/static/systemd/system, whose systemd/system is itself a symlink
    # to the immutable system-units store path, so the etc builder cannot mkdir
    # inside it. Before that became a hard build failure it was a SILENT
    # NO-OP — verifiable on gen 939, where
    # /etc/systemd/system/systemd-tmpfiles-clean.service.d did not exist, i.e.
    # the CANTCREAT self-diagnosis this block exists for never armed.
    # overrideStrategy="asDropin" emits
    # systemd-tmpfiles-clean.service.d/overrides.conf, which systemd MERGES
    # with the packaged unit (a plain systemd.services entry would write a
    # unit file with no ExecStart, shadowing the real one).
    services.systemd-tmpfiles-clean = {
      overrideStrategy = "asDropin";
      unitConfig.OnFailure = "tmpfiles-clean-debug.service";
    };

    timers = {
      crush-update-providers = {
        description = "Daily Crush AI provider update";
        timerConfig = {
          OnCalendar = "00:00";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
        wantedBy = [ "timers.target" ];
      };

      blocklist-auto-update = {
        description = "Weekly blocklist hash update";
        timerConfig = {
          OnCalendar = "Mon *-*-* 04:00";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        wantedBy = [ "timers.target" ];
      };

      service-health-check = {
        description = "Service health check";
        timerConfig = {
          OnCalendar = "*:0/15";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
        wantedBy = [ "timers.target" ];
      };

      rust-target-cleanup = {
        description = "Weekly Rust target/ cleanup (dirs >2GB)";
        timerConfig = {
          OnCalendar = "Sun *-*-* 05:00";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        wantedBy = [ "timers.target" ];
      };

      stale-lsp-cleanup = {
        description = "Kill stale LSP processes (gopls, etc.) older than 5min — runs every 5min";
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "5min";
          AccuracySec = "30s";
        };
        wantedBy = [ "timers.target" ];
      };

      disk-growth-check = {
        description = "Daily disk growth trend check — alert if /data grows >5G in 24h";
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        wantedBy = [ "timers.target" ];
      };

      nix-build-cleanup = {
        description = "Cleanup of orphaned Nix build sandboxes in /nix/var/nix/builds";
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "4h";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
        wantedBy = [ "timers.target" ];
      };

      tmp-cleanup = {
        description = "Remove stale entries in /tmp older than 4 hours";
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "4h";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
        wantedBy = [ "timers.target" ];
      };
    };

    services.tmpfiles-clean-debug = {
      description = "Debug-level re-run of systemd-tmpfiles --clean to name the path that made systemd-tmpfiles-clean fail (CANTCREAT diagnosis)";
      serviceConfig = {
        Type = "oneshot";
        # Boot-order correlation is the leading candidate (a tmpfiles rule
        # touching a hot-tier/DAS path in the post-incident boot sequence),
        # so the rerun must also survive a wedged path without hanging a
        # failure chain indefinitely.
        TimeoutStartSec = "10min";
        Environment = [ "SYSTEMD_LOG_LEVEL=debug" ];
        ExecStart = "${pkgs.systemd}/bin/systemd-tmpfiles --clean";
      };
    };

    services = {
      # Reusable failure notification template — use via `OnFailure = "notify-failure@%n.service"`
      "notify-failure@" = {
        description = "Notify on failure of %i";
        serviceConfig = {
          Type = "oneshot";
          User = primaryUser;
          Environment = [
            "DISPLAY=:0"
            "WAYLAND_DISPLAY=wayland-1"
            "XDG_RUNTIME_DIR=/run/user/${uid}"
          ];
          ExecStart =
            let
              notifyFailure = pkgs.writeShellApplication {
                name = "notify-failure";
                runtimeInputs = [
                  pkgs.libnotify
                  pkgs.util-linux
                  pkgs.coreutils
                ];
                text = ''
                  UNIT="''${1:-unknown}"
                  # Rate-limit: ONE desktop notification per unit per hour —
                  # a crash-looping unit restarts every RestartUSec and must
                  # not become a popup storm (live 2026-09-29: gatus crash-
                  # loop = a critical popup every 5s for ~16h, un-silenceable
                  # because critical urgency bypasses DMS Do-Not-Disturb).
                  # Suppressed firings still land in the journal via logger.
                  STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/notify-failure"
                  mkdir -p "$STATE_DIR"
                  STATE_FILE="$STATE_DIR/''${UNIT//\//_}.last"
                  NOW=$(date +%s)
                  LAST=$(stat -c %Y "$STATE_FILE" 2>/dev/null || echo 0)
                  if [ $(( NOW - LAST )) -ge 3600 ]; then
                    # -u normal, NEVER critical: critical urgency bypasses
                    # DMS Do-Not-Disturb, which made DND unable to silence
                    # failure storms (2026-09-29 movie-night incident).
                    notify-send -u normal "Scheduled task failed" "$UNIT — check journalctl -u $UNIT" 2>/dev/null || \
                      logger -t "$UNIT" -p user.err "Scheduled task failed — check journalctl -u $UNIT"
                    touch "$STATE_FILE"
                  else
                    logger -t "$UNIT" -p user.info "Scheduled task failed — desktop notification suppressed (rate limit 1/h) — check journalctl -u $UNIT"
                  fi
                '';
              };
            in
            "${notifyFailure}/bin/notify-failure %i";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      # Discord path for P0 units — wire via lib onFailureP0 (= the desktop
      # toast of notify-failure@ PLUS this). The 2026-10-12 8-min
      # sole-resolver outage's ONLY signal was one rate-limited normal-
      # urgency desktop toast (DND-suppressible, and the desktop shares the
      # failure domain with the units it watches); dnsblockd / gatus /
      # signoz / clickhouse additionally page the Discord webhook the gatus
      # checks already use — DIRECTLY, not via gatus, because gatus is
      # itself P0 (its 2026-10-12 OIDC-gate death left its own checks
      # unexecuted for the whole window). The webhook arrives via the
      # dedicated sops template notify-failure-p0-env (ONLY
      # DISCORD_WEBHOOK_URL — tq-agent-pool-env doctrine: a multi-key env
      # file must not leak into a unit that fires for arbitrary failing
      # units).
      "notify-failure-p0@" = {
        description = "Notify Discord on failure of %i (P0 units)";
        serviceConfig = {
          Type = "oneshot";
          User = primaryUser;
          # Webhook env rides the dedicated sops template. Optional (empty
          # list) when sops-nix isn't loaded at all — minimal VM fixtures
          # import this platform file without it; the script then logs the
          # missing-DISCORD_WEBHOOK_URL warning and exits 0. On a real host
          # with the unit, sops.nix always renders the template (its
          # condition keys on this very unit's existence).
          EnvironmentFile = lib.optionals (
            ((config.sops or { }).templates or { }) ? "notify-failure-p0-env"
          ) [ config.sops.templates."notify-failure-p0-env".path ];
          ExecStart =
            let
              notifyFailureP0 = pkgs.writeShellApplication {
                name = "notify-failure-p0";
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.util-linux
                  pkgs.curl
                ];
                text = ''
                  UNIT="''${1:-unknown}"
                  # Rate-limit: ONE Discord post per unit per hour, same
                  # containment as the desktop toast in notify-failure@ (a
                  # crash-loop restarts every RestartUSec and must not
                  # webhook-storm). The slot is reserved BEFORE the post so a
                  # Discord-side outage cannot turn the next failure into a
                  # burst; suppressed/failed sends still land in the journal
                  # via logger.
                  STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/notify-failure-p0"
                  mkdir -p "$STATE_DIR"
                  STATE_FILE="$STATE_DIR/''${UNIT//\//_}.last"
                  NOW=$(date +%s)
                  LAST=$(stat -c %Y "$STATE_FILE" 2>/dev/null || echo 0)
                  if [ $(( NOW - LAST )) -lt 3600 ]; then
                    logger -t "$UNIT" -p user.info "P0 unit failure, Discord notify suppressed (rate limit 1/h), check journalctl -u $UNIT"
                    exit 0
                  fi
                  if [ -z "''${DISCORD_WEBHOOK_URL:-}" ]; then
                    logger -t "$UNIT" -p user.err "P0 unit failure, DISCORD_WEBHOOK_URL missing (sops template notify-failure-p0-env not rendered?), check journalctl -u $UNIT"
                    exit 0
                  fi
                  touch "$STATE_FILE"
                  HOST=$(uname -n)
                  # ASCII-only script body: the writeShellApplication shellcheck
                  # stage prints the file whenever it has a finding, and its
                  # output encoder dies on non-ASCII text under the build
                  # locale (a U+2014 em dash in this body killed the build,
                  # 2026-10-20). Backticks are likewise dropped from the
                  # payload: backticks inside the single-quoted printf format
                  # trip SC2016, which is exactly what makes shellcheck print
                  # the file at all.
                  PAYLOAD=$(printf '{"content":"P0 unit FAILED on %s: %s (check journalctl -u %s; notify-failure-p0, rate limit 1/h)"}' "$HOST" "$UNIT" "$UNIT")
                  # 3 attempts x 10s cap: a failure during boot (link not yet
                  # up) still lands once the network arrives; a dead network
                  # exhausts in ~35s and logs. Best-effort by contract, a
                  # notifier must never present ITSELF as a failed unit.
                  for _ in 1 2 3; do
                    if curl -fsS --max-time 10 -H 'Content-Type: application/json' -d "$PAYLOAD" "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1; then
                      logger -t "$UNIT" -p user.info "P0 unit failure, Discord notify sent, check journalctl -u $UNIT"
                      exit 0
                    fi
                    sleep 5
                  done
                  logger -t "$UNIT" -p user.err "P0 unit failure, Discord notify FAILED after 3 attempts (webhook unreachable?), check journalctl -u $UNIT"
                  exit 0
                '';
              };
            in
            "${notifyFailureP0}/bin/notify-failure-p0 %i";
          TimeoutSec = "90s";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      crush-update-providers = {
        description = "Update Crush AI providers";
        inherit onFailure;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe' pkgs.nur.repos.charmbracelet.crush "crush"} update-providers";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      blocklist-auto-update = {
        description = "Download blocklists and update hashes in config";
        inherit onFailure;
        # The script is only git, nix and text tools, and a system unit gets
        # NO coreutils/gnugrep from systemd's default PATH: the 2026-11-23 run
        # died before the first hash (its `git ls-remote` was rewritten to
        # SSH by the owner's global insteadOf rule and the unit has no ssh;
        # the script now makes that lookup ignore the global git config, and
        # its grep/sed/head/mktemp calls need the packages listed here).
        path = [
          pkgs.coreutils
          pkgs.git
          pkgs.gnugrep
          pkgs.nix
          pkgs.gawk
          pkgs.gnused
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart =
            let
              # Intentional TREE access (nix-native plan T8.7, 2026-11-08):
              # the unit's WorkingDirectory below points into the LIVE
              # SystemNix checkout — the script commits blocklist-hash
              # updates back to the repo it reads config from. Do NOT
              # "hermeticize" by copying the tree into the closure; this
              # is the documented counter-example to the writeShellApplication
              # migration wave (the script BYTES are store-pinned via
              # readFile, the WORKING DIRECTORY is deliberately live).
              dnsUpdate = pkgs.writeShellApplication {
                name = "dns-update";
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.git
                  pkgs.gnugrep
                  pkgs.nix
                  pkgs.gawk
                  pkgs.gnused
                ];
                text = builtins.readFile ../../../scripts/dns-update.sh;
              };
            in
            "${dnsUpdate}/bin/dns-update";
          WorkingDirectory = "/home/${primaryUser}/projects/SystemNix";
          User = primaryUser;
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      service-health-check = {
        description = "Check critical services and notify on failure";
        inherit onFailure;
        path = [
          pkgs.systemd
          pkgs.libnotify
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart =
            let
              criticalSystemServices = [
                "caddy"
                "dnsblockd"
                "postgresql"
              ];
              # Intentionally-gated critical services: down + gate marker
              # absent = EXPECTED (report-only, never fails the unit — the
              # 2026-09-09 chronic-FAIL doctrine applied 2026-10-08 with the
              # owner's "forgejo is not ready yet" confirmation: forgejo stays
              # subvol-gated until the migration finalizes, and a per-tick
              # FAIL keeps service-health-check failed + opens deploy exit-4
              # windows for a KNOWN state). Marker present + down = real
              # failure. Marker mirrors forgejo.nix's subvolMigratedMarker
              # (ConditionPathExists semantics: unit runs only once it
              # exists). "or" chain covers a missing forgejo module.
              gatedSystemServices = [
                {
                  name = "forgejo";
                  marker = "${config.services.forgejo.stateDir or "/var/lib/forgejo"}/.subvol-migrated";
                }
              ];
              ignoredFailedServices = [
                "session-*"
                "user@*"
              ];
              # `|| true`: writeShellApplication runs with errexit — a bare
              # failing check_service kills the script before the FAILED
              # report or notify-send ever runs (2026-10-08: the checker died
              # silently at the gated-down forgejo, 6s of retries then exit 1
              # with zero output, because of exactly this). Failures must
              # accumulate in FAILED and reach the report.
              checkBlock = svc: "check_service ${svc} || true";
              gatedBlock = { name, marker }: "check_gated_service ${name} ${marker} || true";
              ignorePattern = builtins.concatStringsSep " | " ignoredFailedServices;
              healthCheck = pkgs.writeShellApplication {
                name = "service-health-check";
                runtimeInputs = [
                  pkgs.systemd
                  pkgs.libnotify
                  pkgs.coreutils
                  pkgs.gnugrep
                  pkgs.gawk
                ];
                text = ''
                  export DISPLAY=:0
                  export WAYLAND_DISPLAY=wayland-1
                  XDG_RUNTIME_DIR=/run/user/$(id -u)
                  export XDG_RUNTIME_DIR

                  STATE_DIR="$HOME/.cache/service-health-check"
                  # Failure ledger: one file per failed unit, "<strikes> <failure epoch>".
                  LEDGER_DIR="$STATE_DIR/failures"
                  NOTIFY_STATE="$STATE_DIR/last-notified-failed"
                  # A first failure older than this is FAILED without a second run: nothing
                  # retried it for a day, so its retry is not what the next hours bring.
                  ACUTE_MAX_AGE_SECONDS=86400
                  mkdir -p "$LEDGER_DIR"

                  FAILED=""
                  # Space-delimited unit ids already in FAILED (exact-token membership test).
                  FAILED_UNITS=""
                  PENDING=""
                  # Space-delimited "<scope>:<unit>" keys examined this run; a ledger file
                  # whose key is absent here belongs to a unit that is no longer failed.
                  OBSERVED=""
                  GATED=""
                  TOTAL=0
                  NOW_EPOCH="$(date +%s)"

                  fail() {
                      FAILED="$FAILED\n  $1"
                  }

                  pend() {
                      PENDING="$PENDING\n  $1"
                  }

                  # "$1" is the manager that owns the unit: "system" or "user".
                  unit_prop() {
                      if [ "$1" = "user" ]; then
                          systemctl --user show "$2" -p "$3" --value 2>/dev/null || true
                      else
                          systemctl show "$2" -p "$3" --value 2>/dev/null || true
                      fi
                  }

                  unit_active() {
                      if [ "$1" = "user" ]; then
                          systemctl --user is-active --quiet "$2" 2>/dev/null
                      else
                          systemctl is-active --quiet "$2" 2>/dev/null
                      fi
                  }

                  # One unit id per line, of every failed service of the given manager.
                  list_failed() {
                      if [ "$1" = "user" ]; then
                          systemctl --user --failed --no-legend --no-pager --plain --type=service 2>/dev/null | awk '{print $1}'
                      else
                          systemctl --failed --no-legend --no-pager --plain --type=service 2>/dev/null | awk '{print $1}'
                      fi
                  }

                  check_service() {
                      TOTAL=$((TOTAL + 1))
                      # Retry up to 3 times with 2s pauses: services may be restarting during
                      # a deploy (activating/reloading state).
                      for _attempt in 1 2 3; do
                          if systemctl is-active --quiet "$1" 2>/dev/null; then
                              return 0
                          fi
                          sleep 2
                      done
                      FAILED_UNITS="$FAILED_UNITS $1.service"
                      fail "$1.service"
                      return 1
                  }

                  # Gated critical service: down + condition marker absent = expected-by-design
                  # (report in GATED, never fail); marker present + down = genuine regression
                  # (fail like any other).
                  check_gated_service() {
                      TOTAL=$((TOTAL + 1))
                      if systemctl is-active --quiet "$1" 2>/dev/null; then
                          return 0
                      fi
                      if [ ! -e "$2" ]; then
                          GATED="$GATED\n  $1 (gated: $2 absent)"
                          return 0
                      fi
                      FAILED_UNITS="$FAILED_UNITS $1.service"
                      fail "$1.service"
                      return 1
                  }

                  # systemd's failed state is a latch, not a severity: a oneshot that exited
                  # non-zero once looks exactly like one that has failed for weeks, and the
                  # latch holds until a run succeeds. What separates the two is whether
                  # anything retries the unit on its own.
                  #   - No trigger (a daemon, an activation-only oneshot) or no trigger that
                  #     is active: nothing retries it, so it is FAILED at once.
                  #   - An active trigger (timer, path): the FIRST failure is acute, reported
                  #     as PENDING in the journal only. The unit's own OnFailure hook already
                  #     alerted for it and its next run may heal it. Found failed again after
                  #     the trigger re-fired, the retry did not help: FAILED, until a run
                  #     succeeds.
                  # systemd keeps no failure count, and its timestamps cannot rebuild one:
                  # after a retry both LastTriggerUSec and InactiveEnterTimestamp belong to
                  # the newest run, and a sub-second run shares the trigger's second. So the
                  # count lives here: a failure epoch not seen before is one more strike.
                  classify_failure() {
                      local scope="$1" unit="$2" label="$3"
                      local trigger failed_at failed_epoch ledger strikes seen_epoch retry_owed trigger_unit
                      OBSERVED="$OBSERVED $scope:$unit"
                      FAILED_UNITS="$FAILED_UNITS $unit"
                      trigger="$(unit_prop "$scope" "$unit" TriggeredBy)" || true
                      if [ -z "$trigger" ]; then
                          fail "$unit ($label)"
                          return 0
                      fi
                      retry_owed=false
                      # TriggeredBy is a space-separated list: any active trigger owes a retry.
                      while IFS= read -r trigger_unit; do
                          if [ -n "$trigger_unit" ] && unit_active "$scope" "$trigger_unit"; then
                              retry_owed=true
                              break
                          fi
                      done <<< "$(printf '%s' "$trigger" | tr ' ' '\n')"
                      if [ "$retry_owed" = false ]; then
                          fail "$unit ($label)"
                          return 0
                      fi
                      failed_at="$(unit_prop "$scope" "$unit" InactiveEnterTimestamp)" || true
                      # An empty timestamp parses as midnight today, which is a plausible
                      # lie: fail closed instead.
                      if [ -z "$failed_at" ]; then
                          fail "$unit ($label)"
                          return 0
                      fi
                      failed_epoch="$(date -d "$failed_at" +%s 2>/dev/null)" || true
                      if [ -z "$failed_epoch" ]; then
                          fail "$unit ($label)"
                          return 0
                      fi
                      ledger="$LEDGER_DIR/$scope:$unit"
                      strikes=0
                      seen_epoch=""
                      if [ -f "$ledger" ]; then
                          read -r strikes seen_epoch < "$ledger" || {
                              strikes=0
                              seen_epoch=""
                          }
                      fi
                      case "$strikes" in
                          "" | *[!0-9]*)
                              strikes=0
                              seen_epoch=""
                              ;;
                      esac
                      if [ "$failed_epoch" != "$seen_epoch" ]; then
                          strikes=$((strikes + 1))
                          ledger_write "$ledger" "$strikes $failed_epoch"
                      fi
                      if [ "$strikes" -eq 1 ] && [ "$NOW_EPOCH" -lt $((failed_epoch + ACUTE_MAX_AGE_SECONDS)) ]; then
                          pend "$unit ($label, timer retry pending)"
                      else
                          fail "$unit ($label)"
                      fi
                  }

                  # A ledger that cannot be written costs one check cycle of classification
                  # (the next run starts from the stale file), never the report.
                  ledger_write() {
                      if printf '%s\n' "$2" > "$1.tmp" && mv -f "$1.tmp" "$1"; then
                          return 0
                      fi
                      echo "WARN: could not update the failure ledger for $1" >&2
                  }

                  # Every failed service of one manager that no check above already covered.
                  # Transient units (systemd-run: tests, soaks, one-off probes) belong to
                  # whoever ran them, not to the declared system, and never run again: a
                  # failed one is debris for its creator to reset, not a service down.
                  sweep_failed() {
                      local scope="$1" label="$2" unit
                      while IFS= read -r unit; do
                          [ -n "$unit" ] || continue
                          case "$unit" in
                              ${ignorePattern})
                                  ;;
                              *)
                                  case " $FAILED_UNITS " in
                                      *" $unit "*) ;;
                                      *)
                                          if [ "$(unit_prop "$scope" "$unit" Transient)" != "yes" ]; then
                                              classify_failure "$scope" "$unit" "$label"
                                          fi
                                          ;;
                                  esac
                                  ;;
                          esac
                      done < <(list_failed "$scope")
                  }

                  # === Critical system services: must be running ===
                  ${builtins.concatStringsSep "\n" (map checkBlock criticalSystemServices)}

                  # === Gated critical services: down is expected while the gate holds ===
                  ${builtins.concatStringsSep "\n" (map gatedBlock gatedSystemServices)}

                  # === Dynamic: every other failed system service ===
                  sweep_failed system "failed"

                  # === Dynamic: every failed user service ===
                  sweep_failed user "user, failed"

                  # A ledger entry whose unit is no longer failed had a successful run: its
                  # next failure starts a new episode.
                  for ledger in "$LEDGER_DIR"/*; do
                      [ -e "$ledger" ] || continue
                      case " $OBSERVED " in
                          *" $(basename "$ledger") "*) ;;
                          *) rm -f "$ledger" || true ;;
                      esac
                  done

                  # === Report ===
                  # Desktop notification, once per distinct set of FAILED units (owner
                  # directive 2026-11-24: never the same "Health Check: services down"
                  # notification stacked). The state file holds the member lines of the last
                  # notified set, which tells a NEW failure (popup, listing the whole current
                  # set) from a member recovering (journal only: good news is not a critical
                  # popup). The unit still exits 1 on every failing tick (journal + OnFailure
                  # + deploy exit-4 semantics unchanged).
                  if [ -n "$FAILED" ]; then
                      current="$(echo -e "$FAILED" | sort)"
                      notified="$(cat "$NOTIFY_STATE" 2>/dev/null || true)"
                      new_failure=false
                      while IFS= read -r member; do
                          [ -n "$member" ] || continue
                          if ! grep -qxF -- "$member" <<< "$notified"; then
                              new_failure=true
                          fi
                      done <<< "$current"
                      if [ "$new_failure" = true ]; then
                          notify-send -u critical "Health Check: services down" "$(echo -e "$FAILED")" 2>/dev/null || true
                          echo "NOTIFIED: a failed unit that was not notified before"
                      else
                          echo "NOTIFY-SKIPPED: every failed unit was already notified (desktop dedup)"
                      fi
                      printf '%s\n' "$current" > "$NOTIFY_STATE"
                      echo "FAILED:$(echo -e "$FAILED")"
                      if [ -n "$PENDING" ]; then
                          echo -e "PENDING (first failure, retry owed on its trigger, its own OnFailure hook alerted):$PENDING"
                      fi
                      if [ -n "$GATED" ]; then
                          echo -e "GATED (expected down):$GATED"
                      fi
                      exit 1
                  else
                      if [ -f "$NOTIFY_STATE" ]; then
                          rm -f "$NOTIFY_STATE"
                          echo "RECOVERED: failure set cleared (dedup state reset)"
                      fi
                      echo "OK: $TOTAL/$TOTAL critical services active, no failed services"
                      if [ -n "$PENDING" ]; then
                          echo -e "PENDING (first failure, retry owed on its trigger, its own OnFailure hook alerted):$PENDING"
                      fi
                      if [ -n "$GATED" ]; then
                          echo -e "GATED (expected down):$GATED"
                      fi
                      exit 0
                  fi
                '';
              };
            in
            "${healthCheck}/bin/service-health-check";
          User = primaryUser;
          Environment = [
            "DISPLAY=:0"
            "WAYLAND_DISPLAY=wayland-1"
            "XDG_RUNTIME_DIR=/run/user/${uid}"
          ];
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      rust-target-cleanup = {
        description = "Weekly Rust target/ cleanup (dirs >2GB)";
        inherit onFailure;
        serviceConfig =
          harden {
            MemoryMax = "256M";
            ProtectHome = "read-only";
            ReadWritePaths = [ "/home/${primaryUser}/projects" ];
          }
          // {
            Type = "oneshot";
            User = primaryUser;
            Environment = [
              "DISPLAY=:0"
              "WAYLAND_DISPLAY=wayland-1"
              "XDG_RUNTIME_DIR=/run/user/${uid}"
            ];
            ExecStart =
              let
                rustCleanup = pkgs.writeShellApplication {
                  name = "rust-target-cleanup";
                  runtimeInputs = [
                    pkgs.cargo-sweep
                    pkgs.findutils
                    pkgs.coreutils
                    pkgs.libnotify
                  ];
                  text = ''
                    SIZE_THRESHOLD_KB=$((2 * 1024 * 1024))
                    SEARCH_ROOTS=("/home/${primaryUser}/projects")
                    TOTAL_FREED_KB=0
                    CLEANED=0
                    SKIPPED=0
                    FAILED=0

                    log() { echo "[rust-target-cleanup] $*"; }

                    for root in "''${SEARCH_ROOTS[@]}"; do
                      [ -d "$root" ] || continue

                      while IFS= read -r target_dir; do
                        [ -d "$target_dir" ] || continue
                        dir_size_kb=$(du -sk "$target_dir" 2>/dev/null | cut -f1) || true || true

                        if [ -z "$dir_size_kb" ] || [ "$dir_size_kb" -lt "$SIZE_THRESHOLD_KB" ]; then
                          SKIPPED=$((SKIPPED + 1))
                          continue
                        fi

                        dir_size_human=$(numfmt --to=iec --suffix=B "$((dir_size_kb * 1024))")
                        project=$(dirname "$target_dir")

                        if [ -f "$project/Cargo.toml" ]; then
                          log "cargo-sweep --time 7d in $project ($dir_size_human)"
                          if cargo-sweep --time 7d --installed 2>/dev/null \
                             || cargo-sweep --time 7d; then
                            new_size_kb=$(du -sk "$target_dir" 2>/dev/null | cut -f1 || true)
                            new_size_kb=''${new_size_kb:-0}
                            freed_kb=$((dir_size_kb - new_size_kb))
                            TOTAL_FREED_KB=$((TOTAL_FREED_KB + freed_kb))
                            CLEANED=$((CLEANED + 1))
                            freed_human=$(numfmt --to=iec --suffix=B "$((freed_kb * 1024))")
                            log "Cleaned $project — freed $freed_human"
                          else
                            log "cargo-sweep failed for $project, falling back to full removal"
                            rm -rf "$target_dir"
                            TOTAL_FREED_KB=$((TOTAL_FREED_KB + dir_size_kb))
                            CLEANED=$((CLEANED + 1))
                            log "Fallback removed $target_dir — freed $dir_size_human"
                          fi
                        else
                          log "Removing orphaned target/ $target_dir ($dir_size_human)"
                          if rm -rf "$target_dir"; then
                            TOTAL_FREED_KB=$((TOTAL_FREED_KB + dir_size_kb))
                            CLEANED=$((CLEANED + 1))
                            log "Removed orphan $target_dir — freed $dir_size_human"
                          else
                            FAILED=$((FAILED + 1))
                            log "FAILED to remove $target_dir"
                          fi
                        fi
                      done < <(find "$root" \
                        -type d \
                        -name target \
                        -not -path '*/.*')
                    done

                    TOTAL_FREED_HUMAN=$(numfmt --to=iec --suffix=B "$((TOTAL_FREED_KB * 1024))")
                    log "Done: cleaned $CLEANED, skipped $SKIPPED (under 2GB), failed $FAILED, freed $TOTAL_FREED_HUMAN"

                    if [ "$CLEANED" -gt 0 ]; then
                      notify-send -u low \
                        "Rust target/ cleanup" \
                        "Cleaned $CLEANED projects, freed $TOTAL_FREED_HUMAN" 2>/dev/null || true
                    fi
                  '';
                };
              in
              "${rustCleanup}/bin/rust-target-cleanup";
            StandardOutput = "journal";
            StandardError = "journal";
          };
      };

      stale-lsp-cleanup = {
        description = "Kill stale LSP processes (gopls, etc.) running longer than 5min";
        inherit onFailure;
        serviceConfig =
          harden {
            MemoryMax = "128M";
            ProtectHome = "read-only";
          }
          // {
            Type = "oneshot";
            User = primaryUser;
            ExecStart =
              let
                lspCleanup = pkgs.writeShellApplication {
                  name = "stale-lsp-cleanup";
                  runtimeInputs = [
                    pkgs.procps
                    pkgs.coreutils
                  ];
                  text = ''
                    MAX_AGE_SECONDS=$((5 * 60))
                    LSP_PROCESS_NAMES=("gopls" "typescript-language-server" "vtsls" "rust-analyzer" "lua-language-server")
                    KILLED=0

                    for proc_name in "''${LSP_PROCESS_NAMES[@]}"; do
                      while IFS= read -r pid; do
                        [ -z "$pid" ] && continue
                        elapsed=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ') || true || true
                        [ -z "$elapsed" ] && continue
                        if [ "$elapsed" -gt "$MAX_AGE_SECONDS" ]; then
                          elapsed_m=$((elapsed / 60))
                          elapsed_s=$((elapsed % 60))
                          echo "Killing stale $proc_name (PID $pid, running ''${elapsed_m}m''${elapsed_s}s)"
                          kill "$pid" 2>/dev/null || true
                          KILLED=$((KILLED + 1))
                        fi
                      done < <(pgrep -u "$USER" "$proc_name" 2>/dev/null)
                    done

                    echo "Done: killed $KILLED stale LSP processes"
                  '';
                };
              in
              "${lspCleanup}/bin/stale-lsp-cleanup";
            StandardOutput = "journal";
            StandardError = "journal";
          };
      };

      nix-build-cleanup = {
        description = "Remove orphaned Nix build sandboxes (builder PID dead, no writes >1h)";
        inherit onFailure;
        serviceConfig =
          harden {
            # Build sandboxes are nixbld-owned (0700 dirs + read-only Go modcache
            # trees) — rm needs DAC override or every run dies EACCES (2026-09-06).
            CapabilityBoundingSet = "CAP_DAC_OVERRIDE";
            MemoryMax = "128M";
            ProtectHome = true;
            ReadWritePaths = [ "/nix/var/nix/builds" ];
          }
          // {
            Type = "oneshot";
            ExecStart =
              let
                buildCleanup = pkgs.writeShellApplication {
                  name = "nix-build-cleanup";
                  runtimeInputs = [
                    pkgs.findutils
                    pkgs.coreutils
                  ];
                  text = ''
                    BUILD_DIR="/nix/var/nix/builds"
                    [ -d "$BUILD_DIR" ] || exit 0

                    before_kb=$(du -sk "$BUILD_DIR" 2>/dev/null | cut -f1 || true)
                    before_kb=''${before_kb:-0}

                    # A sandbox is orphaned ONLY if its embedded daemon-builder PID
                    # is gone AND nothing in its tree was written in the last hour.
                    # The old top-level `-mmin +60` check murdered LIVE builds: the
                    # top dir's mtime freezes at creation while builds churn deep
                    # inside, so every >1h build (clickhouse: 2-4h at -j8) was
                    # rm -rf'd mid-build by this very service (2026-10-03: three
                    # builds killed at 03:20/07:24/11:25; nix then died with
                    # "opening directory"/"setting permissions" ENOENT races).
                    candidates=$(find "$BUILD_DIR" -maxdepth 1 -type d -name 'nix-*' -mmin +60 2>/dev/null || true)
                    for dir in $candidates; do
                      name=$(basename "$dir")
                      pid=''${name#nix-}
                      pid=''${pid%%-*}
                      if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
                        # Builder still alive = active build. Pid-recycle edge
                        # cases only ever DELAY cleanup, never kill a build.
                        echo "Skipping $name: builder PID $pid alive"
                        continue
                      fi
                      if [ -n "$(find "$dir" -mmin -60 -print -quit 2>/dev/null)" ]; then
                        echo "Skipping $name: writes within the last hour"
                        continue
                      fi
                      rm -rf "$dir"
                    done

                    after_kb=$(du -sk "$BUILD_DIR" 2>/dev/null | cut -f1 || true)
                    after_kb=''${after_kb:-0}
                    freed_kb=$((before_kb - after_kb))
                    freed_human=$(numfmt --to=iec --suffix=B "$((freed_kb * 1024))" 2>/dev/null || echo "''${freed_kb}KB")

                    orphan_count=$(find "$BUILD_DIR" -maxdepth 1 -type d -name 'nix-*' 2>/dev/null | wc -l)
                    echo "Cleaned orphaned build sandboxes — freed $freed_human, $orphan_count remaining"
                  '';
                };
              in
              "${buildCleanup}/bin/nix-build-cleanup";
            StandardOutput = "journal";
            StandardError = "journal";
          };
      };

      tmp-cleanup = {
        description = "Remove stale top-level entries in /tmp untouched for >4h";
        inherit onFailure;
        serviceConfig = lib.mkMerge [
          (harden {
            MemoryMax = "128M";
            ProtectHome = true;
            PrivateTmp = false; # MUST see the real /tmp, not a private tmpfs
            ReadWritePaths = [ "/tmp" ];
            # Root WITHOUT capabilities cannot unlink inside foreign-owned
            # non-writable dirs (DAC checks apply to uid 0 too once
            # CAP_DAC_OVERRIDE is dropped) — the unit's whole job is deleting
            # stale nixbld/root build residue, so it carries the two unlink
            # capabilities (bun-memory-watchdog precedent). harden{}'s
            # mkDefault' empty bounding set loses to this direct key.
            CapabilityBoundingSet = "CAP_DAC_OVERRIDE CAP_FOWNER";
          })
          {
            Type = "oneshot";
            ExecStart =
              let
                tmpCleanup = pkgs.writeShellApplication {
                  name = "tmp-cleanup";
                  runtimeInputs = [
                    pkgs.findutils
                    pkgs.coreutils
                  ];
                  text = tmpCleanupText;
                };
              in
              "${tmpCleanup}/bin/tmp-cleanup";
            StandardOutput = "journal";
            StandardError = "journal";
          }
        ];
      };

      disk-growth-check = {
        description = "Check /data disk growth trend and alert if >5G/day";
        inherit onFailure;
        # StateDirectory, NOT ReadWritePaths + preStart mkdir: systemd builds
        # the mount namespace BEFORE any ExecStartPre, so a ReadWritePaths
        # entry pointing at a missing dir aborts with status=226/NAMESPACE
        # and the in-unit mkdir can never create its own namespace path
        # (live bug: unit failed 226 on every run while /var/lib/disk-growth
        # was absent, blinding the /data growth alert for days). PID 1
        # creates StateDirectory dirs before namespace assembly.
        serviceConfig =
          harden {
            MemoryMax = "128M";
            ProtectHome = "read-only";
            StateDirectory = "disk-growth";
          }
          // {
            Type = "oneshot";
            ExecStart =
              let
                diskGrowth = pkgs.writeShellApplication {
                  name = "disk-growth-check";
                  runtimeInputs = [
                    pkgs.coreutils
                    pkgs.util-linux
                  ];
                  text = ''
                    STATE_DIR="/var/lib/disk-growth"
                    STATE_FILE="$STATE_DIR/last_usage_bytes"
                    THRESHOLD=$((5 * 1024 * 1024 * 1024))
                    MOUNT_POINT="/data"

                    # errexit+pipefail: `|| true` rescues a df failure so the
                    # empty-capture guard below stays REACHABLE and exits 1
                    # (absent /data is an alert, not a unit crash)
                    current_bytes=$(df --output=used --block-size=1 "$MOUNT_POINT" 2>/dev/null | tail -1 | tr -d ' ') || true

                    if [ -z "$current_bytes" ]; then
                      echo "ERROR: could not read disk usage for $MOUNT_POINT"
                      exit 1
                    fi

                    current_human=$(numfmt --to=iec --suffix=B "$current_bytes")
                    echo "Current /data usage: $current_human"

                    if [ -f "$STATE_FILE" ]; then
                      last_bytes=$(cat "$STATE_FILE")
                      delta=$((current_bytes - last_bytes))
                      # `--` is load-bearing: a SHRINKING delta is negative
                      # and numfmt parses a leading-dash arg as an unknown
                      # option — under errexit that exits 1 and fails the
                      # unit (found live by the guard-scripts VM test)
                      delta_human=$(numfmt --to=iec --suffix=B -- "$delta")

                      if [ "$delta" -gt "$THRESHOLD" ]; then
                        echo "WARNING: /data grew $delta_human in 24h (threshold: 5G)"
                        exit 1
                      else
                        echo "Growth: $delta_human in 24h (under 5G threshold)"
                      fi
                    else
                      echo "No previous measurement — recording baseline"
                    fi

                    mkdir -p "$STATE_DIR"
                    printf '%s' "$current_bytes" > "$STATE_FILE"
                  '';
                };
              in
              "${diskGrowth}/bin/disk-growth-check";
            StandardOutput = "journal";
            StandardError = "journal";
          };
      };
    };
  };
}
