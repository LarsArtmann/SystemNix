# SystemNix Roadmap

_Long-term direction and raw ideas not yet refined into actionable tasks._

**Updated:** 2026-08-10

For short-term actionable work, see [TODO_LIST.md](./TODO_LIST.md). For current feature status, see [FEATURES.md](./FEATURES.md).

---

## Theme 1: Reliability & Resilience

The system has been hardened through multiple crash cycles (QLC SLC cache exhaustion root-caused Aug 5: BTRFS CoW churn exhausts SLC write cache within 22-47h → direct QLC writes ~253ms → exponential I/O queue → kernel freeze → WDT reset). Mitigations deployed: daily fstrim (was weekly), `commit=300` on all BTRFS mounts, idle I/O priority. Remaining work:

- **Off-site backup** — no DR backup exists. The Aug 3 corruption event (13 files lost) proves this is not theoretical. Evaluate BorgBackup to Hetzner StorageBox (see `docs/research/hetzner-storagebox-borgbackup.md`). **This is the #1 data loss risk — flagged since 2026-06-25.**
- **Reduce unsafe shutdowns** — 58 of 126 power cycles (46%) were unsafe (WDT resets, OOM cascades, power events). This is the ROOT CAUSE of the data corruption. Options: UPS, WDT timeout tuning, oomd threshold adjustment, hung_task_timeout review
- **BTRFS `/data` subvolume migration** — `/data` is BTRFS toplevel (subvolid=5). Migration to `@data` would enable separate CoW semantics. Has btrbk snapshot protection but not a named subvolume. Requires ~1h downtime
- **`/data` fill reduction** — at 92% (700 GiB / 758 GiB). High fill on QLC NAND increases write amplification. Target: <80%
- **QLC NAND SLC cache health** — root-caused as the mechanism behind ALL 3 WDT crashes (Aug 1, 3, 4). BTRFS CoW churn re-exhausts the SLC cache within 22-47h when fstrim is weekly. Daily fstrim + `commit=300` deployed. BFQ I/O priority tiers deployed (7-tier system). Monitor PSI I/O stall rate via Gatus. If crashes resume, consider TLC replacement or UPS
- **PMA page-cache death-loop** — Root-caused Aug 9 crash: PMA commit-failure loop consumed 91% CPU, pinned 16G page cache, 27,312 memory boundary hits, system-wide PSI 95%, kernel freeze, WDT reset. 3-layer fix deployed: upstream `isNothingToCommit()` code fix (uncommitted), cgroup limits (MemoryHigh=6G, MemoryMax=8G, CPUQuota=200%), memory monitoring + Gatus alerts. `memory.events` metric would provide earlier detection
- **Provision Raspberry Pi 3** — hardware needed for DNS failover cluster (VRRP). Module and config ready, hardware not purchased
- **Auditd enablement** — blocked on NixOS 26.05 bug #483085. Re-evaluate when fixed upstream
- **Disk space monitoring** — Darwin is 90%+ full on 256GB SSD. Need automated alerting before builds fail
- **GPUActive memory pressure** — `system-health.nix` collects GPUActive metrics and alerts at 60G threshold. TTM `page_pool_size` reduced from 112 GiB to 24 GiB. GPUActive is the #1 RAM consumer on Strix Halo (~51 GiB with desktop workloads). Remaining: investigate lowering `ttmPagesLimit` and `GPUReclaim` tuning

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
- **I/O throttling for dev builds** — BFQ I/O scheduling deployed (7-tier system, `ioTier` helpers, 14+ services classified). Crush wrapped with ionice/nice. Remaining: wrap dev commands (`go`, `cargo`, `npm`, `pnpm`) with `IOSchedulingClass=idle` or `IOWeight` limits. 5 services in `boot.nix` still use raw I/O literals instead of `ioTier.*`
- **ZFS external drive access** — Connected 2x16TB external ZFS mirror pool (`datapool`, only 21GB used — disposable Docker images). VFIO PCIe passthrough PROVEN WORKING in NixOS VM (kernel 6.18.43, ZFS 2.4.3). QEMU usb-host does NOT work for JMicron dual-LUN bridge. Native ZFS on host kernel 7.1 still untested (simplest option — ZFS 2.4.3 has 7.1 forward-compat patches). Decision needed: native ZFS, permanent VM, or reformat to BTRFS (pool is 99.86% empty)
- **SearXNG streaming results** — User wants progressive rendering (stream results as engines respond), not the current "wait for all engines" model. Options: SearXNG fork with SSE endpoint, Go/Rust streaming proxy, or Caddy `flush_buffers -1`
- **Darwin Home Manager parity** — macOS HM config is minimal (no terminal, editor, theme parity). Blocked by 256GB disk constraint
- **Disabled service triage** (decided 2026-06-25):
  - **voice-agents**: KEEP disabled — LiveKit + Whisper needs GPU resource planning, not ready for daily use
  - **minecraft**: KEEP server disabled, client settings (Prism Launcher) stay enabled — server is seasonal
  - **photomap**: REMOVED (2026-07-04) — module, port, Docker image all cleaned up
  - **DiscordSync**: ✅ Reactivated — upstream migrated to go-cqrs-lite v3 (ADR-0030). GCS attachment backup available via opt-in `gcsBucket`

---

## Theme 4: Architecture & Code Quality

- **Split large modules** — signoz.nix split (943→511L), forgejo.nix split (725→353L). Monitor365 restructured (716L→151L). Remaining candidates: `configuration.nix` is the largest unsplit file
- **Extract dnsblockd** — ~930 lines of production Go embedded in the Nix config. Candidate for standalone repo (see `docs/planning/2026-05-03_02-52_extract-dnsblockd-from-systemnix.md`)
- **Typed NixOS module options** — many modules use `mkEnableOption` only. Add typed options for ports, paths, timeouts → enables validation and testing
- **dnsblockd category enum** — categories are stringly-typed (10 hardcoded strings). Define Go enum type
- **Deploy pipeline reliability** — PMA auto-commit daemon runs unscoped `nix flake update` which triggers the recurring nixpkgs tarball regression (global registry rewrites github→tarball). 4-layer defense deployed (eval guard + pre-commit + CI normalization + recovery script). Registry override needs reboot to activate. Daemon itself needs to normalize or stop committing flake.lock
- **Regression test coverage** — VM test infrastructure exists (`tests/`). Expand beyond Attic/SearXNG to cover: DynamicUser + sops mismatch, deploy.sh start-limit reset, `writeShellApplication` pipefail patterns, `builtins.toString null` slice key bug
- **vendorHash drift detection** — Systemic issue: nixpkgs updates break Go vendorHashes across 8+ repos. `nix flake check` does NOT catch FOD mismatches. Consider CI matrix, batch script, or pre-commit hook
- **SigNoz dashboard v1→v2 migration** — 5 dashboard JSONs in v1 flat format, POSTed to v2 API (non-fatal warnings). Perses v2 schema requires rewriting `spec.display`, `spec.layouts`, `spec.panels`. Mechanical but non-trivial
- **node_exporter textfile phantom metrics** — 14 `system_*` metrics in valid `.prom` files don't appear in node_exporter output. Root cause unknown. 14 Gatus health checks permanently RED
- **Declarative health-check** — `criticalSystemServices` in `scheduled-tasks.nix` is hand-maintained (only 4 services). Generate from Nix config instead

---

## Theme 5: Upstream Contributions

Items that benefit the broader Nix ecosystem:

- **nixpkgs PRs**: `aw-watcher-utilization` poetry-core migration, `valkey`/`aiocache` test fixes, `taskwarrior3` build flags, Kitty GC resilience patch, KeePassXC Chromium manifests
- **Home Manager PRs**: ActivityWatch Wayland watcher deps, ActivityWatch theme option, Darwin user definition requirement (#6036)
- **Third-party**: `jscpd` lockfile publishing, XRT boost 1.87+ compat for `nix-amd-npu`, direnv caching pattern (fish-native mtime gate, GC root optimization)
- **LarsArtmann apps**: dnsblockd OTEL cardinality leak (unbounded labels), dnsblockd per-domain block response type (NXDOMAIN for background services, zero_ip for browser-visible), dnsblockd TLS handshake log noise suppression, Monitor365 DuckDB pool deadlock root cause, DiscordSync chattr ExecStartPre (upstream module fix), PMA daemon broken flake.lock commits, file-and-image-renamer input pinning (`ref=master` → tags), Hermes directory auto-creation + state migration, PMA `GenerateMessage` handler leak, browser-history OTel endpoint URL scheme (gRPC `127.0.0.1:4317` → HTTP `http://localhost:4318`)

See [TODO_LIST.md](./TODO_LIST.md) Priority 6 for detailed task breakdowns.

---

## Theme 6: AI/ML Workloads

- **Jan llama-server respawn** — spawns new `llama-server` every 1-3 min (~1.2GB each). Not a systemd service, no cgroup limits. Needs investigation
- **Voice agents** — LiveKit + Whisper Docker pipeline disabled. Decide: enable with proper resource limits, or remove
- **NPU utilization** — AMD XDNA 2 (50 TOPS) confirmed completely idle (Aug 6 investigation). ROCm GPU is the compute backend. NPU has no vision-LLM path currently. Explore ONNX Runtime / Ryzen AI SDK for small model offloading. Monitor upstream llama.cpp XDNA/IRON plugin progress
- **Local AI vision models** — file-and-image-renamer can use local llama.cpp provider. Pull vision-capable GGUF model (Llama 3.2 Vision, Qwen2-VL), test on Radeon 8060S via ROCm, benchmark cold-start latency
- **Attic cache for AI closures** — Ollama, llama-cpp, and other AI package closures are large (30+ min builds). Attic cache (deployed) should serve these once configured

---

## Theme 7: Binary Cache & CI

- **Attic cache production hardening** — Attic module deployed but cache not yet created. After creating cache + CI token for Monitor365, expand to all LarsArtmann Go repos. Evaluate SQLite scaling, multi-project caching, cache eviction policy
- **Forgejo Actions CI expansion** — Monitor365 CI workflow is the first consumer. Expand to other LarsArtmann repos. Runner MemoryMax raised to 16G for Rust builds
- **VM test CI integration** — Attic and SearXNG VM tests exist. Wire into `.github/workflows/nix-check.yml` `vm-tests` job

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
