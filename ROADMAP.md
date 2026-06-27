# SystemNix Roadmap

_Long-term direction and raw ideas not yet refined into actionable tasks._

For short-term actionable work, see [TODO_LIST.md](./TODO_LIST.md). For current feature status, see [FEATURES.md](./FEATURES.md).

---

## Theme 1: Reliability & Resilience

The system has been hardened through multiple OOM/crash cycles. Remaining work:

- **Automated BTRFS `/data` subvolume migration** — `/data` is BTRFS toplevel (subvolid=5), cannot be snapshotted. Migration plan:
  1. Boot from USB rescue (cannot modify mounted `/data`)
  2. `btrfs subvolume create /data/@data` (under the toplevel)
  3. `rsync -aHAX --info=progress2 /data/ /data/@data/` (excluding `@data` itself)
  4. Update fstab: add `subvol=@data` to the `/data` mount entry
  5. Reboot, verify `/data` mounts the new subvolume
  6. Add `@data` to btrbk config for snapshot protection
  7. Clean up old toplevel data (after verifying snapshots work)
  Requires ~1h downtime window. Docker containers on `/data/docker` will be stopped.
- **Cloud backup** — no off-site backup exists. Evaluate BorgBackup to Hetzner StorageBox (see `docs/research/hetzner-storagebox-borgbackup.md`). Critical for disaster recovery.
- **Provision Raspberry Pi 3** — hardware needed for DNS failover cluster (VRRP). Module and config ready, hardware not purchased.
- **Auditd enablement** — blocked on NixOS 26.05 bug #483085. Re-evaluate when fixed upstream.
- **Disk space monitoring** — Darwin is 90%+ full on 256GB SSD. Need automated alerting before builds fail.

---

## Theme 2: Security Hardening

- **Firewall deny-by-default** — NixOS currently allows all inbound. Docker punches its own holes. Transition to explicit allowlist.
- **Bind Immich to localhost** — currently on `0.0.0.0` with `openFirewall`. Caddy already reverse-proxies.
- **Remove legacy ssh-rsa** from accepted algorithms (kept for macOS client compat — evaluate dropping)
- **Monitor365 agent→server auth** — no authentication, anyone on LAN can POST data
- **AppArmor enablement** — currently `mkDefault false` in security-hardening.nix

---

## Theme 3: Desktop Experience

- **QuickShell / DankMaterialShell** — DONE (v1.4.6 deployed). 13 SystemNix plugins verified. Remaining follow-ups: auto-detect WAN/NPU interfaces (done), declarative Catppuccin accent service, DMS launcher evaluation
- **Darwin Home Manager parity** — macOS HM config is minimal (no terminal, editor, theme parity). Blocked by 256GB disk constraint.
- **Disabled service triage** (decided 2026-06-25):
  - **voice-agents**: KEEP disabled — LiveKit + Whisper needs GPU resource planning, not ready for daily use
  - **minecraft**: KEEP server disabled, client settings (Prism Launcher) stay enabled — server is seasonal
  - **photomap**: REMOVE — podman config permission issue, niche feature, maintenance burden without clear use
  - **DiscordSync**: ✅ Reactivated — upstream migrated to go-cqrs-lite v3 (ADR-0030). GCS attachment backup available via opt-in `gcsBucket` (needs bucket name + service account JSON in sops)

---

## Theme 4: Architecture & Code Quality

- **Split large modules** — `monitor365.nix` (716L), `signoz.nix` (705L), `forgejo.nix` (583L) are too large. Extract sub-modules.
- **Extract dnsblockd** — ~930 lines of production Go embedded in the Nix config. Candidate for standalone repo (see `docs/planning/2026-05-03_02-52_extract-dnsblockd-from-systemnix.md`).
- **Typed NixOS module options** — many modules use `mkEnableOption` only. Add typed options for ports, paths, timeouts → enables validation and testing.
- **dnsblockd category enum** — categories are stringly-typed (10 hardcoded strings). Define Go enum type.

---

## Theme 5: Upstream Contributions

Items that benefit the broader Nix ecosystem:

- **nixpkgs PRs**: `aw-watcher-utilization` poetry-core migration, `valkey`/`aiocache` test fixes, `taskwarrior3` build flags, Kitty GC resilience patch, KeePassXC Chromium manifests, `llama-cpp` ROCm MMFMA flag
- **Home Manager PRs**: ActivityWatch Wayland watcher deps, ActivityWatch theme option, Darwin user definition requirement (#6036)
- **Third-party**: `jscpd` lockfile publishing, XRT boost 1.87+ compat for `nix-amd-npu`

See [TODO_LIST.md](./TODO_LIST.md) Priority 5 for detailed task breakdowns.

---

## Theme 6: AI/ML Workloads

- **Jan llama-server respawn** — spawns new `llama-server` every 1-3 min (~1.2GB each). Not a systemd service, no cgroup limits. Needs investigation.
- **Voice agents** — LiveKit + Whisper Docker pipeline disabled. Decide: enable with proper resource limits, or remove.
- **NPU utilization** — AMD XDNA driver loaded but no workloads using it. Explore ONNX Runtime / Ryzen AI SDK integration.

---

## Deferred / Rejected Ideas

| Idea | Status | Reason |
|------|--------|--------|
| OpenZFS on macOS | Rejected | Kernel panics (ADR-003) |
| otel-tui on Darwin | Rejected | 40+ min builds, disk exhaustion |
| ComfyUI | Removed | Prefer using AI models via code directly |
| Authelia | Removed | Replaced by Pocket ID (passkey-based, simpler) |
| Prometheus | Removed | Replaced by SigNoz (full-stack observability) |
| Hyprland | Removed | Replaced by Niri (scrollable tiling) |
| DNS-over-QUIC overlay | Disabled | Breaks binary cache (40+ min builds) |
