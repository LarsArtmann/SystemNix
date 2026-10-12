# Status Report — Email Outage Diagnosis Session

**Date:** 2026-10-12 08:30 CEST
**Session scope:** Diagnose "What is broken with e-mail?" (live probes), deliver fix map ("fixes?"), self-critique, status report. **Zero file changes made by this session.**
**Surface state at session start:** tree carried `M flake/parts/checks/selftests.nix` + `M modules/nixos/services/system-health.nix` — NOT authored here; left untouched; the auto-commit daemon swept both into `7003b433` mid-session (verified via `git log --stat`). Final tree state: clean.

---

## a) FULLY DONE

1. **Mail MX outage root state proven live** — `mail.artmann.tech` (:25 STARTTLS and :993 IMAPS) both `connection refused` via openssl from evo-x2; `dig @1.1.1.1` confirms `MX 10 mail.artmann.tech` → `46.62.241.133` with apex SPF `v=spf1 -all` + DMARC `p=reject` + `rua=dmarc@larsartmann.cloud`. Consequence: **every `@larsartmann.cloud` address is undeliverable**, and DMARC aggregate reports are sent to an address that cannot receive them. Blocker unchanged: Hetzner per-account mail-port block, owner limit request pending (gatus-config.nix:187-228 documents this as the red-by-design go-live tracker).
2. **Mail relay (postfix→Resend) health verified live** — `mailq` empty; postfix listening on `127.0.0.1:25`; 7-day journal shows **zero** `status=bounced|deferred|sent` lines and zero warnings/fatals. Relay is healthy but has sent NOTHING in ≥7 days (see §d.5: that means consumer mail paths are end-to-end unverified).
3. **InboxClean failure class reconfirmed with fresh evidence** — `/health` returned `503 {"status":"timeout"}` on 3 probes; io PSI at probe time `some avg10=48.05 avg60=46.72` (live storm) — exactly the 2026-10-10 storm-share triage class. Stronger: **`inboxclean-sync.service` FAILED at 08:20:06 today** (OnFailure triggered, 24 fail/error/deadline journal lines in 12h). Still broken, not just historical.
4. **Fix map delivered, owner-split** — Hetzner request + Stalwart go-live + sops key pastes = user; bounced-metric + upstream filings + doc notes = dispatchable agent work.
5. **Deployed-rev integrity check** — flake.lock `inboxclean` rev = `e067cb5b` AND running binary = `inboxclean-e067cb5`: lock and deployment AGREE. The 2026-10-10 close-out claim ("deployed unit ExecStart = inboxclean-171de0d") is stale — another session moved the lock forward since.

## b) PARTIALLY DONE

1. **Gatus external view** — API on :9110 returned **401 Unauthorized**; I did not complete an authenticated pull (basic-auth lives in the sops-rendered gatus-env; a runtime file-read inside a script is the sanctioned pattern and would not have violated secret rules — I under-explored, see §e.3). The two openssl port probes substituted for the "Mail MX STARTTLS"/"Mail IMAPS" checks. Remaining open: first-failure timestamps + full Mail/InboxClean group history from Gatus itself. Effort to finish: S.
2. **Pocket ID SMTP deadness claim** — reported from DOC evidence (key revoked 2026-08-18; security.md rows), then re-probed this session: 10 days of pocket-id journal show NO SMTP errors but also NO successful sends — only cron registrations and OAuth flows. Verdict: **claim unverifiable from the agent sandbox** (the sops value needs sudo-only decrypt; `sudo` is agent-banned). Also observed: pocket-id restarted 3× this morning (07:52, 08:19, 08:21 — new PIDs each time), likely a parallel session deploying; not attributed here. Effort: S with user input (§g Q3).
3. **InboxClean /health green-when-calm determination** — could not observe a calm window this session (storm continuous throughout). The [watch] escape-hatch row (services.md:323) remains the open engineering answer.

## c) NOT STARTED

All from the fix map — not started because the user asked questions, and dispatch was explicitly deferred ("WAIT FOR INSTRUCTIONS"):

| Item | Where queued | Why untouched |
|---|---|---|
| postfix `status=bounced` textfile metric + Gatus check + weekly relay canary | docs/todo/services.md:117 | [ready], not dispatched |
| InboxClean upstream: year-2611 corpus date-parse filing (verify leg first) | docs/todo/upstream.md:162 | [ready]; verify-before-filing leg (raw Date header export) not run |
| InboxClean upstream: `gmail` tag demote PATCH rejection root-cause | docs/todo/services.md:124 | [ready]; needs HTTP status capture |
| gmail-verdict-cache regression test (second /health within TTL must not re-probe) | docs/todo/services.md:325 | [ready], rides next upstream push |
| Paperless runbook mail-wiring PASS note | docs/todo/services.md:132 | [ready], trivial doc edit |
| Non-owner relay delivery probe | docs/todo/services.md:151 | gated on Resend "Verified" + user go-ahead (emails a third party) |

## d) TOTALLY FUCKED UP

1. **Inbound mail for `@larsartmann.cloud` is fully dead** (live-verified this session). Severity: every external sender to any address on the domain gets a bounce; DMARC `rua` collection black-holed; parsedmarc unit deliberately `enable = false` (flipping before the mailbox exists = exit-4 deploys). Root cause: Hetzner mail-port block + Stalwart never taken live. Mitigation: none — this is THE outage.
2. **InboxClean sync actively failing during storms** — unit FAILED 08:20:06 today; `/health` 503s at io PSI ~48%. Root cause (triaged 10-10): local storm-share + hardcoded 5-min sync budget (upstream `commands.go:397`) amplifying corpus-backup runs into total failures. Mitigation exists (deployed 8s budget + 60s verdict cache) but the amplifier is unfixed upstream.
3. **The `/health` signal itself is untrustworthy under load** — it cannot distinguish "process dead" from "disk busy", so the Gatus InboxClean checks page on storms. Design gap, not incident.
4. **Pocket ID SMTP state unknown-and-unverifiable** — either dead since 2026-08-18 (doc record) or quietly fixed; the agent sandbox cannot decrypt the sops value or send a test mail. ~65 days with zero alerting either way (the security.md rows remain the only tracker).
5. **No consumer email path is proven end-to-end** — zero sends in the postfix journal for 7+ days means forgejo notifications, paperless share-links, and cron mail have NO evidence of working (or of the 550-drain failure mode — the "Mail Relay Queue" check is blind to it, which is what services.md:117 fixes).
6. **This session's own miss** — the first answer asserted "Pocket ID SMTP is dead" from doc claims without a live probe, then repeated it in the fixes table. Session discipline exists for exactly this ("never assert a service capability from a doc claim alone"); the re-probe found the truth is *unknowable* from here, which is a different (and more honest) statement. No production impact — diagnosis only — but the claim was stated more firmly than the evidence.

## e) WHAT WE SHOULD IMPROVE

1. **Per-claim live verification** — I verified the MX claim live but carried the Pocket ID claim from docs. Fix: every service-state assertion in an answer gets its own probe (journal/config-grep/socket), not just the headline claim. Cost: one extra grep per claim.
2. **Surface anomalies when noticed, not when asked** — the deployed-rev mismatch (running `e067cb5` vs close-out text `171de0d`) was visible in the first `pgrep` output but only surfaced during report writing. Fix: anomalies observed mid-probe get reported in the same message they were observed in.
3. **Authenticated Gatus access for agent sessions** — the 401 dead-ended a whole observability layer; the creds are already on disk in the sops-rendered env. Fix: a read-only `scripts/gatus-status.sh` that sources the env file at runtime (never echoes it) and pulls `/api/v1/endpoints/statuses` filtered to a group. S effort, permanent payoff for every future diagnosis.
4. **Lightweight liveness endpoint upstream InboxClean** — `/health` conflates liveness with sync health under IO load. A `/livez` (process-up, no probes) would let Gatus separate "dead" from "stormy" and kill the false-page class. Upstream candidate alongside the sync-budget knob.
5. **Relay canary as default** — 7 days of zero sends is invisible because nothing asserts "mail flowed recently". The weekly canary (§f item 3) converts silence into a signal.

## f) Top things to get done next (ranked by impact; all session-grounded, user ceiling 50 — 28 solid, not padded)

| # | Task | Impact | Effort | Category |
|---|---|---|---|---|
| 1 | Hetzner console: submit/approve the pbx VPS mail-port limit request (gates ALL of §a.1/§d.1) | Critical | S | Feature (user) |
| 2 | Paste ONE new Resend key into both sops files (pocket-id + mail-relay.yaml, interactive), restart postfix + pocket-id | Critical | S | Bug (user) |
| 3 | postfix `status=bounced` journal-rate textfile metric + Gatus check + weekly relay canary send | High | M | Bug (services.md:117) |
| 4 | Stalwart go-live ceremony per pbx-artmann `mail-go-live.md` once #1 lands; watch the two Mail checks flip green | Critical | M | Feature (user) |
| 5 | Confirm `larsartmann.cloud` "Verified" in Resend dashboard, then run the non-owner delivery probe | High | S | Verification |
| 6 | Enable parsedmarc on evo-x2 once `dmarc@larsartmann.cloud` can receive (post-#4) — currently `enable = false` by design | High | S | Feature |
| 7 | Correct the stale `171de0d` close-out in services.md:324 → deployed+lock now `e067cb5` (surface-both rule) | Low | S | Documentation |
| 8 | `scripts/gatus-status.sh` authenticated read-only status pull for agent sessions (§e.3) | Medium | S | Quality |
| 9 | File upstream InboxClean: configurable sync run budget (unhardcode `commands.go:397`) with 08:20:06 + PSI evidence | High | M | Bug (upstream) |
| 10 | File upstream InboxClean: year-2611 corpus date-parse (export raw Date headers first — verify-before-filing) | Medium | M | Bug (upstream) |
| 11 | Root-cause InboxClean→Paperless `gmail` tag demote PATCH rejection (capture HTTP status since 2026-09-06) | Medium | M | Bug |
| 12 | Add gmail-verdict-cache regression test (second /health within TTL must not re-probe) | Medium | S | Quality (upstream) |
| 13 | Gatus InboxClean checks: storm-aware handling (PSI-correlated annotation or calm-window probe per services.md:323) | Medium | M | Quality |
| 14 | Upstream InboxClean `/livez` liveness endpoint proposal (§e.4) | Medium | M | Feature (upstream) |
| 15 | Papersync blind-window coverage for `main` after re-consent (rescan/backfill the 2026-09-04→10-04 gap) | Medium | M | Bug (services.md:126) |
| 16 | Stale-historyId risk check: `main` retries from `start_history_id=5152620` — verify full-rescan fallback | Medium | S | Verification (services.md:125) |
| 17 | Per-account `auth_expired` Gatus check decision — should ONE dead Gmail account page? (26-day silent dead class) | Medium | S | Decision (services.md:137) |
| 18 | Push+deploy the InboxClean dead-grant honesty chain + lazy-reconnect slug fix (`1540a56`/`d23c48a`/`e9735c7`) | Medium | S | Bug (upstream.md:46, blocked:push) |
| 19 | Fix the SIX pre-existing InboxClean test failures masking regressions | Medium | M | Quality (upstream.md:47) |
| 20 | Add mail-wiring PASS-since-2026-09-05 note to paperless runbook monitoring map | Low | S | Documentation (services.md:132) |
| 21 | DMARC fleet follow-ups: re-add TLS-RPT hardening row + annotate superseded 09-29 report lines | Medium | S | Documentation (services.md:47) |
| 22 | DMARC flip-time verification bundle (post-#4/#6) | Medium | M | Verification |
| 23 | Weekly DMARC `rua` receipt verification once mailbox live (reports currently black-holed) | Medium | S | Verification |
| 24 | Post-#4: verify cron/system mail reaches the inbox end-to-end (canonical-map path, never proven) | Medium | S | Verification |
| 25 | Post-#2: one Pocket ID email (invite/forgot-password) to close the key-rotation orbit cross-check | Medium | S | Verification (security.md:19) |
| 26 | Add postfix queue+bounce state to post-deploy-check (relay leg) so deploys catch the 550-drain class | Medium | S | Quality |
| 27 | Decide InboxClean→CRM feed scope (plumbed both ends, connected nowhere; zero `/api` hits) | Low | S | Decision (services.md:404) |
| 28 | Re-check `main`-account sync-tick green + `gmail`-tag demote after next calm window (post-re-consent residue) | Medium | S | Verification (TODO_LIST.md:344) |

HARVEST note: items 3, 5, 10-16, 18-21, 27, 28 are ALREADY queued in TODO_LIST.md / docs/todo (verified during session) — harvesting them is a no-op. Genuinely NEW rows this session produced: **#7** (stale close-out correction), **#8** (gatus-status script), **#13** (storm-aware handling variant), **#14** (/livez proposal), **#23/#24** (post-go-live verification legs). Per instruction, HARVEST is **deferred until owner go-ahead**.

## g) Questions I cannot answer myself

1. **Hetzner mail-port limit request** — has it been submitted, and what is its current status (ticket #, approved/rejected/pending)? I have no Hetzner console access; it gates items 1, 4, 6, 22, 23 — the entire mail stack.
2. **Resend dashboard truth** — does `larsartmann.cloud` show as **"Verified"** today? The observed 250s are equally explainable by the owner-address allowance; only the dashboard (or a non-owner test send, which emails a third party and needs your go-ahead + address) can separate them. Gates items 5 and the relay go-live.
3. **Pocket ID sops value** — is `pocket_id_smtp_password` still the revoked/placeholder key, or was it rotated in place since 2026-08-18? The value is sudo-only decrypt (agent-banned) and 10 days of journal show neither a working send nor a failure. Determines whether item 2/25 is a live outage or a hygiene task.

---

*Self-critique summary (asked directly): forgot to live-verify the Pocket ID claim before asserting it (§d.6), under-explored the sanctioned runtime-secret path to the Gatus API (§b.1), and held the deployed-rev observation instead of surfacing it immediately (§e.2). Diagnosis work itself: all headline claims carry fresh live evidence (§a).*
