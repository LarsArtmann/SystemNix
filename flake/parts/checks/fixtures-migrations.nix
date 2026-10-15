# Behavioral fixtures for the hot-tier migration scripts. Split out of
# flake.nix 2026-10-08.
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      checks = {
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

        # discordsync-attachments-migrate is the DESTRUCTIVE one-shot
        # (stop service → rsync ~40 GB → checksum verify → rm -rf source
        # → restart) that auto-starts no-block at the next deploy. The
        # unit script is EXTRACTED from the evaluated evo-x2 config
        # (systemd.services…script — the same rendered text the unit
        # runs), the baked absolute paths are sed-rewritten onto scratch
        # trees, and the root-bound commands are PATH-stubbed
        # (systemctl/chown; rsync/rm wrapped for failure injection)
        # while REAL rsync does the copy + dry-run checksum verify.
        # Covers: happy path, stop fail, copy fail, verify fail,
        # rm fail, restart fail, plus eval-side asserts on the
        # ConditionPathIsDirectory skip + RequiresMountsFor gating.
        discordsync-attachments-migrate-fixture =
          let
            sys = inputs.self.nixosConfigurations.evo-x2;
            migrateUnit = sys.config.systemd.services.discordsync-attachments-migrate;
            migrateScript = pkgs.writeText "discordsync-attachments-migrate.sh" migrateUnit.script;
          in
          pkgs.runCommand "discordsync-attachments-migrate-fixture"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils-full
                rsync
                gnugrep
                gnused
                diffutils
              ];
            }
            ''
              scratch=$(mktemp -d)
              cp ${root}/scripts/test-discordsync-attachments-migrate.sh "$scratch/test.sh"
              bash "$scratch/test.sh" ${migrateScript} \
                ${lib.escapeShellArg migrateUnit.unitConfig.ConditionPathIsDirectory} \
                ${lib.escapeShellArg (lib.concatStringsSep " " migrateUnit.unitConfig.RequiresMountsFor)}
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
