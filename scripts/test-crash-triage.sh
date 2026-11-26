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

fail() {
  echo "test-crash-triage: FAIL: $*" >&2
  exit 1
}

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
  *SYSLOG_IDENTIFIER=systemd-pstore*)
    # EFI-pstore records archived by each boot (the dump of the PREVIOUS
    # boot's death), as JSON like journalctl -o json prints it: the record
    # text in FILE, header line first. The archive under /var/lib is not
    # readable here, so the journal copy is what the decoder sees.
    case "$*" in
      *"-b 00000000000000000000000000000000"*)
        # boot0 archived bootA's death: the CAPTURE kernel's log, deadlocked
        # on the inherited watermark (the 2026-11-25 shape).
        [ "${STUB_PSTORE_FAIL:-}" = boot0 ] && exit 1
        echo '{"__REALTIME_TIMESTAMP":"1795500002000000","MESSAGE":"File dmesg-efi_pstore-179550000001001 moved to /var/lib/systemd/pstore/179550000001/dmesg-efi_pstore-179550000001.txt.","FILE":"Panic#1 Part1\nLinux version 7.3.0 (capture)\n[    0.045123] Memory: 131118 pages RAM\n[   11.918840] Kernel panic - not syncing: System is deadlocked on memory\n[   11.918900] CPU: 3 PID: 1 Comm: systemd Not tainted 7.3.0\n"}'
        ;;
      *"-b aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"*)
        # bootA archived bootB's death: the MAIN kernel's log (long uptime).
        echo '{"__REALTIME_TIMESTAMP":"1795490002000000","MESSAGE":"File dmesg-efi_pstore-179549000001001 moved to /var/lib/systemd/pstore/179549000001/dmesg-efi_pstore-179549000001.txt.","FILE":"Panic#1 Part1\n[ 86412.441000] watchdog: BUG: soft lockup - CPU#12 stuck for 23s!\n[ 86412.550000] Kernel panic - not syncing: soft lockup - CPU 12 stuck for 23s!\n"}'
        ;;
      *) ;;  # this boot archived no dump
    esac
    ;;
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
    # ioPause-era trips (both shapes) — the 2026-10-31 metric fix must
    # count them alongside the socket-stop lines above.
    echo 'memory-emergency-guard-check: MEMORY EMERGENCY IO-PAUSE (trip #4491, zone 6): SIGSTOPped 2 headless driver process group(s)'
    echo 'memory-emergency-guard-check: MEMORY EMERGENCY IO-PAUSE (trip #4492, zone 6): NO eligible headless tree matched the attribution'
    # Observe-only memory trips (2026-11-26: a box with no socket and no
    # sacrifice unit), three of them. 'action taken: sockets' missed every
    # one of them.
    echo 'memory-emergency-guard-check: MEMORY EMERGENCY action taken: I/O churn units only (no socket or sacrifice unit is configured: observe-only mode) (trip #4493, zone 1)'
    echo 'memory-emergency-guard-check: MEMORY EMERGENCY action taken: I/O churn units only (no socket or sacrifice unit is configured: observe-only mode) (trip #4494, zone 2)'
    echo 'memory-emergency-guard-check: MEMORY EMERGENCY action taken: I/O churn units only (no socket or sacrifice unit is configured: observe-only mode) (trip #4495, zone 3)'
    # NOT trips: the mover line and the cooldown heartbeat.
    echo 'memory-emergency-guard-check: MEMORY EMERGENCY IO-TOP (trip #4495, zone 3, 3s sample): system.slice @38MB/s [slice]'
    echo 'memory-emergency-guard-check: MEMORY EMERGENCY still active (I/O PSI some avg60=65.85% sustained) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action'
    # Guided-mode episodes (3) beside the 8 deep-cap applications below.
    for i in $(seq 3); do echo 'thermal-pstate-guard-check: THERMAL THROTTLE ENTER: amd_pstate -> guided after 5x hot ticks:Tctl=97.0'; done
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
    # ioPause-era no-match trips (pre-fix the metric read 34; real 40).
    for i in $(seq 6); do echo 'memory-emergency-guard-check: MEMORY EMERGENCY IO-PAUSE (trip #440, zone 6): NO eligible headless tree matched the attribution'; done
    for i in $(seq 452); do echo 'thermal-pstate-guard-check: thermal-pstate-guard: DEEP THROTTLE ENTER: guided'; done
    for i in $(seq 15); do echo 'thermal-pstate-guard-check: THERMAL THROTTLE ENTER: amd_pstate -> guided after 5x hot ticks:Tctl=97.0'; done
    echo 'kernel: something invoked oom-killer'
    # S-0025 legs: hung tasks (2), btrfs warnings (1), kernel thermal (1).
    echo 'kernel: INFO: task kworker/u386:12 blocked for more than 122 seconds.'
    echo 'kernel: INFO: task btrfs-transacti blocked for more than 122 seconds.'
    echo 'kernel: BTRFS warning (device nvme0n1p3): csum failed root'
    echo 'kernel: thermal thermal_zone9: critical temperature reached (105 C), shutting down'
    # Kill-pass memcg gap fixture (Oct-28 class): one attested victim
    # (task_memcg line + matching kill) and one gap victim (kill line
    # only) -> oom-memcg-attested=1/2.
    echo 'kernel: oom-kill:constraint=CONSTRAINT_NONE,global_oom,task_memcg=/user.slice/user-1000.slice/session-74.scope,task=chromium,pid=3392891,uid=1000'
    echo 'kernel: Out of memory: Killed process 3392891 (chromium) UID:1000'
    echo 'kernel: Out of memory: Killed process 3595707 (chrome-headless) UID:1000'
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
} >"$scratch/bin/journalctl"
chmod +x "$scratch/bin/journalctl"

# Evidence file ONLY for boot "aaaaaaaa" (short id 8 chars).
touch "$scratch/docs/status/tasks/2026-10-27_23-57_boot-aaaaaaaa-evidence-pull.md"

out=$(PATH="$scratch/bin:$PATH" JOURNALCTL="$scratch/bin/journalctl" DOCS_ROOT="$scratch" bash "$script" --boots 3)

# 1. bootB (-2): abrupt, un-evidenced — must flag + propose branch C
#    (40 trips = 34 socket + 6 IO-PAUSE + 452 throttles). Flag checked
#    two-step in block 4 below. S-0025 fields: hung=2 btrfs_warn=1 kthermal=1.
printf '%s\n' "$out" | rg -q 'bbbbbbbb.*ABRUPT.*trips=40 throttle_ENTER=452 throttle_episodes=15 oom=.*oom-memcg-attested=1/2 hung_task=2 btrfs_warn=1 kthermal=1' || fail "bootB census line wrong:\n$out"

# 2. bootA (-1): abrupt, HAS evidence, watchdog reason read from boot0.
#    trips = 25 socket-stop + 2 IO-PAUSE (the 2026-10-31 both-eras fix)
#    + 3 observe-only memory trips (the 2026-11-26 fix); the IO-TOP line
#    and the cooldown heartbeat are not trips.
printf '%s\n' "$out" | rg -q 'aaaaaaaa.*ABRUPT.*trips=30 throttle_ENTER=8 throttle_episodes=3 ' || fail "bootA census line wrong:\n$out"

# 2b. Control for the trip pattern: the pattern this test replaced counts
#     27 on the same bootA fixture (it cannot see the observe-only lines).
old_trips=$(PATH="$scratch/bin:$PATH" rg -c 'action taken: sockets|IO-PAUSE \(trip' < <(PATH="$scratch/bin:$PATH" bash -c 'journalctl -b aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --no-pager'))
[ "$old_trips" = 27 ] || fail "control: the replaced trip pattern should count 27 on bootA, got $old_trips"
new_trips=$(PATH="$scratch/bin:$PATH" rg -c 'action taken: |IO-PAUSE \(trip' < <(PATH="$scratch/bin:$PATH" bash -c 'journalctl -b aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --no-pager'))
[ "$new_trips" = 30 ] || fail "the trip pattern of the script must count 30 on bootA, got $new_trips"
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

# 4b. kdump verdict per boot (2026-11-26): whose log the dump of a boot's
#     death is, read from the NEXT boot's archived EFI-pstore records.
#     bootA died in a kdump-capable way and its capture kernel OOM-panicked
#     (the dump is the capture kernel's); bootB's panic was captured by the
#     main kernel; the running boot has no verdict yet.
printf '%s\n' "$out" | rg -q '00000000.*kdump=pending\(running\)' || fail "running boot kdump verdict wrong:\n$out"
printf '%s\n' "$out" | rg -q 'aaaaaaaa.*kdump=capture-kernel-OOM' || fail "bootA kdump verdict must be capture-kernel-OOM:\n$out"
printf '%s\n' "$out" | rg -q 'bbbbbbbb.*kdump=main-kernel-panic-captured' || fail "bootB kdump verdict must be main-kernel-panic-captured:\n$out"

# 5. Vacuum clock parses 7.9G against the 8G cap.
printf '%s\n' "$out" | rg -q 'headroom: 0.1G' || fail "vacuum clock headroom wrong:\n$(printf '%s\n' "$out" | tail -3)"

# 6. S-0025 verdict block: bootB is NO-EVIDENCE; bootA has a full "B
#    livelock" proposal (27 trips ≥ 5) + evidence so is NOT an open
#    discriminator; boot0 (running) NEVER paged.
printf '%s\n' "$out" | rg -q '=== verdict ===' || fail "verdict block missing"
printf '%s\n' "$out" | rg -q 'abrupt=2 clean=0 running=1' || fail "verdict counts wrong:\n$(printf '%s\n' "$out" | rg 'abrupt=')"
printf '%s\n' "$out" | rg -q 'OPEN DISCRIMINATORS: bbbbbbbb\(NO-EVIDENCE\)' || fail "bootB not the named open discriminator:\n$(printf '%s\n' "$out" | sed -n '/=== verdict ===/,$p')"
printf '%s\n' "$out" | rg -q '00000000\(' && fail "running boot paged in verdict"
printf '%s\n' "$out" | rg -q 'aaaaaaaa\(' && fail "bootA (branch B + evidence) falsely named open discriminator"

# 7. An unreadable journal is a FAILED read, never "none" (2026-11-26): the
#    next boot's pstore query fails -> the verdict says so and the boot is
#    flagged.
out_fail=$(STUB_PSTORE_FAIL=boot0 PATH="$scratch/bin:$PATH" JOURNALCTL="$scratch/bin/journalctl" DOCS_ROOT="$scratch" bash "$script" --boots 3)
printf '%s\n' "$out_fail" | rg -q 'aaaaaaaa.*kdump=unknown\(journal-unreadable\)' || fail "a failed pstore read must not read as a verdict:\n$out_fail"
printf '%s\n' "$out_fail" | rg -q 'KDUMP VERDICT UNREADABLE' || fail "a failed pstore read must be flagged:\n$out_fail"
printf '%s\n' "$out_fail" | rg -q 'bbbbbbbb.*kdump=main-kernel-panic-captured' || fail "one failed read must not disturb the other boots' verdicts:\n$out_fail"

echo "test-crash-triage: PASS (censuses incl. observe-only trips + control, throttle episodes, kdump verdicts incl. unreadable, discriminator branches, evidence sweep, vacuum clock, S-0025 legs + verdict)"
