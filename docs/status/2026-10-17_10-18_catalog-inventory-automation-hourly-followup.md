# Catalog inventory automation session + hourly follow-up — status & self-review

**Session:** 2026-10-17, ~09:30–10:18 CEST (this exchange; the morning waves
1–3 are covered by the 08-45 and 09-28 reports — this report covers the
"how is catalog.home.lan deployed/updated + automate more" turn and the
"make it hourly" follow-up).
**Scope discipline:** report of THIS session's run + what was noticed in
passing. No new research.

## What this session built

Answered the deploy/update chain (CI → dist branch → hourly serving sync →
static vHost; verified against the runbook and live state), then closed the
one manual step left in the catalog.home.lan pipeline:

1. **`catalog-inventory-sync` timer module** (SystemNix,
   `modules/nixos/services/catalog-inventory-sync.nix`, evo-x2) —
   automated regeneration of the hub's committed `inventory.json` from the
   registry. Born daily 04:47; **owner asked hourly in the follow-up —
   now HOURLY at :47 + 15min jitter** (eval-verified:
   `OnCalendar=*-*-* *:47:00`).
2. **`CATALOG_INVENTORY_REQUIRE_ALL_HOSTS=1`** strict mode in the exporter
   (a failed host eval is FATAL, not WARN+shrink) — set by the timer so an
   automated regeneration can never silently drop a host's deployments.
3. **Exporter `--self-test`** (9 assertions through the exact production
   `UNION_FILTER`; wired as `checks.catalog-inventory-selftest`,
   sandbox-built green) — closed the queued TODO row.
4. **Hub staleness gate** `scripts/check-inventory-staleness.sh` (WARN at
   14d, `--strict` ready, 5-case `--self-test`) wired into build.sh +
   build.yml — closed the queued hub TODO row.
5. **Hourly-specific fix — the no-op write guard** in hub
   `scripts/generate-inventory.sh`: hourly `generatedAt` churn would have
   produced ~24 content-free commits/day via the auto-commit daemon. The
   guard skips the write when the export is content-identical AND the
   committed stamp is <24h old (≤1 stamp refresh/day keeps the staleness
   gate a pipeline-liveness signal). 6-case stub-exporter self-test; live
   no-op proven: "no change — kept … (stamp 1h old)".

**Verification:** `nix flake check --no-build` all green (twice — after the
module, after hourly); hub lint leg (shellcheck all scripts + dprint) clean;
both self-tests green; live `--check` = inventory up to date; live run =
no-op guard working as designed.

## a) FULLY DONE

- Deploy/update chain explanation (verified, delivered).
- `catalog-inventory-sync` module + evo-x2 enablement — landed, eval-green,
  unit shape verified (User/ReadWritePaths/Nice/idle/MemoryMax/Timeout).
- Exporter refactor (single `UNION_FILTER`) + `--self-test` +
  `checks.catalog-inventory-selftest` (sandbox-built green).
- `CATALOG_INVENTORY_REQUIRE_ALL_HOSTS=1` strict-hosts mode.
- Hub `check-inventory-staleness.sh` + build.sh/build.yml wiring + self-test.
- Hourly cadence flip (module default, option docs, timer description).
- No-op write guard + `--self-test` in `generate-inventory.sh` (6 cases,
  live-proven).
- Docs updated BOTH repos: runbook (inventory leg + Operations), hub
  AGENTS.md (bullet + ops-table row), hub README, both CHANGELOGs,
  `docs/todo/services.md` (push row stamped, deploy row added), SystemNix
  TODO_LIST close-out, hub TODO close-out + new CI-selftest row harvested.
- All "daily" references swept to hourly (both repos, 8 files).

## b) PARTIALLY DONE

- **Timer automation: landed but NOT LIVE** — the generation carrying
  `catalog-inventory-sync` is undeployed (`[blocked:deploy]` row,
  docs/todo/services.md). Until then, regeneration stays manual.
- **Everything this session: local-only, unpushed** — hub-side changes
  (staleness gate, guard) ride the `[blocked:push]` wave row; the SystemNix
  side needs the owner push too (master was already N-ahead from parallel
  sessions before this one).
- **Verification of the UNIT environment: partial** — I verified shapes by
  eval and ran `generate-inventory.sh` live, but under MY shell env, not
  the unit's restricted environment (User=lars, PrivateTmp, redirected
  XDG_CACHE_HOME). First real fire is post-deploy (row says exactly what
  to check: journal "wrote inventory.json" / "no change").

## c) NOT STARTED (session-relevant, deliberately out of scope)

- Zero-deploy registry triage (9 entries) — queued [ready], untouched.
- Hub CI leg running the scripts' behavioral `--self-test`s — noticed as a
  gap this session, harvested as a hub TODO row, not implemented.
- `systemd-run` rehearsal of the unit env pre-deploy.
- Confirming the new timer appears on timers.home.lan (systemd-timer-
  monitor) post-deploy.

## d) TOTALLY FUCKED UP (all caught in-session, none shipped broken)

1. **The previous turn's status report was never delivered.** The skills
   were loaded, the turn yielded without the report. The owner had to
   re-prompt (the hourly question arrived while the report was still owed).
   This file closes that debt ~50 minutes late.
2. **Staleness script v1 had two real bugs**, both caught by its own
   self-test run: (a) `INVENTORY_FILE`/`INVENTORY_MAX_AGE_DAYS` env
   overrides were resolved once at script START, so the self-test's
   per-call env prefixes never reached `run_check` — the "fresh" case
   passed only by accident (it tested the real repo file); (b) `exit`
   inside a function called as an `if` condition killed the whole harness.
   Fixes: per-call resolution; `return` + set -e propagation.
3. **generate-inventory.sh self-test v1 shipped unrunnable**: the function
   was called before its definition (bash ordering), and the multiedit
   that moved it left a duplicate block + a truncated closing `fi`,
   repaired by a head-truncate (the documented confounded-tool-use class).
   All caught by `bash -n`/first run — final state 6/6 green.
4. **Design miss, exposed by the owner:** I picked "daily 04:47"
   unilaterally (freeze-history caution) when the owner wanted hourly.
   Worse, the daily choice HID the generatedAt-churn problem — hourly
   would have exposed 24 no-op commits/day immediately. The no-op guard
   should have been part of v1 of ANY scheduled writer; it took the
   owner's one-line question to force the second-order churn analysis.

## e) WHAT WE SHOULD IMPROVE

- **Churn analysis for scheduled writers is a v1 concern, not a
  follow-up**: any timer that writes a timestamped artifact through an
  auto-commit daemon needs the "what does this look like at N× frequency"
  question answered BEFORE the first cadence decision.
- **Cadence is an owner-preference dimension** — when a knob has one
  (daily vs hourly), ask; do not fold it into an engineering-safety
  judgment call.
- **Self-tests earned their keep twice this session** (staleness env bug,
  definition-order bug) — but CI never runs them (syntax-only shellcheck
  leg). Harvested as a hub row; flip fast.
- **Deliver, don't load**: loading the status-report skill is not writing
  the status report.

## f) Next things (session-derived, ~25 real ones; owner rows marked)

1. **[owner] Deploy** the catalog-inventory-sync generation; then
   `systemctl start catalog-inventory-sync.service` convergence check
   (`[blocked:deploy]` row).
2. **[owner] Push** the hub wave + bank-sync/cqrs-htmx convention files
   (`[blocked:push]` row) — then verify the first nightly CI green on both
   legs + the new staleness WARN step.
3. **[owner] Push SystemNix master** (already N-ahead before this session;
   more now).
4. Zero-deploy triage (9 entries; `[ready]`, TODO_LIST).
5. Hub: wire the behavioral `--self-test`s into CI (new row, TODO_LIST).
6. Post-deploy: confirm the timer surfaces on timers.home.lan
   (systemd-timer-monitor) and its onFailure path is visible.
7. Pre-deploy rehearsal: `systemd-run` the unit env once (catches
   XDG_CACHE/Nice/ProtectHome surprises without waiting for deploy).
8. Hub: llms.txt list-formatting fix (queued row).
9. Hub: llms.txt "deployments" section decision (queued row, rides 8).
10. Hub: drift-gate `--strict` flip at 2026-10-19 if the WARN list stayed
    clean (queued row).
11. Hub: staleness gate `--strict` flip after the timer soaks (weeks).
12. Hub: `lint` blocks for bank-sync/cqrs-htmx once their `--plain` flags
    are pushed (queued row).
13. Onboard the next go-source cohort (convention files) after the push.
14. Hub [owner]: `architecture/` 404 on catalog.home.lan (host-side fix,
    queued owner row).
15. Hub [owner]: paste the ntfy topic URL into `ALERT_WEBHOOK_URL` (wiring
    is done; one paste arms failure alerts).
16. Hub [owner]: claim the EventCatalog free-use key (~2026-12-10 window;
    runbook `docs/runbooks/free-use-key-chain.md`).
17. Hub: npm audit pass + overrides drop decision (queued row).
18. Hub: ci-log polish + export-step DNS retry hardening (queued rows).
19. SystemNix: consider a gatus check for the timer's last-success age
   (complement to the CI staleness WARN — catches a dead-but-green timer
   pre-push). Only if post-deploy monitoring shows a blind spot.
20. Re-snapshot inventory once the parallel crm.nix work settles (the
   timer does this hourly after deploy — manual until then).
21. Docs: hub AGENTS "jq trap" cross-ref — the guard's stub uses `jq -n`
   with `--argjson` from env strings; if someone runs the self-test inside
   a direnv shell it inherits DIRENV_DIFF (child scripts unaffected —
   verified 2026-10-17; worth keeping the note where the fixtures live).
22. Consider `Persistent=false` review: hourly + Persistent means a
    reboot-storm catches up only one missed run — acceptable; revisit only
    if boots eat runs.
23. `catalog-inventory-sync` calendar option is unexercised by a second
    host — fine (evo-x2-only by design); note if another host ever carries
    the checkouts.
24. After deploy + first week: prune this report's §f into TODO/ROADMAP
    via docs-health (most already harvested).
25. Hub [owner]: rotate-only-when-missing token hardening (standing owner
    row).

## g) Questions I cannot answer myself

1. **Client repos on catalog.home.lan?** Rolls-Royce-mtu, Zlota44,
   SwettySwipperWeb, sec are `excluded` today; onboarding them means their
   service/message names (possibly client-identifying) appear on a
   LAN-served catalog. Confidentiality call is yours.
2. **Zero-deploy chip wording** — "not deployed" is provisional; want
   e.g. "registered, not deployed" or "no deployment"?
3. **Push/deploy ordering** — SystemNix master is N commits ahead
   (parallel sessions + this one): push first and deploy after the mirror
   sync, or deploy the timer generation immediately and push when
   convenient? (Both work; the timer only matters once deployed, the hub
   gate only once pushed — ordering is yours.)

**Standing rules honored:** all work local/unpushed (agents never push);
no secret values anywhere; every emitter carries a self-test; TODO queue +
library rows updated at authoring time (new: hub CI-selftest row; stamped:
push/deploy rows); prose cites short revs where applicable.

---

**Addendum ~10:40 — §g Q1 answered, first cohort onboarded.** Owner:
"They are actually all my projects" — the confidentiality gate is cleared
for every excluded repo. Executed: Zlota44 onboarded as source #5
(convention file + live-verified export + sources.json regen; gate clean).
The merge gate immediately caught a real class bug — quoted-empty
`version: ""` poisoning merge.py's bare-ref upgrade pass (`svc-""` ghost
refs) — fixed via `norm_version` with a selftest regression case. Remaining
cohort: Rolls-Royce-mtuGoHelpCenter-golang needs a source-side CLI export
(indirect consumer); sec + SwettySwipperWeb are not cloned locally. CI
prereq stamped into the push row: re-run setup-forgejo.sh so the
lars/zlota44 mirror exists before the first nightly including it.
