# I/O Scheduling Overhaul — BFQ Priority Tiers for QLC NAND Survival

**Date:** 2026-08-10 02:01
**Session trigger:** SSH session froze during `nix build` + BTRFS scrub. `iotop` showed 20+ kworkers saturating NVMe with `go mod tidy` at 99.99% I/O. User asked: "Can we improve something other than buying a better disk?"
**Status:** Core work DONE, 3 files uncommitted (auto-git swept the first batch)

---

## a) FULLY DONE

### 1. I/O Priority Hierarchy Implemented (14 files, 14 services)

A complete BFQ I/O scheduling tier system was designed and implemented across the entire service fleet:

| Tier | Class | Services | Rationale |
|------|-------|----------|-----------|
| **1** | `best-effort/1` | sshd | Remote access must never be starved |
| **3** | `best-effort/3` | niri, dms, pipewire, crush (alias) | Interactive desktop + AI assistant |
| **4** | default (29 services) | caddy, pocket-id, dnsblockd, gatus, hermes, forgejo, homepage, etc. | Light I/O, network-bound — no change needed |
| **5** | `best-effort/5` | clickhouse, monitor365-server | Heavy databases that should yield to desktop but beat builds |
| **6** | `best-effort/6` | signoz, signoz-collector, browser-history, ollama, atticd, discordsync | Background services with moderate I/O |
| **7** | `best-effort/7` + `Nice=10` | nix-daemon, gitea-runner, projects-management-automation | Build-heavy — lowest priority, yields to everything |
| **idle** | `idle` | fstrim, clamav-daemon | Maintenance tasks — only run when disk is otherwise free |

**Files changed (committed by auto-git in `4691be1f`):**
- `platforms/nixos/system/boot.nix` — sshd (BE/1), dms+pipewire (BE/3)
- `platforms/nixos/system/networking.nix` — nix-daemon (BE/7, Nice=10)
- `platforms/nixos/desktop/niri-config.nix` — niri (BE/3, via unit file text injection)
- `modules/nixos/services/monitor365.nix` — monitor365-server (BE/5)
- `modules/nixos/services/signoz.nix` — clickhouse (BE/5), signoz-collector (BE/6)
- `modules/nixos/services/attic.nix` — atticd (BE/6)
- `modules/nixos/services/discordsync.nix` — discordsync (BE/6)
- `modules/nixos/services/forgejo.nix` — gitea-runner (BE/7, Nice=10)
- `modules/nixos/services/projects-management-automation.nix` — PMA (BE/7, Nice=10)
- `modules/nixos/services/security-hardening.nix` — clamav-daemon (idle)
- `platforms/common/programs/shell-aliases.nix` — crush alias (ionice wrapper)

**Files changed (UNCOMMITTED — post `4691be1f`):**
- `modules/nixos/services/signoz.nix` — signoz query server (BE/6)
- `modules/nixos/services/browser-history.nix` — browser-history (BE/6)
- `modules/nixos/services/ai-stack.nix` — ollama (BE/6)

### 2. Disabled `auto-optimise-store`

`platforms/common/nix-settings.nix`: Changed `auto-optimise-store = true` → `false`.
- Was running hardlink dedup after EVERY build, generating random read I/O competing with the build itself
- `optimise.automatic = true` (daily ~04:00 via `nix-optimise.timer`) already covers periodic dedup
- Net effect: eliminates per-build I/O tax, dedup happens once during low-activity hours

### 3. Crush Shell Alias

`platforms/common/programs/shell-aliases.nix`: Added `crush = "ionice -c 2 -n 3 nice -n 5 crush"`.
- Elevates Crush to BE/3 when launched interactively (above builds at BE/7)
- **Limitation:** Only works in interactive fish/bash/zsh shells — keybindings or program launches bypass it

### 4. Verification

- `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` passes clean (both batches)
- All changes use `mkMerge` with separate I/O priority attrsets — no priority clobbering
- No `harden {}` ExecStart trap violations (I/O settings merged outside harden blocks)

---

## b) PARTIALLY DONE

### Crush I/O Priority (alias only, not wrapper package)
The shell alias approach is fragile — only works in interactive shells. A proper `writeShellApplication` wrapper in `pkgs/` would guarantee BE/3 regardless of invocation method. User was asked if they want this converted; no answer yet.

### 29 Services at Default BE/4 (not individually classified)
These services were identified but left at default. They are light-I/O (network-bound, SQLite-light, containerized), so BE/4 is reasonable. A detailed per-service audit could fine-tune some of them:
- **Core infra:** caddy, pocket-id, dnsblockd, oauth2-proxy, keepalived
- **Databases:** forgejo, taskchampion-sync-server
- **Dashboards/UIs:** homepage-dashboard, gatus, searx, dozzle, openseo
- **Agents/collectors:** cadvisor, monitor365 (agent), browser-history-agent, route-health-monitor
- **App services:** hermes, crush-daily, immich-server, immich-machine-learning, minecraft-server, file-and-image-renamer-health, overview
- **Docker compose:** twenty, whisper-asr, manifest

---

## c) NOT STARTED

1. ~~**Deploy** — none of these changes have been deployed. Eval passes, but real-world BFQ behavior during build storms is unverified~~ done — deployed; deploy fallout fixed in 02-53 report
2. ~~**Gatus monitoring** — no alerting for "I/O contention above threshold" exists. The system-health textfile collector doesn't export I/O wait metrics~~ done — PSI I/O pressure check at `post-deploy-check.sh:542`
3. ~~**AGENTS.md update** — the I/O tier system, the `auto-optimise-store` rationale, and the Crush alias all need to be documented~~ done — BFQ I/O Priority Tiers section in AGENTS.md
4. **Build parallelism reduction** (`build-max-jobs` 4→2) — discussed but user did not request it
5. **`nix-daemon.service` CPUQuota** — discussed but not implemented (BFQ I/O scheduling should be sufficient)

---

## d) TOTALLY FUCKED UP

### BFQ False Alarm
I initially told the user: "BFQ scheduler is loaded but **never activated** — Your NVMe is running with the default scheduler (`none` or `mq-deadline`), which ignores I/O priorities entirely."

This was **WRONG**. Checking `/sys/block/nvme0n1/queue/scheduler` showed `[bfq]` — BFQ was already the active scheduler. Loading the module via `kernelModules = [ "bfq" ]` was sufficient on this kernel. I caused unnecessary alarm and proposed adding `elevator=bfq` kernel params that were not needed.

**Root cause of the error:** I assumed `kernelModules` only loads the module without setting it as the scheduler. In reality, BFQ becomes the default scheduler for the device when it's the only module loaded and the kernel defaults to it for NVMe on this config. I should have checked `cat /sys/block/nvme0n1/queue/scheduler` BEFORE making claims.

**Lesson:** Verify runtime state before making architecture claims. The module being in `kernelModules` was a strong hint it was active; I should have confirmed rather than assumed it was inert.

### Auto-Git Mixed Sessions
The auto-git daemon committed the first batch of I/O changes in `4691be1f`, but the commit message and diff also include **work from a prior session** (sops.nix changes, test-scripts.nix, flake.lock updates, 40+ script changes, configuration.nix hermes disable). The commit message references things I did not do in this session. This is expected behavior per the project's auto-git daemon but makes the history harder to read.

---

## e) WHAT WE SHOULD IMPROVE

### Immediate
1. **Verify BFQ is actually respecting priorities at runtime** — after deploy, run `iotop` during a build and confirm nix-daemon shows lower IO% than sshd
2. **Consider `build-max-jobs = 2`** — halves concurrent write pressure. The I/O scheduling helps fairness but doesn't reduce total I/O volume. 4 concurrent Go/Rust builds writing to CoW BTRFS is still a lot
3. ~~**Convert Crush alias to wrapper package** — guarantees BE/3 from all invocation paths~~ done at `50fd16c4` — wrapper in `platforms/common/packages/base.nix` with `ionice -c 2 -n 3 nice -n 5`
4. ~~**Document the tier system in AGENTS.md** — under a new "I/O Scheduling" section, so future services get the right tier by default~~ done — BFQ I/O Priority Tiers section in AGENTS.md

### Architectural
5. ~~**I/O tier helper in `lib/default.nix`** — instead of hand-writing `IOSchedulingClass`/`IOSchedulingPriority` in every service, create helpers like `ioTier.interactive`, `ioTier.background`, `ioTier.build` that expand to the right systemd directives. This prevents drift and makes tier changes a one-liner~~ done at `6a2b642d`
6. **Docker/OCI containers bypass cgroup I/O scheduling** — Docker services (twenty, whisper-asr, manifest, immich) run in their own cgroup hierarchy. `IOSchedulingClass` on the `docker.service` unit applies to the daemon, not individual containers. Consider `blkio` cgroup weights per container if these become I/O issues
7. **`commit=600` on BTRFS mounts** — currently `commit=300` (5 min). Doubling to 10 min halves metadata write frequency further. Data loss window grows to 10 min (acceptable with daily btrbk snapshots). This directly reduces kworker pressure during builds
8. **Separate `/nix` subvolume** — currently `/nix` lives inside `@` (root subvolume). A dedicated `@nix` subvolume would isolate nix store CoW churn from root filesystem snapshots and could be mounted with different options (e.g., `noatime,compress=zstd,commit=600` without affecting root)

---

## f) Up to 50 Things to Get Done Next

### I/O Scheduling (1-8)
1. ~~Deploy the changes and verify BFQ priorities work at runtime via `iotop`~~ done — `verify-io-tiers.sh` exists; deployed with fixes in 02-53
2. ~~Commit the 3 uncommitted files (signoz, browser-history, ollama)~~ done — committed by auto-git daemon
3. ~~Create I/O tier helpers in `lib/default.nix` (`ioTier.interactive`, `.background`, `.build`)~~ done at `6a2b642d`
4. ~~Convert Crush alias to `writeShellApplication` wrapper package in `pkgs/`~~ done at `50fd16c4`
5. Add `build-max-jobs = 2` (reduce concurrent write pressure)
6. ~~Document the I/O tier system in AGENTS.md under "I/O Scheduling"~~ done — BFQ I/O Priority Tiers section in AGENTS.md
7. Add `commit=600` to BTRFS mounts (`/` and `/data`)
8. Evaluate dedicated `@nix` BTRFS subvolume for nix store isolation

### Monitoring (9-14)
9. ~~Add I/O wait metric to `system-health` textfile collector (export `system_io_wait_percent`)~~ done — PSI I/O pressure check in `post-deploy-check.sh:542`
10. Add Gatus alert for sustained high I/O wait (>80% for 5 min)
11. Add Gatus alert for nix-daemon I/O dominance (check via `iotop` cron or eBPF)
12. Monitor `nix-optimise.timer` duration after disabling `auto-optimise-store` — daily dedup may take longer than expected
13. Add NVMe SLC cache health metric if available via smartctl
14. Track BTRFS kworker count/utilization as a Prometheus metric

### Build System (15-20)
15. Add `ionice -c 2 -n 7` wrapper for `nix build` in shell aliases (manual builds)
16. Evaluate `nix-daemon.service` `CPUQuota=400%` (cap build CPU during desktop use)
17. Set up Attic cache for all LarsArtmann Go packages to eliminate redundant builds
18. Audit `vendorHash` freshness — stale vendor hashes force full rebuilds
19. Consider `nix.settings.max-substitution-jobs` or similar to parallelize downloads
20. Profile which derivations are the I/O hogs (likely Go vendor + Rust cargo vendor)

### Desktop & Interactive (21-26)
21. Add ionice wrappers for `go`, `cargo`, `npm`, `pnpm` in shell aliases
22. Elevate `helium` (browser) user service to BE/3 (interactive)
23. Elevate `qmd-mcp` user service if it does disk I/O during searches
24. Check if `niri-drm-healthcheck` needs I/O priority (it reads DRM state — probably not disk-bound)
25. Add `aw-server` (ActivityWatch) to BE/6 if it does SQLite writes
26. Audit all `systemd.user.services` for I/O priority gaps

### Services (27-35)
27. Set forgejo server (not runner) to BE/5 — Git operations are I/O heavy
28. Set immich-machine-learning to BE/6 — model loading + photo processing
29. Set minecraft-server to BE/5 — chunk I/O is persistent
30. Set hermes to BE/5 — state DB writes
31. Set taskchampion-sync-server to BE/6 — SQLite sync
32. Audit Docker container I/O — add `blkio.weight` per container if needed
33. Set monitor365 agent (not server) to BE/6 — it reads system state frequently
34. Set browser-history-agent to BE/6 — reads browser SQLite profiles
35. Set cadvisor to BE/6 — reads cgroup stats continuously

### BTRFS & Filesystem (36-42)
36. Evaluate `compress=zstd:1` on `/` (faster compression = less CPU, more space — trades may help I/O)
37. Enable BTRFS `fragment_data` debug to check CoW fragmentation levels
38. Profile write amplification factor during a `nix build`
39. Consider `nodatacow` for `/nix/store` (disables CoW for store — reduces amplification but loses checksums)
40. Move `/tmp` build temp dirs to ext4 (like `/rust-cache`) to avoid BTRFS CoW for transient files
41. Evaluate BTRFS `commit=` vs kernel `dirty_ratio` interaction — current `dirty_ratio=10` may interact poorly with `commit=300`
42. Benchmark `go mod tidy` I/O on ext4 vs BTRFS to quantify the CoW tax

### Documentation & Process (43-50)
43. ~~Update AGENTS.md "Non-Obvious Gotchas" with BFQ I/O scheduling notes~~ done — BFQ I/O Priority Tiers section in AGENTS.md
44. Add I/O tier decision guide to `docs/CONTRIBUTING.md` for new services
45. ~~Document the `auto-optimise-store` removal rationale in AGENTS.md~~ done — documented in AGENTS.md BFQ section
46. Add pre-deploy check for IOSchedulingClass presence on new services
47. Write a runbook for "SSH slow during builds" troubleshooting
48. Add I/O tier classification to the service inventory in AGENTS.md
49. Document BFQ vs mq-deadline vs none tradeoffs for QLC NAND
50. Create a "service I/O profile" template for new service PRs

---

## g) Questions (3 max — things I genuinely cannot determine)

### Q1: Should we reduce `build-max-jobs` from 4 to 2?
I/O scheduling makes builds *fair* (they yield to interactive), but 4 concurrent derivations writing to CoW BTRFS still generate massive total I/O volume. Halving to 2 would roughly halve write pressure at the cost of ~2x build time. You value responsiveness over build speed, but 2x slower builds is a significant tradeoff. Only you can decide this tradeoff.

### Q2: Do you want the Crush alias converted to a proper wrapper package?
The alias only works in interactive shells. If you launch Crush from a keybinding, DMS launcher, or another program, it won't get BE/3. A `writeShellApplication` wrapper in `pkgs/` would guarantee it always runs at the right priority. I can't determine if you launch Crush non-interactively.

### Q3: Are you OK with `commit=600` (10-minute data loss window on crash)?
Doubling `commit` from 300→600 halves metadata write frequency, directly reducing kworker pressure during builds. The tradeoff is a 10-minute data loss window on power failure (vs current 5 min). With daily btrbk snapshots + CoW journaling consistency, 5 vs 10 minutes is unlikely to matter — but only you can make the data-loss-vs-performance call.

---

## Resolution (2026-08-10)

Initial I/O scheduling work. Superseded by 04-59 report (Pareto execution). BFQ tier system fully implemented: `ioTier` helpers in `lib/default.nix`, 14+ services classified, Crush wrapper, verify-io-tiers script. Deploy fallout fixes in 02-53 report. Work captured in CHANGELOG [Unreleased]. Remaining items (`//` → mkMerge, raw literals, GOMEMLIMIT validation) harvested into TODO_LIST.
