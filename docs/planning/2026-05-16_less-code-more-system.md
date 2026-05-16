# Less Code, More System: Abstraction Opportunities

**Date:** 2026-05-16
**Context:** Session 23 — post display-watchdog analysis

---

## 5 Concrete Ways to Do More With Less

### 1. `mkDockerService` — Kill 400 lines of boilerplate

**The pattern repeats in 4 files (819 lines total):**
```nix
# Every Docker service does this exact sequence:
tmpfiles.rules = ["d ${stateDir} ..."];
path = [pkgs.docker pkgs.docker-compose];
ExecStart = "${docker-compose} --env-file ${stateDir}/.env -f ${composeFile} up --remove-orphans";
ExecStop  = "${docker-compose} --env-file ${stateDir}/.env -f ${composeFile} down";
ReadWritePaths = [stateDir];
```

**One factory function in `lib/`:**
```nix
mkDockerService = { name, composeFile, stateDir, envFile ? null, memoryMax ? "2G", ... }:
  # Returns the entire systemd.services.<name> + tmpfiles.rules + sops templates
```

**Impact:** 4 files × ~80 lines boilerplate each → 1 function + 4 × ~20 lines config = **~240 lines saved**. Adding a new Docker service goes from 100-200 lines to ~30.

**Affected files:**
- `modules/nixos/services/manifest.nix` (200 lines)
- `modules/nixos/services/openseo.nix` (103 lines)
- `modules/nixos/services/twenty.nix` (188 lines)
- `modules/nixos/services/photomap.nix` (84 lines)

---

### 2. `mkGatusEndpoint` — Kill 400 lines of monitoring boilerplate

**283 lines for 26 endpoints (27 lines each).** Every endpoint has the same shape:
```nix
{ name = "..."; group = "..."; url = "http://localhost:${port}/...";
  interval = "30s"; conditions = [...]; alerts = [{ type = "discord"; }]; }
```

A `mkGatusEndpoint` helper (like the existing `mkRule` in signoz-alerts.nix) could reduce each endpoint from 27 lines to ~5:
```nix
mkGatusEndpoint "Immich" "Media" config.services.immich.port "/"
```

**Impact:** 26 × 22 lines saved = **~570 lines saved**. Adding monitoring for a new service becomes a one-liner.

**Affected files:**
- `modules/nixos/services/gatus-config.nix` (283 lines)

---

### 3. Consecutive-failure watchdog — Kill 5 scripts' shared pattern

**5 scripts** (display-watchdog, niri-drm-healthcheck, route-health-monitor, gpu-recovery) all implement the same pattern:
```sh
STATE_DIR=...; STATE_FILE=...; THRESHOLD=3
mkdir -p "$STATE_DIR"
count=$(cat "$STATE_FILE"); count=$((count+1)); echo "$count" > "$STATE_FILE"
[ "$count" -ge "$THRESHOLD" ] && trigger_recovery
```

**Extract to `lib.sh`:**
```sh
consecutive_counter() { state_file=$1; threshold=$2; shift 2; "$@"; }
```

Then each watchdog becomes: "check condition → `consecutive_check` → act". The 5 scripts shrink by ~15 lines each.

**Impact:** ~75 lines saved. DRY across 5 scripts.

**Affected files:**
- `scripts/display-watchdog.sh` (103 lines)
- `scripts/niri-drm-healthcheck.sh` (53 lines)
- `scripts/route-health-monitor.sh` (266 lines)
- `scripts/gpu-recovery.sh` (119 lines)
- `scripts/internet-diagnostic.sh` (137 lines)

---

### 4. Caddy vhosts as data, not code

**114 lines** of hand-written Caddy config where each vhost follows the same pattern: `@match host`, `handle`, `reverse_proxy localhost:PORT`, optional `forward_auth`.

Declare vhosts as a list:
```nix
virtualHosts = [
  { host = "git.home.lan";  port = config.services.gitea.settings.server.HTTP_PORT; auth = true; }
  { host = "photos.home.lan"; port = config.services.immich.port; auth = true; }
  { host = "ai.home.lan";   port = 11434; auth = false; }
];
```

Then one `map` generates all Caddy blocks. **Adding a new service behind Caddy becomes a one-line data entry** instead of writing 8-15 lines of Caddyfile syntax. Also guarantees every vhost has forward-auth unless explicitly disabled.

**Impact:** ~80 lines saved. 15 → 1 line per vhost.

**Affected files:**
- `modules/nixos/services/caddy.nix` (114 lines)

---

### 5. Service self-registration pattern

The biggest leverage: services should **declare their own monitoring** rather than requiring manual wiring across 3 files (service module, caddy.nix, gatus-config.nix).

Right now adding a service requires:
1. Create `modules/nixos/services/foo.nix`
2. Add to `flake.nix` imports
3. Add `nixosModules.foo` to evo-x2 config
4. Enable in `configuration.nix`
5. Add Caddy vhost in `caddy.nix`
6. Add Gatus endpoint in `gatus-config.nix`
7. Add port reference table to AGENTS.md

**Steps 5-6 should be automatic.** If every service module exposes `{ port; healthPath; virtualHost; needsAuth; }` options, then `caddy.nix` and `gatus-config.nix` can generate their config from `config.services.*` introspection — zero manual wiring.

**Impact:** ~200 lines saved + eliminates a class of manual wiring bugs (forgot to add monitoring, forgot Caddy vhost). New service goes from 7 manual steps to 4.

---

## Summary

| Abstraction | Lines Saved | New Service Effort | Priority |
|---|---|---|---|
| `mkDockerService` | ~240 | 100-200 → 30 lines | P1 |
| `mkGatusEndpoint` | ~570 | 27 → 5 lines per endpoint | P1 |
| Consecutive-failure lib | ~75 | DRY across 5 scripts | P2 |
| Caddy vhosts as data | ~80 | 15 → 1 line per vhost | P2 |
| Service self-registration | ~200 + manual work | 7 steps → 4 steps | P1 |

**Total: ~1,165 lines eliminated.** More importantly, adding a new service goes from touching 7 files to touching 3, and monitoring/reverse-proxy config is automatic.

---

## Current State Baseline

| Metric | Count |
|---|---|
| NixOS service modules | 36 |
| Docker services (boilerplate) | 4 (819 lines) |
| Gatus endpoints | 26 (283 lines, 27 lines each) |
| Caddy vhosts | 7 (114 lines) |
| Scripts with state-file pattern | 5 |
| `harden{}` call sites | 22 |
| `mkPackageOverlay` call sites | 11 |
| `tmpfiles.rules` occurrences | 16 service modules |
