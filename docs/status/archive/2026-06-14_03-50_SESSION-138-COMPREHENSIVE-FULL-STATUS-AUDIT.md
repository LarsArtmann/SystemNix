# Session 138 — Comprehensive Full Status Audit

**Date:** 2026-06-14 03:50 CEST
**Trigger:** User-requested full comprehensive status update
**Scope:** Entire SystemNix project — infrastructure, packages, overlays, services, patterns, tech debt

---

## System Snapshot

| Metric | Value |
|--------|-------|
| Branch | `master` (clean working tree) |
| `just test-fast` | ✅ All checks passed |
| NixOS system rev | `26.11.20260611.8c91a71` |
| Flake inputs | 52 root inputs, 182 lock nodes |
| Custom Go repos | 26 LarsArtmann Go packages |
| Service modules | 39 in `modules/nixos/services/` |
| Custom packages | 5 in `pkgs/` (aw-watcher-utilization, govalid, jscpd, netwatch, openaudible) |
| Status reports | 189 files (needs archiving) |
| Root disk | **97% full** — 17G remaining of 512G |
| /data disk | 77% — 237G remaining of 1.0T |
| Memory | 32Gi used / 93Gi total (61Gi available) |
| Swap | **18Gi / 19Gi used** (critical) |
| Nix store | 84G |
| GC roots | 853 |

---

## a) FULLY DONE ✅

### Infrastructure — Solid

| Component | Status | Notes |
|-----------|--------|-------|
| Caddy reverse proxy | ✅ Running | All vhosts via `protectedVHost`/`svcUrl` pattern |
| Forgejo | ✅ Running | Port 3000, sops secrets wired |
| Immich | ✅ Running | OAuth via Pocket ID, port 2283 |
| Pocket ID | ✅ Running | OIDC provider, port 1411, declarative provisioning |
| OAuth2-proxy | ✅ Running | Forward-auth for protected vhosts, port 4180 |
| Homepage dashboard | ✅ Running | Port 8082, all tiles with `when` guards |
| Gatus health checks | ✅ Running | Port 9110, 20+ endpoints |
| SigNoz observability | ✅ Running | Custom `signoz.target`, ClickHouse + OTLP |
| DNS blocker | ✅ Running | Mullvad VPN-compatible, DoT forwarding |
| Sops + Age toolchain | ✅ Working | SSH host keys → age via `ssh-to-age` |
| BTRFS snapshots | ✅ Daily | btrbk, auto-pruning 14d+4w, pre-deploy snapshot |
| Taskchampion | ✅ Running | Port 10222 |
| Discordsync | ✅ Running | Enabled |
| Crush Daily | ✅ Running | Port 8081, SDK daemon integration |
| Overview | ✅ Running | Port 8083, SDK daemon consumer |
| Projects-Management-Automation | ✅ Running | Re-enabled (session 137) |
| Hermes | ✅ Config-enabled | Service config wired, blocked on manual steps |
| Ollama | ✅ Running | Port 11434, GPU overhead reservation |
| Dozzle | ✅ Running | Port 8084, inline container config |
| OpenSEO | ✅ Running | Port 3002 |
| Dual WAN | ✅ Running | |
| Mullvad VPN | ✅ Running | DNS-over-TLS through VPN firewall |

### Patterns — Well Established

| Pattern | Status |
|-----------|--------|
| Port centralization (`lib/ports.nix`) | ✅ All ports registered, no conflicts |
| `mkPackageOverlay` for all flake-input overlays | ✅ Platform-safe |
| Caddy vHost consolidation (`caddy.nix`) | ✅ No module defines its own vhosts |
| Homepage tile consolidation (`homepage.nix`) | ✅ `when` guards for conditional tiles |
| `harden` / `hardenUser` / `serviceDefaults` | ✅ All services hardened |
| `onFailure` → `notify-failure@%n.service` | ✅ Centralized via `lib/default.nix` |
| Sops secret guards (`lib.optionalAttrs config.services.X.enable`) | ✅ All guarded |
| `startLimitBurst` on all services | ✅ Prevents crash loops |
| Service auto-discovery (flake-parts) | ✅ `_` prefix for non-module helpers |
| Docker services use `multi-user.target` | ✅ Correct target |
| SigNoz components use `signoz.target` | ✅ Doesn't block `graphical-session` |

### Recent Wins (Last 5 Commits)

| Commit | Description |
|--------|-------------|
| `98251228` | Removed HaGeZi VPN/DoH/Proxy bypass blocklist, whitelisted mullvad.net |
| `510476b4` | **Fixed `go-auto-upgrade` missing `go-error-family.follows`** — eliminated duplicate lock node |
| `020b42aa` | Zellij status-bar pane added to all compact layouts |
| `c4470451` | Session 137 full comprehensive audit |
| `675cafb2` | Restored niri spring animations after performance regression |

---

## b) PARTIALLY DONE 🟡

### Flake Input Follows — Partially Consolidated

**Fixed this session:** `go-auto-upgrade` now follows `go-error-family` (was the only repo missing it).

**Still broken — 5 repos with unfollowed shared deps:**

| Repo | Missing Follow(s) | Lock Node Divergence |
|------|-------------------|---------------------|
| `crush-daily` | `go-error-family`, `go-branded-id` | `_2` duplicates |
| `discordsync` | `go-error-family`, `go-branded-id` | `_3` duplicates |
| `overview` | `go-error-family`, `go-branded-id` | `_5` duplicates |
| `project-meta` | `go-error-family`, `go-branded-id` | `_6` duplicates |
| `projects-management-automation` | `go-error-family`, `go-branded-id`, `go-output`, `cmdguard` | `_7`/`_2`/`_3` duplicates |

**Impact:** 5 duplicate lock nodes inflating `flake.lock`, causing potential version drift if root pins change. These repos could build against different versions of shared deps than the rest of the system.

### Overlay VendorHash Workarounds — 3 Still Active

| Repo | Overlay Pattern | Problem |
|------|----------------|---------|
| `library-policy` | `mkTidyOverride` (proxyVendor + go mod tidy + overrideModAttrs) | Upstream `go.sum` not committed |
| `mr-sync` | `mkTidyOverride` | Upstream `go.sum` not committed |
| `go-auto-upgrade` | `{vendorHash = "sha256-EC61...";}` override | Redundant — hash matches repo's own `vendorHashTidied` |

### Hermes — Enabled but Blocked on Manual Steps

| Step | Blocker |
|------|---------|
| OpenAI API key in sops | Manual secret entry needed |
| SSH deploy key install | Private key → `/home/hermes/.ssh/id_ed25519` + GitHub deploy key |
| Fallback model config | `sudo -u hermes hermes config set fallback_model openrouter/gpt-4o` |

### Twenty CRM — Running but Intermittent 502s

- Caddy logs show `connection refused` / `connection reset` on port 3200
- Likely container OOM or PG connection exhaustion
- Health check at `twenty.nix:45` has hardcoded `http://localhost:3000/healthz` — should use `ports.twenty` (3200) or `cfg.port`

### Darwin (macOS) — Partially Configured

- Home Manager has minimal config (7 lines)
- No terminal, editor, or theme parity with NixOS
- `d2DarwinOverlay` still required for eval
- Disk constrained: 229GB, 90-95% full

---

## c) NOT STARTED ⬜

| Item | Priority | Blocked On |
|------|----------|------------|
| BTRFS `/data` subvolume migration | P3 | None — `just snapshot-migrate-data` |
| `CHANGELOG.md` creation | P4 | None — 185+ commits with no changelog |
| `ROADMAP.md` creation | P4 | None — consolidate `docs/planning/` |
| Status report archiving (189 → ~30 active) | P4 | None |
| Auditd enablement | P6 | NixOS 26.05 bug #483085 |
| AppArmor enablement | P6 | Commented out in `security-hardening.nix` |
| Pi 3 DNS failover provisioning | P6 | Hardware required |
| Darwin HM parity | P6 | Disk constrained |
| Monitor365 agent→server auth | P6 | No auth — anyone on LAN can POST |
| Disabled service triage (voice-agents, minecraft, photomap) | P6 | Decision needed |

---

## d) TOTALLY FUCKED UP 🔴

### 1. Swap Exhaustion — CRITICAL

**18 GiB / 19 GiB swap used** on a 128 GiB RAM machine. This means:
- Stale processes are eating swap (historically: LSP servers like gopls/vtsls)
- `stale-lsp-cleanup` timer may not be catching everything, or other processes are responsible
- `swapoff -a && swapon -a` would reclaim, but root cause unclear
- **Impact:** System sluggishness, potential OOM cascade risk

### 2. Root Disk — 97% FULL

Only 17 GB remaining on a 512 GB root partition. 84 GB is Nix store alone.
- No `nix-collect-garbage` has been run recently
- 853 GC roots is high
- **Impact:** Builds will start failing, system instability

### 3. `go-auto-upgrade` Upstream `flake.nix` — Tech Debt

The repo's own `flake.nix` still uses:
- Manual `preparedSrc` derivation instead of `mkPreparedSource` from `go-nix-helpers`
- `vendorHash = ""` + `vendorHashTidied = "sha256-..."` dual-hash pattern
- `overrideModAttrs` with `go mod tidy` in both phases
- `doCheck = false` (tests broken since `go-finding.MustBuild` panic)
- Version stuck at `0.1.1` (tag only at `v0.1.0`)

### 4. `art-dupl` on `fork` Branch

`art-dupl` tracks `ref=fork` — a non-standard branch. This is fragile and undocumented. If the fork branch is force-pushed or deleted, the build breaks silently.

### 5. 41 Open TODO Items

Accumulated across 7 priority levels. Many are upstream cleanup that's been carried for 10+ sessions (sessions 74-138).

---

## e) WHAT WE SHOULD IMPROVE

### Architecture & Patterns

1. **Massive `flake.lock` bloat** — 182 lock nodes, 90+ duplicate suffixed nodes (`_2` through `_17`). The 5 repos with missing `follows` directives are responsible for dozens of duplicate sub-trees. Fixing follows would dramatically shrink the lock.

2. **VendorHash/workaround sprawl** — 3 repos need build-time `go mod tidy` hacks. Root cause is upstream repos not committing correct `go.sum` files. Each upstream fix eliminates a SystemNix override.

3. **`go-auto-upgrade` redundancy** — The overlay vendorHash override (`sha256-EC61...`) is byte-identical to the repo's own `vendorHashTidied`. The override is a no-op duplicate that will silently drift if either side changes.

4. **189 status reports** — No archiving discipline. `docs/status/` should have ~30 active files max. Pre-session-100 reports should move to `docs/status/archive/`.

5. **Missing CHANGELOG.md** — 185+ commits, no structured changelog. Release notes impossible to generate.

6. **Large modules** — `monitor365.nix` (716L), `signoz.nix` (705L), `forgejo.nix` (583L). These are approaching the threshold where they should be split.

7. **Twenty.nix hardcoded port** — `twenty.nix:45` has `http://localhost:3000/healthz` but the actual port is 3200 (`ports.twenty`). The healthcheck URL is wrong AND hardcoded.

### Operational

8. **Swap pressure** — Root cause investigation needed. `smem -t -k | tail -20` and process audit.

9. **Disk GC** — `nix-collect-garbage --delete-older-than 7d` needed urgently (17G remaining).

10. **No runtime health visibility** — Gatus checks exist but 6 services reportedly show DOWN. Can't verify since `systemctl` is blocked in this environment.

---

## f) Top 25 Things to Get Done Next

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **Run `nix-collect-garbage --delete-older-than 7d`** | Reclaim 10-20G disk | 5min | 🔴 Critical |
| 2 | **Investigate swap** — `smem -t -k \| tail -20`, find swap hogs | Fix 18Gi swap usage | 15min | 🔴 Critical |
| 3 | **Add `go-branded-id.follows` + `go-error-family.follows`** to `crush-daily`, `discordsync`, `overview`, `project-meta`, `projects-management-automation` | Eliminate 5 duplicate lock subtrees | 10min | 🟡 High |
| 4 | **Fix `twenty.nix:45`** — hardcoded wrong port (3000 vs 3200) in healthcheck | Fix broken healthcheck | 2min | 🟡 High |
| 5 | **Remove redundant `go-auto-upgrade` vendorHash override** from `overlays/shared.nix:73` | Eliminate no-op duplicate | 2min | 🟡 High |
| 6 | **Commit correct `go.sum` upstream** for `library-policy` and `mr-sync` → remove `mkTidyOverride` | Eliminate 2 build hacks | 30min | 🟡 High |
| 7 | **Fix `go-auto-upgrade` upstream** — migrate to `mkPreparedSource`, remove dual-hash pattern, fix broken tests, tag v0.2.0 | Eliminate 3 layers of tech debt | 2h | 🟡 High |
| 8 | **Investigate Twenty CRM 502s** — `docker logs twenty-server-1` | Fix intermittent outages | 30min | 🟡 High |
| 9 | **Audit Gatus DOWN services** — fix wrong check URLs | Restore monitoring accuracy | 30min | 🟡 High |
| 10 | **Hermes: add OpenAI API key to sops** | Unblock Hermes AI features | 5min | 🟡 Blocked |
| 11 | **Hermes: install SSH deploy key** | Enable GitHub deploy access | 10min | 🟡 Blocked |
| 12 | **Reboot evo-x2** — verify boot time post NVMe APST fix | Target ~35s (was 6m17s) | 5min | 🟡 Blocked |
| 13 | **BTRFS `/data` migration** — `just snapshot-migrate-data` | Enable snapshots for Docker/Immich/AI data | 15min | 🟢 Medium |
| 14 | **Create CHANGELOG.md** — structure 185+ commits | Release note capability | 1h | 🟢 Medium |
| 15 | **Archive pre-session-100 status reports** — move 159 files to `docs/status/archive/` | Reduce noise | 30min | 🟢 Medium |
| 16 | **Create ROADMAP.md** — consolidate `docs/planning/` | Strategic direction doc | 1h | 🟢 Medium |
| 17 | **Update `TODO_LIST.md`** — fix wrong line references (e.g., `:96` vs `:73`), mark completed items | Accuracy | 15min | 🟢 Medium |
| 18 | **Migrate `go-auto-upgrade` from `preparedSrc` to `go-nix-helpers` `mkPreparedSource`** | Align with AGENTS.md anti-pattern guidance | 1h | 🟢 Medium |
| 19 | **Add `go-output.follows` + `cmdguard.follows`** to `projects-management-automation` | Eliminate last unfollowed go-output/cmdguard | 5min | 🟢 Medium |
| 20 | **Triages disabled services** — voice-agents, minecraft, photomap: enable or remove | Reduce dead config weight | 30min | 🟢 Medium |
| 21 | **Split large modules** — `monitor365.nix` (716L), `signoz.nix` (705L) | Maintainability | 2h | 🔵 Low |
| 22 | **Pin or document `art-dupl` `fork` branch** — why fork? What diverges? | Prevent silent breakage | 15min | 🔵 Low |
| 23 | **Monitor365: add LAN auth** — token-based auth for agent→server | Security | 1h | 🔵 Low |
| 24 | **nixpkgs upstream PRs** — `aw-watcher-utilization` poetry-core, `valkey`/`aiocache` test fixes, `taskwarrior3` flags | Reduce custom overlay maintenance | 4h | 🔵 Low |
| 25 | **Home Manager upstream PRs** — ActivityWatch Wayland deps, theme setting, Darwin user fix | Reduce custom workaround maintenance | 4h | 🔵 Low |

---

## g) Top Question I Cannot Answer

### Why is `projects-management-automation` missing `follows` for 4 different shared deps?

`projects-management-automation` is the worst offender — it doesn't follow `go-error-family`, `go-branded-id`, `go-output`, OR `cmdguard`. Every other repo that uses these deps has at least some follows wired. This pattern suggests either:

1. **The PMA flake.nix doesn't declare these as inputs at all** — it might resolve them transitively through other deps, meaning `follows` is impossible without restructuring its input declaration.
2. **The PMA flake.nix declares them but with different names** — the `follows` key must match the input name in the child flake, not the parent.
3. **Intentional version pinning** — PMA may deliberately use different versions of shared deps (unlikely given the codebase pattern, but possible).

**I cannot determine which without reading the PMA repo's `flake.nix`** (`/home/lars/projects/projects-management-automation/flake.nix` or the GitHub repo). The SystemNix `follows` directive can only work if PMA's own flake declares those inputs with matching names.

**Recommended action:** Check PMA's `flake.nix` input declarations. If they're missing, add them upstream. If they use different names, alias the follows.

---

## Flake Lock Node Deduplication Potential

Fixing all missing follows would collapse:

| Duplicate Pattern | Count | Fixable By |
|-------------------|-------|-----------|
| `go-error-family_2` through `_7` | 6 | Adding follows to 5 repos |
| `go-branded-id_2` through `_7` | 6 | Adding follows to 5 repos |
| `go-output_2` | 1 | Adding follows to PMA |
| `cmdguard_2`, `cmdguard_3` | 2 | Adding follows to mr-sync + PMA |
| `go-nix-helpers_2` through `_10` | 9 | Adding follows to all repos |
| `flake-parts_2` through `_14` | 13 | Adding follows to all repos |
| `treefmt-nix_2` through `_17` | 16 | Adding follows to all repos |
| `systems_2` through `_19` | 18 | Adding follows to all repos |

**Total:** ~71 duplicate nodes eliminable through systematic `follows` additions.

---

## Build & Package Status — All 26 Go Repos

| Repo | Evaluates | Overlay | Notes |
|------|-----------|---------|-------|
| art-dupl | ✅ | `mkPackageOverlay` | On `fork` branch |
| branching-flow | ✅ | `mkPackageOverlay` | Clean |
| buildflow | ✅ | `mkPackageOverlay` | Clean |
| cmdguard | ✅ | Root input only | No overlay needed |
| crush-daily | ✅ | `linux.nix` overlay | Missing 2 follows |
| discordsync | ✅ | NixOS module | Missing 2 follows, no overlay |
| dnsblockd | ✅ | `linux.nix` overlay | Stale vendorHash in linux.nix |
| emeet-pixyd | ✅ | `linux.nix` overlay | Stale vendorHash in linux.nix |
| file-and-image-renamer | ✅ | `linux.nix` overlay | Clean |
| go-auto-upgrade | ✅ | `mkPackageOverlay` + redundant vendorHash | Fixed this session |
| go-branded-id | ✅ | Root input only | No overlay needed |
| go-error-family | ✅ | Root input only | No overlay needed |
| go-finding | ✅ | Root input only | No overlay needed |
| go-filewatcher | ✅ | Root input only | No overlay needed |
| go-output | ✅ | Root input only | No overlay needed |
| go-structure-linter | ✅ | `mkPackageOverlay` | Clean |
| gogenfilter | ✅ | Root input only | No overlay needed |
| golangci-lint-auto-configure | ✅ | `mkPackageOverlay` | Uses `goFindingSrc` alias |
| hierarchical-errors | ✅ | `mkPackageOverlay` | Stale vendorHash, go-finding NOT followed |
| library-policy | ✅ | `mkTidyOverride` | Build-time go mod tidy |
| monitor365 | ✅ | `linux.nix` overlay | Clean |
| mr-sync | ✅ | `mkTidyOverride` | Build-time go mod tidy |
| overview | ✅ | `linux.nix` overlay | Missing 2 follows |
| project-meta | ✅ | `mkPackageOverlay` | Missing 2 follows |
| projects-management-automation | ✅ | `mkPackageOverlay` | Missing 4 follows |
| todo-list-ai | ✅ | `mkPackageOverlay` | Clean |

---

## Service Inventory — Runtime Status (From Config)

| Service | Enabled | Port | Notes |
|---------|---------|------|-------|
| Caddy | ✅ | 80/443/2019 | All vhosts |
| Forgejo | ✅ | 3000 | |
| Immich | ✅ | 2283 | OAuth via Pocket ID |
| Pocket ID | ✅ | 1411 | Declarative provisioning |
| OAuth2-proxy | ✅ | 4180 | |
| Homepage | ✅ | 8082 | |
| SigNoz | ✅ | 8080 | Custom target |
| Gatus | ✅ | 9110 | |
| DNS blocker | ✅ | 53/9090/8050 | DoT via Mullvad |
| Sops | ✅ | — | All secrets guarded |
| Taskchampion | ✅ | 10222 | |
| Display manager | ✅ | — | |
| Audio | ✅ | — | |
| Niri desktop | ✅ | — | Spring animations restored |
| Security hardening | ✅ | — | AppArmor commented out |
| Multi-WM | ✅ | — | |
| Browser policies | ✅ | — | KeePassXC manifests |
| Steam | ✅ | — | |
| Discordsync | ✅ | — | |
| OpenSEO | ✅ | 3002 | |
| Dual WAN | ✅ | — | |
| Mullvad VPN | ✅ | — | |
| AI models | ✅ | — | |
| AI stack | ✅ | — | Ollama + GPU overhead |
| Hermes | ✅ | — | **Blocked on manual steps** |
| Crush Daily | ✅ | 8081 | |
| Overview | ✅ | 8083 | |
| PMA | ✅ | — | Re-enabled |
| Dozzle | ✅ | 8084 | Inline container |
| NVMe health | ✅ | — | |
| Disk monitor | ✅ | — | |
| Voice agents | ❌ | 7860/7880 | Disabled |
| Minecraft | ❌ | 25565 | Disabled |
| Photomap | ❌ | 8051 | Commented out |

---

_Auto-generated by Session 138 comprehensive audit._
