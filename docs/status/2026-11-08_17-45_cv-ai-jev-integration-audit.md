# CV AI/Jev Integration Audit — how well is AI leveraged, and does the funnel reach its end goal?

**Question (owner, 2026-11-08 ~17:0x):** How well did we integrate AI (LLMs) and Jev
(TypeSafe.ai) into CV, and how well is it using it? Does it achieve the end goal —
superbly applying for jobs AND projects the owner is qualified for, via native
platforms, email, AND telephone?

**Method:** two read-only code audits (decisionmodel/Jev via subagent over the CV repo;
LLM surfaces via subagent) + first-hand live-state probes (cv-server/cv-scan/cv-agent/
cvagent journals 7–30d, deployed-unit inspection, sops template wiring, flake.lock revs)
+ production-config cross-check (SystemNix cv.nix settings vs CV DI wiring).

## §b Findings

### §b.1 Jev (TypeSafe.ai): architecturally clean, completely dormant, and NOT aimed at the funnel

- The `decisionmodel/` module (13-module Go workspace) is a **developer-lint adjudication
  gate**: it asks ONE Choice question — whether a Go dynamic-`any` surface is a sanctioned
  boundary per the owner's Boundary Philosophy (`decisionmodel/rubric/boundary.json`) —
  feeding `cv adjudicate` (advisory) and the anytypes gate. It has **no seat in job
  evaluation**: the apply/worth-trying/skip verdict is 100% deterministic heuristics
  (`career-pipeline/evaluation/evaluation.go`, score bands + categorical skips + rate
  floor).
- **Zero production wiring**: no `decisionmodel:` block in cv.nix settings, config.yaml,
  or config.production.yaml; defaults are `enabled: false, provider: mock`; `JEV_API_KEY`
  is not in any sops template. The calibration ledger has exactly ONE stamp — a mock
  self-confirmation (accuracy 100%, Brier 0.0254, 2026-10-28); the live ledger DB holds
  0 verdicts. Gate G1 (typesafe.ai waitlist) never opened.
- Craft quality (judged against the TypeSafe skill): provider-neutral seam, severity
  truth-table in code, confidence-never-gates — good. But the one production question
  asks for the DECISION not the judgments (violates "judgments from Jev, decisions in
  code"), the 7 criteria are never sent on the wire for Choice, multi-candidate batches
  ask indistinguishable questions, and structured state is flattened to a string. Also a
  client defect: `jev.go` lacks clef's answer-count guard (a vendor over-reply panics).
- **Verdict: Jev is not integrated into CV-the-product at all.** It is dormant scaffolding
  for a code-quality gate, with an empty earned-autonomy ladder.

### §b.2 LLMs: live at the edges, heuristic at the SEND path — the decisive wiring gap

Live in production (journal-verified):

| Surface | Provider/Model | State |
| --- | --- | --- |
| Agent brain (`cv-agent.timer` daily 04:41 → POST /api/agent/pass) | z.ai glm-5.3-flash via CV_AGENT_API_KEY (sops cv_agent_api_key, 2026-11-02) | LIVE — passes complete with findings=5; lessons=0 (distill threshold 10 not reached); 2026-11-08 04:41 pass FAILED on the z.ai 5h usage quota |
| Public-site chat | Synthetic syn:large:text via OPENAICOMPAT_API_KEY (2026-11-02) | LIVE (chat.enabled in cv.nix; TTS/STT deliberately off) |
| cvagent code→CV-facts extraction | z.ai glm-5.3-flash, 600 AI-facts/day cap | Configured; deployed unit BROKEN since ≥2026-11-07 (`awk: command not found`, exit 127 daily) — upstream fix (Code-To-CV-Agent 1664d48 + 6ff68d3) is LOCKED in SystemNix flake.lock but NOT deployed (deployed system still runs the pre-delegation cvagent.service) |
| CRM mirror (Kith) | n/a | LIVE (opportunities created 2026-11-07) |

NOT live in the autonomous funnel (config-verified):

- **Tailor**: `provideTailorLLM` returns nil when `cfg.Tailor.APIKey == ""` → the
  server's auto-apply path tailors CVs with **DryRunLLM keyword-emphasis heuristics**
  (CV repo internal/di/services_pipeline.go:561-564). No `CV_TAILOR_API_KEY` in the cv-env
  sops template; no tailor block in cv.nix.
- **Cover letter**: LLM writer skipped without the coaching key → template stub in the
  server compose path; `cv letter check` register gate still applies.
- **Coaching**: NullCoach → 503.
- **Alert-router LLM refiner**: off (no coach key).
- Nuance: the **CLI** `cv apply` path CAN refine via the agent key fallback — so
  operator-driven applies are LLM-quality while the timer-driven funnel is heuristic.
  Server and CLI quality diverge by wiring, not by capability.

### §b.3 End-goal channel scorecard (the question's core)

| Channel | Discovery | Application | Verdict |
| --- | --- | --- | --- |
| Native platforms | LIVE: 19 portals scanned every 6h (cv-scan ticks all 200 OK, verified 48h journal); gun.io weekly check was DEAD ≥21 days (transient user timer vanished) — re-registered this session 17:28, fires 21:00 today | A.Team mission path EXISTS in code (browser automation, review-gated submissions) but `missions` scanning is disabled by default and the 30d journal shows **zero mission submissions**; credentials store sealed 2026-11-06 but no relogin/apply traffic since | **Discovery works; native APPLY effectively unused** |
| Email | Reply inbox configured (Stalwart mailbox enabled-but-inert until password staged — owner-gated) | SMTP transport live (local relay → Resend, gate Q2 flipped 2026-10-17, send_on_approve=true, max 5/pass, 7d age cap) — but the retained 30d journal shows **9 completed auto-apply passes, EVERY one sent=0**, and ~30 approvals all granted 2026-10-25 19:20-19:27 now permanently over the 7d age cap (each pass WARNs and skips). Corroboration: the 2026-10-27 owner ruling comments the reply_to cutover is "free while zero real sends carry it" — **zero production application emails have ever been sent** | **Transport live, funnel output = 0; bottleneck is the human approval gate (silent since 2026-10-25)** |
| Telephone | none | none — voice handlers were deleted upstream as a non-goal (~2,700 LOC, CV ROADMAP.md:144 "not enough value for a CV generator"); TTS/STT off in prod; no telephony stack anywhere in SystemNix | **Channel does not exist; also not represented as planned work anywhere** |

### §b.4 Ops context

- cv-server remains in the known SIGSEGV restart cycle (446 panic/SIGSEGV journal lines
  in 7d; upstream TODO row exists — chatstore nil-deref + 5s rehydration timeout).
- The stuck-approval cohort is the SEEDED dev-era store rows bulk-approved 2026-10-25
  (low app-IDs + same-second grantedAt stamps) — i.e. test-era approvals, not live
  opportunities anyone chose; they now merely WARN every 6h.

## §c Changes made this session

1. **Re-registered the gun.io weekly check** as transient user timer `cv-gunio-weekly`
   (Sun 21:00, SuccessExitStatus=3, OnFailure alert preserved) via the runbook's
   `--print-timer` procedure — with `CHROMIUM_EXECUTABLE_PATH=/run/current-system/sw/bin/chromium`
   (stable across upgrades; previous registration pinned a nix-store path). Verified:
   `systemctl --user list-timers` → next fire Sun 2026-11-08 21:00.

## §d Verification evidence

- cv-scan 48h journal: 4 ticks × 3 POSTs, all `-> 200 (ok)` (00:23/06:23/12:23/18:23 cadence).
- 30d journal: `auto-apply pass completed` ×9, all `sent=0`; ~30 distinct `over age cap`
  WARN appIds, all grantedAt 2026-10-25T19:2x; zero send/smtp-submission success lines.
- Agent: `Agent brain configured provider=openaicompat model=glm-5.3-flash max_steps=12
  lessons=0` (repeated across restarts); `agent pass complete findings=5` (Nov 7 ×2);
  one failure `Usage limit reached for 5 hour ... reset at 2026-11-08 12:00:35`.
- cvagent: exit 127 `awk: command not found` Nov 7 05:55 + Nov 8 06:01 (OnFailure);
  SystemNix flake.lock `cvagent` = 6ff68d32 (carries gawk fix 1664d48 + YAML fix 6ff68d3);
  `/etc/systemd/system` still has pre-delegation `cvagent.service` → fix pending deploy
  (existing rows 1810/1813 cover the deploy chain).
- Backups fresh: pipeline-20261108T031700.sqlite (nightly 03:17 unbroken).
- gun.io: `ls ~/.config/systemd/user` showed only the alert unit (timer+service gone);
  `journalctl --user -u cv-gunio-weekly --since -21d` → "No entries"; post-fix
  list-timers shows the timer active (waiting).

## §e Assessment against the end goal

**"Superbly applying for jobs and projects I am qualified for via native platforms,
email AND telephone" is NOT achieved.** Precisely:

1. **Discover + qualify: good.** 19 portals on a 6h cadence, deterministic scoring with
   eligibility/ANÜ/rate-floor axes, CRM mirroring, fresh backups — the machine half of
   the loop is solid and observable.
2. **The funnel's mouth is heuristic, not AI.** The single most owner-visible artifact —
   the tailored CV + cover letter an applicant receives — is produced by keyword
   heuristics and templates in the autonomous path because the funnel-side LLM keys were
   never provisioned. AI currently READS (agent pass review, alert classification would
   if keyed) but does not WRITE what gets sent.
3. **Zero output.** No email has ever been sent; no native-platform application has been
   submitted by the machine in the retained journal window; the human approval gate has
   been silent since 2026-10-25 and the age cap now hard-blocks the stale cohort. North
   star (qualified sends/week) = 0. Operator-minutes per qualified send = undefined.
4. **Telephone is not a thing.** No code, no plan row, no stack — the goal statement and
   the product have diverged; either the goal or the roadmap should change.
5. **Jev specifically: 0% utilization in the product.** The one integration built is a
   code-lint gate that has never run live and whose question design violates the craft
   rules it was built against.

Highest-leverage fixes, in order: (1) owner acts on the approval queue (re-approve real
current candidates or purge the test cohort) — without this nothing else matters;
(2) provision funnel-side LLM keys so approved sends are actually superb; (3) deploy the
locked cvagent fix; (4) decide telephone: plan it or retire it from the goal statement.

## §f Follow-ups (self-harvested)

1. → TODO_LIST `[decision]` "Funnel send-path LLM keys" + docs/todo/services.md — §b.2.
2. → TODO_LIST `[decision]` "Stale approval queue / zero sends" + docs/todo/services.md — §b.3.
3. → TODO_LIST `[ready]` "Durable gun.io weekly check (system timer + absence alerting)"
   + docs/todo/services.md — §b.3/§c.
4. NOT re-harvested (existing rows cover them): cvagent gawk-fix deploy (rows 1810/1813),
   z.ai rate-limit tax (TODO_LIST 675), cv-server SIGSEGV upstream fix (docs/todo/upstream.md),
   ai-meter routing for GLM traffic (TODO_LIST 1829), Jev question-design debt + jev.go
   answer-count guard (dormant gate — revisit only if the owner ever opens G1; noted here
   for the record).
