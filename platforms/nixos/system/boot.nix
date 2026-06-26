{
  config,
  pkgs,
  lib,
  ...
}: let
  ttmPagesLimit = 29360128;
in {
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

    # Load I2C module for DDC/CI monitor brightness control
    # Load pstore for kernel panic/oops log capture in UEFI NVRAM
    # Load bfq for responsive I/O scheduling under heavy disk pressure
    kernelModules = ["i2c-dev" "bfq" "usblp"];

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
      # TTM: match GTT limit so GPU page allocations can use the full 112GB
      # Note: amdgpu.gttsize is deprecated in kernel 7.0+ — use ttm.pages_limit instead
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
      "systemd.show_status=true"
      "systemd.log_level=debug"
    ];

    binfmt.emulatedSystems = ["aarch64-linux"];

    # Wipe /tmp on every boot — prevents stale nix build caches from accumulating
    # (2011 go-build dirs / 59 GB observed in a single boot cycle)
    tmp.cleanOnBoot = true;
    tmp.useTmpfs = true;
  };

  # TTM memory pool configuration for GPU workloads (112GB flexible limit, 16GB reserved for CPU)
  boot.extraModprobeConfig = ''
    options ttm pages_limit=${toString ttmPagesLimit}
    options ttm page_pool_size=${toString ttmPagesLimit}
  '';

  # VM sysctl tuning for AI/ML workloads (AMD Ryzen AI MAX+ 395 — 64 GB unified DDR5, GPU/CPU share same RAM via GTT)
  boot.kernel.sysctl = {
    "vm.overcommit_memory" = lib.mkForce 0; # Heuristic overcommit — prevents wild allocation beyond capacity (overrides Redis's "1")
    "vm.swappiness" = 10; # Use swap before OOM — prevents Rust/nix build crashes (was 1, caused OOM kills on 2026-05-25)
    "vm.dirty_ratio" = 10; # Start writeback at 10% memory (~6.4GB)
    "vm.dirty_background_ratio" = 3; # Background writeback at 3% (~1.9GB)
    "vm.min_free_kbytes" = 2097152; # Keep 2GB free for kernel/GPU allocations
    "vm.max_map_count" = 2147483642; # Maximum for large model memory maps
    "vm.compaction_proactiveness" = 20; # Proactive compaction for hugepages
    "vm.oom_kill_allocating_task" = 0; # Let kernel pick the biggest memory hog (not the allocating process)

    # Crash recovery — prevent needing hard power cuts when GPU/driver hangs
    "kernel.sysrq" = 1; # Full SysRq — enables REISUB emergency reboot from keyboard
    "kernel.panic" = 30; # Auto-reboot 30s after kernel panic (time to read/photograph stack trace, then recover)
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
      "sshd".serviceConfig.OOMScoreAdjust = -1000;
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
        wantedBy = ["multi-user.target"];
        after = ["systemd-modules-load.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          echo 1000 > /sys/kernel/mm/lru_gen/min_ttl_ms
        '';
      };
    };

    user.services = {
      "dms".serviceConfig.OOMScoreAdjust = -500;
      "pipewire".serviceConfig.OOMScoreAdjust = -500;
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
    oomd = {
      enable = true;
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
      # Tighter than NixOS defaults (60% pressure sustained 30s) but tuned for AI/ML:
      # model loads (Ollama 32G) and nix builds cause transient pressure spikes that
      # resolve in seconds. 50% sustained 20s catches the slow-leak thrash scenario
      # (2026-06-19: Helium grew unbounded for 66h) without killing model loads.
      settings.OOM = {
        SwapUsedLimit = "90%";
        DefaultMemoryPressureLimit = "50%";
        DefaultMemoryPressureDurationSec = "20s";
      };
    };

    # ── Per-slice pressure limits: override NixOS module's mkDefault 80% ──
    # The oomd module defaults ManagedOOMMemoryPressureLimit to 80% on each enabled
    # slice. Tighten to 50% to match the global DefaultMemoryPressureLimit above.
    slices = {
      "-".sliceConfig.ManagedOOMMemoryPressureLimit = "50%";
      "system".sliceConfig.ManagedOOMMemoryPressureLimit = "50%";
      "user".sliceConfig.ManagedOOMMemoryPressureLimit = "50%";

      # Hard ceiling on the primary user session — catches runaway allocations from
      # non-systemd processes (Helium/Electron renderers, desktop AI tools) that run
      # outside per-service MemoryMax limits.
      # MemoryHigh=56G throttles gradually (kernel increases reclaim pressure);
      # MemoryMax=64G is the hard kill. Leaves ~29G for system services + kernel.
      # Root cause of the 2026-06-19 crash: Helium renderers grew unbounded for 66h
      # → reclaim thrash → journald starved → sp5100-tco WDT hard reset.
      "user-${toString config.users.users.lars.uid}" = {
        sliceConfig = {
          MemoryHigh = "56G";
          MemoryMax = "64G";
        };
      };
    };
  };

  # Hardware watchdog — last resort: hard-reboots the system if it becomes completely unresponsive.
  # SP5100 TCO timer (AMD chipset) will fire if watchdogd stops petting it within the timeout.
  # Catches GPU driver hangs, kernel deadlocks, and other scenarios where even SysRq fails.
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
    # with multi-GB logs, causing system failures. 16GB ensures crash forensics
    # survive even when services spam errors for hours (see June 2025 disk-full
    # incident where 4G was consumed by ClickHouse/Redis error flood, rotating
    # away the crash boot logs).
    journald.extraConfig = ''
      SystemMaxUse=16G
      RuntimeMaxUse=2G
      MaxFileSec=1week
      MaxRetentionSec=1month
    '';
  };

  # Force performance governor — desktop/workstation with no battery concern
  powerManagement.cpuFreqGovernor = "performance";

  # ZRAM: compressed swap emergency buffer on unified memory APU.
  # 10% = ~6.4 GB virtual device on 64 GB unified DDR5. GPU and CPU share this RAM,
  # so AI workloads compete directly with system processes for the same pool.
  # swappiness=10 ensures the kernel uses swap before OOM kills.
  # swappiness=1 caused the 2026-05-25 OOM crash (kernel killed user@1000 processes
  # instead of swapping out nix-daemon build memory).
  zramSwap = {
    enable = true;
    memoryPercent = 10;
  };
}
