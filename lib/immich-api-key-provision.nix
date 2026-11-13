# Canonical root converger for Immich API keys.
#
# Immich is OIDC-only, so there is no API-level way to bootstrap a key. Its
# Postgres runs on this host with peer auth for the postgres OS user — a
# privilege root already holds — so the converger inserts a scoped key
# (api_key.key = raw sha256 of a random token) directly and renders the token
# to a 0400 file. Extracted 2026-11-13 from the discordsync-immich-key-
# provision pattern after the third copy appeared; this is the implementation
# new consumers declare through `services.immich.apiKeys.<name>`.
#
# Convergence states (per key):
#   file exists + hash in DB  -> no-op (idempotent)
#   file exists, row gone     -> re-insert from file plaintext (DB restore)
#   file missing              -> mint, insert, write file, restart consumers
#
# Rotation: rm the key file + restart the unit. A UI-side deletion is
# resurrected by the re-insert path BY DESIGN — rotate, don't revoke.
#
# keys: attrset name -> {
#   permissions  = [ "asset.read" ... ];  # Immich Permission enum strings
#   keyFile      = "/var/lib/.../x.env";  # rendered secret (0400)
#   owner        = "lars";
#   group        = "users";
#   url          = null | "http://127.0.0.1:2283";  # non-null => env format
#   restartUnits = [ "svc.service" ];     # try-restart after a FRESH mint only
# }
{ lib }:
{
  pkgs,
  config,
  unitName ? "immich-api-key-provision",
  keys,
}:
let
  # Shell-safe: Immich permissions are dotted identifiers with no quoting needs.
  permissionsSql =
    permissions:
    "ARRAY[" + lib.concatMapStringsSep "," (p: "'${p}'") permissions + "]::varchar[]";

  keyCall =
    name: spec:
    let
      url = spec.url or null;
      format = if url == null then "plain" else "env";
      restarts = lib.concatStringsSep " " (spec.restartUnits or [ ]);
    in
    ''provision "${name}" "${spec.keyFile}" "${spec.owner}" "${spec.group}" "${format}" "${if url == null then "" else url}" "${permissionsSql spec.permissions}" "${restarts}" || fail=1'';
in
pkgs.writeShellApplication {
  name = unitName;
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
    pkgs.openssl
    pkgs.util-linux
    pkgs.systemd
    # psql CLIENT from pkgs (not config.services.postgresql.package): that
    # option has no value when postgres is disabled, which would break eval on
    # immich-less hosts. Client/server skew is immaterial for one INSERT.
    pkgs.postgresql
  ];
  text = ''
    set -uo pipefail

    db="${config.services.immich.database.name or "immich"}"
    fail=0
    log() { echo "${unitName}: $*"; }
    psql() { runuser -u postgres -- psql -d "$db" -v ON_ERROR_STOP=1 "$@"; }

    # Schema guard (loud, not silent): the INSERT below is coupled to Immich's
    # api_key shape — `key` is BYTEA holding the raw sha256 digest of the
    # token (api_keys renamed api_key by StandardizeNames; verified live
    # against 3.3.3).
    key_type=$(psql -At -c "SELECT data_type FROM information_schema.columns WHERE table_name = 'api_key' AND column_name = 'key'") || {
      log "FAIL could not read the Immich api_key schema (is the immich DB up?)"
      exit 1
    }
    if [ "$key_type" != "bytea" ]; then
      log "FAIL api_key.key is '$key_type', expected bytea — Immich schema drifted past this converger"
      exit 1
    fi
    uid=$(psql -At -c "SELECT id FROM \"user\" WHERE \"isAdmin\" IS TRUE ORDER BY \"createdAt\" LIMIT 1" || true)
    if [ -z "$uid" ]; then
      log "FAIL no admin user in Immich DB"
      exit 1
    fi

    provision() {
      local name=$1 keyfile=$2 owner=$3 group=$4 format=$5 url=$6 perms=$7 restarts=$8
      local keyname="$name (nix-managed)"
      local token="" hex cnt rid tmp
      local -a units=()
      # shellcheck disable=SC2206 # deliberately split the unit list
      units=($restarts)

      if [ -r "$keyfile" ]; then
        if [ "$format" = "env" ]; then
          token=$(sed -n 's/^IMMICH_API_KEY=//p' "$keyfile" || true)
        else
          token=$(cat "$keyfile" || true)
        fi
      fi

      if [ -n "$token" ]; then
        hex=$(printf '%s' "$token" | openssl dgst -sha256 -hex | awk '{print $NF}')
        cnt=$(psql -At -c "SELECT count(*) FROM api_key WHERE key = decode('$hex', 'hex')") || return 1
        if [ "$cnt" -ge 1 ]; then
          log "converged ($name: key file + api_key row consistent)"
          return 0
        fi
        log "$name: key file present but row missing (DB restore?) — re-inserting from file plaintext"
        psql -c "INSERT INTO api_key (name, key, \"userId\", permissions) VALUES ('$keyname', decode('$hex', 'hex'), '$uid', $perms)" || return 1
        return 0
      fi

      token=$(openssl rand -base64 32 | tr -d '/+=')
      case "$token" in
        *[!A-Za-z0-9]*) log "FAIL $name: generated token contains unexpected characters"; return 1 ;;
      esac
      hex=$(printf '%s' "$token" | openssl dgst -sha256 -hex | awk '{print $NF}')

      # Drop stale rows of THIS key name (orphaned hashes from a deleted key
      # file can never re-validate; every other key is untouched).
      for rid in $(psql -At -c "SELECT id FROM api_key WHERE name = '$keyname'"); do
        psql -c "DELETE FROM api_key WHERE id = '$rid'" || return 1
      done
      psql -c "INSERT INTO api_key (name, key, \"userId\", permissions) VALUES ('$keyname', decode('$hex', 'hex'), '$uid', $perms)" || return 1

      mkdir -p "$(dirname "$keyfile")" || return 1
      tmp=$(mktemp "$(dirname "$keyfile")/.immich-api-key.XXXXXX") || return 1
      if [ "$format" = "env" ]; then
        printf 'IMMICH_URL=%s\nIMMICH_API_KEY=%s\n' "$url" "$token" > "$tmp"
      else
        printf '%s' "$token" > "$tmp"
      fi
      chown "$owner:$group" "$tmp" || return 1
      chmod 0400 "$tmp" || return 1
      mv -f "$tmp" "$keyfile" || return 1

      log "minted $name key ($keyname) + rendered $keyfile"
      if [ "''${#units[@]}" -gt 0 ]; then
        systemctl try-restart "''${units[@]}" || true
      fi
      return 0
    }

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList keyCall keys)}

    exit "$fail"
  '';
}
