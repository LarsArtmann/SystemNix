# Status Report — Session 126: Version Upgrade Sprint (SigNoz + Hermes)

**Date:** 2026-06-09 17:08 CEST
**Host:** Lars-MacBook-Air (Darwin, remote management of evo-x2)
**Branch:** master @ `79005a65` (WIP) + uncommitted working tree changes
**Scope:** SigNoz 0.117.1→0.127.1, OTel Collector 0.144.2→0.144.5, Hermes v2026.5.16→v2026.6.5, Hermes overlay simplification

---

## Executive Summary

Three hardcoded version pins upgraded to latest releases, all building cleanly. The Hermes overlay was simplified significantly — the `fixedHash` / `interceptCallPackage` workaround is **permanently removed** because upstream v2026.6.5 now uses `fetcherVersion=2` natively. `nix flake check` passes clean. One pre-existing build failure (`golangci-lint-auto-configure`) confirmed unrelated to this work.

---

## A) FULLY DONE ✅

### SigNoz Upgrade (0.117.1 → 0.127.1)

| Component | Old | New | Status |
|-----------|-----|-----|--------|
| SigNoz | v0.117.1 | v0.127.1 | ✅ Built, vendorHash verified |
| OTel Collector | v0.144.2 | v0.144.5 | ✅ Built, collectorVendorHash verified |

**Files changed:**
- `flake.nix` lines 103, 107 — tag pins updated
- `flake.lock` — upstream refs refreshed
- `modules/nixos/services/signoz.nix` — version strings (lines 7-8) + both vendor hashes (lines 16, 43)

**Process:** Blank hash → `nix build` → capture `got:` hash → paste → rebuild to verify. Two iterations (collector first, then main binary).

### Hermes Upgrade (v2026.5.16 → v2026.6.5)

| Component | Old | New | Status |
|-----------|-----|-----|--------|
| hermes-agent flake input | v2026.5.16 | v2026.6.5 | ✅ Built |
| Overlay complexity | 37 lines, `fixedHash` + `interceptCallPackage` | 15 lines, simple extend + override | ✅ Simplified |

**Key discovery:** Upstream v2026.6.5 added `fetcherVersion = 2` and `npmDepsFetcherVersion = 2` to `nix/lib.nix`, with a correct `npmDepsHash`. The old workaround (intercepting `callPackage` to patch the TUI npm deps hash) is permanently unnecessary.

**Files changed:**
- `flake.nix` line 145 — tag pin updated
- `flake.lock` — hermes-agent + transitive deps refreshed
- `modules/nixos/services/hermes.nix` — removed 22 lines of workaround code

### Verification

| Check | Result |
|-------|--------|
| `nix build .#signoz-schema-migrator` | ✅ Success |
| `nix build .#signoz` | ✅ Success |
| Hermes (via system package eval) | ✅ Success |
| `just test-fast` (`nix flake check --no-build`) | ✅ All checks passed |

---

## B) PARTIALLY DONE ⚠️

### This Status Report & Commit

- Status report: ✅ Being written now
- Git commit: ⚠️ WIP commit `79005a65` exists, uncommitted changes in working tree (`hermes.nix`, `signoz.nix`) need to be committed

### Hermes Deploy & Runtime Verification

- Build: ✅ Verified building
- Deploy to evo-x2: ❌ Not yet deployed
- Runtime check (hermes gateway, cron jobs): ❌ Blocked on deploy
- OpenAI fallback provider: ⚠️ Config exists, manual secret injection still needed

---

## C) NOT STARTED ❌

1. **Deploy to evo-x2** — `just switch` on evo-x2 to apply all changes
2. **Verify SigNoz dashboards** — Check that existing dashboards, alerts, and data survived the version bump
3. **Verify SigNoz OTel Collector** — Confirm traces/metrics/logs still flowing after collector upgrade
4. **Hermes runtime test** — `journalctl -u hermes --since "5m ago"` to verify gateway starts clean
5. **Hermes OpenAI fallback** — `sops platforms/nixos/secrets/hermes.yaml` needs `openai_api_key` added manually
6. **Hermes SSH deploy key** — Private key needs manual install at `/home/hermes/.ssh/id_ed25519`
7. **GLM-5.1 rate limit monitoring** — Verify cron jobs recovered after upgrade
8. **Boot time verification** — `systemd-analyze` after next reboot
9. **Pi 3 DNS failover** — Still blocked on hardware

---

## D) TOTALLY FUCKED UP 💥

### golangci-lint-auto-configure (Pre-existing, NOT caused by this session)

- **Build failure:** `go mod tidy` needed — the package's go.mod is out of sync
- **Confirmed pre-existing:** Tested via `git stash` — broken before our changes
- **Impact:** Low — not a runtime dependency, development tooling only
- **Fix:** Needs upstream go.mod fix or `overrideModAttrs` with `go mod tidy`

### Hermes npm deps fetcher version hell (RESOLVED, but worth documenting)

During the hermes upgrade, multiple build attempts failed with:
```
error: fetcher version in the arguments to buildNpmPackage (2) is not the same as the one in npm-deps (1)
```

Root cause: The nix store had **cached npm-deps outputs from fetcher v1** that were stale. Even after updating the code, Nix kept reusing the old fixed-output derivation. Required:
1. `nix store delete` on the stale npm-deps paths
2. `nix-collect-garbage` to clean unreachable store entries
3. Only THEN would the new fetcher v2 output be computed

**Lesson:** When upgrading between fetcher versions, aggressively clean the nix store of old FODs.

---

## E) WHAT WE SHOULD IMPROVE 🔧

### Immediate (this session's artifacts)

1. **Amend/squash the WIP commit** — `79005a65` has `vendorHash = ""` placeholders; the real commit should have final hashes
2. **Update AGENTS.md** — Remove `fixedHash` workaround references if any remain; document that hermes v2026.6.5+ needs no hash patching

### Short-term

3. **Automate version pin upgrades** — Create a `just upgrade-pins` recipe that checks GitHub latest releases for all `v[0-9]` pins in `flake.nix` and reports which are behind
4. **SigNoz version centralization** — Version strings exist in BOTH `flake.nix` and `signoz.nix`; should derive from one source
5. **Vendor hash blanking automation** — Script that blanks all vendor hashes, builds, captures `got:` hashes, and fills them in
6. **golangci-lint-auto-configure fix** — Either fix upstream or add `overrideModAttrs` workaround

### Medium-term

7. **Hermes health check** — Add a `mkHttpCheck` for hermes gateway endpoint to Gatus
8. **SigNoz upgrade test** — Add a lightweight smoke test that verifies SigNoz eval + basic build after version bumps
9. **Nix store FOD cleanup** — Add a `just clean-fods` recipe that removes stale fixed-output derivations
10. **Stale LSP cleanup effectiveness** — Verify the daily timer is actually working (check `systemctl list-timers`)

---

## F) Top 25 Next Tasks

| # | Task | Priority | Blocked? |
|---|------|----------|----------|
| 1 | Deploy to evo-x2 (`just switch`) | P0 | No |
| 2 | Verify SigNoz dashboards + data post-upgrade | P0 | On deploy |
| 3 | Verify Hermes gateway starts clean | P0 | On deploy |
| 4 | Commit current changes (this session) | P0 | No |
| 5 | Add `openai_api_key` to hermes sops secrets | P1 | Manual |
| 6 | Install hermes SSH deploy key | P1 | Manual |
| 7 | Fix `golangci-lint-auto-configure` build | P1 | No |
| 8 | Centralize SigNoz version (single source of truth) | P2 | No |
| 9 | Create `just upgrade-pins` automation | P2 | No |
| 10 | Verify stale LSP cleanup timer is running | P2 | On evo-x2 |
| 11 | Boot time measurement after deploy | P2 | On reboot |
| 12 | Add Hermes health check to Gatus | P2 | No |
| 13 | Monitor GLM-5.1 rate limit recovery | P2 | On evo-x2 |
| 14 | Run `just verify` post-deploy verification script | P2 | On deploy |
| 15 | Update AGENTS.md hermes section (no fixedHash needed) | P3 | No |
| 16 | Create vendor hash blanking automation script | P3 | No |
| 17 | Clean up old nix store FODs from fetcher v1 era | P3 | No |
| 18 | Provision Pi 3 for DNS failover | P3 | Hardware |
| 19 | Wire Pi 3 as secondary DNS in dns-failover.nix | P3 | On Pi 3 |
| 20 | Darwin disk space audit (90%+ full) | P3 | On Darwin |
| 21 | Template go-flake-parts to go-nix-helpers (commit + push) | P3 | No |
| 22 | Add SigNoz smoke test for version bump validation | P4 | No |
| 23 | Review FEATURE.md for accuracy post-upgrades | P4 | No |
| 24 | Audit `docs/status/` archive — move old reports | P4 | No |
| 25 | Consider SigNoz ClickHouse backup pre-upgrade strategy | P4 | No |

---

## G) Top #1 Question ❓

**SigNoz 0.117.1 → 0.127.1 is a 10-version jump. Are there any database migration steps required between these versions that we should verify on deploy?**

The SigNoz schema migrator is built from the collector source, and we upgraded that too (0.144.2 → 0.144.5). But a 10-version jump in the main SigNoz binary could include ClickHouse schema changes, breaking API changes, or dashboard format changes. We should check the SigNoz changelog for migration notes before deploying — or at minimum, take a ClickHouse backup first.

---

## Session Stats

| Metric | Value |
|--------|-------|
| Commits | 1 WIP (`79005a65`) + pending final commit |
| Files modified | 4 (`flake.nix`, `flake.lock`, `signoz.nix`, `hermes.nix`) |
| Lines removed | 22 (hermes workaround code) |
| Lines added | 4 (version strings + vendor hashes) |
| Packages upgraded | 3 (signoz, signoz-collector, hermes-agent) |
| Build time | ~25 min total (SigNoz Go builds are slow) |
| `just test-fast` | ✅ Passes clean |
| Pre-existing failures | 1 (`golangci-lint-auto-configure`) |
