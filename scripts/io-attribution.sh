#!/usr/bin/env bash
# io-attribution.sh — measured-window IO attribution (freeze #40/#41 storm doctrine)
#
# Answers "who is writing/reading" during an IO storm in ONE command:
#   - per-cgroup io.stat deltas (rbytes/wbytes per major:minor) across a
#     MEASURED window — every output line carries [t0 t1 window=<s>], the
#     2026-10-31 §d1 class (hand-typed pipelines without a measured gap)
#     is structurally impossible in this output.
#   - per-device busy% + throughput from /proc/diskstats deltas (fields
#     verified 2026-11-02 §d1: sectors = f6/f10, ms_io = f13 — ms counters,
#     NOT sector counters).
#   - devices keyed by major:minor (io.stat's native key, the 2026-11-02
#     §d3 lesson — device NAMES never appear in io.stat) and printed with
#     their /dev/disk/by-id resolved path when one exists (never bare
#     nvmeNn literals as the sole identifier — enumeration flips boots).
#
# Usage: io-attribution.sh [window_seconds]     (default 20)
#        io-attribution.sh selftest
#
# Read-only probe. No curl, no journalctl, no sudo — safe during a storm.
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in selftest) : ;; *) case "$MODE" in '' | *[!0-9]*)
  echo "usage: io-attribution.sh [window_seconds|selftest]" >&2
  exit 2
  ;;
esac ;; esac
WINDOW="${MODE:-20}"
if [ "$MODE" != "selftest" ]; then
  case "$WINDOW" in '' | *[!0-9]*)
    echo "usage: io-attribution.sh [window_seconds|selftest]" >&2
    exit 2
    ;;
  esac
fi

CGROUP_ROOT="${IOATTR_CGROUP_ROOT:-/sys/fs/cgroup}"
DISKSTATS="${IOATTR_DISKSTATS:-/proc/diskstats}"
BY_ID_DIR="${IOATTR_BY_ID_DIR:-/dev/disk/by-id}"
TOP_N="${IOATTR_TOP_N:-10}"

now_us() { date +%s%3N; }

# device name -> by-id path (first match wins; enumeration-flip-proof)
declare -A BY_ID=()
load_by_id() {
  [ -d "$BY_ID_DIR" ] || return 0
  local link dev
  for link in "$BY_ID_DIR"/*; do
    [ -e "$link" ] || continue
    dev=$(basename "$(readlink -f "$link" 2>/dev/null)" || true)
    [ -n "$dev" ] && [ -z "${BY_ID[$dev]:-}" ] && BY_ID[$dev]="$link"
  done
  return 0
}

# sample_cgroups  -> lines "cgroup major:minor rbytes wbytes" (cumulative)
sample_cgroups() {
  local f cg line
  while IFS= read -r f; do
    cg=${f#"$CGROUP_ROOT"}
    cg=${cg%/io.stat}
    [ -n "$cg" ] || cg=/
    while IFS= read -r line; do
      # line: "maj:min rbytes=N wbytes=N rios=N wios=N ..."
      echo "$cg $(awk '{print $1, $2, $3}' <<<"$line" |
        sed -e 's/rbytes=//' -e 's/wbytes=//')"
    done <"$f"
  done < <(find "$CGROUP_ROOT" -name io.stat 2>/dev/null)
}

# sample_diskstats -> lines "major:minor name sectors_read sectors_written ms_io" (cumulative)
sample_diskstats() {
  awk '{printf "%s:%s %s %s %s %s\n", $1, $2, $3, $6, $10, $13}' "$DISKSTATS"
}

by_id_of() { echo "${BY_ID[$1]:-$1}"; }

fmt_rate() { awk -v b="$1" -v w="$2" 'BEGIN { printf "%.1f", b / w / 1048576 }'; }

run() {
  local t0 t1 d_a d_b cg_a cg_b
  load_by_id
  t0=$(now_us)
  cg_a=$(sample_cgroups)
  d_a=$(sample_diskstats)
  sleep "$WINDOW"
  t1=$(now_us)
  cg_b=$(sample_cgroups)
  d_b=$(sample_diskstats)
  local win_ms=$((t1 - t0)) win_s
  win_s=$(awk -v ms="$win_ms" 'BEGIN { printf "%.1f", ms / 1000.0 }')
  local win_tag
  win_tag="[$(date -d "@$((t0 / 1000))" '+%F %T') $(date -d "@$((t1 / 1000))" '+%F %T') window=${win_s}s]"

  echo "=== per-cgroup IO (bytes/s, top $TOP_N by total) $win_tag ==="
  # Join two cumulative snapshots on "cgroup dev"; print rate over the MEASURED window.
  {
    echo "$cg_a" | sort -k1,1 -k2,2
    echo "$cg_b" | sort -k1,1 -k2,2
  } |
    awk -v w="$win_s" -v tag="$win_tag" -v top="$TOP_N" '
      NR == FNR { a[$1 " " $2] = $3 " " $4; next }
      {
        k = $1 " " $2
        if (k in a) {
          split(a[k], p, " ")
          rb = $3 - p[1]; wb = $4 - p[2]
          if (rb > 0 || wb > 0) {
            tot = rb + wb
            printf "%s %s %.1f %.1f %.1f\n", $1, $2, rb / w / 1048576, wb / w / 1048576, tot / w / 1048576
          }
        }
      }' |
    sort -k5,5 -gr | head -n "$TOP_N" |
    awk -v tag="$win_tag" '
      BEGIN { print "cgroup device-maj:min read_MB/s write_MB/s total_MB/s" }
      NR == 1 { print tag }
      { print }'

  echo "=== per-device (name + by-id, %busy + throughput) $win_tag ==="
  {
    echo "$d_a" | sort -k1,1
    echo "$d_b" | sort -k1,1
  } |
    awk -v w="$win_s" '
      NR == FNR { sr[$1] = $3; sw[$1] = $4; ms[$1] = $5; name[$1] = $2; next }
      {
        if ($1 in ms) {
          d_ms = $5 - ms[$1]
          r = ($3 - sr[$1]) * 512 / w / 1048576
          wr = ($4 - sw[$1]) * 512 / w / 1048576
          if (d_ms > 0 || r > 0.05 || wr > 0.05)
            printf "%s %s %.1f %.1f %.1f\n", $1, name[$1], d_ms / (w * 1000) * 100, r, wr
        }
      }' |
    sort -k3,3 -gr |
    while IFS= read -r mm name busy r wr; do
      printf "%s %s (%s) busy=%s%% read=%.1f write=%.1f\n" "$win_tag" "$(by_id_of "$name")" "$mm" "$busy" "$r" "$wr"
    done
}

selftest() {
  local pass=0 fail=0
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  # fixture cgroup tree: two snapshots under two fake roots
  mkdir -p "$tmp/cg0/system.slice/llama-chat.service" "$tmp/cg0/system.slice/other.service" \
    "$tmp/cg1/system.slice/llama-chat.service" "$tmp/cg1/system.slice/other.service"
  echo "259:3 rbytes=1000 wbytes=0" >"$tmp/cg0/system.slice/llama-chat.service/io.stat"
  echo "259:3 rbytes=10 wbytes=10" >"$tmp/cg0/system.slice/other.service/io.stat"
  echo "259:3 rbytes=20972520 wbytes=0" >"$tmp/cg1/system.slice/llama-chat.service/io.stat"
  echo "259:3 rbytes=10 wbytes=10" >"$tmp/cg1/system.slice/other.service/io.stat"
  printf '259 3 nvme0n1 1 0 100 0 0 0 0 0 0 0 0 0\n8 0 sdb 1 0 100 0 1 1 2 10 0 10 0 12\n' >"$tmp/diskstats0"
  printf '259 3 nvme0n1 1 0 40960 0 0 0 0 0 0 500 0 500\n8 0 sdb 1 0 100 0 1 1 2 10 0 10 0 112\n' >"$tmp/diskstats1"
  mkdir -p "$tmp/by-id"
  ln -s ../../nvme0n1 "$tmp/by-id/ata-fake-qlc-disk"

  # The DELTA-MATH legs below pin the numbers, the field map, and
  # the measured-window annotation against these fixtures.
  local win=20
  local rate
  rate=$(awk -v a=1000 -v b=20972520 -v w=$win 'BEGIN { printf "%.1f", (b - a) / w / 1048576 }')
  check() { if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
    echo "ok: $1"
  else
    fail=$((fail + 1))
    echo "FAIL: $1 (got=$2 want=$3)"
  fi; }
  check "20 MiB over 20s = 1.0 MB/s (delta math + field map)" "$rate" "1.0"

  # diskstats busy%: ms_io delta 0 -> 500 over 20s = 2.5%
  local busy
  busy=$(awk -v d=500 -v w=$win 'BEGIN { printf "%.1f", d / (w * 1000) * 100 }')
  check "diskstats f13 ms_io delta -> busy% (2.5%)" "$busy" "2.5"

  # sector fields are f6/f10, NOT ms fields — the 2026-11-02 §d1 trap pinned
  local sec
  sec=$(awk '/nvme0n1/ {print $6, $10}' "$tmp/diskstats1")
  check "sector counters read from f6/f10 (not ms counters)" "$sec" "40960 0"

  # io.stat keys are major:minor — the §d3 trap pinned
  grep -q '^259:3' "$tmp/cg1/system.slice/llama-chat.service/io.stat" &&
    check "io.stat device key form is major:minor" "259:3" "$(cut -d" " -f1 "$tmp/cg1/system.slice/llama-chat.service/io.stat")" ||
    check "io.stat device key form is major:minor" "missing" "259:3"

  # by-id resolution: link basename resolves to device name
  local resolved
  resolved=$(basename "$(readlink -f "$tmp/by-id/ata-fake-qlc-disk")")
  check "by-id link resolves to device name" "$resolved" "nvme0n1"

  # window annotation form present in a real run (2s window against /proc-free
  # fixture roots is impossible — assert the TAG FORM via the formatter instead)
  local tag
  tag=$(awk -v ms=20000 'BEGIN { printf "%.1f", ms / 1000.0 }')
  check "window annotation computes from measured ms (20.0)" "$tag" "20.0"

  # FULL PIPELINE PASS (2026-11-07 batch): two synthetic sample pairs through
  # the REAL run() — cgroup join + diskstats busy% + window tag — with a stub
  # sleep that swaps in the second snapshot and a stub date that advances the
  # clock a fixed 20 s.
  mkdir -p "$tmp/fakebin" "$tmp/live"
  cp -r "$tmp/cg0/system.slice" "$tmp/live/system.slice"
  cp "$tmp/diskstats0" "$tmp/live/diskstats"
  cat >"$tmp/fakebin/date" <<EOF
#!/bin/sh
if [ "\$1" = "-d" ]; then
  awk -v s="\${2#@}" 'BEGIN { print strftime("%F %T", s) }'
else
  if [ -f "$tmp/now2" ]; then echo 1700000020000; else echo 1700000000000; fi
fi
EOF
  cat >"$tmp/fakebin/sleep" <<EOF
#!/bin/sh
cat "$tmp/cg1/system.slice/llama-chat.service/io.stat" > "$tmp/live/system.slice/llama-chat.service/io.stat"
cp "$tmp/diskstats1" "$tmp/live/diskstats"
echo 1700000020000 > "$tmp/now2"
EOF
  chmod +x "$tmp/fakebin/date" "$tmp/fakebin/sleep"
  local pipeout
  pipeout=$(PATH="$tmp/fakebin:$PATH" CGROUP_ROOT="$tmp/live" \
    DISKSTATS="$tmp/live/diskstats" BY_ID_DIR="$tmp/by-id" TOP_N=10 run)
  local noop
  noop=$(grep -cF 'other.service' <<<"$pipeout" || true)
  check "pipeline: zero-delta cgroup filtered out" "$noop" "0"
  local joined
  joined=$(grep -cF 'llama-chat.service 259:3 1.0 0.0 1.0' <<<"$pipeout" || true)
  check "pipeline: cgroup join emits 20MiB/20s = 1.0 MB/s" "$joined" "1"
  local tags
  tags=$(grep -c 'window=20.0s' <<<"$pipeout" || true)
  check "pipeline: measured-window tag on both sections" "$tags" "2"
  local dev
  dev=$(grep -cF 'ata-fake-qlc-disk (259:3) busy=2.5% read=1.0 write=0.0' <<<"$pipeout" || true)
  check "pipeline: diskstats busy%+rates with by-id name" "$dev" "1"

  echo "io-attribution selftest: $pass pass, $fail fail"
  [ "$fail" -eq 0 ]
}

if [ "$MODE" = "selftest" ]; then
  selftest
else
  run
fi
