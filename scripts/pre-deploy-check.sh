#!/usr/bin/env bash
# Pre-deploy validation: catches boot-breaking issues BEFORE nixos-rebuild
# Run: nix run .#pre-deploy-check
set -euo pipefail

PASS=0
FAIL=0
WARN=0

pass() {
  echo "  ✓ $1"
  PASS=$((PASS + 1))
}
fail() {
  echo "  ✗ $1"
  FAIL=$((FAIL + 1))
}
warn() {
  echo "  ⚠ $1"
  WARN=$((WARN + 1))
}

echo "=== Pre-Deploy Validation ==="
echo ""

# 1. Flake syntax check
echo "1. Flake syntax validation"
if nix flake check --no-build >/dev/null 2>&1; then
  pass "nix flake check --no-build"
else
  fail "nix flake check --no-build — fix syntax errors before deploying"
  nix flake check --no-build 2>&1 | tail -5
fi

# 2. Eval the system configuration
echo ""
echo "2. Configuration evaluation"
if nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath >/dev/null 2>&1; then
  pass "nixosConfigurations.evo-x2 evaluates"
else
  fail "nixosConfigurations.evo-x2 evaluation failed"
fi

# 3. Check no Podman/Docker split-brain
echo ""
echo "3. Container runtime consistency"
BACKEND=$(nix eval --raw .#nixosConfigurations.evo-x2.config.virtualisation.oci-containers.backend 2>/dev/null || echo "podman")
DOCKER_ENABLED=$(nix eval --raw .#nixosConfigurations.evo-x2.config.virtualisation.docker.enable 2>/dev/null || echo "false")
if [ "$DOCKER_ENABLED" = "true" ] && [ "$BACKEND" = "podman" ]; then
  fail "oci-containers backend is podman but docker is enabled — split-brain"
else
  pass "Single container runtime (docker=$DOCKER_ENABLED, backend=$BACKEND)"
fi

# 4. Check mount options for nofail on non-critical mounts
echo ""
echo "4. Mount safety (non-root mounts need nofail or noauto)"
MOUNTS=$(nix eval .#nixosConfigurations.evo-x2.config.fileSystems --json 2>/dev/null | jq -r 'to_entries[] | select(.key != "/" and .key != "/boot" and .key != "/nix") | "\(.key)=\(.value.options | join(","))"' 2>/dev/null || echo "")
if [ -z "$MOUNTS" ]; then
  warn "Could not evaluate mount options"
else
  while IFS= read -r line; do
    MOUNT=$(echo "$line" | cut -d= -f1)
    OPTS=$(echo "$line" | cut -d= -f2-)
    if echo "$OPTS" | grep -qE "nofail|noauto"; then
      pass "$MOUNT has nofail/noauto"
    else
      fail "$MOUNT missing nofail/noauto — boot will emergency if mount fails"
    fi
  done <<<"$MOUNTS"
fi

# 5. Check no ExecStart inside harden()
echo ""
echo "5. Service hardening validation"
HARDEN_USERS=$(grep -rn 'harden {' --include="*.nix" . 2>/dev/null | grep -E 'ExecStart|Type|RemainAfterExit' || true)
if [ -n "$HARDEN_USERS" ]; then
  fail "ExecStart/Type found inside harden() — will be silently dropped:"
  echo "$HARDEN_USERS"
else
  pass "No ExecStart/Type inside harden() calls"
fi

# 6. Check current system health (if running on target)
echo ""
echo "6. Current system health"
if command -v systemctl &>/dev/null; then
  FAILED=$(systemctl --failed --no-pager --plain 2>/dev/null | tail -n +2 | grep -c "\.service" || true)
  FAILED=${FAILED:-0}
  if [ "$FAILED" -eq 0 ]; then
    pass "No failed units"
  else
    warn "$FAILED failed unit(s) — review before deploying"
    systemctl --failed --no-pager 2>/dev/null | head -10
  fi
fi

# 7. DMS desktop shell health
echo ""
echo "7. DMS desktop shell health"
if command -v dms &>/dev/null; then
  if dms doctor &>/dev/null; then
    pass "dms doctor passed"
  else
    warn "dms doctor reported issues — run 'dms doctor' for details"
  fi
else
  pass "dms binary not in PATH (may not be deployed yet)"
fi

# 8. Disk space on root filesystem
echo ""
echo "8. Disk space"
ROOT_PCT=$(df -P / 2>/dev/null | awk 'NR==2{gsub(/%/,""); print $5}' || echo "0")
BUILDS_DIR="/nix/var/nix/builds"
STALE_BUILDS=0
if [ -d "$BUILDS_DIR" ]; then
  STALE_BUILDS=$(find "$BUILDS_DIR" -maxdepth 1 -type d -name 'nix-*' -mmin +60 2>/dev/null | wc -l)
fi
if [ "$ROOT_PCT" -ge 95 ]; then
  fail "Root filesystem at ${ROOT_PCT}% — deploying risks emergency shell. Free space before deploying"
elif [ "$ROOT_PCT" -ge 85 ]; then
  warn "Root filesystem at ${ROOT_PCT}% — consider freeing space before deploying"
else
  pass "Root filesystem at ${ROOT_PCT}% usage"
fi
if [ "$STALE_BUILDS" -gt 0 ]; then
  warn "$STALE_BUILDS stale build sandboxes in /nix/var/nix/builds — run 'nix-build-cleanup' or clean manually"
fi

# Summary
echo ""
echo "=== Summary: $PASS passed, $WARN warnings, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ DEPLOY BLOCKED — fix failures above before deploying"
  exit 1
fi

echo ""
echo "✅ Pre-deploy checks passed — safe to deploy"
exit 0
