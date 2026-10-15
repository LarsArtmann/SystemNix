# Post-crash calm gate — WAIT-loop barrier for post-crash resumable readers.
#
# Freeze-6 rule (a), task-queue item "post-crash resumable-reader pause
# automation": after a guard-killed crash, the recovery boot re-arms the
# catch-up fleet (crush-hot-db-migrate, discordsync-db-heal,
# hermes-perms-heal, migrate-rust-cache rsync) minutes after boot while the
# box is still storming — the deterministic amplifier behind freezes #19
# (re-fire 90 s into boot), #20, #22, #25 and #28. Instead of the manual
# SIGSTOP containment used live on 2026-10-06, this gate makes the gated
# units WAIT before their first run of the boot: they cannot start until
# `maintenance-entry-gate` admits (io-PSI some avg10 below the band AND no
# memory-emergency-guard trip within the window). Refusal is free — a
# skipped catch-up run converges later (timer refire, next deploy, next
# boot); a catch-up run inside the storm has killed the box seven times.
#
# The gate does NOT SIGSTOP anything (the freeze-26 ruling: no SIGSTOP of
# live processes outside owner-licensed containment) — it is pure start
# admission: a barrier unit the gated readers are Requires+After-ordered
# behind (see modules/nixos/services/post-crash-calm-gate.nix).
#
# exit 0 = calm, admit; exit 1 = still storming at the wait cap, refuse
# (loud: the gated unit fails its start job and alerts via OnFailure);
# exit 64 = usage error.
{
  writeShellApplication,
  coreutils,
  maintenance-entry-gate,
}:
writeShellApplication {
  name = "post-crash-calm-gate";
  runtimeInputs = [
    coreutils
  ];
  text = ''
    set -uo pipefail

    GATE_NAME="post-crash-calm-gate"
    PSI_MAX="40"
    TRIP_WINDOW_MIN="60"
    POLL_SECS="15"
    MAX_WAIT_MIN="60"
    MAX_WAIT_SECS=""
    # Fixture override for the selftest; production uses the packaged gate.
    ENTRY_GATE="''${POST_CRASH_CALM_GATE_ENTRY_GATE:-${maintenance-entry-gate}/bin/maintenance-entry-gate}"

    usage() {
      echo "usage: post-crash-calm-gate [--name LABEL] [--psi-max N] [--trip-window-min N]" >&2
      echo "                            [--poll-secs N] [--max-wait-min N] [--max-wait-secs N] [selftest]" >&2
      echo "  exit 0 = calm (admit), exit 1 = still storming at the wait cap (refuse)" >&2
      exit 64
    }

    while [ "$#" -gt 0 ]; do
      case "$1" in
      --name)
        [ "$#" -ge 2 ] || usage
        GATE_NAME=$2
        shift 2
        ;;
      --psi-max)
        [ "$#" -ge 2 ] || usage
        PSI_MAX=$2
        shift 2
        ;;
      --trip-window-min)
        [ "$#" -ge 2 ] || usage
        TRIP_WINDOW_MIN=$2
        shift 2
        ;;
      --poll-secs)
        [ "$#" -ge 2 ] || usage
        POLL_SECS=$2
        shift 2
        ;;
      --max-wait-min)
        [ "$#" -ge 2 ] || usage
        MAX_WAIT_MIN=$2
        shift 2
        ;;
      --max-wait-secs)
        [ "$#" -ge 2 ] || usage
        MAX_WAIT_SECS=$2
        shift 2
        ;;
      selftest)
        SELFTEST=1
        shift
        ;;
      *)
        usage
        ;;
      esac
    done

    if [ "''${SELFTEST:-0}" = "1" ]; then
      PASS=0
      EXPECT=5
      ok() {
        PASS=$((PASS + 1))
      }
      FIX=$(mktemp -d)
      trap 'rm -rf "$FIX"' EXIT

      FAKE="$FIX/fake-entry-gate"
      COUNT_FILE="$FIX/count"
      : >"$COUNT_FILE"
      # Fake entry gate: exits 1 until the counter file reaches the value in
      # $FAKE_ADMIT_AFTER (always set by the scenarios), then exits 0.
      # Heredoc body MUST sit flush-left (nix strips the common indent, and
      # the fake gate is executed directly, so `#!` must be at column 0);
      # `\$` keeps the counters/expansions for the fake gate's own runtime.
      cat >"$FAKE" <<FAKE_GATE
#!/bin/sh
n=\$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
n=\$((n + 1))
echo "\$n" >"$COUNT_FILE"
[ "\$n" -ge "\$FAKE_ADMIT_AFTER" ] && exit 0
echo "REFUSE: fake — invocation \$n" >&2
exit 1
FAKE_GATE
      chmod +x "$FAKE"
      export POST_CRASH_CALM_GATE_ENTRY_GATE="$FAKE"

      must_admit() {
        msg=$1
        shift
        if "$0" "$@" >/dev/null 2>&1; then
          ok
        else
          echo "FAIL: $msg must admit" >&2
          exit 1
        fi
      }
      must_refuse() {
        msg=$1
        shift
        if "$0" "$@" >/dev/null 2>&1; then
          echo "FAIL: $msg must refuse" >&2
          exit 1
        fi
        ok
      }

      # 1: calm on the first probe — single gate call, immediate admit.
      echo 999999 >"$COUNT_FILE"
      FAKE_ADMIT_AFTER=0 must_admit "selftest 1 (calm first probe)"

      # 2: never calm, zero wait cap — refuse without sleeping.
      echo 0 >"$COUNT_FILE"
      FAKE_ADMIT_AFTER=999999 must_refuse "selftest 2 (refuse at zero cap)"

      # 3: storming twice then calm — the wait loop polls and admits.
      echo 0 >"$COUNT_FILE"
      FAKE_ADMIT_AFTER=3 must_admit "selftest 3 (poll-then-admit)" --poll-secs 1 --max-wait-min 5

      # 4: calm only after the cap — refuse at the deadline.
      echo 0 >"$COUNT_FILE"
      FAKE_ADMIT_AFTER=999999 must_refuse "selftest 4 (refuse at wait cap)" --poll-secs 1 --max-wait-secs 3

      # 5: the packaged maintenance-entry-gate is the default entry gate and
      # is executable (wiring proof, not behavior).
      unset POST_CRASH_CALM_GATE_ENTRY_GATE
      if [ -x "''${POST_CRASH_CALM_GATE_ENTRY_GATE:-${maintenance-entry-gate}/bin/maintenance-entry-gate}" ]; then
        ok
      else
        echo "FAIL: selftest 5 (default entry gate missing/exec)" >&2
        exit 1
      fi

      echo "post-crash-calm-gate selftest: $PASS/$EXPECT scenarios passed"
      [ "$PASS" -eq "$EXPECT" ]
      exit $?
    fi

    start=$(date +%s)
    if [ -n "$MAX_WAIT_SECS" ]; then
      # Test/fixture granularity; production waits are minute-scaled.
      deadline=$((start + MAX_WAIT_SECS))
    else
      deadline=$((start + MAX_WAIT_MIN * 60))
    fi
    attempt=0
    while :; do
      attempt=$((attempt + 1))
      if "$ENTRY_GATE" --name "$GATE_NAME" --psi-max "$PSI_MAX" --trip-window-min "$TRIP_WINDOW_MIN"; then
        echo "ADMIT: $GATE_NAME calm after $attempt probe(s) ($(( $(date +%s) - start ))s waited) — releasing gated readers."
        exit 0
      fi
      now=$(date +%s)
      if [ "$now" -ge "$deadline" ]; then
        echo "REFUSE: $GATE_NAME still storming after ''${MAX_WAIT_MIN} min / $attempt probe(s) — refusing admission." >&2
        echo "  A skipped post-crash catch-up run is free (timer refire / next deploy / next boot);" >&2
        echo "  a catch-up run inside the storm killed this box 7x (freezes #19/#20/#22/#25/#28)." >&2
        echo "  Re-run later: systemctl start <gated-unit>, or wait for its next trigger." >&2
        exit 1
      fi
      sleep "$POLL_SECS"
    done
  '';
}
