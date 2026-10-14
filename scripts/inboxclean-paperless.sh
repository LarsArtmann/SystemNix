#!/usr/bin/env bash
# Run `inboxclean paperless …` under the DEPLOYED inboxclean-sync unit's
# environment. A bare interactive `inboxclean paperless` cannot see the
# Paperless integration (PAPERLESS_TOKEN lives in the sops-rendered env
# file that only the unit reads as PID 1) and dies with
# paperless.not_configured — this runner reconstructs exactly the env the
# unit gets, so CLI repairs (--backfill --prune, --decrypt-repair, --full)
# operate on the same state dir, accounts TOML, and secret as the service.
#
# Run (self-elevates to root; every target below is root-only):
#   sudo scripts/inboxclean-paperless.sh --full
#   sudo scripts/inboxclean-paperless.sh --backfill --prune --dry-run   # preview
# All arguments pass through verbatim to `inboxclean paperless`.
#
# Env reconstruction per docs/services/paperless.md (gate-tested 2026-09-12):
# INBOXCLEAN_CONFIG (extra-accounts TOML — without it work-account ledger
# rows resolve no source email), LLM_PROVIDER (the CLI config gate rejects
# before dispatch without it), GMAIL_CREDENTIALS_FILE/GMAIL_TOKEN_FILE
# (main-account client), DB_PATH, PATH (carries qpdf), PAPERLESS_URL/TAGS
# from the unit file; PAPERLESS_TOKEN + PAPERLESS_DECRYPT_PASSWORD from the
# rendered sops file.
#
# Secret hygiene: the token is pulled by command substitution INSIDE this
# root process — script text, terminal scrollback, and shell history only
# ever carry file PATHS, never values (the 2026-08-18 fish_history rule).
set -euo pipefail

UNIT=/etc/systemd/system/inboxclean-sync.service
RENDERED=/run/secrets/rendered/inboxclean-paperless-env
BIN=/run/current-system/sw/bin/inboxclean

# Re-exec once through sudo (boot-mirror-activate pattern: pass PATH
# explicitly so it survives sudo's secure_path).
if [ "$(id -u)" -ne 0 ]; then
  SUDO=/run/wrappers/bin/sudo
  [ -x "$SUDO" ] || SUDO="$(command -v sudo || true)"
  if [ -z "$SUDO" ]; then
    echo "✗ this runner needs root (unit env + sops-rendered secrets) and no sudo was found"
    exit 1
  fi
  exec "$SUDO" env PATH="$PATH" bash "$0" "$@"
fi

for required in "$UNIT" "$RENDERED" "$BIN"; do
  if [ ! -e "$required" ]; then
    echo "✗ missing $required"
    echo "  is the inboxclean paperless integration deployed (services.inboxclean.paperless.enable + sops inboxclean-paperless.yaml)?"
    exit 1
  fi
done

# VAR=VALUE words from the deployed unit file, flattened to one line so the
# array read below splits them cleanly.
UNIT_ENV="$(grep -oP '(GMAIL_CREDENTIALS_FILE|GMAIL_TOKEN_FILE|INBOXCLEAN_CONFIG|DB_PATH|LLM_PROVIDER|PAPERLESS_URL|PAPERLESS_TAGS)=\S+' "$UNIT" | tr '\n' ' ' | sed 's/ $//')"
if [ -z "$UNIT_ENV" ]; then
  echo "✗ extracted no known environment from $UNIT"
  echo "  the unit file shape changed — re-derive this script from docs/services/paperless.md"
  exit 1
fi

UNIT_PATH="$(grep -oP '^Environment="PATH=\K[^"]+' "$UNIT")"
if [ -z "$UNIT_PATH" ]; then
  echo "✗ found no Environment=\"PATH=…\" line in $UNIT"
  echo "  the unit no longer carries qpdf on PATH — re-derive this script from docs/services/paperless.md"
  exit 1
fi

PAPERLESS_TOKEN="$(sed -n 's/^PAPERLESS_TOKEN=//p' "$RENDERED")"
if [ -z "$PAPERLESS_TOKEN" ]; then
  echo "✗ no PAPERLESS_TOKEN in $RENDERED"
  echo "  check platforms/nixos/secrets/inboxclean-paperless.yaml (paperless_api_token) and redeploy"
  exit 1
fi
PAPERLESS_DECRYPT_PASSWORD="$(sed -n 's/^PAPERLESS_DECRYPT_PASSWORD=//p' "$RENDERED")"

read -r -a unit_env_args <<<"$UNIT_ENV"

exec sudo -u inboxclean env \
  "${unit_env_args[@]}" \
  PATH="$UNIT_PATH" \
  PAPERLESS_TOKEN="$PAPERLESS_TOKEN" \
  PAPERLESS_DECRYPT_PASSWORD="$PAPERLESS_DECRYPT_PASSWORD" \
  "$BIN" paperless "$@"
