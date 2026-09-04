# Forgejo Mirror Outage: Full Diagnosis, Boot-Order Fix, Monitoring & Curl Hardening

**Date:** 2026-08-22 08:52 · **Session:** single-agent · **Host:** evo-x2
**Input:** Priority-1 items from the 2026-08-21 brutal self-review (forgejo mirror sync spam + module-level curl gzip audit)

---

## Executive Summary

The review's verdict on the `AddAuthCredentialHelperForRemote` error spam — _"Verified NOT fatal: mirrors still complete"_ — was **wrong**. I verified against the forgejo v15.0.6 source that `TouchMirror` advances `mirror.updated_unix` on FAILURE, which is exactly what the review used as its "mirrors still complete" evidence. In reality, **pull-mirror syncing has been broken in three escalating phases since 2026-08-18 15:28, and was 100% dead from 2026-08-21 21:55 until this session's restart at 07:16 today** (~9.5h total silence, ~1.5 days of aborted syncs before that). Nothing alerted, because nothing monitored mirror health — the exact gap the review flagged.

**Current live state (verified 08:52):** mirrors ARE syncing again (`mirror_updated: 2026-08-22T07:16:37` — the 30m cron fired exactly 30 min after the deploy restart). The new Gatus check "Forgejo Mirror Sync" is deployed but **red on a false alarm**: the collector's sqlite `dbPath` is wrong (`scrape_errors=1`), needs one sudo command to fix.

---

## a) FULLY DONE

1. **Full three-phase incident diagnosis** (journal + upstream source + live API + binary grep, all verified):
   - **Phase 1 (08-18 15:28 → 08-21 00:28, 2,400 err lines/day):** forgejo 15.0.6 `runSync` aborts every credentialed sync — `os.CreateTemp` in `AddAuthCredentialHelperForRemote` fails with ENOENT on `/tmp/forgejo-clone-credentials-N` inside the unit's `PrivateTmp` namespace. `runSync` returns early → **syncs never ran at all**. Binary unchanged (15.0.6 since 08-18 06:58 boot); onset was mid-process-lifetime with no restart. Exact in-namespace ENOENT trigger NOT pinned (see d).
   - **Phase 2 (08-21 19:35 → 20:35):** every sync rejected by `recheckPullPermitted` — `migration/cloning from 'github.com' is not allowed` (DNS-rebinding/allowlist recheck failing; ~100 lines).
   - **Phase 3 (08-21 20:55 → 08-22 07:16):** total silence. Mirror queue wedged after the hard-freeze night's restarts. The `update_mirrors` cron (every 30m) pushes into a **unique queue** — dedup-skips log at Trace level only, so a wedged queue produces **zero journal output at LEVEL=Info**. Frozen `mirror_updated` is the ONLY signal.
   - **Why the review was fooled:** `SyncPullMirror` calls `TouchMirror` on failure, advancing `updated_unix` — the review's "UPDATE mirror SET updated_unix in the journal" proof measured failure-activity, not success.
2. **Boot-order fix for the main forgejo unit** (`modules/nixos/services/forgejo.nix`): `mkDnsGate` ExecStartPre (getent probe of `auth.<domain>`, 30×2s) + `after/wants` on `dnsblockd`, `caddy`, `pocket-id`. Root cause: today's 05:55 boot had forgejo up before DNS answered → `Unable to register source: PocketID … no such host` → with `ENABLE_INTERNAL_SIGNIN=false` **nobody could log in at all** until a restart. Verified live: post-deploy start shows `forgejo-wait-dns: DNS resolution ready` and clean OIDC registration.
3. **Mirror-health monitoring** (`system-health.nix` + `gatus-config.nix`), fail-closed, both failure classes covered:
   - `system_forgejo_mirror_last_sync_age_seconds` + `system_forgejo_mirror_sync_stalled` (age >10h) → catches the silent dead-queue class (age only goes stale when NOTHING runs, because TouchMirror advances on failure).
   - `system_forgejo_mirror_errors_30m` + `system_forgejo_mirror_erroring` (≥3 Error lines/30m) → catches active aborts (ENOENT era, allowlist rejections).
   - `system_forgejo_mirror_scrape_errors` → sqlite read failure fail-closes the Gatus pat() checks.
   - Gatus check "Forgejo Mirror Sync" (5m interval, Discord alerting, runbook text in the alert). `gatus-pattern-lint` flake check passes.
   - Options: `collectForgejoMirrors` (auto-disabled without forgejo), `forgejo.dbPath`.
4. **Curl gzip audit (task 2 of the review):** repo-wide sweep of body-parsing curls. The review's cited sites (`pocket-id.nix:79,284`, `forgejo-repos.nix:69,90`, `_forgejo-scripts.nix:55,188,541`) were **already fixed** in an earlier round. Found and fixed the two genuinely remaining jq-parsing curls: `_forgejo-scripts.nix` (forgejo-ssh-keys existing-keys fetch) and `monitor365.nix:414` (agent-watchdog realtime probe). All other candidates were status-code-only or `>/dev/null` probes (unaffected by gzip).
5. **Deployed everything twice** (flake check pass, toplevel build pass, pre-deploy-check pass).
6. **Recovered forgejo from a concurrent-deploy gap:** a concurrent session's activation stopped forgejo at 06:44:32 and its stc wedged before starting it (my deploy lost the lock race, exit 11). Waited out the wedged stc; the concurrent activation completed and forgejo came up at 06:46:29 with the new gate.

## b) PARTIALLY DONE

1. **Mirror-sync monitoring end-to-end green:** metrics + Gatus check deployed and live, but **the check is permanently RED on a false alarm** — the collector emits only `scrape_errors=1` with NO stderr diagnostic line, meaning `[ -r /var/lib/forgejo/data/forgejo.db ]` fails inside the root-run unit → the DB is almost certainly at a **different path** (old `gitea.db` from the pre-rename instance era, or a non-default app.ini `PATH`). One sudo grep of `app.ini` + a `forgejo.dbPath` override fixes it. (My shell has no sudo — see questions.)
2. **Upstream forgejo issues:** evidence fully verified from v15.0.6 source (three distinct bugs: ENOENT abort, TouchMirror-masks-failures, silent dead queue) but **nothing filed** — needs the verify-before-filing outbound pass + a Codeberg account decision.

## c) NOT STARTED

1. Fixing the `forgejo.dbPath` (blocked on sudo/app.ini read).
2. Identifying the **7 unidentified post-deploy smoke failures** (deploy 2 reported FAIL: 8; only one is the known Mirror Sync false alarm — I did not enumerate the others this session; several pre-existing WARNs existed before my changes).
3. Filing upstream forgejo issues.
4. VM test for the forgejo DNS-gate boot ordering.
5. Making `forgejo-github-sync` sense sync health (it only checks repo existence — "134 repos processed, 0 failed" is blind to mirror staleness; that blindness is why this outage was invisible for 4 days).

## d) TOTALLY FUCKED UP

1. **Deploy race with a concurrent session:** my first deploy aborted (exit 11, lock held); the concurrent activation then stopped forgejo and its stc hung ~2 min mid-activation, leaving the forge **down 06:44:32→06:46:29** and the runner erroring. Not my tree's fault (identical build), but I initially misdiagnosed the stc as "gone" because `pgrep -c "switch-to-configuration"` silently matches nothing for >15-char patterns — the deploy.sh guard using `pgrep -f` was right all along. Lesson: never use bare `pgrep <long-name>`.
2. **First collector version shipped a latent bug class I then had to rebuild for:** `case ''|*[!0-9]*)` inside a Nix `''…''` string — the `''` terminates the Nix string; caught by the build, fixed with `grep -qE '^[0-9]+$'`. Cost one build cycle.
3. **My first SQLITE_BUSY hypothesis for `scrape_errors=1` was wrong** (deployed a `.timeout 5000` fix that didn't change the outcome — the real cause is the wrong dbPath). The diagnostic echo I added will prove it next run; I should have verified the path as readable BEFORE shipping the first version (couldn't — no sudo; but I could have added the echo in v1).

## e) WHAT WE SHOULD IMPROVE

1. **Review verification standards:** "UPDATE mirror SET updated_unix" is not success evidence — `TouchMirror` advances on failure. Any future "verified not fatal" claim needs a success-side signal (e.g. commit-graph mtime, `mirror_updated` via API, or fetch traffic).
2. **Silent-degradation services need output-side monitoring, not liveness:** forgejo web 200-green ran through the ENTIRE outage while zero mirrors synced. Same class as every phantom-green in AGENTS.md. The new check closes this one; the pattern to apply everywhere: monitor the artifact (syncs happening), not the process.
3. **Boot-order DNS dependencies:** every daemon that resolves a name exactly-once at startup needs a DNS gate. `forgejo` was the last unguarded one in the OIDC chain (gatus/oauth2-proxy/browser-history/forgejo-oidc-setup already had gates; the MAIN forgejo daemon didn't).
4. **Concurrent-agent deploy races keep biting** (3rd documented occurrence). deploy.sh detection works, but the "losing" deploy's pre-deploy-check ran against mid-activation state and produced 3 phantom failures. Consider a lock-file acquisition at deploy.sh START (before pre-checks), not just detection at switch time.
5. **My sandbox lacks sudo/systemctl/curl** — every root-level diagnostic (app.ini, DB path, unit cat) became indirect. Where a check needs root, ship a diagnosable failure path (stderr echo) in v1, not v2.

## f) NEXT UP TO 50

**P0 — close out this incident:**

1. Run `sudo grep -A6 '^\[database\]' /var/lib/forgejo/custom/conf/app.ini`, get real `PATH`, set `services.system-health.forgejo.dbPath` accordingly (or make the collector try `forgejo.db`+`gitea.db`), deploy, verify Mirror Sync gatus green.
2. Enumerate the 8 post-deploy smoke failures (`nix run .#post-deploy-check`), triage which are mine vs pre-existing.
3. Watch the 30m cron for 2–3 cycles: confirm `mirror_updated` keeps advancing (next due ~07:46, 08:16 …) and no ENOENT/allowlist errors return.
4. Verify the `erroring` metric would have caught the ENOENT era: replay `journalctl --since 2026-08-19 --grep` against the metric's grep pattern (dry-run the exact command).
5. Check whether push mirrors (sync-on-commit to GitHub) also resumed — separate code path (`SyncPushMirror`), same queue.
   **P1 — upstream:**
6. File forgejo issue: unique mirror queue wedges after hard process kills; cron dedup-skip is Trace-silent → total silent sync stop (evidence: this incident).
7. File forgejo issue: `TouchMirror` on failure advances `updated_unix`, masking outages from API consumers.
8. File forgejo issue: `AddAuthCredentialHelperForRemote` ENOENT aborts credentialed mirror syncs (15.0.6, PrivateTmp unit) — include binary/source refs, onset-without-restart observation.
9. Evaluate forgejo `[queue]` config for mirror queue persistence/flush settings that survive crashes.
   **P1 — prevention layers:**
10. Add forgejo DNS-gate boot ordering to a VM test (dnsblockd-not-ready boot must not produce a PocketID-dead forgejo).
11. Make `forgejo-github-sync` verify `mirror_updated` freshness per repo and fail loudly on stalled mirrors (its "0 failed" was blind for 4 days).
12. post-deploy-check: add a forgejo mirror functional probe (API `mirror_updated` age < interval+slack).
13. Consider a generic "sqlite path existence" eval-time or pre-deploy assertion for collector dbPaths (gatus one worked because the path was copy-pasted from a verified incident; forgejo one was assumed from nixpkgs defaults).
14. Sweep other assumed-path consumers (`monitor365.stateDir` etc.) for the same stale-default risk.
    **P2 — from session observations:**
15. `forgejo-runner` logged `connection refused` errors during the 2-min forgejo gap — consider `RestartSec`/backoff review or a gatus check on runner heartbeats.
16. `mnt-buildcache.mount` start job timed out during activation (device job dependency) — buildcache recovery path re-verified post-deploy? (AGENTS says deploy.sh starts it; confirm it did.)
17. DMS/quickshell journal has error lines post-deploy (WARN in smoke) — triage.
18. fish startup 1281ms WARN in smoke — pre-existing, flagged.
19. The `forgejo.service` unit has BOTH `forgejo-wait-dns` ExecStartPre AND existing `forgejo-pre-start`/ensure-password-file — verify ordering is sane (it evaluated and ran correctly; document in module comment).
20. Consider `journalctl` `-g` pattern reuse: my metric greps 4 patterns per run every 2min — fine, but keep an eye on cost (the AGENTS journalctl IO-trap rule is respected: `--grep` + `--since`).
21. Reconcile this report with the 2026-08-21 brutal self-review item (mark it resolved-with-corrections — the "not fatal" claim was wrong).
22. AGENTS.md: after dbPath fix, add the forgejo mirror gotcha entry (dead queue after hard freeze; TouchMirror masking; restart heals).
23. Investigate WHY `os.CreateTemp` ENOENT'd mid-process (systemd-tmpfiles /tmp cleanup? tmpfs eviction? namespace remount?) — only if it recurs; currently silent since 08-21.
24. Check `forgejo-backup` (03:30 dump) ran during the outage window — DB-consistent but confirm zips exist for 08-21/08-22.
25. Review whether `mirror.MIN_INTERVAL=10m` + 30m cron can starve under PULL_LIMIT=50 with 134 mirrors (134 > 50/cycle → 3 cycles per full round; with 8h intervals fine, but verify during catch-up storms).
26. Consider Discord alerting on `system_forgejo_mirror_last_sync_age_seconds` crossing 10h DURING catch-up (first post-fix sync was 30m late — age was ~9.5h at recovery, just under threshold; fine).

## g) QUESTIONS (cannot resolve myself)

1. **DB path (blocks P0 #1):** My shell has no sudo. Please run `sudo grep -A6 '^\[database\]' /var/lib/forgejo/custom/conf/app.ini` and tell me the `PATH` value — or confirm I should make the collector auto-try `data/forgejo.db` + `data/gitea.db` + the app.ini-parsed path without you running anything.
2. **Upstream filing:** File the three forgejo issues (dead queue silence, TouchMirror masking, ENOENT aborts) on Codeberg under your account? I have verified source-level evidence for all three but need your go-ahead + account context (per verify-before-filing, outbound).
3. **The 8 smoke failures:** Want me to enumerate and triage all of them right now (next session runs `nix run .#post-deploy-check` ~2–8 min, fastflowlm probe may cold-load the 21.6 GB model), or only the Mirror Sync one and leave the rest?

---

### Verification evidence trail (this session)

| Claim                    | Evidence                                                                                                                                                                         |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mirrors dead 21:55→07:16 | API `mirror_updated` frozen at `2026-08-21T21:55:58` (two repos), zero `SyncMirrors`/`Mirror.runSync` processes in 60s watch, `mirror_updated: 2026-08-22T07:16:37` post-restart |
| Error timeline           | journal counts/day: 855 (08-18), 2400, 2400, 900 (08-21 until 00:28); `not allowed` 100 lines 08-21 19:35–20:35                                                                  |
| Same binary throughout   | process cmdline `…-forgejo-lts-15.0.6/bin/forgejo web` all boots; version banner 15.0.6                                                                                          |
| TouchMirror-on-failure   | v15.0.6 `services/mirror/mirror_pull.go` `SyncPullMirror`: `if !ok { TouchMirror…; return false }` (fetched from tag v15.0.6)                                                    |
| Queue dedup silence      | v15.0.6 `services/mirror/mirror.go` `ErrAlreadyInQueue` → `log.Trace`; queue is `CreateUniqueQueue`                                                                              |
| OIDC boot failure        | journal 05:55:52 `Unable to register source: PocketID … lookup auth.home.lan: no such host`; post-fix 06:46:29 clean start behind `forgejo-wait-dns`                             |
| Gate wiring              | `nix eval …forgejo.serviceConfig.ExecStartPre` includes `forgejo-wait-dns`; `after` includes caddy/pocket-id/dnsblockd/network-online                                            |
| Metrics deployed         | `system_health.prom` (08:52) carries `system_forgejo_mirror_scrape_errors 1` (the known-bad path)                                                                                |
| Gatus check live         | journal 08:51:30 `endpoint=Forgejo Mirror Sync … success=false` (67ms — it evaluates, red on scrape_errors)                                                                      |
| Checks/lints             | `nix flake check --no-build` pass; toplevel build ×3 pass; `gatus-pattern-lint` build pass; pre-deploy-check 84 pass/0 fail (final run)                                          |
