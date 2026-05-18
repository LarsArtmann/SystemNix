# Session 52 — Comprehensive Status Report

**Date:** 2026-05-19 01:32 (CEST)
**Branch:** master
**Last commit:** `9bbcdb85 chore(flake.lock): update lockfile with upstream revisions`

---

## A) FULLY DONE ✅

### 1. Gitea → Forgejo Migration: Phase 1 (Code Migration)

All code references renamed from `gitea` → `forgejo` across 15 files. Build passes.

**Files changed:**
| File | Change |
|------|--------|
| `modules/nixos/services/gitea.nix` → `forgejo.nix` | Renamed + `$GITHUB_TOKEN` escaping fix |
| `modules/nixos/services/gitea-repos.nix` → `forgejo-repos.nix` | Renamed + `$GITHUB_TOKEN` escaping fix |
| `flake.nix` | serviceModules gitea → forgejo, art-dupl gogenfilter follows |
| `platforms/nixos/system/configuration.nix` | `gitea.enable` → `forgejo.enable`, `gitea-repos` → `forgejo-repos` |
| `modules/nixos/services/caddy.nix` | `config.services.gitea` → `config.services.forgejo` |
| `modules/nixos/services/authelia.nix` | OIDC client name "Gitea" → "Forgejo" |
| `modules/nixos/services/homepage.nix` | Dashboard entry + icon + description |
| `modules/nixos/services/gatus-config.nix` | Health check name + port reference |
| `modules/nixos/services/signoz.nix` | Journald unit `gitea.service` → `forgejo.service` |
| `modules/nixos/services/sops.nix` | Secret/template names, restartUnits, `gitea_token` → `forgejo_token` |
| `justfile` | `gitea-sync-repos` → `forgejo-sync-repos`, `gitea-update-token` → `forgejo-update-token` |
| `AGENTS.md` | All documentation references updated |
| `FEATURES.md` | Feature table updated |
| `docs/migration-gitea-to-forgejo.md` | Status updated to Phase 1 COMPLETE |

**Status:** All code is staged and ready. NOT YET COMMITTED. NOT YET DEPLOYED.

### 2. go-structure-linter Upstream Fix (testhelpers sub-module)

**Root cause:** `go-output/table` imports `go-output/testhelpers` transitively. The `_local_deps` pattern had a replace directive for `testhelpers` but no `require` line in `go.mod`, causing `go build` to see inconsistent vendoring.

**Commits pushed upstream (`go-structure-linter`):**
1. `9ab978e` — Add `testhelpers` to `subModules` list
2. `9f378da` — Add `overrideModAttrs` with `go mod tidy`
3. `6d17332` — Add `testhelpers v0.0.0` to `requireDeps` + remove broken `preBuild`
4. `f4986d1` — Restore correct `vendorHash`

**Verified:** `nix build .#go-structure-linter` succeeds, binary runs correctly.

### 3. Flake Lock Updates

- `go-structure-linter` updated to `f4986d1` (testhelpers fix)
- `art-dupl` now follows top-level `gogenfilter` (dedup — removed 1 lock node)

### 4. Historical (Sessions 46–51)

- **Nix eval memory optimization** — 10-16 GB saved (crush-config, treefmt follows, aarch64-linux removal)
- **Lockfile dedup phase 2** — 123 → 93 nodes (24.4% reduction)
- **NVMe SSD SMART monitoring** — desktop notifications, SigNoz metrics, Gatus alerts
- **Nix GC daily + 3-day retention** — prevents disk exhaustion on both platforms
- **Darwin GC daily** — MacBook disk constantly at 90-95%

---

## B) PARTIALLY DONE 🔧

### 1. Gitea → Forgejo Migration: Phase 2 (Data Migration) — NOT STARTED

Phase 1 code is ready but:
- [ ] Sops secrets file still has `gitea_token` (needs `forgejo_token` key added — Forgejo generates its own API tokens)
- [ ] Data migration: `systemctl stop gitea`, `mv /var/lib/gitea /var/lib/forgejo`, `chown`, `just switch`
- [ ] Verification: token gen, Actions runner, Caddy proxy, GitHub mirrors, push mirrors
- [ ] Estimated downtime: 30 min

### 2. Flake Lock Deduplication — Remaining Duplicates

24.4% reduced but **23 duplicated nodes remain** from private Go repo transitive deps:
- `cmdguard`, `go-branded-id`, `go-finding`, `go-output`, `go-filewatcher`, `gogenfilter` appear as `flake: false` inputs in multiple repos
- Requires upstream repos to accept shared library inputs as overridable
- Third-party duplicates: `hermes-agent` (pyproject-nix ×2, uv2nix), `nix-colors` nixpkgs-lib

### 3. DNS Failover Cluster — Planned, Hardware Not Provisioned

- Code complete: `modules/nixos/services/dns-failover.nix`
- VRRP password in sops
- **Blocker:** Raspberry Pi 3 hardware not provisioned, needs sops + age identity setup

---

## C) NOT STARTED 📋

1. **Forgejo push mirrors** — Bi-directional sync (Forgejo → GitHub push mirrors for owned repos)
2. **Forgejo Actions runner** — Switch from `gitea-actions-runner` to `forgejo-runner` package if available
3. **DNS subdomain rename** — `gitea.home.lan` → `git.home.lan` (low priority, works as-is)
4. **Photomap** — Disabled due to podman config permission issue
5. **Twenty CRM** — Needs integration testing after Forgejo migration
6. **ComfyUI** — Removed from config (session 38), was causing GPU hangs
7. **Distributed Darwin builds** — Build on evo-x2 for MacBook to save disk
8. **Private Go repo transitive dep dedup** — 23 lock nodes, requires upstream coordination
9. **Hermes-agent pyproject-nix dedup** — Third-party controlled
10. **OpenZFS on macOS** — Documented as impossible (kernel panics, ADR-003)

---

## D) TOTALLY FUCKED UP 💥

### 1. Sops Secret Name Mismatch (CRITICAL for deployment)

The code references `forgejo_token` in `sops.nix`:
```nix
["forgejo_token" "github_token" "github_user"]
```

But the actual sops-encrypted file (`platforms/nixos/secrets/secrets.yaml`) still has:
```yaml
gitea_token: ENC[AES256_GCM,...]
```

**Impact:** `just switch` will fail — sops can't find `forgejo_token`.

**Fix needed BEFORE deploying:**
- Either rename `gitea_token` → `forgejo_token` in `secrets.yaml` (sops edit)
- Or add a new `forgejo_token` key (Forgejo will generate its own token anyway)

### 2. Darwin Disk Situation (CHRONIC)

MacBook Air 229 GB disk, regularly at 90-95%. Nix GC hangs. Build failures with `errno=28` are disk-related, not code bugs. Daily GC helps but is a band-aid.

### 3. awww-daemon BrokenPipe (UPSTREAM BUG)

awww 0.12.0 panics on BrokenPipe at `daemon/src/main.rs:712:32`. `Restart=always` covers it but the daemon crashes ~15 times during niri crash cascades. Upstream not fixed.

---

## E) WHAT WE SHOULD IMPROVE 🎯

### Process

1. **Test sops secret names BEFORE committing code changes** — The forgejo_token mismatch would have been caught by a simple `grep` of the secrets file
2. **Reduce status report spam** — 75+ status files in `docs/status/`. Many are near-duplicates. Archive aggressively.
3. **Commit more granularly** — 15-file uncommitted diff mixing Forgejo migration + flake updates + docs. Separate concerns.
4. **Use `just test-fast` before declaring "done"** — The forgejo build passes but the sops secret name will break at deploy time

### Architecture

5. **Centralize Go dep management** — 23 duplicated lock nodes from `flake: false` transitive deps. Create a shared `go-deps` flake input that all repos reference.
6. **Sops secret naming convention** — Adopt `service_name` pattern (e.g., `forgejo_token` not `gitea_token`). Document the rename process in AGENTS.md.
7. **Automated sops validation** — Add a CI check or pre-commit hook that verifies all referenced sops keys exist in the encrypted files.
8. **Disk monitoring alerting** — Darwin disk at 95% needs a Gatus endpoint or at minimum a launchd alert.

### Code Quality

9. **`harden` / `hardenUser` adoption at 100%** — Verify all systemd services use shared helpers (3 user-service modules confirmed, audit remaining)
10. **Service module consistency** — All service modules should follow the same pattern: options, config, tmpfiles, harden, serviceDefaults

---

## F) Top 25 Things to Get Done Next

### Priority 1 — Immediate (blocks deployment)

| # | Task | Est. | Impact |
|---|------|------|--------|
| 1 | **Fix sops secret: rename `gitea_token` → `forgejo_token` in `secrets.yaml`** | 5 min | Blocks Forgejo deploy |
| 2 | **Deploy Forgejo (Phase 2)** — stop gitea, migrate data, `just switch`, verify | 30 min | Governance freedom |
| 3 | **Verify Forgejo post-deploy** — tokens, Actions runner, Caddy, mirrors | 15 min | Confidence in migration |
| 4 | **Commit the current uncommitted changes** | 5 min | Clean working tree |

### Priority 2 — This Week

| # | Task | Est. | Impact |
|---|------|------|--------|
| 5 | **Set up Forgejo push mirrors** (Forgejo → GitHub for owned repos) | 1 hr | Bi-directional sync |
| 6 | **Archive old status docs** — move 70+ files to `archive/` | 10 min | Clean repo |
| 7 | **Add sops key validation** — pre-commit hook or CI check | 30 min | Prevent secret mismatch |
| 8 | **Test full `just switch` on NixOS** — end-to-end validation | 20 min | Confidence in system state |
| 9 | **Update forgejo.nix** — add federation config (activitypub_enabled) if not already | 15 min | Future-proof |
| 10 | **Darwin disk cleanup** — caches, old generations | 15 min | Prevent build failures |

### Priority 3 — This Month

| # | Task | Est. | Impact |
|---|------|------|--------|
| 11 | **DNS failover: provision Pi 3** — flash SD, sops + age setup | 2 hr | HA DNS |
| 12 | **Private Go repo dedup** — coordinate `go-output`, `go-branded-id` etc. as shared top-level inputs | 3 hr | 23 fewer lock nodes |
| 13 | **Photomap fix** — resolve podman config permission issue | 1 hr | Photo exploration |
| 14 | **Distributed Darwin builds** — offload to evo-x2 | 2 hr | MacBook disk relief |
| 15 | **Twenty CRM integration testing** | 1 hr | CRM functionality |
| 16 | **Automated disk alerting for Darwin** — launchd or Gatus remote check | 30 min | Proactive disk management |

### Priority 4 — Backlog

| # | Task | Est. | Impact |
|---|------|------|--------|
| 17 | **DNS subdomain rename** — `gitea.home.lan` → `git.home.lan` | 30 min | Naming clarity |
| 18 | **Hermes-agent pyproject-nix dedup** — upstream coordination | 1 hr | Lock cleanliness |
| 19 | **ComfyUI GPU sandbox** — if re-enabling, needs memory isolation | 2 hr | AI image gen |
| 20 | **awww upstream fix or fork** — BrokenPipe panic | 3 hr | Wallpaper stability |
| 21 | **Service module audit** — verify 100% harden/serviceDefaults adoption | 1 hr | Consistency |
| 22 | **Flake check CI** — GitHub Actions or local pre-push hook | 2 hr | Quality gate |
| 23 | **Valkey/Redis cleanup** — verify no orphan services | 30 min | Reduce attack surface |
| 24 | **Backup automation** — automated off-site backups for critical data | 3 hr | Disaster recovery |
| 25 | **Documentation audit** — verify AGENTS.md matches reality after all recent changes | 1 hr | Accuracy |

---

## G) Top #1 Question I Cannot Answer Myself

**The Forgejo sops secret migration strategy:**

The current `secrets.yaml` has `gitea_token` encrypted. The code now references `forgejo_token`. Two options:

1. **Rename in-place:** `sops --set 'forgejo_token "same-value"' platforms/nixos/secrets/secrets.yaml` then remove old key — preserves the existing token value
2. **Fresh token:** Let Forgejo generate a new API token during first-start, then `sops --set` it — cleaner but requires manual step

Which approach do you prefer? Option 1 is simpler (just rename). Option 2 is cleaner (Forgejo generates its own token matching its own ACL model). Either way, this must happen BEFORE `just switch`.

---

## Working Tree Summary

```
15 files changed, 46 insertions(+), 60 deletions(-)

Staged:
  R gitea.nix → forgejo.nix
  R gitea-repos.nix → forgejo-repos.nix

Unstaged:
  M AGENTS.md
  M FEATURES.md
  M docs/migration-gitea-to-forgejo.md
  M flake.lock          (go-structure-linter update, art-dupl dedup)
  M flake.nix            (forgejo serviceModules, art-dupl gogenfilter follows)
  M justfile             (gitea → forgejo recipes)
  M modules/nixos/services/authelia.nix
  M modules/nixos/services/caddy.nix
  M modules/nixos/services/forgejo.nix
  M modules/nixos/services/forgejo-repos.nix
  M modules/nixos/services/gatus-config.nix
  M modules/nixos/services/homepage.nix
  M modules/nixos/services/signoz.nix
  M modules/nixos/services/sops.nix
  M platforms/nixos/system/configuration.nix
```
