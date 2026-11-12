# SUPERB Residue Batch Execution — 539 Misroute Corrections LIVE, R4/R5/R6 Closed, G-RESEND Still Open

**Created:** 2026-11-12 23:36 CET
**Session:** residue continuation (third of the chain; M1 float-deploy marathon + 14-10 continuation preceded)
**Plan:** `docs/planning/2026-11-11_11-40_SUPERB-send-hardening-residue-mail-restore-pareto-plan.md` — now tombstoned EXECUTED (with the 01-10 closure plan)
**Predecessors:** `2026-11-11_14-10_superb-residue-execution-m1-float-deploy-marathon-status.md`, `2026-11-12_22-50_superb-residue-continuation-misroute-live-new-blindspot-status.md`

## §0 Verdict table

| Item | Verdict | Evidence |
| ---- | ------- | -------- |
| R3.3 misroute batch v2 | **LIVE — 538/538 OK, 0 fail** (+1 dry-run row = **539 total corrections**) | batch log `misroute-v2-progress.log` (535 `vacated applications@artmann.tech` + 3 `vacated <recruiter>`); sqlite `application.misrouted` count = **539** on a fresh snapshot; cv-server rehydrated 23:24:17 **events 48,975 → 49,513 (+538 exactly)**, applications 11,241 |
| v1's 536/536 clean failure | **Root-caused to the invocation** | agent-shell CLI resolves NO config.yaml (CWD has none, no `~/.cv/config.yaml`) AND lars cannot read the cv:cv 0700 store — every row died `ErrNeedsEventStore` before any write. Working form: `sudo -n -u cv env CV_PIPELINE_MAILBOX_PASSWORD=validation-only CV_OIDC_CLIENT_SECRET=validation-only sh -c "cd /var/lib/cv && /run/current-system/sw/bin/cv misroute …"` (CWD resolves the generated config.yaml with the ABSOLUTE DSN; the two dummy envs only satisfy config validation — misroute never uses mailbox/oidc; no real secret touched). Documented in `docs/services/cv.md` |
| R3.4 rehydration verify | **GREEN** | server active; +538 events exactly; real-decider fold (`ApplyApplicationEvent`) proves sampled apps demoted: app-412/app-9802/app-9839/app-9871 → `ready` (the scratch enumerator still printing 536 "applied" rows is EXPECTED — it hardcodes status and counts historical sends; corrections append, never erase) |
| R6 dashboard render | **VERIFIED LIVE** | deployed cv@`76f8e41`: authenticated fetch `/api/pipeline/applications/app-8022/events` → **HTTP 200 + "Misrouted correction (catchall) — vacated applications@artmann.tech"** rendered; app-9802 same. Parity ratchets green in a worktree at the deployed rev (`TestSummarizeEvent_ParityWithAllEventTypes`, `TestEventVisuals_ParityWithAllEventTypes`; templ generate needed the pinned devshell). R6.2 decision: CLI-is-the-surface (no dashboard action link unasked) |
| R4 held-queue release | **CLOSED CLEAN** | re-verified 20 held ALL `applications@artmann.tech` (zero recruiter); `postsuper -H ALL` + flush → queue **0**; journal: **20/20 `status=sent`** at the relay |
| R1 re-probe | **STILL 550 — G-RESEND REMAINS OPEN** | fresh smtplib probe From applications@artmann.tech (23:18) → relay hop `status=bounced (550 The artmann.tech domain is not verified)`. **Contrast proof:** the 20 flushed mails went sent because they carry `from=noreply@larsartmann.cloud` (generic-map rewrite) — larsartmann.cloud IS verified + working; the rejection is artmann.tech-specific. Rows annotated (TODO_LIST + services.md + 09-20 report §0) |
| R5 mail-relay verdicts | **LANDED (rides next deploy)** | `modules/nixos/services/mail-relay-verdicts.nix` + `scripts/mail-relay-verdicts-collector.sh` + fixture selftest (green, repo-file-driven) + `mail-relay-verdicts-selftest` flake check + SigNoz "Outbound Mail Bounced at Relay" (`increase(node_mail_relay_bounced_total[10m]) >= 1`) + evo-x2 enable + runbook section. evo-x2 toplevel eval GREEN |
| R5 split-brain catch | **CAUGHT at eval before any deploy** | first landing (unit `mail-relay-metrics`, file `mail-relay.prom`) collided with `services.mail-relay`'s OWN queue/credential collector — ExecStart conflict failed the toplevel eval. Renamed to `mail-relay-verdicts` (own unit, own prom file, root for journal access vs postfix-user for the SASL probe); split documented in both module headers + runbook |
| R9.2 CV-side flags | **MOOT** | `go vet ./internal/cli/ateam/` green (cookie.go fixed by sibling); portalapply files no longer dirty — the flagged breakages are gone |
| cv-scan.timer | **STILL STOPPED (correct)** | protective stop from 22-50 session remains right: the pipeline's From-domain still bounces. Restart condition: R1 probe green |

## a) The batch discipline that landed it

The 22-50 session's rule — any batch mutation ≥10 rows runs row 1 alone first — paid for itself again: the dry-run (app-8022) proved event-write + fold-demotion + server-restart in one 3-minute window BEFORE 538 writes. Batch v2 ran both phases in ONE cv-server outage window (~80 min: 535 catchall + 3 non-delivery, ~8s/row fold-bound), EXIT-trap restart, zero failures, misroute-failed.txt empty.

The enumerator-vs-decider distinction matters for any future verify: `tmp/r3enumerate` (scratch, CV repo) counts HISTORICAL `application.sent` events (stays 536 forever — corrections append); `tmp/r3verify` folds through the REAL decider and shows the demoted truth. Both scratch tools are gitignored; the durable record is this report + the store.

## b) Still gated on the owner (G-RESEND)

Everything mail-outbound remains behind the Resend dashboard re-verify of artmann.tech (resend.com → Domains; DNS records already live): the T3 same-key idempotency proof (`~/.cache/send-hardening/r2-samekey-pair.py`), the catchall re-dispatch (eligibility RESTORED by tonight's 539 corrections — pairs vacated), and the cv-scan.timer restart. The probe row (TODO_LIST + docs/todo/services.md) carries the live verdict + the restart condition; no nagging needed beyond this report.

## c) Deploys owed

R5 rides the next natural deploy (sibling deploy trains were active all evening). Post-deploy: the collector's first scrape lands `mail-relay-verdicts.prom` and the SigNoz rule provisions; the existing post-deploy §12 legs cover the queue-health collector unchanged. The R5 commit wave: daemon carrier `e2502ab38` (old names, pre-rename, eval-broken transient) → rename commit (this session) heals it — check out the rename commit or later, never the carrier alone.

## d) Incidents / races this session

- **Sibling lock contention:** a parallel tq-agent's commit held `.git/index.lock` through its pre-commit `nix flake check --no-build --all-systems` walk (minutes); my commits went through a patient retry loop, pathspec-scoped. The daemon carrier absorbed my R5 files at OLD paths + the sibling's gcp.json wave — no amend (would absorb foreign work); the rename landed as its own commit.
- **cv-server startup order:** after the batch restart the HTTP listener (127.0.0.1:8098) opened only AFTER the CRM catch-up (538 stage updates syncing as `skipped` opportunities) — a 502 window of minutes, not a defect. The dashboard verify waited for the listener.
- **The 20/20-sent false-thaw:** the flushed held mails' `status=sent` briefly looked like G-RESEND had cleared; the MAIL FROM distribution (`from=<noreply@larsartmann.cloud>` ×20 vs the probe's `applications@artmann.tech`) proved the thaw was the generic-map from-domain, NOT artmann.tech. The deliberate probe caught it within minutes — the d.1 lesson (journal verdict + assert WHICH sender) applied one level up.

## e) Artifact disposition (G2 = KEEP, unchanged)

`~/.cache/send-hardening/` retains the apology draft + storm recipients (owner: keep) + this wave's batch evidence (`r3/run-misroute-batch-v2.sh`, `misroute-v2-progress.log`, fresh + post-batch snapshots, `catchall-rows-fresh.json`), `r6/live-dashboard-verify.sh`, `r1-relay-probe.py`. Cache is volatile by rule — this report + the store are the durable record.

## f) Self-harvest

- **[blocked:deploy] Deploy + live-verify the mail-relay-verdicts collector wave** → rowed in TODO_LIST + docs/todo/monitoring.md below.
- G-RESEND / re-dispatch / T3 / timer-restart: already rowed (probe row + re-dispatch row, both annotated tonight) — deliberately NOT duplicated.
- R9.2: moot (verified green), no row.

**BOTTOM LINE:** the residue plan's executable surface is DONE — 539 corrections live and verified end-to-end, queue closed, verdict observability landed, both plans tombstoned EXECUTED. The only thing left in the chain is the owner's Resend re-verify; every downstream step is rowed with its condition.
