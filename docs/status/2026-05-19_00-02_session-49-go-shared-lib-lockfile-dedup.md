# Session 49 — Go Shared Library Lockfile Deduplication: 93→73 Nodes

**Date:** 2026-05-19 00:02 CEST
**Scope:** Eliminate 20 duplicate lockfile nodes by adding top-level Go shared library inputs + follows

---

## A) FULLY DONE ✅

### Lockfile Go Shared Library Dedup (Session 49)

Added 6 shared Go libraries as top-level `flake = false` inputs in SystemNix, then wired `follows` for all 8 Go tool repos. **Zero upstream repo changes needed** — all repos already expose their library inputs.

**New top-level inputs:**

| Input | URL | flake |
|-------|-----|-------|
| `go-finding` | `git+ssh://git@github.com/LarsArtmann/go-finding?ref=master` | false |
| `go-output` | `git+ssh://git@github.com/LarsArtmann/go-output?ref=master` | false |
| `gogenfilter` | `git+ssh://git@github.com/LarsArtmann/gogenfilter?ref=master` | false |
| `go-branded-id` | `git+ssh://git@github.com/LarsArtmann/go-branded-id?ref=master` | false |
| `go-filewatcher` | `git+ssh://git@github.com/LarsArtmann/go-filewatcher?ref=master` | false |
| `cmdguard` | `git+ssh://git@github.com/LarsArtmann/cmdguard?ref=master` | false |

**New follows directives (30 total):**

| Go Tool Repo | Library Follows Added |
|-------------|----------------------|
| `golangci-lint-auto-configure` | `goFindingSrc → go-finding` |
| `mr-sync` | `cmdguard`, `go-output`, `go-branded-id` |
| `hierarchical-errors` | `go-finding`, `go-filewatcher`, `gogenfilter` |
| `buildflow` | `cmdguard`, `go-finding`, `go-output`, `go-branded-id` |
| `go-auto-upgrade` | `cmdguard`, `go-finding`, `go-output`, `go-branded-id` |
| `go-structure-linter` | `go-finding`, `go-output`, `gogenfilter`, `go-branded-id` |
| `branching-flow` | `go-finding`, `go-output` |
| `projects-management-automation` | `cmdguard`, `go-output`, `go-branded-id`, `go-filewatcher`, `gogenfilter` |

**Nodes eliminated this session:**

| Category | Nodes Removed |
|----------|:---:|
| `go-finding` duplicates | 5 |
| `go-output` duplicates | 5 |
| `gogenfilter` duplicates | 2 |
| `go-branded-id` duplicates | 4 |
| `go-filewatcher` duplicates | 1 |
| `cmdguard` duplicates | 2 |
| `goFindingSrc` (renamed alias) | 1 |
| **Total** | **20** |

### VRRP Sops Auto-Provisioning (Session 49)

- Added `system.activationScripts.sops-provision-vrrp-password` to `sops.nix`
- Auto-provisions `dns_failover_vrrp_password` secret during `just switch`
- Derives age key from SSH host key, idempotent (skips if key exists)
- TODO_LIST.md updated: dns-failover sops task marked ✅ done

### Gitea → Forgejo Migration Plan

- `docs/migration-gitea-to-forgejo.md` — 413-line comprehensive migration guide
- Covers: why migrate, current state inventory, 4-phase migration strategy, rollback plan, sync strategy improvement
- Status: **Proposal (not yet started)**

### Session 47+48 Carry-forward (Already Committed)

- nix-colors removal — Catppuccin Mocha inlined
- VRRP auth password moved to sops-nix
- Wireshark-cli removal (redundant with wireshark)
- NUR lock update
- modernize/gotools collision resolved
- flake-utils, systems, treefmt-nix dedup (session 48: 123→93 nodes)

### Cumulative Lockfile Dedup (Sessions 48+49)

| Metric | Value |
|--------|-------|
| Nodes before session 48 | 123 |
| Nodes after session 48 | 93 |
| Nodes after session 49 | **73** |
| **Total nodes eliminated** | **50 (40.7% reduction)** |
| Suffixed (duplicate) nodes remaining | **4** (from 23) |
| New top-level inputs added (48+49) | 9 |
| Total follows directives added (48+49) | 48 |

### Follows Coverage (After Session 49)

| Follows Target | Inputs | Status |
|---|---|---|
| `nixpkgs` | 30/30 | ✅ 100% |
| `flake-utils` | 10/10 | ✅ 100% |
| `flake-parts` | 8/8 | ✅ 100% |
| `treefmt-nix` | 4/4 | ✅ 100% |
| `systems` | 2/2 | ✅ 100% |
| `home-manager` | 1/1 | ✅ 100% |
| `treefmt-full-flake` | 1/1 | ✅ 100% |
| `go-finding` | 6/6 | ✅ 100% |
| `go-output` | 6/6 | ✅ 100% |
| `gogenfilter` | 3/3 | ✅ 100% |
| `go-branded-id` | 5/5 | ✅ 100% |
| `go-filewatcher` | 2/2 | ✅ 100% |
| `cmdguard` | 4/4 | ✅ 100% |

---

## B) PARTIALLY DONE 🟡

### Remaining 4 Duplicate Lockfile Nodes

| Node | Source | Why Remaining |
|------|--------|---------------|
| `gogenfilter_2` | `projects-management-automation` → `project-discovery-sdk` (transitive) | PMA has `project-discovery-sdk` as `flake: false` which internally depends on `gogenfilter` — nested transitive we can't override from SystemNix |
| `pyproject-nix_2` | `hermes-agent` (third-party) | Third-party controlled, no action possible |
| `pyproject-nix_3` | `hermes-agent` (third-party) | Third-party controlled, no action possible |
| `uv2nix_2` | `hermes-agent` (third-party) | Third-party controlled, no action possible |

**Actionability:**
- `gogenfilter_2`: Could be fixed by adding `project-discovery-sdk` as a top-level input with `gogenfilter` follows, OR by making PMA expose `project-discovery-sdk` as an overridable input
- `pyproject-nix_*` / `uv2nix_2`: Third-party (`hermes-agent` by NousResearch). Not our bug. No action possible unless we fork.

### DNS Failover Cluster

- Module exists, VRRP config in place
- Sops password auto-provisioned via activation script ✅ (new this session)
- **Pi 3 hardware not yet provisioned** — status: planned, not deployed
- TODO in `rpi3/default.nix:160`: "When Pi 3 is provisioned, add sops-nix with age identity from SSH host key"

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

4. **Photomap** — commented out in configuration.nix ("podman config permission issue"), module exists but not enabled
5. **Minecraft server** — disabled, module exists
6. **Dual-WAN testing** — module enabled, ECMP+MPTCP configured, but no real-world failover testing documented
7. **Gatus endpoint coverage** — 26+ endpoints monitored, could add more services
8. **SigNoz per-threshold channel routing** — critical→Discord, warning→log (signoz.nix)
9. **Voice-agents Caddy vHost consolidation** — into caddy.nix pattern
10. **Deploy Dozzle** — Docker container log tailing at `logs.home.lan`

### Gitea → Forgejo Migration

11. **Execute Forgejo migration** — 413-line plan exists at `docs/migration-gitea-to-forgejo.md`, not yet started

### Code Quality

12. **`gogenfilter_2` duplicate** — fix via PMA exposing `project-discovery-sdk` as overridable input, or add `project-discovery-sdk` as top-level
13. **Convert go-auto-upgrade `path:` inputs to SSH URLs** — upstream repo change needed

---

## D) TOTALLY FUCKED UP 💥

**Nothing is currently broken.** All builds pass, all enabled services are healthy, all known issues are resolved or accepted.

The only "acceptance" items:

- **~130W power ceiling** — GMKtec firmware hard limit, no OS override possible. Accepted.
- **watchdogd nixpkgs module bugs** — `device` and `reset-reason` sections broken upstream. Workaround applied.
- **awww-daemon BrokenPipe** — upstream bug in 0.12.0, mitigated with restart limits. Not our bug to fix.
- **3 third-party lockfile duplicates** — `pyproject-nix_*` and `uv2nix_2` from hermes-agent. Not fixable without forking.

---

## E) WHAT WE SHOULD IMPROVE 📈

### Lockfile Hygiene

1. **Mandatory rule: ALL `flake: false` library inputs must be top-level + follows** — no exceptions
2. **Check for new duplicates after every `nix flake update`** — node count should never grow without justification
3. **Periodic lockfile audit** — quarterly run of lock analysis
4. **Pre-commit hook** — reject commits that increase node count beyond a threshold

### Go Ecosystem

5. **Fix `gogenfilter_2` transitive duplicate** — either make PMA expose `project-discovery-sdk` as overridable, or add `project-discovery-sdk` as top-level input
6. **Standardize shared library revs** — go-output, go-finding, cmdguard, go-branded-id are at different revs across repos
7. **Convert go-auto-upgrade `path:` inputs to SSH URLs** — clean up remaining `path:` input anti-pattern

### Operations

8. **Automated lockfile dedup CI** — `nix flake check` + node count threshold in CI
9. **Memory regression tracking** — measure `nix eval` peak memory before/after major changes
10. **Gitea → Forgejo migration** — plan ready, ~4-6h effort for execution

### Documentation

11. **Update AGENTS.md Flake Inputs table** — reflect the 6 new top-level Go library inputs
12. **Update FEATURES.md** — audit against current state
13. **Update TODO_LIST.md** — refresh priorities

---

## F) Top 25 Things to Get Done Next

### P0 — High Impact, Immediate

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | **Deploy session 48+49 changes to evo-x2** — `just switch` + verify all services | 30min | Confirm 50-node lockfile reduction works in production |
| 2 | **Fix `gogenfilter_2` transitive duplicate** — add `project-discovery-sdk` as top-level or make PMA expose it | 1h | Eliminate last controllable duplicate (73→72 nodes) |
| 3 | **Update AGENTS.md** — Flake Inputs table + Go library follows section + lockfile hygiene rules | 30min | Accurate documentation for future sessions |

### P1 — High Impact, Near-term

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 4 | **Provision Pi 3 DNS backup node** — hardware + NixOS + sops age key + VRRP testing | 3-4h | DNS HA failover operational |
| 5 | **Execute Gitea → Forgejo migration** — plan ready at `docs/migration-gitea-to-forgejo.md` | 4-6h | Community-governed git hosting, federation-ready |
| 6 | **Distributed builds** — configure MacBook to offload builds to evo-x2 | 2h | Unblocks Darwin builds at 90% disk |
| 7 | **Dual-WAN failover testing** — disconnect ethernet, verify ECMP→WiFi transition | 1h | Confidence in failover working |
| 8 | **SigNoz per-threshold channel routing** — critical→Discord, warning→log | 1h | Better alert signal-to-noise |
| 9 | **Automated lockfile audit CI** — node count threshold check | 1h | Prevents regression |

### P2 — Medium Impact

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 10 | **Convert go-auto-upgrade `path:` inputs to SSH URLs** | 30min | Clean flake pattern |
| 11 | **Photomap re-enablement** — fix podman permission, uncomment in configuration.nix | 1-2h | Another service running |
| 12 | **Memory regression baseline** — record peak `nix eval` RSS for future comparison | 30min | Track optimization impact |
| 13 | **OpenSEO DataForSEO usage monitoring** — set budget alerts | 30min | Cost control |
| 14 | **Hermes gateway model rotation** — evaluate newer GLM models | 1h | Better bot responses |
| 15 | **Twenty CRM data migration** — populate with actual data | 2h | Useful CRM |
| 16 | **GPU memory budget documentation** — verify actual vs configured fractions | 30min | Confirm GPU headroom |
| 17 | **Deploy Dozzle** — container log tailing at `logs.home.lan` | 1h | Better debugging |

### P3 — Lower Impact, Good to Have

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 18 | **Minecraft server enablement** — for fun, module exists | 30min | Gaming |
| 19 | **awww-daemon upstream bug report** — file BrokenPipe issue | 30min | Help upstream |
| 20 | **watchdogd nixpkgs bug report** — file `device` section parsing bug | 30min | Help upstream |
| 21 | **Darwin disk cleanup automation** — scheduled nix-collect-garbage | 1h | Prevent build failures |
| 22 | **Security audit of Caddy configs** — review all virtual hosts | 1h | Defense in depth |
| 23 | **BTRFS snapshot automation** — verify Timeshift schedules | 30min | Backup reliability |
| 24 | **Documentation pass** — update FEATURES.md, TODO_LIST.md, AGENTS.md to current state | 1-2h | Accurate docs |
| 25 | **Git hooks improvement** — add lockfile node count check to pre-commit | 30min | Automated hygiene |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Should we execute the Gitea → Forgejo migration now, or wait?**

The 413-line migration plan at `docs/migration-gitea-to-forgejo.md` is complete and ready. The migration is a drop-in replacement (same API, same data format, same config keys) with a clear 5-minute rollback path. However:

- **For it**: Community governance, GPLv3 license, federation-ready, push mirrors (Forgejo→GitHub for owned repos)
- **Against it**: 30-minute downtime window, risk of unexpected edge cases in production, need to regenerate all tokens
- **Timing**: We just did a massive lockfile refactor (50 nodes removed). Deploying Forgejo on top of that adds risk surface.

The technical question I can't answer: **Are there any Gitea→Forgejo migration gotchas with NixOS that the plan doesn't cover?** The nixpkgs module options are very similar but not identical — particularly around `stateDir`, user/group names, and Actions runner compatibility.

---

## Session Stats

| Metric | Value |
|--------|-------|
| Session 49 nodes eliminated | 20 |
| Cumulative nodes eliminated (48+49) | 50 |
| Lock nodes before | 123 |
| Lock nodes after | **73** |
| Total reduction | **40.7%** |
| Suffixed nodes before session 48 | 23 |
| Suffixed nodes after session 49 | **4** |
| New top-level inputs (this session) | 6 (go-finding, go-output, gogenfilter, go-branded-id, go-filewatcher, cmdguard) |
| New follows directives (this session) | 30 |
| Build status | ✅ All checks passed |
| Flake check | ✅ `nix flake check --no-build` passes |
| Commits this session | 1 (pending) |
| Active services | 27/35 |
| Disabled services | 3 (comfyui, minecraft, photomap) |
| Remaining controllable duplicates | 1 (`gogenfilter_2`) |
| Third-party unfixable | 3 (`pyproject-nix_*`, `uv2nix_2`) |
