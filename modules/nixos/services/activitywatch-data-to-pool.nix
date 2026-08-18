# One-time data migration: ActivityWatch data → mirrored HDD pool (/mnt/pool)
#
# Moves /home/lars/.local/share/activitywatch → /mnt/pool/services/activitywatch
# (live subvol, btrbk-pool snapshotted) and replaces the source with a symlink.
#
# Context (2026-08-18): aw-watcher-utilization polled every 5s with ~7.5KB
# payloads and grew sqlite.db to 13GB, causing repeated global-OOM kills of
# aw-server (3.2GB RSS during bucket scans). The history was decimated to
# hourly samples and poll_time raised to 300s (platforms/common/programs/
# activitywatch.nix) BEFORE this migration, so the moved tree is ~300MB
# (compact DB + offline queue), not 13GB. The raw 13GB pre-surgery backup
# lives outside this tree in ~/backups and is NOT migrated.
#
# Why a systemd unit instead of a manual root shell: agent sessions have no
# sudo access. deploy.sh starts this unit post-switch (--no-block) so the
# migration runs with deploy-time privileges (same model as
# data-to-pool-migration.nix). Idempotent and ConditionPathIsDirectory-gated:
# once the source is a symlink (or absent) the unit skips instantly on every
# later deploy/boot.
#
# The user activitywatch.target is stopped for a consistent SQLite copy (a
# live rsync of a DB under writes is not a valid snapshot) and restarted from
# the new location afterwards. Root reaches the user manager via the uid-1000
# runtime dir — evo-x2 is a single-user machine (lars = uid 1000).
#
# Safety model (house pattern): rsync -aHAX → checksum dry-run must report
# ZERO differences → chown/chmod --reference → only then rm -rf the source.
# rm (not trash) is deliberate: the tree is checksum-verified on the pool and
# snapshotted by btrbk-pool; trashing would copy it back onto the NVMe home
# partition this migration exists to free.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.activitywatch-data-to-pool;
  inherit (import ../../../lib/default.nix lib)
    harden
    serviceOneshotDefaults
    onFailure
    ioTier
    ;
in
{
  options.services.activitywatch-data-to-pool = {
    enable = lib.mkEnableOption "one-time ActivityWatch data → HDD pool migration with symlink cutover";
  };

  config = lib.mkIf cfg.enable {
    systemd.services.activitywatch-data-to-pool = {
      description = "One-time migration: ~/.local/share/activitywatch → /mnt/pool/services/activitywatch";
      unitConfig = {
        # Runs while the source is a REAL directory; skips once the symlink
        # cutover is done (ConditionPathIsDirectory is false for symlinks)
        # and on fresh installs before ActivityWatch ever created its dir.
        ConditionPathIsDirectory = "/home/lars/.local/share/activitywatch";
        RequiresMountsFor = [ "/mnt/pool" ];
      };
      inherit onFailure;
      startLimitBurst = 5;
      startLimitIntervalSec = 300;
      path = with pkgs; [
        rsync
        btrfs-progs
        coreutils
      ];
      serviceConfig = lib.mkMerge [
        {
          Type = "oneshot";
          User = "root";
          # HDD-pool copy + full checksum verify; generously above the copy's
          # real size to survive a slow pool under other IO.
          TimeoutStartSec = "10m";
        }
        (harden {
          # This unit's whole job is moving /home/lars data: ProtectHome would
          # fight ReadWritePaths on modern systemd via bind-mount precedence,
          # but the honest declaration is "this unit touches home".
          ProtectHome = false;
          MemoryMax = "512M";
          # btrfs subvolume create needs CAP_SYS_ADMIN; rsync -a preserving
          # lars:users owners and the final rm -rf need CAP_CHOWN/CAP_FOWNER/
          # CAP_DAC_OVERRIDE (same capability set as data-to-pool-migration).
          CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH";
          ReadWritePaths = [
            "/home/lars/.local/share"
            "/mnt/pool"
            "/run/user/1000"
          ];
        })
        (serviceOneshotDefaults { })
        ioTier.background
      ];
      script = ''
        # NOTE: NixOS PREPENDS `set -e` to unit scripts — every fallible
        # statement outside an if-condition is explicitly guarded; failures
        # keep the source intact (house pattern).
        set -u
        failures=0

        src="/home/lars/.local/share/activitywatch"
        dest="/mnt/pool/services/activitywatch"

        user_systemd() {
          XDG_RUNTIME_DIR=/run/user/1000 systemctl --user "$@"
        }

        if ! user_systemd stop activitywatch.target; then
          echo "activitywatch-data-to-pool: USER UNIT STOP FAILED — is the user manager running? (source kept)"
          failures=1
        fi

        if btrfs subvolume show "$dest" >/dev/null 2>&1; then
          echo "activitywatch-data-to-pool: subvolume already exists: $dest"
        elif btrfs subvolume create "$dest"; then
          echo "activitywatch-data-to-pool: created subvolume $dest"
        else
          echo "activitywatch-data-to-pool: SUBVOLUME CREATE FAILED: $dest — skipping migrate"
          failures=1
        fi

        if btrfs subvolume show "$dest" >/dev/null 2>&1 && [ "$failures" -eq 0 ]; then
          echo "activitywatch-data-to-pool: copying $src → $dest"
          if ! rsync -aHAX --info=stats1,progress2 "$src"/ "$dest"/; then
            echo "activitywatch-data-to-pool: COPY FAILED (source kept)"
            failures=1
          else
            diff=""
            if ! diff=$(rsync -aHAXn -c -i "$src"/ "$dest"/) || [ -n "$diff" ]; then
              echo "activitywatch-data-to-pool: VERIFY FAILED — differences remain (source kept):"
              printf '%s\n' "$diff" | head -20
              failures=1
            elif ! chown --reference="$src" "$dest" || ! chmod --reference="$src" "$dest"; then
              echo "activitywatch-data-to-pool: OWNER SYNC FAILED: $dest (source kept)"
              failures=1
            elif ! rm -rf -- "$src"; then
              echo "activitywatch-data-to-pool: SOURCE REMOVAL FAILED (data is safe on the pool; cutover manually)"
              failures=1
            elif ! ln -s "$dest" "$src"; then
              echo "activitywatch-data-to-pool: SYMLINK CREATE FAILED — run: ln -s $dest $src"
              failures=1
            else
              echo "activitywatch-data-to-pool: verified identical, source cut over to symlink: $src → $dest"
            fi
          fi
        fi

        if [ -L "$src" ]; then
          if ! user_systemd start activitywatch.target; then
            echo "activitywatch-data-to-pool: USER UNIT START FAILED — start activitywatch.target manually"
            failures=1
          else
            echo "activitywatch-data-to-pool: activitywatch.target restarted from pool location"
          fi
        elif user_systemd stop activitywatch.target >/dev/null 2>&1; then
          user_systemd start activitywatch.target || true
        fi

        if [ "$failures" -ne 0 ]; then
          echo "activitywatch-data-to-pool: FAILED — migration incomplete; source kept where verified"
          exit 1
        fi
        echo "activitywatch-data-to-pool: complete — data lives on the pool, symlink in place, services running"
      '';
    };
  };
}
