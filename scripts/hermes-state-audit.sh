#!/usr/bin/env bash
# Hermes state audit — /home/hermes is 2770 hermes:hermes, so only root can
# traverse it. Run as:  sudo bash scripts/hermes-state-audit.sh
#
# Answers the T8 questions from docs/planning/2026-08-20_09-18_*:
#   - what occupies /home/hermes (58G observed 2026-08-20)?
#   - is MemoryMax=24G justified (GPU mappings are NOT RSS — context below)?
#
# The projects bind (workspace/projects) is EXCLUDED everywhere: it is a
# read-only view of /home/lars/projects — counting it would double-report.
set -euo pipefail

STATE_DIR="${1:-/home/hermes}"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: must run as root (stateDir is 0700 to hermes)." >&2
  echo "  sudo bash $0" >&2
  exit 1
fi
if [ ! -d "$STATE_DIR" ]; then
  echo "ERROR: $STATE_DIR does not exist" >&2
  exit 1
fi

echo "=== Top-level breakdown (2 levels, bind excluded) ==="
du -h -d 2 --exclude='workspace/projects' "$STATE_DIR" 2>/dev/null | sort -rh | head -30

echo
echo "=== 20 largest files (bind excluded) ==="
find "$STATE_DIR" -xdev -path "$STATE_DIR/workspace/projects" -prune -o \
  -type f -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -20 |
  awk -F'\t' '{ printf "%.1f GiB\t%s\n", $1/1073741824, $2 }'

echo
echo "=== Workspace clone growth (writable, ours to bound) ==="
du -h -d 1 --exclude='projects' "$STATE_DIR/workspace" 2>/dev/null | sort -rh | head -10

echo
echo "=== MemoryMax context ==="
echo "Unit MemoryMax: $(systemctl show hermes -p MemoryMax --value)"
echo "Current cgroup memory.current: $(cat /sys/fs/cgroup/system.slice/hermes.service/memory.current 2>/dev/null || echo '?')"
echo "peak (memory.peak): $(cat /sys/fs/cgroup/system.slice/hermes.service/memory.peak 2>/dev/null || echo '?')"
echo "NOTE: PyTorch/ROCm map GPU/HIP allocations into the address space —"
echo "cgroup memory counts them differently than RSS. Do NOT lower MemoryMax"
echo "from these numbers alone; correlate with OOM-kill journal history first:"
echo "  journalctl -u hermes --since -30d | grep -i 'killed process\|oom'"
