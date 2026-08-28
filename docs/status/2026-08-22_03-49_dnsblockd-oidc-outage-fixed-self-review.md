# dnsblockd OIDC Outage — Resolution & Brutal Self-Review

**Date:** 2026-08-22 03:49 CEST · **Host:** evo-x2 · **Scope:** this session only
**Incident window:** 2026-08-22 00:27 (kernel freeze) → 03:42 (service restored)
**Session outcome:** dnsblockd SSO chain repaired and verified to the HTTP layer; time bomb removed; deploy gap fixed systemically. **Real passkey login NOT yet confirmed** (cannot be self-tested).

---

## Timeline (what actually happened)

| Time          | Event                                                                                                                                                          |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 00:27         | Kernel freeze (zram 100%, flm unevictable — prior incident)                                                                                                    |
| 00:32 / 00:48 | Crash-recovery boots; provisioner re-created dnsblockd client; stale-secret desync (prior session's diagnosis)                                                 |
| 02:23         | User login fails `invalid_client` at token exchange (secret desync — original diagnosis correct AT THIS TIME)                                                  |
| 02:37–02:40   | Pocket ID fatal `SQLITE_BUSY` chain → exit 1                                                                                                                   |
| 02:42         | Pocket ID restarts — **dnsblockd client row has VANISHED from the DB** (new, second failure class)                                                             |
| 02:51 / 02:55 | User sees "The requested OAuth 2.0 Client does not exist"                                                                                                      |
| ~02:5x        | User "deploys" the prior session's fix — **no generation is ever created; nothing activates**                                                                  |
| 02:58         | This session starts; finds gen 694 (Aug 20) is still latest → user's deploy never ran                                                                          |
| 03:02         | My deploy #1: provisioner re-creates client (201) + force-regenerates secret. **Login still broken** — bridge + daemon never restarted                         |
| 03:05–03:15   | Root-cause the delivery gap (`is-enabled` rc=1 for indirect units + `EnvironmentFile` read at start only); fix `deploy.sh`; remove `regenerateSecretsFor` flag |
| 03:13–03:27   | Deploys blocked: concurrent session's mid-edit `signoz.nix` syntax error (polled until it parsed; did not touch their file)                                    |
| 03:40         | Deploy #2: flag cleared (provisioner: "Secret file already exists" — stable), restart chain executes                                                           |
| 03:42:04      | `dnsblockd-oidc-secret` writes fresh secret → `dnsblockd` restarts after it                                                                                    |
| 03:44–03:49   | Verified: `/authorize` → `302 /interaction` (client recognized); 0 OIDC errors in dnsblockd journal; DNS + :9090 healthy                                       |

---

## a) FULLY DONE

1. **Diagnosed the second failure class** — Pocket ID's 02:40 SQLITE_BUSY crash destroyed the dnsblockd client row; "Client does not exist" ≠ the secret desync the prior session had diagnosed. Distinguished via journal forensics + manual `/authorize` probe.
2. **Deploy #1 (03:02)** — provisioner re-created the client (HTTP 201) and force-regenerated the secret via `regenerateSecretsFor`.
3. **Root-caused the delivery gap** — a rotated secret never reaches the daemon: `dnsblockd-oidc-secret` is `RemainAfterExit=true` + `wantedBy=dnsblockd.service` → `is-enabled` returns rc=1 ("indirect") → silently skipped by deploy.sh's provisioner loop; and `dnsblockd.service` reads its `EnvironmentFile` only at process start.
4. **Fixed `scripts/deploy.sh`** — dedicated is-active-gated block restarting bridge → daemon in order (mirrors the browser-history pattern), with a comment explaining the indirect-unit trap.
5. **Removed the `regenerateSecretsFor = ["dnsblockd"]` time bomb** — verified eval returns `[ ]`; provisioner confirmed stable ("Secret file already exists") on deploy #2.
6. **Deploy #2 (03:40)** — restart chain executed 03:42:04; secret bridged; daemon restarted after.
7. **Verified to the HTTP layer** — `/authorize?client_id=dnsblockd` → `302 /interaction` (was error-redirect); 0 `invalid_client`/OIDC errors in dnsblockd journal since restart; DNS resolution + dashboard :9090 + memory all green.
8. **Docs** — two new AGENTS.md gotchas (secret-bridge restart chain; client-row-vanish class) + resolution addendum appended to `docs/status/2026-08-22_02-46_dnsblockd-oidc-secret-desync-diagnosis.md`.
9. **Concurrent-session hygiene** — detected the other session's mid-edit `signoz.nix` breakage, re-read before every edit, never touched their files, waited out the 15-min eval block instead of "fixing" their file.

## b) PARTIALLY DONE

1. **End-to-end login verification** — authorize step + secret chain proven; the **actual passkey login incl. token exchange** (where the original 02:23 `invalid_client` fired) is NOT proven. Requires the user's passkey. Stated in my final message but "Done" was overconfident.
2. **Other OIDC clients' secret validity** — oauth2-proxy PROVEN valid (auth-gateway checks green across logs/tasks/daily/manifest); browser-history server up with "OAuth2 providers configured" (validity untested); **forgejo, gatus, immich, monitor365 untested** since the DB trauma. The DB lost at least one row; what else it lost is unknown.
3. **Crash collateral triage** — identified `/mnt/pool` unmounted (DAS USB drop) as the cause of the Immich/Paperless/bank-sync/Attic/attic-cache-502 smoke failures; correctly fenced off as physical/user action. Not followed up (out of scope, correctly).

## c) NOT STARTED

1. **Functional OIDC monitoring** — the entire outage was invisible to Gatus (dnsblockd liveness stayed green while login was broken; Pocket ID stayed green through the 02:40 crash and the client vanish). No `/authorize`-style functional check exists anywhere. I fixed the bug and added **zero** new coverage before declaring done.
2. **Provisioner convergence timer** — provisioner only runs at boot/deploy; a periodic run would self-heal a vanished client within hours.
3. **deploy.sh generalization** — the `is-enabled` indirect-unit trap is structural; I special-cased dnsblockd instead of fixing the loop.
4. **Pocket ID durability work** — SQLITE_BUSY-under-IO-pressure is a recurring crash class (discordsync collateral documented earlier); tonight it turned fatal and destroyed data. No mitigation, no forensics.
5. **Secret-file PathChanged auto-re-bridge** — would remove deploy.sh from the critical path entirely.
6. **TODO_LIST.md harvest** of this report's section (f).
7. **Verification that `data-to-pool-migration` / `activitywatch-data-to-pool` skipped cleanly** on a pool-absent deploy (deploy.sh starts them every time; self-neutralizing conditions _should_ hold — unconfirmed tonight).

## d) TOTALLY FUCKED UP

1. **The premise "we deployed the fix" was false.** The prior session wrote the flag and stopped; the user ran a deploy that **never created a generation** (gen 694 from Aug 20 was still latest at 02:58). Nobody verified activation. The user waited on a fix that did not exist on the machine, then got a WORSE error and reasonably lost trust. Deploy success was never verified by the thing that claimed it.
2. **My `configuration.nix` edit sequence was sloppy.** A newline-only no-op edit (raced by a concurrent modification), then a mangled `};      oauth2-proxy-config` line — three edits and a re-read for a four-line deletion, mid-incident.
3. **Restore-first was mildly violated.** From 03:05 (correct secret on disk) to 03:42 (daemon restarted) login stayed broken ~37 min: ~15 blocked by the concurrent session's broken file (unavoidable), ~12 by bundling flag-removal into the same deploy instead of restoring first and cleaning up later. Defensible on an IO-pressured box; still the wrong priority order during a user-facing outage.
4. **I fixed a silently-broken auth path and left it silently unmonitored.** The exact blindness that let this run for hours (user discovery, not alerting) remains in place after my "resolution". Biggest miss of the session.
5. **Prior diagnosis was stale on arrival** (not mine, but I inherited and initially reasoned from it): context said "secret desync"; reality had escalated to client-vanish. Caught on first evidence pull — but the lesson stands: re-verify before treating any prior report as current truth.

## e) WHAT WE SHOULD IMPROVE

1. **Every auth/OIDC bug fix ships with a functional probe** (Gatus or post-deploy smoke) in the same change — otherwise it regresses silently. Liveness ≠ function.
2. **Deploy UX must surface activation truth** — print the generation delta; a user's deploy that produces no new generation should be a loud failure, not a shrug. Tonight's root trust-breaker.
3. **Generalize, don't accumulate** — deploy.sh is accreting per-service special cases (dnsblockd now joins browser-history). One indirect-unit-aware mechanism for "secret-bridge + consumer" pairs.
4. **Concurrent-session eval blocks should be reported immediately**, not discovered by the user 15 min later. I noted it only in my final message.
5. **Pocket ID's SQLite is a durability liability under IO pressure** — tonight it crashed fatally and lost data. WAL/busy-timeout verification, ioTier, and long-term Postgres migration deserve a decision.
6. **`regenerateSecretsFor` is a loaded footgun** — a flag that must be manually unset or it rotates secrets on every provision run. Consider self-neutralizing semantics or a loud warning after first fire.
7. **Incident reflexes**: on any user-reported "I did X and it still fails", verify X happened (generations, units, files) before theorizing. Worked tonight — keep it as reflex.

## f) NEXT — up to 50, ordered by priority

**P0 — verify & stabilize (today)**

1. [user] Log into `https://dnsblock.home.lan` with passkey — confirm token exchange end-to-end
2. [user] Reseat DAS USB cable/power + clean reboot → `/mnt/pool` back (clears Immich, Paperless, bank-sync, Attic, attic-cache 502s)
3. After pool return: verify `atticd-bootstrap`, `btrfs-verify-pool-backups` recover; `reset-failed` the bootstrap unit
4. After pool return: Immich (incl. OIDC secret validity), Paperless, bank-sync health passes
5. [other session] Finish ClickHouse XFS migration — `signoz-provision` failed unit + `signoz.home.lan` 502
6. Verify `data-to-pool-migration` + `activitywatch-data-to-pool` skipped cleanly on the pool-absent deploys

**P1 — close the monitoring blind spot**
7. Gatus functional check: dnsblockd `/authorize` → 302 (catches BOTH vanish + desync classes)
8. Post-deploy smoke: same authorize probe + assert env-file mtime ≥ dnsblockd start time
9. Alert on Pocket ID fatal line `Failed to run pocket-id` (02:40 crash was silent)
10. SigNoz log rule: `invalid_client` bursts in pocket-id/dnsblockd journals — early desync detector
11. Audit whether ANY alert fired 00:27–03:00; if none, map exactly why and close each hole

**P2 — harden the secret-delivery chain**
12. Generalize deploy.sh: `is-active` fallback (or explicit bridge list) for indirect RemainAfterExit units — kill the special-cases
13. `dnsblockd-oidc-secret`: `PathChanged` on the secret file → auto re-bridge + daemon restart without deploy.sh
14. `pocket-id-provision` convergence timer (6h) — self-heal vanished clients
15. Eval-time assert: `regenerateSecretsFor` ⊆ provisioned clientIds (if not already present)
16. Make `regenerateSecretsFor` self-neutralizing or warn-loudly on consecutive fires
17. Pre-deploy-check: every unit `LoadCredential`-ing a pocket-id secret must be restart-covered in deploy.sh

**P3 — Pocket ID durability**
18. Forensics on the last pre-crash pocket-id DB backup — why did ONLY the dnsblockd row vanish (uncommitted txn loss?)
19. Audit what else 02:40 rolled back (users/webauthn/audit-log) — user+session survived, but unverified systematically
20. ioTier/MemoryMax review for pocket-id under IO storms; verify WAL mode + busy_timeout
21. Long-term decision: Pocket ID → shared Postgres (recurring SQLite-under-pressure crash class)
22. dnsblockd's own `TRACK_METRICS` SQLITE_BUSY errors (02:44) — upstream WAL/busy_timeout review

**P4 — crash-night leftovers (observed tonight)**
23. Root fs 93% / 50G free — run `nix-build-cleanup` (6 stale sandboxes); watch the GC gates
24. [standing P0] btrbk `/data` EIO inode corruption — still blocking nightly data sends
25. Kernel-freeze postmortem: did `memory-emergency-guard` trip? (zram hit 100% at 22:25 — guard exists since the freeze)
26. Verify `lan-nic-watchdog` + memory-emergency-guard healthy this boot
27. [standing] Monitor365 re-enable decision (wireguard-collector ownership)
28. [user, standing] Google-sync OAuth token still placeholder
29. [user, standing] Resend SMTP key dead → Pocket ID email broken until rotated
30. Browser-history: one real Pocket-ID login to prove its secret survived the DB trauma
31. Forgejo + Gatus OIDC login spot-checks
32. Quickshell: 1 error line in the last hour — inspect
33. Fish startup 178ms vs 41ms between smokes — transient IO or regression?
34. TODO_LIST.md harvest from this report (docs-health HARVEST)
35. Reconcile concurrent-session files once ClickHouse XFS lands; quiescent-tree `nix flake check --no-build`
36. Promote the two new AGENTS.md gotchas into `docs/gotchas-archive.md` full narratives
37. deploy.sh: print generation delta on success (kills the silent-no-activation class — tonight's d.1)
38. Consider: post-deploy smoke hard-fails above N failures (tonight it "completed" with 10 FAILs)
39. Capture deploy generation numbers in the journal/report (I did not record 695/696 tonight)
40. Re-verify dnsblockd SSO after the next reboot (proves the chain survives boot, not just deploy)

_(40 items — the honest list; nothing padded to reach 50.)_

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Can you log into `https://dnsblock.home.lan` right now with your passkey?** The authorize step and secret chain are proven; the passkey login + token exchange (where the original error fired) is the one link I cannot execute. If it fails, `journalctl -u dnsblockd --since -5min` will show `exchange failed` within seconds.
2. **When you ran the deploy yourself (before mine) — did it print an error?** No generation was created between Aug 20 04:07 and my 03:02 deploy, so it never activated. Your terminal output is the only place the failure mode lives (deploys from your shell leave no journal), and it decides whether this is a deploy-UX bug worth fixing (item 37).
3. **When will you reseat the DAS USB + reboot for `/mnt/pool`?** If it's more than a few hours out, I'd stop/disable the pool-dependent timers (btrbk-pool, attic backups, bank-sync) in the meantime to kill the failure noise — and if it's imminent, everything in P0 waits for the reboot anyway (the fix is on disk and boot-safe).

---

_Auto-commit daemon has already committed this session's code/docs work (deploy.sh, configuration.nix, AGENTS.md, diagnosis addendum); this report is the only new file. Format note: written as `.md` per explicit request — the status-report skill's HTML default was overridden._
