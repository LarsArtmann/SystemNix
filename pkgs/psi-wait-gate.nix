# PSI WAIT gate — the waiting twin of maintenance-entry-gate (PARETO M10.3,
# 2026-10-17).
#
# Contract difference, deliberately NOT mergeable with the refuse gate:
#   maintenance-entry-gate: ADMISSION for heavy maintenance — exit 1 refuses,
#     a skipped night is free (nix-gc, balance, migrate-*, compsize).
#   psi-wait-gate: ORDERING for must-come-up services — wait for an IO-calm
#     window, then proceed; NEVER refuse. Target users are socket-activated
#     units (fastflowlm, llama-vlm backends): while ExecStartPre waits, the
#     socket backlog queues client connections (Accept=false) — clients see
#     a slow response, never a refused one. Cold model loads page multi-GB
#     GGUFs through the QLC; starting that INSIDE a boot/recovery storm is
#     the freeze #20 stacked-reader class, but the service may not die
#     either — so it waits, bounded by --max-wait-sec, then proceeds with a
#     loud WAIT-BUDGET-EXHAUSTED line (slow answer beats dead service).
#
# Checks per round (same semantics as maintenance-entry-gate):
#   1. IO pressure: /proc/pressure/io `some avg10` >= --psi-max (default 30,
#      the model-load band; the maintenance default 20 is stricter than a
#      daemon start needs) → keep waiting.
#   2. Guard-trip recency (only when --trip-window-min > 0, default 0=off):
#      a memory-emergency-guard trip inside the window keeps the wait going
#      even at calm PSI (episodic-storm dips, freeze #5/#21).
#
# exit 0 = admitted or budget-exhausted-proceeding (the only success shape);
# exit 64 = usage error. Fixture flags (--psi-file/--trip-state-file) exist
# for the selftest — same pattern as maintenance-entry-gate.
{
  writeShellApplication,
  coreutils,
  gawk,
}:
writeShellApplication {
  name = "psi-wait-gate";
  runtimeInputs = [
    coreutils
    gawk
  ];
  text = ''
    set -uo pipefail

    GATE_NAME="wait"
    PSI_MAX="30"
    INTERVAL_SEC="30"
    MAX_WAIT_SEC="1200"
    TRIP_WINDOW_MIN="0"
    PSI_FILE="/proc/pressure/io"
    TRIP_STATE_FILE="/var/lib/memory-emergency-guard/last-trip"
    SELFTEST=0

    usage() {
      echo "usage: psi-wait-gate [--name LABEL] [--psi-max N] [--interval-sec N]" >&2
      echo "                     [--max-wait-sec N] [--trip-window-min N]" >&2
      echo "                     [--psi-file PATH] [--trip-state-file PATH] [selftest]" >&2
      echo "  waits for IO PSI some avg10 < --psi-max (re-checking every --interval-sec)," >&2
      echo "  then exits 0. Budget exhaustion (--max-wait-sec) PROCEEDS, never refuses." >&2
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
      --interval-sec)
        [ "$#" -ge 2 ] || usage
        INTERVAL_SEC=$2
        shift 2
        ;;
      --max-wait-sec)
        [ "$#" -ge 2 ] || usage
        MAX_WAIT_SEC=$2
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

    read_psi() {
      local raw
      raw=$(awk '/^some/ {for (i = 1; i <= NF; i++) if ($i ~ /^avg10=/) {sub(/^avg10=/, "", $i); print $i; exit}}' "$PSI_FILE" 2>/dev/null)
      if [ -z "$raw" ]; then
        echo "WARN: no PSI data at $PSI_FILE — treating io pressure as 0 (fail-open, same as every /proc reader in this repo)" >&2
        raw="0"
      fi
      case "$raw" in
      *[!0-9.]* | ''')
        echo "WARN: unparseable PSI value '$raw' — treating as 0" >&2
        raw="0"
        ;;
      esac
      RET_PSI="$raw"
    }

    # Sets RET_TRIP_AGE_MIN and returns 0 when a recent guard trip should
    # KEEP the wait going; window disabled / no trip / aged trip → return 1.
    trip_blocks() {
      RET_TRIP_AGE_MIN=-1
      [ "$TRIP_WINDOW_MIN" -gt 0 ] || return 1
      local last_trip
      last_trip=$(tr -d '[:space:]' <"$TRIP_STATE_FILE" 2>/dev/null || true)
      case "$last_trip" in
      ''' | *[!0-9]*)
        if [ -n "$last_trip" ]; then
          echo "WARN: unparseable last-trip epoch '$last_trip' — treating as no-trip-ever" >&2
        fi
        return 1
        ;;
      esac
      [ "$last_trip" -gt 0 ] || return 1
      local age_min
      age_min=$((($(date +%s) - last_trip) / 60))
      # Future timestamp = clock skew or corrupt state: conservative reading
      # is "a trip just happened" (maintenance-entry-gate parity).
      [ "$age_min" -lt 0 ] && age_min=0
      if [ "$age_min" -lt "$TRIP_WINDOW_MIN" ]; then
        RET_TRIP_AGE_MIN=$age_min
        return 0
      fi
      return 1
    }

    # The wait loop. Every verdict line goes to stderr (stdout stays empty —
    # callers may pipe it). Always exits 0.
    wait_loop() {
      local start checks
      start=$(date +%s)
      checks=0
      while :; do
        checks=$((checks + 1))
        read_psi
        if awk -v v="$RET_PSI" -v m="$PSI_MAX" 'BEGIN { exit !(v >= m) }'; then
          echo "WAIT: $GATE_NAME — IO PSI some avg10=''${RET_PSI}% >= ''${PSI_MAX}% (check ''${checks}, $(( $(date +%s) - start ))s elapsed); queued clients keep waiting" >&2
        elif trip_blocks; then
          echo "WAIT: $GATE_NAME — guard tripped ''${RET_TRIP_AGE_MIN} min ago (window ''${TRIP_WINDOW_MIN} min); a calm PSI dip is not calm (freeze #5/#21 class)" >&2
        else
          echo "OK: $GATE_NAME — admitted after ''${checks} check(s), $(( $(date +%s) - start ))s (IO PSI some avg10=''${RET_PSI}% < ''${PSI_MAX}%)" >&2
          return 0
        fi
        if [ "$(( $(date +%s) - start ))" -ge "$MAX_WAIT_SEC" ]; then
          echo "WAIT-BUDGET-EXHAUSTED: $GATE_NAME — proceeding anyway after ''${MAX_WAIT_SEC}s budget (last IO PSI some avg10=''${RET_PSI}%). The waiting gate never refuses: the socket backlog keeps clients queued, and a slow answer beats a dead service (see pkgs/psi-wait-gate.nix)." >&2
          return 0
        fi
        sleep "$INTERVAL_SEC"
      done
    }

    if [ "$SELFTEST" = "1" ]; then
      PASS=0
      EXPECT=9
      ok() {
        PASS=$((PASS + 1))
      }
      fail() {
        echo "FAIL: $1" >&2
        exit 1
      }
      FIX=$(mktemp -d)
      trap 'rm -rf "$FIX"' EXIT
      PSI_F="$FIX/psi"
      TRIP_F="$FIX/last-trip"
      now=$(date +%s)

      # Verdict helpers assert BOTH the exit-0 contract and the verdict
      # line (the wait gate's only failure shape is usage-64 — every wait
      # outcome must be one of the two named lines). grep -F: the verdict
      # lines contain parentheses and em dashes.
      must_admit_now() {
        if out=$(wait_loop 2>&1); then
          if printf '%s' "$out" | grep -qF "OK: $GATE_NAME — admitted after 1 check(s)"; then
            ok
          else
            fail "$1: admitted but first-check verdict line missing: $out"
          fi
        else
          fail "$1: wait_loop must exit 0, got $?"
        fi
      }
      must_admit_later() {
        if out=$(wait_loop 2>&1); then
          if printf '%s' "$out" | grep -qF "OK: $GATE_NAME — admitted after"; then
            ok
          else
            fail "$1: admitted verdict line missing: $out"
          fi
        else
          fail "$1: wait_loop must exit 0, got $?"
        fi
      }
      must_exhaust() {
        if out=$(wait_loop 2>&1); then
          if printf '%s' "$out" | grep -qF "WAIT-BUDGET-EXHAUSTED: $GATE_NAME"; then
            ok
          else
            fail "$1: exhaustion verdict line missing: $out"
          fi
        else
          fail "$1: budget exhaustion must still exit 0 (never refuse), got $?"
        fi
      }

      INTERVAL_SEC=1

      # 1: calm PSI admits on the FIRST check, zero waits
      PSI_FILE="$PSI_F"; TRIP_STATE_FILE="$TRIP_F"
      printf 'some avg10=5.00 avg60=1.00 avg300=0.00\nfull avg10=0.00\n' >"$PSI_F"
      must_admit_now "selftest 1 (calm, first check)"

      # 2: decimal boundary just under the band admits immediately
      printf 'some avg10=29.99 avg60=9.00\n' >"$PSI_F"
      must_admit_now "selftest 2 (29.99 < 30)"

      # 3: PSI AT the band keeps waiting; budget exhaustion PROCEEDS (>=
      # semantics decimal-safe + the never-refuse contract)
      printf 'some avg10=30.00 avg60=9.00\n' >"$PSI_F"
      MAX_WAIT_SEC=2
      must_exhaust "selftest 3 (band boundary waits, exhaustion proceeds)"
      MAX_WAIT_SEC=1200

      # 4: storm that FLIPS to calm mid-wait — the fixture is re-read every
      # round, admission lands on a LATER check (the ordering contract)
      printf 'some avg10=88.00\n' >"$PSI_F"
      (sleep 1.2; printf 'some avg10=4.00\n' >"$PSI_F") &
      must_admit_later "selftest 4 (storm→calm flip admits on re-check)"
      wait

      # 5: fresh guard trip + window 60 keeps waiting at CALM PSI
      TRIP_WINDOW_MIN=60
      printf 'some avg10=1.00\n' >"$PSI_F"
      echo "$((now - 30 * 60))" >"$TRIP_F"
      MAX_WAIT_SEC=2
      must_exhaust "selftest 5 (trip 30 min ago holds the wait)"
      MAX_WAIT_SEC=1200

      # 6: aged trip (120 min) admits
      echo "$((now - 120 * 60))" >"$TRIP_F"
      must_admit_now "selftest 6 (trip 120 min ago admits)"

      # 7: garbage trip file degrades to never-tripped
      echo "not-an-epoch" >"$TRIP_F"
      must_admit_now "selftest 7 (garbage trip file)"

      # 8: missing PSI file fails OPEN (PSI-less kernel)
      rm -f "$PSI_F" "$TRIP_F"
      TRIP_WINDOW_MIN=0
      must_admit_now "selftest 8 (no PSI file, fail-open)"

      # 9: usage error exits 64 (the only nonzero shape) — `usage` is
      # invoked directly: self-referencing the binary needs its bin dir on
      # PATH, which writeShellApplication does not guarantee.
      rc=0
      usage >/dev/null 2>&1 || rc=$?
      if [ "$rc" -eq 64 ]; then ok; else fail "selftest 9 (usage must exit 64, got $rc)"; fi

      if [ "$PASS" -ne "$EXPECT" ]; then
        fail "selftest count drift: $PASS PASS vs $EXPECT expected"
      fi
      echo "psi-wait-gate selftest: $PASS/$EXPECT scenarios passed"
      exit 0
    fi

    wait_loop
  '';
}
