# Cache System — Full Review Round

**Date:** 2026-08-15 22:05 (session: "Review everything about the cache system")
**Scope:** the entire build-cache system — module (`buildcache.nix`), consumers (`home.nix` vars/symlinks, `snapshots.nix`), monitoring (`buildcache-metrics`, Gatus), scripts (`report-goexperiment-gaps.sh`, `buildcache-btrfs-convert.sh`, `migrate-buildcache`), and the deployed runtime state. Executed the P0 debt list from `2026-08-15_21-46_BUILDCACHE-SMARTENING-SELF-REVIEW.md` §f.

**Method:** verify behavior, not artifacts — every P0 item closed by executing the real deployed script/binary or reading live journals/metrics.

---

## 1. Runtime verification (all P0 items CLOSED)

| P0 item | Method | Result |
|---|---|---|
| gc never executed | ran the DEPLOYED store script as the unit's user with the unit's exact env/PATH | **exit 0, 12.2s**: npm verify GC'd 1.4G garbage; pnpm prune removed 382 pkgs / 209,908 files / **2.51G**; usage 44%→41%; watermark correctly not hit; rust prune correctly no-op (nothing >14d) |
| sccache untested | tiny serde project, 2 builds (fresh + after `cargo clean`) | **fresh build 6.1s (12 misses, 0 errors, 9.1M written to the mount); clean rebuild 2.3s with 12/12 dependency HITS** — rustc never re-ran. Wrapper resolution, disk-store write, and hit path all proven |
| 96% alert unverified | gatus journal (API is OIDC-gated; sqlite root-only; sudo/systemctl blocked) | **TRIGGERED 03:37 → failing every 30min all day → RESOLVED 21:58** (`filesystem_build-cache-usage`), both sent to Discord. **Alert delivery WORKS for this path** — the monitor365 silence is a separate incident, not a broken alerting stack |
| init idempotency | journal + fix | confirmed live: init skipped 6× on the `!…/.initialized` condition → **fixed** (see §2) |
| script syntax | `bash -n` + line-by-line review (shellcheck unavailable in env) | both OK; one real bug found in the btrfs script (§2) |
| /tmp litter | trash | `/tmp/jv2test`, `/tmp/gocache*.go`, `/tmp/sccache-readme.md`, + this session's `/tmp/sccache-test` all trashed |

Also closed TODO_LIST item: `/mnt/buildcache/me/` test photos trashed (drive now holds only declared cache dirs).

## 2. Issues found & fixed

1. **`buildcache-init` one-shot-per-reformat trap** (the latent bug from the self-review, d.1): `ConditionPathExists=!…/.initialized` made every FUTURE `buildcacheDirs` entry inert — new dirs require manual mkdir after first init. **Fix:** condition removed; init runs idempotently every boot (mkdir/chown/chmod; trivial cost). Audited: this was the repo's ONLY such guard.
2. **`buildcache-gc` would have silently lost pnpm prune under hardening**: the manual run revealed `pnpm store prune` writes state to `~/.cache/pnpm` (dlx + project registries — visible in the run output). Under the unit's `ProtectHome=read-only` those writes fail → `|| echo non-fatal` → weekly prune permanently broken without a signal. **Fix:** `ReadWritePaths` hole for `${homeDir}/.cache/pnpm`. (The manual run could NOT prove the unit worked — it ran without hardening; this is exactly the artifacts-vs-behavior trap again.)
3. **`buildcache-gc` timeout too tight**: `go clean -cache` at watermark scale (100G+ of small files) is metadata-bound on a DRAM-less USB drive; 20min risked a SIGTERM mid-clean + spurious onFailure alert. → 45min.
4. **gc script confusing failure mode** if the mount vanishes mid-run (empty `pct` → "integer expression expected"): explicit guard + clear journal line + exit 1 (onFailure fires with a readable cause).
5. **`buildcache-init` missing `coreutils` in `path`** — worked via systemd's DefaultPATH (`/run/current-system/sw/bin`) fallback; now explicit.
6. **`buildcache-btrfs-convert.sh` staged go-mod into `/tmp` — which is tmpfs (RAM, 48G cap)**. 9G staging would eat RAM; moved to `/var/tmp` (disk-backed).

Not fixed (deliberate): pip/playwright dirs have no GC step — mtime-based pruning would delete ACTIVE artifacts (pip/browser mtimes don't refresh on use); the ≥90% `go clean` guard remains the disk-wedge backstop. Noted as backlog observability.

## 3. Verified healthy (no action)

- Mount options, `mkFilesystem` usage, automount + `nofail` semantics; metrics collector always-writes design (stale-green-proof) live every 5min.
- Gatus checks semantically correct (mounted/smart/usage-vs-threshold); thresholds (failure 3 / success 2 / send-on-resolved) behave as seen in the 03:37→21:58 lifecycle.
- Deployed `hm-session-vars.sh` exports all 8 cache vars; HM symlinks (goimports/go/pnpm-store) + rust target symlinks in place; disk 42% and structurally bounded.
- `migrate-buildcache` is a historical one-time tool — no drift risk vs `buildcacheDirs`.

## 4. Remaining open (unchanged backlog)

- VM test for buildcache-gc (P0 #7 — the one P0 not closed; unit-level execution verified instead).
- Sunday 05:00 first scheduled gc run — **check journal for the hardened (ProtectHome=read-only + hole) prune path**.
- Satellite GOEXPERIMENT sweep (21 repos), btrfs conversion window, go-codec 1.26.6 floor, sccache hit-ratio metric, gopls consolidation — see TODO_LIST + prior report §f.
- monitor365/browser-history outages (5 post-deploy FAILs) — pre-existing, out of cache-system scope.

## 5. Answers to prior open questions (report §g)

1. **Did the ≥85% Discord alert fire?** YES — TRIGGERED 03:37, RESOLVED 21:58, both delivered (gatus journal). Alert delivery is functional; no incident.
2. go-codec 1.26.6 floor / 3. btop upstream issue — still user decisions, untouched.

---

**Bottom line:** all 6 executable P0 items closed with runtime evidence; 3 real bugs fixed (init trap, pnpm-vs-hardening, tmpfs staging) + 3 hardening improvements; cache system verified healthy at 42% with growth structurally bounded. Deployed 22:08 (40 PASS / 5 FAIL — same pre-existing monitor365/browser-history baseline); the deploy itself ran `buildcache-init` successfully, behaviorally confirming the idempotency fix. Post-deploy: verify Sunday 05:00's hardened gc run in the journal.
