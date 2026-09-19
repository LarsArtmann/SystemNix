# Browser History — module scripts factored out so flake checks can import
# them directly (the _forgejo-scripts.nix pattern; `_`-prefixed files are
# skipped by flake.nix module auto-discovery).
{
  pkgs,
}:
{
  # One-time probe-registration purge (see
  # services.browser-history.probeRegistrationCleanup in browser-history.nix
  # for the full rationale). Reads the target email as $1 and the server
  # StateDirectory from $STATE_DIRECTORY (the unit env; /var/lib/browser-history
  # fallback for manual runs). Idempotent: a marker file short-circuits every
  # run after the first success, and a failed purge stamps nothing so the next
  # start retries. Email-scoped on BOTH surfaces — never a blanket
  # UserRegistered delete: the events table is the sole journal, and future
  # registrations of other users must never be caught.
  probeRegistrationPurge = pkgs.writeShellApplication {
    name = "browser-history-probe-registration-purge";
    runtimeInputs = [
      pkgs.sqlite
      pkgs.coreutils
    ];
    text = ''
      email="''${1:-}"
      state_dir="''${STATE_DIRECTORY:-/var/lib/browser-history}"
      db="''${state_dir}/data.db"
      marker="''${state_dir}/.probe-registration-purged-$(printf '%s' "$email" | sha256sum | cut -c1-12)"

      if [ -z "$email" ]; then
        echo "browser-history-probe-registration-purge: no target email given" >&2
        exit 1
      fi
      if [ -f "$marker" ]; then
        exit 0
      fi
      if [ ! -f "$db" ]; then
        echo "browser-history-probe-registration-purge: no data.db yet, nothing to purge"
        exit 0
      fi
      case "$email" in
        *"'"*)
          echo "browser-history-probe-registration-purge: email contains a single quote, refusing" >&2
          exit 1
          ;;
      esac

      result="$(sqlite3 "$db" "
        PRAGMA busy_timeout = 5000;
        BEGIN IMMEDIATE;
        DELETE FROM events
          WHERE event_type = 'UserRegistered'
            AND json_extract(CAST(payload AS TEXT), '\$.email') = '$email';
        SELECT 'events_deleted=' || changes();
        DELETE FROM users_view WHERE email = '$email';
        SELECT 'users_view_deleted=' || changes();
        COMMIT;
      ")" || {
        echo "browser-history-probe-registration-purge: sqlite purge failed (retries next start)" >&2
        exit 1
      }
      printf '%s\n' "$result"
      touch "$marker"
      echo "browser-history-probe-registration-purge: purged probe registration for $email"
    '';
  };
}
