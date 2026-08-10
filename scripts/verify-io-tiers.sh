#!/usr/bin/env bash
# Verify BFQ I/O priority tiers are correctly applied to services.
# Shows current I/O scheduling config and validates tier ordering.
#
# Usage: nix run .#verify-io-tiers
#        or: ./scripts/verify-io-tiers.sh
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "=== BFQ I/O Priority Tier Verification ==="
echo ""

# Check scheduler is BFQ
SCHEDULER=$(cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null | grep -o '\[bfq\]' || echo "")
if [ -n "$SCHEDULER" ]; then
  pass "BFQ scheduler active on nvme0n1"
else
  CURRENT=$(cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null || echo "unknown")
  fail "BFQ not active (current: $CURRENT) — I/O tiers will be ignored"
fi
echo ""

# Expected tier assignments (service → class:priority)
declare -A EXPECTED
EXPECTED["sshd"]="best-effort:1"
EXPECTED["niri"]="best-effort:3"
EXPECTED["pipewire"]="best-effort:3"
EXPECTED["clickhouse"]="best-effort:5"
EXPECTED["monitor365-server"]="best-effort:5"
EXPECTED["discordsync"]="best-effort:6"
EXPECTED["signoz"]="best-effort:6"
EXPECTED["browser-history"]="best-effort:6"
EXPECTED["fstrim"]="idle:"

echo "Service Tier Assignments:"
echo "─────────────────────────────────────────────────────────────"
printf "%-40s %-15s %-15s %s\n" "SERVICE" "EXPECTED" "ACTUAL" "STATUS"
echo "─────────────────────────────────────────────────────────────"

for svc in "${!EXPECTED[@]}"; do
  expected="${EXPECTED[$svc]}"

  # systemd show returns IOSchedulingClass and IOSchedulingPriority
  io_class=$(systemctl show "$svc" -p IOSchedulingClass --value 2>/dev/null || echo "n/a")
  io_pri=$(systemctl show "$svc" -p IOSchedulingPriority --value 2>/dev/null || echo "")

  if [ "$io_class" = "n/a" ] || [ -z "$io_class" ]; then
    actual="not-running"
    status="SKIP"
    printf "%-40s %-15s %-15s %s\n" "$svc" "$expected" "$actual" "$status"
    continue
  fi

  if [ -n "$io_pri" ] && [ "$io_pri" != "0" ]; then
    actual="${io_class}:${io_pri}"
  else
    actual="${io_class}:"
  fi

  if [ "$actual" = "$expected" ]; then
    status="✓"
    pass "$svc at $actual"
  else
    status="✗ MISMATCH"
    fail "$svc expected $expected, got $actual"
  fi
  printf "%-40s %-15s %-15s %s\n" "$svc" "$expected" "$actual" "$status"
done

echo ""
echo "─────────────────────────────────────────────────────────────"

# Verify tier ordering: sshd (BE/1) must be strictly higher priority than nix-daemon
echo ""
echo "Tier Ordering Check:"
SSHD_PRI=$(systemctl show sshd -p IOSchedulingPriority --value 2>/dev/null || echo "")
NIX_PRI=$(systemctl show nix-daemon -p IOSchedulingPriority --value 2>/dev/null || echo "")
if [ -n "$SSHD_PRI" ] && [ -n "$NIX_PRI" ]; then
  if [ "$SSHD_PRI" -lt "$NIX_PRI" ]; then
    pass "sshd (BE/$SSHD_PRI) has higher I/O priority than nix-daemon (BE/$NIX_PRI)"
  else
    fail "sshd (BE/$SSHD_PRI) does NOT have higher I/O priority than nix-daemon (BE/$NIX_PRI)"
  fi
else
  echo "  ⚠ Could not verify tier ordering (services not queryable)"
fi

# Show current I/O pressure
echo ""
echo "Current I/O Pressure (/proc/pressure/io):"
if [ -f /proc/pressure/io ]; then
  cat /proc/pressure/io
else
  echo "  PSI not available on this kernel"
fi

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
exit "$FAIL"
