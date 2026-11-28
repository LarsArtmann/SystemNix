#!/usr/bin/env bash
# Type audit of every keyed sops secret the host config declares.
#
# sops-install-secrets renders STRING values only: any other type fails the
# whole activation ("the value of key '…' is not a string", every secret at
# once), and the pre-deploy manifest check does not look at value types. A
# JSON document is the known way to get there: `sops set --value-file` turns
# a JSON string into an object (sops 3.13.3).
#
# Prints key names and types, never a value. Run from the repo root.
set -euo pipefail

usage() {
  echo "usage: $0 [--host <nixosConfiguration>]" >&2
}

host=evo-x2
while [ "$#" -gt 0 ]; do
  case $1 in
    --host)
      [ "$#" -ge 2 ] || {
        usage
        exit 64
      }
      host=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

for tool in jq sops ssh-to-age sudo; do
  command -v "$tool" > /dev/null || {
    echo "sops-value-types: $tool is not on PATH" >&2
    exit 69
  }
done
sudo -n true 2> /dev/null || {
  echo "sops-value-types: passwordless sudo is required to derive the age identity from the host key" >&2
  exit 77
}
[ -n "${XDG_RUNTIME_DIR:-}" ] || {
  echo "sops-value-types: XDG_RUNTIME_DIR is unset: no tmpfs for the plaintext work dir" >&2
  exit 73
}

# The identity reaches sops through its environment as the INVOKING user.
# sops never runs behind sudo: sudo journals the full COMMAND line, so
# `sudo env SOPS_AGE_KEY=... sops ...` writes the identity into the journal.
SOPS_AGE_KEY=$(sudo -n cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key)
export SOPS_AGE_KEY

work=$XDG_RUNTIME_DIR/sops-value-types.$$
# rm, not trash, for this one directory: it is plaintext on tmpfs, and
# trash would copy it onto the disk.
trap 'rm -rf -- "$work"' EXIT
mkdir -m 700 "$work"

nix eval --impure --json --expr "let c = (builtins.getFlake (toString ./.)).nixosConfigurations.$host.config; in builtins.attrValues (builtins.mapAttrs (name: s: { inherit name; file = toString s.sopsFile; key = if s.key != \"\" then s.key else name; format = s.format; }) c.sops.secrets)" > "$work/secrets.json" \
  || {
    echo "sops-value-types: the host config did not evaluate" >&2
    exit 70
  }

mapfile -t files < <(jq -r 'map(.file) | unique | .[]' "$work/secrets.json" | sort)

bad=0
count=0
for file in "${files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "MISSING FILE    $file"
    bad=$((bad + 1))
    continue
  fi
  if ! sops -d --output-type json "$file" > "$work/plain.json" 2> "$work/decrypt.err"; then
    echo "DECRYPT FAIL    $file"
    bad=$((bad + 1))
    continue
  fi
  while IFS=$'\t' read -r name key secret_format; do
    count=$((count + 1))
    type=$(jq -r --arg k "$key" 'if has($k) then .[$k] | type else "ABSENT" end' "$work/plain.json")
    if [ "$type" != string ]; then
      echo "NOT A STRING    $(basename "$file")  $name (key $key, format $secret_format) -> $type"
      bad=$((bad + 1))
    fi
  done < <(jq -r --arg f "$file" 'map(select(.file == $f)) | .[] | [.name, .key, .format] | @tsv' "$work/secrets.json")
done

echo "sops-value-types: $count declared keyed secrets in ${#files[@]} files, $bad not a string"
[ "$bad" -eq 0 ]
