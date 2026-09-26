{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (import ../../../lib/default.nix lib) harden onFailure serviceOneshotDefaults;
  rootDevice = config.fileSystems."/".device;
  primaryUser = config.users.primaryUser;
  # Forgejo dedicated-subvolume storage (forgejo.nix option): the 8h btrbk
  # leg below only exists once it is enabled — `or false` keeps other hosts'
  # evals clean when the forgejo module is not imported.
  forgejoDedicated = config.services.forgejo.dedicatedSubvolume or false;

  # Only @cache-home remains as a cache subvolume. The other three
  # (@go, @npm, @cargo) were removed 2026-08-17: their contents moved to
  # /mnt/buildcache (GOMODCACHE, npm_config_cache) or were stale, and plain
  # ~/go / ~/.npm dirs inside @ hold nothing churning. @cache-home stays
  # because it still carries ~37 GB of LIVE app caches (measured 2026-09-18
  # during the Samsung cache-tier assessment) that have no
  # buildcache home (nix flake eval cache, browser caches, gopls…) —
  # its snapshot-exclusion from btrbk's @ snapshots is exactly its job.
  # Deleting it would push all that churn into daily @ snapshots + pool
  # sends. Revisit only if those caches get their own off-NVMe home.
  cacheSubvolumes = {
    "@cache-home" = "/home/${primaryUser}/.cache";
  };

  cacheFileSystems = lib.mapAttrs' (subvol: mountPoint: {
    name = mountPoint;
    value = {
      device = rootDevice;
      fsType = "btrfs";
      options = [
        "subvol=${subvol}"
        "compress=zstd"
        "noatime"
        "nodiscard"
        "commit=300"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=10min"
      ];
    };
  }) cacheSubvolumes;

  # Dedicated @home-hermes subvolume for the Hermes Agent Gateway state
  # (2026-09-15): pulls agent-workspace churn out of btrbk's @ snapshots and
  # gives hermes state its own mount + backup policy. Declared ONLY while
  # hermes runs on this host; the subvolume itself is created by
  # scripts/migrate-hermes-subvol.sh (runbook: docs/services/hermes.md).
  # Deliberately NOT the cacheSubvolumes automount style: hermes has tmpfiles
  # rules under /home/hermes, and automount + tmpfiles is the shadow-dir class
  # (dirs silently created on @ under the mountpoint). A plain mount orders
  # before local-fs.target, so tmpfiles-setup only ever sees the mounted
  # subvolume. nofail per the non-root-mount rule; hermes.service's
  # RequiresMountsFor fails loudly when the subvol is absent, so a
  # deploy-before-prepare is loud but safe (see the migration script).
  hermesHomeMount = lib.optionalAttrs (config.services.hermes.enable or false) {
    "/home/hermes" = {
      device = rootDevice;
      fsType = "btrfs";
      options = [
        "subvol=@home-hermes"
        "noatime"
        "compress=zstd"
        "nodiscard"
        "commit=300"
        "nofail"
      ];
    };
  };

  # Rust projects whose target/ dirs should live on ext4 — avoids COW
  # fragmentation from 85K+ small files and keeps them out of btrbk snapshots.
  # Target dirs moved from the old /rust-cache NVMe partition (p9) to the USB
  # SSD build cache (services.buildcache) on 2026-08-14: removes build churn
  # from the QLC NVMe entirely. Dirs are created by buildcache-init (post-
  # mount); only the ~/projects/<p>/target symlinks are managed here.
  rustCacheProjects = [ "monitor365" ];

  rustCacheLinks = builtins.map (
    p: "L+ /home/${primaryUser}/projects/${p}/target - - - - /mnt/buildcache/rust/${p}"
  ) rustCacheProjects;

  # Scrub deferral guard (2026-08-31 freeze lesson). The nixpkgs autoScrub
  # units run `btrfs scrub start -B <mnt>` at IOSchedulingClass=idle, but BFQ
  # priority does not stop the BYTES: a scrub is a full-filesystem read, and
  # stacked on the same QLC NVMe as a btrbk send (or a flm cold load) it
  # saturates the NAND, drives sustained memory-PSI refault stalls, and —
  # live 2026-08-31 16:34 — froze the box with zram empty and zero OOM kills.
  # Weekly scrub is deferrable housekeeping: skip the run when anything
  # heavier is already streaming (next week retries). The skip is NOT silent:
  # btrfs-health metrics keep reporting scrub status, so a perpetually
  # skipped scrub shows up as never-finished (Gatus-visible), not phantom-green.
  scrubGuard = pkgs.writeShellApplication {
    name = "btrfs-scrub-guard";
    runtimeInputs = [
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.gawk
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail
      mnt="''${1:?usage: btrfs-scrub-guard <mountpoint>}"

      # Guard 0 (same doctrine as btrfs-balance-*): never scrub under IO or
      # zram pressure — a manual balance at 99% IO PSI froze the machine
      # (2026-08-24); scrub is the same full-device reader class.
      PSI_IO_SOME=$(awk '/^some/ {for (i = 2; i <= NF; i++) if ($i ~ /^avg10=/) {sub(/^avg10=/, "", $i); printf "%d", $i; exit}}' /proc/pressure/io)
      ZRAM_ORIG=$(awk '{print $1}' /sys/block/zram0/mm_stat 2>/dev/null) || ZRAM_ORIG=0
      ZRAM_DISKSIZE=$(cat /sys/block/zram0/disksize 2>/dev/null) || ZRAM_DISKSIZE=0
      ZRAM_PCT=0
      if [ "''${ZRAM_DISKSIZE:-0}" -gt 0 ] 2>/dev/null; then
        ZRAM_PCT=$(( ''${ZRAM_ORIG:-0} * 100 / ZRAM_DISKSIZE ))
      fi
      if [ "''${PSI_IO_SOME:-0}" -ge 20 ] || [ "$ZRAM_PCT" -ge 80 ]; then
        echo "btrfs-scrub: deferring scrub of $mnt — IO PSI some avg10=''${PSI_IO_SOME}% (>=20) or zram ''${ZRAM_PCT}% full (>=80); scrubbing under pressure froze the machine (2026-08-24/31 classes). Next weekly window retries."
        exit 0
      fi

      # Guard 1: never stack a full-fs read on a live btrbk send or balance —
      # the 2026-08-31 16:34 freeze stacked scrub on / AND /data (Persistent
      # boot catch-up after the 9-day DAS outage) on top of the btrbk-data
      # full re-send and four flm cold loads. NOTE: btrbk/balance units are
      # Type=oneshot — mid-send they sit in "activating", and
      # `systemctl is-active --quiet` returns NON-ZERO for that state, so the
      # naive check would miss exactly the streaming case it exists for
      # (self-review catch, 2026-08-31 17:25). Compare ActiveState explicitly.
      for heavy in btrbk-root.service btrbk-data.service btrbk-pool.service btrfs-balance-metadata.service btrfs-balance-data.service; do
        heavy_state=$(systemctl show -p ActiveState --value "$heavy" 2>/dev/null || echo inactive)
        if [ "$heavy_state" = "active" ] || [ "$heavy_state" = "activating" ]; then
          echo "btrfs-scrub: deferring scrub of $mnt — $heavy is streaming (state=$heavy_state); stacking full-device readers saturated the QLC NVMe and froze the box (2026-08-31 16:34). Next weekly window retries."
          exit 0
        fi
      done

      exec btrfs scrub start -B "$mnt"
    '';
  };

  # btrbk-data EIO repair gate (2026-09-11, docs/todo/storage.md /data repair item).
  # The /data -> pool send has been structurally dead since 2026-07 (EIO csum
  # errors from the unsafe-partition-shrink corruption), yet every nightly
  # run still READ the full ~258G tree for ~3h12m before dying (18G
  # page-cache peak = the oom-kill failure mode, ~329G written) — ~8TB/month
  # of pointless QLC reads. Owner stance: btrbk-data keeps FAILING (the
  # failure is the tripwire), so this gate makes the failure CHEAP instead
  # of removing it: while the marker is absent it takes the cheap local CoW
  # snapshot + retention prune (the /data rollback tier never missed a
  # night — only the send died) and then exits 1, so OnFailure still fires
  # nightly and ExecStart (the expensive `btrbk run` send) never starts.
  # With the marker present it exits 0 and the normal nightly run proceeds.
  # Remove this gate (and the btrfs-verify-pool-backups WARN-only /data
  # branch) when the T04-T08 repair executes.
  btrbkDataGate = pkgs.writeShellApplication {
    name = "btrbk-data-repair-gate";
    runtimeInputs = [
      pkgs.btrbk
      pkgs.coreutils
    ];
    text = ''
      if [ -f /data/.repair-done ]; then
        exit 0
      fi
      echo "btrbk-data: /data EIO repair gate ACTIVE (no /data/.repair-done marker) — taking local snapshot + retention prune, then deliberate fast-fail"
      if ! btrbk -c /etc/btrbk/data.conf snapshot; then
        echo "btrbk-data: local snapshot ALSO failed — inspect /data health before the repair run" >&2
      fi
      if ! btrbk -c /etc/btrbk/data.conf prune; then
        echo "btrbk-data: retention prune failed — snapshots may accumulate while the gate is active" >&2
      fi
      echo "btrbk-data: nightly pool send deliberately SKIPPED (known /data EIO, docs/todo/storage.md P0). This failure is the tripwire and is EXPECTED while the marker is absent; remove the gate after the T04-T08 repair." >&2
      exit 1
    '';
  };
in
{
  fileSystems = {
    "/mnt/btrfs-root" = {
      device = rootDevice;
      fsType = "btrfs";
      options = [
        "noatime"
        "compress=zstd"
        "nodiscard"
        "commit=300"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=10min"
      ];
    };
  }
  // cacheFileSystems
  // hermesHomeMount;

  services = {
    btrbk.instances."root" = {
      # Stagger BEFORE nix-gc (which fires at 00:00) so expired snapshots are
      # deleted first. This lets GC reclaim data extents freed by snapshot expiry.
      # If btrbk and GC ran concurrently, GC couldn't free CoW-shared extents.
      # See docs/crash-analysis-2026-06-26.md — the metadata ratchet section.
      #
      # snapshotOnly=false since 2026-08-16: each nightly snapshot is also
      # sent incrementally to the mirrored HDD pool (/mnt/pool/backups/root).
      # This closes the #1 data-loss risk: all snapshots used to live on the
      # single QLC NVMe that dies with the machine. Offsite leg is covered by
      # the user's Google Photos/Drive (see the 3-drive repurposing plan doc).
      onCalendar = "23:00";
      snapshotOnly = false;
      settings = {
        # LOCAL retention ~1/4 of the old policy (was 14d 4w, user decision
        # 2026-08-21): snapshots pin deleted extents on the space-tight QLC
        # NVMe; local tier only needs rollback + incremental-send-parent duty.
        # The pool (below) is the real history tier.
        #
        # Calendar anchors (btrbk 0.32.7 schedule(), source-verified
        # 2026-09-25 + re-verified in-source 2026-09-26): retention keeps the
        # FIRST snapshot of each calendar bucket group. "3d" keeps the first
        # snapshot of each delta_days group <= 3 (day boundaries are
        # hour-of-day corrected, 00:00 default) — at the nightly 23:00
        # cadence that is 4 dailies (run day + 3 back), one rotating out per
        # night. "1w" keeps the FIRST snapshot of each of the TWO calendar
        # weeks covered (delta_weeks <= 1, weeks start Sunday per
        # preserve_day_of_week default), so a Sunday-dated weekly lives
        # exactly 14 days. The root pin window is therefore 2w sharp, NOT
        # "3d+1w" (~10d) flat.
        snapshot_preserve_min = "2d";
        snapshot_preserve = "3d 1w";
        # Pool = FOREVER (user decision 2026-08-21): target_preserve_min = "all"
        # disables automatic deletion of received backups entirely. Space cost
        # stays near raw data churn — received subvolumes share extents via CoW
        # on the pool (snapshot count is ~free; every DELETED byte on the NVMe
        # is pinned pool-side forever, which is the point). 16T RAID1 headroom
        # makes this viable for years; revisit only if pool usage crosses ~50%.
        target_preserve_min = "all";
        volume."/mnt/btrfs-root" = {
          snapshot_dir = "/mnt/btrfs-root/.snapshots";
          # Disjoint keys merged explicitly — a `//` one level up would drop
          # the `subvolume` key of the left branch entirely (the 2026-09-14
          # integration.nix shallow-merge class).
          subvolume = {
            "@" = {
              target = "/mnt/pool/backups/root";
            };
          }
          // lib.optionalAttrs (config.services.hermes.enable or false) {
            # Hermes state subvolume (2026-09-15): own pool target with
            # BOUNDED retention. @'s target_preserve_min="all" would hoard
            # agent workspace churn on the pool forever (the motivating
            # problem — every byte hermes ever deleted is pinned pool-side
            # today); 7d min / 14d 4w keeps skills, cron, memories and
            # sessions off-NVMe without the forever tier. Local snapshot
            # retention inherits the volume-level 2d / 3d 1w. Receives land
            # in the SAME pool dir as @ — btrfs-verify-pool-backups checks
            # both prefixes.
            "@home-hermes" = {
              target = "/mnt/pool/backups/root";
              target_preserve_min = "7d";
              target_preserve = "14d 4w";
            };
          };
        };
      };
    };

    # /data is a separate BTRFS filesystem (subvolid=5, toplevel) containing
    # Docker volumes, Immich DB, AI models. Snapshots are crash-consistent.
    # The "." subvolume refers to the BTRFS toplevel. Nested subvolumes (like
    # .snapshots itself) are automatically excluded from snapshots by BTRFS.
    # Since 2026-08-16 snapshots are also sent to /mnt/pool/backups/data.
    btrbk.instances."data" = {
      onCalendar = "23:30";
      snapshotOnly = false;
      settings = {
        snapshot_preserve_min = "7d";
        snapshot_preserve = "14d 4w";
        target_preserve_min = "7d";
        target_preserve = "30d 12w";
        volume."/data" = {
          snapshot_dir = "/data/.snapshots";
          subvolume."." = {
            target = "/mnt/pool/backups/data";
          };
        };
      };
    };

    # Local snapshots of the per-service subvolumes ON the pool itself
    # (23:45, after the NVMe instances, before nix-gc at 00:00). Protects
    # against app-level corruption / accidental deletion on the pool:
    # immich media, paperless documents, atticd NAR storage, monitor365
    # buffer, discordsync attachments (pool-native since the 2026-09-22
    # BLOB re-scope of the Own-tools NVMe→pool leg — the discordsync DB
    # stays on NVMe for the Phase-2 hot-db wave). browser-history has NO
    # pool leg: the 2026-09-21 Phase-2 verdicts put its DB on the Samsung
    # hot tier, and its only other state is the DB-dump dir
    # (/mnt/pool/backups/browser-history, covered by the dump + retention).
    # The empty services/browser-history subvol remains on the pool disk
    # from the 2026-08-16 layout (removal needs root; nothing references it).
    btrbk.instances."pool" = {
      onCalendar = "23:45";
      snapshotOnly = true;
      settings = {
        snapshot_preserve_min = "2d";
        snapshot_preserve = "7d 4w";
        volume."/mnt/pool" = {
          snapshot_dir = "/mnt/pool/.snapshots";
          subvolume."services/immich" = { };
          subvolume."services/paperless" = { };
          subvolume."services/atticd" = { };
          subvolume."services/monitor365" = { };
          subvolume."services/discordsync" = { };
          subvolume."services/bank-sync" = { };
          subvolume."services/activitywatch" = { };
          # go-taskqueue journal (services.tq-agent-pool) — task history +
          # watermarks are worth nightly pool snapshots.
          subvolume."services/tq" = { };
        };
      };
    };

    # Forgejo dedicated subvolume (Set-B storage, staged-primary plan gate
    # G1): local snapshots on the Samsung + incremental sends to the HDD
    # pool every 8h. Referenced through the /mnt/hot TOPLEVEL mount (NOT the
    # /var/lib/forgejo dataDir mount) so the leg stays independent of the
    # dataDir mount state — btrbk resolves hot/forgejo from the toplevel.
    # Slots 05/13/21:40 clear of the 23:00-04:00 backup window and the
    # deploy-heavy evening hours; user requirement: backup at least every 8h.
    # Freshness is Gatus-watched via forgejo_subvol_backup_fresh (forgejo.nix
    # collector — 12h threshold = one missed slot tolerated, a dead leg
    # pages within half a day without flapping on a single miss).
    btrbk.instances."forgejo" = lib.mkIf forgejoDedicated {
      onCalendar = "*-*-* 05,13,21:40:00";
      snapshotOnly = false;
      settings = {
        # Local tier: incremental-send parents + short rollback (~9 snaps).
        snapshot_preserve_min = "2d";
        snapshot_preserve = "3d";
        # BOUNDED pool retention (hermes subvol precedent): forgejo state
        # churns (git objects, mirror syncs); forever-pinning was never the
        # goal — the transaction-consistent forgejo dump zips (03:30, 7d)
        # remain the deep-history path.
        target_preserve_min = "7d";
        target_preserve = "14d 8w";
        volume."/mnt/hot" = {
          snapshot_dir = "/mnt/hot/.snapshots";
          subvolume."hot/forgejo" = {
            target = "/mnt/pool/backups/forgejo-subvol";
          };
        };
      };
    };

    # Weekly instead of monthly: the scrub needs ~2h to complete 707 GiB on /data
    # at idle I/O priority. With frequent reboots (58 unsafe shutdowns), a monthly
    # scrub window almost never completes before the next reboot interrupts it.
    # Weekly gives 4x more retry opportunities. The nixpkgs module sets
    # Before=shutdown.target + Conflicts=shutdown.target, so scrub never blocks
    # shutdown — it just gets cancelled and retried next week.
    btrfs.autoScrub = {
      enable = true;
      interval = "weekly";
      fileSystems = [
        "/"
        "/data"
        # Mirrored HDD pool: scrub verifies BOTH raid1 copies match. Weekly is
        # cheap while the pool is near-empty; scrub time grows with usage.
        "/mnt/pool"
      ];
    };

    # Rust target dirs now live on the USB SSD build cache (see rustCacheLinks
    # above). buildcache-init creates the directories after the mount is up.
    buildcache.rustProjects = rustCacheProjects;
  };

  systemd = {
    tmpfiles.rules = rustCacheLinks ++ [
      # btrbk-data needs /data/.snapshots to exist before it can create
      # snapshot subvolumes. Without this, btrbk-data fails with
      # "Failed to fetch subvolume detail for snapshot_dir".
      "d /data/.snapshots 0755 root root -"
      # Pool-side receive targets + snapshot dir. The trailing "-" keeps
      # boot clean when the DAS is detached (nofail); btrbk then fails loudly
      # at 23:00 via RequiresMountsFor + onFailure instead.
      "d /mnt/pool/.snapshots 0755 root root -"
      "d /mnt/pool/backups/root 0755 root root -"
      "d /mnt/pool/backups/data 0755 root root -"
      # Forgejo 8h btrbk leg (gated with the instance above): local snapshot
      # dir on the Samsung + pool-side receive target. Trailing "-" keeps
      # detached-DAS/detached-Samsung boots clean; btrbk fails loudly at the
      # next slot via RequiresMountsFor + onFailure instead.
      "d /mnt/hot/.snapshots 0755 root root -"
      "d /mnt/pool/backups/forgejo-subvol 0755 root root -"
    ];

    services = {
      # btrbk units are Type=oneshot with the global 3min
      # DefaultTimeoutStartSec — far too short for send phases. Observed
      # 2026-08-17: the initial catch-up seed sustained only ~17 MB/s
      # effective through the USB DAS (metadata-heavy nix store + concurrent
      # weekly scrubs) — 6h covered just ~60% of the root send before
      # TimeoutStartSec killed it mid-stream. 24h covers seeds; daily
      # incrementals finish in minutes and never approach the ceiling.
      # Nightly runs are also naturally serialized: a still-active run makes
      # the timer fire skip (systemd does not restart a running oneshot).
      btrbk-root = {
        unitConfig.RequiresMountsFor = [
          "/mnt/pool"
          "/mnt/btrfs-root"
        ];
        serviceConfig = {
          TimeoutStartSec = "24h";
          # btrbk-data oom lesson (2026-08-21): a full-tree send charges its
          # page cache to this unit's cgroup — root re-sends are live since
          # the 2026-09-12 snapshot-loss scenario, so the same 20.6G class
          # applies. MemoryHigh throttles reclaim instead of letting oomd
          # kill a send that was making progress; OOMScoreAdjust = -250
          # keeps the restart-expensive nightly send out of oomd's preferred
          # victims (flm at +300 stays the designated sacrifice).
          MemoryHigh = "4G";
          OOMScoreAdjust = -250;
        };
        inherit onFailure;
      };
      btrbk-data = {
        unitConfig.RequiresMountsFor = [
          "/mnt/pool"
          "/data"
        ];
        serviceConfig = {
          TimeoutStartSec = "24h";
          # EIO repair gate (see btrbkDataGate above): fails the unit in
          # ~seconds while /data/.repair-done is absent — OnFailure semantics
          # preserved, the ~258G full-tree send read never starts. Any future
          # unit-file churn that makes stc restart this chronically-failing
          # unit also now costs seconds, not a 3h re-send (2026-09-09
          # exit-4 class, bounded but not eliminated — the failure stance is
          # deliberate).
          ExecStartPre = "${lib.getExe btrbkDataGate}";
          # oom-kill containment (2026-08-21 incident): the full-tree send
          # charged 20.6G of PAGE CACHE to this unit's cgroup, making btrbk-data
          # the largest /system.slice consumer — systemd-oomd picked it under
          # pressure and killed a send that was otherwise making progress.
          # MemoryHigh (not MemoryMax) throttles: the kernel reclaims the
          # unit's own page cache early, bounding the cgroup without ever
          # killing the send. OOMScoreAdjust = -250 keeps a restart-expensive
          # nightly job (a killed send = hours of QLC re-reads re-paid) out of
          # oomd's preferred victims — flm (+300) remains the designated
          # global-OOM sacrifice.
          MemoryHigh = "4G";
          OOMScoreAdjust = -250;
        };
        inherit onFailure;
      };
      btrbk-pool = {
        unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
        serviceConfig = {
          TimeoutStartSec = "1h";
          # Same treatment as btrbk-data (the nightly walk over services/*
          # charges page cache to this cgroup): throttle early, never become
          # the oomd victim. A snapshot-only run never approaches 4G — the
          # ceiling is pure insurance.
          MemoryHigh = "4G";
          OOMScoreAdjust = -250;
        };
        inherit onFailure;
      };
      btrbk-forgejo = lib.mkIf forgejoDedicated {
        unitConfig.RequiresMountsFor = [
          "/mnt/pool"
          "/mnt/hot"
        ];
        serviceConfig = {
          # First run seeds the whole forgejo tree over the DAS USB link
          # (size unknown until the M17 measurement; 6h covers a worst-case
          # multi-GiB seed at DAS-realistic throughput). 8h incrementals
          # finish in seconds-to-minutes and never approach the ceiling.
          TimeoutStartSec = "6h";
          # btrbk-data oom lesson: page cache of the send is charged to this
          # cgroup — throttle early instead of becoming an oomd victim.
          MemoryHigh = "4G";
          OOMScoreAdjust = -250;
        };
        inherit onFailure;
      };

      # ── scrub deferral (2026-08-31 freeze lesson) ─────────────────────────
      # Replace the nixpkgs autoScrub ExecStart with the guarded wrapper.
      # ExecStop (btrfs-scrub-maybe-cancel) from the nixpkgs module is kept —
      # it only matters for the shutdown-cancel path, which the wrapper's
      # `exec btrfs scrub start -B` preserves.
      # lib.getExe is REQUIRED: writeShellApplication's store path is a
      # DIRECTORY (script lives at <out>/bin/<name>) — the bare `${scrubGuard}`
      # interpolation 203/EXEC'd every weekly fire since the 2026-09-07 first
      # post-deploy window ("Is a directory" on all three units), silently
      # suspending ALL scrub coverage incl. the /data corruption-delta gate.
      "btrfs-scrub--".serviceConfig.ExecStart = lib.mkForce "${lib.getExe scrubGuard} /";
      btrfs-scrub-data.serviceConfig.ExecStart = lib.mkForce "${lib.getExe scrubGuard} /data";
      btrfs-scrub-mnt-pool.serviceConfig.ExecStart = lib.mkForce "${lib.getExe scrubGuard} /mnt/pool";

      # ── btrbk clean: GC for garbled receive targets ────────────────────────
      # `btrbk clean` is btrbk's sanctioned garbage collector for incomplete
      # (interrupted-receive) target subvolumes. It deletes ONLY subvolumes
      # whose receive never committed (no received_uuid) — never complete
      # backups, never sources — and is REQUIRED after any interrupted send:
      # a garbled target subvolume with the target name BLOCKS btrbk from
      # re-sending that snapshot ("exists, but is not a receive target" →
      # "Skipping backup" → permanent history gap under keep-forever target
      # retention). Live case 2026-08-21: root @.20260814/15T2300 (Aug 17
      # seed-era TimeoutStartSec interruptions; local sources still existed →
      # clean unblocked the automatic nightly re-send, healing the chain) and
      # data.20260721T2330 (source long pruned → garbage removal only; the
      # /data seed itself still aborts on the known EIO inode, TODO P0).
      # Timer 23:50 = after all three btrbk windows; After= holds the start
      # while a long seed (24h TimeoutStartSec) is still streaming, so clean
      # never races a live receive. deploy.sh starts it --no-block post-switch
      # so deploy-time heals land before the next nightly window.
      btrbk-pool-clean = {
        description = "btrbk clean: delete incomplete (garbled) receive targets on the pool";
        unitConfig = {
          RequiresMountsFor = [ "/mnt/pool" ];
          After = [
            "btrbk-root.service"
            "btrbk-data.service"
            "btrbk-pool.service"
          ];
        };
        path = [
          pkgs.btrbk
          pkgs.btrfs-progs
          pkgs.coreutils
        ];
        startLimitBurst = 3;
        startLimitIntervalSec = 3600;
        inherit onFailure;
        serviceConfig = lib.mkMerge [
          {
            Type = "oneshot";
            # Runs as the btrbk user: the sudo allowlist (backend
            # btrfs-progs-sudo) already covers subvolume list/show/delete —
            # the same commands nightly pruning uses. Deliberately NOT
            # harden {}: NoNewPrivileges would break the setuid sudo
            # wrapper, and User=btrbk must keep its sudo identity.
            User = "btrbk";
            Group = "btrbk";
            StateDirectory = "btrbk";
            Nice = 10;
            IOSchedulingClass = "best-effort";
            TimeoutStartSec = "30min";
          }
          (serviceOneshotDefaults { })
        ];
        script = ''
          # Aggregate failures: one bad config must never mask the others.
          export PATH=/run/wrappers/bin:$PATH
          failed=0
          for conf in root data pool; do
            echo ":: btrbk clean ($conf)"
            if ! btrbk -c /etc/btrbk/$conf.conf clean; then
              echo "ERROR: btrbk clean failed for $conf.conf" >&2
              failed=1
            fi
          done
          exit $failed
        '';
      };

      # Mirrored-pool Prometheus metrics (mount presence with real-I/O gate,
      # usage, free/total). Same always-write-the-.prom contract as
      # buildcache-metrics: a detached DAS flips pool_mounted to 0 and Gatus
      # alerts instead of serving a stale green file. df on an unmounted
      # /mnt/pool would report the ROOT filesystem's numbers — the mounted
      # gate must run before any usage math.
      pool-metrics = {
        description = "Mirrored HDD pool Prometheus metrics";
        startLimitBurst = 3;
        startLimitIntervalSec = 300;
        path = [
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
            ReadWritePaths = [ "/var/lib/prometheus-node-exporter/textfile_collectors" ];
            # Sticky-dir rename over a foreign-owned prom (mail-relay
            # 2026-09-02..06 class).
            CapabilityBoundingSet = "CAP_FOWNER";
            MemoryMax = "128M";
          })
          (serviceOneshotDefaults { })
        ];
        script = ''
          set -eu
          OUT="/var/lib/prometheus-node-exporter/textfile_collectors/pool.prom"
          # Unique tmp per run (mktemp): a fixed .tmp name collides with
          # stale foreign-owned leftovers in the sticky 1777 textfile dir
          # (mail-relay 2026-09-02..06 outage class).
          mkdir -p "/var/lib/prometheus-node-exporter/textfile_collectors"
          TMP="$(mktemp "/var/lib/prometheus-node-exporter/textfile_collectors/pool.prom.XXXXXX")"
          chmod 644 "$TMP"
          trap 'rm -f "$TMP"' EXIT
          mnt="/mnt/pool"
          threshold=85

          mounted=0
          if
            findmnt -n -o TARGET "$mnt" 2>/dev/null | grep -qx "$mnt" \
              && timeout 15 ls -A "$mnt" >/dev/null 2>&1
          then
            mounted=1
          fi

          usage=0
          over=0
          free_bytes=0
          total_bytes=0
          if [ "$mounted" = 1 ]; then
            usage="$(df --output=pcent "$mnt" | tail -n1 | tr -dc '0-9')"
            free_bytes="$(df -B1 --output=avail "$mnt" | tail -n1 | tr -dc '0-9')"
            total_bytes="$(df -B1 --output=size "$mnt" | tail -n1 | tr -dc '0-9')"
            if [ "''${usage:-0}" -ge "$threshold" ] 2>/dev/null; then
              over=1
            fi
          fi

          mkdir -p "/var/lib/prometheus-node-exporter/textfile_collectors"
          cat > "$TMP" <<METRICS
          # HELP pool_mounted 1 if the mirrored HDD pool is mounted, 0 otherwise
          # TYPE pool_mounted gauge
          pool_mounted ''${mounted}
          # HELP pool_usage_percent Pool filesystem usage percentage (0-100)
          # TYPE pool_usage_percent gauge
          pool_usage_percent ''${usage}
          # HELP pool_usage_over_threshold 1 if usage >= 85%
          # TYPE pool_usage_over_threshold gauge
          pool_usage_over_threshold ''${over}
          # HELP pool_free_bytes Free bytes on the pool filesystem
          # TYPE pool_free_bytes gauge
          pool_free_bytes ''${free_bytes}
          # HELP pool_total_bytes Total bytes on the pool filesystem
          # TYPE pool_total_bytes gauge
          pool_total_bytes ''${total_bytes}
          METRICS
          mv "$TMP" "$OUT"
        '';
      };

      # Fail-loud guard for the pool safety net: mount presence, raid1 mirror
      # health (a single dropped member keeps serving but halves redundancy),
      # and freshness of the received NVMe backups on both targets. A silently
      # broken send must alert, not linger as a phantom backup.
      "btrfs-verify-pool-backups" = {
        description = "Verify pool mount, mirror health, and backup freshness";
        inherit onFailure;
        path = [
          pkgs.btrfs-progs
          pkgs.util-linux
          pkgs.systemd
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
          # gawk is REQUIRED by the mirror-health check below. Without it the
          # `if btrfs device stats | awk …` condition evaluates false on
          # "command not found" (pipefail inside `if` is non-fatal) and the
          # check silently passes — a phantom green observed live 2026-08-18
          # ("awk: command not found" in the unit journal while the unit
          # reported the device-stats branch as clean).
          pkgs.gawk
        ];
        serviceConfig = lib.mkMerge [
          (harden {
            PrivateDevices = false; # btrfs ioctls go through the mount path
            ProtectSystem = "true";
          })
          { Type = "oneshot"; }
        ];
        script = ''
          set -euo pipefail
          MAX_AGE_DAYS=3
          # 2-day early-warning boundary: one storm-eaten nightly send must
          # surface a full day BEFORE the 3-day gate can FAIL (2026-09-17 §f.5:
          # the single FAIL tier was too late to act on; 2026-09-19/20 both
          # root sends were guard-stopped mid-send while the gate stayed green).
          WARN_AGE_DAYS=2

          findmnt -n /mnt/pool >/dev/null || { echo "FAIL: /mnt/pool is not mounted"; exit 1; }

          if btrfs device stats /mnt/pool | awk '$NF+0 > 0 {found=1} END {exit !found}'; then
            echo "FAIL: btrfs device stats report errors on the pool:"
            btrfs device stats /mnt/pool
            exit 1
          fi

          # Freshness is checked PER PREFIX: receive names are
          # <subvol>.YYYYMMDDTHHMM, and @home-hermes.* sorts AFTER @.* — a
          # plain `sort | tail -1` over the whole dir judged only the
          # lexically-last subvolume and stayed green while the other's sends
          # died (fixed with the 2026-09-15 hermes-subvol migration).
          check_freshness() {
            local dir=$1 prefix=$2 fatal=$3
            local latest name datestr snap_epoch age_days
            latest=$(find "$dir" -maxdepth 1 -mindepth 1 -type d -name "$prefix.*" 2>/dev/null | sort | tail -1) || true
            if [ -z "$latest" ]; then
              if [ "$fatal" = "yes" ]; then
                echo "FAIL: no received backups for prefix '$prefix' in $dir"
                exit 1
              fi
              echo "WARN: no received backups for prefix '$prefix' in $dir"
              return
            fi
            # Received subvols keep the snapshot name; parse the date from
            # the NAME (see btrfs-verify-snapshots for why stat mtime lies).
            name=$(basename "$latest")
            datestr="''${name##*.}"
            datestr="''${datestr%%T*}"
            if [ ''${#datestr} -ne 8 ]; then
              echo "FAIL: could not parse date from backup name: $name"
              exit 1
            fi
            snap_epoch=$(date -d "''${datestr:0:4}-''${datestr:4:2}-''${datestr:6:2}" +%s)
            age_days=$(( ($(date +%s) - snap_epoch) / 86400 ))
            if [ "$age_days" -gt "$MAX_AGE_DAYS" ]; then
              if [ "$fatal" = "yes" ]; then
                echo "FAIL: prefix '$prefix' in $dir: newest backup is $age_days days old (threshold: $MAX_AGE_DAYS)"
                exit 1
              fi
              echo "WARN: prefix '$prefix' in $dir: newest backup is $age_days days old"
              return
            fi
            if [ "$age_days" -ge "$WARN_AGE_DAYS" ]; then
              echo "WARN: prefix '$prefix' in $dir: newest backup is $age_days day(s) old (past the ''${WARN_AGE_DAYS}d early-warning boundary; the ''${MAX_AGE_DAYS}d gate FAILs if tonight's send does not land)"
              return
            fi
            echo "OK: $dir prefix '$prefix' newest backup is $age_days day(s) old"
          }

          # @home-hermes receives are only EXPECTED once the host actually
          # mounts the subvolume — pre-migration generations must stay green.
          # Probe the mount UNIT, never the mountpoint: harden{}'s
          # ProtectHome=true hides /home from this unit's namespace, so a
          # findmnt probe here always fails and the gate silently skips
          # (phantom green live 2026-09-17 00:46 — zero hermes receives,
          # check passed).
          hermes_expected=no
          if systemctl is-active --quiet home-hermes.mount; then
            hermes_expected=yes
          fi

          check_freshness /mnt/pool/backups/root "@" yes
          if [ "$hermes_expected" = "yes" ]; then
            check_freshness /mnt/pool/backups/root "@home-hermes" yes
          fi
          # /data stays WARN-only while the /data EIO corruption stance holds
          # (docs/todo/storage.md): btrbk-data has not completed a receive since
          # 2026-08-20, so a hard FAIL here exit-4'd EVERY activation that
          # touched this unit file (2026-09-08/09: two un-anchored
          # generations, reboot-revert hazard). The gap stays visible via
          # btrbk-data OnFailure, backup-coordination, and Gatus
          # backup_all_healthy. Restore hard-FAIL after the corruption repair.
          check_freshness /mnt/pool/backups/data "data" no
        '';
      };

      "btrfs-verify-snapshots" = {
        description = "Verify BTRFS snapshot freshness";
        inherit onFailure;
        path = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.util-linux
          pkgs.gnugrep
        ];
        serviceConfig = lib.mkMerge [
          (harden { })
          {
            Type = "oneshot";
            ProtectSystem = "true";
            ReadWritePaths = [ ];
          }
        ];
        script = ''
          set -euo pipefail
          MAX_AGE_DAYS=3

          SNAP_DIR="/mnt/btrfs-root/.snapshots"
          if [ ! -d "$SNAP_DIR" ]; then
            echo "WARNING: No snapshots directory ($SNAP_DIR)"
            exit 1
          fi

          LATEST=$(find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name '@.*' | sort | tail -1) || true || true
          if [ -z "$LATEST" ]; then
            echo "WARNING: No root snapshots found"
            exit 1
          fi

          # Parse the snapshot creation date from the NAME, not from stat.
          # BTRFS snapshots inherit the source subvolume's root directory mtime,
          # so stat -c %Y returns the SOURCE mtime (e.g. Jun 26 when the root
          # dir was last changed), not when the snapshot was taken. This caused
          # false "24 days old" alerts despite daily snapshots being fresh.
          # btrbk names snapshots as @.YYYYMMDDTHHMM.
          SNAP_NAME=$(basename "$LATEST")
          SNAP_DATESTR="''${SNAP_NAME#@.}"
          SNAP_DATESTR="''${SNAP_DATESTR%%T*}"
          if [ ''${#SNAP_DATESTR} -ne 8 ]; then
            echo "WARNING: Could not parse date from snapshot name: $SNAP_NAME"
            exit 1
          fi
          SNAP_EPOCH=$(date -d "''${SNAP_DATESTR:0:4}-''${SNAP_DATESTR:4:2}-''${SNAP_DATESTR:6:2}" +%s)
          NOW_EPOCH=$(date +%s)
          AGE_DAYS=$(( (NOW_EPOCH - SNAP_EPOCH) / 86400 ))

          if [ "$AGE_DAYS" -gt "$MAX_AGE_DAYS" ]; then
            echo "WARNING: Root snapshot is $AGE_DAYS days old (threshold: $MAX_AGE_DAYS)"
            exit 1
          fi

          echo "OK: Root snapshot is $AGE_DAYS day(s) old"

          # @home-hermes (hermes state subvolume, 2026-09-15): its snapshots
          # live in the same SNAP_DIR but never match the '@.*' glob above.
          # Check it only while the host actually mounts the subvolume, so
          # pre-migration generations stay green.
          if findmnt -n /home/hermes 2>/dev/null | grep -q '@home-hermes'; then
            H_LATEST=$(find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name '@home-hermes.*' | sort | tail -1) || true || true
            if [ -z "$H_LATEST" ]; then
              echo "WARNING: No @home-hermes snapshots found while the subvolume is mounted"
              exit 1
            fi
            H_NAME=$(basename "$H_LATEST")
            H_DATESTR="''${H_NAME#@home-hermes.}"
            H_DATESTR="''${H_DATESTR%%T*}"
            if [ ''${#H_DATESTR} -ne 8 ]; then
              echo "WARNING: Could not parse date from snapshot name: $H_NAME"
              exit 1
            fi
            H_EPOCH=$(date -d "''${H_DATESTR:0:4}-''${H_DATESTR:4:2}-''${H_DATESTR:6:2}" +%s)
            H_AGE=$(( ($(date +%s) - H_EPOCH) / 86400 ))
            if [ "$H_AGE" -gt "$MAX_AGE_DAYS" ]; then
              echo "WARNING: @home-hermes snapshot is $H_AGE days old (threshold: $MAX_AGE_DAYS)"
              exit 1
            fi
            echo "OK: @home-hermes snapshot is $H_AGE day(s) old"
          fi
        '';
      };
    };

    timers."btrfs-verify-snapshots" = {
      description = "Verify BTRFS snapshot freshness daily";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      wantedBy = [ "timers.target" ];
    };

    timers.pool-metrics = {
      description = "Collect mirrored pool metrics every 5 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
        Persistent = true;
      };
    };

    timers."btrfs-verify-pool-backups" = {
      description = "Verify pool safety net daily";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      wantedBy = [ "timers.target" ];
    };

    # 23:50 = after all three btrbk windows (23:00/23:30/23:45). The service's
    # After= ordering additionally holds the start while any btrbk run is still
    # active (e.g. a 24h seed), so clean never races a live receive.
    timers.btrbk-pool-clean = {
      description = "Nightly btrbk clean (garbled-receive GC) after all btrbk runs";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "23:50";
        Persistent = true;
        AccuracySec = "5min";
      };
    };
  };
}
