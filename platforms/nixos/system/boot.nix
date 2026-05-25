{
  pkgs,
  lib,
  ...
}: {
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

    # Load I2C module for DDC/CI monitor brightness control
    # Load pstore for kernel panic/oops log capture in UEFI NVRAM
    # Load bfq for responsive I/O scheduling under heavy disk pressure
    kernelModules = ["i2c-dev" "pstore" "bfq"];

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
      # GTT: allow GPU to address up to 112GB (128GB − 16GB reserved for CPU/system).
      # Not pre-allocated — GPU uses what it needs dynamically.
      "amdgpu.gttsize=114688"
      # TTM: match GTT limit so GPU page allocations can use the full 112GB
      "amdgpu.ttm.pages_limit=29360128"
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
    ];

    binfmt.emulatedSystems = ["aarch64-linux"];

    # Wipe /tmp on every boot — prevents stale nix build caches from accumulating
    # (2011 go-build dirs / 59 GB observed in a single boot cycle)
    tmp.cleanOnBoot = true;
    tmp.useTmpfs = true;
  };

  # IO scheduler: bfq for responsive desktop under heavy disk pressure.
  # Falls back to mq-deadline if bfq module fails to load.
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", TEST=="queue/scheduler", ATTR{queue/scheduler}="bfq"
    ACTION=="add|change", KERNEL=="sd[a-z]*|vd[a-z]*|dm-[0-9]*", TEST=="queue/scheduler", ATTR{queue/scheduler}="bfq"
  '';

  # TTM memory pool configuration for GPU workloads (112GB flexible limit, 16GB reserved for CPU)
  boot.extraModprobeConfig = ''
    options amdgpu gttsize=114688
    options ttm pages_limit=29360128
    options ttm page_pool_size=29360128
  '';

  # VM sysctl tuning for AI/ML workloads (128GB unified memory)
  boot.kernel.sysctl = {
    "vm.overcommit_memory" = lib.mkForce 0; # Heuristic overcommit — prevents wild allocation beyond capacity (overrides Redis's "1")
    "vm.swappiness" = 1; # Minimum swap usage — 128GB RAM makes swap unnecessary for normal use
    "vm.dirty_ratio" = 10; # Start writeback at 10% memory (~13GB)
    "vm.dirty_background_ratio" = 3; # Background writeback at 3% (~4GB)
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
    "vm.panic_on_oom" = 0; # Don't panic on OOM — let OOM killer do its job (earlyoom handles this)
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
    };

    user.services = {
      "waybar".serviceConfig.OOMScoreAdjust = -500;
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

    earlyoom = {
      enable = true;
      freeMemThreshold = 10; # Kill when free RAM drops below 10% (~12.8GB)
      freeSwapThreshold = 10; # Kill when free swap drops below 10%
      enableNotifications = true; # Desktop notification before killing
      extraArgs = [
        "--avoid"
        "^(systemd|sshd|dbus-broker|systemd-logind|systemd-udevd|systemd-journald|niri|waybar|kitty|fish|pipewire|pipewire-pulse|wireplumber|swayidle|dunst)$" # Never kill these
        "--prefer"
        "^(gopls|ollama|llama-server|python3|python|node|java|chrome|chromium|helium|electron|vtsls|tsserver|rust-analyzer|generate_happy_girl|cargo|clang|go)$" # Kill these first
      ];
    };

    # ── Resilience: journald size limits ──────────────────────────────────
    # Without limits, AI services (Ollama, ComfyUI, Hermes) can fill /var/log
    # with multi-GB logs, causing system failures. 4GB is generous for 128GB RAM.
    journald.extraConfig = ''
      SystemMaxUse=4G
      RuntimeMaxUse=1G
      MaxFileSec=1week
      MaxRetentionSec=2week
    '';
  };

  # Force performance governor — desktop/workstation with no battery concern
  powerManagement.cpuFreqGovernor = "performance";

  # ZRAM: compressed swap emergency buffer.
  # 10% = ~12.8GB virtual device on 128GB RAM. Provides headroom for OOM
  # scenarios — the system ran for 16h with swap at 0% before crashing because
  # the 5% (6.4GB) buffer was insufficient under AI workload memory pressure.
  # swappiness=1 ensures the kernel avoids swap unless critically needed.
  zramSwap = {
    enable = true;
    memoryPercent = 10;
  };
}
