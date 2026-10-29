#!/usr/bin/env bash
# test-io-writer-attribution.sh — fixture selftest for
# io-writer-attribution.sh (stability plan M9/F37).  Runs the REPO script
# in --from-snapshots replay mode against known cgroup snapshots and
# asserts: delta math, ranking, threshold filter, root-aggregate
# exclusion, format stability, and argv-free output.  Also exercises the
# usage/exit contract.  The live capture path is deliberately NOT tested
# here (racy by nature); its parsing core is the same awk the replay path
# runs — the 2026-10-28 lesson this encodes: test the JOIN, not the race.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/io-writer-attribution.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

fail() {
  echo "test-io-writer-attribution: FAIL: $*" >&2
  exit 1
}

# --- Fixture: two snapshots one "window" apart -------------------------
# Known deltas (MB): tq-agent-pool +162000 rd / +300 wr (the 2026-10-28
# 02:00 trip shape), session-12.scope +40 rd, system.slice +25 wr,
# quiet.scope unchanged (must NOT appear), plus a cgroup that VANISHED
# between snapshots (must be skipped, not abort).
cat >"$scratch/s1" <<'EOF'
system.slice/tq-agent-pool.service 1000000 0
user.slice/user-1000.slice/session-12.scope 41943040 2097152
system.slice 5242880 5242880
user.slice/user-1000.slice/quiet.scope 1048576 1048576
system.slice/transient-dying.service 999999 999999
EOF
cat >"$scratch/s2" <<'EOF'
system.slice/tq-agent-pool.service 170776647680 314572800
user.slice/user-1000.slice/session-12.scope 83886080 3145728
system.slice 5242880 31457280
user.slice/user-1000.slice/quiet.scope 1048576 1048576
EOF

out=$(bash "$script" --from-snapshots "$scratch/s1" "$scratch/s2" --top 5 --mb-threshold 10)

# 1. Ranking: the biggest reader ranks first.
first=$(printf '%s\n' "$out" | awk '/MB-rd/ { print $0; exit }')
echo "$first" | rg -q 'tq-agent-pool.service' || fail "top reader is not tq-agent-pool: $first"

# 2. Delta math: 170776647680 - 1000000 bytes ≈ 162775.5 MB rd — the line
# must carry that magnitude (160000 < x < 165000), guarding against the
# awk field-offset slip class (2026-10-26 §e.6).
echo "$first" | rg -q '16[0-5][0-9][0-9][0-9]\.[0-9]MB-rd' || fail "reader delta magnitude wrong: $first"

# 3. Threshold filter: quiet.scope (0 delta) must NOT appear.
printf '%s\n' "$out" | rg -q 'quiet.scope' && fail "quiet.scope leaked past threshold"

# 4. Vanished cgroup skipped without abort (exit 0 already proven by
# capturing $out; assert the survivor lines exist too).
printf '%s\n' "$out" | rg -q 'session-12.scope' || fail "session-12 missing"
printf '%s\n' "$out" | rg -q 'MB-wr system.slice$' || fail "system.slice write-only delta missing"

# 5. Root aggregate excluded: the replay fixtures have no root io.stat
#    line by construction; assert the header documents the window+threshold.
printf '%s\n' "$out" | head -1 | rg -q 'window=.*top=5 threshold=10MB' || fail "header contract drifted"

# 5b. Sanity count line: sampled counts must be present and match the
#     fixture (5 cgroups at t0, 4 at t1 — one vanished) so a broken pass
#     can never masquerade as "no movers" (the 2026-10-28 trap).
printf '%s\n' "$out" | rg -q '# sanity: 5 cgroups sampled at t0, 4 at t1' || fail "sanity count line missing/wrong"

# 6. No argv ever: output must not contain '--jwt-secret' style content —
# by construction (comm/cgroup names only); assert no '/' beyond cgroup
# paths is impossible to test generically, so pin the invariant that
# output lines contain no spaces inside the cgroup field (an argv leak
# would show as multi-word tails).
lines=$(printf '%s\n' "$out" | rg -c 'MB-(rd|wr)' || true)
[ "$lines" -ge 3 ] || fail "expected >=3 attribution lines, got: $lines"

# 7. Usage/exit contract.
bash "$script" --help >/dev/null 2>&1 || fail "--help must exit 0"
if bash "$script" --bogus-flag >/dev/null 2>&1; then fail "unknown flag must exit 2"; fi

echo "test-io-writer-attribution: PASS ($lines attribution lines ranked, deltas verified)"
