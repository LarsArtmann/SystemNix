# Status Report — nixpkgs Aug-16 Bump Rescue + Smoke-Check Overhaul

**Date:** 2026-08-16 22:00 · **Session start:** ~20:10 · **Host:** evo-x2 · **Branch:** master
**Trigger:** User's `nix flake update && nh os switch` failed with a hard eval error; task was diagnose → fix → deploy → verify.

---

## Executive Summary

The nixpkgs Aug-13 → Aug-16 bump (`0e251e24` → `e5bdc4a4`) renamed wf-recorder's callPackage arg `ffmpeg` → `ffmpeg_8` (nixpkgs `fc31aa40b9`), turning SystemNix's Aug-13 ffmpeg_6 pin overlay into a hard eval error. The overlay was obsolete anyway — nixpkgs now builds wf-recorder 0.6.0 against FFmpeg 8 by default (verified by local build before removing anything). After removal, the full 12-input lock bump evaluated clean, passed `nix flake check --no-build` (131 checks), deployed, and is live: **evo-x2 runs `26.11.20260816.e5bdc4a`**.

The post-deploy smoke test then surfaced **three pre-existing check-script bug classes** (not deploy damage), all fixed and verified: 5 of 7 auth-gateway probes used hostnames that never existed (phantom SKIPs since inception), curl 8.21's implicit `Accept-Encoding` breaks every body-parsing grep (gzip served, never decoded), and Monitor365 FAILed permanently for a deliberately-disabled service.

**Final verified state: 42 PASS / 2 FAIL (both external, see d) / 7 SKIP (all meaningful) / 2 WARN (both pre-existing, uninvestigated).**

A concurrent session (drive repurposing, `docs/planning/2026-08-16_20-22_three-drive-repurposing.md`) was actively migrating Immich to the new Toshiba MG08 pool (`/mnt/pool`) during this session's verification. Its file edits (`immich.nix`, `hardware-configuration.nix`, `lib/ports.nix`) were deliberately left untouched.

---

## a) FULLY DONE

1. **Root-cause of the eval blocker** — nixpkgs `fc31aa40b9` (2026-08-13) "wf-recorder: pin ffmpeg_8" removed the unversioned `ffmpeg` callPackage arg; our `wfRecorderFfmpeg6Overlay` (`.override { ffmpeg = prev.ffmpeg_6; }`) became `function called with unexpected argument 'ffmpeg'`. Verified via GitHub API (commit + diff) AND empirically (`nix build nixpkgs#wf-recorder` at `e5bdc4a4` → success against ffmpeg 8.1.2).
2. **`wfRecorderFfmpeg6Overlay` removed** (`overlays/linux.nix`) — the exact action TODO_LIST item "Track wf-recorder FFmpeg 7 upstream fix" prescribed. A concurrent agent made the identical edit minutes earlier; diff verified identical intent, no conflict. ffmpeg_6/ffmpeg_7 still exist in nixpkgs if ever needed.
3. **Stale `library-policy.inputs.treefmt-nix.follows` removed** (`flake.nix:208`) — upstream library-policy dropped the treefmt-nix input (verified against its flake at `605765a2`); the override produced the "override for a non-existent input" warning on every command. Comment at flake.nix:40 updated. Post-fix eval shows zero such warnings.
4. **Lock-bump confusion resolved with facts** — initial misread: jq on lock-node key `nixpkgs` showed Aug-10 `2fcb964d`, suggesting a downgrade. Truth: root input `nixpkgs` maps to node key **`nixpkgs_2`** = `e5bdc4a4` (Aug 16, correct); the `nixpkgs` node key is go-nix-helpers' internal pin (harmless). Confirmed via root-inputs mapping in flake.lock.
5. **Full evaluation + check** — `nix eval .#nixosConfigurations.evo-x2...toplevel.drvPath` clean; `nix flake check --no-build` → **all checks passed** (131 check lines; aarch64-darwin skipped as expected/documented).
6. **Deployed** — `nix run .#deploy` succeeded through activation + provisioner restarts. Live generation verified: `nixos-version` → `26.11.20260816.e5bdc4a`. No tarball-lock regression (Registry check PASS).
7. **Auth-gateway phantom coverage fixed** (`scripts/post-deploy-check.sh`) — probes were `dozzle./monitor365./searx./crush./taskchampion.home.lan`; real Caddy vHosts are `logs./monitor./search./daily./tasks.home.lan`. Wrong names NXDOMAIN (dnsblockd resolves only listed subdomains) → SKIPped "unreachable" forever. Now probes real vHosts; verified **7/7 PASS** (monitor → 301, valid).
8. **curl implicit-gzip class fixed** — curl 8.21 (new nixpkgs) sends `Accept-Encoding` by default; gzip-compressing servers (crush-daily middleware, node_exporter) return encoded bodies plain `curl -s` never decodes → greps match nothing, "ignored null byte" bash warnings. Proven empirically (172-byte gzip vs 1027-byte identity on the same endpoint). `--compressed` added to all 9 body-parsing call sites in `post-deploy-check.sh` (incl. the `check()` helper all vHost body assertions use), both `/metrics` scrapes in `pre-deploy-check.sh` (the phantom-metric check would have silently degraded), and 5 in `verify-deployment.sh`. Verified: Crush Daily SKIP → **PASS has reports + PASS latest report session_count >0**. Historical note: the DiscordSync `grep -a` "null bytes in JSON" fix was the same bug, misdiagnosed.
9. **Monitor365 disabled-service handling** (`post-deploy-check.sh`) — units-absent detection via `systemctl list-unit-files 'monitor365*'`; API/UI/agent/watchdog checks now SKIP with reason instead of permanently FAILing a deliberately-off service (private-git-dep blocker, `enable = false` in configuration.nix). Also prevents pointless restart attempts on absent units.
10. **Lint/format** — statix + deadnix clean on all changed `.nix` files; `nix fmt` applied (only side effect: formatting-normalized the daemon's gatus-config.nix commit). `bash -n` clean on all changed scripts.
11. **Documentation updated** — CHANGELOG.md: 3 entries (overlay removal, phantom vhosts, curl gzip). TODO_LIST.md: 2 wf-recorder items closed as DONE with evidence. AGENTS.md: new "curl ≥8.2x implicit Accept-Encoding" gotcha under Shell & DevTools.

## b) PARTIALLY DONE

1. **curl gzip sweep** — check scripts fixed and verified, but **module-level body-parsing curls NOT yet audited/fixed**: `pocket-id.nix:79,284` (API provisioner, parses with jq), `forgejo-repos.nix:69,90`, `_forgejo-scripts.nix:55,188,541` (Forgejo API). These target Go APIs which may not gzip — unverified risk, not confirmed broken. Effort: S to verify each endpoint's encoding behavior.
2. **Null-byte warning elimination** — one "command substitution: ignored null byte" warning still appears in the packaged script (line ~233 post-edit). Root cause of THAT specific line not yet identified (gzip fixed the Crush Daily one; another fetch still emits NULs — likely DiscordSync `/api/stats` embedded data, which already carries a `grep -a` note). Cosmetic but signals an unclean parse. Effort: S.
3. **Verification of the smoke-check fixes through the real deploy path** — `nix run .#post-deploy-check` verified (which builds the wrapped script), but `pre-deploy-check` with `--compressed` hasn't been executed end-to-end yet (next deploy will). Effort: zero (wait for next deploy).
4. **Session changes uncommitted at report time** — all fixes sit in the working tree alongside the concurrent session's edits. The auto-git daemon will sweep them, but attribution/messages may mix the two sessions' work. (Report itself is committed separately per status-report procedure.)

## c) NOT STARTED

1. **Runtime verification of wf-recorder against FFmpeg 8** — build success proven; actual screen recording on the niri desktop NOT tested (session was SSH-only). Risk: low (0.6.0 + ffmpeg_8 is nixpkgs' own default combination now), but the overlay existed because of runtime API breaks.
2. **Regression guard for vhost-name drift** — no automated check asserts `AUTH_VHOSTS` ⊆ real Caddy vHost names; the phantom-SKIP class can silently recur when the next vhost is added/renamed.
3. **Centralized curl helper for scripts** — each script hand-rolls flags; `--compressed` had to be added call-site by call-site (and was missed once before, on DiscordSync).
4. **Pocket ID SQLITE_BUSY investigation** — transient `database is locked` bursts observed around service restarts (20:21, 20:45–20:48; zero after settle). Pattern recurring across deploys; never root-caused (WAL mode? provision-burst write contention?). Not blocking.
5. **quickshell journal 1-error-line WARN** — my journal query used the wrong unit name (`--user -u quickshell` returned nothing); the error line behind the WARN was never identified. Pre-existing WARN, present in every smoke run this session.

## d) TOTALLY FUCKED UP

*(Nothing from this session's work is broken. Two live operational failures exist, both external to the deploy:)*

1. **DiscordSync ↔ Turso cloud sync is DOWN — Turso free-plan quota exhausted** — journal shows `quota_exceeded … SQL read operations are forbidden (reads are blocked, do you need to upgrade your plan?)`, push+pull failing since ≥21:16, sync circuit breaker tripped at 21:26 (1h backoff, `is_quota_error=true`). Local SQLite serving unaffected (process healthy, thumb-hash backfill in progress). Severity: local-first data safe; cloud offsite copy stale. Root cause: Turso plan limits. Mitigation: none applied — needs a decision (see question 1).
2. **Immich offline (502 external, unreachable local) — deliberately stopped by the concurrent storage session at 21:13** for the Toshiba MG08 pool migration (`btrfs subvolume create /mnt/pool/services/immich` observed in the journal, sudo from that session's PWD). NOT deploy damage. Gatus was still green at 21:12:58 pre-stop; will alert during the migration window. Ownership/ETA unknown from this session (see question 2).

**Self-critique of this session's own mistakes:**

- **flake.lock misdiagnosis (wasted cycle)** — I initially concluded the daemon had "downgraded" nixpkgs to Aug-10 `2fcb964d` and burned ~6 tool calls chasing it (commit dates, diffs, jq). The truth was in the failing command's own error output all along (`e5bdc4a4` in the trace) plus the root-inputs→node-key mapping (`nixpkgs` → `nixpkgs_2`). Lesson: read the lock's `root.inputs` mapping before jq-ing node keys.
- **`sed -i` on verify-deployment.sh** — inconsistent tooling (edit/multiedit elsewhere); worked, but bypasses the exact-match discipline.
- **Declared "renamer WARN pre-existing, not gzip" too early** — it was partly the gzip bug class all along (status endpoint parse); the WARN persists only because the data genuinely shows 0 operations. Correct final state, sloppy intermediate reasoning.

## e) WHAT WE SHOULD IMPROVE

1. **Smoke-check assertions must be executable, not aspirational** — 5/7 auth-gateway probes never once exercised their target in their entire existence, and the script still reported "OK". Every check that can SKIP forever without anyone noticing is negative coverage. Fix pattern: derive expected names from config (caddy.nix attrnames) or add a meta-check that SKIP-count > N pages a human.
2. **Environment-dependent tool behavior belongs in a wrapper, not in every call site** — the curl 8.21 gzip change was a system-wide behavior shift that had to be discovered through a broken check. A `scripts/lib.sh` `fetch()` helper (curl + `--compressed` + timeout + retry defaults) would have made the class impossible to reintroduce.
3. **Point-in-time smoke evidence should be committed with the fix** — I verified 7/7 vhosts and Crush Daily PASS in terminal output only; the report/CHANGELOG carries the claim but not the transcript. Cheap fix: `--json` summary output from post-deploy-check, diffable over time.
4. **Concurrent-session coordination is ad-hoc** — two agents edited the same repo simultaneously (identical overlay removal = luck, not process; my `git status` mid-session caught it). The daemon commits also interleave. A lightweight convention (e.g., agents state claimed files in a scratch note) would remove the luck.
5. **`nix flake update && nh os switch` as one command** — the failed flow would have been caught by `nix flake check --no-build` in ~40s before any build attempt. The deploy.sh path does this; the manual path doesn't. Consider a `nix run .#update` app wrapping update+check+switch with the check gate.

## f) Next Tasks (session-derived, ranked)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Decide DiscordSync/Turso: upgrade plan vs disable cloud sync (local-only) | Critical | S | Decision |
| 2 | Confirm Immich returns post pool-migration; verify data intact at `/mnt/pool/services/immich` | Critical | M | Ops |
| 3 | Verify concurrent session's `immich.nix`/`hardware-configuration.nix` edits get deployed (drift check vs running gen) | High | S | Ops |
| 4 | Audit module-level body-parsing curls for gzip risk (pocket-id provisioner, forgejo scripts); add `--compressed` where parsed | High | S | Bug |
| 5 | Identify + fix remaining null-byte warning source in post-deploy-check (~line 233) | Medium | S | Quality |
| 6 | Runtime-verify wf-recorder screen recording on niri (ffmpeg_8) | Medium | S | Verification |
| 7 | Derive AUTH_VHOSTS from caddy.nix config (or eval-time assert names match) — kill the drift class | High | M | Quality |
| 8 | Centralize curl in `scripts/lib.sh` `fetch()` helper; migrate check scripts | Medium | M | Quality |
| 9 | Investigate Pocket ID SQLITE_BUSY restart bursts (WAL/`busy_timeout`/provision contention) | Medium | M | Bug |
| 10 | Identify the quickshell 1-error-line WARN source (correct journal unit) | Low | S | Bug |
| 11 | Confirm File Renamer 0-operations state is expected (fresh dir?) not split-brain | Medium | S | Verification |
| 12 | Document lock-node key mapping gotcha (`nixpkgs` vs `nixpkgs_2`) in AGENTS.md | Low | S | Documentation |
| 13 | Add `nix run .#update` app: flake update + `flake check --no-build` gate + switch | Medium | M | Feature |
| 14 | post-deploy-check: emit machine-readable summary (JSON) for diffable deploys | Low | M | Feature |
| 15 | Turso: if staying local-only, remove sync env/keys from sops + module | High | S | Cleanup |
| 16 | Re-run `pre-deploy-check` end-to-end on next deploy (validates `--compressed` metrics scrapes) | Medium | S | Verification |
| 17 | Monitor365: resolve private-git-dep blocker (publish/vendor wireguard-collector) → re-enable + checks return to enforcing | Medium | L | Feature |
| 18 | Standing backlog unchanged — see TODO_LIST.md P0–P7 (go-cqrs-lite github input, benchstat pin, renamer follows, zram ADR, etc.) | Medium | — | Mixed |

## g) Questions (cannot answer myself)

1. **DiscordSync Turso quota:** the free plan now blocks ALL SQL reads ("do you need to upgrade your plan?"). Upgrade the Turso plan, or drop cloud sync and go local-only (local SQLite is healthy; cloud was the offsite copy)? This decides task 15's direction.
2. **Immich migration ownership:** the concurrent drive-repurposing session stopped immich-server at 21:13 for the `/mnt/pool` migration. Should this session verify its return (and is there an ETA/window), or is the other session fully owning it? Affects whether the Gatus alerts during the window should be tolerated.
3. **Overlay-removal verification bar:** is wf-recorder's ffmpeg_8 BUILD success sufficient to close the TODO, or do you want a real recorded-clip test on the desktop before considering it verified (I cannot interact with the graphical session from here)?

---

*Report procedure note: written as `.md` per explicit user instruction — the status-report skill's canonical format is styled HTML; this is a deliberate one-off override, not a new default. Section (f) is the docs-health HARVEST input; TODO_LIST.md already carries the two closed items, the rest await harvest.*
