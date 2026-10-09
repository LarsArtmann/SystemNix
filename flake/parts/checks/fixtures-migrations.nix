# Behavioral fixtures for the hot-tier migration scripts + browser-history
# probe purge. Split out of flake.nix 2026-10-08.
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    {
      checks = {
        # Behavioral fixture for the browser-history probe-registration
        # purge (2026-09-18 gate-verification residue). Runs the REAL
        # built script (its runtimeInputs supply the real sqlite3) —
        # no stubs — against a scratch DB seeded with the true schemas:
        # events (go-cqrs-lite sqlite dialect) + users_view (cqrs-htmx
        # usermgmt AutoMapperWithTombstone). Covers: email-scoped delete
        # incl. BLOB payloads (the CAST path), decoy survival, marker
        # lifecycle (created on success only), idempotent re-run, the
        # missing-db clean-skip, and argv guards (empty email).
        # The unit WIRING (ExecStartPre entry + non-fatal "-" prefix,
        # without clobbering the OIDC gate's entry) is pinned by the
        # self-assertion inside browser-history.nix's purge block.
        browser-history-probe-purge-fixture =
          pkgs.runCommand "browser-history-probe-purge-fixture"
            {
              nativeBuildInputs = with pkgs; [
                sqlite
                coreutils
                gnugrep
              ];
              purgeBin =
                lib.getExe
                  (import (root + "/modules/nixos/services/_browser-history-scripts.nix") { inherit pkgs; })
                  .probeRegistrationPurge;
            }
            ''
              set -euo pipefail
              FIX=$(mktemp -d)
              STATE="$FIX/state"; mkdir -p "$STATE"
              DB="$STATE/data.db"
              PROBE='probe-gate@example.com'

              sqlite3 "$DB" "
              CREATE TABLE IF NOT EXISTS events (
                id TEXT PRIMARY KEY, event_type TEXT NOT NULL, aggregate_type TEXT NOT NULL,
                aggregate_id TEXT NOT NULL, version INTEGER NOT NULL,
                schema_version INTEGER NOT NULL DEFAULT 1, payload BLOB,
                payload_encoding TEXT NOT NULL DEFAULT 'json', metadata TEXT,
                occurred_at TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT (datetime('now')),
                UNIQUE(aggregate_type, aggregate_id, version));
              CREATE TABLE IF NOT EXISTS users_view (
                key TEXT PRIMARY KEY, email TEXT, display_name TEXT, email_verified INTEGER,
                totp_enabled INTEGER, created_at TEXT, updated_at TEXT, data TEXT, tombstoned INTEGER);
              "
              sqlite3 "$DB" "
              INSERT INTO events (id,event_type,aggregate_type,aggregate_id,version,payload,occurred_at) VALUES
               ('evt-probe','UserRegistered','User','u-probe',1,'{\"schema_version\":1,\"email\":\"probe-gate@example.com\",\"roles\":[]}','2026-09-18T03:00:00Z'),
               ('evt-probe-blob','UserRegistered','User','u-probe2',1,CAST('{\"email\":\"probe-gate@example.com\"}' AS BLOB),'2026-09-18T03:00:00Z'),
               ('evt-decoy','UserRegistered','User','u-decoy',1,'{\"email\":\"other@example.com\"}','2026-09-18T03:00:00Z'),
               ('evt-other','VisitSaved','Visit','v1',1,'{}','2026-09-18T03:00:00Z');
              INSERT INTO users_view (key,email,display_name,tombstoned) VALUES
               ('u-probe','probe-gate@example.com','Probe',0),
               ('u-decoy','other@example.com','Other',0);
              "

              run() { STATE_DIRECTORY="$1" "$purgeBin" "$PROBE" >"$FIX/out" 2>&1; }

              if STATE_DIRECTORY="$STATE" "$purgeBin" >/dev/null 2>&1; then
                echo 'FAIL: empty argv must be refused'; exit 1
              fi

              run "$STATE"
              grep -q 'events_deleted=2' "$FIX/out" || { echo 'FAIL: events_deleted != 2'; cat "$FIX/out"; exit 1; }
              grep -q 'users_view_deleted=1' "$FIX/out" || { echo 'FAIL: users_view_deleted != 1'; cat "$FIX/out"; exit 1; }
              c=$(sqlite3 "$DB" "SELECT count(*) FROM events WHERE event_type='UserRegistered';")
              [ "$c" = "1" ] || { echo "FAIL: decoy UserRegistered must survive, got $c"; exit 1; }
              c=$(sqlite3 "$DB" "SELECT count(*) FROM events WHERE event_type='UserRegistered' AND CAST(payload AS TEXT) LIKE '%probe-gate%';")
              [ "$c" = "0" ] || { echo 'FAIL: probe events remain'; exit 1; }
              c=$(sqlite3 "$DB" "SELECT count(*) FROM users_view;")
              [ "$c" = "1" ] || { echo 'FAIL: users_view decoy must survive'; exit 1; }
              c=$(sqlite3 "$DB" "SELECT count(*) FROM events;")
              [ "$c" = "2" ] || { echo 'FAIL: non-registration events must survive'; exit 1; }
              has_marker() { find "$1" -maxdepth 1 -name '.probe-registration-purged-*' -print -quit | grep -q .; }
              # NOTE: find, not a bare ls-glob — stdenv runs check
              # scripts with nullglob, so a non-matching marker glob
              # silently expands to nothing and `ls` lists the CWD
              # (the 2026-08-27 nullglob phantom-verdict class).
              has_marker "$STATE" || { echo 'FAIL: marker missing'; exit 1; }

              run "$STATE"
              c=$(sqlite3 "$DB" "SELECT count(*) FROM events;")
              [ "$c" = "2" ] || { echo 'FAIL: second run mutated state'; exit 1; }

              STATE3="$FIX/state3"; mkdir -p "$STATE3"
              run "$STATE3"
              has_marker "$STATE3" && { echo 'FAIL: marker without db'; exit 1; }

              STATE2="$FIX/state2"; mkdir -p "$STATE2"; echo notadb > "$STATE2/data.db"
              if run "$STATE2"; then echo 'FAIL: corrupt db must fail'; exit 1; fi
              has_marker "$STATE2" && { echo 'FAIL: marker on failure'; exit 1; }

              echo 'PASS: browser-history probe-purge fixture' > "$out"
            '';

        # migrate-hot-db.sh is the DESTRUCTIVE vehicle of the hot-DB
        # per-service waves (stops services, rsyncs dataDirs) — the
        # 2026-09-30 storage.md row demanded a stub-fixture test BEFORE
        # its first user window. PATH-injected stubs for btrfs/chattr/
        # systemctl/mountpoint/ionice/nice + real rsync against
        # scratch trees via the script's env overrides. Runs the REAL
        # committed script (pre-deploy-metrics-selftest staging shape).
        migrate-hot-db-fixture =
          pkgs.runCommand "migrate-hot-db-fixture"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils-full
                rsync
                gawk
                findutils
                gnugrep
                diffutils
                gnused
              ];
            }
            ''
              scratch=$(mktemp -d)
              mkdir -p "$scratch/scripts"
              cp ${root}/scripts/migrate-hot-db.sh "$scratch/scripts/migrate-hot-db.sh"
              cp ${root}/scripts/test-migrate-hot-db.sh "$scratch/scripts/test-migrate-hot-db.sh"
              bash "$scratch/scripts/test-migrate-hot-db.sh"
              touch $out
            '';

        # migrate-rust-cache.sh FORMATS the second SanDisk and moves the
        # live Rust caches off buildcache — its first live run
        # (2026-10-06) died at the mkfs call (missing -f) BEFORE any
        # destructive step; this fixture pins that fix and every
        # refusal gate so the ONE real sudo window executes a proven
        # script. SED-patched copy (scratch DEVICE/MOUNT/SOURCES,
        # SUDO="", user gate) + PATH stubs for lsblk/mkfs.btrfs/mount/
        # findmnt/mountpoint/chown; real rsync/find/df vs scratch trees.
        migrate-rust-cache-fixture =
          pkgs.runCommand "migrate-rust-cache-fixture"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils-full
                findutils
                gawk
                gnugrep
                gnused
                rsync
              ];
            }
            ''
              scratch=$(mktemp -d)
              mkdir -p "$scratch/scripts"
              cp ${root}/scripts/migrate-rust-cache.sh "$scratch/scripts/migrate-rust-cache.sh"
              cp ${root}/scripts/test-migrate-rust-cache.sh "$scratch/scripts/test-migrate-rust-cache.sh"
              bash "$scratch/scripts/test-migrate-rust-cache.sh"
              touch $out
            '';

        # migrate-caddy-logs-hot.sh did its live 2026-10-01→10-04
        # window with only shellcheck + dry-run coverage — every
        # FAILURE branch (verify-fail caddy restart, EXIT/INT traps,
        # refusal gates, the hardened finalize window checks, and the
        # destructive shadow-cleanup's detached-Samsung guard) was
        # never exercised for real. Same stub-fixture pattern as the
        # hot-db sibling: PATH stubs for the root-bound commands,
        # real rsync/find/tar, aux-mount faked by symlink.
        migrate-caddy-logs-fixture =
          pkgs.runCommand "migrate-caddy-logs-fixture"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils-full
                rsync
                gawk
                findutils
                gnugrep
                diffutils
                gnused
                gnutar
                zstd
              ];
            }
            ''
              scratch=$(mktemp -d)
              mkdir -p "$scratch/scripts"
              cp ${root}/scripts/migrate-caddy-logs-hot.sh "$scratch/scripts/migrate-caddy-logs-hot.sh"
              cp ${root}/scripts/test-migrate-caddy-logs-hot.sh "$scratch/scripts/test-migrate-caddy-logs-hot.sh"
              bash "$scratch/scripts/test-migrate-caddy-logs-hot.sh"
              touch $out
            '';

      };
    };
}
