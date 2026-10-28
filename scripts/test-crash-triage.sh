#!/usr/bin/env bash
# test-crash-triage.sh — fixture selftest for crash-triage.sh (stability
# plan M10/F39).  Drives the script through a STUB journalctl (the
# usb-flap pattern) with a canned 4-boot world encoding the 2026-10-28
# night: a clean boot, a watchdog-killed boot WITH evidence, a
# watchdog-killed boot WITHOUT evidence (must page), and the newest
# boot.  Asserts: end classification, full-count censuses (the F35
# anti-truncation rule), reset-reason attribution to the NEXT boot,
# discriminator branch proposals, un-evidenced-boot flag, vacuum clock.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/crash-triage.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

fail() { echo "test-crash-triage: FAIL: $*" >&2; exit 1; }

# --- Stub journalctl ------------------------------------------------------
mkdir -p "$scratch/bin" "$scratch/docs/status/tasks"
# Shebang resolved at runtime (usb-flap pattern): /usr/bin/env does not
# exist inside the Nix sandbox, so a hardcoded env shebang makes the stub
# unexecutable in the flake check while it works live.
bash_abs="$(command -v bash)"
{
  printf '#!%s\n' "$bash_abs"
  cat <<'STUB'
# Canned world (oldest -> newest):
#  bootC (3 days ago):   clean shutdown, no trips
#  bootB (Oct 26-27):    452 throttles + 34 trips, NO shutdown ceremony,
#                        reset reason reported by bootA's kernel log
#  bootA (Oct 27-28):    25 trips + 8 throttles, watchdog-killed, HAS
#                        evidence file
#  boot0 (now):          the running boot (reason line for bootA inside)
case "$*" in
  *--list-boots*)
    cat <<'EOF'
 -3 33333333333333333333333333333333 Tue 2026-10-25 10:00:00 CEST Tue 2026-10-26 09:00:00 CET
 -2 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb Mon 2026-10-26 22:55:34 CET Tue 2026-10-27 10:03:11 CET
 -1 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa Tue 2026-10-27 10:04:43 CET Wed 2026-10-28 00:40:38 CET
  0 00000000000000000000000000000000 Wed 2026-10-28 00:42:49 CET Wed 2026-10-28 00:42:50 CET
EOF
    ;;
  *"-b 00000000000000000000000000000000"*|*-b\ 0*)
    # newest boot: carries the reset reason for bootA
    echo 'kernel: x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired'
    echo 'systemd: Started Whatever.'
    ;;
  *"-b aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"*)
    echo 'memory-emergency-guard-check: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #4490, zone 6)'
    echo 'thermal-pstate-guard-check: thermal-pstate-guard: DEEP THROTTLE ENTER: guided'  # 8x
    echo 'thermal-pstate-guard-check: thermal-pstate-guard: DEEP THROTTLE ENTER: guided'
    echo 'thermal-pstate-guard-check: thermal-pstate-guard: DEEP THROTTLE ENTER: guided'
    echo 'thermal-pstate-guard-check: thermal-pstate-guard: DEEP THROTTLE ENTER: guided'
    echo 'thermal-pstate-guard-check: thermal-pstate-guard: DEEP THROTTLE ENTER: guided'
    echo 'thermal-pstate-guard-check: thermal-pstate-guard: DEEP THROTTLE ENTER: guided'
    echo 'thermal-pstate-guard-check: thermal-pstate-guard: DEEP THROTTLE ENTER: guided'
    echo 'thermal-pstate-guard-check: thermal-pstate-guard: DEEP THROTTLE ENTER: guided'
    # 24 more trip lines
    for i in $(seq 24); do echo 'memory-emergency-guard-check: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #45, zone 6)'; done
    echo 'nsfw-server: readyz 200 OK'   # mid-line end, no ceremony
    echo 'systemd[1896]: Reached target Shutdown'  # USER-manager line — must NOT count as ceremony (the live trap)
    ;;
  *"-b bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"*)
    for i in $(seq 34); do echo 'memory-emergency-guard-check: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #44, zone 6)'; done
    for i in $(seq 452); do echo 'thermal-pstate-guard-check: thermal-pstate-guard: DEEP THROTTLE ENTER: guided'; done
    echo 'kernel: something invoked oom-killer'
    ;;
  *"-b 33333333333333333333333333333333"*)
    echo 'systemd[1]: Reached target Shutdown'
    ;;
  *--disk-usage*)
    echo 'Archived and active journals take up 7.9G on disk.'
    ;;
  *)
    echo "stub: unmatched args: $*" >&2; exit 1 ;;
esac
STUB
} > "$scratch/bin/journalctl"
chmod +x "$scratch/bin/journalctl"

# Evidence file ONLY for boot "aaaaaaaa" (short id 8 chars).
touch "$scratch/docs/status/tasks/2026-10-27_23-57_boot-aaaaaaaa-evidence-pull.md"

out=$(PATH="$scratch/bin:$PATH" JOURNALCTL="$scratch/bin/journalctl" DOCS_ROOT="$scratch" bash "$script" --boots 3)

# 1. bootB (-2): abrupt, un-evidenced — must flag + propose branch C
#    (34 trips + 452 throttles). Flag checked two-step in block 4 below.
printf '%s\n' "$out" | rg -q 'bbbbbbbb.*ABRUPT.*trips=34 throttle_ENTER=452' || fail "bootB census line wrong:\n$out"

# 2. bootA (-1): abrupt, HAS evidence, watchdog reason read from boot0.
printf '%s\n' "$out" | rg -q 'aaaaaaaa.*ABRUPT.*trips=25 throttle_ENTER=8' || fail "bootA census line wrong:\n$out"
printf '%s\n' "$out" | rg -q 'reset-reason\(in this boot, for previous\).*watchdog timer expired' || fail "reset reason line missing"
printf '%s\n' "$out" | rg -q 'aaaaaaaa' || true
printf '%s\n' "$out" | rg 'aaaaaaaa' -A 3 | rg -q 'boot-aaaaaaaa-evidence-pull' || fail "bootA evidence not linked"

# 3. bootC (-3... shown as oldest of --boots 3? we asked for 3 boots:
#    newest-first = boot0, bootA, bootB; bootC excluded — assert absent).
printf '%s\n' "$out" | rg -q '33333333' && fail "bootC should be outside --boots 3 window"

# 4. bootB un-evidenced flag (two-step form of the check above).
seg=$(printf '%s\n' "$out" | rg 'bbbbbbbb' -A 3)
echo "$seg" | rg -q 'UNEVIDENCED CRASHED BOOT' || fail "bootB un-evidenced flag missing:\n$seg"
echo "$seg" | rg -q 'C combined' || fail "bootB branch proposal not C:\n$seg"

# 5. Vacuum clock parses 7.9G against the 8G cap.
printf '%s\n' "$out" | rg -q 'headroom: 0.1G' || fail "vacuum clock headroom wrong:\n$(printf '%s\n' "$out" | tail -3)"

echo "test-crash-triage: PASS (censuses, discriminator branches, evidence sweep, vacuum clock)"
