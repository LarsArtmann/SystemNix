#!/usr/bin/env bash
# boot-evidence-pull.sh — one-command boot-evidence pull (pre-vacuum remedy).
#
# The freeze-27/28 evidence pulls were bespoke journalctl sessions; every
# new boot autopsy re-invented the pipeline by hand. This script
# parameterizes it: resolve a boot selector, dump the boot journal ONCE,
# and emit the CANONICAL sections (boot-boundary lines, census, kernel
# OOM, memory-emergency-guard, thermal THROTTLE, kernel panic/BUG/oops,
# remote ClickHouse death-window tail) into a commit-ready evidence file
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
# BEP_CH_TAIL bounds the last-N bodies (default 20). Fail-soft: a dark,
# failed, or skipped pipeline is evidence CONTEXT (never a pull failure)
# and always carries the M22 not-evidence-of-absence caveat.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TASKS_DIR="$REPO_ROOT/docs/status/tasks"

# ── pure helpers (fixture-tested by `selftest`) ──────────────────────────

bep_grep_oom() {
  grep -E 'invoked oom-killer|oom-kill:|Out of memory' "$1" || true
}

bep_grep_guard() {
  grep -F 'memory-emergency-guard' "$1" || true
}

bep_grep_thermal() {
  grep -F 'THERMAL THROTTLE' "$1" || true
}

bep_grep_panic() {
  grep -E 'kernel:.*(panic|BUG|oops)' "$1" || true
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

bep_render_ch() {
  # <lo-ns> <hi-ns> <tail-n> <status> <tsv-file> — ClickHouse
  # death-window section. Pure: reads only its arguments/files, so the
  # selftest drives it with fixture TSVs (no clickhouse-client).
  # <status>: ok | dark | failed:<reason> | skipped:<reason>
  # <tsv-file>: "timestamp<TAB>body" rows, timestamp DESC (row 1 = newest).
  local lo="$1" hi="$2" tail_n="$3" status="$4" tsv="$5"
  local lo_h hi_h max_ns max_h rows
  lo_h=$(date -u -d "@$((lo / 1000000000))" '+%Y-%m-%d %H:%M:%S')
  hi_h=$(date -u -d "@$((hi / 1000000000))" '+%Y-%m-%d %H:%M:%S')

  cat <<EOF
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: $lo -> $hi epoch-ns UTC ($lo_h -> $hi_h UTC)
EOF
  case "$status" in
  ok)
    max_ns=$(head -n 1 "$tsv" | cut -f1)
    rows=$(wc -l <"$tsv")
    max_h=$(date -u -d "@$((max_ns / 1000000000))" '+%Y-%m-%d %H:%M:%S')
    printf 'Pipeline ALIVE in this window — newest row: %s (%s UTC); rows fetched: %s (last %s by timestamp DESC). Per M22 pull BOTH sources: ClickHouse is fresher than the journal cut by the flush lag.\n' "$max_ns" "$max_h" "$rows" "$tail_n"
    printf '\nLast rows (timestamp<TAB>body, newest first):\n'
    bep_fenced "$tsv"
    ;;
  dark)
    printf 'PIPELINE DARK FOR THIS WINDOW — 0 rows in the window.\n'
    printf 'Per M22: ClickHouse absence is NOT evidence of absence — the collector has a fatal-at-startup failure mode that silences the whole log pipeline (proven #37). Cross-check signoz-collector liveness across this boot BEFORE trusting the gap.\n'
    bep_fenced /dev/null
    ;;
  failed:*)
    printf 'clickhouse query FAILED: %s\n' "${status#failed:}"
    printf 'Remote tail unavailable for this window — same M22 caveat: absence here is NOT evidence of absence; cross-check signoz-collector liveness across this boot.\n'
    bep_fenced /dev/null
    ;;
  skipped:*)
    printf 'Remote tail SKIPPED: %s\n' "${status#skipped:}"
    printf 'Journal-only evidence — M22: check signoz-collector liveness before inferring quiet; ClickHouse may hold the window the journal flushed away.\n'
    bep_fenced /dev/null
    ;;
  *)
    echo "internal error: unknown bep_render_ch status: $status" >&2
    return 1
    ;;
  esac
}

bep_ch_fetch() {
  # <lo-ns> <hi-ns> <tail-n> <outfile> <errfile> — LIVE clickhouse-client
  # probe over the death window; prints a status token on stdout
  # (ok | dark | failed:<reason> | skipped:<reason>). Never throws: the
  # pipeline state is evidence context, not a pull failure (M22).
  local lo="$1" hi="$2" tail_n="$3" out="$4" err="$5" reason
  command -v clickhouse-client >/dev/null 2>&1 || {
    printf 'skipped:clickhouse-client not on PATH\n'
    return 0
  }
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
    printf 'dark\n'
  fi
  return 0
}

bep_render() (
  # <journal-dump> <id8> <full-id> <first-ts> <last-ts> <ch-section-file>
  # — canonical evidence sections on stdout. Pure: reads only its
  # arguments/files, so the selftest can drive it without journalctl or
  # clickhouse-client (the CH section is pre-rendered by bep_render_ch).
  # Subshell body so the temp-dir EXIT trap cannot reference a popped
  # function local (bash 5.3 destroys locals BEFORE a RETURN trap runs).
  local dump="$1" id8="$2" fullid="$3" first_ts="$4" last_ts="$5" ch_sect="$6"
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  bep_grep_oom "$dump" >"$tmp/oom"
  bep_grep_guard "$dump" >"$tmp/guard"
  bep_grep_thermal "$dump" >"$tmp/thermal"
  bep_grep_panic "$dump" >"$tmp/panic"

  local n_oom n_guard n_thermal n_panic
  n_oom=$(wc -l <"$tmp/oom")
  n_guard=$(wc -l <"$tmp/guard")
  n_thermal=$(wc -l <"$tmp/thermal")
  n_panic=$(wc -l <"$tmp/panic")

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
- guard-lines (memory-emergency-guard): $n_guard
- thermal-THROTTLE-lines: $n_thermal
- kernel panic/BUG/oops lines: $n_panic

## Kernel OOM lines (all)
$(bep_fenced "$tmp/oom")

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
    echo "Oct 11 23:00:01 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0"
    echo "Oct 11 23:00:01 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,task=nix,pid=1"
    echo "Oct 11 23:00:02 evo-x2 kernel: Out of memory: Killed process 1 (nix)"
    echo "Oct 11 23:05:00 evo-x2 memory-emergency-guard-check[9]: MEMORY EMERGENCY: zone 6 trip"
    echo "Oct 11 23:15:00 evo-x2 thermal-pstate-guard-check[9]: THERMAL THROTTLE ENTER: amd_pstate -> guided"
    echo "Oct 11 23:20:00 evo-x2 kernel: BUG: unable to handle page fault"
  } >"$tmp/journal"
  printf '## Remote log tail — ClickHouse death window (fixture)\n\n```plain\nfixture row\n```\n' >"$tmp/ch-sect"

  out=$(bep_render "$tmp/journal" "bf8a454c" "bf8a454cdeadbeef000000000000000000000000" "2026-10-11 11:09:43" "2026-10-12 13:04:01" "$tmp/ch-sect")
  printf '%s\n' "$out" >"$tmp/evidence.md"

  check "census oom count" grep -q '^- oom-lines: 3$' "$tmp/evidence.md"
  check "census guard count" grep -q '^- guard-lines (memory-emergency-guard): 1$' "$tmp/evidence.md"
  check "census thermal count" grep -q '^- thermal-THROTTLE-lines: 1$' "$tmp/evidence.md"
  check "census panic count" grep -q '^- kernel panic/BUG/oops lines: 1$' "$tmp/evidence.md"
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
  out=$(bep_render "$tmp/journal.big" "bf8a454c" "bf8a454cdeadbeef" "t1" "t2" "$tmp/ch-sect")
  printf '%s\n' "$out" >"$tmp/evidence.big.md"
  check "truncation marker" grep -q 'TRUNCATED (150 total; showing first 25 / last 25)' "$tmp/evidence.big.md"
  check "truncated head present" grep -q 'synthetic 1$' "$tmp/evidence.big.md"
  check "truncated tail present" grep -q 'synthetic 150$' "$tmp/evidence.big.md"
  check "middle elided" bash -c '! grep -q "synthetic 80\$" '"$tmp"'/evidence.big.md'
  check "big census panic count" grep -q '^- kernel panic/BUG/oops lines: 150$' "$tmp/evidence.big.md"

  # ClickHouse death-window section (M22): the four pipeline states.
  printf '1790632991000000000\tnewest row body\n1790632891000000000\tolder row body\n' >"$tmp/ch.tsv"
  bep_render_ch 1790632831000000000 1790633129000000000 20 ok "$tmp/ch.tsv" >"$tmp/ch-ok.md"
  check "ch ok: window echoed" grep -qF 'Window: 1790632831000000000 -> 1790633129000000000' "$tmp/ch-ok.md"
  check "ch ok: newest row cited" grep -qF 'newest row: 1790632991000000000' "$tmp/ch-ok.md"
  check "ch ok: newest ns cited" grep -qF '1790632991000000000' "$tmp/ch-ok.md"
  check "ch ok: rows fetched count" grep -qF 'rows fetched: 2 (last 20' "$tmp/ch-ok.md"
  check "ch ok: bodies preserved" grep -qF 'newest row body' "$tmp/ch-ok.md"
  check "ch ok: M22 fresher note" grep -qF 'FRESHER than the journal cut' "$tmp/ch-ok.md"

  : >"$tmp/ch-empty.tsv"
  bep_render_ch 1000000000 2000000000 20 dark "$tmp/ch-empty.tsv" >"$tmp/ch-dark.md"
  check "ch dark: dark banner" grep -qF 'PIPELINE DARK FOR THIS WINDOW' "$tmp/ch-dark.md"
  check "ch dark: not-evidence-of-absence" grep -qF 'absence is NOT evidence of absence' "$tmp/ch-dark.md"
  check "ch dark: collector cross-check" grep -qF 'signoz-collector liveness' "$tmp/ch-dark.md"

  bep_render_ch 1000000000 2000000000 20 'failed:CANNOT_CONNECT to localhost:9000' "$tmp/ch-empty.tsv" >"$tmp/ch-failed.md"
  check "ch failed: reason surfaced" grep -qF 'query FAILED: CANNOT_CONNECT to localhost:9000' "$tmp/ch-failed.md"
  check "ch failed: M22 caveat" grep -qF 'NOT evidence of absence' "$tmp/ch-failed.md"

  bep_render_ch 1000000000 2000000000 20 'skipped:clickhouse-client not on PATH' "$tmp/ch-empty.tsv" >"$tmp/ch-skipped.md"
  check "ch skipped: reason surfaced" grep -qF 'SKIPPED: clickhouse-client not on PATH' "$tmp/ch-skipped.md"
  check "ch skipped: M22 caveat" grep -qF 'signoz-collector liveness' "$tmp/ch-skipped.md"

  # epoch-ns conversion: local-time stamps and UTC stamps that name the
  # same instant must agree, and the result must be nanosecond scale.
  # POSIX TZ form (sign INVERTED: UTC-4 = UTC+4) — parses without
  # tzdata zone files, so it holds in the nix sandbox too.
  check "epoch-ns honors local tz" test "$(TZ=UTC-4 bep_epoch_ns '2026-10-28 07:05:12')" = "$(TZ=UTC bep_epoch_ns '2026-10-28 03:05:12')"
  check "epoch-ns nanosecond scale" test "$(TZ=UTC bep_epoch_ns '2026-10-28 07:05:12')" = "$(TZ=UTC date -d '2026-10-28 07:05:12' +%s)000000000"

  # Full render: the CH section lands AFTER the panic section (canonical
  # order) and carries the heading the stability.md remedy bullet names.
  out=$(bep_render "$tmp/journal" "bf8a454c" "bf8a454cdeadbeef" "t1" "t2" "$tmp/ch-ok.md")
  printf '%s\n' "$out" >"$tmp/evidence.order.md"
  local panic_line ch_line
  panic_line=$(grep -n '^## Kernel panic/BUG/oops lines' "$tmp/evidence.order.md" | cut -d: -f1)
  ch_line=$(grep -n '^## Remote log tail' "$tmp/evidence.order.md" | cut -d: -f1)
  check "ch section present in render" test -n "$ch_line"
  check "ch section after panic section" test "$ch_line" -gt "$panic_line"

  # Write path: refuses to overwrite an existing evidence file.
  printf 'existing\n' >"$tmp/target.md"
  if printf 'new\n' | bep_write "$tmp/target.md" 2>/dev/null; then
    echo "FAIL: bep_write must refuse an existing target"
    failures=$((failures + 1))
  fi
  check "refusal kept original content" grep -q '^existing$' "$tmp/target.md"
  printf 'streamed\n' | bep_write "$tmp/ok.md" 2>/dev/null
  check "write to fresh target" grep -q '^streamed$' "$tmp/ok.md"

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

bep_resolve_boot() {
  # <spec> — resolve via --list-boots; sets BEP_ID/BEP_FIRST_TS/BEP_LAST_TS
  # and BEP_NEXT_FIRST_TS (first ts of the FOLLOWING boot, empty for the
  # newest — bounds the M22 ClickHouse death window at the next boot).
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
  BEP_NEXT_FIRST_TS=""
  if [ -n "$next_line" ]; then
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
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence"
    BEP_DUMP=$(mktemp "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence/boot-evidence.XXXXXX")
    # "${var:-}" not "$var": the trap fires at SCRIPT exit, after main()'s
    # locals are popped (same bash locals/EXIT-trap hazard as the helper
    # subshell bodies above) — a bare "$var" under set -u kills the trap
    # AND the cleanup, leaking the scratch dump (re-fired live 2026-10-31,
    # 27580a79 pull: file written, exit 1, scratch left behind).
    trap 'rm -f "${BEP_DUMP:-}"' EXIT
    journalctl --quiet --no-pager -b "$BEP_ID" >"$BEP_DUMP"
    if [ -z "$out" ]; then
      out="$TASKS_DIR/$(date -u '+%Y-%m-%d_%H-%M')_boot-${id8}-evidence-pull.md"
    fi
    # M22 ClickHouse death window: [journal cut -> next boot]. Fails soft
    # — dark/failed/skipped render as evidence context, never aborts.
    local lo_ns hi_ns ch_status ch_out ch_err ch_sect tail_n
    tail_n=${BEP_CH_TAIL:-20}
    case "$tail_n" in '' | *[!0-9]*) tail_n=20 ;; esac
    lo_ns=$(bep_epoch_ns "$BEP_LAST_TS")
    if [ -n "$BEP_NEXT_FIRST_TS" ]; then
      hi_ns=$(bep_epoch_ns "$BEP_NEXT_FIRST_TS")
    else
      hi_ns=$(printf '%s000000000\n' "$(date +%s)")
    fi
    [ "$hi_ns" -lt "$lo_ns" ] && hi_ns=$lo_ns
    ch_out=$(mktemp "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence/ch.XXXXXX")
    ch_err=$(mktemp "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence/ch.XXXXXX")
    ch_sect=$(mktemp "${XDG_CACHE_HOME:-$HOME/.cache}/boot-evidence/ch.XXXXXX")
    trap 'rm -f "${BEP_DUMP:-}" "${ch_out:-}" "${ch_err:-}" "${ch_sect:-}"' EXIT
    ch_status=$(bep_ch_fetch "$lo_ns" "$hi_ns" "$tail_n" "$ch_out" "$ch_err")
    bep_render_ch "$lo_ns" "$hi_ns" "$tail_n" "$ch_status" "$ch_out" >"$ch_sect"
    bep_render "$BEP_DUMP" "$id8" "$BEP_ID" "$BEP_FIRST_TS" "$BEP_LAST_TS" "$ch_sect" | bep_write "$out"
    ;;
  esac
}

main "$@"
