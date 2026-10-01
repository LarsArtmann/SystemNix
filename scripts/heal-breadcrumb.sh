#!/usr/bin/env bash
# Heal-attribution breadcrumb (convention: CONTRIBUTING.md → "Verification conventions").
# Manual system heals (systemd-tmpfiles --create, nix-daemon restart, manual
# socket/service starts) leave ONE journaled line + one state-file stamp so the
# next forensics round can attribute the recovery (the 2026-09-25 05:32
# /run/binfmt heal's actor was unknowable without this).
#
# Usage:  bash scripts/heal-breadcrumb.sh "<what was healed> <how>"
# Works unprivileged (logger -> journald socket); state log under
# ~/.local/state (override with HEAL_LOG). Never put secret VALUES in the text.
set -euo pipefail

msg="${1:-}"
if [[ -z $msg ]]; then
  echo "usage: $0 \"<what was healed> <how>\"" >&2
  exit 2
fi

stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
invoker="${SUDO_USER:-$(id -un)}"
invoker_uid="$(id -u "$invoker")"
line="${stamp} user=${invoker} uid=${invoker_uid} ${msg}"

if command -v logger >/dev/null 2>&1; then
  logger -t systemnix-heal -p info -- "${line}" ||
    echo "warn: logger failed (breadcrumb kept in state file only)" >&2
else
  echo "warn: logger not found (breadcrumb kept in state file only)" >&2
fi

log_file="${HEAL_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/systemnix-heals.log}"
mkdir -p "$(dirname "$log_file")"
printf '%s\n' "$line" >>"$log_file"

echo "breadcrumb: ${line}"
echo "journal: journalctl -t systemnix-heal | state: ${log_file}"
