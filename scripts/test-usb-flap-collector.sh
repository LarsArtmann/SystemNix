#!/usr/bin/env bash
# Fixture selftest for scripts/usb-flap-collector.sh (the SAME repo file
# the usb-flap-metrics unit runs — never a grep of its own copy).
#
# Covers the 2026-10-21 report §e.3 ask: state resume, delta math, window
# pruning, threshold flip, plus the fail-closed side probe. The journal is
# faked with a stub journalctl that serves canned short-unix event lines
# and can be told to fail, so every branch runs without a real journal.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTOR="$HERE/usb-flap-collector.sh"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*" >&2; }
assert_eq() { # desc got want
  if [ "$2" = "$3" ]; then ok; else fail "$1: got '$2' want '$3'"; fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Run one collector invocation in a fresh scratch env.
# Env: EVENTS_FILE (canned event epochs, one per line), PROBE_RC,
#      BOOT_RC (first-run boot-timestamp call), plus collector env.
run_collector() {
  local dir="$1"; shift
  local stub="$dir/bin"
  mkdir -p "$stub"
  cat > "$stub/journalctl" <<STUB
#!/usr/bin/env bash
EVENTS_FILE='${dir}/events.txt'
PROBE_RC='$PROBE_RC'
BOOT_RC='$BOOT_RC'
for a in "\$@"; do
  case "\$a" in
    --since) mode=window ;;
    --output=short-unix) [ "\$mode" = window ] || mode=boot ;;
    -n) [ "\$mode" = boot ] || mode=probe ;;
  esac
done
case "\$mode" in
  boot)
    [ "\$BOOT_RC" = 0 ] || exit "\$BOOT_RC"
    last=0
    [ -s "\$EVENTS_FILE" ] && last="\$(tail -1 "\$EVENTS_FILE")"
    echo "\$last.000000 host kernel: usb 2-1: USB disconnect, device number 9"
    ;;
  window)
    since="\$(printf '%s\n' "\$@" | sed -n 's/^@//p' | head -1)"
    while read -r e; do
      case "\$e" in ''|*[!0-9]*) continue ;; esac
      [ "\$e" -ge "\$since" ] && echo "\$e.000000 host kernel: usb 2-1.1: USB disconnect, device number 5"
    done < "\$EVENTS_FILE"
    ;;
  probe) [ "\$PROBE_RC" = 0 ] || exit "\$PROBE_RC"; echo "ok" ;;
esac
STUB
  chmod +x "$stub/journalctl"
  mkdir -p "$dir/state" "$dir/textfile"
  (
    export PATH="$stub:$PATH"
    export OUT="$dir/textfile/usb-flap.prom"
    export TEXTFILE_DIR="$dir/textfile"
    export STATE_DIR="$dir/state"
    export THRESHOLD="$THRESHOLD"
    export WINDOW="$WINDOW"
  bash "$COLLECTOR"
  )
}

metric() { # prom name
  awk -v m="$2" '$1 == m { print $2 }' "$1"
}

NOW="$(date +%s)"

# --- Scenario 1: first run, fresh-boot mode (no state replay) -------------
d="$WORK/s1"; mkdir -p "$d"
printf '%s\n' "$((NOW - 10))" "$((NOW - 5))" > "$d/events.txt"
PROBE_RC=0 BOOT_RC=0 THRESHOLD=5 WINDOW=3600 run_collector "$d"
assert_eq "s1 first-run total (boot-only window)" "$(metric "$d/textfile/usb-flap.prom" usb_flap_disconnects_total)" "2"
assert_eq "s1 delta" "$(metric "$d/textfile/usb-flap.prom" usb_flap_disconnects_delta)" "2"
assert_eq "s1 last_hour" "$(metric "$d/textfile/usb-flap.prom" usb_flap_disconnects_last_hour)" "2"
assert_eq "s1 rate_over below threshold" "$(metric "$d/textfile/usb-flap.prom" usb_flap_rate_over_threshold)" "0"
assert_eq "s1 last epoch" "$(metric "$d/textfile/usb-flap.prom" usb_flap_last_disconnect_epoch)" "$((NOW - 10))"
assert_eq "s1 scrape_errors clean" "$(metric "$d/textfile/usb-flap.prom" usb_flap_scrape_errors)" "0"

# --- Scenario 2: state resume + delta math across runs --------------------
d="$WORK/s2"; mkdir -p "$d"
printf '%s\n' "$((NOW - 100))" > "$d/events.txt"
PROBE_RC=0 BOOT_RC=0 THRESHOLD=5 WINDOW=3600 run_collector "$d"
# Second run: state exists (resume since=NOW-100... state since = first-run
# NOW; fake events all >= since? since stored is first run's NOW, so make
# the second window contain 2 newer events by lowering the resume point.
printf '7 %s\n' "$((NOW - 100))" > "$d/state/state"
printf '%s\n' "$((NOW - 60))" "$((NOW - 30))" "$((NOW - 200))" > "$d/events.txt"
PROBE_RC=0 BOOT_RC=0 THRESHOLD=5 WINDOW=3600 run_collector "$d"
assert_eq "s2 total = 7 + 2 resumed" "$(metric "$d/textfile/usb-flap.prom" usb_flap_disconnects_total)" "9"
assert_eq "s2 delta counts only the new window" "$(metric "$d/textfile/usb-flap.prom" usb_flap_disconnects_delta)" "2"

# --- Scenario 3: window pruning --------------------------------------------
d="$WORK/s3"; mkdir -p "$d"
# Pre-seed the window file with a stale event (older than WINDOW=60) and a
# fresh one; the fresh run adds two more fresh events, prunes the stale.
mkdir -p "$d/state"
printf '%s\n' "$((NOW - 600))" "$((NOW - 10))" > "$d/state/window"
printf '3 %s\n' "$((NOW - 600))" > "$d/state/state"
printf '%s\n' "$((NOW - 20))" "$((NOW - 5))" > "$d/events.txt"
PROBE_RC=0 BOOT_RC=0 THRESHOLD=5 WINDOW=60 run_collector "$d"
assert_eq "s3 stale event pruned, fresh kept" "$(metric "$d/textfile/usb-flap.prom" usb_flap_disconnects_last_hour)" "3"

# --- Scenario 4: threshold flip --------------------------------------------
d="$WORK/s4"; mkdir -p "$d"
for i in 1 2 3 4 5; do printf '%s\n' "$((NOW - i))" >> "$d/events.txt"; done
PROBE_RC=0 BOOT_RC=0 THRESHOLD=5 WINDOW=3600 run_collector "$d"
assert_eq "s4 rate_over flips at threshold" "$(metric "$d/textfile/usb-flap.prom" usb_flap_rate_over_threshold)" "1"
assert_eq "s4 last_hour" "$(metric "$d/textfile/usb-flap.prom" usb_flap_disconnects_last_hour)" "5"

# --- Scenario 5: fail-closed side probe ------------------------------------
d="$WORK/s5"; mkdir -p "$d"
printf '%s\n' "$((NOW - 10))" > "$d/events.txt"
PROBE_RC=1 BOOT_RC=0 THRESHOLD=5 WINDOW=3600 run_collector "$d"
assert_eq "s5 broken journal flagged fail-closed" "$(metric "$d/textfile/usb-flap.prom" usb_flap_scrape_errors)" "1"
assert_eq "s5 prom still rendered (never silent)" "$(test -s "$d/textfile/usb-flap.prom" && echo yes)" "yes"

# --- Scenario 6: corrupt/non-numeric delta counters fail closed ------------
d="$WORK/s6"; mkdir -p "$d"
# Event lines that do not parse as epochs poison the window math →
# scrape_errors must be 1, never a frozen quiet day.
printf 'not-an-epoch\n' > "$d/events.txt"
PROBE_RC=0 BOOT_RC=0 THRESHOLD=5 WINDOW=3600 run_collector "$d"
assert_eq "s6 malformed epoch flagged" "$(metric "$d/textfile/usb-flap.prom" usb_flap_scrape_errors)" "1"

echo "usb-flap-collector selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
