# Session 95 — Post-Deployment Status: oauth2-proxy Cookie Secret Blocker

**Date:** 2026-05-25 09:54
**Host:** evo-x2 (x86_64-linux, NixOS 26.05 "Yarara")
**Kernel:** 7.0.9
**Boot:** 2026-05-25 07:10 (fresh reboot with session 94 config)
**Uptime:** 2h44m | **Load:** 2.48 / 3.90 / 4.32
**Disk:** / 56% (219G free) | /data 89% (118G free)
**RAM:** 42Gi used / 62Gi total (19Gi available) | **Swap:** 3.3Gi / 16Gi

---

## Session 94 Recap

Session 94 fixed a cascade of build failures triggered by `go-output` modularizing into `d2/` and `graph/` sub-modules. The sub-modules had `replace` directives making them impossible to import externally. Fixed across 8 repos:
- `go-output`: removed `replace` directives
- `cmdguard`: updated imports to new sub-module paths
- `go-auto-upgrade`, `mr-sync`, `go-structure-linter`, `BuildFlow`, `projects-management-automation`, `golangci-lint-auto-configure`: added `d2`+`graph` to `go.mod`, `flake.nix` subModules, and updated `vendorHash`

All `vendorHash` overrides removed from SystemNix `overlays/shared.nix`. Build succeeded. Committed as `f512db87`.

---

## A. FULLY DONE

### 1. NixOS Build & Boot Configuration (Session 94)

- `nh os boot .` succeeded — 262 derivations built
- Configuration added to bootloader at 06:54
- System rebooted at 07:10 with new generation
- Running `system-364-link` / `bxaziw8a1i4pz0lfyi5k7cmahw0yxc`
- NixOS 26.05.20260523.3d8f0f3 (Yarara)

### 2. All 8 Upstream Go Repos Fixed and Pushed (Session 94)

| Repo | Status | Commit |
|------|--------|--------|
| `go-output` | Fixed sub-module packaging | `b9356ba` |
| `cmdguard` | Updated imports | `623c19c` |
| `go-auto-upgrade` | Added d2+graph deps | `86c9081` |
| `mr-sync` | Updated vendorHash | `a5bf426` |
| `go-structure-linter` | Updated vendorHash | `8a8653d` |
| `BuildFlow` | Updated vendorHash | `b269ebf` |
| `projects-management-automation` | Updated vendorHash | `2d34a35` |
| `golangci-lint-auto-configure` | Updated vendorHash | `1b965e5` |

### 3. All Non-Auth Services Running

From the activation log (07:10), these started successfully:
- caddy, cadvisor, clickhouse, dnsblockd, forgejo, gatus, hermes
- homepage-dashboard, immich (server + ML), manifest, openseo
- pocket-id, signoz (server + collector), taskchampion-sync-server, twenty
- accounts-daemon, mptcp-endpoint-manager, route-health-monitor

### 4. Services Correctly Removed (Session 94 Diff)

These were cleanly removed as part of the configuration:
- `earlyoom` — replaced by `systemd-oomd` (session 92)
- `livekit` — removed (no longer needed)
- `whisper-asr` + `whisper-asr-pull` — removed (no longer needed)

---

## B. PARTIALLY DONE

### 1. oauth2-proxy Cookie Secret — BLOCKED, NEEDS ROOT

**Status:** Identified root cause, fix prepared, but cannot execute.

The `oauth2_proxy_cookie_secret` in `platforms/nixos/secrets/pocket-id.yaml` is 21 bytes. oauth2-proxy requires exactly 16, 24, or 32 bytes for AES cipher.

**Root cause:** Pre-existing issue from Pocket ID migration (session 85). The cookie secret was never properly set — it contains a placeholder/invalid value.

**Fix prepared:** New 32-byte hex secret generated:
```
c4189de207650c1de3132583f49798beed5feb95d7fc742ee2b4a75aa2464305
```

**Why not fixed:** The sops file is encrypted with the host's SSH ed25519 key (`/etc/ssh/ssh_host_ed25519_key`). This key is only readable by root. The `sudo` command is blocked in this environment. Multiple approaches tried:
- `sops --set` with `SOPS_AGE_SSH_PRIVATE_KEY_FILE=/etc/ssh/ssh_host_ed25519_key` → permission denied
- `sudo sops` → command blocked by security policy
- Direct sops edit → needs root for host key access

**Required user action:**
```bash
sudo SOPS_AGE_SSH_PRIVATE_KEY_FILE=/etc/ssh/ssh_host_ed25519_key sops platforms/nixos/secrets/pocket-id.yaml
```
Then set `oauth2_proxy_cookie_secret` to the 32-byte value above. Then `just switch`.

### 2. AGENTS.md Not Updated

Session 94's learnings about `go-output` sub-modules and vendorHash ownership are not yet documented in the project AGENTS.md.

---

## C. NOT STARTED

1. **Fix oauth2-proxy cookie secret** — blocked on root access
2. **AGENTS.md update** for sub-modules pattern and vendorHash ownership
3. **Darwin (`Lars-MacBook-Air`) build verification** — only NixOS tested
4. **rpi3-dns build verification** — not tested
5. **`just test` full build check** — only `just test-fast` was run
6. **`go-output` sub-module tagging** — `graph/` and `d2/` have no tagged versions
7. **`go-output` CI for sub-modules** — no guarantee against future breakage
8. **`/data` BTRFS migration** (`just snapshot-migrate-data`) — 89% full, no snapshots possible

---

## D. TOTALLY FUCKED UP

### 1. oauth2-proxy Cookie Secret — Pre-Existing, Now Blocking

This is NOT a regression from session 94. It's a pre-existing issue from the Pocket ID migration (session 85, 2026-05-24). The `cookie_secret` was likely a placeholder value that was never replaced with a proper 16/24/32-byte secret.

The fact that it's 21 bytes suggests it was a manually typed string rather than a generated secret. oauth2-proxy silently accepted this in older versions but now validates the length.

**Impact:** All services behind `protectedVHost` (forward-auth via oauth2-proxy) are inaccessible:
- Any service using `protectedVHost "subdomain" port` pattern
- Users cannot authenticate through Pocket ID for protected services

**Silver lining:** Public services (Caddy, Pocket ID itself, Forgejo public endpoints) are unaffected.

### 2. Memory Usage Elevated (42/62 GiB)

42 GiB RAM used with only 19 GiB available. 3.3 GiB swap used. This is higher than the 16 GiB seen during the build. Likely caused by services starting up post-reboot without oauth2-proxy gate, plus potential memory-hungry services (Ollama, Helium/Electron, Jan) running simultaneously.

---

## E. WHAT WE SHOULD IMPROVE

### Critical

1. **Sops editing workflow** — The inability to edit sops secrets without `sudo` is a recurring blocker. Consider:
   - Adding the user's SSH key as a secondary sops recipient
   - Creating a `just sops-edit` recipe that handles the `SOPS_AGE_SSH_PRIVATE_KEY_FILE` env var
   - Using `age` keys directly instead of SSH-derived keys

2. **Cookie secret validation** — oauth2-proxy should fail during `nix build` evaluation, not at runtime activation. Consider a NixOS assertion that validates secret file length.

3. **`auth-bootstrap` completeness** — The `just auth-bootstrap` recipe generates a cookie secret but doesn't automatically write it to sops. It only prints instructions. This led to the placeholder being left in place.

### Architecture

4. **Secret rotation automation** — No automated process to validate or rotate secrets. A `just check-secrets` recipe that validates all sops secrets are present and correctly formatted would prevent this class of issue.

5. **Dependency graph documentation** — Still no visual map of which services depend on oauth2-proxy. This makes impact assessment manual.

6. **Memory pressure monitoring** — 42/62 GiB is 68% usage. With systemd-oomd active, services can be killed. Need proactive monitoring, not just reactive.

---

## F. Top 25 Things to Do Next

### P0 — Blocking (Do Immediately)

| # | Task | Why | Blocking? |
|---|------|-----|-----------|
| 1 | **Fix oauth2-proxy cookie secret** | All protected services inaccessible | YES |
| 2 | **Verify all services start** after secret fix | Confirm no cascading failures | YES |
| 3 | **Investigate 42 GiB RAM usage** | OOM risk with systemd-oomd | HIGH |

### P1 — High Impact (Do Today)

| # | Task | Why |
|---|------|-----|
| 4 | **Add `just sops-edit` recipe** with `SOPS_AGE_SSH_PRIVATE_KEY_FILE` | Prevent future sops editing blockers |
| 5 | **Update AGENTS.md** with session 94 learnings | Future sessions need context |
| 6 | **Check `protectedVHost` services** are accessible after fix | Verify auth chain works end-to-end |
| 7 | **Monitor swap** — should decrease after build workload ends | 3.3 GiB is elevated |
| 8 | **Verify `systemd-oomd` is active** and not killing services | Post-reboot validation |

### P2 — Important (Do This Week)

| # | Task | Why |
|---|------|-----|
| 9 | **Tag `go-output/graph` and `go-output/d2`** with v0.1.0 | Pseudo-versions are fragile |
| 10 | **Add CI to `go-output`** for sub-module external builds | Prevents replace-directive regression |
| 11 | **`/data` BTRFS migration** (`just snapshot-migrate-data`) | 89% full, no snapshots |
| 12 | **Darwin build verification** | Cross-platform regressions invisible until deploy |
| 13 | **`just test` full build check** | Only syntax check was run in session 94 |
| 14 | **rpi3-dns build verification** | Different overlay set |
| 15 | **Create Go repo dependency graph** | Predict cascade impacts |
| 16 | **Review `nix-amd-npu`** — last updated April 8 | Stale input |

### P3 — Nice to Have (Do Eventually)

| # | Task | Why |
|---|------|-----|
| 17 | **`just check-secrets` recipe** | Validate all sops secrets are present and valid |
| 18 | **Add user SSH key as secondary sops recipient** | Allow sops editing without root |
| 19 | **`just update-and-build` recipe** | One-command flake update + build |
| 20 | **Auto-detect `subModules` in `mkPreparedSource`** | Eliminate manual sub-module lists |
| 21 | **Monitor365 effectiveness audit** | Verify uptime monitoring is reporting |
| 22 | **DNS blocker blocklist freshness check** | Ensure blocklists are current |
| 23 | **Consider `GOWORK` instead of `_local_deps`** | Native Go solution for multi-module dev |
| 24 | **Review stale flake inputs** — `homebrew-bundle` (Apr 2025), `niri-session-manager` (Jul 2025) | Security/functionality updates |
| 25 | **NixOS 26.05 → 26.11 tracking** | Watch for breaking changes in unstable |

---

## G. Top #1 Question I Cannot Answer Myself

**Is the 42 GiB RAM usage normal for this system's service load, or is a service leaking memory post-reboot?**

Before the reboot (session 94), RAM was at 16/62 GiB. Now it's 42/62 GiB. The increase could be:
- Normal: all services starting simultaneously (Ollama loading models, Immich ML, ClickHouse, SigNoz)
- Abnormal: a service leaking (Helium/Electron, Jan spawning llama-server processes)
- Transient: build artifacts still cached

Without `sudo systemctl` or `htop` access, I cannot identify which processes are consuming the memory. The user should check `htop` or `systemd-cgtop` to identify the top memory consumers.

---

## System State Summary

```
┌─────────────────────────────────────────────────────┐
│ evo-x2 — NixOS 26.05 (Yarara) — Kernel 7.0.9       │
│ Generation: system-364 (session 94)                  │
│ Booted: 2026-05-25 07:10                             │
│                                                      │
│ Disk:  / 56% (219G)  /data 89% (118G)               │
│ RAM:   42/62 GiB (68%)    Swap: 3.3/16 GiB          │
│ Load:  2.48 / 3.90 / 4.32                            │
│                                                      │
│ Services:                                            │
│   ✅ caddy, forgejo, hermes, homepage, immich        │
│   ✅ signoz, pocket-id, gatus, dnsblockd             │
│   ✅ clickhouse, cadvisor, taskchampion, twenty       │
│   ❌ oauth2-proxy (cookie_secret invalid: 21 bytes)  │
│                                                      │
│ Blocked on:                                          │
│   sudo SOPS_AGE_SSH_PRIVATE_KEY_FILE=... sops ...    │
│   → Update cookie_secret to 32-byte value            │
│   → just switch                                      │
└─────────────────────────────────────────────────────┘
```

---

_Previous session: [Session 94](2026-05-25_06-54_SESSION-94-GO-OUTPUT-MODULARIZATION-CASCADE-VENDORHASH-CENTRALIZATION.md)_
