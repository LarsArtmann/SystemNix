# Rust build cache SSD - the second SanDisk SDSSDA240G (serial 174244451713),
# USB 3.0 in the SAME JMicron JMS567 enclosure as /mnt/buildcache.
#
# Purpose: give Rust's churn (per-project target/ dirs, the sccache global
# compile cache, and CARGO_HOME) its own filesystem. Rust target/ trees are
# the single largest build-cache consumer (121G measured 2026-09-22) and are
# pure write amplification; moving them here frees the Go/JS/Python caches on
# /mnt/buildcache and takes Rust's write pressure off that disk. Supersedes
# the 2026-09-22 two-SanDisk btrfs-merge decision (2026-10-06 user direction:
# dedicate the single empty 240GB SSD to the Rust cache).
#
# Why btrfs + compress=zstd:1 (NOT ext4 like /mnt/buildcache):
#   - rust debuginfo + DWARF objects compress ~2-2.5x; zstd:1 reclaims most of
#     the 240G raw for the large target/ trees.
#   - cargo does NOT content-hash-verify its target/ cache the way Go verifies
#     go-build: on ext4 + data=writeback a torn write (SandForce SF-2000, no
#     PLP, dirty-shutdown history) is served SILENTLY. btrfs checksums turn it
#     into an EIO = cache miss = clean rebuild.
#   - Single profile (one disk, rebuildable cache): no redundancy wanted.
#
# Consum CSR: SCCACHE_DIR, CARGO_HOME (platforms/nixos/users/home.nix) and the
# ~/projects/<p>/target symlinks (platforms/nixos/system/snapshots.nix).
#
# Migration of existing caches: `nix run .#migrate-rust-cache` (run BEFORE the
# first deploy of this module - it formats/mounts the disk and moves the
# existing rust/sccache/cargo trees off /mnt/buildcache).
{
  flake.nixosModules.rust-cache =
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

      cacheSsd = import ../../../lib/cache-ssd.nix lib;

      cfg = config.services.rust-cache;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      primaryUser = config.users.primaryUser;
      homeDir = config.users.users.${primaryUser}.home;

      # Dirs provisioned on the mount by rust-cache-init. CARGO_HOME points at
      # <mountPoint>/cargo; the env-less fallback at ~/.cargo/registry
      # converges onto the SAME registry (home.nix symlink).
      rustCacheDirs = [
        "sccache"
        "cargo"
        "cargo/registry"
      ]
      ++ map (project: "rust/${project}") cfg.rustProjects;

      # ID_SERIAL of the cache SSD and the mountpoint's systemd unit name —
      # shared cache-SSD helpers (lib/cache-ssd.nix).
      deviceSerial = cacheSsd.deviceSerialFromDevice cfg.device;
      mountUnitName = cacheSsd.mountUnitNameFor cfg.mountPoint;
    in
    {
      options.services.rust-cache = {
        enable = lib.mkEnableOption "USB SSD Rust build cache at /mnt/rust-cache (dedicated target/sccache/cargo disk)";

        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/rust-cache";
          description = "Mount point for the Rust cache btrfs filesystem.";
        };

        device = lib.mkOption {
          type = lib.types.str;
          default = "/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713-part1";
          description = ''
            Partition device. by-id (ata- serial form) is stable across sdb/sdc
            letter swaps between the two USB-attached SSDs.
          '';
        };

        wholeDiskDevice = lib.mkOption {
          type = lib.types.str;
          default = "/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713";
          description = "Whole-disk device for SMART queries (smartctl -d sat).";
        };

        rustProjects = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Rust project names that get a target/ dir symlinked from
            ~/projects/<name>/target into the cache (see snapshots.nix).
          '';
        };

        usageThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 85;
          description = "Usage percentage at which the Gatus alert fires (240 GB drive; caches should be pruned before full).";
        };

        criticalThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 95;
          description = ''
            Usage percentage for the SEPARATE CRITICAL Gatus tier. Deliberately
            distinct from usageThresholdPercent: the 85% alert stood red for
            days while the disk filled (alert fatigue — freezes #60-63,
            2026-11-22..24, all rode >=96% usage while "alerted"). This tier
            must read as page-now, not standing state.
          '';
        };

        gc = {
          enable = lib.mkEnableOption "weekly Rust cache garbage collection";

          maxAgeDays = lib.mkOption {
            type = lib.types.int;
            default = 14;
            description = ''
              Orphaned cache dirs (rust/<name> with no matching ~/projects/<name>
              dir) older than this are deleted whole. Resident projects are
              NEVER whole-dir pruned — reclaiming their space is a placement
              decision, not a GC decision.
            '';
          };

          sweepMaxAgeDays = lib.mkOption {
            type = lib.types.int;
            default = 21;
            description = ''
              Age threshold for the per-artifact sweep: deps/root artifact
              files deleted together with their companion
              .fingerprint/<stem> dirs, plus stale incremental session dirs.
            '';
          };

          aggressiveAgeDays = lib.mkOption {
            type = lib.types.int;
            default = 7;
            description = "Sweep age used once usage is at or above actThresholdPercent.";
          };

          actThresholdPercent = lib.mkOption {
            type = lib.types.int;
            default = 80;
            description = ''
              Usage at which the GC escalates to the aggressive sweep age
              (usageThresholdPercent stays the Gatus alert threshold — the
              two numbers are deliberately separate).
            '';
          };

          calendar = lib.mkOption {
            type = lib.types.str;
            default = "Sun *-*-* 05:15:00";
            description = "OnCalendar for the GC timer (default: Sunday 05:15 - right after buildcache-gc 05:00, idle I/O tier).";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        # nofail: a dead/absent USB drive must never block boot. automount: mount
        # on first access rather than at boot, tolerating late DAS power-up.
        # device-timeout bounds the wait if the enclosure is unplugged.
        # device-bound: the kernel mount table stores device NUMBERS
        # (major:minor), not paths - a USB reconnect mints a new number, the
        # by-id symlink cannot re-point the established mount, and a zombie
        # EIOs forever (2026-08-16 buildcache class). device-bound makes systemd
        # stop the mount when the .device unit dies; the automount then
        # re-resolves the by-id path on next access.
        fileSystems.${cfg.mountPoint} = mkFilesystem {
          inherit (cfg) device;
          fsType = "btrfs";
          options = [
            "noatime"
            "compress=zstd:1"
            "space_cache=v2"
            "commit=120"
            "nofail"
            "x-systemd.automount"
            # 2s: a dead/flapping enclosure must not cost the full timeout per
            # mount lookup - every D-state probe stalls its caller and fakes IO
            # PSI saturation (2026-08-24 buildcache class).
            "x-systemd.device-timeout=2s"
            "x-systemd.device-bound"
          ];
        };

        # The JMS567 bridge power rule is shared with buildcache.nix (the same
        # enclosure) - duplicated here so this module is self-contained if the
        # two ever split onto separate enclosures. Duplicate udev rules are
        # idempotent attribute writes.
        services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="152d", ATTR{idProduct}=="0567", TEST=="power/control", ATTR{power/control}="on"
          ACTION=="add", SUBSYSTEM=="pci", ATTR{class}=="0x0c0330|0x0c0340", TEST=="power/control", ATTR{power/control}="on"
        ''
        + lib.optionalString (deviceSerial != null) ''
          ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_SERIAL}=="${deviceSerial}", ENV{SYSTEMD_WANTS}+="rust-cache-usb-recovery.service"
        '';

        systemd.services.rust-cache-init = {
          description = "Initialize Rust cache directories on the USB SSD";
          wantedBy = [ "multi-user.target" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          unitConfig = {
            RequiresMountsFor = cfg.mountPoint;
            ConditionPathIsMountPoint = cfg.mountPoint;
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
            (harden {
              ReadWritePaths = [ cfg.mountPoint ];
              CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
              MemoryMax = "64M";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            for dir in ${lib.concatStringsSep " " rustCacheDirs}; do
              mkdir -p "${cfg.mountPoint}/$dir"
              chown ${primaryUser}:users "${cfg.mountPoint}/$dir"
              chmod 0755 "${cfg.mountPoint}/$dir"
            done
            echo "rust-cache initialized at ${cfg.mountPoint}"
          '';
        };

        # Belt-and-braces for x-systemd.device-bound, triggered by udev when
        # the partition reappears (and by deploy.sh after every switch): reap
        # any zombie mount, re-arm the automount, verify REAL I/O, then
        # re-provision dirs and refresh metrics.
        #
        # NOTE: deliberately NOT using harden {} - its PrivateTmp/ProtectSystem
        # options create a slave mount namespace in which umount(2) cannot
        # affect the HOST mount table; the zombie reaper would silently no-op.
        systemd.services.rust-cache-usb-recovery = {
          description = "Recover rust-cache mount after USB hotplug (zombie reaper + remount)";
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
            # CAP_FOWNER for the sticky-dir sweep (the fallback dirs are
            # lars-owned under the sticky-bit /tmp; deleting them requires
            # CAP_FOWNER even as root). CAP_DAC_OVERRIDE covers traversal into
            # foreign-owned trees.
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

            # 1. Ask PID 1 to tear down automount + mount (real umount in the
            #    HOST namespace), then lazily detach any zombie that survives
            #    (busy CWDs/FDs) whose source device node no longer exists.
            systemctl stop ${mountUnitName}.automount 2>/dev/null || true
            systemctl stop ${mountUnitName}.mount 2>/dev/null || true
            src="$(findmnt -n -t btrfs -o SOURCE -- "$mnt" 2>/dev/null || true)"
            if [ -n "$src" ] && [ ! -b "$src" ]; then
              echo "reaping stale rust-cache mount (source $src has no device node)"
              umount -l "$mnt" || true
            fi

            # 2. Clear failed start state and make sure the automount is armed.
            systemctl reset-failed ${mountUnitName}.mount 2>/dev/null || true
            systemctl start ${mountUnitName}.automount 2>/dev/null || true

            # 2.5 Reap a real ~/.cargo/registry that displaced the HM symlink
            # while the mount was dead: env-less cargo (CARGO_HOME absent)
            # recreates it as a REAL dir on the NVMe, re-contaminating the NVMe
            # and blocking the next home-manager activation (checkLinkTargets
            # "Existing file in the way"). Cache data only; symlinks kept.
            if [ -e "${homeDir}/.cargo/registry" ] && [ ! -L "${homeDir}/.cargo/registry" ]; then
              rm -rf -- "${homeDir}/.cargo/registry"
              echo "reaped real dir at ${homeDir}/.cargo/registry (HM symlink will replace it)"
            fi

            # 3. Drive absent: done - zombie (if any) is reaped, automount is
            #    armed, and the udev SYSTEMD_WANTS rule heals on replug.
            if [ ! -b "$dev" ]; then
              echo "rust-cache device absent ($dev) - automount armed, will heal on replug"
              exit 0
            fi

            # 4. Trigger the automount by path access and demand REAL I/O.
            if ! timeout 20 ls -A "$mnt" >/dev/null 2>&1; then
              echo "rust-cache still failing I/O after recovery attempt" >&2
              exit 1
            fi

            # 5. Re-provision dirs and refresh metrics now.
            systemctl start rust-cache-init.service rust-cache-metrics.service

            echo "rust-cache recovered: $(findmnt -n -t btrfs -o SOURCE -- "$mnt")"
          '';
        };

        # Always writes the .prom file - including when the drive is absent - so
        # a dead/unmounted drive flips rustcache_mounted to 0 and Gatus alerts,
        # instead of silently serving a stale green file.
        systemd.services.rust-cache-metrics = {
          description = "Rust cache SSD Prometheus metrics (mount, usage, SMART)";
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
              CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_SYS_RAWIO CAP_FOWNER";
              MemoryMax = "128M";
            })
            (serviceOneshotDefaults { })
          ];
          script = cacheSsd.metricsScript {
            prefix = "rustcache_";
            promName = "rust-cache.prom";
            mnt = cfg.mountPoint;
            inherit (cfg) wholeDiskDevice;
            threshold = cfg.usageThresholdPercent;
            inherit textfileDir;
            criticalThreshold = cfg.criticalThresholdPercent;
            # Event-driven GC trigger (see systemd.paths.rust-cache-reclaim):
            # flag touched while usage >= gc.actThresholdPercent.
            reclaimFlagPath = "/run/rust-cache-reclaim.flag";
            reclaimThreshold = cfg.gc.actThresholdPercent;
          };
        };

        systemd.timers.rust-cache-metrics = {
          description = "Collect Rust cache SSD metrics every 5 minutes";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "5min";
            Persistent = true;
          };
        };

        # Weekly Rust cache GC: (1) per-artifact aged sweep inside resident
        # target dirs — artifact file deleted TOGETHER with its companion
        # .fingerprint/<stem> dir (deleting one without the other makes cargo
        # relink redundantly or fail at link time); plus stale incremental
        # session dirs. cargo keeps old build-dir and dep variants forever,
        # so this is the only reclaim they ever get. (2) Orphan-dir prune:
        # rust/<name> whose project tree is gone. (3) Threshold ladder to a
        # more aggressive sweep age. Runs as the primary user (all cache dirs
        # are user-owned). rm instead of trash is deliberate: trashing tens
        # of GB of rebuildable cache would write it to the NVMe trash — the
        # exact I/O this SSD exists to keep OFF the NVMe. Cache data only,
        # never user data; paths anchored under the mount point.
        #
        # 2026-11-18 redesign: the old cold-prune-ALL leg is GONE. Measured
        # on monitor365 (199G/224G, the only resident that ever mattered):
        # ZERO bytes older than 7d — the working set churns in place
        # (same-hash artifacts overwrite, refreshing mtimes), so age-based
        # reclamation finds ~0, and "cold-prune ALL" only ever destroyed
        # ACTIVE caches to buy a rebuild storm on a 24 MB/s USB SSD.
        # Reclaiming a resident project's space is a placement decision
        # (cargo clean / move the target), never a GC decision.
        systemd.services.rust-cache-gc = lib.mkIf cfg.gc.enable {
          description = "Rust cache garbage collection (aged artifact sweep, orphan prune, threshold ladder)";
          startLimitBurst = 3;
          startLimitIntervalSec = 300;
          unitConfig = {
            RequiresMountsFor = cfg.mountPoint;
            ConditionPathIsMountPoint = cfg.mountPoint;
          };
          path = [
            pkgs.coreutils
            pkgs.findutils
            pkgs.procps
          ];
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = primaryUser;
              WorkingDirectory = cfg.mountPoint;
              # The rate-limit stamp lives here, not on the cache mount: the
              # mount root is root-owned 0755, so the user running this unit
              # cannot create a file there (touch EPERM, unit failed on its
              # first non-skipped run 2026-11-24 23:38).
              StateDirectory = "rust-cache-gc";
              # rm -rf of metadata-bound target trees on a DRAM-less USB SSD is
              # slow; 30min is generous but bounded.
              TimeoutStartSec = "30min";
            }
            (harden {
              ReadWritePaths = [ cfg.mountPoint ];
              MemoryMax = "512M";
            })
            ioTier.maintenance
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            mnt="${cfg.mountPoint}"
            max_age=${toString cfg.gc.maxAgeDays}
            sweep_age=${toString cfg.gc.sweepMaxAgeDays}
            aggressive_age=${toString cfg.gc.aggressiveAgeDays}
            act=${toString cfg.gc.actThresholdPercent}
            projects_root="${homeDir}/projects"

            # Busy-builder guard (the target-gc rule, ported with Leg 1.5):
            # in-flight artifacts have no fingerprint yet and would be
            # misclassified as orphans. Skip, do not fail — the path/timer
            # trigger retries on its next scrape.
            if pgrep -x cargo >/dev/null 2>&1 || pgrep -x rustc >/dev/null 2>&1; then
              echo "rust-cache-gc: cargo/rustc running - skipping this run (in-flight artifacts have no fingerprint yet)"
              exit 0
            fi

            # Rate limit for usage-triggered runs: the metrics scrape rewrites
            # the reclaim flag every 5 min while usage is high, re-arming the
            # path unit each time the GC goes inactive. Without this stamp that
            # would re-sweep the disk continuously. 6h = one sweep per window.
            stamp="/var/lib/rust-cache-gc/stamp"
            if [ -f "$stamp" ]; then
              age=$(( $(date +%s) - $(stat -c %Y "$stamp") ))
              if [ "$age" -lt 21600 ]; then
                echo "rust-cache-gc: last run ''${age}s ago (<21600s) - skipping"
                exit 0
              fi
            fi
            touch "$stamp"

            usage() {
              df --output=pcent "$mnt" | tail -n1 | tr -dc '0-9'
            }

            # Aged artifact sweep across every resident target dir.
            sweep() {
              age=$1
              local t debug base stem n
              for t in "$mnt"/rust/*; do
                [ -d "$t" ] || continue
                debug="$t/debug"
                [ -d "$debug" ] || continue
                if [ -d "$debug/incremental" ]; then
                  n=$(find "$debug/incremental" -mindepth 1 -maxdepth 1 -type d -mtime "+$age" | wc -l)
                  if [ "$n" -gt 0 ]; then
                    find "$debug/incremental" -mindepth 1 -maxdepth 1 -type d -mtime "+$age" -exec rm -rf {} +
                    echo "rust-cache-gc: swept $n stale incremental session dirs under $(basename "$t")"
                  fi
                fi
                for artifact_dir in "$debug/deps" "$debug"; do
                  [ -d "$artifact_dir" ] || continue
                  while IFS= read -r -d ''' f; do
                    base=$(basename "$f")
                    case "$base" in
                      *.rlib|*.rmeta|*.d|*.so|*.dylib|*.bin) stem="''${base%.*}" ;;
                      *) stem="$base" ;;
                    esac
                    rm -f -- "$f"
                    rm -rf -- "$debug/.fingerprint/$stem"
                  done < <(find "$artifact_dir" -maxdepth 1 -type f -mtime "+$age" -print0)
                done
                # Orphan fingerprint dirs: aged fingerprint whose artifact is
                # gone (failed companion rm, prior manual deletes). Kept
                # fingerprints without artifacts would block rebuilds.
                if [ -d "$debug/.fingerprint" ]; then
                  while IFS= read -r -d ''' fp; do
                    stem=$(basename "$fp")
                    if ! compgen -G "$debug/deps/$stem.*" >/dev/null && ! compgen -G "$debug/$stem.*" >/dev/null; then
                      rm -rf -- "$fp"
                    fi
                  done < <(find "$debug/.fingerprint" -mindepth 1 -maxdepth 1 -type d -mtime "+$age" -print0)
                fi
              done
            }

            echo "rust-cache-gc: start at $(usage)% usage (sweep ''${sweep_age}d, aggressive ''${aggressive_age}d, act ''${act}%)"

            # Leg 1: normal aged sweep.
            sweep "$sweep_age"

            # Leg 1.5: fingerprint-orphan sweep (age-INDEPENDENT, ported from
            # monitor365 scripts/target-gc.sh — cargo-safe rules proven there
            # 2026-11-17/18). The aged sweeps reclaim ~0 on this disk: the
            # working set churns in place, refreshing mtimes (measured
            # 2026-11-18: zero bytes older than 7d at 199G/224G). What DOES
            # accumulate: artifacts whose fingerprint variant is gone —
            # feature-set changes mint new .fingerprint stems and abandon the
            # old ones (libduckdb-sys alone minted 8+ variants at 3.2G EACH
            # before the 2026-11-17 manual clean). The -mmin +120 floor on
            # pass 1 keeps a build that started seconds after the busy-guard
            # pgrep from having its just-written, fingerprint-pending
            # artifacts reaped mid-compile.
            orphan_files=0
            orphan_bytes=0
            orphan_fps=0
            orphan_builds=0
            for t in "$mnt"/rust/*; do
              [ -d "$t" ] || continue
              debug="$t/debug"
              [ -d "$debug" ] || continue
              # Pass 1: artifact files with no fingerprint dir (older than
              # 120 min only — see the race note above).
              for artifact_dir in "$debug/deps" "$debug"; do
                [ -d "$artifact_dir" ] || continue
                while IFS= read -r -d ''' f; do
                  base="''${f##*/}"
                  case "$base" in
                    *.rlib|*.rmeta|*.d|*.so|*.dylib|*.o|*.bin) stem="''${base%.*}" ;;
                    *) stem="$base" ;;
                  esac
                  if [ ! -d "$debug/.fingerprint/$stem" ]; then
                    orphan_bytes=$((orphan_bytes + $(stat -c %s -- "$f" 2>/dev/null || echo 0)))
                    rm -f -- "$f"
                    orphan_files=$((orphan_files + 1))
                  fi
                done < <(find "$artifact_dir" -maxdepth 1 -type f -mmin +120 -print0)
              done
              # Pass 2: fingerprint dirs with no artifact anywhere (reverse
              # orphans — a live fingerprint with a deleted artifact makes
              # cargo SKIP the rebuild and fail at link time).
              if [ -d "$debug/.fingerprint" ]; then
                while IFS= read -r -d ''' fp; do
                  stem="''${fp##*/}"
                  if ! compgen -G "$debug/deps/$stem.*" >/dev/null && ! compgen -G "$debug/$stem.*" >/dev/null; then
                    rm -rf -- "$fp"
                    orphan_fps=$((orphan_fps + 1))
                  fi
                done < <(find "$debug/.fingerprint" -mindepth 1 -maxdepth 1 -type d -print0)
              fi
              # Pass 3: build-script out dirs no fingerprint references
              # (build dirs are named inside fingerprint JSONs by path).
              if [ -d "$debug/build" ]; then
                for d in "$debug/build/"*/; do
                  [ -d "$d" ] || continue
                  name="''${d%/}"; name="''${name##*/}"
                  [ -d "$debug/.fingerprint/$name" ] && continue
                  grep -rqF -- "$name" "$debug/.fingerprint" 2>/dev/null && continue
                  rm -rf -- "$d"
                  orphan_builds=$((orphan_builds + 1))
                done
              fi
            done
            echo "rust-cache-gc: orphan sweep: ''${orphan_files} artifacts ($((orphan_bytes / 1048576))MB), ''${orphan_fps} fingerprints, ''${orphan_builds} build dirs"

            # Leg 2: orphaned cache dirs — project tree gone. The dir's OWN
            # mtime must be older than max_age (a freshly recreated shadow is
            # kept for its grace window).
            for t in "$mnt"/rust/*; do
              [ -d "$t" ] || continue
              p=$(basename "$t")
              if [ ! -d "$projects_root/$p" ]; then
                if [ -z "$(find "$t" -maxdepth 0 -mtime "-$max_age" -print)" ]; then
                  rm -rf -- "$t"
                  echo "rust-cache-gc: pruned orphaned cache dir rust/$p (no project dir at projects/$p)"
                fi
              fi
            done

            # Leg 3: threshold ladder — escalate the sweep age once.
            pct=$(usage) || pct=""
            if [ -z "$pct" ]; then
              echo "rust-cache-gc: usage unavailable - mount vanished mid-run?" >&2
              exit 1
            fi
            if [ "$pct" -ge "$act" ] && [ "$sweep_age" -ne "$aggressive_age" ]; then
              echo "rust-cache-gc: at ''${pct}% >= act ''${act}% - aggressive sweep at ''${aggressive_age}d"
              sweep "$aggressive_age"
              pct=$(usage)
            fi

            echo "rust-cache-gc: done at ''${pct}% usage"
            if [ "$pct" -ge "$act" ]; then
              echo "rust-cache-gc: WARNING still >= ''${act}% - remaining usage is held by RESIDENT projects; GC never wipes active caches. Reclaim = monitor365 scripts/target-gc.sh --apply, cargo clean <project>, or move the target (placement decision), see docs/agents/storage.md"
            fi
          '';
        };

        systemd.timers.rust-cache-gc = lib.mkIf cfg.gc.enable {
          description = "Weekly Rust cache garbage collection";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.gc.calendar;
            Persistent = true;
            Unit = "rust-cache-gc.service";
          };
        };

        # Event-driven GC trigger (2026-11-24, freeze #60-63 class): the
        # metrics scrape (every 5 min) touches /run/rust-cache-reclaim.flag
        # while usage >= gc.actThresholdPercent — this path unit turns that
        # into a GC run, so headroom restoration is usage-triggered, not
        # calendar-paced (the Sunday timer watched a ~28G/day regrowth fill
        # the disk between fires: owner clean 92%->31% on 11-18, 100% by
        # 11-24). The flag is rewritten each scrape while high — the path
        # unit re-arms every time the GC unit goes inactive (plain oneshot,
        # deliberately NO RemainAfterExit: the boot-mirror class-11
        # deaf-trigger trap) — and removed below threshold. The GC service's
        # own stamp (its StateDirectory) rate-limits to one sweep per 6h.
        systemd.paths.rust-cache-reclaim = lib.mkIf cfg.gc.enable {
          description = "Trigger rust-cache-gc when rust-cache usage crosses the reclaim threshold";
          wantedBy = [ "multi-user.target" ];
          unitConfig.ConditionPathIsMountPoint = cfg.mountPoint;
          pathConfig = {
            PathChanged = [ "/run/rust-cache-reclaim.flag" ];
            Unit = "rust-cache-gc.service";
          };
        };

        # Service-integration registry entry: the Rust cache SSD textfile metric
        # checks gated on this module.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          rust-cache = {
            inherit (cfg) enable;
            vHost.layer = "none";
            checks = [
              {
                name = "Rust Cache SSD";
                group = "Filesystem";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] != pat(*rustcache_mounted 0\n*)"
                  "[BODY] == pat(*\nrustcache_mounted *)"
                  "[BODY] != pat(*rustcache_smart_healthy 0\n*)"
                  "[BODY] == pat(*\nrustcache_smart_healthy *)"
                ];
                alert = "Rust cache SSD (/mnt/rust-cache) unmounted or SMART-failing - cargo/rustc builds will fail with missing-directory errors. Check: findmnt /mnt/rust-cache, sudo smartctl -d sat -H /dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713. If the drive died: revert SCCACHE_DIR/CARGO_HOME in platforms/nixos/users/home.nix and rebuild on NVMe.";
              }
              {
                name = "Rust Cache Usage";
                group = "Filesystem";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "30m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] != pat(*rustcache_mounted 0\n*)"
                  "[BODY] == pat(*\nrustcache_mounted *)"
                  "[BODY] == pat(*\nrustcache_usage_over_threshold 0*)"
                ];
                alert = "Rust cache SSD over 85% — STANDING-STATE advisory, not a page (this alert reads red for days on this box; the 95% CRITICAL tier is the actionable one). Plan headroom: the usage-triggered GC (rust-cache-reclaim.path + fingerprint-orphan sweep) reclaims what it can; residents are a placement decision — see docs/agents/storage.md.";
              }
              {
                name = "Rust Cache Critical";
                group = "Filesystem";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] != pat(*rustcache_mounted 0\n*)"
                  "[BODY] == pat(*\nrustcache_mounted *)"
                  "[BODY] == pat(*\nrustcache_usage_critical 0*)"
                ];
                alert = "Rust cache SSD >=95% — one cargo wave from the freeze class (freezes #60-63, 2026-11-22..24, all rode >=96% usage + build batteries). The cargo-gate wrapper refuses builds on a disk this full; reclaim headroom NOW: monitor365 `bash scripts/target-gc.sh --apply` (cargo-idle) or cargo clean a resident. Structural note: demand ~265G vs 224G supply — shrink/placement is the owner decision pending (docs/agents/storage.md, 2026-11-18 verdict).";
              }
            ];
          };
        };
      };
    };
}
