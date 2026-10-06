#!/usr/bin/env bash
# test-migrate-rust-cache — fixture test for scripts/migrate-rust-cache.sh
# (the script FORMATS a disk and moves caches; it runs ONCE under sudo in a
# maintenance window — every failure branch is exercised here first).
#
# Strategy: the script hardcodes DEVICE/MOUNT/SOURCES/lars/sudo, so the test
# runs a SED-PATCHED COPY with scratch paths, SUDO="", and the current user —
# plus PATH-injected stubs for lsblk/mkfs.btrfs/mount/findmnt/mountpoint/
# chown. rsync/find/df/wc run REAL against /tmp fixtures. The mkfs stub
# mimics real mkfs.btrfs semantics: it REFUSES to overwrite an existing
# filesystem without -f — which is exactly how the 2026-10-06 live run
# failed (the gate recognized the spare, mkfs refused, script exited clean).
#
# Covers: fresh-spare happy path (format WITH -f, mount options, all three
# cache moves with content verify, sources removed), re-run idempotency
# (no second mkfs, residual cache dir converges), wrong-content gate refusal
# (ext4/buildcache → no mkfs, sources untouched), mounted-device refusal,
# and a SELF-VERIFYING assertion count (emitted PASS lines == anchored
# ok-call sites — hand-count drift flips red instead of rotting silently).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT_UNDER_TEST=$HERE/migrate-rust-cache.sh

FAILURES=0
PASS_COUNT=0
ok() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}
fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
BIN="$SCRATCH/bin"
STATE="$SCRATCH/state"
FIXTURE_DEV="$SCRATCH/dev/sandisk-part1"
FIXTURE_BC_DEV="$SCRATCH/dev/buildcache-dev"
FIXTURE_MOUNT="$SCRATCH/mnt/rust-cache"
FIXTURE_BUILD="$SCRATCH/mnt/buildcache"
mkdir -p "$BIN" "$STATE" "$(dirname "$FIXTURE_DEV")" "$(dirname "$FIXTURE_MOUNT")"
touch "$FIXTURE_DEV" "$FIXTURE_BC_DEV"

reset_state() {
  rm -rf "$STATE"
  mkdir -p "$STATE"
  : >"$STATE/mounted.tsv"
  : >"$STATE/mkfs.log"
  : >"$STATE/mount.log"
  : >"$STATE/fstype"
  : >"$STATE/label"
}

# ── stubs ───────────────────────────────────────────────────────────────────
# lsblk -nrno FIELD dev → state-file lookup (missing dev → exit 1, like real)
cat >"$BIN/lsblk" <<EOF
#!$BASH
field="\$2"; dev="\$3"
[ "\$dev" = "$FIXTURE_DEV" ] || exit 1
case "\$field" in
  FSTYPE) cat "$STATE/fstype" 2>/dev/null || true ;;
  LABEL) cat "$STATE/label" 2>/dev/null || true ;;
  MOUNTPOINTS) awk -F'\t' -v d="\$dev" '\$1 == d {print \$2}' "$STATE/mounted.tsv" 2>/dev/null || true ;;
  *) exit 1 ;;
esac
exit 0
EOF
# mkfs.btrfs: real-mkfs refusal semantics (existing fs + no -f → ERROR, exit 1)
cat >"$BIN/mkfs.btrfs" <<EOF
#!$BASH
force=0; label=""; dev=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -f) force=1 ;;
    -L) label="\$2"; shift ;;
    -d | -m) shift ;;
    *) dev="\$1" ;;
  esac
  shift
done
[ "\$dev" = "$FIXTURE_DEV" ] || { echo "mkfs stub: unexpected device: \$dev" >&2; exit 1; }
if [ -s "$STATE/fstype" ] && [ "\$force" != 1 ]; then
  echo "ERROR: \$dev appears to contain an existing filesystem (type=\$(cat "$STATE/fstype"), label=\$(cat "$STATE/label"))" >&2
  echo "ERROR: use the -f option to force overwrite of \$dev" >&2
  exit 1
fi
echo btrfs >"$STATE/fstype"
echo "\$label" >"$STATE/label"
echo "mkfs force=\$force label=\$label dev=\$dev" >>"$STATE/mkfs.log"
EOF
# mount -o opts dev mnt → log + mounted.tsv
cat >"$BIN/mount" <<EOF
#!$BASH
echo "\$*" >>"$STATE/mount.log"
printf '%s\t%s\n' "\$3" "\$4" >>"$STATE/mounted.tsv"
EOF
# mountpoint -q mnt → mounted.tsv field 2
cat >"$BIN/mountpoint" <<EOF
#!$BASH
awk -F'\t' -v p="\$2" '\$2 == p {found=1} END {exit found ? 0 : 1}' "$STATE/mounted.tsv"
EOF
# findmnt -n -o FSTYPE mnt → btrfs iff mounted
cat >"$BIN/findmnt" <<EOF
#!$BASH
awk -F'\t' -v p="\$4" '\$2 == p {found=1} END {exit found ? 0 : 1}' "$STATE/mounted.tsv" && echo btrfs
EOF
# chown: no-op (sandbox user cannot chown; ownership is verified live)
cat >"$BIN/chown" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
# SANDBOX SHEBANG TRAP (test-migrate-hot-db lesson): rewrite stub
# interpreters to the bash running this test
for stub in "$BIN"/*; do
  sed -i "1c #!$BASH" "$stub"
done
chmod +x "$BIN"/*
export PATH="$BIN:$PATH"

# sed-patched copy: scratch paths, no sudo, current user gate
COPY="$SCRATCH/migrate.sh"
cp "$SCRIPT_UNDER_TEST" "$COPY"
sed -e "s|^DEVICE=\"/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713-part1\"|DEVICE=\"$FIXTURE_DEV\"|" \
  -e "s|^MOUNT=\"/mnt/rust-cache\"|MOUNT=\"$FIXTURE_MOUNT\"|" \
  -e "s|^SOURCES=\"/mnt/buildcache\"|SOURCES=\"$FIXTURE_BUILD\"|" \
  -e 's|^SUDO="sudo -n"|SUDO=""|' \
  -e 's|= "lars" ]|= "\$(id -un)" ]|' \
  "$SCRIPT_UNDER_TEST" >"$COPY"
for patched in "DEVICE=\"$FIXTURE_DEV\"" "MOUNT=\"$FIXTURE_MOUNT\"" "SOURCES=\"$FIXTURE_BUILD\"" 'SUDO=""'; do
  grep -qF "$patched" "$COPY" || {
    fail "sed patch drifted: '$patched' not in copy — migrate-rust-cache.sh header text changed"
    exit 1
  }
done
ok "sed patch applied cleanly (all 5 anchors present in copy)"

seed_buildcache() {
  mkdir -p "$FIXTURE_BUILD/cargo/registry/index/github.com-1cc" "$FIXTURE_BUILD/rust/monitor365/target/debug" "$FIXTURE_BUILD/sccache/0/5"
  echo "crate index blob" >"$FIXTURE_BUILD/cargo/registry/index/github.com-1cc/blob"
  echo "cache entry" >"$FIXTURE_BUILD/cargo/registry/cache-entry"
  echo "object file" >"$FIXTURE_BUILD/rust/monitor365/target/debug/main.o"
  mkdir -p "$FIXTURE_BUILD/rust/monitor365/target/debug/deps-empty"
  echo "sccache blob" >"$FIXTURE_BUILD/sccache/0/5/abcdef"
}
expect_sources_gone() {
  for d in cargo rust sccache; do
    [ ! -e "$FIXTURE_BUILD/$d" ] || return 1
  done
}

# ── scenario 1: fresh spare disk → format WITH -f, mount, move all three ────
reset_state
echo btrfs >"$STATE/fstype"
echo ssd-btrfs >"$STATE/label"
printf '%s\t%s\n' "$FIXTURE_BC_DEV" "$FIXTURE_BUILD" >>"$STATE/mounted.tsv"
seed_buildcache
if bash "$COPY" >"$SCRATCH/out1.log" 2>"$SCRATCH/err1.log"; then
  ok "scenario 1: script exits 0 on fresh spare"
else
  fail "scenario 1: script exited nonzero — $(tail -n3 "$SCRATCH/err1.log")"
fi
grep -q '^mkfs force=1 label=rust-cache' "$STATE/mkfs.log" &&
  ok "scenario 1: mkfs ran WITH -f (the 2026-10-06 live-run regression)" ||
  fail "scenario 1: mkfs missing or ran without -f — $(cat "$STATE/mkfs.log")"
grep -qF "noatime,compress=zstd:1,space_cache=v2,commit=120" "$STATE/mount.log" &&
  grep -qF "$FIXTURE_DEV $FIXTURE_MOUNT" "$STATE/mount.log" &&
  ok "scenario 1: mounted with the module's mount options" ||
  fail "scenario 1: mount log unexpected — $(cat "$STATE/mount.log")"
expect_sources_gone &&
  ok "scenario 1: all three source dirs removed from buildcache" ||
  fail "scenario 1: source dirs still present"
for d in cargo rust sccache; do
  [ -d "$FIXTURE_MOUNT/$d" ] || fail "scenario 1: $FIXTURE_MOUNT/$d missing"
done
[ "$(find "$FIXTURE_MOUNT" -type f | wc -l)" -eq 4 ] &&
  ok "scenario 1: 4 cache files landed on rust-cache" ||
  fail "scenario 1: file count on rust-cache wrong: $(find "$FIXTURE_MOUNT" -type f | wc -l)"
grep -q 'done\.' "$SCRATCH/out1.log" && ok "scenario 1: done banner" || fail "scenario 1: no done banner"

# ── scenario 2: re-run idempotency (no re-format; residual dir converges) ───
mkdir -p "$FIXTURE_BUILD/sccache"
echo "fresh cache churn" >"$FIXTURE_BUILD/sccache/new-blob"
if bash "$COPY" >"$SCRATCH/out2.log" 2>"$SCRATCH/err2.log"; then
  ok "scenario 2: re-run exits 0"
else
  fail "scenario 2: re-run exited nonzero — $(tail -n3 "$SCRATCH/err2.log")"
fi
[ "$(wc -l <"$STATE/mkfs.log")" -eq 1 ] &&
  ok "scenario 2: no second mkfs (already-formatted skip)" ||
  fail "scenario 2: mkfs ran again — $(cat "$STATE/mkfs.log")"
grep -q 'already formatted' "$SCRATCH/out2.log" &&
  ok "scenario 2: skip banner present" ||
  fail "scenario 2: no already-formatted banner"
[ ! -e "$FIXTURE_BUILD/sccache" ] &&
  ok "scenario 2: residual sccache converged to rust-cache" ||
  fail "scenario 2: residual sccache not moved"
grep -q "SKIP (no source or already moved): cargo" "$SCRATCH/out2.log" &&
  ok "scenario 2: already-moved dirs SKIP cleanly" ||
  fail "scenario 2: cargo not SKIPped on re-run"

# ── scenario 3: wrong content → gate refusal, nothing formatted/moved ──────
reset_state
echo ext4 >"$STATE/fstype"
echo buildcache >"$STATE/label"
seed_buildcache
if bash "$COPY" >"$SCRATCH/out3.log" 2>"$SCRATCH/err3.log"; then
  fail "scenario 3: script succeeded on a WRONG-content disk"
else
  ok "scenario 3: gate refused wrong-content disk (nonzero exit)"
fi
grep -q 'expected btrfs+ssd-btrfs' "$SCRATCH/err3.log" &&
  ok "scenario 3: refusal names the expected content" ||
  fail "scenario 3: refusal message unclear — $(cat "$SCRATCH/err3.log")"
[ -s "$STATE/mkfs.log" ] && fail "scenario 3: mkfs RAN on refused disk" ||
  ok "scenario 3: no mkfs on refused disk"
[ -f "$FIXTURE_BUILD/cargo/registry/cache-entry" ] &&
  ok "scenario 3: sources untouched on refusal" ||
  fail "scenario 3: sources disturbed on refusal"

# ── scenario 4: mounted device → format refusal ─────────────────────────────
reset_state
echo btrfs >"$STATE/fstype"
echo ssd-btrfs >"$STATE/label"
printf '%s\t%s\n' "$FIXTURE_DEV" "$SCRATCH/elsewhere" >>"$STATE/mounted.tsv"
if bash "$COPY" >"$SCRATCH/out4.log" 2>"$SCRATCH/err4.log"; then
  fail "scenario 4: script formatted a MOUNTED device"
else
  ok "scenario 4: mounted device refused (nonzero exit)"
fi
grep -q 'is mounted' "$SCRATCH/err4.log" &&
  ok "scenario 4: refusal says the device is mounted" ||
  fail "scenario 4: mounted-refusal message unclear — $(cat "$SCRATCH/err4.log")"
[ -s "$STATE/mkfs.log" ] && fail "scenario 4: mkfs RAN on mounted device" ||
  ok "scenario 4: no mkfs on mounted device"

# ── self-verifying assertion count ──────────────────────────────────────────
EXPECTED=$(grep -cE '(^|[[:space:]])ok[[:space:]]"' "$0")
if [ "$PASS_COUNT" -eq "$EXPECTED" ] && [ "$FAILURES" -eq 0 ]; then
  echo "ALL PASS: $PASS_COUNT assertions (anchored count matches)"
  exit 0
else
  echo "FAILURES: $FAILURES; PASS lines: $PASS_COUNT vs anchored ok-call sites: $EXPECTED" >&2
  exit 1
fi
