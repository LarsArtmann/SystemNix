# Session 78 — Comprehensive Execution Plan

**Date:** 2026-05-23 08:29 CEST
**Status:** PLANNING — awaiting approval before execution

---

## Self-Reflection: What I Missed & Could Do Better

### What I Forgot in the Status Report
1. **SigNoz already has 16 alert rules** including a memory-critical rule (>90%). The status report said "no memory/swap alerting" — **partially wrong**. What's missing is only a SWAP-specific rule and alert routing to Discord.
2. **`protectedVHost` helper already exists** in caddy.nix — I didn't highlight that fixing the `tasks.${domain}` vhost is literally a 1-line change from inline to `protectedVHost`.
3. **`lib/rocm.nix` already centralizes `HSA_OVERRIDE_GFX_VERSION`** — I identified it as scattered tech debt, but the fix is already partially done. Just need to make voice-agents and ai-stack use it instead of hardcoding.
4. **`mkHttpCheck` helper exists** in lib — could immediately add health checks for all services.
5. **The `just check` command exists** — `just status` isn't needed as a separate command; `just check` + `just health` already cover it.
6. **Docker `latest` tags** — manifest and twenty use `mkDockerService`, so they have `imageTag` options. The fix is to just change the default, not a structural change.
7. **OpenSEO `AUTH_MODE`** — needs investigation. It may not support OIDC. Changing to `local_auth` means we need a way to manage credentials.

### What I Could Improve
1. **Use existing helpers more** — `mkDockerService`, `mkHttpCheck`, `protectedVHost`, `serviceTypes`, `harden` — many services don't fully leverage the shared library.
2. **Consolidate GPU config** — `lib/rocm.nix` exists but voice-agents and ai-stack hardcode `HSA_OVERRIDE_GFX_VERSION` instead of importing from it.
3. **Type safety** — many services use plain `lib.types.str` for ports instead of `serviceTypes.servicePort`. Docker image tags should use a structured type with validation.
4. **Documentation accuracy** — FEATURES.md and TODO_LIST.md are stale. This creates a false picture of the system.

### Architecture Type Model Improvements
1. **Shared port registry** — add a `lib/ports.nix` with all service ports as constants. Prevents conflicts (e.g., openseo:3001 vs monitor365:3001).
2. **Docker image tag type** — create a `serviceTypes.dockerImageTag` that rejects `"latest"` and requires semver.
3. **Harden profiles** — instead of per-service `extraHarden` overrides, define named profiles like `hardenWeb`, `hardenDocker`, `hardenGPU` that compose properly.
4. **GPU memory fraction type** — formalize the GPU memory allocation as a type with validation (0.0-1.0).

---

## Pareto Analysis

### The 1% that delivers 51% of the result:
- **Deploy 8 undeployed commits** — serial8250 boot fix, homepage memory cap, ZRAM expansion, watchdog fix. All committed, none running.

### The 4% that delivers 64%:
- Deploy commits + **fix 3 Docker `latest` tags** + **add forward-auth to tasks vhost** + **add swap alert rule**

### The 20% that delivers 80%:
- All above + **consolidate GPU config** + **fix FEATURES.md** + **add health checks for missing services** + **create shared port constants**

---

## Comprehensive Plan — Sorted by Impact/Effort

### Legend
- **Impact:** 🔴 Critical > 🟠 High > 🟡 Medium > 🟢 Low
- **Effort:** XS (<12min), S (12-30min), M (30-60min), L (60-120min)
- **Type:** fix = bug fix, sec = security, perf = performance, refac = refactoring, docs = documentation, feat = new feature

---

### Phase 1: Deploy & Verify (Critical — Do First)

| # | Task | Impact | Effort | Type | File(s) |
|---|------|--------|--------|------|---------|
| 1.1 | Deploy all 8 undeployed commits via `just switch` | 🔴 | XS | perf | — |
| 1.2 | Verify boot time reduced from ~3m54s to ~2m20s | 🟠 | XS | perf | — |
| 1.3 | Verify homepage memory ~150-200MB (was 1-2GB) | 🟠 | XS | perf | — |
| 1.4 | Verify display-watchdog restarts niri correctly | 🟡 | XS | fix | — |

### Phase 2: Security Quick Wins (High Impact, Low Effort)

| # | Task | Impact | Effort | Type | File(s) |
|---|------|--------|--------|------|---------|
| 2.1 | Pin twenty Docker image from `"latest"` → specific version | 🟠 | XS | sec | `twenty.nix` |
| 2.2 | Pin manifest Docker image from `"latest"` → specific version | 🟠 | XS | sec | `manifest.nix` |
| 2.3 | Pin openseo Docker image from `"latest"` → specific version | 🟠 | XS | sec | `openseo.nix` |
| 2.4 | Add forward-auth to `tasks.${domain}` vhost using `protectedVHost` | 🟠 | XS | sec | `caddy.nix` |
| 2.5 | Add swap alert rule to SigNoz (`swap-critical.json`) | 🟡 | XS | feat | `signoz-alerts.nix` |

### Phase 3: Consolidation & Cleanup (Medium Impact, Low Effort)

| # | Task | Impact | Effort | Type | File(s) |
|---|------|--------|--------|------|---------|
| 3.1 | Create `lib/ports.nix` — centralized port registry | 🟡 | S | refac | new file |
| 3.2 | Make voice-agents use `lib/rocm.nix` instead of hardcoded `HSA_OVERRIDE_GFX_VERSION` | 🟡 | XS | refac | `voice-agents.nix` |
| 3.3 | Make ai-stack use `lib/rocm.nix` instead of hardcoded `HSA_OVERRIDE_GFX_VERSION` | 🟡 | XS | refac | `ai-stack.nix` |
| 3.4 | Fix manifest `CORS_ORIGIN` from `localhost` to actual domain | 🟡 | XS | fix | `manifest.nix` |
| 3.5 | Remove gpu-recovery dead code from niri-config.nix | 🟢 | XS | refac | `niri-config.nix` |
| 3.6 | Fix `file-and-image-renamer` version mismatch note in FEATURES.md | 🟢 | XS | docs | `FEATURES.md` |

### Phase 4: Documentation Accuracy (Medium Impact, Medium Effort)

| # | Task | Impact | Effort | Type | File(s) |
|---|------|--------|--------|------|---------|
| 4.1 | Fix FEATURES.md: ZRAM 50%→10%, boot time, remove phantom scripts | 🟡 | S | docs | `FEATURES.md` |
| 4.2 | Update TODO_LIST.md with current state — mark deployed items done | 🟡 | S | docs | `TODO_LIST.md` |
| 4.3 | Update AGENTS.md with any new patterns/discoveries from this session | 🟡 | XS | docs | `AGENTS.md` |

### Phase 5: Hardening (Medium Impact, Medium Effort)

| # | Task | Impact | Effort | Type | File(s) |
|---|------|--------|--------|------|---------|
| 5.1 | Add Gatus health checks for services missing them (openseo, twenty, manifest, hermes) | 🟡 | S | feat | `gatus-config.nix` |
| 5.2 | Add OpenSEO auth investigation — check if `local_auth` works or OIDC is supported | 🟡 | S | sec | `openseo.nix` |
| 5.3 | Audit Docker container memory limits in compose files | 🟡 | S | perf | `twenty.nix`, `openseo.nix` |
| 5.4 | Add deer-flow-frontend memory limit to Docker compose | 🟡 | XS | perf | (wherever deer-flow is) |

### Phase 6: Architecture Improvements (Lower Impact, Higher Effort)

| # | Task | Impact | Effort | Type | File(s) |
|---|------|--------|--------|------|---------|
| 6.1 | Migrate services to use `lib/ports.nix` constants instead of inline port numbers | 🟢 | M | refac | many files |
| 6.2 | Add `serviceTypes.dockerImageTag` — reject `"latest"` at eval time | 🟡 | S | refac | `lib/types.nix` |
| 6.3 | Create hardening profiles (`hardenWeb`, `hardenDocker`, `hardenGPU`) in lib | 🟢 | S | refac | `lib/systemd.nix` |
| 6.4 | Consolidate voice-agents Caddy vHost into caddy.nix pattern | 🟢 | S | refac | `voice-agents.nix`, `caddy.nix` |

### Phase 7: Not Started / Deferred (High Effort or External Dependency)

| # | Task | Impact | Effort | Type | Notes |
|---|------|--------|--------|------|-------|
| 7.1 | Configure secondary LLM provider for Hermes | 🟠 | M | feat | Needs API key |
| 7.2 | Fix Hermes git remote access (SSH deploy key) | 🟡 | S | sec | Needs keygen |
| 7.3 | Fix Hermes sudo access | 🟡 | M | sec | Architecture decision needed |
| 7.4 | Verify Hermes firecrawl/edge-tts/fal/exa tools at runtime | 🟡 | M | feat | Needs manual testing |
| 7.5 | Move Forgejo admin password to sops | 🟡 | S | sec | Needs sops config |
| 7.6 | Register more OIDC clients in Authelia | 🟡 | M | sec | Per-client setup |
| 7.7 | Enable Immich hardware acceleration | 🟡 | S | perf | Test GPU passthrough |
| 7.8 | Provision Pi 3 for DNS failover | 🟡 | L | feat | Hardware + OS install |
| 7.9 | Investigate Ollama `wantedBy = []` — document or fix | 🟡 | S | docs | Needs user input |
| 7.10 | Flake inputs audit — find stale/unused inputs | 🟢 | M | refac | 47 inputs to audit |
| 7.11 | Create `just status` command | 🟢 | S | feat | Or extend `just check` |
| 7.12 | nix-colors integration (~6h) | 🟢 | L | refac | Low priority |
| 7.13 | Deploy Dozzle at logs.home.lan | 🟢 | S | feat | New service module |

---

## D2 Execution Graph

```d2
direction: right

title: Session 78 Execution Plan — SystemNix

phase1: {
  shape: rectangle
  label: Phase 1: Deploy & Verify
  style.fill: "#f38ba8"

  deploy -> verify_boot -> verify_homepage -> verify_watchdog
}

phase2: {
  shape: rectangle
  label: Phase 2: Security Quick Wins
  style.fill: "#fab387"

  pin_twenty -> pin_manifest -> pin_openseo -> fix_tasks_auth -> add_swap_alert
}

phase3: {
  shape: rectangle
  label: Phase 3: Consolidation
  style.fill: "#f9e2af"

  create_ports -> rocm_voice -> rocm_aistack -> fix_cors -> remove_dead_code
}

phase4: {
  shape: rectangle
  label: Phase 4: Documentation
  style.fill: "#a6e3a1"

  fix_features -> update_todo -> update_agents
}

phase5: {
  shape: rectangle
  label: Phase 5: Hardening
  style.fill: "#89b4fa"

  add_gatus_checks -> investigate_openseo_auth -> audit_docker_mem -> deer_flow_limit
}

phase6: {
  shape: rectangle
  label: Phase 6: Architecture
  style.fill: "#cba6f7"

  migrate_ports -> docker_tag_type -> harden_profiles -> consolidate_vhosts
}

phase1 -> phase2 -> phase3 -> phase4 -> phase5 -> phase6
```

---

## Top #1 Question

**Is OpenSEO supposed to be publicly accessible?**

It's currently behind Caddy + Authelia forward-auth at `seo.${domain}`, but the app itself has `AUTH_MODE: local_noauth`. If Authelia is bypassed (misconfig, direct IP access), the service is wide open. Before I change it, I need to know:
1. Should OpenSEO be accessible to anyone who passes Authelia? (Current behavior is fine then — double-auth is annoying)
2. Should OpenSEO have its own user accounts? (Change to `local_auth`)
3. Is OpenSEO ever accessed directly without going through Caddy?

---

_This plan covers 44 tasks across 7 phases. Phases 1-3 (19 tasks) are the 80/20 — deploy + security + consolidation. Phases 4-6 (12 tasks) are quality improvements. Phase 7 (13 tasks) are deferred._
