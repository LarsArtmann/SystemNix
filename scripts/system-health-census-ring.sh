#!/usr/bin/env bash
# Census memory-collector durability ring — local textfile fallback so the
# per-cgroup memory census (system_cgroup_mem_*) survives a SigNoz-ingest
# outage. The 10-03 OOM cascade had its census gap 07:18→17:00 exactly
# across the pressure window the census exists to explain (only the 07:17
# minute survived to bound the pre-cascade state).
#
# Why a separate ring instead of just system_health.prom: the collector
# computes the census EARLY but publishes the whole .prom with a single
# atomic mv at the END of the run — a run killed by the 5min unit timeout
# (the 2026-08-31 journal-walk wedge class) lost the census along with
# everything else. The collector feeds each census sample through this ring
# IMMEDIATELY after computing it, so the sample lands on disk before the
# slow journal sections can kill the run, and a local copy exists even when
# the SigNoz ingest path is the thing that starved.
#
# The ring is a LOG, not a prom file: it holds many timestamped sample
# blocks and must never be scraped by node_exporter (duplicate series from
# stale blocks would poison the exposition). The ring filename must never
# end in .prom.
#
# Usage: system-health-census-ring RING_PATH KEEP_BLOCKS < sample-block
#   RING_PATH    ring file path (inside the node_exporter textfile dir)
#   KEEP_BLOCKS  rotate-last-N ceiling in sample BLOCKS (>= 2)
# stdin: one sample block of prom-formatted lines (no HELP/TYPE comments).
#
# Rotation is block-granular: a sample block survives COMPLETE or not at
# all, so a recovered ring never shows torn half-samples.
set -euo pipefail

append_ring() {
  local ring="${1:-}" keep_blocks="${2:-}" sample="" total=0 tmp="" start=0

  if [ -z "$ring" ] || [ -z "$keep_blocks" ]; then
    echo "usage: $0 RING_PATH KEEP_BLOCKS < sample-block" >&2
    exit 2
  fi
  if ! [ "$keep_blocks" -ge 2 ] 2>/dev/null; then
    echo "census-ring: KEEP_BLOCKS must be an integer >= 2 (got: $keep_blocks)" >&2
    exit 2
  fi

  sample="$(cat)"
  if [ -z "$sample" ]; then
    echo "census-ring: empty sample block, nothing to append" >&2
    return 0
  fi

  # mktemp in the ring's own directory: same sticky-1777 / foreign-owner
  # constraints as the collector's .prom tmp (rename-over-foreign needs
  # CAP_FOWNER; mktemp self-heals with zero caps). A SIGKILL between
  # mktemp and mv leaves a census-memory-ring.log.XXXXXX corpse — the
  # collector's reaper sweeps those (never scraped: not *.prom).
  tmp="$(mktemp "$ring.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT

  # Count kept blocks; a ring with ZERO valid headers is corrupt or
  # foreign garbage — start fresh rather than carry unbounded junk
  # (grep exits 1 on zero matches: the journalctl exit-code trap class).
  if [ -f "$ring" ]; then
    total="$(grep -c '^# census_sample' "$ring" 2>/dev/null || true)"
    [ -n "$total" ] || total=0
  fi

  {
    if [ "$total" -gt 0 ]; then
      # Keep the newest (keep_blocks - 1) old blocks; the new block makes
      # exactly keep_blocks after the append. Header index of the first
      # block to keep (1-based): total - (keep_blocks - 1). awk passes
      # every line once the first kept header is seen — blocks stay whole.
      start=$((total - keep_blocks + 2))
      awk -v start="$start" '/^# census_sample/ { i++ } i >= start' "$ring"
    fi
    printf '# census_sample ts=%s epoch=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(date +%s)"
    printf '%s\n' "$sample"
  } >"$tmp"

  mv -f "$tmp" "$ring"
  trap - EXIT
}

run_selftest() {
  # Deliberately NOT local: the EXIT trap runs outside the function scope,
  # where a local fixture would be unbound under set -u.
  fixture="$(mktemp -d)"
  trap 'rm -rf "$fixture"' EXIT

  local failures=0
  assert_eq() {
    if [ "$2" != "$3" ]; then
      echo "SELFTEST FAIL ($1): expected [$3], got [$2]" >&2
      failures=$((failures + 1))
    else
      echo "ok: $1"
    fi
  }

  local ring="$fixture/textfile/census-memory-ring.log"
  mkdir -p "$fixture/textfile"

  # One block = 1 header + 32 metric lines (8 cgroups x 4 families), the
  # collector's max shape.
  gen_block() {
    local cg family
    for cg in user.slice system.slice session-1.scope session-2.scope init.scope machine.slice user@1000.service nix-daemon.service; do
      for family in bytes anon_bytes shmem_bytes unevictable_bytes; do
        printf 'system_cgroup_mem_%s{cgroup="%s"} %d\n' "$family" "$cg" $((RANDOM * 4096 + 1048576))
      done
    done
  }

  # 1. First append: ring created with exactly one complete block.
  gen_block | "$0" "$ring" 5
  assert_eq "first-append-blocks" "$(grep -c '^# census_sample' "$ring")" "1"
  assert_eq "first-append-lines" "$(wc -l <"$ring")" "33"

  # 2. Early-sample durability (the 10-03 property): sample A lands while
  #    the collector run later dies before publishing its .prom — the ring
  #    must still hold A on the next tick, with B appended after it
  #    (history preserved, newest last).
  gen_block | "$0" "$ring" 5
  assert_eq "history-preserved" "$(grep -c '^# census_sample' "$ring")" "2"
  assert_eq "newest-last" "$(tail -n 33 "$ring" | head -n 1 | grep -c '^# census_sample')" "1"
  assert_eq "head-is-block-start" "$(head -n 1 "$ring" | grep -c '^# census_sample')" "1"

  # 3. Guard-trip-style pressure window: 300 rapid ticks (a 10h starved
  #    window at 2-min cadence) against keep=5 — the ring stays bounded at
  #    exactly keep_blocks whole blocks and never tears one.
  local _n
  for _n in {1..300}; do
    gen_block | "$0" "$ring" 5
  done
  assert_eq "pressure-window-bounded" "$(grep -c '^# census_sample' "$ring")" "5"
  assert_eq "pressure-window-lines" "$(wc -l <"$ring")" "165"
  assert_eq "every-line-valid" "$(grep -c -E '^# census_sample |^system_cgroup_mem_[a-z_]+\{cgroup="[^"]+"\} [0-9]+$' "$ring")" "165"

  # 4. Epoch monotonicity across the window (forensic ordering).
  assert_eq "epochs-monotonic" "$(awk '/^# census_sample/ { if ($4 != "" && $4 + 0 < last) bad++; last = $4 + 0 } END { print bad + 0 }' "$ring")" "0"

  # 5. Empty sample: collector guard bypassed — no block, ring unchanged.
  local before
  before="$(wc -l <"$ring")"
  printf '' | "$0" "$ring" 5 2>/dev/null
  assert_eq "empty-sample-noop" "$(wc -l <"$ring")" "$before"

  # 6. Corrupt ring self-heal: garbage with zero valid headers is dropped,
  #    not carried (an unheadered ring would grow unboundedly forever).
  printf 'garbage line\nmore garbage\n' >"$ring"
  gen_block | "$0" "$ring" 5
  assert_eq "corrupt-ring-healed" "$(head -n 1 "$ring" | grep -c '^# census_sample')" "1"
  assert_eq "corrupt-ring-dropped" "$(grep -c 'garbage' "$ring")" "0"

  # 7. SIGKILL-corpse tmp (census-memory-ring.log.XXXXXX): ignored by the
  #    append, never mistaken for the ring.
  printf 'corpse' >"$ring.a1b2c3"
  gen_block | "$0" "$ring" 5
  assert_eq "corpse-ignored" "$(grep -c '^# census_sample' "$ring")" "2"

  # 8. Bad usage fails loudly.
  if "$0" 2>/dev/null; then
    echo "SELFTEST FAIL (usage-no-args): expected exit 2" >&2
    failures=$((failures + 1))
  fi
  if "$0" "$ring" 1 </dev/null 2>/dev/null; then
    echo "SELFTEST FAIL (usage-tiny-keep): expected exit 2" >&2
    failures=$((failures + 1))
  fi
  if "$0" --append "$ring" 5 </dev/null 2>/dev/null; then
    echo "SELFTEST FAIL (usage-dashed-mode): expected exit 2" >&2
    failures=$((failures + 1))
  fi

  if [ "$failures" -gt 0 ]; then
    echo "SELFTEST FAILED: $failures assertion(s)" >&2
    exit 1
  fi
  echo "SELFTEST PASSED: system-health-census-ring"
}

case "${1:-}" in
selftest) run_selftest ;;
-*)
  echo "usage: $0 RING_PATH KEEP_BLOCKS < sample-block" >&2
  echo "       $0 selftest" >&2
  exit 2
  ;;
*) append_ring "$@" ;;
esac
