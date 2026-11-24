# Status Report 2026-11-24 00:07 CET — Immich declarative admin settings, one week later

**Session lineage:** this report covers the 2026-11-15 session (commit `6977c5754` — four Immich admin
surfaces moved into `services.immich.settings`) and tonight's one-week-later live verification.
User framing: "It's been a week" — so the load-bearing question this report answers is **what
actually landed, what is live, and what never got proven**.

## Scope — what this report VERIFIED vs did NOT

| Claim | Verified with (command/artifact) | Result |
|---|---|---|
| Commit pushed | `git merge-base --is-ancestor 6977c5754 origin/master` | PUSHED |
| My settings block untouched since | `git log 6977c5754..HEAD -- modules/nixos/services/immich.nix` | one later commit (`e08caa916`, converger CAP_DAC_OVERRIDE — another session, different section); settings block intact |
| **Deployed** | deployed generation `system-1027` (store path `…26.11.20261119.0bb8272`); grepped the DEPLOYED pre-start script (`/nix/store/kcah156x…/immich-server-pre-start`) heredoc | all four settings present: `"trash":{"days":365}`, `"user":{"deleteDelay":3650}`, `"smtp":{"enabled":true,"from":"immich@larsartmann.cloud","transport":{"host":"127.0.0.1","port":25,"secure":false}`, `"preview":{"progressive":true}`; `progressiveJpeg` count **0** |
| Stale-key warning dead | `journalctl -u immich-server --since 2026-11-15 \| grep -c "Unknown keys found"` | 9 hits in the 11-15→11-19 pre-deploy window; **0 since 11-19**; 0 on current boot |
| Relay healthy | `/var/lib/prometheus-node-exporter/textfile_collectors/mail-relay.prom` | queue 0, over-threshold 0, placeholder 0, scrape-errors 0 |
| **Relay accepts the immich@ envelope** | non-mutating SMTP probe (EHLO/MAIL FROM `<immich@larsartmann.cloud>`/RCPT TO `<lars@larsartmann.cloud>`/QUIT — no DATA, nothing queued) via the house `/dev/tcp` pattern | `MAIL: 250 2.1.0 Ok`, `RCPT: 250 2.1.5 Ok` |
| Immich mail attempts since deploy | `journalctl -u immich-server --since 2026-11-19 \| grep -icE "smtp\|mailer\|nodemailer"` | 0 (nothing triggered, nothing failed) |
| Live environment | `journalctl --list-boots`, `pgrep -f 'nh os\|switch-to-configuration\|bin/deploy'`, deploy logs | boot 0 started 21:13:15 today (previous boot ended 21:12:17); **a deploy is LIVE RIGHT NOW** (PID 2727005, log `2026-11-23_23-59-48.log`, no exit line at authoring time); earlier today 19:19 + 19:35 deploys exited code=3 (quotaboard smoke class — already rowed, not this work) |

**NOT verified (and why):**
- **End-to-end delivery through Resend into an inbox** — needs a real DATA send; I did not send mail without consent (probe stayed pre-DATA by design).
- **Admin UI rendering of the values** — `/api/system-config` is 401-gated; no browser session.
- **Outcome of the right-now deploy** — still running at authoring time; my pushed work rides it either way (it evaluates the current tree).
- **Whether any non-default admin-UI-era settings existed in Immich's DB before the file took over** — `system_metadata` is not agent-readable; the settings FILE has owned config for months, so any clobber predates this work (flagged §f/§g).
- Load-average 102→28 during this session's first minutes (recovering storm — observed one line, not investigated; out of scope).

## a) FULLY DONE

1. **All four admin settings are declarative, deployed, and live-rendered** — delete delay 3650, trash 365 days, preview progressive JPEG true, SMTP 127.0.0.1:25 unauthenticated from `immich@larsartmann.cloud`. Evidence in the scope table (deployed-generation pre-start heredoc, gen-1027 since 2026-11-19).
2. **The stale `image.progressiveJpeg` unknown-key warning is eliminated** — warned on every config load pre-deploy (9 journal hits 11-15→11-19), zero since. The schema-exact replacement (`image.preview.progressive`) is the 3.3.6-DTO-verified key.
3. **Commit + queue hygiene** — daemon sweep repaired into properly-messaged `6977c5754` (amend-forward after `git show --stat` verified exactly my 5 files), pushed; both runbooks corrected (mail-relay.md + immich.md: the "admin-UI-only, lives in DB" claim was false — `IMMICH_CONFIG_FILE` **replaces** DB config and UI saves throw); progressiveJpeg TODO row ticked on BOTH surfaces in one pass; formatter (0 changed), TODO gate (rc=0), and full eval green.
4. **Relay acceptance of the Immich envelope proven live tonight** — the `250/250` probe closes the claim that `immich@larsartmann.cloud` passes the postfix null client unrewritten toward Resend (generic maps only rewrite `@home.lan`/`@evo-x2` forms — now probe-backed, not just read-backed).
5. **Schema safety against the deployed 3.3.6 DTO** — every key validated against the server's `config.dto.js` in the store path BEFORE the edit (configFile mode throws on invalid config at startup, so this mattered).
6. **Relay-gating parity** — the SMTP block is `optionalAttrs config.services.mail-relay.enable`, matching the forgejo pattern; disabled relay degrades to Immich's SMTP-disabled default instead of a dead config.

## b) PARTIALLY DONE

1. **Email setup is relay-accepted but NOT delivery-proven** — no DATA send has ever traversed relay→Resend→inbox for this sender. Immich-side journal shows zero attempts since deploy (nothing has triggered a notification). This is the session's largest open verification gap.
2. **"Via nix-email" is implemented as same-provider-path, not as Stalwart-submission** — Immich sends through the local postfix relay → Resend (the nix-email stack's own outbound provider, `larsartmann.cloud` verified). Literal Immich→Stalwart-submission-on-the-VPS would need an immich@ mailbox account + password provisioned on pbx-artmann (VPS-side, not reachable from agent shells) — interpretation flagged at the time, still the honest label.
3. **Report self-harvest** — the direct follow-up (delivery proof + mailbox decision) lands as a row with this report; the remaining §f list is deliberately NOT harvested (brainstorm-grade, see §f preamble).

## c) NOT STARTED

1. **immich@larsartmann.cloud mailbox on Stalwart** (if inbound/replies are ever wanted) — zero work done; needs VPS-side provisioning regardless.
2. **End-to-end test email** — not sent (consent-gated, see §g).
3. **DB-era settings audit** (what the Immich DB held before file-ownership) — not started; value is low because file-ownership predates this session.
4. **Post-deploy battery leg asserting the four rendered values in `/run/immich/config.json`** — idea only; nothing exists.
5. **Runbook semantics notes** (deleteDelay=3650 ≈ user purge effectively off; trash-365 keeps trashed assets snapshot-covered for a year — storage interplay) — additive doc notes, not written.

## d) TOTALLY FUCKED UP

**Nothing found.** The deployed config is correct, live, warning-free, and relay-accepted. What I list instead is the honest near-miss inventory (all caught before shipping; none reached the tree wrong):

- Typed `rg -rn …` (the `-r` = REPLACE trap) once — the hook caught it; this was the **third documented strike** of that exact trap on this host, and AGENTS.md documents it verbatim. My miss, not the tooling's.
- Two edit-tool rejections ("must read the file first") on the runbooks — process friction, self-inflicted.
- Two wrong `nix eval` attribute guesses (`finalPackage` doesn't exist on the flake attrpath; `package` does).
- Probe attempt 1 used `openssl s_client` on a PLAINTEXT port (wrong tool for plain SMTP — TLS handshake noise, empty output); attempt 2 mis-parsed the EHLO multi-line response (break condition matched `250-` continuations, shifting every read by one). Attempt 3 with the documented `/dev/tcp` pattern + full EHLO drain went green. An empty probe read is never evidence — the first "no output" would have been worthless had I quoted it.

## e) WHAT WE SHOULD IMPROVE

**What I forgot (last session):**
- The end-to-end mail verification row should have been queued AT AUTHORING TIME on 11-15 — the self-harvest discipline I applied to status reports applies equally to a change session's own follow-ups. It sat unqueued for a week.
- I stated "not deployed yet" but didn't say WHO/WHEN deploys — a week passed before anyone looked; the config was inert on disk while the admin UI (if consulted) contradicted it.
- The admin-UI save-lockout behavior change ("Cannot update configuration while IMMICH_CONFIG_FILE is in use") was buried in runbook prose; it's an experience change the owner would hit without context.

**What could have been done better:**
- The relay-envelope probe takes two minutes and closes the mail claim's weakest link — doing it on 11-15 instead of tonight would have made the 11-15 close-out claim actually answer "is mail live" instead of "is mail configured" (the 2026-09-18 lesson: a close-out must answer the question the item ASKED).
- The from-address is a hardcoded `larsartmann.cloud` literal — consistent with house patterns (mail-relay's default is too), but it's now the same domain string in 3+ modules with no single source (split-brain seed).
- I reported the settings eval result but never re-verified the runbook edits rendered correctly in context (I did — minor).

**What we should still improve:**
1. Data-presence legs for declarative app config: a post-deploy battery leg asserting the four values in the rendered `/run/immich/config.json` (the class the 2026-10-21 incident report asked for; immich currently has none for settings).
2. Single-source the mail domain (`larsartmann.cloud`) the way ports are single-sourced, before another module hardcodes it.
3. Queue authors' premise-check habit held here (config greps before queueing), but verification CLAIMS in final messages should carry their probe command inline — tonight's report format (scope table with commands) is the standard to keep.

## f) Next things (up to 50 — capped at 30, and why)

The skill guidance says a large N is a brainstorm, not a commitment list. I stopped at **30 grounded items**: every one is either (i) this session's direct follow-up, (ii) a pre-existing queue row I re-verified is still open tonight (pointer, no duplicate), or (iii) a small idea born of something I directly observed. Padding to 50 would mean inventing items with no observation behind them — anti-value.

**HARVESTED NOW (rows landing with this report):**
1. Immich mail end-to-end delivery proof (DATA send) — relay-accepted ≠ delivered; owner test-email or one consented probe send. *(→ services.md + TODO_LIST now)*
2. immich@larsartmann.cloud mailbox: wanted or sender-identity-only final? *(same row, decision leg)*

**EPHEMERAL — act on next interaction, no row:**
3. Read the RIGHT-NOW deploy's outcome (`/var/log/systemnix-deploys/2026-11-23_23-59-48.log` tail + generation-anchor check) — it carries the pushed master tip; verify `readlink /run/current-system` == newest `system-N-link` per anchor discipline once it exits.
4. Note tonight's storm tail (1m load 28, 15m 102) resolved itself; if a freeze/PSI row ever cites this window, boot 0 started 21:13:15 (previous boot ended 21:12:17). <!-- fresh:skip: deliberately not harvested - point-in-time storm observation for freeze forensics; freeze rows carry their own boot evidence -->

**ALREADY ROWED — re-verified open tonight (pointers, do not re-add):**
5. Quotaboard availability contract + deploy-smoke treatment of session-scoped user services *(TODO_LIST 3898, BLOCKED on owner answer)*
6. Attribute the 19:09/19:19 deploys *(TODO_LIST 3896, BLOCKED on owner answer)* <!-- fresh:skip: represented verbatim at TODO_LIST.md:3896 (BLOCKED on owner answer) -->
7. Prune-candidates paging policy *(TODO_LIST 3897, BLOCKED on owner answer)*
8. Reviewfix sessions must stamp Task-Queue-ID footers on fix commits *(TODO_LIST 3895)*
9. Standing quotaboard :8791 connection-refusal *(TODO_LIST 3894)*
10. browser-history-agent rejected-visit loop upstream *(TODO_LIST 3893 — 62+ failures, P0 pages)*
11. project-discovery-daemon OTEL terminal state *(TODO_LIST 3892)* <!-- fresh:skip: represented verbatim at TODO_LIST.md:3892 -->
12. project-discovery degraded-health gatus leg *(services.md 1264)*
13. audiblesync progressCmd flip decision *(services.md 1263)* <!-- fresh:skip: represented verbatim at docs/todo/services.md:1263 -->
14. Undated `library.json` weekly-archive verify (next run 2026-11-29 05:01) *(services.md 1262 — time-boxed, do before Saturday)*
15. Parked audiblesync lock float deploy *(services.md 1261)*
16. journal-serve cold-boot SQLITE_BUSY race *(services.md 1260)*
17. Immich runbook probe-permission matrix *(services.md ~1187)*
18. Takeout ingest reconcile: state both count semantics *(services.md ~1184)* <!-- fresh:skip: represented at docs/todo/services.md:1204 + TODO_LIST.md:3707 (line pointer in text was stale) -->
19. Migrate drive-paperless onto `services.immich.apiKeys` *(services.md ~632)*
20. Catalog 21-subdomain eval warning *(services.md ~380)*
21. Pocket ID auto-rotation deploy + apply-flip mechanics *(services.md ~389-390)*
22. Client-secrets consumers ↔ pocket-id cycles (stale-secret class) *(services.md ~1142)*
23. CI nix-check + VM-test leg cluster *(pipeline.md CI cluster rows: branching-flow SSH 44, nix-check watch 48, compat 49, actionlint 50, RO-PAT 73, selftest carrier 108)* <!-- fresh:skip: represented as the CI cluster in docs/todo/pipeline.md -->
24. Re-anchor the four dump legs *(services.md ~911)*
25. tq-agent-pool start in the first sub-30% PSI window *(services.md ~745 — tonight's declining load may be that window; the 15m avg still >30% at 00:07)*

**BRAINSTORM — deliberately NOT harvested (with reasons):**
26. Post-deploy battery leg asserting the four rendered config values — no failing signal exists yet; queue it when a settings regression ever bites (§c4). 
27. DB-era settings audit — file-ownership predates this session; blast radius is not this week's work (§c3).
28. Runbook semantics notes (deleteDelay=3650 ≈ purge-off; trash-365 snapshot interplay) — sub-5-min doc append; do on sight at the next immich touch (§c5).
29. Single-source the mail domain literal across mail-relay/immich/pocket-id — real split-brain seed, but a refactor with zero current failure; ROADMAP-grade. <!-- fresh:skip: routed to ROADMAP.md Theme 4 (single-source the mail sender-domain literal, verified 8-module duplication) -->
30. Immich→relay send-counter observability (immich has no per-surface mail metric; only the relay queue gauge exists) — weak value while zero notifications fire; revisit if email becomes load-bearing (e.g. album invites).

## g) Questions I can NOT figure out myself

1. **BLOCKED: is `immich@larsartmann.cloud` meant to RECEIVE (real Stalwart mailbox — replies/invites land somewhere), or is sender-identity-only the intended end state?** VPS-side provisioning is not reachable from evo-x2 agent shells, and I will not invent mailbox infrastructure on a production mail server without the answer.
2. **BLOCKED: is full Nix ownership of ALL Immich admin config the intended permanent posture?** The settings file locks the whole admin config UI file-wide (saves throw), and that now covers four more surfaces. If you want selected surfaces UI-editable, they must come OUT of the Nix block — the opposite edit of what we just landed.
3. **BLOCKED: may I send ONE real probe email through the relay (`immich@larsartmann.cloud` → your inbox) to prove Resend→inbound delivery, or will you click Immich's admin "Send test email" button yourself?** It's a real outbound mail to a real mailbox — I don't send production email unasked.

## THEN WAITING FOR INSTRUCTIONS (per the standing directive)

Nothing else touched tonight beyond the verification probes above; the report + the two harvested queue rows are the only writes.
