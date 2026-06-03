#!/usr/bin/env bash
# disk-diagnostic.sh — Diagnose disk space usage on evo-x2 via SSH
set -euo pipefail

TARGET="${1:-lars@192.168.1.150}"
SSH_OPTS="-o ServerAliveInterval=60 -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"

run() {
  ssh ${SSH_OPTS} "${TARGET}" "$@" 2>&1 | grep -v 'AUTHORIZED ACCESS\|authorized users\|Individual use\|strictly prohibited\|criminal and civil\|activities on\|reported to law\|not an authorized\|disconnect immediately\|^---$\|^\*'
}

echo "=========================================="
echo "  Disk Space Diagnostic"
echo "  Target: ${TARGET}"
echo "  $(date)"
echo "=========================================="

# --- Overall filesystem usage ---
echo ""
echo "--- Filesystem Usage ---"
run "df -h / /data /boot"

# --- Quick suspects ---
echo ""
echo "--- Nix store size ---"
run "du -sh /nix/store"

echo ""
echo "--- Nix generations (system) ---"
run "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | wc -l"
run "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -5"

echo ""
echo "--- Nix generations (user) ---"
run "nix-env --list-generations --profile /nix/var/nix/profiles/per-user/lars/home-manager 2>/dev/null | wc -l || echo 0"

echo ""
echo "--- Reclaimable by GC (dry-run) ---"
run "sudo nix store gc --dry-run 2>&1 | tail -3"

echo ""
echo "--- BTRFS allocation (root) ---"
run "sudo btrfs filesystem df /"

echo ""
echo "--- BTRFS snapshots size ---"
run "sudo btrfs subvolume list / 2>/dev/null | grep snapshot | head -10 || true"

echo ""
echo "--- Journal log size ---"
run "sudo journalctl --disk-usage"

echo ""
echo "--- Docker disk usage ---"
run "sudo docker system df 2>/dev/null || echo 'Docker not running'"

echo ""
echo "--- Large files (>1G, root partition only) ---"
run "sudo find / -xdev -type f -size +1G -exec ls -lh {} \; 2>/dev/null | awk '{print \$5, \$9}' | sort -rh | head -20"

echo ""
echo "--- Top dirs in / (depth 1, fast estimate) ---"
run "sudo du -d1 -h --apparent-size / 2>/dev/null | sort -rh | head -15"

echo ""
echo "=========================================="
echo "Done."
