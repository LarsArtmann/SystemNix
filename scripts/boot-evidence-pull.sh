#!/usr/bin/env bash
# boot-evidence-pull.sh — one-command boot-evidence pull (pre-vacuum remedy).
#
# The freeze-27/28 evidence pulls were bespoke journalctl sessions; every
# new boot autopsy re-invented the pipeline by hand. This script
# parameterizes it: resolve a boot selector, dump the boot journal ONCE,
# and emit the CANONICAL sections (boot-boundary lines, census, kernel
# OOM, memory-emergency-guard, thermal THROTTLE, kernel panic/BUG/oops,
# pstore dump + kdump capture line of the next boot, remote ClickHouse
# death-window tail) into a commit-ready evidence file
# under docs/status/tasks/ whose header
# cites the boot id8 in the hex-boundary form the pre-vacuum evidence
# gate greps for (scripts/pre-vacuum-evidence-gate.sh).
#
# journald auto-vacuums at SystemMaxUse (8G on evo-x2) — the journal is
# the only forensic source for a freeze boot; pull BEFORE anything else.
#
# Usage:
#   boot-evidence-pull.sh [-b <boot-spec>] [-o <file>|-]
#     -b <spec>   anything `journalctl -b` resolves: -1 (default), 0, -2,
#                 or a full/prefix boot id
#     -o <file>   output path ('-' = stdout). Default:
#                 docs/status/tasks/<UTC-date-time>_boot-<id8>-evidence-pull.md
#                 An existing target is NEVER overwritten (evidence files
#                 are append-only artifacts) — pick another path.
#   boot-evidence-pull.sh list       journalctl --list-boots
#   boot-evidence-pull.sh selftest   fixture selftest (flake check:
#                                    checks.x86_64-linux.boot-evidence-pull-selftest)
#
# The ClickHouse death-window section (M22, docs/agents/stability.md)
# queries signoz_logs.distributed_logs_v2 over [journal cut -> next boot]
# (epoch-ns UTC): the journal loses its final ~30-90s to flush lag at a
# watchdog death, and the remote tail is FRESHER when the pipeline is
# alive (#36) or silently DARK when the collector died pre-death (#37).
# A POSITIVE-CONTROL query runs first over the 10 minutes ending at the
# journal cut and the verdict rests on BOTH windows (2026-11-26):
#   alive-fresher  rows at/after the cut: the pipeline was alive at the cut
#   alive-behind   rows before the cut only: the remote tail lags the cut,
#                  so 0 rows in the death window is NOT a dead pipeline
#   dark           0 rows in the control window too: nothing was emitted
# BEP_CH_TAIL bounds the last-N bodies (default 20). Fail-soft: a dark,
# behind, failed, or skipped pipeline is evidence CONTEXT (never a pull
# failure) and carries the M22 not-evidence-of-absence caveat.
#
# The pstore section reads the boot AFTER the pulled one through
# scripts/lib/pstore-records.sh (systemd-pstore archives a panic's EFI
# pstore dump at the start of the next boot; the token says whether the
# dump is the main kernel's or the capture kernel's) and the kdump-save
# journal line of the 10 minutes after the cut.  The library's
# PSTORE_JOURNALCTL seam is what the selftest stubs.
#
# Each pull first runs scripts/boot-evidence-scratch-gc.sh (quiet,
# fail-soft) to reclaim scratch leaked by prior killed sessions —
# age+holder-gated, so a concurrent pull's fresh scratch is never touched.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TASKS_DIR="$REPO_ROOT/docs/status/tasks"

# The pstore + kdump capture decoding lives in scripts/lib/pstore-records.sh,
# resolved RELATIVE TO THIS SCRIPT: the flake check copies the script and its
# lib/ side by side into a scratch dir, where $REPO_ROOT/scripts/lib does not
# exist.  A missing lib is fail-soft (2026-11-26): the journal is the only
# forensic source of a freeze boot and its evidence must never be lost over a
# helper; the pstore section then says that it was NOT read.
BEP_PSTORE_LIB="$(dirname "$(readlink -f "$0")")/lib/pstore-records.sh"
if [ -r "$BEP_PSTORE_LIB" ]; then
  # shellcheck source=scripts/lib/pstore-records.sh disable=SC1091
  source "$BEP_PSTORE_LIB"
fi

# ── pure helpers (fixture-tested by `selftest`) ──────────────────────────

bep_grep_oom() {
  grep -E 'invoked oom-killer|oom-kill:|Out of memory' "$1" || true
}

bep_ts_delta() {
  # <kill_epoch> <line_epoch> — absolute seconds between two syslog-derived
  # timestamps, YEAR-BOUNDARY safe.  Syslog timestamps carry no year, so GNU
  # date assumes the CURRENT year for both lines: a Dec 31 kill and its
  # Jan 1 systemd line parse ~365 days apart instead of seconds (live-proven:
  # Dec 31 23:59:30 -> Jan 01 00:00:05 parses to -31,535,965 s).  The true
  # delta is recovered by also trying +-365 d and +-366 d (leap years) and
  # keeping the candidate with the smallest absolute value — for any normal
  # intra-boot gap the raw delta itself wins, so the adjustment can never
  # pull a legitimately distant line into the window.
  local d best cand
  d=$(($2 - $1))
  best=$((d < 0 ? -d : d))
  for off in 31536000 -31536000 31622400 -31622400; do
    cand=$((d + off))
    [ "$cand" -lt 0 ] && cand=$((-cand))
    [ "$cand" -lt "$best" ] && best=$cand
  done
  echo "$best"
}

bep_killpass_join() {
  # <dump> <oom> — per-victim memcg join over the kernel kill pass (the
  # Oct-28 10:15 cascade class: `Out of memory: Killed process PID ...`
  # lines whose pid has NO matching `oom-kill:...task_memcg=` line).  A
  # global-OOM pass can kill several processes while the kernel only
  # prints the task_memcg line for its SELECTED victim, so per-victim
  # memcg must be JOINED, never inferred in prose.  Basis levels:
  #   attested   — kernel `oom-kill:` line names the pid's task_memcg
  #   unit-join  — systemd `<unit>: The kernel OOM killer killed some
  #                processes in this unit.` lines within the join window
  #                (unit-level evidence, NOT a kernel-attested path);
  #                candidates are ranked leaf-over-slice and
  #                uid-consistent (counter-uid units excluded), and ALL
  #                tied top-ranked units are listed with " | " when the
  #                pass cannot disambiguate
  #   UNRESOLVED — no join found; the section names the gap instead of
  #                fabricating a cgroup path
  # Window: 60 s. Calibrated 2026-11-02 over the two live OOM boots —
  # b0d70d73 (systemd lines LEAD kernel kills, up to exactly -30 s:
  # session-74.scope sat ON the old +-30 edge and a -31 s line would
  # silently miss) and 7b12c3db (systemd lines LAG 1-8 s). Join output
  # is byte-identical at 30/45/60 on both boots (counter-uid exclusion +
  # leaf-over-slice + uid-shape scoring absorb the wider net), so 60 s
  # is pure margin for the async-cgroup-notification lead class.  Deltas
  # are year-boundary safe (bep_ts_delta; Dec->Jan kill windows recover
  # their true seconds from the year-blind syslog timestamps).
  local dump="$1" oom="$2" win=60
  local kills kline pid task uid ts uts att line unit lts lus udiff score bestscore first cand
  kills=$(grep -E 'Out of memory: Killed process' "$dump" || true)
  if [ -z "$kills" ]; then
    return 0
  fi
  printf '%s\n' "$kills" | while IFS= read -r kline; do
    pid=$(printf '%s\n' "$kline" | sed -n 's/.*Killed process \([0-9][0-9]*\).*/\1/p')
    task=$(printf '%s\n' "$kline" | sed -n 's/.*Killed process [0-9][0-9]* (\([^)]*\)).*/\1/p')
    uid=$(printf '%s\n' "$kline" | sed -n 's/.*UID:\([0-9][0-9]*\).*/\1/p')
    ts=$(printf '%s\n' "$kline" | awk '{print $1, $2, $3}')
    uts=$(date -d "$ts" +%s 2>/dev/null || echo 0)
    att=$(grep -E ",pid=${pid}(,|$)" "$oom" 2>/dev/null | sed -n 's/.*task_memcg=\([^,]*\).*/\1/p' | head -n 1 || true)
    if [ -n "$att" ]; then
      printf 'pid=%s task=%s uid=%s memcg=%s basis=attested\n' "$pid" "$task" "$uid" "$att"
      continue
    fi
    bestscore=""
    cands=""
    while IFS= read -r line; do
      unit=$(printf '%s\n' "$line" | sed -n 's/.*systemd\[[0-9]*\]: \([^:]*\): The kernel OOM killer killed.*/\1/p')
      [ -n "$unit" ] || continue
      udiff=$((win + 1))
      if [ "$uts" -gt 0 ]; then
        lts=$(printf '%s\n' "$line" | awk '{print $1, $2, $3}')
        lus=$(date -d "$lts" +%s 2>/dev/null || echo 0)
        [ "$lus" -gt 0 ] && udiff=$(bep_ts_delta "$uts" "$lus")
      fi
      [ "$udiff" -le "$win" ] || continue
      # Counter-uid exclusion: a user@975 line cannot evidence a uid-1000
      # victim (live Oct-28: the hermes scope's line sat closest to the
      # session-74 kills and would have won on proximity alone), and NO
      # user-flavored unit can evidence a uid-0 (system) victim — the
      # win=60 calibration pass would otherwise let a -58 s session line
      # join an unrelated uid-0 kill.
      case "$unit" in
      user@*.service | user-*.slice)
        [ "$uid" = 0 ] && continue
        if [ -n "$uid" ]; then
          u2=$(printf '%s' "$unit" | sed -E 's/^user[@-]([0-9]+)\.(service|slice)$/\1/')
          [ "$u2" != "$uid" ] && continue
        fi
        ;;
      session-*.scope)
        [ "$uid" = 0 ] && continue
        ;;
      esac
      # Leaf units (.scope/.service) beat parent aggregates (.slice):
      # systemd emits OOM-unit lines for BOTH and the closest line can be
      # the slice (live Oct-28: system.slice at +18 s vs session-74.scope
      # at -30 s).  Units whose name carries the victim's uid discriminator
      # (session-*.scope, user@<uid>, user-<uid>.) rank above unshaped
      # scopes, so a foreign scope (the hermes-worker-cron exec scope does
      # not embed its uid in the name) cannot outrank the victim's own
      # session units.  Ties keep the full winner set for honest listing.
      score=$udiff
      case "$unit" in
      *.slice) score=$((score + 1000000)) ;;
      *.scope | *.service) score=$((score - 1000)) ;;
      esac
      case "$unit" in
      session-*.scope) [ -n "$uid" ] && score=$((score - 500)) ;;
      user@"$uid".service | user-"$uid".*) [ -n "$uid" ] && score=$((score - 500)) ;;
      esac
      if [ -z "$bestscore" ] || [ "$score" -lt "$bestscore" ]; then
        bestscore=$score
        cands="$unit"
      elif [ "$score" -eq "$bestscore" ]; then
        case "
$cands" in
        *"$unit"*) : ;;
        *) cands="$cands
$unit" ;;
        esac
      fi
    done < <(grep -F 'The kernel OOM killer killed' "$dump" || true)
    if [ -n "$cands" ]; then
      printf 'pid=%s task=%s uid=%s' "$pid" "$task" "$uid"
      first=1
      while IFS= read -r cand; do
        [ -n "$first" ] && printf ' ' || printf ' | '
        printf 'unit=%s' "$cand"
        first=""
      done <<<"$cands"
      printf ' basis=unit-join (systemd unit-level evidence, NOT a kernel-attested memcg path; tied candidates listed when the pass cannot disambiguate)\n'
    else
      printf 'pid=%s task=%s uid=%s memcg=UNRESOLVED basis=none (no task_memcg line and no systemd OOM-unit join in the dump)\n' "$pid" "$task" "$uid"
    fi
  done
}

bep_grep_guard() {
  grep -F 'memory-emergency-guard' "$1" || true
}

bep_grep_thermal() {
  grep -F 'THERMAL THROTTLE' "$1" || true
}

# Real kernel crash signatures, and nothing else (2026-11-26).  The loose
# `kernel:.*(panic|BUG|oops)` grep counted 4 benign lines on EVERY boot (two
# command-line echoes carrying `panic=` / `hung_task_panic=`, two `[drm]
# Registered N planes with drm panic` lines) while a real `Oops:` never
# matched (the pattern had a lowercase `oops` and no `Oops:`).  A signature
# must OPEN the kernel message: journalctl prints kernel lines as `<stamp>
# <host> kernel: <message>`, and every crash print below starts its message
# with the signature (a page-fault oops prints `BUG: unable to handle ...`).
# The second pass names the boot-noise shapes explicitly, so a later
# loosened signature cannot re-admit them (both echo spellings: `Command
# line:` and `Kernel command line:` differ in the case of the first letter).
BEP_PANIC_SIG='[[:space:]]kernel:[[:space:]]*(Oops:|Kernel panic|kernel BUG|BUG:|general protection fault|unable to handle kernel paging request)'
BEP_PANIC_NOISE='kernel:.*([Cc]ommand line:|\[drm\])'

bep_grep_panic() {
  grep -E "$BEP_PANIC_SIG" "$1" | grep -Ev "$BEP_PANIC_NOISE" || true
}

bep_fenced() {
  # <file> — print the file inside a fenced code block (sections are
  # always fenced even when empty, so the file is grep-stable).
  printf '```\n'
  cat "$1"
  printf '```\n'
}

bep_epoch_ns() {
  # <"YYYY-MM-DD HH:MM:SS"> — journalctl (LOCAL time) stamp -> epoch-ns.
  printf '%s000000000\n' "$(date -d "$1" +%s)"
}

# Positive-control window of the ClickHouse section: the seconds ENDING at the
# journal cut.  600 s (2026-11-26): the measured behind-tail cut (boot
# 8b31b428) held 11154 rows in that window and 0 rows after the cut, and a
# pipeline that is merely quiet for a minute (a low-traffic stretch, a batch
# interval) must not pass for a dead one.
BEP_CH_CONTROL_S=600

bep_ch_verdict() {
  # <death-window rows> <control-window rows> -> alive-fresher | alive-behind | dark
  if [ "$1" -gt 0 ]; then
    # Rows at/after the cut are their own proof of life, whatever the
    # control window holds (2026-11-26).
    printf 'alive-fresher\n'
  elif [ "$2" -gt 0 ]; then
    printf 'alive-behind\n'
  else
    printf 'dark\n'
  fi
  return 0
}

bep_render_ch() {
  # <lo-ns> <hi-ns> <tail-n> <status> <tsv-file> <ctl-file>: ClickHouse
  # death-window section. Pure: reads only its arguments/files, so the
  # selftest drives it with fixture TSVs (no clickhouse-client).
  # <status>: ok | empty | failed:<reason> | skipped:<reason>
  # <tsv-file>: "timestamp<TAB>body" rows, timestamp DESC (row 1 = newest).
  # <ctl-file>: the positive-control row "count<TAB>max-ns<TAB>min-ns" of the
  # control window before the cut; count() is a FULL count (a LIMIT-bounded
  # tail is no census).  Read only for ok/empty; a malformed row fails loud
  # instead of deciding the verdict on a guess.
  local lo="$1" hi="$2" tail_n="$3" status="$4" tsv="$5" ctl="$6"
  local lo_h hi_h ctl_lo ctl_lo_h max_ns max_h rows verdict v
  # Initialized, not just declared: `local x` leaves x UNSET, and a verdict
  # leg that never formats the control stamps must not die on it under -u.
  local ctl_row='' ctl_rows=0 ctl_max=0 ctl_min=0 ctl_max_h='' ctl_min_h='' lag_s=''
  lo_h=$(date -u -d "@$((lo / 1000000000))" '+%Y-%m-%d %H:%M:%S')
  hi_h=$(date -u -d "@$((hi / 1000000000))" '+%Y-%m-%d %H:%M:%S')
  ctl_lo=$((lo - BEP_CH_CONTROL_S * 1000000000))
  [ "$ctl_lo" -ge 0 ] || ctl_lo=0
  ctl_lo_h=$(date -u -d "@$((ctl_lo / 1000000000))" '+%Y-%m-%d %H:%M:%S')

  cat <<EOF
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: $lo -> $hi epoch-ns UTC ($lo_h -> $hi_h UTC)
Control window (positive control, 2026-11-26): $ctl_lo -> $lo epoch-ns UTC ($ctl_lo_h -> $lo_h UTC), the $BEP_CH_CONTROL_S s before the cut; the verdict below rests on BOTH windows, so 0 rows after the cut alone are never read as a dead pipeline.
EOF
  case "$status" in
  ok | empty)
    ctl_row=$(cat "$ctl")
    [ "$(grep -c '' "$ctl")" = 1 ] || {
      echo "internal error: ClickHouse control row must be exactly one line" >&2
      return 1
    }
    IFS=$'\t' read -r ctl_rows ctl_max ctl_min <<<"$ctl_row"
    for v in "$ctl_rows" "$ctl_max" "$ctl_min"; do
      case "$v" in
      '' | *[!0-9]*)
        echo "internal error: malformed ClickHouse control row: $ctl_row" >&2
        return 1
        ;;
      esac
    done
    rows=$(wc -l <"$tsv")
    verdict=$(bep_ch_verdict "$rows" "$ctl_rows")
    # count() = 0 prints 0 for max and min: no stamps to format then.
    if [ "$ctl_rows" -gt 0 ]; then
      ctl_max_h=$(date -u -d "@$((ctl_max / 1000000000))" '+%Y-%m-%d %H:%M:%S')
      ctl_min_h=$(date -u -d "@$((ctl_min / 1000000000))" '+%Y-%m-%d %H:%M:%S')
    fi
    ;;
  esac

  case "$status" in
  ok)
    max_ns=$(head -n 1 "$tsv" | cut -f1)
    max_h=$(date -u -d "@$((max_ns / 1000000000))" '+%Y-%m-%d %H:%M:%S')
    printf 'Pipeline ALIVE in this window: newest row: %s (%s UTC); rows fetched: %s (last %s by timestamp DESC). Per M22 pull BOTH sources: ClickHouse is fresher than the journal cut by the flush lag.\n' "$max_ns" "$max_h" "$rows" "$tail_n"
    printf 'Verdict: %s. The death window holds %s row(s) (newest %s = %s UTC). Control window (the %s s before the cut): %s row(s)' \
      "$verdict" "$rows" "$max_ns" "$max_h" "$BEP_CH_CONTROL_S" "$ctl_rows"
    if [ "$ctl_rows" -gt 0 ]; then
      printf ', newest %s = %s UTC, oldest %s = %s UTC' "$ctl_max" "$ctl_max_h" "$ctl_min" "$ctl_min_h"
    fi
    printf '.\n'
    printf '\nLast rows (timestamp<TAB>body, newest first):\n'
    bep_fenced "$tsv"
    ;;
  empty)
    case "$verdict" in
    alive-behind)
      lag_s=$(((lo - ctl_max) / 1000000000))
      printf 'Verdict: alive-behind. The pipeline was alive BEFORE the journal cut: the control window (the %s s before the cut) holds %s row(s), newest %s = %s UTC, %s s before the cut. The death window holds 0 rows because the remote tail is BEHIND the journal cut, so the empty window is NOT evidence of a dead pipeline (until 2026-11-26 this state was reported as a dark pipeline). ClickHouse holds nothing newer than the cut: the final flush gap of the journal is NOT covered by the remote tail for this boot.\n' \
        "$BEP_CH_CONTROL_S" "$ctl_rows" "$ctl_max" "$ctl_max_h" "$lag_s"
      ;;
    dark)
      printf 'Verdict: dark. 0 rows in the control window (the %s s before the cut) and 0 rows in the death window: the pipeline emitted nothing across the cut.\n' "$BEP_CH_CONTROL_S"
      printf 'Per M22: ClickHouse absence is NOT evidence of absence: the collector has a fatal-at-startup failure mode that silences the whole log pipeline (proven #37). Cross-check signoz-collector liveness across this boot BEFORE trusting the gap.\n'
      ;;
    esac
    bep_fenced /dev/null
    ;;
  failed:*)
    printf 'Verdict: unknown (no verdict: a query FAILED; the verdict needs both windows).\n'
    printf 'clickhouse query FAILED: %s\n' "${status#failed:}"
    printf 'Remote tail unavailable for this window — same M22 caveat: absence here is NOT evidence of absence; cross-check signoz-collector liveness across this boot.\n'
    bep_fenced /dev/null
    ;;
  skipped:*)
    printf 'Verdict: unknown (no verdict: the query was SKIPPED; the verdict needs both windows).\n'
    printf 'Remote tail SKIPPED: %s\n' "${status#skipped:}"
    printf 'Journal-only evidence — M22: check signoz-collector liveness before inferring quiet; ClickHouse may hold the window the journal flushed away.\n'
    bep_fenced /dev/null
    ;;
  *)
    echo "internal error: unknown bep_render_ch status: $status" >&2
    return 1
    ;;
  esac
  return 0
}

bep_ch_fetch() {
  # <lo-ns> <hi-ns> <tail-n> <outfile> <errfile> <ctl-outfile>: LIVE
  # clickhouse-client probe: the positive-control aggregate FIRST, then the
  # death-window tail; prints a status token on stdout
  # (ok | empty | failed:<reason> | skipped:<reason>). Never throws: the
  # pipeline state is evidence context, not a pull failure (M22).
  local lo="$1" hi="$2" tail_n="$3" out="$4" err="$5" ctl_out="$6" reason
  command -v clickhouse-client >/dev/null 2>&1 || {
    printf 'skipped:clickhouse-client not on PATH\n'
    return 0
  }
  # An aggregate on purpose: count() is the FULL row count of the control
  # window (a tail bounded by LIMIT would cap it) and max(timestamp) is the
  # newest row before the cut.  The window is half-open on the cut so the
  # two windows partition [control start -> next boot].
  if ! timeout 30 clickhouse-client --format TSV --query \
    "SELECT count(), max(timestamp), min(timestamp) FROM signoz_logs.distributed_logs_v2 WHERE timestamp >= $((lo - BEP_CH_CONTROL_S * 1000000000)) AND timestamp < $lo" \
    >"$ctl_out" 2>"$err"; then
    reason=$(head -n 1 "$err")
    printf 'failed:%s\n' "${reason:-clickhouse-client exited non-zero (control window)}"
    return 0
  fi
  if ! timeout 30 clickhouse-client --format TSV --query \
    "SELECT timestamp, body FROM signoz_logs.distributed_logs_v2 WHERE timestamp >= $lo AND timestamp <= $hi ORDER BY timestamp DESC LIMIT $tail_n" \
    >"$out" 2>"$err"; then
    reason=$(head -n 1 "$err")
    printf 'failed:%s\n' "${reason:-clickhouse-client exited non-zero}"
    return 0
  fi
  if [ -s "$out" ]; then
    printf 'ok\n'
  else
    printf 'empty\n'
  fi
  return 0
}

# The kdump capture line is searched in the journal of the minutes AFTER the
# journal cut, not by boot selector: a capture boot has its own boot id and
# may or may not have made it into the boot index (it never did on the
# failing cuts), so only a time range finds its kdump-save line either way.
# 10 min (2026-11-26): the capture boot races the 90 s hardware watchdog and
# the next boot started 60-67 s after the cut on record.
BEP_KDUMP_WINDOW_MIN=10
# The two lines kdump-save.service prints (modules/nixos/services/
# _kdump-capture-units.nix).  Matched on MESSAGE text: no journal identifier
# of a capture boot has ever been observed live, so a selector could match
# nothing and read as "no line".
BEP_KDUMP_SIG='kdump-save: (wrote /var/crash/|vmcore-dmesg FAILED)'
BEP_PSTORE_HEADING='pstore (EFI) crash dump and kdump capture line (read from the next boot)'

bep_kdump_range() {
  # <since-ts> <until-ts>: the journal between two local-time stamps
  # ("YYYY-MM-DD HH:MM:SS", the form --list-boots prints), UNFILTERED.  The
  # caller greps the text afterwards: in a pipeline, pipefail would merge a
  # FAILED read with a grep that found nothing into one rc, and an unread
  # journal is not an empty one.  Reads through the library seam, so one
  # stub covers the records query and this range.
  local jc
  jc=$(pstore_journalctl_cmd)
  command -v "$jc" >/dev/null 2>&1 || {
    echo "journalctl command not found: $jc" >&2
    return 1
  }
  "$jc" --quiet --no-pager -o short-iso --since "$1" --until "$2"
}

bep_kdump_verdict() {
  # <state: saved|failed|none|error|nonext> <kdump-save journal lines, or
  # the error text> <pstore token> <pstore fetch: ok|error|nonext>: the
  # kdump capture line(s) on stdout. Pure.
  # The kdump-save JOURNAL lines decide; only their absence is read against
  # the pstore token, and a token of `none` never becomes "no crash".
  local state="$1" text="$2" token="$3" fetch="$4" n
  case "$state" in
  saved | failed)
    n=$(printf '%s\n' "$text" | grep -c '')
    if [ "$state" = saved ]; then
      printf 'kdump: capture SAVED: kdump-save.service ran in the capture boot and wrote the dmesg of the crashed kernel under /var/crash (%s kdump-save journal line(s) in the %s min after the cut, listed below; read the vmcore-dmesg.txt as root).\n' \
        "$n" "$BEP_KDUMP_WINDOW_MIN"
    else
      printf 'kdump: capture FAILED: kdump-save.service ran but vmcore-dmesg FAILED, so the dmesg of the crashed kernel was not written under /var/crash for this cut (%s kdump-save journal line(s) in the %s min after the cut, listed below); pstore is the fallback the unit itself names.\n' \
        "$n" "$BEP_KDUMP_WINDOW_MIN"
    fi
    printf '%s\n' '```'
    printf '%s\n' "$text"
    printf '%s\n' '```'
    ;;
  none)
    case "$fetch:$token" in
    error:*)
      printf 'kdump: capture UNKNOWN: no kdump-save journal line in the %s min after the cut, and the pstore read FAILED, so whose dump it is stays unknown (fetch=error is not a "no dump" answer; read /var/crash and /var/lib/systemd/pstore as root).\n' \
        "$BEP_KDUMP_WINDOW_MIN"
      ;;
    *:capture-kernel-OOM | *:capture-kernel-panicked)
      printf 'kdump: capture FAILED: no kdump-save journal line in the %s min after the cut and the pstore dump is the panic of the capture kernel itself (token=%s: the capture boot died before kdump-save could leave a line; confirm /var/crash as root).\n' \
        "$BEP_KDUMP_WINDOW_MIN" "$token"
      ;;
    *:main-kernel-panic-captured)
      printf 'kdump: capture UNKNOWN: the pstore dump is the panic text of the main kernel, but no kdump-save journal line exists in the %s min after the cut (the capture boot may not have persisted its journal; read /var/crash as root before concluding the vmcore-dmesg is missing).\n' \
        "$BEP_KDUMP_WINDOW_MIN"
      ;;
    *)
      printf 'kdump: capture UNKNOWN: no kdump-save journal line in the %s min after the cut and no pstore dump was archived by the next boot (token=%s). Expected after a clean shutdown or a cut that took no panic path; when the ledger calls this boot a crash, read /var/crash and /var/lib/systemd/pstore as root before concluding nothing was captured.\n' \
        "$BEP_KDUMP_WINDOW_MIN" "$token"
      ;;
    esac
    ;;
  error)
    printf 'kdump: capture UNKNOWN: the journal read for the %s min after the cut FAILED (%s): no verdict, an unread journal is not an empty one.\n' \
      "$BEP_KDUMP_WINDOW_MIN" "$text"
    ;;
  nonext)
    printf 'kdump: capture UNKNOWN: no next boot in the journal, so neither a capture boot nor an archive of the dump of this boot can show up yet.\n'
    ;;
  *)
    echo "internal error: unknown kdump state: $state" >&2
    return 1
    ;;
  esac
  return 0
}

bep_render_pstore() {
  # <next-boot-id or ''> <facts-block> <records-listing-file> <kdump-text>:
  # pstore section on stdout. Pure: reads only its arguments/files.
  local next="$1" facts="$2" records="$3" kdump="$4"
  local fetch n fetch_err
  fetch=$(pstore_fact "$facts" fetch || true)
  n=$(pstore_fact "$facts" records || true)
  fetch_err=$(pstore_fact "$facts" fetch_err || true)
  cat <<EOF
## $BEP_PSTORE_HEADING

systemd-pstore.service archives the EFI pstore dump of a panic at the start of the boot AFTER the crash, so this section reads the NEXT boot, not this one. With a crash image loaded the surviving dump is often the log of the CAPTURE kernel (512 MiB kernel: "N pages RAM" below 2000000), not of the main kernel: the token says whose log it is (decoded by scripts/lib/pstore-records.sh).
Records: journalctl -b <next boot> -o json SYSLOG_IDENTIFIER=systemd-pstore, the validated unprivileged selector (on systemd 262 _SYSTEMD_UNIT=systemd-pstore.service and _COMM=systemd-pstore match nothing; /var/lib/systemd/pstore and /var/crash are root-only).
kdump: the journal of the $BEP_KDUMP_WINDOW_MIN min after the cut, matched on the two lines kdump-save.service prints ("kdump-save: wrote /var/crash/" = saved, "kdump-save: vmcore-dmesg FAILED" = failed; modules/nixos/services/_kdump-capture-units.nix).
An empty read is never evidence: records=0 means "that boot archived no dump", never "no crash".
Next boot: ${next:-NONE (this is the newest boot in the journal)}
EOF
  printf '%s\n' "$facts"
  if [ "$fetch" = error ]; then
    printf 'pstore read FAILED: %s (fetch=error: the journal could not be read; the token above is the zero-record default and NOT a "no dump" answer).\n' \
      "${fetch_err:-journalctl exited non-zero}"
  fi
  printf '\nRecords (%s; dump order, highest part first: Part1 holds the newest lines):\n' "${n:-0}"
  bep_fenced "$records"
  # Trailing newline on purpose: the text arrived through a command
  # substitution, which strips it, and bep_render adds the blank line that
  # separates this section from the next heading.
  printf '\n%s\n' "$kdump"
  return 0
}

bep_pstore_live() (
  # <next-boot-id or ''> <journal-cut-ts>: pstore section on stdout. The one
  # impure pstore function: it reads the journal (through the library seam,
  # which the selftest stubs). Subshell body: the parse globals and the
  # scratch-dir EXIT trap stay scoped (same bash 5.3 hazard as bep_render).
  # Never fails: every read state renders as text, the pull goes on.
  local next="$1" cut="$2" tmp jsonl fetch=nonext fetch_err='' facts kdump_state=nonext kdump_text='' range until token
  if [ -z "${PSTORE_RECORDS_LOADED:-}" ]; then
    printf '## %s\n\npstore: helper library MISSING at %s, so this section was NOT read (re-run the pull from a tree that carries scripts/lib/pstore-records.sh). An unread section is not a "no dump" answer.\n' \
      "$BEP_PSTORE_HEADING" "$BEP_PSTORE_LIB"
    return 0
  fi
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  : >"$tmp/records"
  facts=$'token=none\nfetch=nonext'
  if [ -n "$next" ]; then
    if jsonl=$(pstore_journal_fetch "$next" 2>"$tmp/fetch.err"); then
      fetch=ok
    else
      # Not an answer: the block keeps the zero-record shape and says so.
      fetch=error
      jsonl=''
      fetch_err=$(head -n 1 "$tmp/fetch.err")
    fi
    pstore_jsonl_parse <<<"$jsonl"
    facts=$(
      pstore_facts
      printf 'fetch=%s\n' "$fetch"
      [ -z "$fetch_err" ] || printf 'fetch_err=%s\n' "$fetch_err"
    )
    pstore_records_list >"$tmp/records"
    # kdump-save lines of the minutes after the cut.  Both reads are
    # separated from their grep so a FAILED read never renders as "no
    # line".
    if until=$(date -d "$cut $BEP_KDUMP_WINDOW_MIN minutes" '+%Y-%m-%d %H:%M:%S' 2>"$tmp/kdump.err") &&
      range=$(bep_kdump_range "$cut" "$until" 2>"$tmp/kdump.err"); then
      kdump_text=$(printf '%s\n' "$range" | grep -E "$BEP_KDUMP_SIG" || true)
      if printf '%s\n' "$kdump_text" | grep -q 'vmcore-dmesg FAILED'; then
        kdump_state=failed
      elif [ -n "$kdump_text" ]; then
        kdump_state=saved
      else
        kdump_state=none
      fi
    else
      kdump_state=error
      kdump_text=$(head -n 1 "$tmp/kdump.err")
    fi
  fi
  token=$(pstore_fact "$facts" token || true)
  kdump_text=$(bep_kdump_verdict "$kdump_state" "$kdump_text" "$token" "$fetch")
  bep_render_pstore "$next" "$facts" "$tmp/records" "$kdump_text"
)

bep_render() (
  # <journal-dump> <id8> <full-id> <first-ts> <last-ts> <ch-section-file>
  # <pstore-section-file>: canonical evidence sections on stdout. Pure:
  # reads only its arguments/files, so the selftest can drive it without
  # journalctl or clickhouse-client (the CH and pstore sections are
  # pre-rendered by bep_render_ch and bep_pstore_live).
  # Subshell body so the temp-dir EXIT trap cannot reference a popped
  # function local (bash 5.3 destroys locals BEFORE a RETURN trap runs).
  local dump="$1" id8="$2" fullid="$3" first_ts="$4" last_ts="$5" ch_sect="$6" pstore_sect="$7"
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  bep_grep_oom "$dump" >"$tmp/oom"
  bep_killpass_join "$dump" "$tmp/oom" >"$tmp/killjoin"
  bep_grep_guard "$dump" >"$tmp/guard"
  bep_grep_thermal "$dump" >"$tmp/thermal"
  bep_grep_panic "$dump" >"$tmp/panic"

  local n_oom n_guard n_thermal n_panic
  n_oom=$(wc -l <"$tmp/oom")
  n_guard=$(wc -l <"$tmp/guard")
  n_thermal=$(wc -l <"$tmp/thermal")
  n_panic=$(wc -l <"$tmp/panic")
  local n_killed n_att n_join
  n_killed=$(grep -c 'basis=' "$tmp/killjoin" || true)
  n_att=$(grep -c 'basis=attested' "$tmp/killjoin" || true)
  n_join=$(grep -c 'basis=unit-join' "$tmp/killjoin" || true)

  cat <<EOF
# Boot evidence pull: id8 $id8 (full: $fullid)

Pulled $(date -u '+%Y-%m-%d %H:%M UTC') by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: $first_ts -> $last_ts (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 $id8 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
$(bep_fenced <(head -n 3 "$dump"))

### Last 12 lines
$(bep_fenced <(tail -n 12 "$dump"))

## Census
- oom-lines: $n_oom
- oom kill-pass join: $n_killed killed process(es) — $n_att memcg-attested, $n_join unit-joined, $((n_killed - n_att - n_join)) unresolved
- guard-lines (memory-emergency-guard): $n_guard
- thermal-THROTTLE-lines: $n_thermal
- kernel panic/BUG/oops lines: $n_panic (real kernel crash signatures only: Oops:, Kernel panic, kernel BUG, BUG:, general protection fault, unable to handle kernel paging request; command-line echoes and [drm] lines are not counted)

## Kernel OOM lines (all)
$(bep_fenced "$tmp/oom")

## OOM kill-pass join — memcg per killed process (kernel-attested or systemd unit-join, never inferred)
$(bep_fenced "$tmp/killjoin")

## memory-emergency-guard lines (all)
$(bep_fenced "$tmp/guard")

## THERMAL THROTTLE lines
$(bep_fenced "$tmp/thermal")

## Kernel panic/BUG/oops lines
EOF
  if [ "$n_panic" -gt 100 ]; then
    {
      head -n 25 "$tmp/panic"
      echo "... TRUNCATED ($n_panic total; showing first 25 / last 25)"
      tail -n 25 "$tmp/panic"
    } >"$tmp/panic.bounded"
    bep_fenced "$tmp/panic.bounded"
  else
    bep_fenced "$tmp/panic"
  fi
  printf '\n'
  cat "$pstore_sect"
  printf '\n'
  cat "$ch_sect"
)

bep_write() {
  # <target> — stdin to the target; '-' = stdout. Never overwrites an
  # existing evidence file (append-only artifact discipline).
  local target="$1"
  if [ "$target" = "-" ]; then
    cat
    return 0
  fi
  if [ -e "$target" ]; then
    echo "REFUSING to overwrite existing evidence file: $target (evidence files are append-only — pass -o with another path)" >&2
    return 1
  fi
  mkdir -p "$(dirname "$target")"
  cat >"$target"
  echo "evidence file written: $target" >&2
  echo "next: git add + commit it, then re-run scripts/pre-vacuum-evidence-gate.sh" >&2
}

# ── selftest (no journalctl; fixtures only) ──────────────────────────────

bep_selftest() (
  # Subshell body: scratch-dir EXIT trap + exit statuses stay scoped to
  # the selftest (same bash 5.3 RETURN-trap/locals hazard as bep_render).
  local failures=0 tmp out
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  check() { # <desc> <cmd...>
    local desc="$1"
    shift
    if "$@"; then
      :
    else
      echo "FAIL: $desc"
      failures=$((failures + 1))
    fi
  }

  # Fixture journal: filler + known signal lines.
  {
    for i in $(seq 1 30); do echo "Oct 11 12:00:0$i evo-x2 filler[$i]: noise $i"; done
    # Boot noise the panic census must NOT count (2026-11-26: these four
    # shapes were the whole "4 panic lines on every boot" census): the two
    # kernel command-line echoes carrying panic= / hung_task_panic= and the
    # two drm-panic plane registrations.
    echo "Oct 11 12:00:31 evo-x2 kernel: Command line: BOOT_IMAGE=/boot/vmlinuz-7.3.5-initrd.efi initrd=/EFI/nixos/zw52sl67fam8mzql38b1lg7078p0113f-initrd-linux-7.3.5-initrd.efi crashkernel=512M nmi_watchdog=panic softlockup_panic=1 hung_task_panic=1"
    echo "Oct 11 12:00:31 evo-x2 kernel: Kernel command line: BOOT_IMAGE=/boot/vmlinuz-7.3.5-initrd.efi crashkernel=512M nmi_watchdog=panic softlockup_panic=1 hung_task_panic=1"
    echo "Oct 11 12:00:32 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic"
    echo "Oct 11 12:00:34 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic"
    echo "Oct 11 23:00:01 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0"
    echo "Oct 11 23:00:01 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=1"
    echo "Oct 11 23:00:02 evo-x2 kernel: Out of memory: Killed process 1 (nix)"
    # Kill-pass join fixture (Oct-28 10:15 cascade class): a global pass
    # whose SELECTED victim carries task_memcg while a same-pass
    # chrome-headless kill gets NO oom-kill: line — plus the systemd
    # unit line the join keys on, and one fully unresolved victim.
    echo "Oct 11 23:10:01 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0"
    echo "Oct 11 23:10:01 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,global_oom,task_memcg=/user.slice/user-1000.slice/session-74.scope,task=chromium,pid=3392891,uid=1000"
    echo "Oct 11 23:10:01 evo-x2 kernel: Out of memory: Killed process 3392891 (chromium) total-vm:1518605956kB, UID:1000 oom_score_adj:300"
    echo "Oct 11 23:10:01 evo-x2 kernel: Out of memory: Killed process 3595707 (chrome-headless) total-vm:1518498916kB, UID:1000 oom_score_adj:300"
    echo "Oct 11 23:10:02 evo-x2 systemd[1]: session-74.scope: The kernel OOM killer killed some processes in this unit."
    echo "Oct 11 23:11:00 evo-x2 kernel: Out of memory: Killed process 424242 (ghost) total-vm:800kB, UID:0 oom_score_adj:0"
    # Join-window calibration legs (2026-11-02: win=60; systemd lines can
    # LEAD kernel kills — the Oct-28 correct join line sat at exactly -30 s
    # under the old win=30). One victim whose unit line leads by -45 s
    # (inside the window -> unit-join) and one at -121 s (outside ->
    # UNRESOLVED; the wider window must NOT fish it in).
    echo "Oct 11 23:20:01 evo-x2 kernel: Out of memory: Killed process 5000001 (early-lead) total-vm:100kB, UID:1000 oom_score_adj:0"
    echo "Oct 11 23:19:16 evo-x2 systemd[1]: session-77.scope: The kernel OOM killer killed some processes in this unit."
    echo "Oct 11 23:40:01 evo-x2 kernel: Out of memory: Killed process 5000002 (far-past) total-vm:100kB, UID:1000 oom_score_adj:0"
    echo "Oct 11 23:38:00 evo-x2 systemd[1]: session-78.scope: The kernel OOM killer killed some processes in this unit."
    echo "Oct 11 23:59:40 evo-x2 kernel: Out of memory: Killed process 6000001 (midnight) total-vm:100kB, UID:1000 oom_score_adj:0"
    echo "Oct 12 00:00:10 evo-x2 systemd[1]: session-79.scope: The kernel OOM killer killed some processes in this unit."
    echo "Oct 11 23:05:00 evo-x2 memory-emergency-guard-check[9]: MEMORY EMERGENCY: zone 6 trip"
    echo "Oct 11 23:15:00 evo-x2 thermal-pstate-guard-check[9]: THERMAL THROTTLE ENTER: amd_pstate -> guided"
    echo "Oct 11 23:20:00 evo-x2 kernel: BUG: unable to handle page fault"
  } >"$tmp/journal"
  printf '%s\n' '## Remote log tail (fixture)' '' '```plain' 'fixture row' '```' >"$tmp/ch-sect"
  printf '%s\n' '## pstore (EFI) crash dump and kdump capture line (fixture)' '' 'kdump: capture SAVED (fixture)' >"$tmp/pstore-sect"

  out=$(bep_render "$tmp/journal" "bf8a454c" "bf8a454cdeadbeef000000000000000000000000" "2026-10-11 11:09:43" "2026-10-12 13:04:01" "$tmp/ch-sect" "$tmp/pstore-sect")
  printf '%s\n' "$out" >"$tmp/evidence.md"

  check "census oom count" grep -q '^- oom-lines: 11$' "$tmp/evidence.md"
  check "census killpass join line" grep -q -- '- oom kill-pass join: 7 killed process(es) — 2 memcg-attested, 3 unit-joined, 2 unresolved' "$tmp/evidence.md"
  check "join: pid1 attested" grep -q 'pid=1 task=nix uid= memcg=/system.slice/tq-agent-pool.service basis=attested' "$tmp/evidence.md"
  check "join: chromium attested path" grep -q 'pid=3392891 task=chromium uid=1000 memcg=/user.slice/user-1000.slice/session-74.scope basis=attested' "$tmp/evidence.md"
  check "join: headless unit-joined" grep -q 'pid=3595707 task=chrome-headless uid=1000 unit=session-74.scope basis=unit-join' "$tmp/evidence.md"
  check "join: ghost unresolved" grep -q 'pid=424242 task=ghost uid=0 memcg=UNRESOLVED' "$tmp/evidence.md"
  check "join: -45 s lead joins" grep -q 'pid=5000001 task=early-lead uid=1000 unit=session-77.scope basis=unit-join' "$tmp/evidence.md"
  check "join: -121 s stays unresolved" grep -q 'pid=5000002 task=far-past uid=1000 memcg=UNRESOLVED' "$tmp/evidence.md"
  check "join: midnight +30 s joins" grep -q 'pid=6000001 task=midnight uid=1000 unit=session-79.scope basis=unit-join' "$tmp/evidence.md"
  check "join: section heading" grep -q '^## OOM kill-pass join' "$tmp/evidence.md"

  # Real-dump regression leg (2026-11-02 item-3): the committed sanitized
  # b0d70d73 cascade excerpt (tests/fixtures/boot-evidence-pull/) pins the
  # LIVE ranking the synthetic fixtures above missed — the first join
  # implementation ranked system.slice, then the hermes scope, over the
  # victim's own session units, and both mistakes were caught only by the
  # live run. The fixture freezes the exact systemd line order that
  # produced those traps, so a future ordering change re-fires HERE.
  local fixture_dir="${BEP_FIXTURE_DIR:-$REPO_ROOT/tests/fixtures/boot-evidence-pull}"
  if [ -f "$fixture_dir/b0d70d73-oom-cascade.dump" ]; then
    local fj foom
    fj=$(mktemp "$tmp/cascade.XXXXXX")
    foom=$(mktemp "$tmp/cascade.oom.XXXXXX")
    grep -E 'invoked oom-killer|oom-kill:|Out of memory' \
      "$fixture_dir/b0d70d73-oom-cascade.dump" >"$foom"
    bep_killpass_join "$fixture_dir/b0d70d73-oom-cascade.dump" "$foom" >"$fj"
    check "cascade: 9 victims joined" test "$(grep -c 'basis=' "$fj")" = 9
    check "cascade: 7 attested" test "$(grep -c 'basis=attested' "$fj")" = 7
    check "cascade: 2 unit-joined" test "$(grep -c 'basis=unit-join' "$fj")" = 2
    check "cascade: headless tie set exact" \
      grep -qF 'pid=3595707 task=chrome-headless uid=1000 unit=user@1000.service | unit=session-95.scope | unit=session-74.scope basis=unit-join' "$fj"
    check "cascade: second headless same tie" \
      grep -qF 'pid=3592942 task=chrome-headless uid=1000 unit=user@1000.service | unit=session-95.scope | unit=session-74.scope basis=unit-join' "$fj"
    check "cascade: system.slice NEVER wins a join" bash -c "! grep -qF 'unit=system.slice' '$fj'"
    check "cascade: hermes scope NEVER wins a uid-1000 join" \
      bash -c "! grep 'uid=1000' '$fj' | grep -qF 'hermes-worker-cron'"
    check "cascade: session-74 attested for chromium" \
      grep -qF 'pid=3392891 task=chromium uid=1000 memcg=/user.slice/user-1000.slice/session-74.scope basis=attested' "$fj"
    check "cascade: hermes chromium attested to its own scope" \
      grep -qF 'pid=44547 task=chromium uid=975 memcg=/user.slice/user-975.slice/user@975.service/app.slice/hermes-worker-cron-f59d5d8cfb7b-exec-bc914a5abdee4e77bb5b714e20c0cd2b.scope basis=attested' "$fj"
    rm -f "$fj" "$foom"
  else
    echo "FAIL: real-dump cascade fixture missing at $fixture_dir"
    failures=$((failures + 1))
  fi

  # Later-window record leg (2026-11-07 item): the committed sanitized
  # b0d70d73 LATER-window excerpt (17:49, 19:15/19:34, 20:43, 23:59→00:03)
  # pins the memcg-constraint class: every OOM outside the 10:14–10:15
  # global pass was CONSTRAINT_MEMCG with ONLY `oom-kill:` summary lines —
  # no `Out of memory: Killed process` line, no systemd OOM-unit line — so
  # the kill-pass join must emit NOTHING for those windows (the census
  # counts them; the join never fabricates a unit from a window that has
  # no per-victim kill line to anchor on).
  local flw foomlw fjoinlw
  flw="$fixture_dir/b0d70d73-later-windows.dump"
  if [ -f "$flw" ]; then
    foomlw=$(mktemp "$tmp/lw.oom.XXXXXX")
    fjoinlw=$(mktemp "$tmp/lw.join.XXXXXX")
    grep -E 'invoked oom-killer|oom-kill:|Out of memory' "$flw" >"$foomlw"
    check "later-windows: 4 memcg invocations" test "$(grep -c 'invoked oom-killer' "$foomlw")" = 4
    check "later-windows: 4 memcg oom-kill lines" test "$(grep -c 'oom-kill:' "$foomlw")" = 4
    check "later-windows: 0 Killed-process lines" test "$(grep -c 'Out of memory' "$foomlw")" = 0
    bep_killpass_join "$flw" "$foomlw" >"$fjoinlw"
    check "later-windows: join emits NOTHING" test ! -s "$fjoinlw"
    rm -f "$foomlw" "$fjoinlw"
  else
    echo "FAIL: later-windows fixture missing at $flw"
    failures=$((failures + 1))
  fi

  # Year-boundary legs (2026-11-07 item): syslog timestamps carry no year,
  # so a Dec 31 kill and its Jan 1 systemd line parse ~365 days apart under
  # GNU date (live-proven: -31,535,965 s for a true +35 s gap).  Each leg is
  # an isolated mini-dump so the year-recovered line is the ONLY candidate:
  #   lag   — systemd line Jan 1 (+35 s true) must join the Dec 31 kill
  #   lead  — systemd line Dec 31 (-55 s true) must join the Jan 1 kill
  #   far   — a Dec 31 line 310 s from the Jan 1 kill must stay out (the
  #           +-365/366 d rollover recovery must not fish it into the window)
  local fyr foomyr fjoinyr yr_case yr_dump
  for yr_case in lag lead far; do
    fyr=$(mktemp "$tmp/year.$yr_case.XXXXXX")
    foomyr=$(mktemp "$tmp/year.$yr_case.oom.XXXXXX")
    fjoinyr=$(mktemp "$tmp/year.$yr_case.join.XXXXXX")
    case "$yr_case" in
    lag)
      yr_dump="Dec 31 23:59:30|Jan 01 00:00:05|session-91.scope|6000011"
      ;;
    lead)
      yr_dump="Jan 01 00:00:40|Dec 31 23:59:45|session-92.scope|6000012"
      ;;
    far)
      yr_dump="Jan 01 00:05:00|Dec 31 23:59:50|session-93.scope|6000013"
      ;;
    esac
    {
      echo "${yr_dump%%|*} evo-x2 kernel: Out of memory: Killed process ${yr_dump##*|} (yearleg) total-vm:100kB, UID:1000 oom_score_adj:0"
      echo "$(printf '%s' "$yr_dump" | cut -d'|' -f2) evo-x2 systemd[1]: $(printf '%s' "$yr_dump" | cut -d'|' -f3): The kernel OOM killer killed some processes in this unit."
    } >"$fyr"
    grep -E 'invoked oom-killer|oom-kill:|Out of memory' "$fyr" >"$foomyr"
    bep_killpass_join "$fyr" "$foomyr" >"$fjoinyr"
    case "$yr_case" in
    lag)
      check "year: Dec->Jan lag +35 s joins" grep -qF 'pid=6000011 task=yearleg uid=1000 unit=session-91.scope basis=unit-join' "$fjoinyr"
      ;;
    lead)
      check "year: Dec->Jan lead -55 s joins" grep -qF 'pid=6000012 task=yearleg uid=1000 unit=session-92.scope basis=unit-join' "$fjoinyr"
      ;;
    far)
      check "year: 310 s across year stays unresolved" grep -qF 'pid=6000013 task=yearleg uid=1000 memcg=UNRESOLVED' "$fjoinyr"
      ;;
    esac
    rm -f "$fyr" "$foomyr" "$fjoinyr"
  done

  check "census guard count" grep -q '^- guard-lines (memory-emergency-guard): 1$' "$tmp/evidence.md"
  check "census thermal count" grep -q '^- thermal-THROTTLE-lines: 1$' "$tmp/evidence.md"
  check "census panic count (the 4 benign boot lines are in the fixture)" grep -q '^- kernel panic/BUG/oops lines: 1 (' "$tmp/evidence.md"
  check "census panic: command-line echo not listed" bash -c "! grep -q 'Command line:' '$tmp/evidence.md'"
  check "census panic: drm-panic line not listed" bash -c "! grep -q 'drm panic' '$tmp/evidence.md'"
  check "census panic: the real BUG line is listed" grep -qF 'kernel: BUG: unable to handle page fault' "$tmp/evidence.md"

  # Panic census defect shape (2026-11-26): 4 benign lines + 1 real `Oops:`
  # must count exactly 1 and list only the Oops line.  The third check
  # keeps the fixture honest: the retired loose pattern still counts the 4
  # noise lines and still misses the Oops, so this leg cannot go green by
  # the fixture losing its shape.
  cat >"$tmp/journal.panic" <<'PANIC'
Nov 25 11:06:52 evo-x2 kernel: Command line: BOOT_IMAGE=/boot/vmlinuz-7.3.5-initrd.efi crashkernel=512M nmi_watchdog=panic softlockup_panic=1 hung_task_panic=1
Nov 25 11:06:52 evo-x2 kernel: Kernel command line: BOOT_IMAGE=/boot/vmlinuz-7.3.5-initrd.efi crashkernel=512M nmi_watchdog=panic softlockup_panic=1 hung_task_panic=1
Nov 25 11:06:55 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Nov 25 11:06:58 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
Nov 25 11:07:02 evo-x2 kernel: Oops: 0000 [#1] PREEMPT SMP NOPTI
Nov 25 11:07:02 evo-x2 kernel: CPU: 0 UID: 0 PID: 1 Comm: systemd Not tainted 7.3.5 #1-NixOS
Nov 25 11:07:03 evo-x2 some-daemon[42]: Oops: user-space failure, not a kernel line
PANIC
  bep_grep_panic "$tmp/journal.panic" >"$tmp/panic.out"
  check "panic: 4 benign + 1 Oops counts exactly 1" test "$(grep -c '' "$tmp/panic.out")" = 1
  check "panic: only the Oops line is listed" grep -qxF 'Nov 25 11:07:02 evo-x2 kernel: Oops: 0000 [#1] PREEMPT SMP NOPTI' "$tmp/panic.out"
  check "panic: fixture keeps the defect shape (loose grep = 4 noise, 0 Oops)" \
    test "$(grep -E 'kernel:.*(panic|BUG|oops)' "$tmp/journal.panic" | grep -c 'Oops:'),$(grep -cE 'kernel:.*(panic|BUG|oops)' "$tmp/journal.panic")" = 0,4
  # The second pass must have teeth on its own: under a signature loosened
  # to any `panic` (which admits all 4 noise lines) the census still counts
  # the Oops line alone.  Found by a mutation run on 2026-11-26: the noise
  # pattern missed `Kernel command line:` (lowercase c) while the anchored
  # signature hid it.
  check "panic: noise pass filters the 4 benign lines on its own (loosened signature)" \
    test "$(BEP_PANIC_SIG='[[:space:]]kernel:[[:space:]]*(Oops:|.*panic)' bep_grep_panic "$tmp/journal.panic" | grep -c '')" = 1

  # Every signature of the set matches on its own; hang and lockup reports
  # (WARNING, hung task, soft lockup) are another census, not a crash line.
  cat >"$tmp/journal.sigs" <<'SIGS'
Nov 25 11:07:02 evo-x2 kernel: Oops: 0000 [#1] PREEMPT SMP NOPTI
Nov 25 11:07:02 evo-x2 kernel: Kernel panic - not syncing: Fatal exception
Nov 25 11:07:02 evo-x2 kernel: kernel BUG at kernel/sched/core.c:1234!
Nov 25 11:07:02 evo-x2 kernel: BUG: kernel NULL pointer dereference, address: 0000000000000012
Nov 25 11:07:02 evo-x2 kernel: general protection fault, probably for non-canonical address 0xdffffc0000000001
Nov 25 11:07:02 evo-x2 kernel: unable to handle kernel paging request at virtual address ffffffffl
Nov 25 11:07:02 evo-x2 kernel: BUG: unable to handle page fault for address: ffffc90000c67ffc
Nov 25 11:07:02 evo-x2 kernel: WARNING: CPU: 3 PID: 1 at kernel/sched/core.c:1234
Nov 25 11:07:02 evo-x2 kernel: INFO: task nix:1234 blocked for more than 120 seconds.
Nov 25 11:07:02 evo-x2 kernel: watchdog: BUG: soft lockup - CPU: 3 stuck at
SIGS
  check "panic: all 7 signature lines, none of the 3 hang lines" test "$(bep_grep_panic "$tmp/journal.sigs" | grep -c '')" = 7
  check "first line present" grep -q 'filler\[1\]: noise 1' "$tmp/evidence.md"
  check "last line present" grep -q 'BUG: unable to handle page fault' "$tmp/evidence.md"
  check "oom line preserved" grep -q 'invoked oom-killer' "$tmp/evidence.md"
  check "guard line preserved" grep -q 'MEMORY EMERGENCY: zone 6 trip' "$tmp/evidence.md"

  # Hex-boundary contract with the pre-vacuum gate: the header must cite
  # the id8 as a STANDALONE token (the gate greps (^|[^0-9a-f])id8([^0-9a-f]|$)).
  check "id8 standalone (gate grep hits)" \
    grep -qE '(^|[^0-9a-f])bf8a454c([^0-9a-f]|$)' "$tmp/evidence.md"
  # Negative control: a document that only embeds the id8 INSIDE the full
  # id must NOT match the gate grep (the phantom-green class the gate
  # exists to prevent).
  printf 'full: bf8a454cdeadbeef\n' >"$tmp/negative.md"
  if grep -qE '(^|[^0-9a-f])bf8a454c([^0-9a-f]|$)' "$tmp/negative.md"; then
    echo "FAIL: hex-boundary negative control must not match"
    failures=$((failures + 1))
  fi

  # Panic truncation: >100 kernel panic lines collapse to first 25 / last 25.
  {
    for i in $(seq 1 150); do echo "Oct 11 23:2$(printf '%02d' $((i % 10))):00 evo-x2 kernel: BUG: synthetic $i"; done
    for i in $(seq 1 5); do echo "Oct 11 23:30:0$i evo-x2 filler-trailing[$i]"; done
  } >"$tmp/journal.big"
  out=$(bep_render "$tmp/journal.big" "bf8a454c" "bf8a454cdeadbeef" "t1" "t2" "$tmp/ch-sect" "$tmp/pstore-sect")
  printf '%s\n' "$out" >"$tmp/evidence.big.md"
  check "truncation marker" grep -q 'TRUNCATED (150 total; showing first 25 / last 25)' "$tmp/evidence.big.md"
  check "truncated head present" grep -q 'synthetic 1$' "$tmp/evidence.big.md"
  check "truncated tail present" grep -q 'synthetic 150$' "$tmp/evidence.big.md"
  check "middle elided" bash -c '! grep -q "synthetic 80\$" '"$tmp"'/evidence.big.md'
  check "big census panic count" grep -q '^- kernel panic/BUG/oops lines: 150 (' "$tmp/evidence.big.md"

  # ClickHouse death-window section (M22): the verdict rests on BOTH windows
  # (2026-11-26).  <ctl-file> = one row "count, newest, oldest" of the
  # control window.  The behind numbers are the measured false-DARK cut
  # (boot 8b31b428): journal cut 1795601151 * 1e9, 11154 control rows,
  # newest 1795601140890453000 (10 s before the cut), 0 rows after the cut.
  printf '1790632991000000000\tnewest row body\n1790632891000000000\tolder row body\n' >"$tmp/ch.tsv"
  printf '700\t1790632985000000000\t1790632400000000000\n' >"$tmp/ch-ctl.tsv"
  bep_render_ch 1790632831000000000 1790633129000000000 20 ok "$tmp/ch.tsv" "$tmp/ch-ctl.tsv" >"$tmp/ch-ok.md"
  check "ch ok: window echoed" grep -qF 'Window: 1790632831000000000 -> 1790633129000000000' "$tmp/ch-ok.md"
  check "ch ok: newest row cited" grep -qF 'newest row: 1790632991000000000' "$tmp/ch-ok.md"
  check "ch ok: newest ns cited" grep -qF '1790632991000000000' "$tmp/ch-ok.md"
  check "ch ok: rows fetched count" grep -qF 'rows fetched: 2 (last 20' "$tmp/ch-ok.md"
  check "ch ok: bodies preserved" grep -qF 'newest row body' "$tmp/ch-ok.md"
  check "ch ok: M22 fresher note" grep -qF 'FRESHER than the journal cut' "$tmp/ch-ok.md"
  check "ch ok: verdict alive-fresher" grep -qF 'Verdict: alive-fresher.' "$tmp/ch-ok.md"
  check "ch ok: control window echoed" grep -qF 'Control window (positive control, 2026-11-26): 1790632231000000000 -> 1790632831000000000 epoch-ns UTC' "$tmp/ch-ok.md"
  check "ch ok: control count + newest row cited" grep -qF 'Control window (the 600 s before the cut): 700 row(s), newest 1790632985000000000' "$tmp/ch-ok.md"

  : >"$tmp/ch-empty.tsv"
  printf '11154\t1795601140890453000\t1795600551207406000\n' >"$tmp/ch-ctl.tsv"
  bep_render_ch 1795601151000000000 1795601211000000000 20 empty "$tmp/ch-empty.tsv" "$tmp/ch-ctl.tsv" >"$tmp/ch-behind.md"
  check "ch behind: verdict alive-behind" grep -qF 'Verdict: alive-behind.' "$tmp/ch-behind.md"
  check "ch behind: control count + newest row cited" grep -qF 'holds 11154 row(s), newest 1795601140890453000' "$tmp/ch-behind.md"
  check "ch behind: lag behind the cut cited" grep -qF '10 s before the cut' "$tmp/ch-behind.md"
  check "ch behind: not evidence of a dead pipeline" grep -qF 'NOT evidence of a dead pipeline' "$tmp/ch-behind.md"
  check "ch behind: NO dark verdict" bash -c "! grep -q 'Verdict: dark' '$tmp/ch-behind.md'"
  check "ch behind: legacy DARK banner retired" bash -c "! grep -q 'PIPELINE DARK' '$tmp/ch-behind.md'"

  # Rows after the cut with an EMPTY control window: the rows are their own
  # proof of life, so this cell must never fall through to dark either.
  printf '0\t0\t0\n' >"$tmp/ch-ctl.tsv"
  bep_render_ch 1790632831000000000 1790633129000000000 20 ok "$tmp/ch.tsv" "$tmp/ch-ctl.tsv" >"$tmp/ch-ok-noctl.md"
  check "ch rows-after-cut + empty control: alive-fresher" grep -qF 'Verdict: alive-fresher.' "$tmp/ch-ok-noctl.md"
  check "ch rows-after-cut + empty control: 0 control rows shown" grep -qF 'Control window (the 600 s before the cut): 0 row(s).' "$tmp/ch-ok-noctl.md"

  bep_render_ch 1000000000 2000000000 20 empty "$tmp/ch-empty.tsv" "$tmp/ch-ctl.tsv" >"$tmp/ch-dark.md"
  check "ch dark: verdict dark rests on both windows" grep -qF 'Verdict: dark. 0 rows in the control window (the 600 s before the cut) and 0 rows in the death window' "$tmp/ch-dark.md"
  check "ch dark: not-evidence-of-absence" grep -qF 'absence is NOT evidence of absence' "$tmp/ch-dark.md"
  check "ch dark: collector cross-check" grep -qF 'signoz-collector liveness' "$tmp/ch-dark.md"
  check "ch dark: legacy DARK banner retired" bash -c "! grep -q 'PIPELINE DARK FOR THIS WINDOW' '$tmp/ch-dark.md'"

  # A control row that is not exactly one numeric line must fail loud (the
  # verdict would otherwise rest on a guessed count), never render a section.
  printf 'garbage\n' >"$tmp/ch-ctl-bad.tsv"
  if bep_render_ch 1000000000 2000000000 20 empty "$tmp/ch-empty.tsv" "$tmp/ch-ctl-bad.tsv" >"$tmp/ch-bad.md" 2>/dev/null; then
    echo "FAIL: a malformed control row must fail loud"
    failures=$((failures + 1))
  fi
  printf '1\t2\t3\n4\t5\t6\n' >"$tmp/ch-ctl-two.tsv"
  if bep_render_ch 1000000000 2000000000 20 empty "$tmp/ch-empty.tsv" "$tmp/ch-ctl-two.tsv" >"$tmp/ch-two.md" 2>/dev/null; then
    echo "FAIL: a two-line control row must fail loud"
    failures=$((failures + 1))
  fi

  bep_render_ch 1000000000 2000000000 20 'failed:CANNOT_CONNECT to localhost:9000' "$tmp/ch-empty.tsv" "$tmp/ch-ctl.tsv" >"$tmp/ch-failed.md"
  check "ch failed: reason surfaced" grep -qF 'query FAILED: CANNOT_CONNECT to localhost:9000' "$tmp/ch-failed.md"
  check "ch failed: M22 caveat" grep -qF 'NOT evidence of absence' "$tmp/ch-failed.md"
  check "ch failed: no verdict invented" grep -qF 'Verdict: unknown (no verdict: a query FAILED' "$tmp/ch-failed.md"

  bep_render_ch 1000000000 2000000000 20 'skipped:clickhouse-client not on PATH' "$tmp/ch-empty.tsv" "$tmp/ch-ctl.tsv" >"$tmp/ch-skipped.md"
  check "ch skipped: reason surfaced" grep -qF 'SKIPPED: clickhouse-client not on PATH' "$tmp/ch-skipped.md"
  check "ch skipped: M22 caveat" grep -qF 'signoz-collector liveness' "$tmp/ch-skipped.md"
  check "ch skipped: no verdict invented" grep -qF 'Verdict: unknown (no verdict: the query was SKIPPED' "$tmp/ch-skipped.md"

  # Live fetch contract through a stub clickhouse-client: the control
  # aggregate goes out FIRST with half-open bounds [cut - 600 s, cut), the
  # death-window query is unchanged, and a FAILED control query reports
  # `failed:` (never `empty`, which would read as 0 rows and decide the
  # verdict).  The
  # stubs are written with the running bash as interpreter: /usr/bin/env
  # does not exist in the nix sandbox.
  mkdir -p "$tmp/bin" "$tmp/stub"
  {
    printf '#!%s\n' "$BASH"
    cat <<'CHSTUB'
# Stub clickhouse-client of the selftest (boot-evidence-pull.sh): answers by query shape, fails on demand, logs every call.
printf '%s\n' "$*" >>"$BEP_STUB_DIR/ch.calls"
case " $* " in
*" count(), max(timestamp), min(timestamp) "*) q=ctl ;;
*) q=rows ;;
esac
if [ "${BEP_CH_STUB_FAIL:-}" = "$q" ]; then
  echo "Code: 516. DB::Exception: stub failure ($q) (version 25.x)" >&2
  exit 1
fi
cat "$BEP_STUB_DIR/ch-$q.tsv"
CHSTUB
  } >"$tmp/bin/clickhouse-client"
  chmod +x "$tmp/bin/clickhouse-client"
  export PATH="$tmp/bin:$PATH" BEP_STUB_DIR="$tmp/stub"
  printf '11154\t1795601140890453000\t1795600551207406000\n' >"$tmp/stub/ch-ctl.tsv"
  : >"$tmp/stub/ch-rows.tsv"
  : >"$tmp/stub/ch.calls"
  st=$(bep_ch_fetch 1795601151000000000 1795601211000000000 20 "$tmp/ch.out" "$tmp/ch.err" "$tmp/ch.ctl")
  check "ch fetch: 0 window rows is EMPTY, not dark" test "$st" = empty
  check "ch fetch: control row kept for the renderer" test "$(cat "$tmp/ch.ctl")" = $'11154\t1795601140890453000\t1795600551207406000'
  check "ch fetch: control aggregate FIRST, half-open on the cut" test "$(sed -n 1p "$tmp/stub/ch.calls")" = '--format TSV --query SELECT count(), max(timestamp), min(timestamp) FROM signoz_logs.distributed_logs_v2 WHERE timestamp >= 1795600551000000000 AND timestamp < 1795601151000000000'
  check "ch fetch: death-window query SECOND, bounds unchanged" test "$(sed -n 2p "$tmp/stub/ch.calls")" = '--format TSV --query SELECT timestamp, body FROM signoz_logs.distributed_logs_v2 WHERE timestamp >= 1795601151000000000 AND timestamp <= 1795601211000000000 ORDER BY timestamp DESC LIMIT 20'
  check "ch fetch: exactly two queries" test "$(grep -c '' "$tmp/stub/ch.calls")" = 2
  printf '1795601155000000000\tafter the cut\n' >"$tmp/stub/ch-rows.tsv"
  st=$(bep_ch_fetch 1795601151000000000 1795601211000000000 20 "$tmp/ch.out" "$tmp/ch.err" "$tmp/ch.ctl")
  check "ch fetch: window rows is OK" test "$st" = ok
  : >"$tmp/stub/ch.calls"
  st=$(BEP_CH_STUB_FAIL=ctl bep_ch_fetch 1795601151000000000 1795601211000000000 20 "$tmp/ch.out" "$tmp/ch.err" "$tmp/ch.ctl")
  check "ch fetch: failed control is failed:, never a verdict" test "${st#failed:}" != "$st"
  check "ch fetch: failed control names the reason" grep -qF 'Code: 516. DB::Exception: stub failure (ctl)' <<<"$st"
  check "ch fetch: no window query after a failed control" test "$(grep -c '' "$tmp/stub/ch.calls")" = 1
  st=$(BEP_CH_STUB_FAIL=rows bep_ch_fetch 1795601151000000000 1795601211000000000 20 "$tmp/ch.out" "$tmp/ch.err" "$tmp/ch.ctl")
  check "ch fetch: failed window query is failed:" test "${st#failed:}" != "$st"
  st=$(PATH=/nonexistent bep_ch_fetch 1 2 20 "$tmp/ch.out" "$tmp/ch.err" "$tmp/ch.ctl")
  check "ch fetch: no client is skipped:" test "$st" = 'skipped:clickhouse-client not on PATH'

  # epoch-ns conversion: local-time stamps and UTC stamps that name the
  # same instant must agree, and the result must be nanosecond scale.
  # POSIX TZ form (sign INVERTED: UTC-4 = UTC+4) — parses without
  # tzdata zone files, so it holds in the nix sandbox too.
  check "epoch-ns honors local tz" test "$(TZ=UTC-4 bep_epoch_ns '2026-10-28 07:05:12')" = "$(TZ=UTC bep_epoch_ns '2026-10-28 03:05:12')"
  check "epoch-ns nanosecond scale" test "$(TZ=UTC bep_epoch_ns '2026-10-28 07:05:12')" = "$(TZ=UTC date -d '2026-10-28 07:05:12' +%s)000000000"

  # Full render: canonical order is panic -> pstore -> remote tail (the CH
  # section carries the heading the stability.md remedy bullet names).
  out=$(bep_render "$tmp/journal" "bf8a454c" "bf8a454cdeadbeef" "t1" "t2" "$tmp/ch-ok.md" "$tmp/pstore-sect")
  printf '%s\n' "$out" >"$tmp/evidence.order.md"
  local panic_line pstore_line ch_line
  panic_line=$(grep -n '^## Kernel panic/BUG/oops lines' "$tmp/evidence.order.md" | cut -d: -f1)
  pstore_line=$(grep -n '^## pstore (EFI) crash dump' "$tmp/evidence.order.md" | cut -d: -f1)
  ch_line=$(grep -n '^## Remote log tail' "$tmp/evidence.order.md" | cut -d: -f1)
  check "pstore section present in render" test -n "$pstore_line"
  check "pstore section after panic section" test "$pstore_line" -gt "$panic_line"
  check "ch section present in render" test -n "$ch_line"
  check "ch section after pstore section" test "$ch_line" -gt "$pstore_line"
  check "ch section after panic section" test "$ch_line" -gt "$panic_line"

  # pstore + kdump section (2026-11-26): read from the NEXT boot through the
  # library's PSTORE_JOURNALCTL seam, here a stub journalctl that answers
  # from fixture files, fails on demand and logs every call.  Legs: records
  # + kdump SAVED, none, the capture-kernel OOM shape, no next boot, and
  # unreadable journal reads (which must never render as "no dump").
  check "pstore: helper library sourced" test -n "${PSTORE_RECORDS_LOADED:-}"
  {
    printf '#!%s\n' "$BASH"
    cat <<'JCTL'
# Stub journalctl of the selftest (boot-evidence-pull.sh): the records query and the kdump range each answer from a fixture file.
printf '%s\n' "$*" >>"$BEP_STUB_DIR/jctl.calls"
case " $* " in
*' --since '*)
  [ -z "${BEP_STUB_FAIL_RANGE:-}" ] || { echo "stub journalctl: range unreadable" >&2; exit 1; }
  cat "$BEP_STUB_DIR/kdump.range"
  ;;
*' -o json '*)
  [ -z "${BEP_STUB_FAIL_JSON:-}" ] || { echo "stub journalctl: boot unreadable" >&2; exit 1; }
  cat "$BEP_STUB_DIR/records.jsonl"
  ;;
*)
  echo "stub journalctl: unexpected query: $*" >&2
  exit 3
  ;;
esac
JCTL
  } >"$tmp/bin/journalctl"
  chmod +x "$tmp/bin/journalctl"
  # Scoped to the selftest subshell on purpose: the stub must not outlive it.
  # shellcheck disable=SC2031
  export PSTORE_JOURNALCTL="$tmp/bin/journalctl" PSTORE_ARCHIVE_ROOT=''

  # Records + kdump SAVED: the shape of a working capture path.  The main
  # kernel's long uptime stamps are the dump, and kdump-save.service wrote
  # the dmesg; the retention and unit-state lines around it are noise.
  cat >"$tmp/stub/records.jsonl" <<'JSONL'
{"SYSLOG_IDENTIFIER":"systemd-pstore","FILE":"Panic#1 Part3\n<6>[    0.000000] Linux version 7.3.5 (stub)\n","MESSAGE":"PStore dmesg-efi_pstore-179560116503001 moved to /var/lib/systemd/pstore/1795601165/001/dmesg-efi_pstore-179560116503001"}
{"SYSLOG_IDENTIFIER":"systemd-pstore","FILE":"Panic#1 Part2\n<4>[ 86400.000001] filler of a long-lived kernel\n","MESSAGE":"PStore dmesg-efi_pstore-179560116502001 moved to /var/lib/systemd/pstore/1795601165/001/dmesg-efi_pstore-179560116502001"}
{"SYSLOG_IDENTIFIER":"systemd-pstore","FILE":"Panic#1 Part1\n<0>[ 86412.400000] Kernel panic - not syncing: stub panic\n","MESSAGE":"PStore dmesg-efi_pstore-179560116501001 moved to /var/lib/systemd/pstore/1795601165/001/dmesg-efi_pstore-179560116501001"}
JSONL
  cat >"$tmp/stub/kdump.range" <<'RANGE'
2026-11-25T11:05:51+01:00 evo-x2 systemd[1]: journal of the minutes after the cut (fixture)
2026-11-25T11:06:05+01:00 evo-x2 kdump-save-start[467]: kdump-save: wrote /var/crash/20261125-110551/vmcore-dmesg.txt
2026-11-25T11:06:06+01:00 evo-x2 kdump-retention-start[900]: kdump-retention: removed old dump /var/crash/20261120-101010
2026-11-25T11:06:07+01:00 evo-x2 systemd[1]: kdump-save.service: Deactivated successfully.
RANGE
  : >"$tmp/stub/jctl.calls"
  bep_pstore_live 0737ecd796a143208516dbcff4e46e07 "2026-11-25 11:05:51" >"$tmp/pstore-saved.md"
  check "pstore: heading" grep -qF '## pstore (EFI) crash dump and kdump capture line (read from the next boot)' "$tmp/pstore-saved.md"
  check "pstore: next boot cited" grep -qF 'Next boot: 0737ecd796a143208516dbcff4e46e07' "$tmp/pstore-saved.md"
  check "pstore: library fields rendered" grep -qxF 'token=main-kernel-panic-captured' "$tmp/pstore-saved.md"
  check "pstore: records counted" grep -qxF 'records=3' "$tmp/pstore-saved.md"
  check "pstore: fetch ok" grep -qxF 'fetch=ok' "$tmp/pstore-saved.md"
  check "pstore: records listed in dump order" test "$(sed -n 's/^- record=\(Panic#1 Part[0-9]\) .*/\1/p' "$tmp/pstore-saved.md")" = $'Panic#1 Part3\nPanic#1 Part2\nPanic#1 Part1'
  check "pstore: archive path listed" grep -qF 'archive=1795601165/001/dmesg-efi_pstore-179560116501001' "$tmp/pstore-saved.md"
  check "pstore: kdump SAVED" grep -qF 'kdump: capture SAVED:' "$tmp/pstore-saved.md"
  check "pstore: kdump journal line listed" grep -qF 'kdump-save: wrote /var/crash/20261125-110551/vmcore-dmesg.txt' "$tmp/pstore-saved.md"
  check "pstore: retention noise filtered from the kdump lines" bash -c "! grep -q 'kdump-retention' '$tmp/pstore-saved.md'"
  check "pstore: unit-state noise filtered from the kdump lines" bash -c "! grep -q 'kdump-save.service: Deactivated' '$tmp/pstore-saved.md'"
  check "pstore: exactly one kdump journal line listed" test "$(sed -n '/^kdump: capture SAVED/,$p' "$tmp/pstore-saved.md" | grep -c 'kdump-save: wrote')" = 1
  check "pstore: records query = next boot + validated selector" grep -qxF -- '--quiet --no-pager -b 0737ecd796a143208516dbcff4e46e07 -o json SYSLOG_IDENTIFIER=systemd-pstore' "$tmp/stub/jctl.calls"
  check "pstore: kdump range = cut .. cut + 10 min" grep -qxF -- '--quiet --no-pager -o short-iso --since 2026-11-25 11:05:51 --until 2026-11-25 11:15:51' "$tmp/stub/jctl.calls"
  check "pstore: exactly two journal reads" test "$(grep -c '' "$tmp/stub/jctl.calls")" = 2

  # No records: the next boot archived nothing (clean shutdown class).  The
  # section says so and the call is not an error.
  : >"$tmp/stub/records.jsonl"
  printf '%s\n' '2026-11-25T11:06:05+01:00 evo-x2 systemd[1]: Reached target Multi-User System.' >"$tmp/stub/kdump.range"
  bep_pstore_live 0737ecd796a143208516dbcff4e46e07 "2026-11-25 11:05:51" >"$tmp/pstore-none.md"
  check "pstore none: token none" grep -qxF 'token=none' "$tmp/pstore-none.md"
  check "pstore none: records=0" grep -qxF 'records=0' "$tmp/pstore-none.md"
  check "pstore none: section says what zero means" grep -qF 'records=0 means "that boot archived no dump", never "no crash"' "$tmp/pstore-none.md"
  check "pstore none: gaps empty, never gaps=0" grep -qxF 'gaps=' "$tmp/pstore-none.md"
  check "pstore none: empty records fence" grep -qxF 'Records (0; dump order, highest part first: Part1 holds the newest lines):' "$tmp/pstore-none.md"
  check "pstore none: kdump UNKNOWN" grep -qF 'kdump: capture UNKNOWN: no kdump-save journal line in the 10 min after the cut and no pstore dump was archived by the next boot (token=none)' "$tmp/pstore-none.md"
  check "pstore none: no SAVED or FAILED claimed" bash -c "! grep -q 'kdump: capture \(SAVED\|FAILED\)' '$tmp/pstore-none.md'"

  # The capture-kernel OOM shape of the 2026-11-25 cuts: the dump is the
  # capture kernel (512 MiB) and it deadlocked, kdump-save left no line.
  cat >"$tmp/stub/records.jsonl" <<'JSONL'
{"SYSLOG_IDENTIFIER":"systemd-pstore","FILE":"Panic#1 Part2\n<4>[   13.062170] 131118 pages RAM\n","MESSAGE":"PStore dmesg-efi_pstore-179560116502001 moved to /var/lib/systemd/pstore/1795601165/001/dmesg-efi_pstore-179560116502001"}
{"SYSLOG_IDENTIFIER":"systemd-pstore","FILE":"Panic#1 Part1\n<0>[   13.064395] Kernel panic - not syncing: System is deadlocked on memory\n","MESSAGE":"PStore dmesg-efi_pstore-179560116501001 moved to /var/lib/systemd/pstore/1795601165/001/dmesg-efi_pstore-179560116501001"}
JSONL
  : >"$tmp/stub/kdump.range"
  bep_pstore_live 0737ecd796a143208516dbcff4e46e07 "2026-11-25 11:05:51" >"$tmp/pstore-capoom.md"
  check "pstore cap-OOM: token" grep -qxF 'token=capture-kernel-OOM' "$tmp/pstore-capoom.md"
  check "pstore cap-OOM: pages_ram" grep -qxF 'pages_ram=131118' "$tmp/pstore-capoom.md"
  check "pstore cap-OOM: deadlocked" grep -qxF 'deadlocked=1' "$tmp/pstore-capoom.md"
  check "pstore cap-OOM: kdump FAILED names the capture kernel" grep -qF 'kdump: capture FAILED: no kdump-save journal line in the 10 min after the cut and the pstore dump is the panic of the capture kernel itself (token=capture-kernel-OOM' "$tmp/pstore-capoom.md"

  # The FAILED journal-line class through the live path: kdump-save.service
  # ran and could not write the dmesg.  The verdict must come from that
  # line, never from the pstore token (here the capture-kernel OOM shape).
  printf '%s\n' '2026-11-25T11:06:05+01:00 evo-x2 kdump-save-start[467]: kdump-save: vmcore-dmesg FAILED (rc=1) - check pstore as fallback' >"$tmp/stub/kdump.range"
  bep_pstore_live 0737ecd796a143208516dbcff4e46e07 "2026-11-25 11:05:51" >"$tmp/pstore-kdump-failed.md"
  check "pstore kdump-failed: verdict from the journal line" grep -qF 'kdump: capture FAILED: kdump-save.service ran but vmcore-dmesg FAILED' "$tmp/pstore-kdump-failed.md"
  check "pstore kdump-failed: the line is listed" grep -qF 'kdump-save: vmcore-dmesg FAILED (rc=1) - check pstore as fallback' "$tmp/pstore-kdump-failed.md"
  check "pstore kdump-failed: never SAVED" bash -c "! grep -q 'kdump: capture SAVED' '$tmp/pstore-kdump-failed.md'"

  # No next boot (the pulled boot is the newest one): nothing to ask.
  : >"$tmp/stub/jctl.calls"
  bep_pstore_live "" "2026-11-25 11:05:51" >"$tmp/pstore-nonext.md"
  check "pstore nonext: next boot NONE" grep -qF 'Next boot: NONE (this is the newest boot in the journal)' "$tmp/pstore-nonext.md"
  check "pstore nonext: fetch=nonext" grep -qxF 'fetch=nonext' "$tmp/pstore-nonext.md"
  check "pstore nonext: kdump UNKNOWN names the missing next boot" grep -qF 'kdump: capture UNKNOWN: no next boot in the journal' "$tmp/pstore-nonext.md"
  check "pstore nonext: journal never asked" test ! -s "$tmp/stub/jctl.calls"

  # Unreadable journal: NOT an answer.  Each failed read surfaces as its own
  # error and nothing renders as a "no dump" claim.  The kdump range fixture
  # is emptied first, so a read that SUCCEEDS here finds no line.
  : >"$tmp/stub/kdump.range"
  BEP_STUB_FAIL_JSON=1 BEP_STUB_FAIL_RANGE=1 bep_pstore_live 0737ecd796a143208516dbcff4e46e07 "2026-11-25 11:05:51" >"$tmp/pstore-error.md"
  check "pstore error: fetch=error" grep -qxF 'fetch=error' "$tmp/pstore-error.md"
  check "pstore error: records read failure surfaced" grep -qF 'pstore read FAILED: stub journalctl: boot unreadable' "$tmp/pstore-error.md"
  check "pstore error: kdump read failure surfaced" grep -qF 'kdump: capture UNKNOWN: the journal read for the 10 min after the cut FAILED (stub journalctl: range unreadable)' "$tmp/pstore-error.md"
  check "pstore error: never claims no dump" bash -c "! grep -q 'archived no pstore dump' '$tmp/pstore-error.md'"
  BEP_STUB_FAIL_RANGE=1 bep_pstore_live 0737ecd796a143208516dbcff4e46e07 "2026-11-25 11:05:51" >"$tmp/pstore-error-range.md"
  check "pstore error-range: records still read" grep -qxF 'fetch=ok' "$tmp/pstore-error-range.md"
  check "pstore error-range: kdump read failure surfaced" grep -qF 'kdump: capture UNKNOWN: the journal read for the 10 min after the cut FAILED (stub journalctl: range unreadable)' "$tmp/pstore-error-range.md"
  BEP_STUB_FAIL_JSON=1 bep_pstore_live 0737ecd796a143208516dbcff4e46e07 "2026-11-25 11:05:51" >"$tmp/pstore-error-json.md"
  check "pstore error-json: kdump line read anyway" grep -qF 'kdump: capture UNKNOWN: no kdump-save journal line in the 10 min after the cut, and the pstore read FAILED' "$tmp/pstore-error-json.md"

  # kdump line states that the stub legs above do not reach: the FAILED
  # journal line, SAVED with the lines fenced, and a verdict of `none` over
  # a main-kernel dump (no capture line although the dump was written).
  kd=$(bep_kdump_verdict failed '2026-11-25T11:06:05+01:00 evo-x2 kdump-save-start[467]: kdump-save: vmcore-dmesg FAILED (rc=1) - check pstore as fallback' none ok)
  check "kdump failed: verdict" grep -qF 'kdump: capture FAILED: kdump-save.service ran but vmcore-dmesg FAILED' <<<"$kd"
  check "kdump failed: journal line fenced" grep -qF 'kdump-save: vmcore-dmesg FAILED (rc=1) - check pstore as fallback' <<<"$kd"
  check "kdump failed: fenced exactly" test "$(grep -c '^```$' <<<"$kd")" = 2
  kd=$(bep_kdump_verdict error 'journalctl: stub failure' none ok)
  check "kdump error: no verdict over an unread journal" grep -qF 'kdump: capture UNKNOWN: the journal read for the 10 min after the cut FAILED (journalctl: stub failure): no verdict' <<<"$kd"
  kd=$(bep_kdump_verdict none '' main-kernel-panic-captured ok)
  check "kdump none over a main-kernel dump: UNKNOWN, not FAILED" grep -qF 'kdump: capture UNKNOWN: the pstore dump is the panic text of the main kernel' <<<"$kd"
  kd=$(bep_kdump_verdict none '' capture-kernel-panicked ok)
  check "kdump none over a capture-kernel panic: FAILED" grep -qF 'kdump: capture FAILED: no kdump-save journal line in the 10 min after the cut and the pstore dump is the panic of the capture kernel itself (token=capture-kernel-panicked' <<<"$kd"

  # Write path: refuses to overwrite an existing evidence file.
  printf 'existing\n' >"$tmp/target.md"
  if printf 'new\n' | bep_write "$tmp/target.md" 2>/dev/null; then
    echo "FAIL: bep_write must refuse an existing target"
    failures=$((failures + 1))
  fi
  check "refusal kept original content" grep -q '^existing$' "$tmp/target.md"
  printf 'streamed\n' | bep_write "$tmp/ok.md" 2>/dev/null
  check "write to fresh target" grep -q '^streamed$' "$tmp/ok.md"

  # End to end through main() (2026-11-26): the real script as a child
  # process, journalctl and clickhouse-client stubbed on PATH, scratch under
  # $tmp, the evidence on stdout.  Pins what no pure leg can: the resolve
  # step hands the pstore section the NEXT boot's id, the verdict and the
  # sections land in one file, and the EXIT trap removes every scratch file
  # (it leaked the ch.* files of every successful pull before the global
  # list).
  mkdir -p "$tmp/e2e/bin"
  {
    printf '#!%s\n' "$BASH"
    cat <<'JCTL'
# Stub journalctl of the end-to-end leg: the boot list, the boot dump, the records query and the kdump range each answer from a fixture file.
case " $* " in
*' --list-boots '*) cat "$BEP_STUB_DIR/e2e-boots.txt" ;;
*' -o json '*) cat "$BEP_STUB_DIR/e2e-records.jsonl" ;;
*' --since '*) cat "$BEP_STUB_DIR/e2e-kdump.range" ;;
*' -b '*) cat "$BEP_STUB_DIR/e2e-boot.dump" ;;
*)
  echo "stub journalctl: unexpected query: $*" >&2
  exit 3
  ;;
esac
JCTL
  } >"$tmp/e2e/bin/journalctl"
  chmod +x "$tmp/e2e/bin/journalctl"
  cat >"$tmp/stub/e2e-boots.txt" <<'BOOTS'
-2 b4931451c4564d3b8a69516165d82e7b Tue 2026-11-24 20:46:44 CET Wed 2026-11-25 08:57:47 CET
-1 8b31b428b94e49048dfa2c47573dcb82 Wed 2026-11-25 08:58:54 CET Wed 2026-11-25 11:05:51 CET
0 0737ecd796a143208516dbcff4e46e07 Wed 2026-11-25 11:06:51 CET Fri 2026-11-27 00:00:00 CET
BOOTS
  cp "$tmp/journal" "$tmp/stub/e2e-boot.dump"
  # The remote tail is BEHIND the cut in this leg: rows before it, none after.
  printf '11154\t1795601140890453000\t1795600551207406000\n' >"$tmp/stub/ch-ctl.tsv"
  : >"$tmp/stub/ch-rows.tsv"
  cp "$tmp/stub/records.jsonl" "$tmp/stub/e2e-records.jsonl"
  printf '%s\n' '2026-11-25T11:06:05+01:00 evo-x2 kdump-save-start[467]: kdump-save: wrote /var/crash/20261125-110551/vmcore-dmesg.txt' >"$tmp/stub/e2e-kdump.range"
  mkdir -p "$tmp/e2e/xdg"
  # TZ=UTC-1 (POSIX form, sign inverted: UTC+1) parses the CET boot-list
  # stamps like the live box does, and needs no tzdata zone file, so the
  # epoch-ns window below holds in the nix sandbox too.
  PATH="$tmp/e2e/bin:$PATH" TZ=UTC-1 XDG_CACHE_HOME="$tmp/e2e/xdg" PSTORE_JOURNALCTL="$tmp/e2e/bin/journalctl" \
    bash "$0" -b -1 -o - >"$tmp/e2e/evidence.md" 2>"$tmp/e2e/stderr.txt"
  check "e2e: evidence header cites the pulled boot" grep -qF '# Boot evidence pull: id8 8b31b428 (full: 8b31b428b94e49048dfa2c47573dcb82)' "$tmp/e2e/evidence.md"
  check "e2e: boot window from the boot list" grep -qF 'Boot window: 2026-11-25 08:58:54 -> 2026-11-25 11:05:51 (journalctl --list-boots).' "$tmp/e2e/evidence.md"
  check "e2e: behind-tail verdict in the file" grep -qF 'Verdict: alive-behind.' "$tmp/e2e/evidence.md"
  check "e2e: death window = journal cut -> next boot" grep -qF 'Window: 1795601151000000000 -> 1795601211000000000 epoch-ns UTC' "$tmp/e2e/evidence.md"
  check "e2e: pstore section read the NEXT boot by id" grep -qF 'Next boot: 0737ecd796a143208516dbcff4e46e07' "$tmp/e2e/evidence.md"
  check "e2e: capture-kernel token decoded" grep -qxF 'token=capture-kernel-OOM' "$tmp/e2e/evidence.md"
  check "e2e: kdump SAVED line in the file" grep -qF 'kdump: capture SAVED:' "$tmp/e2e/evidence.md"
  check "e2e: census counts the fixture" grep -qF -- '- oom-lines: 11' "$tmp/e2e/evidence.md"
  check "e2e: nothing on stderr" test ! -s "$tmp/e2e/stderr.txt"
  check "e2e: EXIT trap left NO scratch file" test -z "$(find "$tmp/e2e/xdg" -type f)"

  if [ "$failures" -eq 0 ]; then
    echo "boot-evidence-pull selftest: all cases green"
    exit 0
  fi
  echo "boot-evidence-pull selftest: $failures FAILURE(S)"
  exit 1
)

# ── live path ────────────────────────────────────────────────────────────

BEP_ID=""
BEP_FIRST_TS=""
BEP_LAST_TS=""
BEP_DUMP=""
BEP_NEXT_ID=""
# Scratch files of the live pull, a GLOBAL list on purpose (2026-11-26): the
# EXIT trap fires at SCRIPT exit, after main()'s locals are popped, so it
# could never see the ch.* paths held in locals.  Every successful pull
# leaked its three ch files that way (18 files from the 6 pulls of 2026-11-24
# and 2026-11-25 measured in ~/.cache/boot-evidence; the startup gc below
# was reclaiming this leak, not only killed sessions).
BEP_SCRATCH=()

bep_scratch() { # <variable name> <mktemp template>: one scratch file INTO that variable, remembered for the EXIT trap
  # Must run in the parent shell, never inside a command substitution: an
  # append done in a subshell never reaches the list the trap reads.
  local f
  f=$(mktemp "$2")
  BEP_SCRATCH+=("$f")
  printf -v "$1" '%s' "$f"
}

bep_resolve_boot() {
  # <spec> — resolve via --list-boots; sets BEP_ID/BEP_FIRST_TS/BEP_LAST_TS
  # and BEP_NEXT_FIRST_TS (first ts of the FOLLOWING boot, empty for the
  # newest; it bounds the M22 ClickHouse death window at the next boot) plus
  # BEP_NEXT_ID (that boot's id, which the pstore section reads).
  local spec="$1" line next_line boots
  boots=$(journalctl --list-boots --no-pager --quiet 2>/dev/null) || return 1
  line=$(printf '%s\n' "$boots" | awk -v s="$spec" '$1 == s || $2 ~ "^"s {print; exit}')
  if [ -z "$line" ]; then
    echo "boot spec '$spec' not found in journalctl --list-boots (try: $0 list)" >&2
    return 1
  fi
  next_line=$(printf '%s\n' "$boots" | awk -v s="$spec" '$1 == s || $2 ~ "^"s {found=1; next} found {print; exit}')
  BEP_ID=$(printf '%s' "$line" | awk '{print $2}')
  BEP_FIRST_TS=$(printf '%s' "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}' | head -n 1)
  BEP_LAST_TS=$(printf '%s' "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}' | tail -n 1)
  BEP_NEXT_ID=""
  BEP_NEXT_FIRST_TS=""
  if [ -n "$next_line" ]; then
    BEP_NEXT_ID=$(printf '%s' "$next_line" | awk '{print $2}')
    BEP_NEXT_FIRST_TS=$(printf '%s' "$next_line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}' | head -n 1)
  fi
  [ -n "$BEP_FIRST_TS" ] && [ -n "$BEP_LAST_TS" ]
}

bep_usage() {
  sed -n '2,/^set -euo pipefail$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' | head -n -1
}

main() {
  local mode="pull"
  case "${1:-}" in
  list | selftest)
    mode="$1"
    shift
    ;;
  esac

  local spec="-1" out=""
  while getopts ":b:o:h" opt; do
    case $opt in
    b) spec=$OPTARG ;;
    o) out=$OPTARG ;;
    h)
      bep_usage
      return 0
      ;;
    \?)
      echo "unknown option: -$OPTARG" >&2
      bep_usage >&2
      return 2
      ;;
    esac
  done
  shift $((OPTIND - 1))

  case "$mode" in
  list)
    exec journalctl --list-boots --no-pager
    ;;
  selftest)
    bep_selftest
    ;;
  pull)
    if [ "$#" -gt 0 ]; then
      echo "unexpected argument: $1 (use -b <boot-spec>)" >&2
      bep_usage >&2
      return 2
    fi
    command -v journalctl >/dev/null 2>&1 || {
      echo "journalctl not found on PATH" >&2
      return 1
    }
    bep_resolve_boot "$spec"
    local id8
    id8=${BEP_ID:0:8}
    # Scratch lives under ~/.cache, NOT /var/tmp (2026-10-27 storage audit F5:
    # killed sessions leak their /var/tmp scratch — the EXIT trap below only
    # fires on a clean exit — and /tmp is wiped mid-session by tmpfiles; the
    # evidence boot dump can be 100s of MB and belongs on durable cache).
    # Startup self-clean: reclaim leaked scratch from prior killed
    # sessions (age+holder-gated, so a concurrent fresh pull is never
    # touched). Fail-soft — a broken/missing gc never aborts the pull.
    # (2026-11-02: 2.1G of leaked dumps reclaimed by hand; this closes
    # the leak class. Standalone entry: scripts/boot-evidence-scratch-gc.sh)
    local gc="$REPO_ROOT/scripts/boot-evidence-scratch-gc.sh"
    if [ -x "$gc" ]; then
      "$gc" quiet || true
    fi
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence"
    bep_scratch BEP_DUMP "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence/boot-evidence.XXXXXX"
    # One EXIT trap removes every file bep_scratch created.  The list is a
    # global because the trap fires at SCRIPT exit, after main()'s locals
    # are popped: a path held in a local is empty by then (2026-10-31, the
    # same hazard leaked the dump through a bare "$var" under set -u; that
    # fix made the trap survive but left the ch.* locals leaking).
    trap 'rm -f "${BEP_SCRATCH[@]}"' EXIT
    journalctl --quiet --no-pager -b "$BEP_ID" >"$BEP_DUMP"
    if [ -z "$out" ]; then
      out="$TASKS_DIR/$(date -u '+%Y-%m-%d_%H-%M')_boot-${id8}-evidence-pull.md"
    fi
    # M22 ClickHouse death window: [journal cut -> next boot], queried
    # after its positive-control window. Fails soft: dark/behind/failed/
    # skipped render as evidence context, never aborts.
    # ch_sect_path / pstore_sect_path (not ch_sect / pstore_sect): bep_render
    # holds locals of those names in its subshell body, and shellcheck pairs
    # same-named modifications across the two scopes (SC2030/SC2031).
    local lo_ns hi_ns ch_status ch_out ch_ctl ch_err ch_sect_path pstore_sect_path tail_n
    tail_n=${BEP_CH_TAIL:-20}
    case "$tail_n" in '' | *[!0-9]*) tail_n=20 ;; esac
    lo_ns=$(bep_epoch_ns "$BEP_LAST_TS")
    if [ -n "$BEP_NEXT_FIRST_TS" ]; then
      hi_ns=$(bep_epoch_ns "$BEP_NEXT_FIRST_TS")
    else
      hi_ns=$(printf '%s000000000\n' "$(date +%s)")
    fi
    [ "$hi_ns" -lt "$lo_ns" ] && hi_ns=$lo_ns
    bep_scratch ch_out "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence/ch.XXXXXX"
    bep_scratch ch_ctl "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence/ch-ctl.XXXXXX"
    bep_scratch ch_err "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence/ch.XXXXXX"
    bep_scratch ch_sect_path "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence/ch.XXXXXX"
    bep_scratch pstore_sect_path "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence/pstore.XXXXXX"
    ch_status=$(bep_ch_fetch "$lo_ns" "$hi_ns" "$tail_n" "$ch_out" "$ch_err" "$ch_ctl")
    bep_render_ch "$lo_ns" "$hi_ns" "$tail_n" "$ch_status" "$ch_out" "$ch_ctl" >"$ch_sect_path"
    # pstore dump + kdump capture line of the NEXT boot. Fails soft by
    # design: every read state (none, error, no next boot) renders as text.
    bep_pstore_live "$BEP_NEXT_ID" "$BEP_LAST_TS" >"$pstore_sect_path"
    bep_render "$BEP_DUMP" "$id8" "$BEP_ID" "$BEP_FIRST_TS" "$BEP_LAST_TS" "$ch_sect_path" "$pstore_sect_path" | bep_write "$out"
    ;;
  esac
}

main "$@"
