#!/usr/bin/env bash
# Fixture selftest for scripts/lib/zombie-mount-gate.sh (pre-deploy §17
# zombie-mount detector). Negative-path parity with the §10/§11/§13/§14/
# §15/§16 selftests: the gate blocks deploys, so its FAIL verdicts must be
# proven against fixtures, not trusted from a green-path-only live probe
# (docs/status/tasks/2026-10-21_04-27_task-* §e.3/§f.5).
#
# The stub findmnt/timeout ride PATH; the device-existence seam is
# ZM_DEV_ROOT (fixture sysfs), and a dead real-IO probe is simulated by a
# listed mount with no directory behind it (ls -A fails = the EIO shape).
set -uo pipefail

PASS_CNT=0
FAIL_CNT=0
ok() {
  PASS_CNT=$((PASS_CNT + 1))
}
bad() {
  echo "FAIL: $1" >&2
  FAIL_CNT=$((FAIL_CNT + 1))
}

LIB="$(
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
)/lib"
# shellcheck source=lib/zombie-mount-gate.sh disable=SC1091
source "$LIB/zombie-mount-gate.sh"

FIX=$(mktemp -d)
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/bin" "$FIX/dev"

BASH_BIN="$(command -v bash)"

# Stub findmnt driven by fixture files:
#   $FIX/targets        → output of `findmnt -rn -o TARGET`
#   $FIX/source.<key>   → output of `findmnt -nro SOURCE -t … /mnt/X`
#     (key = target path with / → _, e.g. mnt_pool)
cat >"$FIX/bin/findmnt" <<EOF
#!$BASH_BIN
case " \$* " in
  *' -rn -o TARGET '*)
    cat "$FIX/targets" 2>/dev/null
    exit 0
    ;;
  *' -nro SOURCE '*)
    tgt="\${*: -1}"
    key="\$(printf '%s' "\$tgt" | sed 's|^/||; s|/|_|g')"
    if [ -f "$FIX/source.\$key" ]; then
      cat "$FIX/source.\$key"
    fi
    exit 0
    ;;
esac
exit 1
EOF

# Stub timeout: drop the budget and exec the command (the real-IO leg then
# exercises the REAL ls against fixture dirs — a missing dir = dead fs).
# Quoted delimiter: "$@" must reach the stub file verbatim, not expand at
# write time (an unquoted heredoc turned the stub into a no-op rc-0 and the
# IO probe never tripped — caught by leg 3).
cat >"$FIX/bin/timeout" <<'EOF'
#!BASH_PLACEHOLDER
shift
exec "$@"
EOF
sed -i "1s|.*|#!$BASH_BIN|" "$FIX/bin/timeout"
chmod +x "$FIX/bin/findmnt" "$FIX/bin/timeout"

PATH="$FIX/bin:$PATH"
export PATH
# Fixture sysfs: the lib's device-existence checks resolve under $FIX/dev
# (device nodes live at $FIX/dev/dev/sdX1, mirroring the ZM_DEV_ROOT prefix).
# shellcheck disable=SC2034
ZM_DEV_ROOT="$FIX/dev"
# Fixture VFS: the real-IO probe's ls targets $FIX/root/mnt/… instead of the
# live mounts (the listed paths exist on the real box — without the remap the
# probe would answer from the LIVE filesystem, green-washing leg 3/leg 6).
# shellcheck disable=SC2034
ZM_ROOT="$FIX/root"

# Fixture-mount helpers: mnt creates the target dir + optional device file;
# src writes the findmnt SOURCE row(s).
mnt() { # mnt <path> [device]
  mkdir -p "$FIX/root$1"
  if [ -n "${2:-}" ]; then
    mkdir -p "$(dirname "$FIX/dev$2")"
    : >"$FIX/dev$2"
  fi
}
src() { # src <path> <row...>
  local key
  key="$(printf '%s' "$1" | sed 's|^/||; s|/|_|g')"
  shift
  printf '%s\n' "$@" >"$FIX/source.$key"
}

run_leg() { # run_leg — capture the scan's verdicts into FIX/out
  : >"$FIX/out"
  # shellcheck disable=SC2034
  ZM_PASS="$FIX/bin/vpass" ZM_FAIL="$FIX/bin/vfail"
  cat >"$FIX/bin/vpass" <<EOF
#!$BASH_BIN
printf 'PASS %s\n' "\$1" >> "$FIX/out"
EOF
  cat >"$FIX/bin/vfail" <<EOF
#!$BASH_BIN
printf 'FAIL %s\n' "\$1" >> "$FIX/out"
EOF
  chmod +x "$FIX/bin/vpass" "$FIX/bin/vfail"
  zm_scan
}

expect_fail() { # expect_fail <grep-pattern>
  if grep -q "FAIL $1" "$FIX/out"; then
    ok
  else
    bad "leg: expected FAIL verdict '$1' — got:
$(cat "$FIX/out")"
  fi
}
expect_no_fail() {
  if grep -q 'FAIL ' "$FIX/out"; then
    bad "unexpected FAIL verdict(s):
$(cat "$FIX/out")"
  else
    ok
  fi
}
expect_pass_line() { # expect_pass_line <grep-pattern>
  if grep -q "PASS $1" "$FIX/out"; then
    ok
  else
    bad "expected PASS verdict missing:
$(cat "$FIX/out")"
  fi
}

# ── Leg 1: green — healthy mounts, devices present, IO probe answers ────────
mnt /mnt/pool /dev/sda1
mnt /mnt/buildcache /dev/sdb1
src /mnt/pool "/dev/sda1[/@pool]"
src /mnt/buildcache "/dev/sdb1"
printf '/mnt/pool\n/mnt/buildcache\n' >"$FIX/targets"
run_leg
expect_pass_line "no zombie mounts"
expect_no_fail

# ── Leg 2: zombie device — SOURCE /dev/sdX absent from fixture sysfs ────────
mnt /mnt/pool /dev/sda1
mnt /mnt/buildcache
src /mnt/pool "/dev/sda1[/@pool]"
src /mnt/buildcache "/dev/sdX1"
printf '/mnt/pool\n/mnt/buildcache\n' >"$FIX/targets"
run_leg
expect_fail "ZOMBIE MOUNT /mnt/buildcache"
# NO pass line here: zm_scan emits the green verdict only when NOTHING tripped
# (that suppression is itself part of the verdict contract — pinned in leg 3).
if grep -q 'umount -l /mnt/buildcache' "$FIX/out"; then
  ok
else
  bad "zombie-device verdict lost the umount-l recovery hint"
fi

# ── Leg 3: dead IO — device exists, the mount fails every read (no dir) ─────
# Also pins the suppression contract: a tripped mount emits NO green verdict
# even when every other mount is healthy.
mnt /mnt/pool /dev/sda1
src /mnt/pool "/dev/sda1[/@pool]"
mnt /mnt/buildcache /dev/sdb1
src /mnt/buildcache "/dev/sdb1"
printf '/mnt/pool\n/mnt/buildcache\n' >"$FIX/targets"
# NO "$FIX/root/mnt/buildcache" dir: ls -A fails = the EIO shape (mnt()
# created it above; the dead fs is simulated by removing it post-listing,
# exactly the zombie shape: findmnt lists it, nothing answers behind it).
rm -rf "$FIX/root/mnt/buildcache"
run_leg
expect_fail "ZOMBIE/DEAD MOUNT /mnt/buildcache"
if grep -q '^PASS ' "$FIX/out"; then
  bad "tripped scan must NOT emit the green verdict (got one):
$(cat "$FIX/out")"
else
  ok
fi
if grep -q 'das-link-recovery-check.sh' "$FIX/out"; then
  ok
else
  bad "dead-IO verdict lost the das-link-recovery-check recovery pointer"
fi

# ── Leg 4: autofs row filtered — systemd-1 row ignored, real row checked ────
mnt /mnt/pool /dev/sda1
src /mnt/pool "systemd-1" "/dev/sda1[/@pool]"
printf '/mnt/pool\n' >"$FIX/targets"
run_leg
expect_pass_line "no zombie mounts"
expect_no_fail

# ── Leg 5: autofs-only SOURCE (cold automount) — no device check, no fail ───
mnt /mnt/pool
src /mnt/pool "systemd-1"
printf '/mnt/pool\n' >"$FIX/targets"
run_leg
expect_pass_line "no zombie mounts"
expect_no_fail

# ── Leg 6: non-/mnt targets ignored (grep anchor is ^/mnt/) ─────────────────
mnt /somewhere-else /dev/sdz9
src /somewhere-else "/dev/sdz9"
printf '/mnt/pool\n/somewhere-else\n' >"$FIX/targets"
mnt /mnt/pool /dev/sda1
src /mnt/pool "/dev/sda1[/@pool]"
run_leg
expect_pass_line "no zombie mounts"
expect_no_fail

# ── Leg 7: wiring tripwire — pre-deploy-check.sh still sources + calls it ───
PDC="$(cd "$LIB/.." && pwd)/pre-deploy-check.sh"
if grep -q 'zombie-mount-gate.sh' "$PDC" && grep -q 'zm_scan' "$PDC"; then
  ok
else
  bad "pre-deploy-check.sh no longer wires the zombie-mount gate (§17 would run nothing, phantom-green)"
fi

echo "zombie-mount-gate selftest: $PASS_CNT passed, $FAIL_CNT failed"
if [ "$FAIL_CNT" -gt 0 ]; then
  exit 1
fi
