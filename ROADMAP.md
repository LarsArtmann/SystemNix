# SystemNix Roadmap

_Long-term direction and raw ideas not yet refined into actionable tasks._

**Updated:** 2026-09-05 (Btrfs-at-Facebook LWN research: snapshot-drop cleanup idea added to Theme 1)

For short-term actionable work, see [TODO_LIST.md](./TODO_LIST.md). For current feature status, see [FEATURES.md](./FEATURES.md).

---

## Theme 1: Reliability & Resilience

The system has been hardened through multiple crash cycles. The root cause chain is now well-understood: QLC NAND SLC cache exhaustion → I/O queue → kernel freeze → WDT reset, compounded by systemd-oomd killing critical services (nix-daemon, PMA) during memory pressure bursts. Mitigations deployed: daily fstrim, `commit=300`, BFQ I/O priority tiers, `ManagedOOMPreference=omit` on critical services, memory.events monitoring. Remaining work:

- **Off-site backup** — **pool safety net is LIVE (2026-08-17):** btrbk root+data sends + every application backup (forgejo, pocket-id, immich, twenty, manifest, paperless) land on the 2×16 TB BTRFS mirror — the single-NVMe risk is closed. The remaining gap is the 3rd, OFF-SITE copy: user states important photos/docs already live in Google Photos/Drive — decide whether that satisfies 3-2-1 or whether an offsite leg (periodic sdf vault rotation, or the evaluated-but-never-executed Hetzner StorageBox + Borg, `docs/research/hetzner-storagebox-borgbackup.md`) returns
- **Reduce unsafe shutdowns** — 58+ unsafe shutdowns from WDT resets. This is the ROOT CAUSE of data corruption. Options: UPS, WDT timeout tuning, oomd threshold adjustment, dedicated TLC boot disk. The three kernel freezes of 2026-08-22/24/31 were scheduler LIVELOCKS (WDT, softlockup detectors and kdump were ALL armed and NONE fired — the class pets the watchdog "eventually"); prevention lives in the layered guard/sev1/stability stack, never in-kernel detection
- **Samsung 1TB migration (ratified 2026-08-31)** — `/nix` moves to the internally-installed Samsung 970 EVO Plus (BTRFS ~860G zstd + XFS 64G for hot DBs, nodatacow subvols per the Rev-2 decision doc); QLC exec-latency-under-buildstorm is the driver. Phase 1/2 clusters live in TODO_LIST; end-state moves docker data-root off the QLC `/data` too. Root disk pressure is meanwhile RESOLVED (82% after the GC-guard fix + user levers; the old 95%/96% crisis entries are closed)
- **BTRFS `/data` subvolume migration** — `/data` is BTRFS toplevel (subvolid=5). Migration to `@data` would enable separate CoW semantics
- **Snapshot-drop cleanup for big tree churn (Btrfs-at-Facebook pattern, noted 2026-09-05)** — Facebook's build farm replaced 2-10-min "delete huge checkout trees" with snapshot-on-entry / drop-subvolume-on-exit (near-instant, reclaimed by a background worker) and cut build-machine capacity by a third. Local candidates IF cleanup ever becomes I/O-painful: VM-test scratch dirs, heavy build checkouts, `/mnt/buildcache` rust targets (needs the deferred buildcache btrfs+zstd conversion first — TODO P2). NOT actionable today: buildcache-gc completes in minutes and Nix-store churn already avoids snapshot pinning via `@nix`
- **`/data` rename + model-root consolidation (user idea 2026-09-05)** — `/data` holds ONLY redownloadable bulk (ai 291G + models 210G + llamacpp 92G + Steam 106G + docker root ~20G, mostly overlay2); the sole stateful data is the docker data-root's tiny volumes (twenty/manifest postgres), ALREADY covered pool-side by nightly pg_dumps — so the broken `/data` btrbk send is nearly irrelevant data-wise (the P0 item is about the corruption itself, not backup value). Rename the mountpoint to a truth-in-advertising name (e.g. `/redownloadable`) and consolidate the THREE scattered model roots into one dedicated folder (`/data/ai/models` is canonical per ai-models.nix; absorb `/data/models` ad-hoc diffusion/video models + `/data/llamacpp-models` GGUFs). Config touchpoints: hardware-configuration.nix, snapshots.nix (btrbk-data volume + tmpfiles + RequiresMountsFor), default-services.nix (docker data-root), ai-models.nix, fastflowlm.nix + llama-rag.nix modelDir defaults, home.nix (Jan symlink), gatus alert texts; runtime steps: docker data-root move (docker down), Steam library re-add, model-path migrations (same-fs renames = instant). Coordinate with the Samsung migration (docker data-root end-state) and the `/data` EIO repair (P0)
- **Crash-loop circuit breaker** — crash-loop DETECTION metrics are live (`system_service_start_limit_hit`, restart-churn) — auto-remediation/reset-failed is the remaining gap. New idea (freeze #3, 2026-08-31): boot-time catch-up stampede control — after multi-day outages every Persistent timer + scrub + dump fires in the same minute; stagger catch-ups or add a boot IO-admission gate
- **disko at the already-deferred reinstall** — declarative partitioning researched 2026-08-28; a provisioning-time tool (nixos-anywhere), NOT safely retrofittable — draft the config when the reinstall is actually scheduled
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
- **ZFS era CLOSED (2026-08-16)** — the 2×16 TB external ZFS mirror (`datapool`) was forensically extracted (373,491/373,491 files verified, zero user media), DESTROYED, and rebuilt as the BTRFS RAID1 backup pool (`/mnt/pool`). Native-ZFS-on-host experiment is moot. Remaining: retire the stale ZFS-VM scripts/workflow remnants (TODO_LIST)
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
- **Observability backend migration (SigNoz → VM ecosystem)** — Researched 2026-08-18, NOT scheduled. Verdict: keep SigNoz today (pain already paid, 2.5 GiB of 94 GiB). Target stack when triggered: VictoriaMetrics + VictoriaLogs + Tempo + Grafana (all stock nixpkgs modules, <1 GiB total) — or VictoriaTraces replacing Tempo+Grafana if it hits v1.0 stable first. **Revisit triggers:** VictoriaTraces v1.0, a NEW SigNoz/ClickHouse incident class, ClickHouse resource pressure, or wanting Grafana for other reasons. Full analysis + migration sketch: `docs/research/observability-signoz-to-victoriametrics.md`
- **Real OTel instrumentation for own Go services** — overview and PMA carry `OTEL_EXPORTER_OTLP_ENDPOINT` but ship ZERO spans (never instrumented upstream; the env var is a documented noop). Either add otel SDK spans upstream or drop the pretense + audit the expectations registry — and add phantom-telemetry detection (alert when a registered exporter goes span-silent). Applies to every future own-service integration: wired ≠ instrumented (`docs/status/2026-08-18_02-38_otel-coverage-audit-buildflow-overview-pma.md`)

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
- **NPU utilization** — AMD XDNA 2 (50 TOPS): FastFlowLM + Qwen3.6-35B-A3B systemd-managed on it since 2026-08-17 (socket-activated `Accept=true` + socat bridge, idle TTL — the fragile hand-started era is over). Remaining exploration: ONNX Runtime / Ryzen AI SDK for small-model offloading beyond the LLM slot
- **Shared `services.rocm-gpu` module** — every GPU consumer hand-merges `rocmEnv // {}` (Ollama got it, gpu-python got it, session vars didn't — 136 days of CPU-fallback llama-server). A module with `options.services.<x>.rocm = true` that auto-injects `HSA_OVERRIDE_GFX_VERSION`/`HSA_ENABLE_SDMA`, the ROCm `LD_LIBRARY_PATH`, and the `render`/`video` groups makes the class structurally impossible (suggested 2026-04-04, still open; `docs/status/2026-08-18_17-42_llama-server-vram-fix-rocm-session-vars.md` §C.5)
- **Local AI vision models** — file-and-image-renamer can use local llama.cpp provider. Pull vision-capable GGUF model, test on Radeon 8060S via ROCm
- **Attic cache for AI closures** — Ollama, llama-cpp, and other AI package closures are large (30+ min builds). Attic cache should serve these once configured

---

## Theme 7: Binary Cache & CI

- **Attic cache production hardening** — Attic module deployed but cache not yet created. After creating cache + CI token, expand to all LarsArtmann Go repos
- **Forgejo Actions CI expansion** — Monitor365 CI workflow is the first consumer. Expand to other LarsArtmann repos
- **VM test CI integration** — 11 VM tests exist. Wire into `.github/workflows/nix-check.yml` `vm-tests` job

---

## Deferred / Rejected Ideas

| Idea                  | Status   | Reason                                                                                                |
| --------------------- | -------- | ----------------------------------------------------------------------------------------------------- |
| ZFS `datapool`        | Removed  | Forensically extracted + destroyed 2026-08-16; disks rebuilt as BTRFS RAID1 backup pool (`/mnt/pool`) |
| OpenZFS on macOS      | Rejected | Kernel panics (ADR-003)                                                                               |
| otel-tui on Darwin    | Rejected | 40+ min builds, disk exhaustion                                                                       |
| ComfyUI               | Removed  | Prefer using AI models via code directly                                                              |
| Authelia              | Removed  | Replaced by Pocket ID (passkey-based, simpler)                                                        |
| Prometheus            | Removed  | Replaced by SigNoz (full-stack observability)                                                         |
| Hyprland              | Removed  | Replaced by Niri (scrollable tiling). grimblast dependency purged (~122 MiB)                          |
| swww wallpaper daemon | Removed  | Ghost service crash-looping 1220+ times/boot. DMS manages wallpapers natively via IPC                 |
| DNS-over-QUIC overlay | Disabled | Breaks binary cache (40+ min builds)                                                                  |
| llama-cpp MFMA flag   | Removed  | No-op on RDNA 3.5 (Strix Halo). Only affects CDNA GPUs                                                |
| SearXNG rate limiter  | Removed  | Private LAN, no abuse vector. Redis removed too                                                       |
| `discard=none`        | Reverted | Would have bricked boot. `nodiscard` mount option confirmed working                                   |
| Git core.compression  | Removed  | Counterproductive for .nix files — poor compression, increases CPU. Level 9 removed                   |
