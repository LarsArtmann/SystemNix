# Pool (HDD RAID1 on the DAS) USB replug self-heal — the /mnt/pool analogue of
# buildcache-usb-recovery.
#
# Why: the buildcache disk self-heals after a DAS unplug/replug (automount +
# device-bound + udev SYSTEMD_WANTS + recovery unit, live-verified), but the
# pool mount is a plain fstab entry with NO device-bound and NO automount: it
# persists across an unplug holding the OLD device major:minor while replugged
# members enumerate with NEW numbers. Until someone notices, /mnt/pool is a
# silent EIO mount and every pool service fails against it.
#
# Design (mirrors buildcache, with btrfs-RAID1-specific decisions):
#   - udev rule keyed to the TWO Toshiba ID_SERIALs (never sd-letters — the
#     2026-08-27 udev letter-collision class) starts the recovery unit on
#     whole-disk add (pool members have no partitions).
#   - Zero members present = the whole USB link is down: the "DAS USB link"
#     Gatus check owns that alert. This unit exits CLEANLY so a boot without
#     the DAS never pollutes systemctl --failed.
#   - Any member present but the pool refusing to mount (partial
#     re-enumeration) FAILS LOUDLY: a degraded mount is a user decision,
#     never automated (recorded doctrine, 2026-08-22).
#   - Zombie reaper compares the mount's major:minor against the CURRENT
#     members (the `[ -b $src ]` test used for buildcache cannot see the
#     renumbered-device case: /dev/sda exists again after replug, just with
#     a new devt).
#   - Plain `mount /mnt/pool` via fstab (by-label) — full membership only.
#   - REAL I/O verification (timeout ls -A), never mount-table presence
#     (phantom-green lesson, 2026-08-16 twice).
#   - Restart pool consumers that FAILED during the outage (is-failed gated:
#     never touches intentionally-disabled or healthy units; enabled units
#     that merely stopped are left to their normal wants/deps).
#   - Deliberately NOT harden {} — PrivateTmp/ProtectSystem create a slave
#     mount namespace in which umount(2) cannot touch the HOST mount table;
#     the reaper would silently no-op (buildcache lesson). Only non-namespace
#     directives below.
#   - Every unit lists EVERY binary it execs in `path` (exit-127 class:
#     fa9e56b7 balance guards died a week on missing awk).
{
  flake.nixosModules.pool-recovery =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ;

      cfg = config.services.pool-recovery;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      stateDir = "/var/lib/pool-recovery";

      # ID_SERIAL of each member, parsed from the by-id device path
      # ("ata-<model>_<serial>"). Whole disks — no -partN suffix.
      memberSerials = map (
        m:
        let
          m' = builtins.match "(ata|scsi|usb)-(.+)" (baseNameOf m);
        in
        if m' == null then throw "pool-recovery: member '${m}' is not an ata/scsi/usb by-id path" else builtins.elemAt m' 1
      ) cfg.members;
    in
    {
      options.services.pool-recovery = {
        enable = lib.mkEnableOption "DAS pool (/mnt/pool) USB replug self-heal: zombie reaper + remount + failed-service restart + real-IO metrics";

        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/pool";
          description = "Mount point of the pool btrfs filesystem (must exist in /etc/fstab; this module never defines the mount itself).";
        };

        members = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/dev/disk/by-id/ata-TOSHIBA_MG08ACA16TE_72U0A005FWTG"
            "/dev/disk/by-id/ata-TOSHIBA_MG08ACA16TE_72U0A0ZUFWTG"
          ];
          description = ''
            by-id paths of the btrfs RAID1 members. by-id (ata- serial form) is
            stable across sd-letter swaps between replugs; the kernel creates
            it via SAT passthrough even though the USB bridge hides the model
            at the plain SCSI layer.
          '';
        };

        restartUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "atticd.service"
            "atticd-bootstrap.service"
            "immich-server.service"
            "paperless-web.service"
            "paperless-consumer.service"
            "paperless-task-queue.service"
            "paperless-scheduler.service"
            "bank-sync.service"
          ];
          description = ''
            Pool consumers to restart when they are in FAILED state after the
            pool comes back. is-failed gated on purpose: intentionally
            disabled services (monitor365, bank-sync when disabled) and units
            that are merely inactive are never touched — failed means "should
            have been running and died against the EIO mount".
          '';
        };

        settleTimeoutSeconds = lib.mkOption {
          type = lib.types.int;
          default = 90;
          description = "How long to wait for ALL members to appear after the first add event before acting (Toshibas spin up in seconds; 90s is generous).";
        };
      };

      config = lib.mkIf cfg.enable {
        # One rule per member serial, whole-disk add only (pool members are
        # unpartitioned). SYSTEMD_WANTS coalesces the two near-simultaneous
        # triggers into one unit job; the script also flocks for safety.
        services.udev.extraRules = lib.concatStringsSep "\n" (
          map (serial: ''
            ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="${serial}", ENV{SYSTEMD_WANTS}+="pool-usb-recovery.service"
          '') memberSerials
        );

        systemd.services.pool-usb-recovery = {
          description = "Recover pool mount after DAS replug (zombie reaper + remount + failed-service restart)";
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          path = [
            pkgs.util-linux
            pkgs.coreutils
            pkgs.btrfs-progs
            pkgs.systemd
          ];
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            CapabilityBoundingSet = "CAP_SYS_ADMIN";
            NoNewPrivileges = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            MemoryMax = "128M";
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
          };
          script =
            let
              membersStr = lib.concatStringsSep " " cfg.members;
              unitsStr = lib.concatStringsSep " " cfg.restartUnits;
            in
            ''
              set -eu
              mnt="${cfg.mountPoint}"

              # Two serials fire two add events — a second run must not race
              # the first (flock held fd, held-for-duration pattern).
              exec 9>/run/pool-usb-recovery.lock
              flock -n 9 || {
                echo "pool-usb-recovery: another run in flight — exiting"
                exit 0
              }

              # 1. Settle: wait for the members to appear (spin-up latency).
              members="${membersStr}"
              total=${toString (lib.length cfg.members)}
              present=0
              deadline=$(( $(date +%s) + ${toString cfg.settleTimeoutSeconds} ))
              while :; do
                present=0
                for dev in $members; do
                  if [ -b "$dev" ]; then present=$((present + 1)); fi
                done
                [ "$present" -eq "$total" ] && break
                [ "$(date +%s)" -ge "$deadline" ] && break
                sleep 2
              done
              echo "pool-usb-recovery: $present/$total member(s) present"

              # 2. Zero members = whole USB link down: the "DAS USB link"
              #    Gatus check owns that alert. Exit CLEANLY — a boot without
              #    the DAS must not fail this unit (systemctl --failed noise).
              if [ "$present" -eq 0 ]; then
                echo "pool-usb-recovery: no pool members — DAS link down (monitored by Gatus)"
                exit 0
              fi

              # 3. Register devices with the btrfs module (idempotent; udev's
              #    own btrfs rules usually did this already).
              btrfs device scan --all-devices >/dev/null 2>&1 || true

              # 4. Zombie reaper: a persisted mount holds the OLD major:minor
              #    while replugged members enumerate with NEW numbers. Compare
              #    the mount's devt against every CURRENT member; no match =
              #    stale. ([ -b $src ] alone cannot see this: /dev/sda exists
              #    again after replug, just renumbered.)
              mounted_devt="$(findmnt -n -o MAJ:MIN -- "$mnt" 2>/dev/null || true)"
              if [ -n "$mounted_devt" ]; then
                match=0
                for dev in $members; do
                  if [ -b "$dev" ]; then
                    devt="$(lsblk -nrno MAJ:MIN "$dev")"
                    if [ "$devt" = "$mounted_devt" ]; then match=1; fi
                  fi
                done
                if [ "$match" -eq 1 ]; then
                  # Live member, but is it serving REAL I/O?
                  if timeout 20 ls -A "$mnt" >/dev/null 2>&1; then
                    echo "pool-usb-recovery: mount healthy ($mnt) — no action"
                    systemctl start pool-recovery-metrics.service 2>/dev/null || true
                    exit 0
                  fi
                  echo "pool-usb-recovery: mount devt matches a member but I/O fails — remounting" >&2
                else
                  echo "pool-usb-recovery: reaping stale pool mount (devt $mounted_devt matches no current member)"
                fi
                systemctl stop mnt-pool.mount 2>/dev/null || true
                umount -l "$mnt" 2>/dev/null || true
              fi

              # 5. Mount via fstab (by-label). NEVER -o degraded: with a member
              #    missing, btrfs refuses and this unit fails LOUDLY — a
              #    degraded mount is a user decision (2026-08-22 doctrine).
              if ! findmnt -n -- "$mnt" >/dev/null 2>&1; then
                echo "pool-usb-recovery: mounting $mnt"
                mount "$mnt"
              fi

              # 6. REAL I/O proof, not mount-table presence.
              if ! timeout 20 ls -A "$mnt" >/dev/null 2>&1; then
                echo "pool-usb-recovery: pool still failing I/O after recovery attempt" >&2
                exit 1
              fi

              # 7. Record device error counters (alerts handled elsewhere; the
              #    5-min metrics collector surfaces them).
              btrfs device stats "$mnt" || true

              # 8. Restart pool consumers that FAILED against the dead mount.
              #    is-failed gated: disabled-but-present units and healthy ones
              #    are untouched.
              for unit in ${unitsStr}; do
                if systemctl is-failed --quiet "$unit" 2>/dev/null; then
                  echo "pool-usb-recovery: restarting failed pool service: $unit"
                  systemctl reset-failed "$unit" 2>/dev/null || true
                  systemctl start "$unit" 2>/dev/null || echo "pool-usb-recovery: start $unit failed (non-fatal)" >&2
                fi
              done

              # 9. Counters + immediate metrics refresh so Gatus flips now.
              mkdir -p "${stateDir}"
              n=$(cat "${stateDir}/recoveries" 2>/dev/null || echo 0)
              echo $((n + 1)) > "${stateDir}/recoveries"
              date +%s > "${stateDir}/last_recovery"
              systemctl start pool-recovery-metrics.service 2>/dev/null || true
              echo "pool-usb-recovery: recovered $(findmnt -n -o SOURCE -- "$mnt")"
            '';
        };

        # Always writes the .prom — including when the pool is absent — so a
        # dead/unmounted pool flips pool_usb_recovery_mounted to 0 and Gatus
        # alerts instead of serving a stale green file (buildcache lesson).
        systemd.services.pool-recovery-metrics = {
          description = "Pool DAS Prometheus metrics (real-IO mount, members, device errors)";
          startLimitBurst = 3;
          startLimitIntervalSec = 300;
          inherit onFailure;
          path = [
            pkgs.util-linux
            pkgs.coreutils
            pkgs.btrfs-progs
            pkgs.gnugrep
            pkgs.gawk
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
            }
            (harden {
              ReadWritePaths = [ textfileDir ];
              CapabilityBoundingSet = "CAP_SYS_ADMIN";
              MemoryMax = "128M";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            OUT="${textfileDir}/pool-recovery.prom"
            TMP="''${OUT}.tmp"
            mnt="${cfg.mountPoint}"

            # Mount-table presence is not health: gate on real I/O.
            mounted=0
            if
              findmnt -n -o TARGET "$mnt" 2>/dev/null | grep -qx "$mnt" \
                && timeout 15 ls -A "$mnt" >/dev/null 2>&1
            then
              mounted=1
            fi

            members="${lib.concatStringsSep " " cfg.members}"
            members_present=0
            for dev in $members; do
              if [ -b "$dev" ]; then members_present=$((members_present + 1)); fi
            done

            # Sum all *_errs counters across devices (0 when unmounted — the
            # error state that matters is unmountable-pool, already flagged by
            # mounted=0).
            device_errors=0
            if [ "$mounted" = 1 ]; then
              device_errors="$(btrfs device stats "$mnt" 2>/dev/null | awk '{s+=$2} END{print s+0}')"
            fi

            recoveries=$(cat "${stateDir}/recoveries" 2>/dev/null || echo 0)
            last_ts=$(cat "${stateDir}/last_recovery" 2>/dev/null || echo 0)

            mkdir -p "${textfileDir}"
            cat > "$TMP" <<METRICS
            # HELP pool_usb_recovery_mounted 1 if the pool is mounted AND answers real I/O
            # TYPE pool_usb_recovery_mounted gauge
            pool_usb_recovery_mounted ''${mounted}
            # HELP pool_usb_recovery_members_present Number of RAID1 member devices currently present
            # TYPE pool_usb_recovery_members_present gauge
            pool_usb_recovery_members_present ''${members_present}
            # HELP pool_usb_recovery_device_errors Sum of btrfs device stats error counters (0 when unmounted)
            # TYPE pool_usb_recovery_device_errors gauge
            pool_usb_recovery_device_errors ''${device_errors}
            # HELP pool_usb_recovery_recoveries_total Successful replug recoveries since provisioning
            # TYPE pool_usb_recovery_recoveries_total counter
            pool_usb_recovery_recoveries_total ''${recoveries}
            # HELP pool_usb_recovery_last_recovery_seconds Unix timestamp of the last successful recovery
            # TYPE pool_usb_recovery_last_recovery_seconds gauge
            pool_usb_recovery_last_recovery_seconds ''${last_ts}
            METRICS
            mv "$TMP" "$OUT"
          '';
        };

        systemd.timers.pool-recovery-metrics = {
          description = "Collect pool DAS metrics every 5 minutes";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "5min";
            Persistent = true;
          };
        };
      };
    };
}
