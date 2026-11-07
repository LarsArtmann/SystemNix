# OpenCloud auth fix — full session status, retrospective, and next-work roadmap

**Timestamp:** 2026-11-03 20:39 CET · **Session window:** ~19:35–20:39 CET · **Instance:** opencloud-auth-fix session (single agent)
**Companion report:** docs/status/2026-11-03_20-15_opencloud-idm-bootstrap-empty-tree-auth-fix-session.md (the fix narrative + evidence chain; this report is the comprehensive retrospective the owner requested — sections a–g).
**Trigger:** owner: "OpenCloud auth fix!" — later expanded: full status + what was forgotten / could be better / what's next.

**Live state at write time:** opencloud ACTIVE (restarted 20:04:55, zero restarts since), IDM tree re-seeded (`idm.boltdb` 65536 bytes, DN-proof green: `uid={admin,idp,libregraph,reva}` + `ou=users`/`ou=groups`), vHost 200, webfinger 200, **0 error-level journal lines since 20:05, 0 auth-class errors**. Anchor untouched (operational fix — no deploy, no toplevel change). Commit `5cdbb2cf3` (my docs) landed 20:12:54 with hooks green; the daemon's `89b1d9733` carries my three swept doc files TOGETHER with a parallel session's files (selftests.nix + sops scripts — flagged, not absorbed).

---

## a) FULLY DONE

1. **Session-start discipline** — status/todo pre-read, git content-pin, parallel-session check (pgrep for deploy processes, `git log --since`), BEFORE any diagnosis. Found no co-session owning opencloud.
2. **Root-cause diagnosis with a complete evidence chain** — journal signature (idm binds `uid=reva`/`uid=libregraph,ou=sysusers,o=libregraph-idm` → "not found" → graph 49 → proxy 500 `Autoprovisioning user failed`); these 19:45 attempts are the ONLY autoprovision attempts EVER (first login = first discovery, breakage since the Oct 26 pilot deploy); elevated secret-safe state inspection (`idm.boltdb` since Oct 26 12:22, exactly 32768 bytes = empty buckets; yaml untouched since init); upstream source reading (opencloud v7.2.4 `services/idm/pkg/command/server.go` + libregraph/idm v0.5.0 `boltdb.go`/`ldbbolt.go`/`server.go`): bootstrap runs only when the DB file is absent, `bolt.Open` creates the file BEFORE seeding, bootstrap failure is logged-then-ignored → permanent empty-but-present tree.
3. **Negative-path elimination** — Pocket ID groups/roles (no `no roles` ever), CSP/TLS/port layers (fixed 2026-11-02), yaml secrets (never read values; key NAMES only confirmed `idm.service_user_passwords` + `admin_user_id` present).
4. **The operational fix** — quarantined the empty DB as `idm.boltdb.broken-20261103-bootstrap-skipped-empty-tree` (evidence kept, mirrors the trap-#10 bleve pattern), restarted, bootstrap re-ran from the unchanged yaml (passwords symmetric — seed hashes what graph/proxy bind with). Zero data loss (pure config-derived seed data; no user ever created). No deploy needed.
5. **Verification to the last agent-reachable hop** — new DB 65536 bytes 2 s after start; DN-string proof of the full seeded tree; 0 error-level lines; 0 auth-class errors; all listeners up (9500/9100/9233/9234/9236/9239); vHost 200 + webfinger 200 via the CORRECT bind IP (192.168.1.150, resolved from `ss -ltn` after my first guessed-IP probe came back empty).
6. **Paperwork, no drift** — runbook trap **#13** (bootstrap-skip-forever class: signature, mechanism, fix, evidence paths, "strings the DB FIRST" instruction), IDM-tree sanity verify recipe, owner-hands first-login note; `[watch]` first-login-confirm row + `[ready]` upstream verify-and-file row in docs/todo/services.md with the matching TODO_LIST queue one-liner; status report (20-15); CHANGELOG entry. `scripts/check-todo-system.sh`: "TODO queue/library structure clean" (my rows; the 173 unharvested-§f WARNs are other sessions', pre-existing).
7. **Commit discipline under the daemon race** — the daemon swept my three doc files TOGETHER with a parallel session's files into `89b1d9733`; I did NOT amend (that would absorb their mid-flight work into my rewritten commit — the 2026-09-14 class), landed on top with a PATHSPEC commit `5cdbb2cf3` for my remaining files; hooks green.
8. **Parallel-session attribution** — flagged foreign working-tree files immediately (selftests.nix, sops scripts), left them untouched; new parallel edits appearing during my commit window were likewise not touched.
9. **Script hygiene** — all intermediates under `~/.cache/opencloud-auth-fix/` (the /tmp-is-volatile doctrine), scripts print NO secret values (key-name-only yaml access, DN-shaped strings only).

## b) PARTIALLY DONE

1. **End-to-end login verdict** — every link in the auth chain is verified EXCEPT the final hop: the browser passkey login that produces a real autoprovision attempt. That is the owner's action (agent cannot perform an OIDC passkey login). Queued `[watch]`; the runbook owner-hands note names it the final auth verification.
2. **Why the ORIGINAL Oct 26 bootstrap failed** — the failure MECHANISM is proven (upstream code), but the first-failure TRIGGER is unknown: journald retention does not reach Oct 26, and I did NOT exhaust the archived-journal path (`ls /var/log/journal/<machine-id>/` raw `.journal` files) before declaring it unrecoverable — recorded as improvement e.4, one-time forensic pass queued in §f.
3. **jq/direnv doctrine** — this session the stdin form ALSO returned null (AGENTS.md says stdin forms still work); I worked around via `env -u DIRENV_DIFF` but did not run the clean A/B (with/without DIRENV_DIFF, same command) to pin the doctrine change. Observation recorded in the 20-15 report §e.4; AGENTS.md not touched.
4. **18:37 deploy exit-3 smoke failures** — established the exit was I/O PSI (storm class, NOT opencloud), but did not enumerate ALL flagged smoke checks; a fuller read of that deploy log would confirm nothing else regressed tonight.
5. **Runtime guard against the poisoned-tree class** — I have the IDEA (ExecStartPost probe: `strings` the DB for sysusers DNs, fail the unit loudly on an empty tree) but did not implement it (deliberate: an ops fix with no deploy; the idea is queued in §f for an owner decision).
6. **gatus posture after the fix** — I probed manually (openssl) but did not query gatus state; the liveness check should be green, the webfinger body-pat check is known-red by WRONG PREMISE (services.md:670, probed against the live response 2026-11-02) — separate concern, deliberately untouched.

## c) NOT STARTED

1. **Upstream issue filing** (opencloud-eu/opencloud) — row queued `[ready]`, work not started; gated on verify-before-filing (scratch reproduction of the poisoned-tree mechanism) + github-voice.
2. **FEATURES.md opencloud status touch** — the 2026-11-02 sessions queued "UI now reachable — one status touch"; tonight's "auth functional" state belongs in the same touch. Not done by me.
3. **TODO_LIST.md:1714 twice-stale opencloud leg** ("deploying this session" wording, flagged by TWO earlier 2026-11-02 reports) — I edited TODO_LIST.md THIS session and still did not fix that row. Fix-on-sight miss.
4. **ExecStartPost IDM-seed assertion** (see b.5) — not started, needs a deploy.
5. **Correct-premise gatus check for the login path** — the existing webfinger pat check asserts a body string the live response does not contain; replacing/fixing it (and possibly adding a graph-health probe) is not started.
6. **OIDC client dedup** (services.md:700 — "web" provisioned twice per run), **ocis port-env eval guard** (services.md:672), **pilot-adoption [decision] row** (services.md:630) — pre-existing opencloud surface rows, all untouched this session (deliberate scope).

## d) TOTALLY FUCKED UP

Honest ledger — nothing was destroyed and the service never went down unexpectedly, but four real missteps:

1. **Unprivileged script execution ×2** — both my inspect AND fix scripts initially lacked the self-elevation guard (`exec sudo bash "$0"`); the first fix attempt died on `systemctl restart` access-denied and the inspections returned Permission-denied artifacts. The boot-mirror self-elevation precedent is documented in AGENTS.md — I should have written the guard FIRST, every time. Two wasted round trips, one of them on a production mutation path (the mutation aborted safely; rollback guard did not even engage).
2. **Guessed the LAN IP for the vHost probe** (192.168.1.20 → empty output) — the AGENTS.md session-discipline section documents the empty-output failure signature AND the LAN-IP requirement; I knew the rule and still typed a guessed address. One wasted probe. "No URL guessing" applies to IPs too.
3. **jq stdin-form misread** — the flake.lock introspection returned nulls that I first interpreted as "nonstandard lock structure" and burned extra probes on, when the known direnv trap was the simpler explanation; only the `env -u DIRENV_DIFF` retry resolved it. Cost: ~2 probes and a moment of wrong-model reasoning.
4. **Deploy-window judgment call** — I restarted opencloud at PSI ~42% (storm ongoing) rather than waiting; it went clean (TimeoutStartSec 5min headroom, sub-second effective start), but under the owner's fresh PSI deploy policy this risk class deserves an explicit wait-or-proceed decision. Turned out fine; would repeat only with a stated reason.

No reverts, no destroyed work, no service downtime beyond the one designed ~seconds restart, no secret exposure (values never read or printed; the `monitor365` argv-secret class does not apply to opencloud's processes).

## e) WHAT WE SHOULD IMPROVE

1. **Script template discipline: elevation guard FIRST.** Every ops script starts with `if [ "$(id -u)" != 0 ]; then exec sudo bash "$0"; fi` — write it before the body, not after the first Permission-denied. Consider a `scripts/lib/self-elevate.sh` or a template comment in docs/CONTRIBUTING.md.
2. **Pre-run read-back.** A 5-second read of a just-written script before executing it would have caught both missing guards (the edit-before-read rule applies to my own scripts too).
3. **Resolve probe targets from live state, never from memory** — `ss -ltn` for bind IPs before any openssl probe; the AGENTS.md rule documents the failure signature, the fix is to make resolution a reflex.
4. **Exhaust archived journals before "unrecoverable"** — `journalctl` retention != raw `.journal` file availability; a `ls /var/log/journal/<machine-id>/` sweep should precede any "evidence gone" claim.
5. **Runtime assertion for derived-state seeding** — any service whose state is config-derived-but-write-once (IDM tree, bleve) deserves a post-start health probe that fails loudly on an empty tree; journal silence masks this class (trap #10 + #13 are siblings).
6. **Doctrine updates need A/B proof** — the jq anomaly should be pinned with a same-command with/without `DIRENV_DIFF` pair before editing the AGENTS.md doctrine line.
7. **Fix-on-sight applies to files I am already editing** — TODO_LIST.md:1714 was under my cursor; still skipped. The two-line-fix rule (owner-granted 2026-09-06) covers this.
8. **Watch rows need a named verifier** — the `[watch]` login-confirm row is owner-gated; pairing it with a concrete "if 500 then strings-the-DB" instruction (done) makes it actionable by ANY session, which is the right pattern — generalize it.
9. **Status-report §f proposals convention** — this report's §f list follows the 2026-11-02 v1 precedent: proposals are NOT auto-harvested into the queue; the owner picks. Only the session's DIRECT follow-ups were harvested (done in the 20-15 report).

## f) NEXT WORK (proposals — NOT auto-harvested; owner picks)

OpenCloud direct follow-ups (1–10):

1. **Owner: retry the browser login** at `https://cloud.home.lan` — the final auth verdict; on success close the `[watch]` row.
2. **Close-out paperwork after login works** — close the watch row, update FEATURES.md opencloud line (UI reachable + auth functional), update the pilot-adoption decision row (services.md:630) with the new facts.
3. **Upstream verify-and-file** — reproduce the poisoned-tree mechanism in a scratch/VM test (sabotage the seed, restart, observe the permanent skip), then file with fix suggestion (seed on empty DB / make bootstrap failure fatal); gates: verify-before-filing, github-voice. (Row already queued.)
4. **ExecStartPost IDM-seed assertion** in opencloud.nix — probe `strings <stateDir>/idm/idm.boltdb` for `ou=sysusers` DNs post-start; fail the unit loudly on an empty tree (needs a deploy; also covers trap #10's silent-derived-data class for THIS service).
5. **Fix the wrong-premise gatus webfinger check** (services.md:670) — the `*oidc-callback*` pat does not match the live body; rewrite the condition against the actual response (issuer link assertion) or drop the body condition.
6. **Identify the HTTP-to-NATS prober** — journal shows `Client parser ERROR` with `GET /health`-style protos hitting the embedded NATS (9233/9234) at 16:33/17:56 today; some check probes NATS ports with HTTP — find who and re-point (selftestable premise: grep gatus/Caddy config for those ports).
7. **Forensic pass on archived journals** for the Oct 26 bootstrap-failure trigger (raw `.journal` files; one-time; may close the "unknown trigger" gap in trap #13).
8. **Silence the benign NATS reconnect noise** — `storage-users` logs `Disconnected from NATS` error-level on every restart (seen 16:12/18:55 today); the dnsblockd 4318 `LogFilterPatterns` precedent applies if this buries signal.
9. **Rehome the session's ops scripts** (`~/.cache/opencloud-auth-fix/{inspect-idm,prove-seed,fix-idm}.sh`) into `scripts/` with root guards if the IDM-tree probe becomes a standing tool (else let the cache expire).
10. **Verify btrbk actually snapshots `services/opencloud`** — runbook says the roster covers it; confirm one real snapshot exists post-Oct-26 (and that tonight's snapshot will include the quarantine evidence file).

Adjacent opencloud surface rows, untouched this session (11–15):

11. **OIDC client dedup** — the provisioner mints "OpenCloud Web" twice (registry entry + extraOidcClients); keep one side (services.md:700).
12. **ocis port-behavior env-class eval guard** (services.md:672) — pin `PROXY_HTTP_ADDR` honored / `NATS_PORT` ignored / web-9100 compiled-in at eval time.
13. **Verify services.md:657 resolution** — the pocket-id-provision "Failed to generate secret for 'OpenCloud Web'" row: the client is public (no secret) — check whether the provision failure is actually gone on current gens and close the row if moot.
14. **Desktop client pairing + Android client** (owner-hands items in the runbook) — now meaningfully unblocked since auth works.
15. **boot-time suture posture** — opencloud restarts under boot contention (2026-11-02 class); check startLimit/MemoryMax posture once the storm discipline lands.

Session-hygiene improvements (16–20):

16. **Add the self-elevation guard pattern to docs/CONTRIBUTING.md** as a mandated script template line (from e.1).
17. **Pin the jq/direnv anomaly with an A/B** and correct the AGENTS.md doctrine line (from b.3).
18. **Fix TODO_LIST.md:1714's twice-stale opencloud leg** (from c.3).
19. **Enumerate the 18:37 deploy's full smoke-failure list** (from b.4) and confirm nothing else regressed tonight.
20. **Record the opencloud argv surface in the redact-argv matrix** if any opencloud process ever carries secrets on argv (checked this session: it does not — keep it that way; one-line note in the redactor selftest fixtures if extended).

Pre-existing queue items I touched the periphery of, worth re-prioritizing after login confirmation (21–24):

21. **PSI deploy policy encoding** (pipeline.md:596, owner directive 2026-10-27) — every ops-with-deploy decision tonight bumped against this gap.
22. **Deploy-quiescence productization** (pipeline.md:592) — tonight's restart rode no deploy; the next opencloud module change will.
23. **Daemon float-split guard** (pipeline.md:595) — flake.lock float commits appeared again tonight (b92853884).
24. **doc-counts anchor duality** (pipeline.md:602/603) — the CHANGELOG+README count anchors will bite whoever next re-stamps counts after tonight's CHANGELOG edit.

Longer-arc (25–30):

25. **Generalize "derived-state write-once" audit** — sweep services for config-seeded-once stores (IDM-like) and check each has either re-seed-on-empty or a loud post-start probe (trap #13 generalizes beyond opencloud).
26. **LogFilterPatterns fleet audit** — dnsblockd got it, opencloud could; sweep for other noisy error-level repeat lines that bury signal.
27. **Session-discipline doctrine: "operational fixes need no deploy — but DO need paperwork + a runtime guard proposal"** — tonight worked well; codify the shape.
28. **Retain policy for quarantine evidence files** — `*.broken-*` siblings (bleve 2026-10-27, idm 2026-11-03) live on snapshot-rostered subvols; define a reclaim age (e.g., 90d) in the runbooks.
29. **opencloud login-path monitoring** — SigNoz rule on `Autoprovisioning user failed` (the error that hid for 8 days); an alert would have surfaced it day one.
30. **Consider OC_LOG_LEVEL posture** — bootstrap failures log at Error (good); the seeding line is Debug (invisible); a one-time debug-level start during the upstream reproduction would capture the full seed trace.

## g) QUESTIONS (cannot answer myself)

1. **Was the 19:45 login attempt yours, and is "auth fix" = that browser-login 500?** The journal proves the attempts but not the human; if you meant a DIFFERENT auth symptom (desktop client? a different vHost?), my fix targeted the wrong surface and I need to know now.
2. **Please retry the login now** (`https://cloud.home.lan`, Pocket ID passkey) — did it complete, and does your user appear? This is the single unverified hop; your answer closes the watch row or re-opens the diagnosis (the runbook trap #13 signature check applies if it 500s again).
3. **Hardening appetite: land the ExecStartPost IDM-seed assertion + corrected gatus check as a deploy NOW, or hold?** Tonight's storm is at the monitor365 ~10-min trip cadence and the PSI deploy policy row (avg2/80%) is still unlanded — I cannot decide the deploy-timing tradeoff for you.

---

**Stopping point:** per instruction — reporting and WAITING. No further actions taken after this file.

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** already-tracked f.1 f.2 f.5 f.11-14 f.17 f.18 f.19 f.21 f.22 f.23 f.24 · NEW rowed: 14 rows → services 9, storage 2, pipeline 2, upstream 1, monitoring 1; f.18/f.20 merged into 14-48 rows
