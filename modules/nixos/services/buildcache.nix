# Build cache SSD - SanDisk SDSSDA240G on USB 3.0 (SandForce SF-2000, DRAM-less).
#
# Purpose: keep rebuildable build caches (Go build/module cache, golangci-lint,
# goimports, Rust target dirs, npm/pnpm, pip, Playwright browsers) OFF the QLC
# NVMe. The NVMe's SLC cache exhaustion incidents (2026-08-12 WDT crashes, 93%
# disk crisis) were driven by exactly this ephemeral churn. Cache data is
# disposable: if the 10-year-old drive dies, everything rebuilds.

#
# Why ext4 + data=writeback: build caches are small-file, stat-heavy workloads
# where ext4 measured 2x lower random latency than btrfs on this drive (234us
# vs 503us). data=writeback removes the ordered-mode journal double-write
# (136 -> ~280 MB/s sequential). Corruption risk from writeback + no PLP +
# 34 dirty shutdowns is acceptable: every consumer verifies content hashes
# (go-build) or rebuilds on anomaly (cargo clean, pnpm store prune). See
# docs/status/2026-08-14_12-30_ssd-recovery-benchmarking-session.md for the
# benchmark and architecture analysis.
#
# TRIM does NOT pass through the USB bridge (lsblk -D reports DISC-MAX 0B).
# If write performance degrades over months from stale-block pressure, the fix
# is a reformat - the drive is a cache:
#   mkfs.ext4 -L buildcache /dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311-part1
#
# Migration of existing caches: `nix run .#migrate-buildcache` (run BEFORE the
# first deploy of this module - it creates dirs the deploy expects, and moves
# ~/.cache/goimports + ~/.cache/go aside so home-manager symlinks cleanly).
{
  flake.nixosModules.buildcache =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        mkFilesystem
        harden
        ioTier
        serviceOneshotDefaults
        onFailure
        ;

      # Env-less cache reap inventories — parsed from the single source
      # scripts/lib/buildcache-reap-names.sh (shared with deploy.sh and the
      # home.nix activation reap; never keep a private name copy here).
      reapNames = import ../../../lib/buildcache-cache-names.nix lib;
      cacheSsd = import ../../../lib/cache-ssd.nix lib;

      cfg = config.services.buildcache;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      primaryUser = config.users.primaryUser;
      homeDir = config.users.users.${primaryUser}.home;

      # Rust dirs (rust/, sccache/, cargo/, cargo/registry) were MOVED to the
      # dedicated Rust cache SSD on 2026-10-06 — see
      # modules/nixos/services/rust-cache.nix. This module now owns only the
      # Go / JS / Python build caches.
      buildcacheDirs = [
        "go-build"
        "go-mod"
        "golangci-lint"
        "goimports"
        "go"
        "npm"
        "pip"
        "pnpm-store"
        # 2026-09-22 fallback-symlink targets (home.nix HM outOfStoreSymlinks
        # for env-less pnpm): must be provisioned here so a post-recovery
        # init heals the dangling ~/.cache/pnpm and ~/.local/state/pnpm links
        # before the next HM deploy.
        "pnpm-cache"
        "pnpm-state"
        "playwright"
        # 2026-11-04: per-task agent caches (convention: per-task
        # GOCACHE/GOLANGCI_LINT_CACHE live under agent-caches/<task> — see
        # docs/agents/storage.md). Provisioned by init so the direnv guard's
        # redirects and the agent-cache-gc sweep always find the parent.
        "agent-caches"
      ];

      # ID_SERIAL of the cache SSD and the mountpoint's systemd unit name —
      # shared cache-SSD helpers (lib/cache-ssd.nix).
      deviceSerial = cacheSsd.deviceSerialFromDevice cfg.device;
      mountUnitName = cacheSsd.mountUnitNameFor cfg.mountPoint;

      # Eval-time converge-coverage guard (2026-11-03, gitea-runner class).
      # A recovery remount stops mnt-buildcache.mount, and RequiresMountsFor
      # implies Requires=, so every daemon gated on this mount is TERMed with
      # it. Nothing converged them back: the runner stayed dark from the
      # 21:11:01 deploy recovery until its own 5-min ensure timer fired 72s
      # later (the post-deploy smoke FAILed in that window). Same shape as
      # pool-recovery's coverage assertion (2026-10-04).
      # Bound = any unitConfig.RequiresMountsFor path on or under the mount
      # point (the exact mount and "/mnt/buildcache/x" both bind the mount).
      # Daemon = explicit non-"no" Restart; oneshots self-heal on their next
      # tick and must never be converged.
      buildcacheBoundDaemons = lib.filterAttrs (
        _: svc:
        let
          rmf = (svc.unitConfig or { }).RequiresMountsFor or null;
          paths = if lib.isList rmf then map toString rmf else lib.optionals (rmf != null) [ (toString rmf) ];
          bound = lib.any (p: p == cfg.mountPoint || lib.hasPrefix "${cfg.mountPoint}/" p) paths;
          restart = (svc.serviceConfig or { }).Restart or null;
        in
        bound && restart != null && restart != "no"
      ) config.systemd.services;

      unconvergedDaemons = lib.filter (
        unit: !lib.elem "${unit}.service" (cfg.recoveryRestartUnits ++ cfg.recoveryRestartUnitsExempt)
      ) (lib.attrNames buildcacheBoundDaemons);
    in
    {
      options.services.buildcache = {
        enable = lib.mkEnableOption "USB SSD build cache at /mnt/buildcache (keeps build caches off the QLC NVMe)";

        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/buildcache";
          description = "Mount point for the build cache ext4 filesystem.";
        };

        device = lib.mkOption {
          type = lib.types.str;
          default = "/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311-part1";
          description = ''
            Partition device. by-id (ata- serial form) is stable across sdb/sdc
            letter swaps between the two USB-attached SSDs; the kernel creates it
            via SAT passthrough even though the USB bridge hides the model at the
            plain SCSI layer.
          '';
        };

        wholeDiskDevice = lib.mkOption {
          type = lib.types.str;
          default = "/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311";
          description = "Whole-disk device for SMART queries (smartctl -d sat).";
        };

        usageThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 85;
          description = "Usage percentage at which the Gatus alert fires (240 GB drive; caches should be pruned before full).";
        };

        gc = {
          enable = lib.mkEnableOption "daily build cache garbage collection (npm/pnpm prune, high-watermark go clean)";

          highWatermarkPercent = lib.mkOption {
            type = lib.types.int;
            default = 90;
            description = ''
              If usage is at or above this percentage after the regular pruning
              steps, the nuclear option runs: go clean -cache. Rationale: Go's
              native 5-day LRU trim is defeated by gopls refreshing mtimes
              (markUsed), so an unbounded go-build is the one cache that CAN
              wedge the disk - a cold rebuild is always preferable to a full
              disk failing all builds.
            '';
          };

          calendar = lib.mkOption {
            type = lib.types.str;
            # 2026-10-20: weekly → daily. The mount went 75% → 100% (0 bytes
            # free) in ONE day between two Sunday runs — the watermark guard
            # only fires DURING a run, so a weekly cadence let the disk sit
            # wedged at 100% for up to six days, ENOSPC-ing every env-less Go
            # build (~/.cache/go-build converges here). Daily keeps the
            # "never wedge" promise; the prunes are cheap (npm verify + pnpm
            # prune ≈ 13 min) and go clean -cache still only fires at ≥90%.
            default = "*-*-* 05:00:00";
            description = "OnCalendar for the GC timer (default: daily 05:00 - after btrbk 23:00/23:30, idle I/O tier).";
          };
        };

        recoveryRestartUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Build-cache consumers to converge once the mount is proven healthy:
            FAILED units are restarted (died against the EIO mount) and units
            that are enabled but merely INACTIVE are started (the mount-stop
            dropout class: RequiresMountsFor turns a recovery remount into a
            stop of every bound daemon). Disabled/masked units are never
            touched; deliberately hand-stopped listed units come back on the
            next recovery run, which is intended because every entry here is an
            always-on daemon whose stop Gatus alerts on anyway.

            The healthy fast path also converges this list, so a deploy-time
            recovery run heals an externally stopped consumer instead of
            waiting for its own timer (2026-11-03: the gitea runner stayed dark
            for 72s after a deploy and the post-deploy smoke FAILed).

            NOTE: this list is NOT concat-merged, a second definition REPLACES
            it wholesale.
          '';
        };

        recoveryRestartUnitsExempt = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Build-cache-bound daemons deliberately NOT converged after a
            remount. The only escape hatch from the eval-time coverage
            assertion (config.assertions), so every entry needs a comment
            justifying why the unit self-heals (own timer, watchdog, etc.).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = unconvergedDaemons == [ ];
            message = ''
              buildcache: build-cache-bound daemon(s) missing from services.buildcache.recoveryRestartUnits — a recovery remount stops mnt-buildcache.mount, RequiresMountsFor propagates that stop to every bound daemon, and nothing brings them back (2026-11-03: the gitea runner died at a 21:11 deploy recovery and the post-deploy smoke FAILed). Add to recoveryRestartUnits, or recoveryRestartUnitsExempt with a reason: ${lib.concatStringsSep ", " unconvergedDaemons}
            '';
          }
        ];

        # nofail: a dead/absent USB drive must never block boot. automount: mount
        # on first access rather than at boot, tolerating late DAS power-up.
        # device-timeout bounds the wait if the enclosure is unplugged.
        # device-bound: the kernel mount table stores device NUMBERS
        # (major:minor), not paths - a USB reconnect mints a new number, the
        # by-id symlink cannot re-point the established mount, and a zombie
        # EIOs forever (2026-08-16, twice). device-bound makes systemd stop
        # the mount when the .device unit dies; the automount then re-resolves
        # the by-id path on next access and mounts the NEW device node.
        fileSystems.${cfg.mountPoint} = mkFilesystem {
          inherit (cfg) device;
          fsType = "ext4";
          # No boot fsck (2026-10-06): passno=2 (the NixOS default for
          # non-root fs) otherwise runs a full systemd-fsck@ on this
          # DRAM-less cache SSD whenever the automount is first pulled
          # (49.9s of boot-transaction IO storm, measured 2026-10-06) —
          # for a REBUILDABLE cache whose ext4 journal already replays
          # unclean shutdowns. The GC timer + SMART alerts own its health;
          # if corruption ever eats it, re-run the documented mkfs (line
          # 22) and let the caches rebuild.
          noCheck = true;
          options = [
            "noatime"
            "lazytime"
            "data=writeback"
            "commit=120"
            "nofail"
            "x-systemd.automount"
            # 2s (was 10s): a dead/flapping enclosure must not cost the full
            # timeout per mount lookup - every D-state probe stalls its caller
            # (login chain, units, scripts) and fakes IO PSI saturation
            # (2026-08-24 crash3: phantom PSI from automount waits). A healthy
            # enumerated device answers instantly; USB enumeration happens
            # before the automount trigger, not inside this window.
            "x-systemd.device-timeout=2s"
            "x-systemd.device-bound"
          ];
        };

        # The enclosure is a JMicron JMS567 (152d:0567) - a bridge notorious
        # for dropping off the bus under load (9 disconnects in 36 min,
        # 2026-08-16). Two rules make flaps self-healing instead of wedging:
        #  - power/control=on disables USB runtime autosuspend on the bridge
        #    (a known JMS567 disconnect trigger)
        #  - SYSTEMD_WANTS on partition add runs the recovery service the
        #    moment the SSD reappears, so the remount is immediate rather
        #    than waiting for the next build access or metrics poll.
        services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="152d", ATTR{idProduct}=="0567", TEST=="power/control", ATTR{power/control}="on"
          # Pin all USB host controllers awake: a runtime-suspended (D3cold)
          # controller on this platform raises no PME wake on hotplug, so
          # replug events are silently LOST - the host looks blind while the
          # device is healthy (2026-08-29 DAS recovery: all six USB/USB4
          # controllers sat suspended with control=auto). Covers xHCI
          # (0x0c0330) and USB4 (0x0c0340) class devices.
          ACTION=="add", SUBSYSTEM=="pci", ATTR{class}=="0x0c0330|0x0c0340", TEST=="power/control", ATTR{power/control}="on"
        ''
        + lib.optionalString (deviceSerial != null) ''
          ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_SERIAL}=="${deviceSerial}", ENV{SYSTEMD_WANTS}+="buildcache-usb-recovery.service"
        '';

        # Runs on EVERY boot, deliberately: mkdir/chown/chmod are idempotent,
        # and an init-once `.initialized` gate (removed 2026-08-15) made any
        # newly-added buildcacheDirs entry inert - the sccache dir had to be
        # provisioned by hand after the drive was already initialized.
        systemd.services.buildcache-init = {
          description = "Initialize build cache directories on the USB SSD";
          wantedBy = [ "multi-user.target" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          unitConfig = {
            # With x-systemd.automount the mount happens on first ACCESS;
            # RequiresMountsFor + ExecStart touching the path trigger it.
            RequiresMountsFor = cfg.mountPoint;
            # Guard against root-fs contamination: if the automount unit is dead
            # and the drive absent, mkdir would create dirs on the NVMe root.
            # While the automount is active the path IS a mountpoint (autofs),
            # and a blocked trigger fails the mkdir instead of falling through.
            ConditionPathIsMountPoint = cfg.mountPoint;
            # Skip cleanly when the USB SSD is unplugged: the armed autofs
            # mountpoint still satisfies ConditionPathIsMountPoint, but any
            # access EIOs (zombie) or blocks 10s then fails (device-timeout),
            # failing the unit and blocking deploy activation (exit code 4).
            # The udev recovery service runs init explicitly on replug.
            ConditionPathExists = cfg.device;
          };
          path = [
            pkgs.coreutils
            pkgs.util-linux
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
            }
            # Root oneshot doing ownership ops: overrides REPLACE harden's empty
            # default (which drops all capabilities). CAP_CHOWN for chown(2),
            # CAP_FOWNER/CAP_DAC_OVERRIDE for chmod/traversal on re-init.
            (harden {
              ReadWritePaths = [ cfg.mountPoint ];
              CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
              MemoryMax = "64M";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            for dir in ${lib.concatStringsSep " " buildcacheDirs}; do
              mkdir -p "${cfg.mountPoint}/$dir"
              chown ${primaryUser}:users "${cfg.mountPoint}/$dir"
              chmod 0755 "${cfg.mountPoint}/$dir"
            done
            echo "buildcache initialized at ${cfg.mountPoint}"
          '';
        };

        # Belt-and-braces for x-systemd.device-bound, triggered by udev when
        # the SSD partition reappears (and by deploy.sh after every switch):
        # reap any zombie mount left behind (e.g. busy writers forced systemd
        # into a lazy detach), re-arm the automount, verify REAL I/O - then
        # re-provision dirs and refresh metrics immediately so Gatus flips
        # without waiting for the 5-min poll. Also heals the drive-ABSENT case:
        # daemon-reload does NOT retroactively enforce device-bound on an
        # existing zombie, so this unit reaps it even with no device present.
        #
        # A HEALTHY mount is never torn down (2026-11-03): deploy.sh starts
        # this unit after every switch, and the old unconditional teardown
        # stopped mnt-buildcache.mount, which RequiresMountsFor propagates
        # into every consumer (the gitea runner died at 21:11:01 and the
        # post-deploy smoke FAILed). The healthy fast path converges
        # recoveryRestartUnits and exits; a real recovery does the same after
        # proving I/O.
        #
        # NOTE: deliberately NOT using harden {} - its PrivateTmp/
        # ProtectSystem options create a slave mount namespace in which
        # umount(2) cannot affect the HOST mount table; the zombie reaper
        # would silently no-op. Only non-namespace directives below.
        systemd.services.buildcache-usb-recovery = {
          description = "Recover buildcache mount after USB hotplug (zombie reaper + remount + consumer convergence)";
          startLimitBurst = 3;
          startLimitIntervalSec = 300;
          inherit onFailure;
          path = [
            pkgs.util-linux
            pkgs.coreutils
            pkgs.systemd
          ];
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            # CAP_FOWNER for the /tmp/bc-fallback sweep (step 6): the fallback
            # dirs are lars-owned under the sticky-bit /tmp, so deleting them
            # requires CAP_FOWNER even as root (memory-emergency-guard
            # 2026-08-22 class - hit live 2026-09-18: every recovery run
            # failed EPERM and OnFailure'd). CAP_DAC_OVERRIDE covers
            # traversal into foreign-owned trees.
            CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_FOWNER CAP_DAC_OVERRIDE";
            NoNewPrivileges = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            MemoryMax = "64M";
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
          };
          script = ''
            set -eu
            mnt="${cfg.mountPoint}"
            dev="${cfg.device}"

            # Converge build-cache consumers against a healthy mount: restart
            # FAILED units AND start enabled-but-inactive units. The step-1
            # teardown stops mnt-buildcache.mount, RequiresMountsFor implies
            # Requires=, so the mount stop TERMs every bound daemon; without
            # this they stay dark until their own timers/retries (2026-11-03:
            # the gitea runner was stopped by a deploy-time recovery at
            # 21:11:01 and the post-deploy smoke FAILed 72s before its ensure
            # timer brought it back). --no-block: never serialize this unit
            # behind the slowest consumer (the pool-recovery 2026-10-12 lesson).
            converge_consumers() {
              for unit in ${lib.concatStringsSep " " cfg.recoveryRestartUnits}; do
                if systemctl is-failed --quiet "$unit" 2>/dev/null; then
                  echo "buildcache-usb-recovery: restarting failed buildcache consumer: $unit"
                  systemctl reset-failed "$unit" 2>/dev/null || true
                  systemctl start --no-block "$unit" 2>/dev/null || echo "buildcache-usb-recovery: start $unit failed (non-fatal)" >&2
                else
                  en="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
                  case "$en" in
                    disabled | masked) continue ;;
                  esac
                  if ! systemctl is-active --quiet "$unit" 2>/dev/null; then
                    echo "buildcache-usb-recovery: starting enabled-but-inactive buildcache consumer: $unit"
                    systemctl start --no-block "$unit" 2>/dev/null || echo "buildcache-usb-recovery: start $unit failed (non-fatal)" >&2
                  fi
                fi
              done
            }

            # A mount that is demonstrably healthy (right device number, ext4,
            # real I/O) must be LEFT ALONE. The old unconditional teardown ran
            # on every deploy and stop-propagated into every bound daemon.
            mount_healthy() {
              [ -b "$dev" ] || return 1
              if ! findmnt -n -- "$mnt" >/dev/null 2>&1; then
                # Armed automount, not yet pulled: one access mounts it. A
                # dead device fails here (device-timeout), and with no
                # automount armed the access lands on the root-fs shadow dir
                # - the findmnt re-check below refuses that.
                timeout 10 ls -A "$mnt" >/dev/null 2>&1 || return 1
                findmnt -n -- "$mnt" >/dev/null 2>&1 || return 1
              fi
              hsrc="$(findmnt -n -t ext4 -o SOURCE -- "$mnt" 2>/dev/null || true)"
              [ -n "$hsrc" ] || return 1
              [ -b "$hsrc" ] || return 1
              # devt identity, not path identity: a replug can hand the same
              # by-id path to a different node (sd letter reuse), and a
              # foreign filesystem may sit at the mountpoint.
              [ "$(stat -c %t:%T -- "$hsrc" 2>/dev/null || true)" = "$(stat -c %t:%T -- "$dev" 2>/dev/null || true)" ] || return 1
              timeout 10 ls -A "$mnt" >/dev/null 2>&1
            }

            # udev and deploy.sh can fire this unit concurrently; a second run
            # must not race the first's teardown/remount.
            exec 9>/run/buildcache-usb-recovery.lock
            flock -n 9 || {
              echo "buildcache-usb-recovery: another run in flight - exiting"
              exit 0
            }

            # 0. Healthy fast path (2026-11-03): never tear down a working
            #    mount. Still converge consumers (a no-op for healthy ones) so
            #    an externally stopped or boot-dropped consumer heals here.
            if mount_healthy; then
              echo "buildcache healthy ($mnt) - no teardown"
              systemctl start buildcache-init.service buildcache-metrics.service 2>/dev/null || true
              converge_consumers
              exit 0
            fi

            # 1. Ask PID 1 to tear down automount + mount (real umount in the
            #    HOST namespace), then lazily detach any zombie that survives
            #    (busy CWDs/FDs) whose source device node no longer exists.
            systemctl stop ${mountUnitName}.automount 2>/dev/null || true
            systemctl stop ${mountUnitName}.mount 2>/dev/null || true
            src="$(findmnt -n -t ext4 -o SOURCE -- "$mnt" 2>/dev/null || true)"
            if [ -n "$src" ] && [ ! -b "$src" ]; then
              echo "reaping stale buildcache mount (source $src has no device node)"
              umount -l "$mnt" || true
            fi

            # 2. Clear failed start state and make sure the automount is armed.
            systemctl reset-failed ${mountUnitName}.mount 2>/dev/null || true
            systemctl start ${mountUnitName}.automount 2>/dev/null || true

            # 2.5 Reap real dirs that displaced the HM-managed ~/.cache
            # symlinks while the mount was dead: env-less tools (no GOCACHE)
            # recreate ~/.cache/<name> as REAL dirs on the NVMe, which both
            # re-contaminates the NVMe with build churn AND blocks the next
            # home-manager activation (checkLinkTargets "Existing file in the
            # way"). Cache data only, exact paths, symlink occupants kept.
            # Names come from the single source scripts/lib/buildcache-reap-
            # names.sh (shared with deploy.sh and the home.nix activation reap
            # — never a private copy). 2026-09-17: added the dead-mount
            # fallback names (gobuild gocache gomod; attribution corrected
            # 2026-11-06 in reap-names.sh — only `gocache` is BuildFlow's
            # scripts, `gobuild`/`gomod` match the agent-session export
            # class, no tracked source) - the original
            # 3-name list evaded them forever, leaving unowned NVMe churn
            # after every dead-mount episode. 2026-09-22 sweep: pnpm
            # (dlx/metadata cache, ~/.cache/pnpm — the store symlink covers
            # only the store; env-less pnpm recreates the cache dir as a real
            # dir on the NVMe during dead-mount windows).
            for d in ${lib.concatStringsSep " " reapNames.cacheDirs}; do
              if [ -e "${homeDir}/.cache/$d" ] && [ ! -L "${homeDir}/.cache/$d" ]; then
                # 2026-11-07: skip systemd mounts (hot-user-caches go-build
                # class) — rm -rf on a mountpoint wipes the mounted cache
                # contents then EBUSY-aborts (same class as the home.nix
                # activation + deploy.sh reaps, fixed same day).
                if /run/current-system/sw/bin/mountpoint -q -- "${homeDir}/.cache/$d"; then
                  echo "skip ${homeDir}/.cache/$d (systemd mount owns it — not a fallback dir)"
                else
                  rm -rf -- "${homeDir}/.cache/$d"
                  echo "reaped real dir at ${homeDir}/.cache/$d (HM symlink will replace it)"
                fi
              fi
            done
            # The non-.cache fallback paths from home.nix — env-less
            # pnpm/cargo recreate them as real dirs during dead-mount windows,
            # same checkLinkTargets abort class (2026-09-22 review fix).
            for d in ${lib.concatStringsSep " " reapNames.homeRelDirs}; do
              if [ -e "${homeDir}/$d" ] && [ ! -L "${homeDir}/$d" ]; then
                if /run/current-system/sw/bin/mountpoint -q -- "${homeDir}/$d"; then
                  echo "skip ${homeDir}/$d (systemd mount owns it — not a fallback dir)"
                else
                  rm -rf -- "${homeDir}/$d"
                  echo "reaped real dir at ${homeDir}/$d (HM symlink will replace it)"
                fi
              fi
            done

            # 3. Drive absent: done - zombie (if any) is reaped, automount is
            #    armed, and the udev SYSTEMD_WANTS rule heals on replug. Do NOT
            #    probe I/O here: an armed automount with no device blocks ~10s
            #    (device-timeout) and fails, which would mark this unit failed.
            if [ ! -b "$dev" ]; then
              echo "buildcache device absent ($dev) - automount armed, will heal on replug"
              exit 0
            fi

            # 4. Trigger the automount by path access and demand REAL I/O,
            #    not just mount-table presence.
            if ! timeout 20 ls -A "$mnt" >/dev/null 2>&1; then
              echo "buildcache still failing I/O after recovery attempt" >&2
              exit 1
            fi

            # 5. Re-provision cache dirs and refresh metrics now.
            systemctl start buildcache-init.service buildcache-metrics.service
            # 6. Sweep the tmpfs fallback caches the fish guard filled during
            # the outage (/tmp/bc-fallback/* - 00-go-cache-guard redirects
            # GOCACHE/GOMODCACHE/etc. there when this mount is dead). The
            # mount is healed and verified above, so the fallback copies are
            # pure duplication; tmpfs reclaims instantly (no snapshots, no
            # NVMe writes). rm is safe: rebuildable caches by contract.
            if [ -d /tmp/bc-fallback ]; then
              rm -rf /tmp/bc-fallback
              echo "buildcache fallback sweep: /tmp/bc-fallback removed (tmpfs reclaimed)"
            fi

            # 7. Converge consumers: the step-1 mount stop propagated through
            #    RequiresMountsFor and TERMed every bound daemon. Real I/O is
            #    proven by step 4, so they can come back now.
            converge_consumers

            echo "buildcache recovered: $(findmnt -n -t ext4 -o SOURCE -- "$mnt")"
          '';
        };

        # Always writes the .prom file - including when the drive is absent - so a
        # dead/unmounted drive flips buildcache_mounted to 0 and Gatus alerts,
        # instead of silently serving a stale green file.
        systemd.services.buildcache-metrics = {
          description = "Build cache SSD Prometheus metrics (mount, usage, SMART)";
          startLimitBurst = 3;
          startLimitIntervalSec = 300;
          path = [
            pkgs.smartmontools
            pkgs.util-linux
            pkgs.coreutils
            pkgs.gnugrep
          ];
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
            }
            (harden {
              ReadWritePaths = [ textfileDir ];
              # CAP_SYS_ADMIN/SYS_RAWIO for SMART; CAP_FOWNER for the sticky-dir
              # rename over a foreign-owned prom (mail-relay 2026-09-02..06 class).
              CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_SYS_RAWIO CAP_FOWNER";
              MemoryMax = "128M";
            })
            (serviceOneshotDefaults { })
          ];
          script = cacheSsd.metricsScript {
            prefix = "buildcache_";
            promName = "buildcache.prom";
            mnt = cfg.mountPoint;
            inherit (cfg) wholeDiskDevice;
            threshold = cfg.usageThresholdPercent;
            inherit textfileDir;
          };
        };

        systemd.timers.buildcache-metrics = {
          description = "Collect build cache SSD metrics every 5 minutes";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "5min";
            Persistent = true;
          };
        };

        # Daily cache GC (weekly 2026-08-15..2026-10-20 — the mount wedged at
        # 100% for days between Sunday runs; see the calendar default above).
        # Runs as the primary user (all cache dirs are
        # user-owned). rm on stale rust targets instead of trash is deliberate:
        # trashing 30G of rebuildable cache would write it to the NVMe trash -
        # the exact I/O this SSD exists to keep OFF the NVMe. Cache data only,
        # never user data; paths are anchored under the mount point.
        systemd.services.buildcache-gc = lib.mkIf cfg.gc.enable {
          description = "Build cache garbage collection (npm/pnpm prune, high-watermark go clean)";
          startLimitBurst = 3;
          startLimitIntervalSec = 300;
          unitConfig = {
            RequiresMountsFor = cfg.mountPoint;
            ConditionPathIsMountPoint = cfg.mountPoint;
          };
          environment = {
            # 2026-11-05: the LIVE go cache is the Samsung hot-user-caches
            # automount (/home/lars/.cache/go-build); the /mnt/buildcache
            # tree is the abandoned pre-migration copy (reclaimed by
            # migrate-go-caches-hot.sh reclaim-usb after the soak).
            GOCACHE = "/home/lars/.cache/go-build";
            npm_config_cache = "${cfg.mountPoint}/npm";
          };
          path = [
            pkgs.go
            pkgs.nodejs
            pkgs.pnpm
            pkgs.coreutils
            pkgs.findutils
          ];
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = primaryUser;
              # pnpm resolves its store relative to CWD when PNPM_HOME/XDG vars
              # are absent (a bare unit cwd=/ made it write /_tmp_* and fail
              # EACCES under ProtectSystem=strict, 2026-08-16). The mount is
              # writable and always exists for this unit.
              WorkingDirectory = cfg.mountPoint;
              # 45min: `go clean -cache` at high-watermark scale (100G+ of
              # small files) is metadata-bound on a DRAM-less USB SSD - 20min
              # was too tight to survive the exact scenario the watermark guard
              # exists for.
              TimeoutStartSec = "45min";
            }
            (harden {
              # pnpm writes state/metadata under HOME: ~/.cache/pnpm (dlx +
              # project registries) and ~/.local/state/pnpm (pnpm-state.json) -
              # without these holes prune fails under read-only home (verified
              # live 2026-08-15; the state hole added 2026-08-16).
              #
              # DELIBERATELY NO `-~/tmp/go-lint*` HOLES (2026-11-03): the `-`
              # prefix tolerates ENOENT but NOT ENODEV, and ~/tmp is an
              # fstab/automount mount point. While that mount is FAILED,
              # systemd aborts namespace setup for the whole unit:
              # "Failed to set up mount namespacing: /home/lars/tmp/go-lint: No
              # such device" -> status=226/NAMESPACE. Live evidence: EVERY run
              # from 2026-11-02 17:38 through 2026-11-03 21:11 died this way,
              # silently disabling the only guard that keeps the buildcache
              # disk off 100%. The two paths held the LEGACY golangci cache
              # (the wrapper writes /mnt/buildcache/golangci-lint, or the
              # /tmp/bc-fallback tmpfs when the mount is dead, since
              # 2026-10-10), so no writer needs a hole here; step 2.5's trim is
              # now a best-effort no-op under ProtectHome=read-only (its find
              # calls are `|| true`-tolerant) and the ~1.4G residue is an owner
              # reclaim (docs/todo/storage.md). NEVER put a ReadWritePaths entry
              # under a mount point with the `-` prefix: gate the MOUNT, not the
              # path.
              ProtectHome = "read-only";
              ReadWritePaths = [
                cfg.mountPoint
                "${homeDir}/.cache/pnpm"
                "${homeDir}/.local/state/pnpm"
              ];
              MemoryMax = "512M";
            })
            ioTier.maintenance
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            mnt="${cfg.mountPoint}"
            watermark=${toString cfg.gc.highWatermarkPercent}

            usage() {
              df --output=pcent "$mnt" | tail -n1 | tr -dc '0-9'
            }

            echo "buildcache-gc: start at $(usage)% usage"

            # 1. npm: verify garbage-collects corrupt/old tarballs
            npm cache verify || echo "buildcache-gc: npm cache verify failed (non-fatal)"

            # 2. pnpm: remove packages no longer referenced by any project.
            #    --store is MANDATORY: pnpm resolves its store relative to
            #    CWD/HOME state when PNPM_HOME/XDG vars are absent - a bare
            #    unit cwd=/ made it EACCES on /_tmp_* under ProtectSystem
            #    (silent weekly prune failure, caught 2026-08-16).
            pnpm store prune --store "$mnt/pnpm-store" || echo "buildcache-gc: pnpm store prune failed (non-fatal)"

            # 2.5. Legacy storm-fallback lint cache: the wrapper's dead-mount
            #      fallback moved to /tmp/bc-fallback (tmpfs) on 2026-10-10, so
            #      ~/tmp/go-lint is reclaimable residue (832M at the move).
            #      7d mtime gate drains the legacy tree and bounds any future
            #      regrowth (reverted wrapper, stray writer) without touching
            #      fresh cache. Dirs are optional - skipped when absent.
            #      BEST EFFORT ONLY since 2026-11-03: this unit no longer holds
            #      a ReadWritePaths hole for these paths (a `-`-prefixed hole
            #      under the ~/tmp mount point killed the whole gc with
            #      226/NAMESPACE while that mount was failed), so under
            #      ProtectHome=read-only the deletes below fail EACCES and are
            #      tolerated - the gc's real job (buildcache hygiene) wins.
            for legacy in "${homeDir}/tmp/go-lint" "${homeDir}/tmp/go-lint-analysis"; do
              if [ -d "$legacy" ]; then
                find "$legacy" -xdev -type f -mtime +7 -delete || true
                find "$legacy" -xdev -depth -mindepth 1 -type d -empty -delete || true
              fi
            done

            # 4. High watermark: go-build is the only unbounded cache (gopls
            #    mtime refresh defeats Go's 5-day LRU trim). Cold it if needed.
            pct=$(usage)
            if [ -z "''${pct:-}" ]; then
              echo "buildcache-gc: usage unavailable - mount vanished mid-run?" >&2
              exit 1
            fi
            echo "buildcache-gc: after pruning at ''${pct}% usage"
            if [ "$pct" -ge "$watermark" ]; then
              echo "buildcache-gc: usage >= $watermark% - running go clean -cache (cold rebuild is better than a full disk)"
              go clean -cache
              echo "buildcache-gc: post-clean usage: $(usage)%"
            fi

            echo "buildcache-gc: done"
          '';
        };

        systemd.timers.buildcache-gc = lib.mkIf cfg.gc.enable {
          description = "Daily build cache garbage collection";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.gc.calendar;
            Persistent = true;
            Unit = "buildcache-gc.service";
          };
        };

        # Stale per-task agent caches (2026-11-04): Crush sessions historically
        # exported per-task GOCACHE/GOLANGCI_LINT_CACHE dirs that landed in
        # ~/.cache (the @cache-home subvol on the QLC NVMe) and were never
        # reaped — the 2026-11-03 purge wave removed ~16G of this litter by
        # hand. The convention moves per-task caches to
        # /mnt/buildcache/agent-caches/<task>; the direnv guard
        # (zz-smart-nix.sh) rewrites strays at shell start; this unit is the
        # backstop that ages out BOTH namespaces. Sweep patterns are
        # deliberately narrow: only agent-litter-shaped names, never the HM
        # out-of-store symlinks (find -type d does not match a symlink), never
        # live caches (mtime-gated — go touches entries on every build write).
        systemd.services.buildcache-agent-cache-gc = lib.mkIf cfg.gc.enable {
          description = "Age out stale per-task agent caches (~/.cache litter + mount agent-caches)";
          startLimitBurst = 3;
          startLimitIntervalSec = 300;
          unitConfig = {
            RequiresMountsFor = cfg.mountPoint;
            # Gate BOTH mounts, never a path: the @cache-home automount must be
            # up before the namespace holes below are created, and the
            # conditions skip cleanly (result=skip) when either mount is dead
            # — sweeping a shadow dir on the root fs would be exactly the
            # contamination ConditionPathIsMountPoint exists to prevent (the
            # ~/tmp/go-lint 226/NAMESPACE lesson: gate the MOUNT, not a path).
            ConditionPathIsMountPoint = [
              cfg.mountPoint
              "${homeDir}/.cache"
            ];
          };
          path = [
            pkgs.coreutils
            pkgs.findutils
          ];
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = primaryUser;
              TimeoutStartSec = "10min";
            }
            (harden {
              ProtectHome = "read-only";
              ReadWritePaths = [
                cfg.mountPoint
                "${homeDir}/.cache"
              ];
              MemoryMax = "256M";
            })
            ioTier.maintenance
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            mnt="${cfg.mountPoint}"
            home_cache="${homeDir}/.cache"
            echo "buildcache-agent-cache-gc: start"

            # Home litter: real dirs shaped like agent per-task caches,
            # unmodified >=48h (the negative-test-lints 2026-11-03 precedent).
            # go-build-*/ *-gocache are the per-task GOCACHE shapes (exact
            # go-build is the HM symlink — excluded by the pattern); go-tmp and
            # negative-test-lints.* are litter names observed in the
            # 2026-11-03 purge wave. Anything else under ~/.cache (gopls,
            # nix, browser caches, owner-triage dirs like cv-go/glac-fleet)
            # is NEVER matched.
            find "$home_cache" -mindepth 1 -maxdepth 1 -type d \
              \( -name 'go-build-*' -o -name '*-gocache' -o -name 'gocache-*' \
                 -o -name 'go-tmp' -o -name 'negative-test-lints.*' \) \
              -mtime +2 -print -exec rm -rf {} + \
              || echo "buildcache-agent-cache-gc: home sweep failed (non-fatal)" >&2

            # Mount side: per-task caches LIVE here by convention; age out
            # dirs untouched >=7d (an active task touches its dir on every
            # build write, so 7d staleness is safely quiescent).
            if [ -d "$mnt/agent-caches" ]; then
              find "$mnt/agent-caches" -mindepth 1 -maxdepth 1 -type d \
                -mtime +7 -print -exec rm -rf {} + \
                || echo "buildcache-agent-cache-gc: mount sweep failed (non-fatal)" >&2
            fi

            echo "buildcache-agent-cache-gc: done"
          '';
        };

        # Staggered +20min from buildcache-gc (05:00) so the two IO-tier
        # sweeps never overlap on the USB link.
        systemd.timers.buildcache-agent-cache-gc = lib.mkIf cfg.gc.enable {
          description = "Daily stale agent-cache sweep";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 05:20:00";
            Persistent = true;
            Unit = "buildcache-agent-cache-gc.service";
          };
        };

        # Service-integration registry entry: the buildcache/pool textfile
        # metric checks (SSD health/usage + pool mount/usage) gated on this
        # module. Replaces rows in gatus-config.nix.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          buildcache = {
            inherit (cfg) enable;
            vHost.layer = "none";
            checks = [
              {
                name = "Build Cache SSD";
                group = "Filesystem";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  # pat() is a GLOB: HELP comments contain "metric 1", so assert absence
                  # of the 0-value line plus presence of the metric instead ('!' is a
                  # literal in filepath.Match - no glob negation exists).
                  "[BODY] != pat(*buildcache_mounted 0\n*)"
                  "[BODY] == pat(*\nbuildcache_mounted *)"
                  "[BODY] != pat(*buildcache_smart_healthy 0\n*)"
                  "[BODY] == pat(*\nbuildcache_smart_healthy *)"
                ];
                alert = "Build cache SSD (/mnt/buildcache) unmounted or SMART-failing - pnpm/playwright/npm builds will fail with missing-directory errors (Go caches live on the Samsung hot tier since 2026-11-05). Check: findmnt /mnt/buildcache, sudo smartctl -d sat -H /dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311. If the drive died: revert GOCACHE/GOMODCACHE in platforms/nixos/users/home.nix and rebuild caches on NVMe.";
              }
              {
                name = "Build Cache Usage";
                group = "Filesystem";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "30m";
                conditions = [
                  "[STATUS] == 200"
                  # Fail-closed on the dead-drive state (2026-08-22 DAS
                  # outage): with the drive absent the usage metrics vanish
                  # but over_threshold last wrote "0" via the always-write
                  # .prom - this check stayed GREEN on a dead drive for
                  # days while "Build Cache SSD" alone carried the signal.
                  # Mounted must be 1; anchored form (HELP embeds "metric 1").
                  "[BODY] != pat(*buildcache_mounted 0\n*)"
                  "[BODY] == pat(*\nbuildcache_mounted *)"
                  "[BODY] == pat(*\nbuildcache_usage_over_threshold 0*)"
                ];
                alert = "Build cache SSD exceeds 85% - the 240 GB drive is filling. Prune: cargo clean in monitor365; pnpm store prune; rm old Playwright browsers (the abandoned pre-migration Go trees are reclaimed by scripts/migrate-go-caches-hot.sh reclaim-usb after the soak).";
              }
              {
                name = "Pool Mounted";
                group = "Filesystem";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  # HELP comment contains "pool_mounted 1" - absence-of-0 + presence.
                  "[BODY] != pat(*pool_mounted 0\n*)"
                  "[BODY] == pat(*\npool_mounted *)"
                ];
                alert = "Mirrored HDD pool (/mnt/pool) unmounted - immich + paperless data, ALL application backups, and the btrbk safety net are offline. Check: findmnt /mnt/pool, systemctl status mnt-pool.mount. If a DAS member died: the raid1 still serves from the other member; replace the drive and btrfs replace.";
              }
              {
                name = "Pool Usage";
                group = "Filesystem";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "30m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*pool_usage_over_threshold 0*)"
                ];
                alert = "Mirrored HDD pool exceeds 85% - review /mnt/pool usage: backups retention (30d 12w targets, forgejo zips 7d), archive/forensic-snapshots growth.";
              }
            ];
          };
        };
      };
    };
}
