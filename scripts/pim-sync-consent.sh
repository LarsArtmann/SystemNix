#!/usr/bin/env bash
# pim-sync consent launcher (runbook: docs/services/pim-sync.md).
#
# Does the agent half of the pim-sync go-live in one run: it ingests the GCP
# Desktop client JSON into sops, drives the Google consents (the owner only
# clicks Continue in the browser that opens) and ingests the four token files
# into sops. No secret value reaches a command line, a history file or
# stdout: values travel file -> sops, then sops -> a 0600 file on tmpfs.
#
# The host age identity is derived into a shell variable and handed to sops
# through its environment as the INVOKING user. sops never runs behind sudo:
# sudo journals the full COMMAND line, so `sudo env SOPS_AGE_KEY=... sops`
# writes the identity into the system journal (7 such lines, 2026-11-22 and
# 2026-11-25).
#
# Every sops value must stay ONE string (sops-nix renders string values
# only, any other type fails the whole activation), and the sops CLI cannot
# write a JSON document as one: `sops set --value-file` / `--value-stdin`
# parse the string a second time and store an object (sops 3.13.3, proven
# on a scratch copy 2026-11-28). The ingest therefore decrypts the file to
# tmpfs, edits it as data and encrypts it again, and replaces the file only
# when every untouched value, every written value and the recipient set are
# proven identical.
set -euo pipefail

die() {
  echo "pim-sync-consent: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
usage: pim-sync-consent.sh [--client-json <file>] [--account personal|work] [--secret-file <file>] [--no-browser] [--pim-sync <bin>]

  --client-json <file>  validate this GCP Desktop client JSON and ingest it into sops first
  --account <name>      only this account's two grants (default: personal and work)
  --secret-file <file>  read the client JSON from this file instead of sops
  --no-browser          print each consent URL instead of opening it
  --pim-sync <bin>      pim-sync binary (default: the flake input's package)

PIM_SYNC_SOPS_FILE overrides the sops file (test runs against a scratch copy);
PIM_SYNC_CONSENT_TIMEOUT bounds each consent in seconds (default 600).

Every consent needs a browser ON THIS HOST (the redirect goes to its loopback
interface). personal = lartyhd@gmail.com, work = lars@helpless.ai.
USAGE
}

client_json=
account=
secret_file=
no_browser=false
pim_sync_bin=
consent_timeout=${PIM_SYNC_CONSENT_TIMEOUT:-600}
sops_file=${PIM_SYNC_SOPS_FILE:-platforms/nixos/secrets/pim-sync.yaml}
sops_rule_path=platforms/nixos/secrets/pim-sync.yaml
browser_units=0

while [ "$#" -gt 0 ]; do
  case $1 in
    --client-json)
      [ "$#" -ge 2 ] || die "--client-json needs a file"
      client_json=$2
      shift 2
      ;;
    --account)
      [ "$#" -ge 2 ] || die "--account needs a name"
      account=$2
      shift 2
      ;;
    --secret-file)
      [ "$#" -ge 2 ] || die "--secret-file needs a file"
      secret_file=$2
      shift 2
      ;;
    --no-browser)
      no_browser=true
      shift
      ;;
    --pim-sync)
      [ "$#" -ge 2 ] || die "--pim-sync needs a path"
      pim_sync_bin=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

declare -A account_email=(
  [personal]=lartyhd@gmail.com
  [work]=lars@helpless.ai
)
declare -A token_key=(
  [personal.json]=pim_sync_token_personal
  [work.json]=pim_sync_token_work
  [personal-calendar.json]=pim_sync_token_personal_calendar
  [work-calendar.json]=pim_sync_token_work_calendar
)

if [ -n "$account" ]; then
  accounts=("$account")
else
  accounts=(personal work)
fi
for name in "${accounts[@]}"; do
  [ -n "${account_email[$name]:-}" ] || die "unknown account '$name' (personal or work)"
done

[ -n "${XDG_RUNTIME_DIR:-}" ] || die "XDG_RUNTIME_DIR is unset: no tmpfs for the plaintext work dir"
work=$XDG_RUNTIME_DIR/pim-sync-consent.$$
auth_pid=

# rm, not trash, for this one directory: it lives on tmpfs and holds
# plaintext secrets, and trash would copy them onto the disk.
cleanup() {
  if [ -n "$auth_pid" ]; then
    kill "$auth_pid" 2>/dev/null || true
  fi
  [ -z "${work:-}" ] || rm -rf -- "$work"
}
trap cleanup EXIT

command -v jq > /dev/null || die "jq is not on PATH"

mkdir -m 700 "$work"
mkdir -m 700 "$work/tokens"
: > "$work/written.tsv"

need_sops() {
  if [ -n "${SOPS_AGE_KEY:-}" ]; then
    return
  fi
  for tool in sops ssh-to-age sudo; do
    command -v "$tool" > /dev/null || die "$tool is not on PATH"
  done
  sudo -n true 2> /dev/null || die "passwordless sudo is required to derive the age identity from the host key"
  [ -w "$sops_file" ] || die "$sops_file is not writable by $(id -un)"
  SOPS_AGE_KEY=$(sudo -n cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) \
    || die "cannot derive the age identity from the host key"
  export SOPS_AGE_KEY
}

value_sha() { # <json file> <key>: sha256 of the key's string value, exact bytes
  jq -j --arg key "$2" '.[$key]' "$1" | sha256sum | cut -d' ' -f1
}

# Public shape of the sops metadata that a rewrite must not change.
sops_shape() {
  sed -n '/^sops:/,$p' "$1" | grep -E 'recipient: age1|unencrypted_suffix|shamir_threshold' | sort
}

# Writes string values (key <TAB> file pairs in $work/written.tsv) into the
# sops file and proves the result before replacing it.
sops_write() {
  local before=$work/sops.before.json plain=$work/sops.plain.json new=$work/sops.new.yaml
  local key file keys_before keys_after want got shape_before shape_after tmp
  need_sops
  sops -d --output-type json "$sops_file" > "$before" || die "cannot decrypt $sops_file"
  jq -e 'all(.[]; type == "string")' "$before" > /dev/null \
    || die "$sops_file holds a non-string value: sops-nix cannot render that, fix it before writing"
  cp "$before" "$plain"
  while IFS=$'\t' read -r key file; do
    jq --arg key "$key" --rawfile value "$file" '.[$key] = $value' "$plain" > "$plain.next" \
      || die "cannot stage $key"
    mv -f "$plain.next" "$plain"
  done < "$work/written.tsv"
  jq -r 'to_entries[] | "\(.key): \(.value|tojson)"' "$plain" > "$work/sops.plain.yaml"

  shape_before=$(sops_shape "$sops_file")
  sops -e --filename-override "$sops_rule_path" /dev/stdin < "$work/sops.plain.yaml" > "$new" 2> "$work/sops-encrypt.err" \
    || die "sops -e failed: $(sed -n '1,3p' "$work/sops-encrypt.err")"
  shape_after=$(sops_shape "$new")
  [ -n "$shape_after" ] || die "refusing to write: the new file shows no age recipient"
  [ "$shape_before" = "$shape_after" ] || die "refusing to write: the sops metadata shape would change"

  sops -d --output-type json "$new" > "$work/sops.after.json" || die "the new file does not decrypt"
  keys_before=$(jq -r 'keys[]' "$before" | sort)
  keys_after=$(jq -r 'keys[]' "$work/sops.after.json" | sort)
  [ "$keys_before" = "$keys_after" ] || die "refusing to write: the key set would change"
  while IFS= read -r key; do
    got=$(value_sha "$work/sops.after.json" "$key")
    file=$(awk -F '\t' -v k="$key" '$1 == k { print $2 }' "$work/written.tsv")
    if [ -n "$file" ]; then
      want=$(sha256sum "$file" | cut -d' ' -f1)
    else
      want=$(value_sha "$before" "$key")
    fi
    [ "$got" = "$want" ] || die "refusing to write: value mismatch for $key after re-encryption (value not shown)"
  done <<< "$keys_after"
  jq -e 'all(.[]; type == "string")' "$work/sops.after.json" > /dev/null || die "refusing to write: a value is not a string"

  tmp=$sops_file.tmp.$$
  cp "$new" "$tmp" && chmod 0644 "$tmp"
  mv -f "$tmp" "$sops_file"
  cmp -s "$new" "$sops_file" || die "$sops_file differs from the verified file after install"
  while IFS=$'\t' read -r key _; do
    echo "pim-sync-consent: wrote $key into $sops_file (verified by hash, value not shown)"
  done < "$work/written.tsv"
  : > "$work/written.tsv"
}

ingest_json() { # <sops key> <file holding one JSON document>
  local key=$1 file=$2
  [ -s "$file" ] || die "$file is empty"
  jq -e 'type == "object"' "$file" > /dev/null || die "$file is not a JSON object"
  printf '%s\t%s\n' "$key" "$file" >> "$work/written.tsv"
  sops_write
}

open_url() {
  local url_file=$1
  if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
    xdg-open "$(cat "$url_file")" > /dev/null 2>&1 &
    return 0
  fi
  # A transient user unit carries the graphical session's environment; the
  # URL goes through a file because systemd expands % specifiers in argv.
  browser_units=$((browser_units + 1))
  # shellcheck disable=SC2016 # the inner sh expands $1, not this shell
  systemd-run --user --wait --quiet --collect \
    --unit="pim-sync-consent-browser-$$-$browser_units" \
    sh -c 'xdg-open "$(cat "$1")"' _ "$url_file" > /dev/null 2>&1
}

consent() {
  local name=$1 grant=$2 calendar=() token key email url log pid waited rc
  if [ "$grant" = calendar ]; then
    calendar=(--calendar)
    token="$name-calendar.json"
  else
    token="$name.json"
  fi
  key=${token_key[$token]}
  email=${account_email[$name]}
  log=$work/auth-$token.log

  rm -f -- "$work/tokens/$token"
  "$pim_sync_bin" auth --account "$name" "${calendar[@]}" \
    --secret "$work/client.json" --tokens-dir "$work/tokens" > "$log" 2>&1 &
  pid=$!
  url=
  for _ in $(seq 1 150); do
    url=$(grep -m1 -o 'https://accounts\.google\.com/[^[:space:]]*' "$log" || true)
    [ -n "$url" ] && break
    kill -0 "$pid" 2> /dev/null || break
    sleep 0.2
  done
  auth_pid=$pid
  if [ -z "$url" ]; then
    wait "$pid" 2> /dev/null || true
    sed -n '1,40p' "$log" >&2
    die "pim-sync auth printed no consent URL for $name ($grant)"
  fi

  printf 'pim-sync-consent: %s (%s grant): consent as %s\n' "$name" "$grant" "$email"
  printf '%s\n' "$url" > "$work/url.txt"
  if $no_browser; then
    echo "  open in a browser on this host: $url"
  elif ! open_url "$work/url.txt"; then
    echo "  could not open a browser from this shell — open this URL yourself: $url"
  fi

  waited=0
  while [ ! -s "$work/tokens/$token" ]; do
    if ! kill -0 "$pid" 2> /dev/null; then
      wait "$pid" 2> /dev/null || rc=$?
      sed -n '1,40p' "$log" >&2
      die "consent for $name ($grant) ended without a token (rc=${rc:-0})"
    fi
    if [ "$waited" -ge "$consent_timeout" ]; then
      kill "$pid" 2> /dev/null || true
      die "consent for $name ($grant) timed out after ${consent_timeout}s"
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid" || die "pim-sync auth failed for $name ($grant) after saving the token"
  auth_pid=
  jq -e '.refresh_token != null' "$work/tokens/$token" > /dev/null || die "$token has no refresh_token"
  ingest_json "$key" "$work/tokens/$token"
}

cd "$(dirname "$0")/.." || exit 1

if [ -z "$pim_sync_bin" ]; then
  pim_sync_bin=$(nix build --no-link --print-out-paths --impure --expr \
    '(builtins.getFlake (toString ./.)).inputs.pim-sync.packages.x86_64-linux.default')/bin/pim-sync \
    || die "cannot resolve the pim-sync package from the flake input"
fi
[ -x "$pim_sync_bin" ] || die "pim-sync binary is not executable: $pim_sync_bin"

if [ -n "$client_json" ]; then
  jq -e '(.installed.client_id | type == "string" and length > 0) and (.installed.client_secret | type == "string" and length > 0)' \
    "$client_json" > /dev/null \
    || die "$client_json is not a GCP Desktop client JSON (.installed.client_id / .client_secret missing): download the Desktop-app client, not a Web one"
  need_sops
  ingest_json pim_sync_oauth_client_secret "$client_json"
fi

if [ -n "$secret_file" ]; then
  cp "$secret_file" "$work/client.json"
else
  need_sops
  sops -d --output-type json "$sops_file" | jq -j '.pim_sync_oauth_client_secret' > "$work/client.json"
fi
chmod 600 "$work/client.json"
jq -e '.installed.client_id != null' "$work/client.json" > /dev/null \
  || die "the client secret is still a placeholder: run again with --client-json <downloaded Desktop client JSON>"

for name in "${accounts[@]}"; do
  consent "$name" contacts
  consent "$name" calendar
done

echo "pim-sync-consent: done. Next: deploy, then review the first dry-run in the journal (docs/services/pim-sync.md)."
