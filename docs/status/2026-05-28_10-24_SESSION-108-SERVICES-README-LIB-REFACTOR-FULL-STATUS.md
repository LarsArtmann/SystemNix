# Session 108: Services README, `mkSecretCheck`, `mkDesktopNotifyService`, Docker Import Standardization

**Date:** 2026-05-28 10:24 CEST | **Status:** COMPLETE | **Platform:** evo-x2 (NixOS 26.11)

---

## A) FULLY DONE ✅

### 1. Created `modules/nixos/services/README.md`

Comprehensive documentation for the flake-parts NixOS service module conventions:

- **Auto-discovery rules** — filename must match `flake.nixosModules.<name>`
- **Anatomy** — skeleton module with `cfg`, `lib` import, `lib.mkIf` guard
- **7-step checklist** for adding new services
- **Module naming** — when to use `services.<name>` vs `services.<name>-config`
- **Inputs** — when to use `{ inputs, ... }` vs `_:`
- **Secrets patterns** — central registry vs inline, env templates, pre-start validation
- **Timer patterns** — standard systemd timer for periodic tasks
- **Custom user creation** — `primaryUser` default, `systemdServiceIdentity`
- **Desktop notification services** — DISPLAY/WAYLAND/XDG_RUNTIME_DIR setup
- **Home Manager integration** — `serviceDefaultsUser {}` vs `serviceDefaults {}`
- **3 code examples** — native NixOS service, Docker service, auth-protected service
- **11 common gotchas** including WatchdogSec, handle_path vs handle, Docker import pattern, image digests

**Commits:** `4cb76e4c` (README created), `fb94b376` (conventions added), `56830c64` (new helpers documented)

### 2. Added `mkSecretCheck` helper to `lib/default.nix`

Abstracts the repeated `writeShellApplication` boilerplate for pre-start secret validation:

```nix
mkSecretCheck pkgs {
  name = "pocket-id-encryption-key";
  secretPath = config.sops.secrets.pocket_id_encryption_key.path;
  message = "pocket-id: ENCRYPTION_KEY is missing...";
  extraCheck = "...";  # optional custom validation
}
```

**Refactored 3 modules** to use it:
- `pocket-id.nix` — encryption key check (with `just auth-bootstrap` hint)
- `oauth2-proxy.nix` — cookie secret check (with base64 length validation via `extraCheck`)
- `gatus-config.nix` — env template check

**Commit:** `e0cdb26f`

### 3. Added `mkDesktopNotifyService` helper to `lib/default.nix`

Abstracts the duplicated desktop-notification timer+service pattern:

```nix
mkDesktopNotifyService pkgs {
  name = "disk-monitor";
  description = "Check disk usage and notify";
  checkScript = "...";
  runtimeInputs = [...];
  user = cfg.user;
  uid = uid;
  interval = cfg.interval;
  hardenFn = harden;  # or hardenUser for HM services
}
```

Generates both `timer` and `service` attrs. Handles:
- `Type = "oneshot"`
- DISPLAY/WAYLAND_DISPLAY/XDG_RUNTIME_DIR env
- `harden`/`hardenUser` integration (configurable via `hardenFn`)
- `onFailure` notification
- `Persistent = true` timer

**Refactored 2 modules** to use it:
- `disk-monitor.nix` — BTRFS disk usage notifications with threshold tracking
- `nvme-health-monitor.nix` — NVMe SSD health notifications (uses `hardenUser`)

**Commit:** `cb05f17a`

### 4. Standardized Docker import pattern in 2 modules

Fixed inconsistent `mkDockerService` imports:
- `openseo.nix` — was using ad-hoc double-import of `lib/default.nix`; now uses `libHelpers.mkDockerServiceFactory`
- `voice-agents.nix` — was importing `lib/docker.nix` directly; now uses `libHelpers.mkDockerServiceFactory`

**Commit:** `c1f1bb5f`

### 5. Validation

- `just test-fast` — ✅ all checks passed (x86_64-linux)
- `nix flake check --no-build` — ✅ all outputs evaluate correctly
- deadnix — ✅ zero dead code
- statix — ✅ zero antipatterns
- alejandra — ✅ properly formatted
- gitleaks — ✅ no secrets found
- All 35 nixosModules discovered and validated

---

## B) PARTIALLY DONE ⚠️

### 1. `TODO_LIST.md` is stale (last updated 2026-05-21, session 75)

Many items are now completed but not marked:
- ✅ writeShellScript → writeShellApplication migration (session 103)
- ✅ mkPackageOverlay platform safety (session 107)
- ✅ mkPreparedSource auto-features (session 107)
- ✅ Gatus health checks for all services (session 104)
- ✅ Centralize Docker image tags (session 104)
- ✅ Standardize lib.getExe (session 105)
- ✅ Add NixOS VM test for ExecStart paths (session 105)
- ✅ GitHub Actions CI (already existed)
- ✅ Authelia → Pocket ID migration (session 85)
- ✅ BTRFS snapshots overhaul (session 84)
- ⚠️ Hermes extra deps (firecrawl, edge-tts, fal, exa) — added, partially deployed
- ⚠️ Secondary LLM provider for Hermes — not started
- ⚠️ Deploy committed changes — many sessions' changes not yet deployed

### 2. Consumer repo changes not committed/pushed

From session 107, 5 repos still have uncommitted flake.lock/vendorHash changes:
- BuildFlow, Standup-Killer, library-policy, PMA, mr-sync
- Standup-Killer has pre-existing Go type errors (blocks build regardless)
- branching-flow has private repo HTTPS auth issue

### 3. `nix flake check --all-systems` — Darwin eval partially broken

The `--all-systems` flag fails on Darwin because some packages are Linux-only:
- Expected behavior (packages declare `meta.badPlatforms`)
- Not a new issue — Darwin overlay stubs handle most of this
- The `--no-build` flag skips incompatible systems; `--all-systems` attempts them

### 4. 3 Services explicitly disabled in configuration.nix

| Service | Line | Reason |
|---------|------|--------|
| `voice-agents` | 194 | `enable = false` — likely resource concern or not needed |
| `file-and-image-renamer` | 164–166 | Go 1.26.3 required, nixpkgs-unstable has 1.26.2 |
| `minecraft` | 204 | `enable = false` — server not needed currently |

### 5. `photomap` — commented out with podman permission issue

Line 125: `# photomap.enable = true;` — podman config permission issue

---

## C) NOT STARTED ⏳

### From TODO_LIST.md (still outstanding)

1. **Configure secondary LLM provider for Hermes** — OpenRouter/OpenAI as GLM-5.1 fallback
2. **Hermes git remote access** — SSH deploy key for sandbox
3. **Monitor GLM-5.1 rate limit** — verify cron jobs recovered after reset
4. **Deploy committed changes** — sessions 101–108 have changes not deployed
5. **Verify boot time** — expect ~35s with all optimizations
6. **Verify hermes new Python deps** — no ImportError in journal
7. **Check SigNoz provision logs** — channel + rule creation, 4 dashboards
8. **Test Discord alert channel** — `POST /api/v1/channels/test`
9. **Verify Gatus endpoints** — `status.home.lan` healthy, webhook loaded, TLS check active
10. **Add per-threshold SigNoz channel routing** — critical→Discord, warning→log
11. **Consolidate voice-agents Caddy vHost** into caddy.nix pattern
12. **nix-colors integration** — wire to Home Manager, migrate 17+ hardcoded colors
13. **Deploy Dozzle** — Docker container log tailing at `logs.home.lan`
14. **Create `just status` command** — automated status report generation
15. **Provision Pi 3** for DNS failover cluster
16. **Wire Pi 3 as secondary DNS** in dns-failover.nix
17. **Investigate swap exhaustion** — 13Gi/13Gi historically, 7 gopls instances
18. **Flake inputs audit** — 85 inputs, some may be stale/unused
19. **Add memory/swap alerting** to SigNoz/Gatus
20. **Convert go-auto-upgrade `path:` inputs to SSH URLs**
21. **Create shared flake-parts template** (mkGoPackage, checks, devShells)
22. **Convert `/data` BTRFS from toplevel to `@data` subvolume** — enables snapshots
23. **Strip shebangs from external `.sh` files** used with `writeShellApplication`
24. **Consolidate overlays/shared.nix and overlays/linux.nix** — mkPackageOverlay is now platform-safe
25. **Textfile collectors directory ownership** — `nobody:nogroup 1777` → dedicated user

### New from this session

26. **Update `TODO_LIST.md`** — mark completed items, add new ones from sessions 101–108
27. **Add ADR for `mkSecretCheck`/`mkDesktopNotifyService`** — document design decisions

---

## D) TOTALLY FUCKED UP 💥

### 1. Darwin eval breaks with `--all-systems`

`nix flake check --all-systems` fails because Linux-only packages (e.g., otel-tui, netwatch, openaudible) declare `meta.badPlatforms` for Darwin. The `--no-build` flag skips them; `--all-systems` does not.

**Impact:** Low — CI should use `--no-build`, not `--all-systems`. The Darwin configuration itself evaluates fine.

### 2. `/data` disk at ~92% (933G/1.0T)

Only 91G free. AI models and Docker images are main consumers. Trending upward. No automated cleanup for old Docker images or model caches.

### 3. Swap historically at ~63% (12Gi/19Gi)

From session 75 TODO. systemd-oomd is now active (session 92), but memory pressure remains a concern. No alerting configured for swap exhaustion.

### 4. 85 flake.lock inputs

From `nix flake metadata`. Many may be stale or unused. `flake.lock` is 3,500+ lines. No automated input pruning.

### 5. `file-and-image-renamer` blocked on Go version mismatch

`charm.land/fantasy@v0.25.0` requires Go 1.26.3, but nixpkgs-unstable has 1.26.2. This is an upstream nixpkgs issue, not fixable in SystemNix directly.

### 6. `photomap` — podman permission issue

Blocked on podman configuration. Not investigated in detail.

### 7. Session 101 ExecStart bugs were latent runtime bombs

Fixed in session 103, but this class of bug (directory vs file in ExecStart) could recur. The `just test-exec-paths` check catches it, but it's not run automatically in CI.

---

## E) WHAT WE SHOULD IMPROVE 🔧

### Process Improvements

1. **Auto-run `just test-exec-paths` in CI** — The ExecStart path validation test catches directory-vs-file bugs. It should run on every PR.
2. **Keep `TODO_LIST.md` current** — It's 7 days stale. Mark done items, add new ones after each session.
3. **Commit per logical change** — Session 108 combined README + mkSecretCheck + mkDesktopNotifyService + Docker fixes into 5 commits. Good separation.
4. **Pre-commit auto-formatting** — The commit hooks already run alejandra, but we had to manually run it once because the first edit introduced formatting issues. Consider `nix fmt` before commit.
5. **Document new helpers in AGENTS.md** — `mkSecretCheck` and `mkDesktopNotifyService` should be added to the lib/ helpers table.

### Architecture Improvements

6. **Type models for secrets** — `mkSecretCheck` validates at runtime (ExecStartPre). Nix-level type assertions would be better (e.g., `cookie_secret` must be 16/24/32 bytes). Could add to `serviceTypes`.
7. **Consolidate overlay files** — With platform-safe `mkPackageOverlay`, reconsider `shared.nix` vs `linux.nix` split. Manual overlays still need guards.
8. **Abstract `writeShellApplication` + `builtins.readFile` pattern** — External `.sh` files with redundant shebangs. Could create `mkExternalScript` that strips the shebang.
9. **Add `mkPeriodicTask` helper** — Generalize the timer+oneshot pattern beyond desktop notifications (e.g., for backups, syncs, health checks).
10. **Auto-generate service module skeleton** — A `just new-service <name>` command that creates the boilerplate from the README template.

### Ecosystem Quality

11. **Commit & push 5 consumer repos** — Session 107 changes are still uncommitted.
12. **Fix Standup-Killer Go type errors** — 7 type errors in `domain/cqrs/`.
13. **Fix branching-flow private repo HTTPS auth** — `GOPRIVATE` or SSH rewrite rules.
14. **Input audit** — Review 85 flake inputs, remove unused ones.
15. **Feature inventory** — Create `FEATURES.md` with honest status indicators.

---

## F) TOP 25 THINGS TO DO NEXT 🎯

### P0 — Immediate (<30 min)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Deploy all committed changes** — `just switch` (sessions 101–108) | Ship everything | 10 min |
| 2 | **Update `TODO_LIST.md`** — mark done items, add new ones | Planning accuracy | 15 min |
| 3 | **Commit & push 5 consumer repos** (BuildFlow, Standup-Killer, library-policy, PMA, mr-sync) | Prevents data loss | 15 min |
| 4 | **Add `mkSecretCheck` and `mkDesktopNotifyService` to AGENTS.md** | Documentation accuracy | 5 min |
| 5 | **Run `just test` (full build)** — not just `test-fast` | Confidence | 30 min |

### P1 — This Week (<2 hr)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 6 | **Fix Standup-Killer Go type errors** — `event.Version` cast | Unblocks build | 30 min |
| 7 | **Create `FEATURES.md`** — feature inventory with status indicators | Project visibility | 1 hr |
| 8 | **Add `just test-exec-paths` to CI** — catch ExecStart directory bugs | Quality gate | 30 min |
| 9 | **Input audit** — review 85 flake inputs, remove unused | Build speed | 1 hr |
| 10 | **Strip shebangs from external `.sh` files** used with `writeShellApplication` | Cleaner scripts | 30 min |
| 11 | **Configure secondary LLM provider for Hermes** | Reliability | 1 hr |
| 12 | **Verify all deployed services healthy** — Gatus, SigNoz, journald | Operational confidence | 30 min |

### P2 — Architecture (this sprint)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 13 | **Convert `/data` BTRFS to `@data` subvolume** | Enables snapshots | 30 min |
| 14 | **Consolidate overlays: move Linux-only mkPackageOverlay calls to shared.nix** | Simpler structure | 1 hr |
| 15 | **Add `mkPeriodicTask` helper** — timer+oneshot for backups, syncs | DRY | 1 hr |
| 16 | **Type models for secrets** — Nix-level assertions for cookie_secret, etc. | Safety | 1 hr |
| 17 | **nix-colors integration** — migrate 17+ hardcoded colors | Maintainability | 2 hr |
| 18 | **Textfile collectors: dedicated user** instead of 1777 | Security | 30 min |
| 19 | **Add memory/swap alerting** to SigNoz/Gatus | Early warning | 1 hr |
| 20 | **Create `just new-service <name>` command** — auto-generate boilerplate | DX | 1 hr |

### P3 — Ecosystem / Nice to Have

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 21 | **Deploy Dozzle** — Docker log tailing at `logs.home.lan` | Observability | 2 hr |
| 22 | **Provision Pi 3** for DNS failover | Resilience | 2 hr |
| 23 | **Create shared flake-parts template** for new Go repos | DX | 2 hr |
| 24 | **Add CI flake check to all consumer repos** | Early detection | 2 hr |
| 25 | **Archive old status docs** — 350+ files in `docs/status/` + `archive/` | Disk space | 30 min |

---

## G) OPEN QUESTION

**#1 question I cannot figure out myself:**

> **`just test-fast` passes but `--all-systems` fails on Darwin.** The error is from Linux-only packages declaring `meta.badPlatforms`. This is *expected* behavior — those packages should not build on Darwin. But should our CI run `--all-systems` or `--no-build`? If `--all-systems`, how do we make it skip packages that are intentionally Linux-only without setting `allowUnsupportedSystem = true` (which defeats the purpose)? If `--no-build`, we never validate that the Darwin configuration actually evaluates all the way. **What is the correct CI command for a cross-platform flake that has intentionally platform-limited packages?**

---

## Session Metrics

| Metric | Value |
|--------|-------|
| Files changed | 9 |
| Commits | 5 |
| New lib helpers | 2 (`mkSecretCheck`, `mkDesktopNotifyService`) |
| Modules refactored | 7 (3 secret checks, 2 notify services, 2 Docker imports) |
| Lines changed (lib + modules) | ~400 (net reduction via abstraction) |
| `just test-fast` | ✅ all checks passed |
| NixOS modules | 35 active, 36 files |
| Flake inputs | 85 |
| Disabled services | 3 (voice-agents, file-and-image-renamer, minecraft) |
| TODO_LIST.md age | 7 days stale |
| Status docs total | 95+ in `docs/status/`, 350+ in `archive/` |
