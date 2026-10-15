# Maintenance entry gate — IO-pressure + guard-trip admission for HEAVY
# maintenance work (the migrate-* script class, nix-gc / nix-build-cleanup
# ExecStartPre via btrfs-gc-guard, btrfs balance jobs).
#
# Why: nothing on this box refused heavy work while the memory-emergency-guard
# was tripped (freeze #21 verdict). migrate-rust-cache launched FOUR times on
# 2026-10-06/07 and killed the box three times (freezes #19/#20/#21); the
# scheduled midnight nix-gc fired into 2+ hours of zone-6 IO PSI and the
# kernel died 59 s into a 9,463-path deletion burst. A skipped maintenance
# night is free; maintenance inside an IO storm is not.
#
# Two checks:
#   1. IO pressure: /proc/pressure/io `some avg10` >= --psi-max (default 20,
#      the repo's standing maintenance band: balance/scrub deferral + the
#      deploy gate). The interactive migrate-* scripts pass --psi-max 30
#      (their queue row's band). Missing/unparseable PSI file degrades to 0
#      with a warning — the same fail-open every other /proc reader in the
#      repo uses; PSI-enabled kernels (all of them here) always parse.
#   2. Guard-trip recency: any memory-emergency-guard trip within the last
#      --trip-window-min (default 60, the deploy gate's freeze-#5 window)
#      means a calm point-in-time PSI reading is NOT evidence of calm
#      (episodic storms oscillate; freeze #5 + #21 both killed in dips).
#      Read from the guard's OWN fsynced state file (`last-trip` epoch,
#      written before the trip journal line — freeze-13 persist-before-log
#      order) instead of journalctl: no journal dependency, works under
#      harden{} units, cannot time out, survives journal vacuuming.
#
# exit 0 = admit, exit 1 = refuse, exit 64 = usage error.
# Serialization (one migrate-* at a time) is NOT this binary's job: flock
# must be held by the CALLER for its whole lifetime (a child's flock dies
# with the child) — each migrate-* script takes /run/lock itself.
{
  writeShellApplication,
  coreutils,
  gawk,
}:
writeShellApplication {
  name = "maintenance-entry-gate";
  runtimeInputs = [
    coreutils
    gawk
  ];
  text = ''
    set -uo pipefail

    GATE_NAME="maintenance"
    PSI_MAX="20"
    TRIP_WINDOW_MIN="60"
    PSI_FILE="/proc/pressure/io"
    TRIP_STATE_FILE="/var/lib/memory-emergency-guard/last-trip"
    SELFTEST=0

    usage() {
      echo "usage: maintenance-entry-gate [--name LABEL] [--psi-max N] [--trip-window-min N]" >&2
      echo "                              [--psi-file PATH] [--trip-state-file PATH] [selftest]" >&2
      echo "  exit 0 = admit, exit 1 = refuse (reason on stderr)" >&2
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
      --psi-file)
        [ "$#" -ge 2 ] || usage
        PSI_FILE=$2
        shift 2
        ;;
      --trip-state-file)
        [ "$#" -ge 2 ] || usage
        TRIP_STATE_FILE=$2
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

    # The gate verdict: sets PSI_RAW + TRIP_AGE_MIN globals for the caller's
    # message, returns 0 to admit / 1 to refuse.
    run_gate() {
      PSI_RAW=$(awk '/^some/ {for (i = 1; i <= NF; i++) if ($i ~ /^avg10=/) {sub(/^avg10=/, "", $i); print $i; exit}}' "$PSI_FILE" 2>/dev/null)
      if [ -z "$PSI_RAW" ]; then
        echo "WARN: no PSI data at $PSI_FILE — treating io pressure as 0 (fail-open, same as every /proc reader in this repo)" >&2
        PSI_RAW="0"
      fi
      case "$PSI_RAW" in
      *[!0-9.]* | ''')
        echo "WARN: unparseable PSI value '$PSI_RAW' — treating as 0" >&2
        PSI_RAW="0"
        ;;
      esac

      now=$(date +%s)
      last_trip=$(tr -d '[:space:]' <"$TRIP_STATE_FILE" 2>/dev/null || true)
      case "$last_trip" in
      ''' | *[!0-9]*)
        if [ -n "$last_trip" ]; then
          echo "WARN: unparseable last-trip epoch '$last_trip' — treating as no-trip-ever" >&2
        fi
        last_trip=0
        ;;
      esac
      TRIP_AGE_MIN=-1
      if [ "$last_trip" -gt 0 ]; then
        TRIP_AGE_MIN=$(((now - last_trip) / 60))
        if [ "$TRIP_AGE_MIN" -lt 0 ]; then
          # Future timestamp = clock skew or a corrupt state file. The
          # conservative reading is "a trip just happened".
          TRIP_AGE_MIN=0
        fi
      fi

      if awk -v v="''$PSI_RAW" -v m="''$PSI_MAX" 'BEGIN { exit !(v >= m) }'; then
        echo "REFUSE: $GATE_NAME — IO PSI some avg10=''${PSI_RAW}% (>= ''${PSI_MAX}% band)." >&2
        echo "  Heavy maintenance inside an IO storm killed this box 3x on 2026-10-06/07 (freezes #19/#20/#21)." >&2
        echo "  Wait for a quiet window; a refused run is free." >&2
        return 1
      fi

      if [ "$TRIP_AGE_MIN" -ge 0 ] && [ "$TRIP_AGE_MIN" -lt "$TRIP_WINDOW_MIN" ]; then
        echo "REFUSE: $GATE_NAME — memory-emergency-guard tripped ''${TRIP_AGE_MIN} min ago (window ''${TRIP_WINDOW_MIN} min)." >&2
        echo "  A calm point-in-time PSI reading inside an episodic storm is NOT evidence of calm (freeze #5/#21 class)." >&2
        echo "  Wait >= ''${TRIP_WINDOW_MIN} min without a trip, then re-run." >&2
        return 1
      fi

      return 0
    }

    verdict_line() {
      if [ "$TRIP_AGE_MIN" -lt 0 ]; then
        printf 'OK: %s — IO PSI some avg10=%s%% (< %s), last guard trip: never (window %s min)\n' "$GATE_NAME" "$PSI_RAW" "$PSI_MAX" "$TRIP_WINDOW_MIN"
      else
        printf 'OK: %s — IO PSI some avg10=%s%% (< %s), last guard trip %s min ago (window %s min)\n' "$GATE_NAME" "$PSI_RAW" "$PSI_MAX" "$TRIP_AGE_MIN" "$TRIP_WINDOW_MIN"
      fi
    }

    if [ "$SELFTEST" = "1" ]; then
      PASS=0
      EXPECT=11
      ok() {
        PASS=$((PASS + 1))
      }
      FIX=$(mktemp -d)
      trap 'rm -rf "$FIX"' EXIT
      PSI_F="$FIX/psi"
      TRIP_F="$FIX/last-trip"
      # Point the gate AT the fixtures: without this the selftest reads the
      # REAL /proc/pressure/io + guard state — a selftest that only passes on
      # a quiet box is a random red, not a test (live: refused scenario 1
      # while the host sat at PSI some avg10 >= 20 under build load).
      PSI_FILE="$PSI_F"
      TRIP_STATE_FILE="$TRIP_F"
      now=$(date +%s)

      # Verdict helpers: shellcheck-clean admit/refuse assertions (the
      # `cmd && ok || fail` shortcut is SC2015-unsound and writeShellApplication
      # runs shellcheck as a build gate).
      must_admit() {
        if run_gate >/dev/null 2>&1; then
          ok
        else
          echo "FAIL: $1 must admit" >&2
          exit 1
        fi
      }
      must_refuse() {
        if run_gate >/dev/null 2>&1; then
          echo "FAIL: $1 must refuse" >&2
          exit 1
        fi
        ok
      }

      # 1: calm PSI, no trip state ever
      printf 'some avg10=5.00 avg60=1.00 avg300=0.00\nfull avg10=0.00\n' >"$PSI_F"
      must_admit "selftest 1"
      verdict_line | grep -q 'last guard trip: never' || {
        echo "FAIL: selftest 1 verdict must say never-tripped" >&2
        exit 1
      }

      # 2: PSI just under the band admits (decimal boundary)
      printf 'some avg10=19.99 avg60=9.00\n' >"$PSI_F"
      must_admit "selftest 2 (19.99 < 20)"

      # 3: PSI at the band refuses (>= semantics, decimal-safe)
      printf 'some avg10=20.00 avg60=9.00\n' >"$PSI_F"
      must_refuse "selftest 3 (20.00 >= 20)"

      # 4: the migrate band boundary (--psi-max 30 — the interactive
      # migrate-* scripts' band; the default 20 band was scenarios 2-3)
      PSI_MAX="30"
      printf 'some avg10=29.50 avg60=9.00\n' >"$PSI_F"
      must_admit "selftest 4 (29.5 < 30 band)"
      printf 'some avg10=30.00 avg60=9.00\n' >"$PSI_F"
      must_refuse "selftest 4b (30 >= 30)"
      PSI_MAX="20"

      # 5: trip 30 min ago blocks a 60-min window even at PSI 0
      printf 'some avg10=0.00\n' >"$PSI_F"
      echo "$((now - 30 * 60))" >"$TRIP_F"
      must_refuse "selftest 5 (trip 30 min ago)"

      # 6: trip 61 min ago admits
      echo "$((now - 61 * 60))" >"$TRIP_F"
      must_admit "selftest 6 (trip 61 min ago)"

      # 7: future timestamp counts as a just-now trip (clock-skew safe)
      echo "$((now + 600))" >"$TRIP_F"
      must_refuse "selftest 7 (future epoch)"

      # 8: garbage trip file degrades to never-tripped
      echo "not-an-epoch" >"$TRIP_F"
      must_admit "selftest 8 (garbage trip file)"

      # 9: missing PSI file fails OPEN with a warning (PSI-less kernel)
      rm -f "$PSI_F" "$TRIP_F"
      must_admit "selftest 9 (no PSI file)"

      # 10: zero padding / whitespace around the trip epoch parses
      printf 'some avg10=1.00\n' >"$PSI_F"
      printf '  %s  \n' "$((now - 120 * 60))" >"$TRIP_F"
      must_admit "selftest 10 (padded epoch)"

      if [ "$PASS" -ne "$EXPECT" ]; then
        echo "FAIL: selftest count drift: $PASS PASS lines vs $EXPECT expected" >&2
        exit 1
      fi
      echo "maintenance-entry-gate selftest: $PASS/$EXPECT scenarios passed"
      exit 0
    fi

    if run_gate; then
      verdict_line
      exit 0
    fi
    exit 1
  '';
}
