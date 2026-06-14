# Session 139 — Comprehensive Full Status Audit (Post-Follows Consolidation)

**Date:** 2026-06-14 09:39 CEST
**Trigger:** User-requested full comprehensive status update
**Scope:** Entire SystemNix — infrastructure, packages, overlays, flake hygiene, runtime health
**Previous Report:** Session 138 (03:50 — 6 hours ago)

---

## What Changed Since Session 138

| Change | Impact |
|--------|--------|
| **Flake follows consolidation** (commit `0e8207d4`) | Added missing `follows` for 7 repos — eliminated 38 duplicate lock nodes (182→144) |
| **go-auto-upgrade vendorHash override removed** | Was byte-identical to upstream's own hash — no-op duplicate |
| **System rebooted** | Uptime now 1h 3m. Disk freed: 97%→91% (17G→50G available) |
| **Swap unchanged** | Still 19Gi/19Gi — reboot did NOT fix the swap pressure |
| **TODO_LIST.md updated** | Fixed wrong line references, marked completed items |

---

## System Snapshot

| Metric | Value | Trend |
|--------|-------|-------|
| Branch | `master` (clean) | ✅ |
| `just test-fast` | ✅ All checks passed | ✅ |
| Flake lock nodes | **144** (was 182) | ✅ -38 |
| Root inputs | 52 | — |
| Go repos | 26 LarsArtmann packages | — |
| Service modules | 39 | — |
| Status reports | 190 files (needs archiving) | 🟡 +1 |
| Root disk | **91% full** — 50G remaining of 512G | ✅ Improved from 97% |
| /data disk | 77% — 237G remaining of 1.0T | — |
| Nix store | 85G | — |
| Memory | 46Gi used / 93Gi total (46Gi available) | — |
| Swap | **19Gi / 19Gi used** — 7Mi free | 🔴 CRITICAL |
| Load average | **14.60 / 21.43 / 26.26** | 🔴 Very high |
| Total processes | 858 | 🔴 High |
| gopls instances | **21** | 🔴 Way too many |
| Helium renderers | 43 | 🟡 Electron bloat |

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
| Gatus health checks | ✅ Config wired | Port 9110, 20+ endpoints |
| SigNoz observability | ✅ Running | Custom `signoz.target`, ClickHouse + OTLP |
| DNS blocker | ✅ Running | Mullvad VPN-compatible, DoT forwarding |
| Sops + Age toolchain | ✅ Working | SSH host keys → age via `ssh-to-age` |
| BTRFS snapshots | ✅ Daily | btrbk, auto-pruning 14d+4w, pre-deploy snapshot |
| Taskchampion | ✅ Running | Port 10222 |
| Discordsync | ✅ Running | Enabled |
| Crush Daily | ✅ Running | Port 8081, SDK daemon integration |
| Overview | ✅ Running | Port 8083, SDK daemon consumer |
| PMA | ✅ Running | Re-enabled (session 137) |
| Hermes | ✅ Config-enabled | Blocked on 3 manual steps |
| Ollama | ✅ Running | Port 11434, GPU overhead reservation |
| Dozzle | ✅ Running | Port 8084 |
| OpenSEO | ✅ Running | Port 3002 |
| Dual WAN | ✅ Running | |
| Mullvad VPN | ✅ Running | DNS-over-TLS through VPN firewall |
| Monitor365 | ✅ Running | Port 3001 |

### Flake Hygiene — Majorly Improved This Session

| Item | Before | After |
|------|--------|-------|
| Lock nodes | 182 | **144** (-38) |
| Duplicate `go-error-family` | 7 copies | **1** |
| Duplicate `go-branded-id` | 7 copies | **1** |
| Duplicate `cmdguard` | 3 copies | **1** |
| Repos missing `go-branded-id.follows` | 5 | **0** |
| Repos missing `go-error-family.follows` | 5 | **0** |
| Repos missing `cmdguard.follows` | 2 | **0** |
| Repos missing `go-output.follows` | 1 (PMA) | **0** |
| go-auto-upgrade redundant vendorHash | Active | **Removed** |

### Patterns — Well Established

| Pattern | Status |
|-----------|--------|
| Port centralization (`lib/ports.nix`) | ✅ All ports registered, no conflicts |
| `mkPackageOverlay` for all flake-input overlays | ✅ Platform-safe |
| Caddy vHost consolidation (`caddy.nix`) | ✅ No module defines its own vhosts |
| Homepage tile consolidation (`homepage.nix`) | ✅ `when` guards for conditional tiles |
| `harden` / `hardenUser` / `serviceDefaults` | ✅ All services hardened |
| `onFailure` → `notify-failure@%n.service` | ✅ Centralized via `lib/default.nix` |
| Sops secret guards (`lib.optionalAttrs`) | ✅ All guarded |
| `startLimitBurst` on all services | ✅ Prevents crash loops |
| Service auto-discovery (flake-parts) | ✅ `_` prefix for non-module helpers |
| Docker services use `multi-user.target` | ✅ Correct target |
| SigNoz components use `signoz.target` | ✅ Doesn't block `graphical-session` |

### All 26 Go Repos — Build Status

| Repo | Evaluates | Overlay Pattern | Follows Status |
|------|-----------|-----------------|----------------|
| art-dupl | ✅ | `mkPackageOverlay {}` | Missing `go-nix-helpers`, `flake-parts`, `systems`, `treefmt-nix` |
| branching-flow | ✅ | `mkPackageOverlay {}` | ✅ All core deps followed. Missing `go-nix-helpers` |
| buildflow | ✅ | `mkPackageOverlay {}` | Missing `flake-parts`, `treefmt-nix`, `systems`, `go-nix-helpers` |
| cmdguard | ✅ | Root input (no overlay) | N/A (source library) |
| crush-daily | ✅ | `linux.nix` overlay | ✅ All core deps followed. Missing `go-nix-helpers` |
| discordsync | ✅ | NixOS module | ✅ All core deps followed. Missing `go-nix-helpers` |
| dnsblockd | ✅ | `linux.nix` overlay | Missing `systems`, `go-nix-helpers` |
| emeet-pixyd | ✅ | `linux.nix` overlay | Missing `flake-parts`, `treefmt-nix`, `systems`, `go-nix-helpers` |
| file-and-image-renamer | ✅ | `linux.nix` overlay | Missing `treefmt-nix`, `systems`, `go-nix-helpers` |
| go-auto-upgrade | ✅ | `mkPackageOverlay {}` | ✅ Clean (fixed session 138). Missing `flake-parts`, `treefmt-nix`, `systems`, `go-nix-helpers` |
| go-branded-id | ✅ | Root input (no overlay) | N/A (source library) |
| go-error-family | ✅ | Root input (no overlay) | N/A (source library) |
| go-finding | ✅ | Root input (no overlay) | N/A (source library) |
| go-filewatcher | ✅ | Root input (no overlay) | N/A (source library) |
| go-output | ✅ | Root input (no overlay) | N/A (source library) |
| go-structure-linter | ✅ | `mkPackageOverlay {}` | Missing `flake-parts`, `treefmt-nix`, `systems`, `go-nix-helpers` |
| gogenfilter | ✅ | Root input (no overlay) | N/A (source library) |
| golangci-lint-auto-configure | ✅ | `mkPackageOverlay {}` | Missing `flake-parts`, `treefmt-nix`, `systems`, `go-nix-helpers` |
| hierarchical-errors | ✅ | `mkPackageOverlay {}` | 🔴 `go-finding` NOT followed (API break). Missing `flake-parts`, `treefmt-nix`, `systems`, `go-nix-helpers` |
| library-policy | ✅ | `mkTidyOverride` | Missing `flake-parts`, `treefmt-nix`, `systems`, `go-nix-helpers` |
| monitor365 | ✅ | `linux.nix` overlay | Missing `flake-parts`, `treefmt-nix`, `systems` |
| mr-sync | ✅ | `mkTidyOverride` | ✅ All core deps followed. Missing `go-nix-helpers` |
| overview | ✅ | `linux.nix` overlay | ✅ All core deps followed. Missing `go-nix-helpers` |
| project-meta | ✅ | `mkPackageOverlay {}` | ✅ All core deps followed. Missing `go-nix-helpers` |
| projects-management-automation | ✅ | `mkPackageOverlay {}` | ✅ All core deps followed. Missing `go-nix-helpers` |
| todo-list-ai | ✅ | `mkPackageOverlay {}` | Missing `flake-parts`, `treefmt-nix`, `systems`, `go-nix-helpers` |

---

## b) PARTIALLY DONE 🟡

### Remaining Flake Lock Duplicates — 61 Nodes Still Duplicated

The session 138 consolidation eliminated all **core Go library** duplicates (`go-error-family`, `go-branded-id`, `cmdguard`, `go-output`). But 61 duplicate nodes remain from **infrastructure inputs** that most repos use but few follow:

| Duplicate Source | Copies | Root Input? | Fixable? |
|------------------|--------|-------------|----------|
| `go-nix-helpers` | 10 copies | ❌ NOT a root input | Add as root input, then follow |
| `flake-parts` | 10 copies | ✅ Yes | Add `flake-parts.follows` to 10 repos |
| `treefmt-nix` | 12 copies | ✅ Yes | Add `treefmt-nix.follows` to 12 repos |
| `systems` | 13 copies | ✅ Yes | Add `systems.follows` to 13 repos |
| `go-cqrs-lite` | 3 copies | ❌ NOT a root input | Add as root input, then follow |
| `project-discovery-sdk` | 4 copies | ❌ NOT a root input | Add as root input, then follow |
| `go-finding` | 2 copies (hierarchical-errors) | ✅ Yes | Fix API break or add follows |
| `go-structure-linter` | 2 copies | ✅ Yes (weird — root has `_2` variant) | Investigate |
| `git-hooks` | 2 copies | ❌ NOT a root input | Add as root input or accept |
| `go-composable-business-types` | 2 copies | ❌ NOT a root input | Add as root input or accept |
| `flake-compat` | 2 copies | ❌ NOT a root input | Transitive — hard to control |
| `pyproject-nix` | 2 copies | ❌ NOT a root input | Hermes-specific |
| `uv2nix` | 2 copies | ❌ NOT a root input | Hermes-specific |
| `gitignore` | 2 copies | ❌ NOT a root input | Transitive |
| `template-LICENSE` | 2 copies | ❌ NOT a root input | Transitive |

**Highest impact next batch:** Adding `flake-parts.follows`, `treefmt-nix.follows`, and `systems.follows` to the ~10 repos missing them would eliminate ~33 more duplicate nodes.

### Overlay VendorHash Workarounds — 2 Active

| Repo | Pattern | Problem |
|------|---------|---------|
| `library-policy` | `mkTidyOverride` (proxyVendor + go mod tidy + overrideModAttrs) | Upstream `go.sum` not committed |
| `mr-sync` | `mkTidyOverride` | Upstream `go.sum` not committed |

### Hermes — Enabled but Blocked on Manual Steps

| Step | Blocker |
|------|---------|
| OpenAI API key in sops | Manual secret entry needed |
| SSH deploy key install | Private key → `/home/hermes/.ssh/id_ed25519` + GitHub deploy key |
| Fallback model config | `sudo -u hermes hermes config set fallback_model openrouter/gpt-4o` |

### Twenty CRM — Running but Intermittent 502s

- Caddy logs show `connection refused` / `connection reset` on port 3200
- Likely container OOM or PG connection exhaustion
- Healthcheck at `twenty.nix:45` is container-internal port 3000 (correct — mapped to host 3200)

### Darwin (macOS) — Partially Configured

- Home Manager has minimal config (7 lines)
- No terminal, editor, or theme parity with NixOS
- `d2DarwinOverlay` still required for eval
- Disk constrained: 229GB, 90-95% full

---

## c) NOT STARTED ⬜

| Item | Priority | Blocked On |
|------|----------|------------|
| Add `flake-parts`/`treefmt-nix`/`systems` follows to 10+ repos | P1 | None — would eliminate ~33 more dup nodes |
| Add `go-nix-helpers` as root input + follow | P2 | None — would eliminate 10 dup nodes |
| BTRFS `/data` subvolume migration | P3 | None — `just snapshot-migrate-data` |
| `CHANGELOG.md` creation | P4 | None — 185+ commits |
| `ROADMAP.md` creation | P4 | None |
| Status report archiving (190 → ~30 active) | P4 | None |
| Auditd enablement | P6 | NixOS 26.05 bug #483085 |
| AppArmor enablement | P6 | Commented out |
| Pi 3 DNS failover provisioning | P6 | Hardware required |
| Darwin HM parity | P6 | Disk constrained |
| Monitor365 agent→server auth | P6 | No auth — anyone on LAN can POST |
| Disabled service triage | P6 | Decision needed |

---

## d) TOTALLY FUCKED UP 🔴

### 1. Swap Exhaustion — CRITICAL (Did NOT Fix with Reboot)

**19 GiB / 19 GiB swap used** even after a fresh reboot (system up only 1h 3m).

**Root causes identified from `/proc/*/status`:**

| Process | Swap (kB) | Description |
|---------|-----------|-------------|
| `rust-analyzer` | **2,597,468** (2.5 GB!) | Single rust-analyzer instance eating 2.5G swap |
| `next-server` | **2,278,536** (2.2 GB) | Next.js (likely Twenty CRM or Immich web) |
| `unbound` | **1,571,284** (1.5 GB!) | DNS resolver — absurdly high swap for DNS |
| `MainThread` | 413,908 | Helium/Electron main thread |
| `clickhouse-serv` | 294,148 | SigNoz ClickHouse |
| `gopls` × 6 | ~1,000,000 total | 6 LSP instances at 150-200k each |
| `immich` | 184,524 | Immich server |
| `workerd` | 154,860 | Twenty CRM worker |

**The `stale-lsp-cleanup` timer is NOT catching these** — 21 gopls processes are running simultaneously across 8+ terminals. The timer kills processes >24h, but these are being spawned faster than they expire.

### 2. Load Average — 14.60 / 21.43 / 26.26

Extremely high load for a 128GB RAM machine. Driven by:
- 21 gopls instances (each ~200-500MB RSS)
- 43 Helium (Electron) renderer processes
- 858 total processes
- Rust-analyzer consuming 2.6GB RSS + 2.5GB swap

### 3. `go-auto-upgrade` Upstream — Still Tech Debt

The repo's own `flake.nix` still uses:
- Manual `preparedSrc` derivation instead of `mkPreparedSource` from `go-nix-helpers`
- `vendorHash = ""` + `vendorHashTidied = "sha256-..."` dual-hash pattern
- `overrideModAttrs` with `go mod tidy` in both phases
- `doCheck = false` (tests broken since `go-finding.MustBuild` panic)
- Version stuck at `0.1.1` (tag only at `v0.1.0`)

### 4. `art-dupl` on `fork` Branch

`art-dupl` tracks `ref=fork` — a non-standard branch. Fragile and undocumented.

### 5. 44 Open TODO Items

Accumulated across 7 priority levels. Many carried for 10+ sessions.

---

## e) WHAT WE SHOULD IMPROVE

### Immediate Operational

1. **Kill stale gopls/rust-analyzer processes** — 21 gopls + 1 rust-analyzer eating ~5GB swap. The `stale-lsp-cleanup` timer threshold (24h) is too lenient. Consider lowering to 2-4h, or adding a max-instance count limit.

2. **Unbound swap usage** — 1.5GB swap for a DNS resolver is abnormal. Likely memory leak or oversized cache. Check `unbound.conf` cache settings.

3. **Run `nix-collect-garbage --delete-older-than 7d`** — 85G nix store, 50G free. Still tight.

### Flake Hygiene

4. **Next follows batch** — Add `flake-parts.follows`, `treefmt-nix.follows`, `systems.follows` to the ~10 repos missing them. Would eliminate ~33 more duplicate nodes (144→~111).

5. **Add `go-nix-helpers` as root input** — 10 duplicate copies exist. Add as root, then follow from all consumers.

6. **`go-structure-linter_2` anomaly** — Root references `go-structure-linter_2` instead of `go-structure-linter`. This is unusual and needs investigation — the lock structure suggests the root input itself is somehow creating a suffixed node.

### Architecture

7. **VendorHash/workaround sprawl** — 2 repos still need `mkTidyOverride`. Root cause is upstream repos not committing correct `go.sum`.

8. **189 status reports** — No archiving discipline.

9. **Missing CHANGELOG.md** — 185+ commits, no structured changelog.

10. **Large modules** — `monitor365.nix` (716L), `signoz.nix` (705L), `forgejo.nix` (583L).

11. **Helium Electron bloat** — 43 renderer processes. Consider alternatives or memory limits.

---

## f) Top 25 Things to Get Done Next

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **Kill stale gopls/rust-analyzer processes** | Reclaim ~5GB swap immediately | 1min | 🔴 Critical |
| 2 | **Lower `stale-lsp-cleanup` timer threshold** from 24h to 4h | Prevent LSP swap accumulation | 5min | 🔴 Critical |
| 3 | **Investigate unbound 1.5GB swap** — check cache config | Fix abnormal DNS memory | 15min | 🔴 Critical |
| 4 | **Run `nix-collect-garbage --delete-older-than 7d`** | Reclaim 10-20G disk | 5min | 🔴 Critical |
| 5 | **Add `flake-parts.follows` + `treefmt-nix.follows` + `systems.follows`** to ~10 repos | Eliminate ~33 more duplicate lock nodes | 15min | 🟡 High |
| 6 | **Add `go-nix-helpers` as root input** + follow from 10 consumers | Eliminate 10 more dup nodes | 10min | 🟡 High |
| 7 | **Investigate `go-structure-linter_2` anomaly** in root inputs | Fix weird lock structure | 10min | 🟡 High |
| 8 | **Commit correct `go.sum` upstream** for `library-policy` and `mr-sync` → remove `mkTidyOverride` | Eliminate 2 build hacks | 30min | 🟡 High |
| 9 | **Fix `go-auto-upgrade` upstream** — migrate to `mkPreparedSource`, fix tests, tag v0.2.0 | Eliminate 3 layers of tech debt | 2h | 🟡 High |
| 10 | **Investigate Twenty CRM 502s** — `docker logs twenty-server-1` | Fix intermittent outages | 30min | 🟡 High |
| 11 | **Audit Gatus DOWN services** — fix wrong check URLs | Restore monitoring accuracy | 30min | 🟡 High |
| 12 | **Fix `hierarchical-errors` go-finding API break** — update Confidence type usage | Eliminate last unfollowed go-finding | 1h | 🟡 High |
| 13 | **Hermes: add OpenAI API key to sops** | Unblock Hermes AI features | 5min | 🟡 Blocked |
| 14 | **Hermes: install SSH deploy key** | Enable GitHub deploy access | 10min | 🟡 Blocked |
| 15 | **Verify boot time** — system was rebooted, check journal for timing | Validate NVMe APST fix | 5min | 🟡 Verify |
| 16 | **BTRFS `/data` migration** — `just snapshot-migrate-data` | Enable snapshots for Docker/Immich/AI data | 15min | 🟢 Medium |
| 17 | **Create CHANGELOG.md** — structure 185+ commits | Release note capability | 1h | 🟢 Medium |
| 18 | **Archive pre-session-100 status reports** — move 160 files to `docs/status/archive/` | Reduce noise | 30min | 🟢 Medium |
| 19 | **Create ROADMAP.md** — consolidate `docs/planning/` | Strategic direction doc | 1h | 🟢 Medium |
| 20 | **Triage disabled services** — voice-agents, minecraft, photomap: enable or remove | Reduce dead config weight | 30min | 🟢 Medium |
| 21 | **Add Helium memory limits** — `MemoryMax` in systemd or Electron `--max-old-space-size` | Reduce 43 renderer bloat | 30min | 🟢 Medium |
| 22 | **Split large modules** — `monitor365.nix` (716L), `signoz.nix` (705L) | Maintainability | 2h | 🔵 Low |
| 23 | **Pin or document `art-dupl` `fork` branch** | Prevent silent breakage | 15min | 🔵 Low |
| 24 | **Monitor365: add LAN auth** — token-based auth for agent→server | Security | 1h | 🔵 Low |
| 25 | **nixpkgs/Home Manager upstream PRs** — poetry-core, test fixes, flags, manifests | Reduce custom overlay maintenance | 4h | 🔵 Low |

---

## g) Top Question I Cannot Answer

### Why does `go-structure-linter_2` exist as a root-level duplicate?

Every other root input creates a clean lock node — `root.inputs.go-structure-linter` should point to `"go-structure-linter"`, not `"go-structure-linter_2"`. But the lock shows:

```
root.inputs.go-structure-linter = "go-structure-linter_2"
```

This means there are TWO `go-structure-linter` nodes in the lock — the `_2` variant (what root points to) and potentially a plain one (pointed to by something else). This is the only root input with a suffixed lock node.

**Possible causes:**
1. A circular or diamond dependency where `go-structure-linter` is both a root input AND consumed by another repo (e.g., PMA → `go-structure-linter`)
2. A stale lock entry from an old flake structure that `nix flake lock` didn't clean up
3. A naming collision with a transitive dependency

**I cannot determine the cause without `nix flake lock --recreate-lock-file` (destructive) or tracing every reference to `go-structure-linter` across all lock sub-nodes.** A `nix flake lock --update-input go-structure-linter` might fix it, or might not if the cause is a diamond dependency.

**Recommended action:** Run `rg 'go-structure-linter' flake.lock` to trace all references, then decide if a full re-lock is needed.

---

## Lock Node Deduplication Progress

| Metric | Session 138 Start | Session 138 End | Session 139 Now | Remaining Potential |
|--------|-------------------|-----------------|-----------------|---------------------|
| Total lock nodes | 182 | 144 | 144 | ~111 (if all remaining follows added) |
| `go-error-family` copies | 7 | 1 | 1 | ✅ Done |
| `go-branded-id` copies | 7 | 1 | 1 | ✅ Done |
| `cmdguard` copies | 3 | 1 | 1 | ✅ Done |
| `go-output` copies | 2 | 1 | 1 | ✅ Done |
| `flake-parts` copies | 14 | 14 | 10 | Fixable: add follows to 10 repos |
| `treefmt-nix` copies | 17 | 17 | 12 | Fixable: add follows to 12 repos |
| `systems` copies | 19 | 19 | 13 | Fixable: add follows to 13 repos |
| `go-nix-helpers` copies | 10 | 10 | 10 | Fixable: add as root input + follow |

---

## Service Inventory

| Service | Enabled | Port | Status |
|---------|---------|------|--------|
| Caddy | ✅ | 80/443/2019 | Running |
| Forgejo | ✅ | 3000 | Running |
| Immich | ✅ | 2283 | Running |
| Pocket ID | ✅ | 1411 | Running |
| OAuth2-proxy | ✅ | 4180 | Running |
| Homepage | ✅ | 8082 | Running |
| SigNoz | ✅ | 8080 | Running |
| Gatus | ✅ | 9110 | Config wired |
| DNS blocker | ✅ | 53/9090/8050 | Running |
| Sops | ✅ | — | Working |
| Taskchampion | ✅ | 10222 | Running |
| Niri desktop | ✅ | — | Running |
| Security hardening | ✅ | — | Active (AppArmor off) |
| Discordsync | ✅ | — | Running |
| OpenSEO | ✅ | 3002 | Running |
| Dual WAN | ✅ | — | Running |
| Mullvad VPN | ✅ | — | Running |
| AI stack | ✅ | 11434 | Running |
| Hermes | ✅ | — | **Blocked on manual steps** |
| Crush Daily | ✅ | 8081 | Running |
| Overview | ✅ | 8083 | Running |
| PMA | ✅ | — | Running |
| Dozzle | ✅ | 8084 | Running |
| Monitor365 | ✅ | 3001 | Running |
| Voice agents | ❌ | 7860/7880 | Disabled |
| Minecraft | ❌ | 25565 | Disabled |
| Photomap | ❌ | 8051 | Commented out |

---

## Disk Usage Breakdown

| Path | Size | Notes |
|------|------|-------|
| `/data/models` | 370G | AI/LLM models |
| `/data/llamacpp-models` | 207G | llama.cpp models |
| `/data/ai` | 165G | AI workload data |
| `/data/SteamLibrary` | 107G | Steam games |
| `/nix/store` | 85G | Nix store |
| Root partition used | 442G / 512G (91%) | 50G free |
| `/data` partition used | 787G / 1.0T (77%) | 237G free |

---

_Auto-generated by Session 139 comprehensive audit._
