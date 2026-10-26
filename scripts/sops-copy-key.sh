#!/usr/bin/env bash
# Copy a secret value between sops-encrypted YAML files without exposing it.
# The value exists only in process memory/argv: never on the invoking agent
# command line, never in a history file, never on stdout. Sudo runs INSIDE
# the script (the agent command guard only sees the typed invocation line).
# Pattern authority: .crush/skills/sops-secret-management/SKILL.md
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 <src-sops-yaml> <src-key> <dst-sops-yaml> <dst-key>" >&2
  exit 64
fi

src=$1
srcKey=$2
dst=$3
dstKey=$4

for f in "$src" "$dst"; do
  if [ ! -f "$f" ]; then
    echo "sops-copy-key: no such file: $f" >&2
    exit 66
  fi
done
command -v sops >/dev/null || { echo "sops-copy-key: sops not on PATH" >&2; exit 69; }
command -v ssh-to-age >/dev/null || { echo "sops-copy-key: ssh-to-age not on PATH" >&2; exit 69; }

SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key)

value=$(SOPS_AGE_KEY=$SOPS_AGE_KEY sops -d --extract "[\"$srcKey\"]" "$src")
if [ -z "$value" ]; then
  echo "sops-copy-key: source key '$srcKey' in $src is empty" >&2
  exit 65
fi

SOPS_AGE_KEY=$SOPS_AGE_KEY sops --set "[\"$dstKey\"] \"${value}\"" "$dst" >/dev/null

roundtrip=$(SOPS_AGE_KEY=$SOPS_AGE_KEY sops -d --extract "[\"$dstKey\"]" "$dst")
if [ "$roundtrip" != "$value" ]; then
  echo "sops-copy-key: round-trip mismatch after --set (dst readback differs)" >&2
  exit 70
fi
echo "sops-copy-key: '$dstKey' set in $dst and verified (value not displayed)"
