# Session 70 — Discord Notification Channels, Monitoring Stack Maturity

**Date:** 2026-05-11 16:13
**Session Focus:** SigNoz Discord notification channels, Gatus Discord alerting, monitoring stack completeness
**Result:** Discord alerts working for SigNoz + Gatus ✅ · All pre-commit hooks pass ✅ · NOT YET DEPLOYED ⚠️

---

## Executive Summary

Implemented Discord notification channels for both SigNoz and Gatus monitoring stacks. SigNoz now has 9 declarative alert rules routing to a Discord channel via `preferredChannels`. Gatus now alerts on endpoint failures via Discord webhook. The webhook URL is managed as a sops secret.

**13 commits undeployed since session 66.** The system is running generation 313; the latest commit is 12 commits ahead.

---

## a) FULLY DONE ✅

### Discord Notification Channels (this session)

| Component | Status | Detail |
|-----------|--------|--------|
| SigNoz Discord channel | ✅ | `discord_configs` with webhook URL from sops, deployed by provision script |
| SigNoz alert rules → Discord | ✅ | All 9 rules have `preferredChannels = ["Discord Alerts"]` |
| Gatus Discord alerting | ✅ | `alerting.discord` with placeholder replacement via ExecStartPre |
| Sops secret | ✅ | `platforms/nixos/secrets/signoz.yaml` created, age-encrypted |
| Provision script extension | ✅ | Idempotent channel provisioning (delete by name → create fresh) |
| Validation | ✅ | `just test-fast` passes, all pre-commit hooks green |

### SigNoz Observability Stack (sessions 67–70)

| Component | Status |
|-----------|--------|
| 9 declarative alert rules | ✅ Disk, CPU, Memory, Systemd, GPU Thermal, DNS Blocker, EMEET PIXY, GPU VRAM, Niri Down |
| Declarative rule provisioning | ✅ `signoz-provision` service (idempotent delete/create) |
| Discord notification channel | ✅ Deployed alongside rules in same provision service |
| node_exporter + cAdvisor | ✅ System + container metrics |
| amdgpu-metrics | ✅ GPU VRAM, busy %, temp via textfile collector |
| niri-health-metrics | ✅ Compositor running/restarts/DRM errors |
| Journald log collection | ✅ 8 key services |
| ClickHouse storage | ✅ Metrics, traces, logs |
| OTel Collector | ✅ Prometheus scraping + OTLP ingest + journald |

### Gatus Health Checks (sessions 67–70)

| Component | Status |
|-----------|--------|
| 25 health check endpoints | ✅ Infrastructure, Development, Media, Monitoring, Productivity, AI |
| Discord alerting | ✅ `default-alert` with failure-threshold=3, send-on-resolved |
| SQLite storage | ✅ Persistent history |
| systemd hardening | ✅ `harden {}` + `serviceDefaults {}` |

### Go Tooling Ecosystem (session 69)

| Component | Status |
|-----------|--------|
| 5 new flake inputs wired | ✅ buildflow, go-auto-upgrade, go-structure-linter, branching-flow, art-dupl |
| All 9 Go projects build | ✅ Standardized flakes across ecosystem |
| 19 overlays total | ✅ 13 shared + 6 Linux-only |

### Monitoring Hardening (sessions 67–68)

| Component | Status |
|-----------|--------|
| `onFailure` for critical services | ✅ caddy, hermes, signoz, signoz-provision + 7 others (11 total) |
| `notify-failure@` template | ✅ Desktop notifications via `notify-send` on service failure |
| `systemdServiceIdentity` adoption | ✅ hermes.nix (9 lines saved) |
| Gatus check fixes | ✅ Caddy localhost→127.0.0.1, ComfyUI removed bogus TLS, 5m interval |
| Boot stability | ✅ Removed invalid `amdgpu.deepfl`, coredump 1G + compress, Quad9 fallback |

### lib/ Shared Infrastructure

| Helper | Adopters | Status |
|--------|----------|--------|
| `harden {}` | 20 modules, 27 call sites | ✅ Mature |
| `serviceDefaults {}` | 21 modules | ✅ Mature |
| `serviceTypes.systemdServiceIdentity` | 1 module (hermes) | ⚠️ Low adoption |
| `serviceTypes.servicePort` | 2 modules (gatus, hermes) | ⚠️ Low adoption |
| `serviceTypes.restartDelay` | 1 module (hermes) | ⚠️ Only 1 |

---

## b) PARTIALLY DONE ⚠️

### onFailure Coverage

**11/20 services have `onFailure` wired.** 9 critical services still missing:

| Missing Service | Module |
|----------------|--------|
| dns-blocker | `dns-blocker.nix` |
| authelia (via authelia-main) | `authelia.nix` |
| ollama | `ai-stack.nix` |
| comfyui | `comfyui.nix` |
| homepage | `homepage.nix` |
| taskchampion-sync-server | `taskchampion.nix` |
| signoz-collector | `signoz.nix` |
| dual-wan monitor | `dual-wan.nix` |
| monitor365 | `monitor365.nix` |

### systemdServiceIdentity Adoption

Only hermes.nix uses it. `ai-models.nix` is the only other module with all three fields (user, group, stateDir). Most modules only define `User` — not worth adopting the helper for single-field usage.

### Gatus Secret Injection

The ExecStartPre + sed pattern works but is fragile — it mutates a file in `/run/` after copying from the Nix store. If the webhook URL contains regex-special characters, the `sed` could break. (Current URL is safe.)

---

## c) NOT STARTED ❌

### Deployment

- **13 commits undeployed** since generation 313 (session 66)
- Kernel still at 7.0.1 — 7.0.6 available in nixpkgs-unstable
- `just switch` + reboot needed to activate everything

### Overlay Extraction

- flake.nix is 843 lines — ~200 lines of overlays could move to `overlays/` directory
- No overlay tests or validation beyond `nix flake check`

### Remaining Service Modules Without Hardening

13 service modules have no `harden {}`:

| Module | Why No Harden | Should It? |
|--------|--------------|------------|
| `sops.nix` | No systemd services | ❌ N/A |
| `steam.nix` | No systemd services | ❌ N/A |
| `audio.nix` | No systemd services | ❌ N/A |
| `default.nix` | No systemd services | ❌ N/A |
| `multi-wm.nix` | No systemd services | ❌ N/A |
| `ai-models.nix` | tmpfiles only | ⚠️ No services |
| `monitor365.nix` | User service | ✅ YES — missing |
| `monitoring.nix` | Timer/oneshot | ✅ Maybe |
| `niri-config.nix` | User services | ✅ YES — missing |
| `dns-failover.nix` | keepalived | ✅ YES — missing |
| `display-manager.nix` | SDDM theme | ⚠️ Minimal |
| `chromium-policies.nix` | No systemd services | ❌ N/A |
| `file-and-image-renamer.nix` | User service | ✅ Already has it (via sd.serviceDefaultsUser) |

### Gatus Endpoint Improvements

- No alert descriptions per endpoint (all use default)
- No endpoint-specific thresholds
- DNS Blocker health check uses HTTP — should also check actual blocking

### SigNoz Dashboarding

- Only 1 dashboard (`signoz-overview.json`) — could have per-service dashboards
- No saved views or report configurations

### Documentation Gaps

- No TODO_LIST.md exists
- AGENTS.md is comprehensive but some sections (GPU defense, monitoring) could be more concise
- No ADRs for Discord notification architecture decisions

---

## d) TOTALLY FUCKED UP 💥

### Gatus ExecStartPre Environment Variable Trick

The `environment.GATUS_CONFIG_PATH = "/run/gatus/gatus.yaml"` override in the gatus systemd service works because the nixpkgs gatus module sets this same variable — we override it to point to the runtime copy. However, there's a subtle issue:

- The nixpkgs module sets `GATUS_CONFIG_PATH` via `environment` to the Nix store path
- Our override replaces it with `/run/gatus/gatus.yaml`
- The `preStart` script copies FROM `${GATUS_CONFIG_PATH}` (the Nix store path) TO `/run/gatus/gatus.yaml`
- **But**: at `preStart` time, the environment variable is already overridden, so `${GATUS_CONFIG_PATH}` is `/run/gatus/gatus.yaml` — which doesn't exist yet on first boot!

**Fix needed**: The preStart should hardcode the Nix store config path instead of reading `$GATUS_CONFIG_PATH`. Or use `ExecStartPre` with the full Nix store path.

### Signoz Provision Script — Channel Created BEFORE Rules

The provision script creates the channel first, then rules. Rules reference channels by name via `preferredChannels`. This means the channel must exist before rules are created. Currently the order is correct (channels first). But if the channel creation fails silently (the `|| true` at the end), rules will reference a non-existent channel name and alerts won't fire.

### No Deployment Testing

All 13 undeployed commits passed `nix flake check --no-build` but have NOT been tested with a real `nix build` or `just switch`. The flake check only validates evaluation — not that services actually start.

---

## e) WHAT WE SHOULD IMPROVE! 🎯

### 1. Nix-Native Secret Injection for Gatus

**Current:** Placeholder string `__DISCORD_WEBHOOK_URL__` + `sed` in ExecStartPre
**Better:** Use `systemd.services.gatus.environmentFile` with a sops template, then reference environment variables in the Gatus config. **BUT** Gatus doesn't support env var substitution in YAML config. Alternative: generate the entire gatus config file at runtime from a sops template.

**Most Nix-native approach:** Use `sops.templates` to render the full gatus.yaml with the webhook URL baked in, pointing Gatus at the rendered file. This eliminates the sed hack entirely.

### 2. Overlay Extraction from flake.nix

843 lines is too long. Extract overlays to `overlays/shared.nix` and `overlays/linux.nix`. flake.nix should import them.

### 3. systemdServiceIdentity — Design Decision Needed

Only 1/42 modules uses it. Options:
- **A)** Keep it — adopt in ai-models.nix (only other 3-field candidate)
- **B)** Split into `serviceUser`, `serviceGroup`, `serviceStateDir` — more granular, wider adoption
- **C)** Remove it — the pattern isn't common enough to justify a helper

### 4. Harden Remaining User Services

`monitor365.nix` and `niri-config.nix` define user systemd services without `harden {}`. User services can still benefit from sandboxing (PrivateTmp, NoNewPrivileges, etc.) — use `serviceDefaultsUser` + `harden {}`.

### 5. SigNoz Rule Schema Migration

The existing rules use the v1 API format (`POST /api/v1/rules` with `{ data: { rule: { ... } } }`). SigNoz has a v2 API (`POST /api/v2/rules`) with a cleaner schema (`PostableRule`) that supports `condition.thresholds` with per-threshold channel routing. Consider migrating for richer alert routing.

### 6. Alert Rule Testing

No way to test if alert rules actually fire. Should:
- Create a test metric endpoint that always returns a value above threshold
- Verify the Discord channel receives a notification
- Or use `POST /api/v1/testRule` endpoint

### 7. Commit Hygiene — Doc-Only Commits Mixed with Code

Sessions 67-70 interleaved code changes with status reports and planning docs in the same branch. For cleaner history, consider: feature branches for code, `docs/` changes in separate commits.

---

## f) Top 25 Things We Should Get Done Next

### Critical (Deploy or Die)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Deploy all 13 commits** (`just switch` + reboot) | 🔴 Critical | 15 min |
| 2 | **Verify Discord notifications actually fire** after deploy | 🔴 Critical | 10 min |
| 3 | **Fix Gatus ExecStartPre GATUS_CONFIG_PATH bug** (preStart reads from overridden env var) | 🔴 Bug | 5 min |

### High Priority (Monitoring Completeness)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 4 | Wire `onFailure` to remaining 9 critical services | 🟡 High | 30 min |
| 5 | Add `harden {}` to monitor365, niri-config, dns-failover user services | 🟡 High | 20 min |
| 6 | Replace Gatus sed hack with sops template approach | 🟡 High | 30 min |
| 7 | Add SigNoz alert rule for Ollama down | 🟡 High | 15 min |
| 8 | Add SigNoz alert rule for Docker daemon down | 🟡 High | 15 min |
| 9 | Test alert firing end-to-end (trigger GPU VRAM alert, check Discord) | 🟡 High | 20 min |

### Medium Priority (Architecture & Quality)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 10 | Extract overlays from flake.nix → `overlays/` directory | 🟢 Medium | 1 hr |
| 11 | Decide on `systemdServiceIdentity` future (keep/split/remove) | 🟢 Medium | 15 min |
| 12 | Migrate SigNoz rules from v1 → v2 API schema | 🟢 Medium | 1 hr |
| 13 | Add per-service SigNoz dashboards (Docker, GPU, DNS) | 🟢 Medium | 2 hr |
| 14 | Create `TODO_LIST.md` from all planning docs | 🟢 Medium | 30 min |
| 15 | Add Gatus endpoint descriptions and per-endpoint alert config | 🟢 Medium | 30 min |
| 16 | Add DNS blocking effectiveness check to Gatus (verify blocked domain returns block page) | 🟢 Medium | 20 min |

### Lower Priority (Nice to Have)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 17 | Wire Pi 3 DNS failover (hardware not provisioned yet) | 🔵 Low | 4 hr |
| 18 | Add Gatus alerting for certificate expiry (TLS certs for *.home.lan) | 🔵 Low | 30 min |
| 19 | Create ADR for Discord notification architecture | 🔵 Low | 30 min |
| 20 | Consolidate docs/status/ — archive sessions 45-62 | 🔵 Low | 15 min |
| 21 | Add `just test` (full build) to CI pipeline or pre-push hook | 🔵 Low | 1 hr |
| 22 | Explore SigNoz log-based alert rules (journald → alert on error patterns) | 🔵 Low | 1 hr |
| 23 | Add Caddy reverse proxy metrics dashboard in SigNoz | 🔵 Low | 1 hr |
| 24 | Harden ClickHouse service (currently no MemoryMax, no harden) | 🔵 Low | 30 min |
| 25 | Update kernel from 7.0.1 → 7.0.6 (will happen with `just switch`) | 🔵 Low | 0 min (automatic) |

---

## g) Top #1 Question I Cannot Figure Out Myself

**The Gatus ExecStartPre `GATUS_CONFIG_PATH` bug:**

In `gatus-config.nix`, the `preStart` script reads `${GATUS_CONFIG_PATH}` to copy the config — but we also override `environment.GATUS_CONFIG_PATH = "/run/gatus/gatus.yaml"`. At preStart execution time, which value does `$GATUS_CONFIG_PATH` have? The systemd docs say `ExecStartPre` runs in the same environment as `ExecStart`, so the overridden value would be used — meaning the preStart tries to copy from `/run/gatus/gatus.yaml` (which doesn't exist yet) to `/run/gatus/gatus.yaml`.

**The fix is simple** — hardcode the Nix store config path in the preStart instead of reading `$GATUS_CONFIG_PATH`:

```nix
let
  staticConfig = config.services.gatus.settings; # or the generated file path
in {
  preStart = ''
    cp ${staticConfigFile} /run/gatus/gatus.yaml
    sed -i ...
  '';
}
```

But I can't test this without deploying. **Should I fix this before or after deployment?** The preStart will fail on first boot, but Gatus itself will still start with the old config path (the nixpkgs module sets `GATUS_CONFIG_PATH` to the Nix store path via `environment`). Actually — we override it. So Gatus will look for `/run/gatus/gatus.yaml` which doesn't exist if preStart fails. This means **Gatus will crash on boot**.

This needs to be fixed before deploying.

---

## Undeployed Commits (generation 313 → HEAD)

| # | Commit | Description |
|---|--------|-------------|
| 1 | `93e18cf6` | fix(monitoring): improve Gatus health checks, boot stability, DNS resilience |
| 2 | `d8375175` | fix(monitoring): add upstream DNS check, clean stale imports, reduce DNS log noise |
| 3 | `59985ac4` | feat(monitoring): add GPU VRAM and Niri compositor alert rules to SigNoz |
| 4 | `3e2c16c5` | fix(gatus): remove bogus TLS client config from ComfyUI HTTP check |
| 5 | `821f46c5` | fix(monitoring): wire failure notifications to caddy, hermes, and signoz |
| 6 | `13b8c12f` | refactor(hermes): adopt systemdServiceIdentity from lib/types.nix |
| 7 | `d1f2652b` | feat(nix): wire 5 Go tooling projects as flake inputs with overlays |
| 8 | `bce40ad0` | chore: update flake.lock for new Go tooling inputs |
| 9 | `821f46c5` | (duplicate in rebase?) |
| 10 | `25d88350` | docs(planning): add Go flake standardization plan |
| 11 | `667307db` | docs(status): session 69 |
| 12 | `79b2f579` | docs(status): session 68 |
| 13 | `7a8a1912` | feat(monitoring): add Discord notification channels for SigNoz and Gatus |

---

## Are We Doing Things in the Most Nix-Native Ways Possible?

### ✅ What's Good

1. **flake-parts architecture** — modular, composable, correct
2. **sops-nix for secrets** — age-encrypted, declarative, auto-decrypted at boot
3. **Shared lib/ helpers** — `harden`, `serviceDefaults`, `serviceTypes` — DRY and consistent
4. **Module option patterns** — every service defines its own `port` option, referenced by Caddy
5. **Idempotent provisioning** — delete-by-name/create pattern for SigNoz rules and channels
6. **treefmt + alejandra** — automatic formatting, no style debates
7. **Pre-commit hooks** — gitleaks, deadnix, statix, alejandra, flake check

### ⚠️ What Could Be More Nix-Native

1. **Gatus secret injection** — The `sed` hack is not Nix-native. Should use `sops.templates` to render the full config YAML with the secret baked in.
2. **SigNoz provision script** — Bash+curl is functional but fragile. A Nix-native alternative would be a small Go/Python tool that reads declarative rule definitions and reconciles them via the API.
3. **Overlay organization** — 200 lines of overlays in flake.nix should be in `overlays/` files, imported via `flake-parts` or direct `imports`.
4. **Test infrastructure** — `just test-fast` only does `nix flake check --no-build`. Should have `nix build` tests (maybe via CI).
5. **`justfile` still exists** — AGENTS.md says it's deprecated, but it's still the task runner. The migration to `flake.nix` apps hasn't started.

### ❌ What's Anti-Pattern

1. **Gatus `environment` override trick** — Overriding a nixpkgs module's `environment` key to change runtime behavior is fragile and undocumented. If nixpkgs changes how `GATUS_CONFIG_PATH` is set, we break.
2. **`|| true` on all curl calls** — The provision script silently swallows errors. If SigNoz is up but returns 500, we think provisioning succeeded.

---

_Arte in Aeternum_
