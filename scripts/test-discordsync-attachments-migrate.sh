#!/usr/bin/env bash
# Stub-fixture harness for the destructive discordsync-attachments-migrate
# oneshot (modules/nixos/services/discordsync.nix). The unit script is
# EXTRACTED from the evaluated evo-x2 config by the flake check
# (discordsync-attachments-migrate-fixture) and handed to us as $1; we
# sed-rewrite the baked absolute paths onto scratch trees and PATH-stub
# the root-bound commands (systemctl, chown; rsync/rm wrapped for
# failure injection). Real rsync does the copy + checksum verify.
#
# Covers: happy path (copy → verify → rm source → restart), stop fail,
# copy fail, verify fail, rm fail, restart fail — every branch keeps the
# source or migrates it exactly as designed — plus eval-side asserts on
# the unit's ConditionPathIsDirectory skip + RequiresMountsFor gating.
set -uo pipefail

MIGRATE_SRC="$1"
UNIT_CONDITION="$2"
UNIT_MOUNTS="$3"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
STUB="$scratch/stub"
mkdir -p "$STUB"

REAL_RM="$(command -v rm)"
REAL_RSYNC="$(command -v rsync)"

# ---- systemctl stub: logs invocations; per-phase failure injection ----
cat >"$STUB/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "systemctl $*" >> "${STUB_LOG:?}"
[ "${STUB_FAIL_STOP:-0}" = 1 ] && [ "${1:-}" = stop ] && exit 1
[ "${STUB_FAIL_START:-0}" = 1 ] && [ "${1:-}" = start ] && exit 1
exit 0
EOF
BASH_BIN=$(command -v bash)
sed -i "1s|.*|#!$BASH_BIN|" "$STUB/systemctl"
chmod +x "$STUB/systemctl"

# ---- chown stub: the sandbox has no discordsync user; ownership
#      correctness is a unit-level User=/harden concern, not script logic ----
cat >"$STUB/chown" <<'EOF'
#!/usr/bin/env bash
echo "chown $*" >> "${STUB_LOG:?}"
exit 0
EOF
sed -i "1s|.*|#!$BASH_BIN|" "$STUB/chown"
chmod +x "$STUB/chown"

# ---- rm wrapper: fails ONLY for the injected path (rm -rf -- PATH) ----
cat >"$STUB/rm" <<EOF
#!$(command -v bash)
if [ "\${1:-}" = -rf ] && [ "\${2:-}" = -- ] && [ "\${3:-}" = "\${STUB_RM_FAIL_PATH:-}" ]; then
  echo "rm stub: injected failure for \$3" >> "\${STUB_LOG:?}"
  exit 1
fi
exec "$REAL_RM" "\$@"
EOF
sed -i "1s|.*|#!$BASH_BIN|" "$STUB/rm"
chmod +x "$STUB/rm"

# ---- rsync wrapper: on the checksum verify pass (its -c flag is
#      verify-only; the -n rides inside -aHAXn), corrupt the
#      destination first (simulates post-copy drift) when armed ----
cat >"$STUB/rsync" <<EOF
#!$(command -v bash)
for a in "\$@"; do
  if [ "\$a" = "-c" ] && [ -n "\${STUB_VERIFY_CORRUPT:-}" ]; then
    "$REAL_RM" -rf -- "\$STUB_VERIFY_CORRUPT"
  fi
done
exec "$REAL_RSYNC" "\$@"
EOF
sed -i "1s|.*|#!$BASH_BIN|" "$STUB/rsync"
chmod +x "$STUB/rsync"

# ---- rewritten copy of the unit script (baked paths → scratch) ----
SRC="$scratch/src"
DEST="$scratch/dest"
sed -e "s#/var/lib/discordsync/attachments#$SRC#g" \
  -e "s#/mnt/pool/services/discordsync/attachments#$DEST#g" \
  "$MIGRATE_SRC" >"$scratch/migrate.sh"
chmod +x "$scratch/migrate.sh"
grep -q "$scratch/src" "$scratch/migrate.sh" || fail "path rewrite missed the source literal"
grep -q "$scratch/dest" "$scratch/migrate.sh" || fail "path rewrite missed the destination literal"

export STUB_LOG="$scratch/stub.log"
: >"$STUB_LOG"

seed() {
  rm -rf "$SRC" "$DEST"
  mkdir -p "$SRC/shard-a" "$SRC/shard-b"
  echo alpha >"$SRC/shard-a/a.bin"
  dd if=/dev/urandom of="$SRC/shard-b/b.bin" bs=64k count=4 status=none
}

run_migrate() {
  PATH="$STUB:$PATH" "$scratch/migrate.sh" >"$scratch/out" 2>&1
}

src_intact() { [ -f "$SRC/shard-a/a.bin" ] && [ -f "$SRC/shard-b/b.bin" ]; }

# ---- 1. happy path: copy → verify → rm source → restart ----
seed
STUB_FAIL_STOP=0 STUB_FAIL_START=0 run_migrate
[ $? -eq 0 ] || {
  cat "$scratch/out"
  fail "happy path exited nonzero"
}
[ -f "$DEST/shard-a/a.bin" ] && [ -f "$DEST/shard-b/b.bin" ] ||
  {
    cat "$scratch/out"
    fail "happy path did not populate the destination"
  }
[ ! -e "$SRC" ] || {
  cat "$scratch/out"
  fail "happy path left the source behind"
}
grep -q "verified identical, source removed" "$scratch/out" || {
  cat "$scratch/out"
  fail "happy-path completion line missing"
}
grep -q "^systemctl stop discordsync.service$" "$STUB_LOG" || fail "happy path never stopped the service"
grep -q "^systemctl start discordsync.service$" "$STUB_LOG" || fail "happy path never restarted the service"

# ---- 2. stop fail: refuse before touching anything ----
seed
: >"$STUB_LOG"
STUB_FAIL_STOP=1 run_migrate
[ $? -eq 1 ] || {
  cat "$scratch/out"
  fail "stop-fail must exit 1"
}
grep -q "STOP FAILED" "$scratch/out" || {
  cat "$scratch/out"
  fail "stop-fail message missing"
}
src_intact || fail "stop-fail damaged the source"
[ ! -e "$DEST" ] || fail "stop-fail created the destination"

# ---- 3. copy fail: destination unusable → source kept ----
seed
: >"$STUB_LOG"
touch "$DEST"
run_migrate
[ $? -eq 1 ] || {
  cat "$scratch/out"
  fail "copy-fail must exit 1"
}
grep -q "COPY FAILED" "$scratch/out" || {
  cat "$scratch/out"
  fail "copy-fail message missing"
}
src_intact || fail "copy-fail damaged the source"

# ---- 4. verify fail: dest drifts after copy → checksum gate holds ----
seed
: >"$STUB_LOG"
STUB_VERIFY_CORRUPT="$DEST/shard-b/b.bin" run_migrate
[ $? -eq 1 ] || {
  cat "$scratch/out"
  fail "verify-fail must exit 1"
}
grep -q "VERIFY FAILED" "$scratch/out" || {
  cat "$scratch/out"
  fail "verify-fail message missing"
}
src_intact || fail "verify-fail damaged the source"
[ -f "$DEST/shard-a/a.bin" ] || fail "verify-fail: partial copy missing (expected copied files to remain)"

# ---- 5. rm fail: data safe on the pool, source kept, exit 1 ----
seed
: >"$STUB_LOG"
STUB_RM_FAIL_PATH="$SRC" run_migrate
[ $? -eq 1 ] || {
  cat "$scratch/out"
  fail "rm-fail must exit 1"
}
grep -q "SOURCE REMOVAL FAILED" "$scratch/out" || {
  cat "$scratch/out"
  fail "rm-fail message missing"
}
src_intact || fail "rm-fail damaged the source"
cmp -s "$SRC/shard-b/b.bin" "$DEST/shard-b/b.bin" || fail "rm-fail: pool copy incomplete"

# ---- 6. restart fail: migration complete, operator must start manually ----
seed
: >"$STUB_LOG"
STUB_FAIL_START=1 run_migrate
[ $? -eq 1 ] || {
  cat "$scratch/out"
  fail "restart-fail must exit 1"
}
grep -q "RESTART FAILED" "$scratch/out" || {
  cat "$scratch/out"
  fail "restart-fail message missing"
}
[ ! -e "$SRC" ] || fail "restart-fail: source should already be migrated+removed"
grep -q "start discordsync.service manually" "$scratch/out" || fail "restart-fail operator hint missing"

# ---- 7. unit-level gates, eval-side: the one-time skip condition and
#        the mount gating must be part of the RENDERED unit config ----
[ "$UNIT_CONDITION" = "/var/lib/discordsync/attachments" ] ||
  fail "ConditionPathIsDirectory drifted: $UNIT_CONDITION"
grep -q "mnt/pool" <<<"$UNIT_MOUNTS" || fail "RequiresMountsFor lost the pool edge: $UNIT_MOUNTS"

echo "PASS: discordsync-attachments-migrate stub fixture (6 scenarios + unit gates)"
