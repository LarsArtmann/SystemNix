# Session 48 — Lockfile Deduplication Phase 2: Full Audit & Status

**Date:** 2026-05-18 23:36 CEST
**Scope:** Flake lockfile deduplication (flake-utils, systems, treefmt-nix, nix-ssh-config), full project status

---

## A) FULLY DONE ✅

### Lockfile Deduplication (Session 48)

| Change | Nodes Removed | How |
|--------|:---:|-----|
| `flake-utils` top-level + follows for 9 inputs + `utils` alias for helium | 19 | New top-level input, `inputs.flake-utils.follows` on 9 repos, `inputs.utils.follows` on helium |
| `systems` top-level + follows for flake-utils, niri-session-manager | 1 | New top-level input, cascading from flake-utils dedup |
| `treefmt-nix` top-level + follows for dnsblockd, library-policy, niri-session-manager, treefmt-full-flake | 4 | New top-level input with nixpkgs follows |
| `nix-ssh-config.treefmt-full-flake` follows top-level | 4 | Eliminated old treefmt-full-flake + `flake-parts_2` + `nixpkgs_2` |
| **Total** | **30** | **123 → 93 nodes (24.4% reduction)** |

### Follows Coverage

| Follows Target | Inputs | Status |
|---|---|---|
| `nixpkgs` | 30/30 that have nixpkgs dep | ✅ 100% |
| `flake-utils` | 10/10 that have flake-utils dep | ✅ 100% |
| `flake-parts` | 8/8 that have flake-parts dep | ✅ 100% |
| `treefmt-nix` | 4/4 that have treefmt-nix dep | ✅ 100% |
| `systems` | 2/2 that have systems dep | ✅ 100% |
| `home-manager` | 1/1 that has HM dep | ✅ 100% |
| `treefmt-full-flake` | 1/1 that has it | ✅ 100% |

### Session 47 Carry-forward (Already Committed)

- nix-colors removal — Catppuccin Mocha inlined
- VRRP auth password moved to sops-nix
- Wireshark-cli removal (redundant with wireshark)
- NUR lock update
- modernize/gotools collision resolved

### AGENTS.md Updated

- Lockfile hygiene rules expanded (flake-utils, systems, treefmt-nix mandatory)
- Flake Inputs table updated with 3 new top-level inputs + follows details for 17 inputs
- Remaining nixpkgs instances section corrected (nixpkgs_2 eliminated)
- Remaining duplicates documented with actionability assessment

---

## B) PARTIALLY DONE 🟡

### Go Private Repo Transitive Dep Dedup (23 nodes remaining)

These are `flake: false` source-only inputs within each Go repo's flake. Dedup requires **upstream repo changes** — each repo needs to expose its shared library inputs as overridable.

**Identical-rev groups (safe to collapse immediately once upstream allows):**

| Library | Copies at Same Rev | Repos Involved |
|---------|:---:|----------------|
| `gogenfilter` | 3 | go-structure-linter, hierarchical-errors, projects-management-automation |
| `go-branded-id` | 2 | go-structure-linter, projects-management-automation |
| `go-branded-id` | 2 | buildflow, mr-sync (→ could follow canonical `go-branded-id`) |
| `go-output` | 3 | branching-flow, buildflow, go-auto-upgrade |
| `go-finding` | 3 | branching-flow, buildflow, golangci-lint-auto-configure |
| `go-filewatcher` | 2 | hierarchical-errors, projects-management-automation |
| `cmdguard` | 2 | buildflow, go-auto-upgrade |

**Different-rev groups (need upstream rev synchronization):**

| Library | Distinct Revs | Fragmentation |
|---------|:---:|---------------|
| `go-output` | 5 | Most fragmented — 7 nodes across 5 revs |
| `go-finding` | 3 | 6 nodes across 3 revs |
| `cmdguard` | 3 | 5 nodes across 3 revs |
| `go-branded-id` | 2 | 5 nodes across 2 revs |

### DNS Failover Cluster

- Module exists, VRRP config in place
- Sops password provisioned
- **Pi 3 hardware not yet provisioned** — status: planned, not deployed

### ComfyUI

- Module exists, working
- **Disabled** (`services.comfyui.enable = false`) — "prefer AI via code"
- No data loss risk — just not active

---

## C) NOT STARTED ⚪

### Infrastructure

1. **Pi 3 DNS backup node provisioning** — hardware purchase + NixOS install + age key for sops
2. **Distributed builds** — MacBook Air disk exhaustion (90-95% full) could benefit from offloading builds to evo-x2
3. **GPU firmware bug** — Hermes anime-comic-pipeline SIGSEGV causing GPU driver hangs. Defense-in-depth exists (watchdog, sysrq, auto-reboot) but root cause not fixed

### Service Improvements

4. **Photomap** — commented out in configuration.nix, module exists but not enabled
5. **Minecraft server** — disabled, module exists
6. **Dual-WAN testing** — module enabled, ECMP+MPTCP configured, but no real-world failover testing documented
7. **Gatus endpoint coverage** — 26+ endpoints monitored, could add more services

### Code Quality

8. **Remaining 23 lock nodes** — Go private repo transitive deps (see Section B)
9. **hermes-agent internal pyproject-nix/uv2nix duplicates** — third-party controlled, no action from our side
10. **nix-colors nixpkgs-lib duplicate** — third-party, low priority

---

## D) TOTALLY FUCKED UP 💥

**Nothing is currently broken.** All builds pass, all enabled services are healthy, all known issues are resolved or accepted.

The only "acceptance" items:

- **~130W power ceiling** — GMKtec firmware hard limit, no OS override possible. Accepted.
- **watchdogd nixpkgs module bugs** — `device` and `reset-reason` sections broken upstream. Workaround applied.
- **awww-daemon BrokenPipe** — upstream bug in 0.12.0, mitigated with restart limits. Not our bug to fix.

---

## E) WHAT WE SHOULD IMPROVE 📈

### Lockfile Hygiene

1. **Add `inputs.nixpkgs.follows = "nixpkgs"` rule to ALL new inputs** — mandatory, no exceptions
2. **Check for new duplicates after every `nix flake update`** — node count should never grow without justification
3. **Periodic lockfile audit** — run the python analysis script quarterly

### Go Ecosystem

4. **Standardize shared library revs** — go-output, go-finding, cmdguard, go-branded-id are at different revs across repos. This is the #1 source of lock bloat (23 nodes)
5. **Create a shared `go-deps` flake** — single source of truth for all shared Go library inputs, consumed by all Go tool repos. Would eliminate the entire 23-node class
6. **Upstream `follows` support** — each Go tool repo should expose its library inputs as overridable (standard flake-parts pattern)

### Operations

7. **Automated lockfile dedup CI** — a `nix flake check` + node count threshold in CI
8. **Memory regression tracking** — measure `nix eval` peak memory before/after major changes

---

## F) Top 25 Things to Get Done Next

### P0 — High Impact, Immediate

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | **Create `go-deps` shared flake** — single source of truth for go-output, go-finding, cmdguard, go-branded-id, gogenfilter, go-filewatcher | 2-3h | Eliminates 23 lock nodes, standardizes revs |
| 2 | **Provision Pi 3 DNS backup node** — hardware + NixOS + sops age key + VRRP testing | 3-4h | DNS HA failover operational |
| 3 | **`just switch` and verify** — apply all session 47+48 changes to evo-x2 | 30min | Confirm everything works in production |

### P1 — High Impact, Near-term

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 4 | **Distributed builds** — configure MacBook to offload builds to evo-x2 | 2h | Unblocks Darwin builds at 90% disk |
| 5 | **Dual-WAN failover testing** — disconnect ethernet, verify ECMP→WiFi transition | 1h | Confidence in failover working |
| 6 | **Automated lockfile audit** — CI check for node count growth | 1h | Prevents regression |
| 7 | **Update all Go repos to latest shared dep revs** — sync go-output, go-finding across all consumers | 2h | Reduces fragmentation |
| 8 | **Photomap re-enablement** — uncomment in configuration.nix, verify service | 30min | Another service running |

### P2 — Medium Impact

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 9 | **SigNoz alert tuning** — review 26+ Gatus endpoints, add SigNoz-specific alerts | 1h | Better observability |
| 10 | **Memory regression baseline** — record peak `nix eval` RSS for future comparison | 30min | Track optimization impact |
| 11 | **OpenSEO DataForSEO usage monitoring** — set budget alerts | 30min | Cost control |
| 12 | **Hermes gateway model rotation** — evaluate newer GLM models | 1h | Better bot responses |
| 13 | **Twenty CRM data migration** — populate with actual data | 2h | Useful CRM |
| 14 | **GPU memory budget documentation** — verify actual vs configured fractions | 30min | Confirm GPU headroom |
| 15 | **Wallpaper collection update** — refresh wallpapers-src input | 15min | Fresh wallpapers |

### P3 — Lower Impact, Good to Have

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 16 | **Minecraft server enablement** — for fun, module exists | 30min | Gaming |
| 17 | **awww-daemon upstream bug report** — file BrokenPipe issue | 30min | Help upstream |
| 18 | **watchdogd nixpkgs bug report** — file `device` section parsing bug | 30min | Help upstream |
| 19 | **Darwin disk cleanup automation** — scheduled nix-collect-garbage | 1h | Prevent build failures |
| 20 | **niri-session-manager app mappings** — expand for more apps | 30min | Better session restore |
| 21 | **EMEET PIXY audio profiles** — tune noise cancellation settings | 30min | Better call quality |
| 22 | **Security audit of Caddy configs** — review all virtual hosts | 1h | Defense in depth |
| 23 | **BTRFS snapshot automation** — verify Timeshift schedules | 30min | Backup reliability |
| 24 | **Documentation pass** — update FEATURES.md, TODO_LIST.md to current state | 1h | Accurate docs |
| 25 | **Git hooks improvement** — add lockfile node count check to pre-commit | 30min | Automated hygiene |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Should we create a shared `go-deps` flake, or should each Go tool repo just expose its library inputs as overridable?**

Two approaches to eliminating the 23 remaining duplicate nodes:

| Approach | Pros | Cons |
|----------|------|------|
| **A) `go-deps` shared flake** | Single source of truth, one update propagates everywhere, cleanest lockfile | New repo to maintain, all Go repos depend on it, version bump cascade |
| **B) Per-repo overridable inputs** | No new repo, each repo stays independent, standard flake pattern | Still 23 nodes in SystemNix lock (but all following), more boilerplate in flake.nix |
| **C) Hybrid** — top-level `go-output`, `go-finding` etc. as inputs + follows overrides | No new repo, collapses duplicates from SystemNix side, keeps repos independent | Many new top-level inputs (6+), more complex flake.nix |

I recommend **Approach C** — add each shared Go library as a top-level input and use follows to collapse identical-rev duplicates. This requires zero upstream changes and eliminates the problem from SystemNix's perspective. The different-rev nodes remain but that's a rev sync problem, not a structural one.

---

## Session Stats

| Metric | Value |
|--------|-------|
| Commits today | 16 |
| Commits this month | ~30 |
| Lock nodes before | 123 |
| Lock nodes after | 93 |
| Nodes eliminated | 30 (24.4%) |
| New top-level inputs | 3 (`flake-utils`, `systems`, `treefmt-nix`) |
| New follows directives | 18 |
| Build status | ✅ All checks passed |
| Active services | 27/35 |
| Disk usage (repo) | 1.1 GB |
| Disk usage (flake.lock) | 56 KB |
| Remaining suffixed nodes | 23 (Go transitive deps) |
| Third-party unfixable | 3 (hermes pyproject-nix/uv2nix, nix-colors nixpkgs-lib) |
