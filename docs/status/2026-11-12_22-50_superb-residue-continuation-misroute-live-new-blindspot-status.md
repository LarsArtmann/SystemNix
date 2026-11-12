# SUPERB Residue Continuation — Misroute Live, New Send-Path Blind Spot, Batch v1 Failed Clean

**Created:** 2026-11-12 22:50 CET
**Executor:** the residue-execution session (continuation of the 11-40 plan, after `docs/status/2026-11-11_14-10_…`)
**Owner inputs this leg:** G-RESEND "idk what you're talking about" (→ explained below), R7 = "not now" (→ watch row), G2 artifacts = **keep**.

## Headline

**M1 is fully CLOSED** (verified live through the later float `76f8e41`: misroute
wave ancestor-checked, `cv misroute`/`cv claims` render on the deployed binary,
anchor system-1004 == newest, Monitor365's exit-3 flag re-probed UP). **But the
funnel is actively self-harming**: Resend is STILL 550-unverified (owner did not
know — explained in-chat), and the 2026-11-12 auto-apply fires proved a NEW
send-path blind spot — three real-recipient sends BOUNCED at the relay yet
recorded `application.sent{success}` (the client-250-as-verdict class, d.1 not
yet encoded in CV's send path), burning three real recruiter pairs in the
at-most-once ledger. Protective stop of `cv-scan.timer` landed (next 00:23 fire
would burn more). The R3 batch then executed and **failed 536/536 CLEAN** (zero
writes): the CLI invoked as the agent user cannot resolve the event store
(`Claims needs the persisted event store; set pipeline.event_store_driver=sqlite
and event_store_dsn in config.yaml`) — the runbook's recipe assumed the
server-user config resolution; needs an explicit DSN/config path per invocation.

## a) Fully done (verified)

1. **M1 CLOSED end-to-end**: anchor OK (current == newest == system-1004, tree
   drained); live cv binary = `cv-76f8e41` (deriver + path), `def2cd74e` (the
   misroute wave) verified ANCESTOR of it; `cv misroute --help` and `cv claims`
   smoke-render on the deployed binary (22:01).
2. **M1.8**: `docs/services/cv.md` live-state breadcrumb committed (misroute
   live via 7c81dc944→76f8e41, shim kJ19EtgX, RE-ENUMERATE-before-batch rule).
3. **Monitor365 exit-3 flag CLOSED**: :3001 answers (308 redirect, listener
   live) — the deploy's "NEW smoke failure" was the stale-by-read-time class.
4. **R7 owner decision encoded**: watch row in `docs/todo/stability.md`
   (WARN-and-pass classifier deferred; evidence ×2 preserved).
5. **R3.1/3.2 re-verified on a FRESH live snapshot** (22:0x): still exactly
   **536 catchall rows / 1225 sends / zero overlap** with now-62 real-recipient
   apps; +28 new approvals, +3 sends, 3 `send.claimed`, **zero** misroutes yet.
   The batch list is stable and current (`catchall-rows-fresh.json`).
6. **Protective stop: `cv-scan.timer`** (inactive as of 22:0x) — its 6-hourly
   auto-apply leg is the pair-burning engine while Resend is dead (next fire
   00:23 prevented). cv-server itself untouched/active.
7. **New-bug row landed** (`5b8648ab1`, `docs/todo/upstream.md`): the CV send
   path records success on relay-bounced sends — full journal evidence (three
   recipients + timestamps) + fix class (async verdict: bounce-DSN ingestion or
   Resend send-status check; client 250 = local acceptance only).

## b) Partially done

1. **R3.3 batch v1**: ran the 536-row loop with the lease discipline (stop
   cv-server → loop → restart; trap worked, server active again) — **all 536
   failed on the SAME clean error** (store-config resolution, zero writes, no
   partial state). Fix is mechanical (run as the cv service user with its
   config/env, or pass the store DSN explicitly); NOT yet diagnosed to the
   working invocation. The 3 non-delivery misroutes (app-9802 →
   pauli.ojala@getstream.io, app-9839 → jobs@dutc.io, app-9871 →
   careers@proofline.sh, journal-mapped) are staged but not run.
2. **R5 landing**: drafts remain proven-but-unlanded (18/18 selftest); next
   natural deploy carries them.

## c) Not started

R2 (G-RESEND-gated), R3.4–R3.6, R4.2/4.3 (after R3), R6 (after R3), R9.2
(portalapply sibling still uncommitted in the CV tree), R8 closeout.

## d) Totally fucked up

1. **Fired the 536-row batch without a 1-row dry-run** — a single probe misroute
   would have surfaced the store-config error in seconds; instead I paid a full
   cv-server stop/start window for 536 identical clean failures. No data damage
   (the verb errored pre-store), but the dry-run-first discipline for ANY
   batch-mutation is now written down here as the lesson.
2. **The runbook recipe's store-direct assumption was never live-tested** — the
   `cv claims` recipe (and my batch) assumed the CLI resolves the sqlite store;
   agent-user invocation does not. The recipe needs the working invocation
   appended (this is also why my earlier `cv claims` smoke "worked": it listed
   an EMPTY store view, not the live one — the rehydration counts (events=7435)
   I read as a store census were a PARTIAL/different fold. Corrected
   interpretation: the real store census comes from the sqlite snapshot, which
   I did have right).
3. **My pathspec commit was gate-blocked once** (TODO title format) while the
   daemon carried the files anyway — benign, noted for the pattern.
4. Prior-report items stand: pipe-masked rc (a.1 there), anchor-started-pre-
   drain, `rg -rn` block.

## e) Improvements

1. **Batch-mutation dry-run rule**: any loop that mutates prod state ≥10 rows
   runs row 1 alone first, inspects, then continues. (This session paid for it.)
2. **The new blind spot is the third instance of the same class** (d.1 client
   250; my `cv claims` empty-store read; the send-path success-on-bounce) —
   "assert WHICH entity served the evidence" needs a send-path codification,
   rowed in upstream.md.
3. **cv-scan.timer auto-apply needs a mail-path health gate**: the sweep should
   refuse to fire sends while the relay verdict is bouncing (the R5 collector's
   `node_mail_relay_bounce_over_threshold` is exactly the signal a future
   auto-apply gate could consume — synergy worth rowing when R5 lands).

## f) Next (ordered)

1. [S] Diagnose the working misroute invocation (sudo -u cv with service env /
   explicit DSN) → 1-row dry-run → verify the correction event in a fresh
   snapshot.
2. [M] R3.3 v2: the 536-row batch + the 3 non-delivery misroutes (evidence
   notes from the journal) → R3.4 rehydration verify (statuses→ready, pairs
   vacated, notes stamped).
3. [S] R5 landing (collector+module+rule+selftest) on the next deploy.
4. [S] G-RESEND: owner acts in the Resend dashboard (explained in-chat) → R1
   journal-verdict tick + R2 idempotency pair + restart `cv-scan.timer`.
5. [S] R4.2/4.3 held-queue release (after R3). [S] R6 dashboard verify.
6. [S] R9.2 CV-side flags once the portalapply sibling lands. [M] R8 closeout
   (01-10 tombstone EXECUTED, CHANGELOG, reconciliation; artifacts KEPT per
   owner).

## g) Owner questions

1. **Resend re-verify**: now that the failure mode is explained — will you do
   the dashboard re-verify (resend.com → Domains → artmann.tech), or is there a
   Resend API key in sops you want me to probe an agent-side verification path
   with? Every hour it stays unverified, the funnel stays dark (and the timer
   stays stopped).

**Live state at authoring (22:50):** cv-server active; cv-scan.timer STOPPED
(protective); anchor system-1004; Resend still bouncing (18:23 evidence);
R3 batch artifacts current in `~/.cache/send-hardening/r3/`.
