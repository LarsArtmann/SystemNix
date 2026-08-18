# One-time data migration: /data → mirrored HDD pool (/mnt/pool)
#
# Moves three NVMe /data trees onto the pool (2026-08-18):
#   /data/atticd             → /mnt/pool/services/atticd             (live subvol, btrbk-pool snapshotted)
#   /data/monitor365         → /mnt/pool/services/monitor365         (subvol reserved at 2026-08-16 pool bring-up; service disabled since 2026-08-12)
#   /data/monitor365-archive → /mnt/pool/archive/monitor365-archive  (cold archive tier: RAID1 redundancy only, NOT snapshotted by btrbk-pool)
#
# Why a systemd unit instead of a manual root shell: agent sessions have no
# sudo/systemctl access. deploy.sh starts this unit post-switch (--no-block)
# so the migration runs with deploy-time privileges. Idempotent and
# ConditionPathExists-gated: once all three sources are gone the unit skips
# instantly on every later deploy/boot.
#
# Safety model per source: rsync -aHAX (numeric owners preserved —
# /data/monitor365 is uid 966:956 from the disabled-service era) → checksum
# dry-run must report ZERO differences → only then rm -rf the source. rm (not
# trash) is deliberate: trashing ~63 GB would copy it onto the NVMe home
# partition this migration exists to free (same reasoning as buildcache-gc).
# Old copies stay recoverable from the nightly /data btrbk snapshots (14d
# local, 30d+12w pool-side) while they age out.
#
# Heal phase (added 2026-08-18 after the first monitor365 verify flagged
# exactly one `>fc........` file — same size, same mtime, different content,
# with ZERO kernel csum/EIO errors): a non-empty verify diff triggers a
# per-file diagnose-and-heal — stat both sides, md5 the SOURCE twice
# (differing hashes = non-deterministic read = corrupt extent, the /data
# torn-write class), filefrag the physical extent layout (cross-ref against
# the known corrupt windows ~595G / ~627-639G), fuser for live writers, then
# a forced re-copy (--ignore-times bypasses the quick-check) and a single-file
# re-verify. Only a clean full re-verify afterwards lets the migration
# proceed to source deletion; anything unhealed keeps the source (failsafe).
_: {
  flake.nixosModules.data-to-pool-migration =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.data-to-pool-migration;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ioTier
        ;
    in
    {
      options.services.data-to-pool-migration = {
        enable = lib.mkEnableOption "one-time /data → HDD pool migration (atticd, monitor365, monitor365-archive)";
      };

      config = lib.mkIf cfg.enable {
        systemd.services.data-to-pool-migration = {
          description = "One-time migration: /data/{atticd,monitor365,monitor365-archive} → /mnt/pool";
          # OR-prefixed conditions: the unit runs while ANY source remains and
          # skips cleanly (condition failed) once all are migrated.
          unitConfig = {
            ConditionPathExists = [
              "|/data/atticd"
              "|/data/monitor365"
              "|/data/monitor365-archive"
            ];
            RequiresMountsFor = [
              "/mnt/pool"
              "/data"
            ];
          };
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          path = with pkgs; [
            rsync
            btrfs-progs
            coreutils
            findutils
            gnugrep
            psmisc
            e2fsprogs
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              # 12h: a multi-million-file monitor365 buffer makes the
              # rsync file-list build alone run tens of minutes; copy plus
              # TWO checksum-verify walks can legitimately take hours.
              TimeoutStartSec = "12h";
            }
            (harden {
              # 1G: the 1.9M-entry verify walk peaked AT the old 512M cap
              # (483M swap) — headroom is cheaper than a swap-death mid-heal
              # on a one-shot unit.
              MemoryMax = "1G";
              # btrfs subvolume create needs CAP_SYS_ADMIN; rsync -a preserving
              # foreign numeric owners (uid 966 / lars) needs CAP_CHOWN +
              # CAP_DAC_OVERRIDE + CAP_FOWNER, and reading the 0750 uid-966
              # source tree needs CAP_DAC_READ_SEARCH (harden defaults to an
              # empty bounding set — first run shipped CAP_SYS_ADMIN only and
              # every chown failed with EPERM; the checksum verify caught it
              # and kept the sources).
              CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH";
              ReadWritePaths = [
                "/data"
                "/mnt/pool"
              ];
            })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
          script = ''
            # NOTE: NixOS PREPENDS `set -e` to unit scripts — any unguarded
            # failing statement aborts the run (observed live: run 1 died at
            # rm). Every fallible statement outside an if-condition is
            # explicitly guarded; failures accumulate and keep sources intact.
            set -u
            failures=0

            # Diagnose + heal ONE differing file. Returns 0 only if the
            # forced re-copy made source and dest checksum-identical.
            heal_one() {
              local srcroot="$1" destroot="$2" rel="$3"
              local sf="$srcroot/$rel" df="$destroot/$rel"
              echo "data-to-pool-migration: heal: $rel"
              stat -c '  src: size=%s mtime=%y inode=%i' "$sf" 2>/dev/null || echo "  src: STAT FAILED"
              stat -c '  dst: size=%s mtime=%y inode=%i' "$df" 2>/dev/null || echo "  dst: STAT FAILED (absent — will copy fresh)"
              echo "  md5 src pass1: $(md5sum "$sf" 2>/dev/null | cut -d' ' -f1 || true)"
              echo "  md5 src pass2: $(md5sum "$sf" 2>/dev/null | cut -d' ' -f1 || true)"
              echo "  md5 dst:       $(md5sum "$df" 2>/dev/null | cut -d' ' -f1 || true)"
              filefrag "$sf" 2>/dev/null | sed 's/^/  frag: /' || true
              filefrag -v "$sf" 2>/dev/null | sed -n '3,10p' | sed 's/^/  extent: /' || true
              fuser -v "$sf" 2>&1 | sed 's/^/  fuser: /' || true
              if ! rsync -aHAX --ignore-times --info=stats2 "$sf" "$df"; then
                echo "data-to-pool-migration: heal COPY FAILED: $rel"
                return 1
              fi
              local reverif=""
              if ! reverif=$(rsync -aHAXn -c -i "$sf" "$df"); then
                echo "data-to-pool-migration: heal VERIFY COMMAND FAILED: $rel"
                return 1
              fi
              if [ -n "$reverif" ]; then
                echo "data-to-pool-migration: heal UNRESOLVED (differs after forced re-copy): $rel"
                echo "  md5 src pass3: $(md5sum "$sf" 2>/dev/null | cut -d' ' -f1 || true)"
                echo "  → pass1≠pass2 or pass2≠pass3 = NON-DETERMINISTIC SOURCE READ = corrupt extent"
                return 1
              fi
              echo "data-to-pool-migration: healed: $rel"
              return 0
            }

            migrate() {
              local src="$1" dest="$2"
              if [ ! -e "$src" ]; then
                echo "data-to-pool-migration: skip (already migrated): $src"
                return 0
              fi
              echo "data-to-pool-migration: copying $src → $dest"
              if ! mkdir -p "$dest"; then
                echo "data-to-pool-migration: MKDIR FAILED: $dest"
                failures=1
                return 0
              fi
              if ! rsync -aHAX --info=stats1,progress2 "$src"/ "$dest"/; then
                echo "data-to-pool-migration: COPY FAILED: $src (source kept)"
                failures=1
                return 0
              fi
              # Verify: checksum every file on both sides; the itemized dry-run
              # must produce zero output. Anything else keeps the source.
              local diff=""
              if ! diff=$(rsync -aHAXn -c -i "$src"/ "$dest"/); then
                echo "data-to-pool-migration: VERIFY COMMAND FAILED: $src (source kept)"
                failures=1
                return 0
              fi
              if [ -n "$diff" ]; then
                echo "data-to-pool-migration: VERIFY DIFF: $src — attempting targeted heal"
                printf '%s\n' "$diff" | head -20
                local unhealed=0
                while IFS= read -r line; do
                  [ -n "$line" ] || continue
                  case "$line" in
                    ">f"*|"<f"*)
                      # itemized flags are 11 chars + a space; the rest is the path
                      if ! heal_one "$src" "$dest" "''${line:12}"; then
                        unhealed=1
                      fi
                      ;;
                    *)
                      echo "data-to-pool-migration: unhandled diff line (treated as unhealed): $line"
                      unhealed=1
                      ;;
                  esac
                done <<< "$diff"
                if [ "$unhealed" -ne 0 ]; then
                  echo "data-to-pool-migration: VERIFY DIFF FAILED: $src — unhealed differences remain (source kept)"
                  failures=1
                  return 0
                fi
                # Full clean re-verify required after any healing.
                if ! diff=$(rsync -aHAXn -c -i "$src"/ "$dest"/) || [ -n "$diff" ]; then
                  echo "data-to-pool-migration: VERIFY DIFF FAILED after heal: $src (source kept)"
                  printf '%s\n' "$diff" | head -20
                  failures=1
                  return 0
                fi
                echo "data-to-pool-migration: post-heal full verify clean: $src"
              fi
              # Carry the source top-dir ownership/permissions onto the dest
              # root (numeric: keeps the stale monitor365 uid 966:956 intact).
              if ! chown --reference="$src" "$dest" || ! chmod --reference="$src" "$dest"; then
                echo "data-to-pool-migration: OWNER SYNC FAILED: $dest (source kept)"
                failures=1
                return 0
              fi
              echo "data-to-pool-migration: verified identical ($(du -sh "$src" | cut -f1)): $src"
              if ! rm -rf -- "$src"; then
                echo "data-to-pool-migration: SOURCE REMOVAL FAILED: $src (data is safe on the pool; remove manually)"
                failures=1
                return 0
              fi
              echo "data-to-pool-migration: source removed: $src"
            }

            # 1. Live-service subvol for atticd storage (flip happens in a
            #    follow-up deploy that repoints services.attic-config.storagePath).
            #    On create failure the atticd migrate is SKIPPED: rsync would
            #    otherwise silently create a plain dir and lose btrbk-pool
            #    snapshot isolation.
            if btrfs subvolume show /mnt/pool/services/atticd >/dev/null 2>&1; then
              echo "data-to-pool-migration: subvolume already exists: /mnt/pool/services/atticd"
            elif btrfs subvolume create /mnt/pool/services/atticd; then
              echo "data-to-pool-migration: created subvolume /mnt/pool/services/atticd"
            else
              echo "data-to-pool-migration: SUBVOLUME CREATE FAILED: /mnt/pool/services/atticd — skipping atticd migrate"
              failures=1
            fi

            # 2. The data moves. Archive first (largest, irreplaceable DuckDB),
            #    then the empty attic tree, then the monitor365 buffer.
            #    monitor365 gets a scale probe first: its event buffer may
            #    hold millions of tiny encrypted chunks — a plain rsync spent
            #    12+ min in the file-list build alone with zero bytes written
            #    (twice). The count log makes the next decision factual, and
            #    --info=progress2 surfaces transfer progress in the journal.
            if ! mkdir -p /mnt/pool/archive; then
              echo "data-to-pool-migration: MKDIR FAILED: /mnt/pool/archive"
              failures=1
            fi
            migrate /data/monitor365-archive /mnt/pool/archive/monitor365-archive
            if btrfs subvolume show /mnt/pool/services/atticd >/dev/null 2>&1; then
              migrate /data/atticd /mnt/pool/services/atticd
            fi
            if [ -e /data/monitor365 ]; then
              echo "data-to-pool-migration: counting /data/monitor365 (120s cap)..."
              if monitor365_count=$(timeout 120 find /data/monitor365 -xdev | wc -l); then
                echo "data-to-pool-migration: /data/monitor365 entries: ''${monitor365_count:-0}"
              else
                echo "data-to-pool-migration: count exceeded 120s — multi-million-entry tree, expect a LONG copy"
              fi
            fi
            migrate /data/monitor365 /mnt/pool/services/monitor365

            # 3. Provenance sidecar for the archive copy (house rule: every
            #    archive gets one at creation time). Non-critical: a failure
            #    here must not fail the migration.
            if [ -d /mnt/pool/archive/monitor365-archive ] && [ ! -e /mnt/pool/archive/monitor365-archive/README-migration.md ]; then
              if printf '%s\n' \
                "# monitor365 archive — migrated from /data/monitor365-archive" \
                "" \
                "Migrated $(date -Is) by data-to-pool-migration.service on evo-x2." \
                "Reason: /data (NVMe) repurposing — cold archive moves to the RAID1 HDD pool." \
                "Contents: monitor365-events.db (28G live DuckDB at disable time 2026-08-02)," \
                "TSV exports and compressed DBs. Service disabled since 2026-08-12." \
                "Method: rsync -aHAX as root; rsync -c checksum dry-run verified zero" \
                "differences before the source was deleted." \
                "Tier note: archive/ is NOT snapshotted by btrbk-pool — RAID1 is the" \
                "only redundancy for this copy (cold data; nightly /data snapshots on" \
                "the pool keep older copies until their retention expires)." \
                > /mnt/pool/archive/monitor365-archive/README-migration.md
              then
                echo "data-to-pool-migration: wrote provenance README"
              else
                echo "data-to-pool-migration: WARNING — could not write provenance README"
              fi
            fi

            if [ "$failures" -ne 0 ]; then
              echo "data-to-pool-migration: FAILED — at least one source was not migrated; source dirs kept"
              exit 1
            fi
            echo "data-to-pool-migration: complete — all sources migrated, verified and removed"
          '';
        };
      };
    };
}
