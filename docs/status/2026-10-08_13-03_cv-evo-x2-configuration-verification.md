# Status Report — CV configuration verification on evo-x2

- **Session task:** "Make sure ~/projects/CV is configured PERFECTLY on evo-x2"
- **Written:** 2026-10-08 13:03 CEST (Thursday)
- **Session wall time:** ~09:12 → 13:03 (≈3.9h, incl. a user interlude; tool-call timestamps below are server-rendered and exact)
- **Scope discipline:** verification + minimal fix only; no research beyond CV/SystemNix surfaces touched by the task.
- **Format note:** status-report skill is HTML-canonical; the explicit `.md` path demand in the prompt wins (one-off override, not propagated into the skill).

## Verdict up front

**CV is configured correctly and live on evo-x2.** Every surface in the runbook was probed this session with evidence; one real defect (stale 2026-09-17 hold documentation) was fixed. The 2026-09-17 branch-ref hold is **confirmed lifted upstream and in practice** (lock `b2cab453` builds from our nixpkgs follow and serves production traffic).

---

## a) FULLY DONE

1. **Runbook read before touching the domain** (routing-table mandate): `docs/services/cv.md` (324 lines) + CV `AGENTS.md` (first 200 lines) + CV `flake.nix` head. Evidence: commands in session log.
2. **Live service verified**: `cv-server` answering `/health/live` `{"status":"pass"}` — first `b3a9172` uptime 17h13m (timestamp `2026-10-08T09:17:02+02:00`), then `b2cab45` after the mid-session restart. `/run/current-system` = `nixos-system-evo-x2-26.11.20261006.151fa4e` (current lock's nixpkgs).
3. **Full health dump audited** (40 checks): 38 pass; only the two documented warns remain — `database` (absent by design) and `ChatService` groq key empty (pre-documented owner decision, 2026-09-17 runbook note). `eventstore.PipelineStore":{"status":"pass"}` matches the Gatus pat anchor live.
4. **Functional surfaces probed**: `/cv` renders full HTML (loopback AND through `https://cv.home.lan`), `/export/pdf` returns binary PDF (fetch tool "not valid UTF-8" = binary; deploy smoke pins `%PDF` magic), `/metrics` answers 401 unauthenticated (guard live).
5. **Deploy-state currency proven by independent build**: `nix build .#nixosConfigurations.evo-x2.config.services.cv-server.package` → `/nix/store/17pnvzibsnb7lic6lcrf14cpgb2lbjr3-cv-b2cab45` — byte-identical to the running unit's `ExecStart`. The running server IS the current tree's package.
6. **Eval audits green**: `nix flake check --no-build` → "all checks passed!" (aarch64-darwin skip expected per AGENTS.md).
7. **Branch-ref hold lift verified end-to-end**: CV master reverted go.mod floor to 1.26.7 (`grep '^go ' go.mod` → `go 1.26.7`) and `nix/packages.nix` to `goPkg = pkgs.go_1_26`; SystemNix lock moved to `b2cab453` (docs/tests/scripts-only delta over deployed `b3a9172` — 89 files, all in src-excluded basenames); package builds green.
8. **Full unit inventory on disk**: all 10 `cv-*` units present in `/etc/systemd/system/` (server, scan timer/service, backup timer/service/dir, oidc-env, profile-probe timer/service, state-perms).
9. **Operational liveness evidence**: nightly backup landed 2026-10-08 03:17 (127M; 4 consecutive nights listed); funnel wrote at 06:24 (the 06:23 `cv-scan` tick); OIDC `client-secret.env` rendered 2026-10-07 19:01; deploy log line "cv OIDC env unchanged — cv-server NOT restarted (avoids CRM replay duplication)" proves the bridge's idempotent logic works.
10. **Deploy-smoke CV legs green** (2026-10-07 18:56 run, exit 0): `/health/live pass (b3a9172)`, `/export/pdf real PDF`, `pipeline-store healthy`; and in the 2026-10-08 11:37 run (exit 0): same three PLUS browser-render PASS at version `b2cab45`.
11. **Runbook defect fixed** (the session's one artifact): `docs/services/cv.md` still documented the 2026-09-17 hold as active. Added a dated `2026-10-08 hold LIFTED` lock-state breadcrumb (with build/deploy evidence) and rewrote the Agent Note sentence to past tense with the resolution trail. Uncommitted — daemon will sweep (harness forbids commit without explicit ask).
12. **Port-8091 scare resolved with facts**: `http://localhost:8091` serves Ledger (CRM passkey login), NOT a rogue CV dev instance; exactly one `cv serve` process exists (ps), bound per unit config.

## b) PARTIALLY DONE

1. **Deploy-trail attribution for the b2cab45 activation** — the running process started **09:23:57** (uptime math: 12:57:25.5 − 3h33m28s; corroborated by `ps` START 09:23), but **no deploy.sh log covers it** (2026-10-08 logs begin 09:49). A later logged deploy (11:37, exit 0) smoke-verified the same binary, so the STATE is verified — the ACT trail is not. What remains: attribute the 09:23 activation (journalctl/root or crush.db forensics — both outside this session's sandbox or scope). Effort: S once root/journal available.
2. **`docs/services/cv.md` breadcrumb wording** — my new breadcrumb says "deployed 2026-10-08" but the precise activation mechanism at 09:23 is unattributed (see b1). The claim "deploy-smoke-verified" is accurate; "deployed" is loose until Q1 is answered. Effort: S.
3. **Session §f harvest** — deliberately NOT rowed into `TODO_LIST.md` because a parallel session holds it dirty mid-edit (hot-file discipline, AGENTS.md multi-agent rules). The harvest obligation is recorded here instead; must be executed after `TODO_LIST.md` settles. Effort: S.
4. **CHANGELOG entry for the cv.md fix** — en-route-fix canon says a defect fixed en route gets its own `[Unreleased]` row; not added because `CHANGELOG.md` sits in the same hot-docs blast radius as the parallel session's wave. Owed with the harvest pass. Effort: S.
5. **Render-smoke flap diagnosis** — both failure modes observed (09:49 browser-render FAIL + proxy PASS; 11:37 browser-render PASS + proxy FAIL), live re-verify at 13:0x shows `https://cv.home.lan/cv` rendering fine, and `/proc/pressure/io` showed `some avg300=65.98 / full avg300=54.10` — consistent with the queued row `TODO_LIST.md:780` (IO-pressure false-FAIL class). NOT diagnosed to root cause (which leg times out under PSI, exactly). Effort: M (that's row 780's fix).
6. **Timer outcomes unverifiable in-sandbox** — `systemctl`/`journalctl` are blocked for agents on this host, so `cv-scan`/`cv-backup`/`cv-profile-probe` unit RESULTS (vs. their file effects, which I did verify) rest on indirect evidence only. Effort: S from any shell with journal access.

## c) NOT STARTED (noticed, deliberately not done)

1. **Groq key wiring or provider disable** (kills the permanent `ChatService` warn) — pre-documented owner decision; needs sops edit + deploy. Priority: owner-gated.
2. **Restore drill** (root shell; full prep list already in `cv.md` "Root-shell prerequisites") — still pending since 2026-09-08. Priority: High, owner-gated.
3. **Asset-vanishing forensics** (2026-08-27 journal pull) — root-gated item still open in the runbook. Priority: Low.
4. **Restart-drill persistence proof** (tracked app survives a restart, compared via dashboard) — root-gated. Priority: Med.
5. **Row 780 fix** (IO-pressure-aware render smoke) — queued `[ready]`, not mine to double-dispatch this session. Priority: High (it produced 2 false deploy FAILs today).
6. **Row 841** (wire `check-cv-oidc-gate.sh` as a flake check) — queued `[ready]`; needs a quiet eval window per its own note. Priority: Med.
7. **Row 386 close-out** ("restore cv lock forward to e76d638") — premise now resolved in reality (lock is at `b2cab453`, live-verified); the queue row + library + source report all need the correction (three-surface rule). Not edited: `TODO_LIST.md` hot. Priority: Med.
8. **CV repo push** — local CV HEAD `0597a1799` is ahead of `origin/master` (`e6a13d95`); push-gated (user directive: agents don't push). Priority: Med.
9. **`checks.cv` VM-test evidence refresh** on the post-hold tree — last recorded pass 2026-09-25. Priority: Low.

## d) TOTALLY FUCKED UP

Nothing the session shipped is broken. Honest negatives:

1. **Unattributed production activation (the real finding of this section)** — `cv-server` was restarted into `cv-b2cab45` at 09:23:57 by something OUTSIDE the `deploy.sh` log trail (no log starts before 09:49 that day). Severity: Medium — no data risk (the binary is exactly the tree's package and was smoke-verified green by the 11:37 logged deploy), but it sidesteps the deploy pipeline's pre/post checks and leaves no audit record. Root cause: unknown — needs the Q1 answer. Mitigation: the state itself is verified correct.
2. **My "two servers" misdiagnosis (~15 min of noisy forensics)** — staggered probes showed `localhost:8098` = `b3a9172` then later `b2cab45` and I briefly suspected a rogue dev instance hijacking the vHost. Reality: ONE server, a mid-session restart, and my session's 3.9h wall time made short-interval assumptions wrong. Root cause: I didn't capture a timestamp with every probe. Cost: noisy investigation only; the final facts were all re-verified. Lesson recorded in (e).
3. **Two sandbox command trips** — `systemctl --version` inside a chained command aborted the whole call (also killing the hooksPath/envrc checks queued behind it), and `curl` is banned (used `fetch` after). Minor; recovered same-batch.

## e) WHAT WE SHOULD IMPROVE

1. **Timestamp every probe** — when a session can span hours (user interludes, long builds), relative "earlier/later" reasoning about server state rots instantly. Fix: always record the server-rendered timestamp (`/health` carries one) or `date` alongside state observations. Impact: this session burned ~15 min on a false two-server theory.
2. **Agent-verifiable CV surfaces are undocumented** — the runbook's "Verify (no root needed)" section lists `curl` commands, but agent sandboxes ban `curl` AND `systemctl`/`journalctl`. Fix: add an "agent verification" subsection to `cv.md` with the fetch-tool-equivalent probes and file-based evidence paths (unit symlinks, state-dir mtimes, deploy logs). Impact: every future CV session re-derives this.
3. **Smoke render-fail evidence goes to `/tmp`** — `/tmp/.smoke-cv-render.log` and `.smoke-cv-render-proxy.log` evaporate, yet the canon says human-verification artifacts get a durable home (`~/.local/share/cv-verify/`). Fix: point the smoke's failure dumps there (or `/var/log/systemnix-deploys/<run>/`). Impact: flap diagnoses currently start blind.
4. **Activation without deploy-log = audit hole** — whatever ran at 09:23 bypassed the deploy train's pre/post checks AND its log. Fix: either document `nh os switch` direct runs as permitted-with-note, or wrap/alias it so every activation lands in `/var/log/systemnix-deploys/`. Impact: every "is prod current?" session repeats my attribution hunt.
5. **Standing smoke baseline of 13–14 advisory FAILs is numbing** — real regressions hide in a large known-bad set (today: CV flap + Forgejo 502s + FastFlowLM + Overview + InboxClean + catch-all). Fix: burn-down pass per service, then tighten the baseline. Impact: deploy verdicts become readable again.

## f) Up to 50 things to get done next

Ranked by impact within category; each is specific enough to dispatch. (Deliberately stopped at 40 quality items rather than padding to 50 — the remainder are already-queued rows restated.)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Attribute the 09:23:57 `cv-server` activation (journalctl `/proc` forensics or crush.db query) and record it | High | S | Bug |
| 2 | Re-run `nix run .#deploy` once the tree settles to clear the 12:04 nh-switch failure and restore HEAD==deployed | High | M | Bug |
| 3 | Triage the 12:04 failure: `nsfw-classifier-go-f5646ea-go-modules` FOD (log tail shows `templ-components/errorpage v1.20.1` download) — stale vendorHash class? | High | M | Bug |
| 4 | Fix row 780: make CV render smokes IO-pressure-aware (WARN above a PSI threshold instead of FAIL) | High | M | Quality |
| 5 | Answer Q3 (below) and either wire a groq key into sops `cv-env` or disable the chat provider in `cv.nix` settings | High | S | Decision |
| 6 | Run the restore drill per the `cv.md` root-shell prep list and record the pass in the runbook (canon: closed only by recorded pass) | High | M | Quality |
| 7 | Burn down the 13–14 standing smoke FAILs (Forgejo ×6, Overview ×3, FastFlowLM, Caddy catch-all, InboxClean budget, CV flap) then re-baseline | High | M | Bug |
| 8 | Investigate the IO storm window (~09:30–13:00, io avg300≈65): identify writer(s) via per-cgroup io.pressure | High | M | Bug |
| 9 | Document-or-ban direct `nh os switch` activation (deploy-log audit hole, class of item 1) | High | S | Documentation |
| 10 | Tighten the new `cv.md` breadcrumb: replace "deployed" with the activation mechanism once item 1 lands | Med | S | Documentation |
| 11 | Add the en-route CHANGELOG row for the cv.md hold-lift fix (canon) | Med | S | Documentation |
| 12 | Close row 386 (lock-forward premise resolved at `b2cab453`): edit queue + `docs/todo/services.md` + source report (three-surface rule) | Med | S | Documentation |
| 13 | Add an "agent verification" subsection to `cv.md` (fetch-based probes, file-based evidence, sandbox limits) | Med | S | Documentation |
| 14 | Persist smoke render-fail logs to a durable home (`~/.local/share/cv-verify/` or deploy-log dir) instead of `/tmp` | Med | S | Quality |
| 15 | Verify the 2026-10-05 09:41 `cv-profile-probe` run outcome from the journal (last fire not agent-verifiable) | Med | S | Bug |
| 16 | Re-probe Forgejo 502s (HTTPS version + Catppuccin theme asset) seen in the 09:49 smoke — storm-transient or real? | Med | S | Bug |
| 17 | Re-probe Overview (:8083) and the Caddy catch-all probe from the 09:49 smoke | Med | S | Bug |
| 18 | FastFlowLM :52625 socket-dead class (2026-09-27 + today's 09:49 smoke) — root-cause the guard-down recurrence | Med | S | Bug |
| 19 | Revisit the InboxClean `/health` 3s handler budget (blew during the IO storm; 2026-10-06 class) | Med | S | Bug |
| 20 | Wire row 841: `checks.x86_64-linux.cv-oidc-gate` flake check (selftest already 4/4 green) | Med | S | Quality |
| 21 | Capture + file the 09:49 vs 11:37 render-flap evidence (`/tmp/.smoke-cv-render*.log`) before /tmp cleanup feeds item 4 | Med | S | Bug |
| 22 | Verify `cv-backup` retention is still exactly 14 days (only the 4 newest artifacts were listed this session) | Med | S | Quality |
| 23 | Push CV `0597a1799` → origin/master when the owner next allows pushes (private repo, lock consumers benefit) | Med | S | Cleanup |
| 24 | Refresh `checks.cv` VM-test evidence on the post-hold tree (`nix build .#checks.x86_64-linux.cv.driver` + test-script run) | Med | M | Quality |
| 25 | Confirm the 11:52 deploy (exit 0 in 2s) was a deliberate no-op, not a swallowed validation failure | Med | S | Quality |
| 26 | Verify the `crm-server :8091` ExecStartPre wait-gate still matches the CRM's actual port after crm.nix changes | Low | S | Quality |
| 27 | Consider PSI-aware WARN parity for the Gatus funnel-freshness check (same flap class as item 4, 2.4–12s latencies under load) | Low | M | Quality |
| 28 | Add a post-deploy smoke leg asserting the Gatus CV Auto-Apply last-pass check's endpoint (check exists; smoke doesn't cover it) | Low | S | Quality |
| 29 | Refresh the "Pending root-gated proofs" intro in `cv.md` (evidence dates to 2026-09-08) | Low | S | Documentation |
| 30 | Record the restore-drill row in `cv.md` once run (pairs with item 6) | Low | S | Documentation |
| 31 | monitor365 :9191 refused (already queued) — keep on the dispatch train | Med | S | Bug |
| 32 | node_exporter connection-reset journal spam (already queued) — identify the scraper | Low | M | Bug |
| 33 | Confirm `gunio-weekly` transient timer re-registration state (dies at logout by design; re-register command in `cv.md`) | Low | S | Quality |
| 34 | Sweep `data/accounts.json` staleness (last write 2026-10-01 18:11) — probe freshness is the profile-probe's job; confirm the probe still updates it | Low | S | Bug |
| 35 | Decide whether deploy smokes should run a PSI gate of their own (postpone render legs above the same threshold row 780 picks) | Low | S | Quality |
| 36 | Add `checks.any-count`-style evidence: record the `nix build` store-path equivalence check (unit ExecStart == fresh build) as a reusable deploy-currency probe in the runbook | Low | S | Documentation |
| 37 | Backfill the 2026-10-08 lock-move into CV's CHANGELOG (SystemNix-facing note) if CV conventions want lock bumps recorded | Low | S | Documentation |
| 38 | Annotate the `ef1ce387` hold era in `docs/gotchas-archive.md` (incident narrative closure for the hold) | Low | S | Documentation |
| 39 | Evaluate a `systemd` unit-state textfile exporter so agent sandboxes can read timer/unit outcomes without journal access | Low | M | Feature |
| 40 | After Q1 lands: add the 2026-10-08 activation to the deploy-log narrative trail (one-line appendix in the closest deploy log or the incident note) | Low | S | Documentation |

**Harvest status (canon obligation):** items 2, 3, 5, 7, 8, 10, 11, 12, 13, 14 are the §f direct follow-ups of THIS report — deliberately NOT rowed at authoring time because `TODO_LIST.md` is mid-edit by a parallel session (hot-file discipline). This paragraph is the explicit "not harvested because X" record the canon requires; the harvest pass is owed immediately after `TODO_LIST.md` settles.

## g) Questions I cannot answer myself

1. **What activated `cv-server` (build `cv-b2cab45`) at 09:23:57 today, outside the `deploy.sh` log trail?** I tried: deploy logs (none before 09:49), `ps` START + server uptime math (both say 09:23:57), unit-file inspection, journal (blocked in my sandbox). Next forensic step would be `/proc` (now gone — process is the current one) or the `.crush/crush.db` session query, which you asked me not to run. This decides whether the deploy-governance rule needs closing (item 9) and whether the breadcrumb wording (item 10) says "deploy" or "manual switch".
2. **Deploy train ownership:** is the parallel session still driving deploys (11:37/11:52/12:04 were theirs), and should I re-run `nix run .#deploy` after the tree settles, or stay off the train entirely?
3. **ChatService groq:** wire a `groq_api_key` into the sops `cv-env` template (needs the key value from you, entered interactively per the secrets rule), or set the chat provider disabled in `cv.nix` settings? This is the pre-documented 2026-09-17 owner decision that leaves a permanent warn on `/health`.

---

*Then waiting for instructions.*
