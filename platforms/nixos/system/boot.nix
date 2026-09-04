{
  pkgs,
  lib,
  ...
}:
let
  inherit (import ../../../lib/default.nix lib) ioTier;

  # Ceiling for active GPU buffer object allocations (TTM pages, 4 KiB each).
  # 31457280 pages × 4096 = 120 GiB. GTT-first architecture (2026-09-02): the BIOS
  # UMA carveout is 512 MiB, so ALL real GPU memory is GTT (= shared system RAM);
  # the driver reports GTT total ≈ MemTotal (~125 GiB after the small carveout).
  # This ceiling is ~5 GiB below that so TTM refuses allocations before the box is
  # fully pinned. Still a CEILING, not a reservation.
  ttmPagesLimit = 31457280;

  # Pool cache for freed BO pages — pages retained for GPU reuse instead of returned to kernel.
  # 6291456 pages × 4096 = 24 GiB (was 112 GiB — same as pages_limit, which meant freed pages
  # were NEVER returned to the kernel, causing GPUActive=51+ GiB with only desktop workloads).
  # 24 GiB is enough for smooth desktop compositing; excess freed pages return to kernel's free pool.
  ttmPagePoolSize = 6291456;
in
{
  # Bootloader and Kernel Configuration
  boot = {
    # Systemd boot configuration
    loader = {
      timeout = 2;
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 50; # Limit to 50 generations to prevent /boot full
      efi.canTouchEfiVariables = true;
    };

    # Use latest kernel for Ryzen AI Max+ support
    kernelPackages = pkgs.linuxPackages_latest;

    # Verbose boot — surface activation/initrd errors on console instead of silent hang
    initrd.verbose = true;
    consoleLogLevel = 7;

    # ── kdump crash capture (2026-08-22 freeze forensics) ────────────────
    # Both kernel freezes died SILENT (journal cut mid-write, no panic, no
    # dump). softlockup_panic/hung_task_panic never fired: a scheduler
    # LIVELOCK (all CPUs burning in zram refault with IRQs enabled, RCU
    # progressing) pets the hardware watchdog "eventually", never trips the
    # soft-lockup detector, and starves khungtaskd of CPU. Hang detection
    # cannot catch that class — admission control + the emergency guard act
    # BEFORE the cliff; kdump guarantees that when a panic DOES fire (driver
    # bug, hung_task, future policy change) the vmcore lands in /var/crash
    # and the postmortem is a 10-minute read instead of archaeology.
    # Retention is bounded by kdump-retention.service below (root fs is tight).
    crashDump.enable = true;

    # Load I2C module for DDC/CI monitor brightness control
    # Load pstore for kernel panic/oops log capture in UEFI NVRAM
    # Load bfq for responsive I/O scheduling under heavy disk pressure
    kernelModules = [
      "i2c-dev"
      "bfq"
      "usblp"
      # JMS567 DAS bridge (152d:0567) requires UAS at attach time — when uas
      # is not available it vanishes entirely instead of falling back to BOT
      # (private-cloud 2025-11-24: boot-time disappearances until uas was
      # guaranteed loaded; the standard quirks=152d:0567:u fallback caused
      # TOTAL enumeration failure on this exact controller). Pre-loading
      # removes on-demand autoload from the bridge's USB handshake path.
      "uas"
      "usb-storage"
      # Complete the SCSI disk chain resident as well: sd_mod/sg normally
      # autoload on disk appearance, but this bridge family is documented
      # to misbehave when any driver of its attach path is not already
      # resident (see uas note above) — close the whole class.
      "sd_mod"
      "sg"
    ];

    # AMD GPU + NPU optimization kernel parameters for Strix Halo (128GB unified memory)
    kernelParams = [
      # Disabled 2026-04-20: overdrive was causing GPU hangs → niri SIGABRT → full desktop crash.
      # The kernel warns: "amdgpu: Overdrive is enabled, please disable it before reporting any bugs"
      # Re-enable only if you need manual fan/clk control and accept the instability risk.
      # "amdgpu.ppfeaturemask=0xfffd7fff"
      # TPM disabled — saves ~4.3s device enumeration at boot. Not used for measured boot or sealed secrets.
      # Re-enable if you need: TPM-sealed disk encryption (systemd-cryptenroll),
      # measured boot / remote attestation, or Secure Boot with UKI signing.
      "tpm.disabled=1"
      # Increase ring lockup timeout (default 10s) — prevents false-positive GPU resets
      # under heavy compute/ML workloads on Strix Halo
      "amdgpu.lockup_timeout=30000"
      "amdgpu.gpu_recovery=1" # Attempt GPU reset on hang instead of leaving GPU in dead state
      # amd_pstate=performance: bypass firmware frequency management, keep cores at max under load.
      # Previously "guided" (firmware decides freq within min/max). Switched to "performance" to
      # eliminate firmware freq management overhead and maintain max clocks during heavy workloads.
      # The ~130W power ceiling is GMKtec firmware PPT — not OS-controllable (no ryzen_smu for
      # Strix Halo yet, no RAPL constraints exposed, no platform profile in BIOS).
      "amd_pstate=performance"
      # TTM: GTT allocation ceiling. amdgpu.gttsize is GONE in kernel 7.0+ —
      # ttm.pages_limit (here + extraModprobeConfig below) is the only knob.
      "amdgpu.ttm.pages_limit=${toString ttmPagesLimit}"
      # IOMMU enabled — required for full 128GB memory mapping on Strix Halo.
      # Previously set to "off" for ~6% memory read improvement, but this prevented
      # the kernel from seeing the upper 64GB of RAM (only 64GB of 128GB visible).
      "amd_iommu=on"
      # ── pstore: kernel panic/oops log capture in UEFI NVRAM ──────────
      # Survives reboots — critical for diagnosing GPU driver hangs and kernel
      # panics when journald never gets to flush. systemd-pstore auto-mounts /sys/fs/pstore.
      "pstore.backend=efi"
      "pstore.record_console=true"
      "pstore.max_reason=3" # PANIC, OOPS, and WARN
      # Blacklist serial8250 — no physical serial ports on this hardware.
      # Without this, the driver registers phantom ttyS0-S3 devices and systemd
      # waits ~90s for them to appear, adding 1m31s to boot time.
      "module_blacklist=serial8250"
      # Disable NVMe APST (Autonomous Power State Transition) — prevent drive from entering
      # deep power states with high exit latency. Suspected cause of 2m50s device detection
      # delay on GMKtec EVO-X2 (dev-nvme0n1.device waits ~170s for controller to respond).
      # Zero cost on desktop (no battery), could save ~2.5min boot time.
      "nvme_core.default_ps_max_latency_us=0"
      # Removed systemd.log_level=debug and systemd.show_status=true (2026-07-11):
      # These generated massive log I/O in initrd, compounding the BTRFS metadata
      # ENOSPC stall. Every debug log line triggers a BTRFS metadata write for the
      # journal, which takes seconds when metadata allocation is near-full.
      # Result: 3.5min initrd activation (13s CPU, rest pure I/O wait on logging).
      # Keep pstore for crash diagnosis — it writes to NVRAM, not the filesystem.
      # Redirect boot logs to tty2 — SDDM takes over tty1's VT in graphics mode at
      # graphical.target, so the kernel text console on tty1 has no scanout buffer to
      # render to (DRM/KMS exclusive access). tty2 is a plain text VT with getty that
      # SDDM never claims, so all kernel/systemd/activation output is visible there.
      # Ctrl+Alt+F2 = boot log, Ctrl+Alt+F1 = SDDM.
      # console=tty1 is listed last so /dev/console still resolves to tty1 (NixOS default
      # — some services write to /dev/console expecting the primary VT). Once SDDM starts
      # tty1 output is invisible, but tty2 retains the full log.
      "console=tty2"
      "console=tty1"
      # Enable task delay accounting — kernel has CONFIG_TASK_DELAY_ACCT=y compiled in
      # but it's inert without this boot param. iotop shows "CONFIG_TASK_DELAY_ACCT not
      # enabled" without it. Near-zero overhead. eBPF tools (bcc/bpftrace) don't need it
      # but iotop does for SWAPIN%/IO% columns.
      "delayacct"
    ];

    binfmt.emulatedSystems = [ "aarch64-linux" ];

    # Wipe /tmp on every boot — prevents stale nix build caches from accumulating
    # (2011 go-build dirs / 59 GB observed in a single boot cycle)
    tmp.cleanOnBoot = true;
    # NOTE: useTmpfs = false — we define /tmp as a static systemd.mount below.
    # boot.tmp.useTmpfs generates a mount with no size limit (50% RAM = ~47 GiB).
    # systemd.mounts creates a static tmp.mount unit that switch-to-configuration
    # can diff/update atomically. fileSystems."/tmp" generates a runtime fstab
    # entry instead — switch-to-configuration sees the unit disappear and tries
    # to unmount /tmp, which fails (busy) → activation exit code 1.
    tmp.useTmpfs = false;
  };

  # USB HDD enclosure tuning — JMicron JMS567 (152d:0567) BOT bridge
  # Kernel defaults nr_requests=2 for USB mass storage, starving the block layer.
  # With only 2 pending requests, the USB pipe idles between transfers, throttling
  # sequential throughput. nr_requests=128 keeps the pipe saturated — drives are
  # 2x Toshiba MG08ACA16TE (16TB 7200RPM) that deliver ~276 MB/s when unchoked.
  # (REMOVED 2026-08-27: a companion hdparm -S 120 spindown rule matched
  # KERNEL=="sd[ab]" — written for the RETIRED ZFS pool disks, which are gone.
  # sd[ab] now letter-collides with LIVE DAS disks on replug (confirmed topology:
  # sdb+sdd = btrfs pool members, sda = buildcache SSD; letters reshuffle per
  # enumeration). Never match DAS disks by KERNEL letters — if spindown is ever
  # wanted again for specific cold disks, match by ID_SERIAL instead. The active
  # pool must NOT standby anyway: nightly btrbk sends, weekly scrubs, and
  # pool-backed services (paperless/immich/atticd) make 10-min standby cycles
  # pure latency + wear.)
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="block", ATTRS{idVendor}=="152d", ATTRS{idProduct}=="0567", ATTR{queue/nr_requests}="128"
  '';

  # Static /tmp tmpfs mount with explicit 48 GiB size cap.
  # MUST use systemd.mounts (NOT fileSystems) so the unit is in the Nix store
  # closure and switch-to-configuration can track it across generations.
  # size= is a CEILING, not a reservation — RAM is only consumed by files actually
  # written. Stale accumulation is handled by the tmp-cleanup timer in
  # scheduled-tasks.nix (removes untouched entries >4h old).
  systemd.mounts = [
    {
      what = "tmpfs";
      where = "/tmp";
      type = "tmpfs";
      options = "mode=1777,size=48G";
    }
  ];

  # TTM memory pool configuration for GPU workloads (GTT-first, 2026-09-02).
  # 128 GiB physical RAM; BIOS UMA carveout reduced to 512 MiB — visible RAM
  # (~125 GiB) is GTT-shared instead of statically reserved by the iGPU.
  # pages_limit = max pages TTM allocator can grab (ceiling, not reservation):
  # 120 GiB, ~5 GiB below expected MemTotal so GPU pinning fails before the box.
  # page_pool_size = max pages the TTM pool caches for reuse after BO free.
  # MUST STAY SMALL (24 GiB): when pool = pages_limit (112 GiB era), freed GPU
  # pages were never returned to the kernel → GPUActive=51+ GiB with only desktop
  # workloads → chronic memory pressure → BTRFS commit stalls → SQLite lock
  # renewal failures → Pocket ID crash-loop → auth.home.lan down. Do NOT raise it
  # to "match" pages_limit. See docs/status/ for the analysis.
  boot.extraModprobeConfig = ''
    options ttm pages_limit=${toString ttmPagesLimit}
    options ttm page_pool_size=${toString ttmPagePoolSize}
  '';

  # VM sysctl tuning for AI/ML workloads (AMD Ryzen AI MAX+ 395 — 128 GiB physical,
  # ~125 GiB visible to Linux with the 512 MiB BIOS VRAM carveout (GTT-first,
  # 2026-09-02). GPU/CPU share the same RAM via GTT on this unified-memory APU)
  #
  # ZRAM-FIRST RECLAIM STRATEGY (2026-08-13):
  # This machine has zram as its ONLY swap (no disk swap). zram compresses in RAM
  # at ~370 MiB/s — far faster than BTRFS page cache reclaim on QLC NAND (~253ms/write).
  # Therefore we want the kernel to PREFER zram swap over disk page cache reclaim.
  #
  # The old swappiness=10 was BACKWARDS for zram-only: it told the kernel to prefer
  # page cache reclaim (disk I/O) over swap (zram, in RAM), causing BTRFS I/O storms
  # when memory pressure rose. swappiness=150 makes the kernel prefer zram swap,
  # reducing disk I/O pressure dramatically.
  #
  # The 2026-05-25 OOM crash was caused by swappiness=1 (never swap, always reclaim
  # page cache). swappiness=10 was raised as a fix but was still too low for zram-only.
  # The correct value for zram-only is 100-200 (kernel docs: "for zram, use 100+").
  boot.kernel.sysctl = {
    "vm.overcommit_memory" = lib.mkForce 0; # Heuristic overcommit — prevents wild allocation beyond capacity (overrides Redis's "1")
    "vm.swappiness" = 150; # zram-only: prefer zram swap (in RAM, ~370 MiB/s) over page cache reclaim (disk I/O, ~253ms/write on QLC NAND). Old value 10 caused BTRFS I/O storms.
    "vm.watermark_scale_factor" = 100; # Start background reclaim earlier & gradually (default 100). Old value 10 caused "panic reclaim" — sudden large I/O bursts when memory ran low.
    "vm.vfs_cache_pressure" = 150; # Prefer reclaiming dentry/inode cache (cheap, no disk I/O) over page cache (expensive). Default 100.
    "vm.dirty_ratio" = 5; # Start foreground writeback at 5% memory (~4.7GB) — lower than old 10% to reduce BTRFS writeback bursts on QLC NAND
    "vm.dirty_background_ratio" = 1; # Background writeback at 1% (~940MB) — start gentle writeback sooner, avoid sudden bursts
    "vm.min_free_kbytes" = 2097152; # Keep 2GB free for kernel/GPU allocations
    "vm.max_map_count" = 2147483642; # Maximum for large model memory maps
    "vm.compaction_proactiveness" = 20; # Proactive compaction for hugepages
    "vm.oom_kill_allocating_task" = 0; # Let kernel pick the biggest memory hog (not the allocating process)

    # Crash recovery — prevent needing hard power cuts when GPU/driver hangs
    "kernel.sysrq" = 1; # Full SysRq — enables REISUB emergency reboot from keyboard
    "kernel.panic" = 10; # Auto-reboot 10s after kernel panic — kdump captures the vmcore FIRST (crashkernel path reboots after dump completes); 10s is pure post-dump recovery latency. Was 30 (time to photograph a stack trace) — kdump makes the photo redundant.
    "kernel.softlockup_panic" = 1; # Panic on soft lockup (CPU stuck in kernel with interrupts disabled)
    "kernel.watchdog_thresh" = 20; # Soft lockup detection threshold in seconds (default: 10, raised to avoid GPU compute false positives)
    "kernel.hung_task_panic" = 1; # Panic when a task is stuck in D state for too long
    "kernel.hung_task_timeout_secs" = 120; # Hung task timeout (default: 120 = 2 min)
    "vm.panic_on_oom" = 0; # Don't panic on OOM — let cgroup limits + systemd-oomd handle it
  };

  # Raise per-user process limit — default 4096 is too low for desktop + AI workloads
  # (4832 threads across 297 processes observed, causing niri EAGAIN on thread spawn)
  security.pam.loginLimits = [
    {
      domain = "@users";
      type = "soft";
      item = "nproc";
      value = "65536";
    }
    {
      domain = "@users";
      type = "hard";
      item = "nproc";
      value = "262144";
    }
  ];

  # Protect critical services from OOM killer
  # sshd: -1000 (maximum protection — remote access is the last resort)
  # journald: -500 (lost journald = lost crash diagnostics)
  # dbus-broker: -500 (D-Bus IPC — death breaks logind/DRM master/session management)
  # systemd-logind: -500 (session/seat management — death breaks niri DRM master)
  # systemd-udevd: -500 (device node management — death breaks /dev/dri/* access)
  systemd = {
    services = {
      "sshd".serviceConfig = lib.mkMerge [
        { OOMScoreAdjust = -1000; }
        ioTier.interactive
      ];
      "systemd-journald".serviceConfig.OOMScoreAdjust = -500;
      "dbus-broker".serviceConfig.OOMScoreAdjust = -500;
      "systemd-logind".serviceConfig.OOMScoreAdjust = -500;
      "systemd-udevd".serviceConfig.OOMScoreAdjust = -500;

      # ── MGLRU thrashing prevention ──────────────────────────────────────
      # min_ttl_ms protects the youngest page generation from eviction for N ms.
      # Under memory pressure, this prevents the thrash spiral (evict hot page →
      # fault it back → evict another) that starves journald and freezes the
      # desktop. 1000ms is the documented sweet spot (~human-detectable lag).
      # The OOM killer fires if the working set still can't fit — but cleanly,
      # instead of locking up the entire system.
      # MGLRU is compiled in (CONFIG_LRU_GEN=y, enabled=0x0007) but min_ttl_ms
      # defaults to 0 (disabled). This is sysfs-only (/sys/kernel/mm/lru_gen/),
      # not a /proc/sys/ sysctl, so it can't go in boot.kernel.sysctl.
      mglru-thrash-protection = {
        description = "Enable MGLRU thrashing prevention (min_ttl_ms=1000)";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-modules-load.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          echo 1000 > /sys/kernel/mm/lru_gen/min_ttl_ms
        '';
      };

      # ── kdump vmcore retention ────────────────────────────────────────
      # vmcores of a 94 GB machine are multi-GB even filtered+compressed;
      # an unbounded /var/crash on the space-tight root fs would trade one
      # emergency for another. Keep the 2 newest dumps, hard-cap total at
      # 20G (oldest deleted first). Timer at boot + weekly — dumps are rare.
      kdump-retention = {
        description = "Bound /var/crash vmcore retention (2 newest, max 20G total)";
        serviceConfig = {
          Type = "oneshot";
        };
        script = ''
          set -euo pipefail
          CRASH_DIR="/var/crash"
          [ -d "$CRASH_DIR" ] || exit 0

          list_entries() {
            # kdump default layout: timestamp dirs; also tolerate flat vmcore files.
            ${pkgs.findutils}/bin/find "$CRASH_DIR" -mindepth 1 -maxdepth 1 \( -name 'vmcore*' -o -type d \) -printf '%T@ %p\n' | sort -rn
          }

          # Keep the 2 newest entries, delete the rest.
          list_entries | ${pkgs.gawk}/bin/awk 'NR > 2 { $1=""; sub(/^ /, ""); print }' | while read -r old; do
            [ -n "$old" ] && ${pkgs.coreutils}/bin/rm -rf -- "$old" && echo "kdump-retention: removed old dump $old"
          done

          # Hard cap: while total exceeds 20G, delete the oldest remaining entry.
          while :; do
            total_bytes=$(${pkgs.coreutils}/bin/du -sb "$CRASH_DIR" 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $1}')
            [ "''${total_bytes:-0}" -lt 21474836480 ] && break
            oldest=$(list_entries | tail -1 | ${pkgs.gawk}/bin/awk '{ $1=""; sub(/^ /, ""); print }')
            [ -z "$oldest" ] && break
            ${pkgs.coreutils}/bin/rm -rf -- "$oldest"
            echo "kdump-retention: 20G cap exceeded — removed $oldest"
          done
        '';
      };
    };

    user.services = {
      "dms".serviceConfig = lib.mkMerge [
        { OOMScoreAdjust = -500; }
        ioTier.desktop
      ];
      "pipewire".serviceConfig = lib.mkMerge [
        { OOMScoreAdjust = -500; }
        ioTier.desktop
      ];
    };

    # ── Resilience: coredump storage limits ───────────────────────────────
    # AI workloads (PyTorch/ROCm, llama.cpp, Ollama) can produce 50-100GB core
    # dumps on SIGSEGV. Without limits, a single crash fills /var/lib/systemd/coredump.
    coredump.settings.Coredump = {
      Storage = "external";
      Compress = "yes";
      MaxUse = "1G";
      KeepFree = "5G";
    };

    # ── OOM protection: systemd-oomd (replaces earlyoom) ──────────────────
    # PSI-based monitoring measures actual memory pressure (process stalling)
    # rather than free RAM thresholds — critical on unified memory where GTT
    # allocations hide from MemAvailable.
    # Defense layers:
    #   1. Per-service MemoryMax cgroup limits (instant kill via harden {})
    #   2. systemd-oomd PSI monitoring (kills under sustained pressure, per-slice)
    #   3. watchdogd hard reboot (system completely unresponsive)
    #
    # Threshold rationale (adjusted 2026-08-14, up from 50%/20s):
    # The previous 50%/20s killed nix-daemon mid-build (65% pressure during
    # legitimate 4-8 GB nix build spike) and the Twenty Docker worker in
    # steady-state (856 MB container was largest under system.slice).
    # 60% sustained 30s catches genuine memory exhaustion (slow leaks, runaway
    # processes) while tolerating the transient pressure spikes inherent to
    # nix builds, AI model loads (Ollama 32G), and Docker container restarts.
    # nix-daemon is additionally exempted via ManagedOOMPreference=omit.
    # Per-slice MemoryMax limits (user-1000: 90G hard cap) remain as backstop.
    oomd = {
      enable = true;
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
      settings.OOM = {
        SwapUsedLimit = "90%";
        DefaultMemoryPressureLimit = "60%";
        DefaultMemoryPressureDurationSec = "30s";
      };
    };

    # ── Per-slice pressure limits: override NixOS module's mkDefault 80% ──
    # The oomd module defaults ManagedOOMMemoryPressureLimit to 80% on each enabled
    # slice. Match the global DefaultMemoryPressureLimit (60%) for consistency.
    slices = {
      "-".sliceConfig.ManagedOOMMemoryPressureLimit = "60%";
      "system".sliceConfig.ManagedOOMMemoryPressureLimit = "60%";
      "user".sliceConfig.ManagedOOMMemoryPressureLimit = "60%";

      # Hard ceiling on the primary user session — catches runaway allocations from
      # non-systemd processes (Helium/Electron renderers, desktop AI tools) that run
      # outside per-service MemoryMax limits.
      # MemoryHigh=80G throttles gradually (kernel increases reclaim pressure);
      # MemoryMax=90G is the hard kill. With 93G visible RAM, this leaves ~3G for
      # kernel + system services — tight, but MemoryHigh=80G starts reclaiming user
      # pages well before the wall, giving system.slice breathing room.
      # Root cause of the 2026-06-19 crash: Helium renderers grew unbounded for 66h
      # → reclaim thrash → journald starved → sp5100-tco WDT hard reset.
      #
      # The UID is hardcoded because `config.users.users.lars.uid` is null at eval
      # time (isNormalUser assigns UID at activation, not eval). `toString null` = "",
      # so the slice name silently becomes "user-" — the limits are applied to a
      # nonexistent slice and user-1000.slice runs uncapped. This caused the
      # 2026-08-03 WDT crash: user processes grew unbounded for 2 days → OOM → WDT.
      "user-1000" = {
        sliceConfig = {
          MemoryHigh = "80G";
          MemoryMax = "90G";
        };
      };
    };
  };

  # Hardware watchdog — last resort: hard-reboots the system if it becomes completely unresponsive.
  # SP5100 TCO timer (AMD chipset) will fire if watchdogd stops petting it within the timeout.
  # Catches GPU driver hangs, kernel deadlocks, and other scenarios where even SysRq fails.
  #
  # TRADEOFF (see docs/crash-analysis-2026-06-26.md Appendix D):
  #   timeout=30s races against kernel.hung_task_timeout_secs=120s. The WDT
  #   always wins, so hung_task_panic=1 never fires for runtime freezes → no
  #   pstore dump. 30s prioritizes fast recovery over forensics. Raising to
  #   120s would let hung_task capture a dump first, but means 120s of
  #   unresponsiveness on genuine hangs. Kept at 30s because:
  #     - The BTRFS metadata ENOSPC crash (the repeat failure) is now prevented
  #       by the GC guard in btrfs-health.nix
  #     - GPU driver hangs (the other scenario) benefit from fast recovery
  #     - nowayout=0 means the WDT does NOT protect boot/activation hangs anyway
  services = {
    watchdogd = {
      enable = true;
      settings = {
        timeout = 30; # Hard reset after 30s without a kick
        interval = 10; # Pet the watchdog every 10s
        safe-exit = true; # Disable WDT on clean shutdown
        meminfo = {
          enabled = true;
          warning = 0.95; # Warn at 95% RAM usage
          critical = 0.98; # Reboot at 98% RAM usage (OOM imminent, system likely unresponsive)
        };
      };
    };

    systembus-notify.enable = lib.mkForce true;

    # ── Resilience: journald size limits ──────────────────────────────────
    # Without limits, AI services (Ollama, ComfyUI, Hermes) can fill /var/log
    # with multi-GB logs, causing system failures. 8GB is sufficient for crash
    # forensics while leaving headroom on the 2TB QLC NVMe (SLC cache
    # exhaustion is the primary risk — journal writes compete with everything
    # else for SLC cache blocks).
    # settings.Journal (structured) replaces services.journald.extraConfig,
    # which nixpkgs removed (2026-09-05: surfaced by the discordsync pin
    # bump pulling nixpkgs 0968519e into the eval graph).
    journald.settings.Journal = {
      SystemMaxUse = "8G";
      RuntimeMaxUse = "2G";
      MaxFileSec = "1week";
      MaxRetentionSec = "1month";
    };
  };

  # Force performance governor — desktop/workstation with no battery concern
  powerManagement.cpuFreqGovernor = "performance";

  # QLC NAND SLC cache exhaustion is the root cause of the recurring
  # evening WDT crashes (2026-08-03, 2026-08-04). Weekly fstrim is
  # insufficient: BTRFS CoW churn (every write = new block + unreported
  # free block) re-exhausts the SLC cache within 22-47h. With the cache
  # gone, every write hits QLC directly (~253ms each), creating an
  # exponential I/O queue buildup that eventually freezes the kernel.
  # Daily fstrim keeps the NVMe controller's FTL informed of freed blocks
  # so the SLC cache stays healthy. The Aug-3 fstrim trimmed 446 GiB of
  # stale blocks — subsequent daily runs only trim ~24h of churn (~50-100
  # GiB), taking ~10-15 min instead of 1h14m.
  systemd.timers.fstrim.timerConfig.OnCalendar = lib.mkForce "daily";

  # kdump vmcore retention — bound /var/crash growth (boot + weekly)
  systemd.timers.kdump-retention = {
    description = "Run kdump vmcore retention cleanup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10min";
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  # Run fstrim at idle I/O priority so it doesn't compete with host I/O.
  # fstrim is a background maintenance task; a 10-15 min trim run at idle
  # priority is preferable to a 5 min run that starves foreground I/O and
  # risks SLC cache exhaustion from the trim-induced write amplification.
  systemd.services.fstrim.serviceConfig = ioTier.maintenance;

  # ZRAM: compressed swap on unified memory APU. This is the ONLY swap — no disk swap.
  # 50% of ~94 GiB visible RAM = ~47 GiB virtual device. At ~2.6-3.2x zstd compression,
  # a FULL 47 GiB device costs ~15-18 GiB of physical RAM while holding ~120+ GiB of
  # original data. GPU and CPU share this RAM, so AI workloads compete directly with
  # system processes.
  #
  # swappiness=150 (set above) makes the kernel prefer zram swap over page cache reclaim.
  # This is CRITICAL: zram compresses in RAM at ~370 MiB/s, while page cache reclaim hits
  # QLC NAND at ~253ms/write. Preferring zram reduces BTRFS I/O pressure dramatically.
  # The old swappiness=10 was backwards for zram-only — it forced disk I/O instead of
  # using fast in-RAM compression, causing BTRFS writeback storms (2026-08-13 incident).
  #
  # The 2026-05-25 OOM crash was caused by swappiness=1 (never swap). The fix to 10 was
  # insufficient — 150 is correct for zram-only per kernel docs ("for zram, use 100+").
  #
  # Why 30% not 17%: The old 17% (16 GiB) filled to 98.4% under normal load, leaving no
  # headroom. When zram fills completely with no disk swap fallback, the kernel falls
  # back to aggressive page cache eviction — which means BTRFS disk I/O. Larger zram =
  # more headroom before hitting that cliff. At 3.2x ratio, the extra 12 GiB costs only
  # ~3.7 GiB physical RAM — a good trade on a 110 GiB system.
  #
  # Why 50% not 30% (2026-09-02): the 28.2 GiB device sat at 97% fill (27.4 GiB of
  # swapped pages compressing to 10.7 GiB physical at 2.6x) as STEADY STATE — with
  # 53% MemAvailable and 0.26% PSI, i.e. a perfectly healthy machine whose swap-fill
  # gauge read "critical". Fill-% is only a meaningful cliff signal with headroom:
  # at 50% the same load reads ~58%, the unevictable-shmem cliff (swap exhaustion)
  # moves ~19 GiB further out, and the physical cost is bounded by compression.
  # Idle cost is ZERO: zram allocates physical pages only for actually-stored data.
  # NOTE: takes effect on REBOOT (zram device is sized at boot, not hot-resizable).
  #
  # level=1 (not the kernel default of 3): zram compresses individual 4 KiB
  # pages synchronously in the reclaim path. At 4 KiB block sizes, higher zstd
  # levels can't find enough patterns to justify their CPU cost. Benchmark on
  # 256 MiB of representative data (binary code, text, zeros, structures):
  #   L1: 2.85x ratio, 373 MiB/s compress  (1.7% worse ratio than L3)
  #   L3: 2.90x ratio, 334 MiB/s compress  (kernel default)
  #   L5: 2.96x ratio, 172 MiB/s compress  (48% slower for +2% ratio)
  # On the live 3.2x ratio, L1 costs ~60 MiB extra physical RAM across a full
  # 16 GiB device — negligible. The 11.5% compress speed gain compounds under
  # memory pressure (swap-in/swap-out is synchronous and blocks the reclaim path).
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd(level=1)";
  };
}
