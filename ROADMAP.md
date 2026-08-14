# SystemNix Roadmap

_Long-term direction and raw ideas not yet refined into actionable tasks._

**Updated:** 2026-08-14

For short-term actionable work, see [TODO_LIST.md](./TODO_LIST.md). For current feature status, see [FEATURES.md](./FEATURES.md).

---

## Theme 1: Reliability & Resilience

The system has been hardened through multiple crash cycles. The root cause chain is now well-understood: QLC NAND SLC cache exhaustion → I/O queue → kernel freeze → WDT reset, compounded by systemd-oomd killing critical services (nix-daemon, PMA) during memory pressure bursts. Mitigations deployed: daily fstrim, `commit=300`, BFQ I/O priority tiers, `ManagedOOMPreference=omit` on critical services, memory.events monitoring. Remaining work:

- **Off-site backup** — no DR backup exists. The Aug 3 corruption event (13 files lost) proves this is not theoretical. Evaluate BorgBackup to Hetzner StorageBox (see `docs/research/hetzner-storagebox-borgbackup.md`). **This is the #1 data loss risk — flagged since 2026-06-25.**
- **Reduce unsafe shutdowns** — 58+ unsafe shutdowns from WDT resets. This is the ROOT CAUSE of data corruption. Options: UPS, WDT timeout tuning, oomd threshold adjustment, dedicated TLC boot disk
- **Disk space management** — Root filesystem chronically at 90-93%. BTRFS snapshots hold references preventing GC reclamation. Need snapshot retention tuning or capacity expansion
- **BTRFS `/data` subvolume migration** — `/data` is BTRFS toplevel (subvolid=5). Migration to `@data` would enable separate CoW semantics
- **Crash-loop circuit breaker** — No system-wide mechanism to detect and bound crash loops before they cause I/O pressure → WDT crash. The browser-history 592-restart and Twenty 235-restart loops both went undetected (crash-loop DETECTION metrics now live — auto-remediation/reset-failed is the remaining gap)
- **Provision Raspberry Pi 3** — hardware needed for DNS failover cluster (VRRP)
- **Auditd enablement** — blocked on NixOS 26.05 bug #483085
- **GPUActive memory pressure** — `system-health.nix` collects GPUActive metrics and alerts at 60G threshold. TTM `page_pool_size` reduced from 112 GiB to 24 GiB. Remaining: investigate lowering `ttmPagesLimit` and `GPUReclaim` tuning

---

## Theme 2: Security Hardening

- **Firewall deny-by-default** — NixOS currently allows all inbound. Docker punches its own holes. Transition to explicit allowlist
- **Bind Immich to localhost** — currently on `0.0.0.0` with `openFirewall`. Caddy already reverse-proxies
- **Remove legacy ssh-rsa** from accepted algorithm (kept for macOS client compat — evaluate dropping)
- **Monitor365 agent→server auth** — no authentication, anyone on LAN can POST data
- **AppArmor enablement** — currently `mkDefault false` in security-hardening.nix

---

## Theme 3: Desktop Experience

- **Niri blur** — Desktop Renaissance v3 added terminal transparency but niri's HM module lacks a `blur {}` option. Transparent terminals without blur are hard to read. Options: raw KDL config, wait for niri-flake, or drop transparency
- **Smart-audio per-app routing** — current daemon moves ALL audio on focus change (default sink). True per-app routing (matching PipeWire stream PIDs to niri window PIDs) would only move the focused window's audio. Also: manual-override cooldown, DMS output widget
- **ZFS external drive access** — Connected 2x16TB external ZFS mirror pool (`datapool`, only 21GB used — disposable Docker images). VFIO PCIe passthrough PROVEN WORKING in NixOS VM. SATA pool spun down. Native ZFS on host kernel 7.1 still untested. Decision needed: native ZFS, permanent VM, or reformat to BTRFS (pool is 99.86% empty)
- **SearXNG streaming results** — User wants progressive rendering (stream results as engines respond), not the current "wait for all engines" model. Options: SearXNG fork with SSE endpoint, Go/Rust streaming proxy, or Caddy `flush_buffers -1`
- **Darwin Home Manager parity** — macOS HM config is minimal (no terminal, editor, theme parity). Blocked by 256GB disk constraint
- **Disabled service triage** (decided 2026-06-25):
  - **voice-agents**: KEEP disabled — LiveKit + Whisper needs GPU resource planning
  - **minecraft**: KEEP server disabled, client settings (Prism Launcher) stay enabled — server is seasonal
  - **photomap**: REMOVED (2026-07-04) — module, port, Docker image all cleaned up
  - **DiscordSync**: ✅ Reactivated — upstream migrated to go-cqrs-lite v3. GCS attachment backup available via opt-in `gcsBucket`

---

## Theme 4: Architecture & Code Quality

- **Split large modules** — signoz.nix split (943→511L), forgejo.nix split (725→353L). Monitor365 restructured (716L→151L). Remaining candidates: `configuration.nix` is the largest unsplit file
- **Extract dnsblockd** — ~930 lines of production Go embedded in the Nix config. Candidate for standalone repo (see `docs/planning/2026-05-03_02-52_extract-dnsblockd-from-systemnix.md`)
- **Typed NixOS module options** — many modules use `mkEnableOption` only. Add typed options for ports, paths, timeouts → enables validation and testing
- **dnsblockd category enum** — categories are stringly-typed (10 hardcoded strings). Define Go enum type
- **Deploy pipeline reliability** — PMA auto-commit daemon runs unscoped `nix flake update` which triggers the recurring nixpkgs tarball regression. 4-layer defense deployed. Registry override needs reboot to activate
- **Regression test coverage** — VM test infrastructure exists (`tests/`). Expand beyond current 11 tests to cover: DynamicUser + sops mismatch, deploy.sh start-limit reset, `writeShellApplication` pipefail patterns, StartLimitBurst placement audit
- **Unified readiness gates** — `mkOidcGate`/`mkDnsGate` cover OIDC + DNS probing; a generalized `mkReadinessGate { type = "http"|"dns"|"tcp" }` would also cover DiscordSync's external-HTTP probe and service-to-service health probes

---

## Theme 5: Upstream Contributions

Items that benefit the broader Nix ecosystem:

- **nixpkgs PRs**: `aw-watcher-utilization` poetry-core migration, `valkey`/`aiocache` test fixes, `taskwarrior3` build flags, Kitty GC resilience patch, KeePassXC Chromium manifests
- **Home Manager PRs**: ActivityWatch Wayland watcher deps, ActivityWatch theme option, Darwin user definition requirement (#6036)
- **Third-party**: `jscpd` lockfile publishing, XRT boost 1.87+ compat for `nix-amd-npu`, direnv caching pattern (fish-native mtime gate, GC root optimization), wf-recorder FFmpeg 7 compat, hermes-agent `py-modules` fix
- **LarsArtmann apps**: dnsblockd OTEL cardinality leak, Monitor365 DuckDB pool deadlock root cause, DiscordSync chattr ExecStartPre, PMA daemon broken flake.lock commits, Hermes directory auto-creation, browser-history `CheckpointStore` + `expires_at` reaper + registration-lock release, cqrs-htmx import-path gating, BuildFlow pre-commit devShell binaries, picoclaw modernc bump, golangci-lint-auto-configure vendoring

See [TODO_LIST.md](./TODO_LIST.md) Priority 6 for detailed task breakdowns.

---

## Theme 6: AI/ML Workloads

- **Jan llama-server respawn** — spawns new `llama-server` every 1-3 min (~1.2GB each). Not a systemd service, no cgroup limits. Needs investigation
- **Voice agents** — LiveKit + Whisper Docker pipeline disabled. Decide: enable with proper resource limits, or remove
- **NPU utilization** — AMD XDNA 2 (50 TOPS) confirmed completely idle. ROCm GPU is the compute backend. Explore ONNX Runtime / Ryzen AI SDK for small model offloading
- **Local AI vision models** — file-and-image-renamer can use local llama.cpp provider. Pull vision-capable GGUF model, test on Radeon 8060S via ROCm
- **Attic cache for AI closures** — Ollama, llama-cpp, and other AI package closures are large (30+ min builds). Attic cache should serve these once configured

---

## Theme 7: Binary Cache & CI

- **Attic cache production hardening** — Attic module deployed but cache not yet created. After creating cache + CI token, expand to all LarsArtmann Go repos
- **Forgejo Actions CI expansion** — Monitor365 CI workflow is the first consumer. Expand to other LarsArtmann repos
- **VM test CI integration** — 11 VM tests exist. Wire into `.github/workflows/nix-check.yml` `vm-tests` job

---

## Deferred / Rejected Ideas

| Idea                  | Status   | Reason                                         |
| --------------------- | -------- | ---------------------------------------------- |
| OpenZFS on macOS      | Rejected | Kernel panics (ADR-003)                        |
| otel-tui on Darwin    | Rejected | 40+ min builds, disk exhaustion                |
| ComfyUI               | Removed  | Prefer using AI models via code directly       |
| Authelia              | Removed  | Replaced by Pocket ID (passkey-based, simpler) |
| Prometheus            | Removed  | Replaced by SigNoz (full-stack observability)  |
| Hyprland              | Removed  | Replaced by Niri (scrollable tiling). grimblast dependency purged (~122 MiB)   |
| swww wallpaper daemon     | Removed  | Ghost service crash-looping 1220+ times/boot. DMS manages wallpapers natively via IPC |
| DNS-over-QUIC overlay     | Disabled | Breaks binary cache (40+ min builds)                           |
| llama-cpp MFMA flag   | Removed  | No-op on RDNA 3.5 (Strix Halo). Only affects CDNA GPUs |
| SearXNG rate limiter  | Removed  | Private LAN, no abuse vector. Redis removed too |
| `discard=none`        | Reverted | Would have bricked boot. `nodiscard` mount option confirmed working |
| Git core.compression  | Removed  | Counterproductive for .nix files — poor compression, increases CPU. Level 9 removed |
