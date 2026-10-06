# Deploy Unblock: paperless-gpt lambda call-shape + MaxMind/GeoMetrikks go-live support

**Session window:** 2026-10-06 ~21:35–22:10 CEST
**Author session:** MaxMind-credentials Q&A + deploy-block diagnosis (Crush)
**Tree state at authoring:** HEAD `5fa91613` (heuristic daemon commit), `M docs/todo/services.md` (foreign session, in-flight), my fix swept into `5fa91613` (content-verified).

---

## Session narrative (30 seconds)

User asked how to add MaxMindDB credentials to GeoMetrikks → answered from the runbook + module source (config was pre-wired; only the sops values were missing). Clarified `MAXMINDDB_USER_ID` = **numeric Account ID**, not email (verified against upstream `GilbN/geometrikks` README + `docs/configuration.md` via Sourcegraph). User pasted keys into `platforms/nixos/secrets/geometrikks.yaml` out-of-band. Advised `nix run .#deploy` (a bare `systemctl restart` would serve the OLD rendered env — the sops yaml is store-baked). The deploy was **BLOCKED** by the pre-deploy gate: `nix flake check` failed on `checks.x86_64-linux.paperless-gpt` — a parallel session's test file declared `{ inputs }:` while its caller passes `{ pkgs inputs; }`. Fixed the one-liner, verified eval + full flake check + alejandra + the full pre-deploy gate (76 passed / 9 warnings / 0 failed). Deploy is now unblocked and **awaiting the owner's switch**.

---

## a) FULLY DONE

| # | Item | Evidence | Scope |
|---|------|----------|-------|
| a1 | **Diagnosed + fixed the tree-wide eval break**: `tests/test-paperless-gpt.nix:20` `{ inputs }:` → `{ pkgs, inputs }:` (caller `tests/default.nix:41` passes `{ pkgs inputs; }`; signature now matches the sibling-test convention — `test-browser-history.nix`, `test-caddy-mint.nix` all declare `{ pkgs, inputs }:`) | Pre-deploy output error text; after fix: `nix eval .#checks.x86_64-linux.paperless-gpt.name` → `"vm-test-run-paperless-gpt"` | `tests/test-paperless-gpt.nix` (1 semantic line) |
| a2 | **Full `nix flake check --no-build --keep-going` green** on the fixed tree (exit 0, zero error lines) — the `--keep-going` enumeration-first critical rule was followed on the first blocked deploy | `/tmp/flakecheck.log`, exit code captured in-session | whole flake |
| a3 | **Repo-canonical formatting applied + verified**: alejandra normalized the file (it had landed pre-`fmt`); `alejandra --check` passes; `git diff -w` confirms style-only beyond the one-liner (13 ins / 16 del, all lambda-collapse style) | in-session diff + check output | `tests/test-paperless-gpt.nix` |
| a4 | **Full pre-deploy gate re-run green**: `nix run .#pre-deploy-check` → **76 passed, 9 warnings, 0 failed, "safe to deploy"** | `/tmp/predeploy.log`, exit 0 | deploy gate |
| a5 | **MaxMind go-live guidance delivered with verified facts**: keys pre-wired in `modules/nixos/services/geometrikks.nix:377-403` (sops keys + env template + restartUnits); paste path via `sops` editor (fish_history leak rule); `MAXMINDDB_USER_ID` = numeric Account ID (upstream-verified) | `docs/services/geometrikks.md:122-129`; Sourcegraph on `GilbN/geometrikks` | no code changes |
| a6 | **Daemon-race discipline held**: content-pin before edit (`b7665ca1`), foreign in-flight files left untouched, post-sweep verification of `5fa91613` (8-file heuristic commit; my file content-verified inside it; NO amend — would have absorbed the parallel session's files) | `git show 5fa91613 --stat` | git hygiene |
| a7 | **Self-harvest executed at authoring time**: the new eval-breaking + unformatted instance appended to the existing pipeline row on BOTH surfaces (`TODO_LIST.md:434` + `docs/todo/pipeline.md:165`) with Source pointer to this report | those two files, this session | queue + library |

## b) PARTIALLY DONE

| Item | Works now | Remaining open | Blocker | Effort |
|------|-----------|----------------|---------|--------|
| **GeoMetrikks MaxMind go-live** | Keys pasted by user into `geometrikks.yaml` (user-confirmed "done"); all Nix wiring pre-existed; deploy gate green | The deploy itself + post-deploy verification (`journalctl -u geometrikks` must show ingestion started, NO `Cannot start ingestion … GeoLite2-City.mmdb`) | **Owner runs the switch** (`nix run .#deploy`); I do not deploy (owner-gated, P01 posture) | S (minutes, post-switch) |
| **The fix's permanence** | Working tree + swept into `5fa91613` (committed, pushed? unknown — did not check remote state) | Whether a human-readable commit message should replace the heuristic one (it rode with 7 foreign files — amending is prohibited by the daemon-race rule) | Policy: heuristic sweeps stay as-is unless owner asks | S |

## c) NOT STARTED (this session's vantage; no research beyond session evidence)

- **The deploy train itself** — owner-gated; carries ~15 landed-but-undeployed fixes (polkit, vendorHash wave, thermal-pstate rung, forgejo gate, geometrikks, netbird, indexer-web, macbook rename… per `docs/planning/2026-10-06_16-59_PARETO-1PERCENT-EXECUTION-PLAN.md` P01). Priority: **Critical** — this session unblocked exactly this.
- **Post-deploy geometrikks verification legs** — ingestion journal line + map data + the queued smoke-probe extensions (see f-items; already queued rows exist).
- **CARTO basemap key** — optional user-gated step 3 of the runbook (`carto.com/basemaps/apikey`); keyless tiles work today. Unknown whether the user did it.
- **Root-cause gating of the call-shape class** — I fixed the instance; the gate (why pre-commit/daemon commits admit an eval-BREAKING nix file) is queued, untouched.
- **VM RUN of `checks.x86_64-linux.paperless-gpt`** — eval-verified only this session. The test semantics did not change (signature fix only), and the owning session reported it GREEN on 10-03; CI's next push exercises the run. Deliberately not run here (heavy, PSI-gated posture).

## d) TOTALLY FUCKED UP

1. **The tree was eval-RED tree-wide for hours and nobody deployed.** Severity: blocked EVERY deploy (the entire P01 deploy train). Root cause: `tests/test-paperless-gpt.nix` (committed 10-06 20:54/21:00 by a parallel session) had a lambda-signature mismatch with its call site. Workaround: **none possible** — fixed in-session. Aggravator: the boot-speed session (21:31 report) OBSERVED the break, correctly declined to co-edit foreign in-flight work, flagged it — and then both sessions waited. Two agents watching a one-line fire is worse than one agent causing it.
2. **The broken file ALSO bypassed formatting AND eval gates on commit.** `tests/test-paperless-gpt.nix` landed pre-`nix fmt` (alejandra --check failed on the pre-fix file) AND eval-breaking, through the daemon/pre-commit path — same class as the queued 2026-09-19 geometrikks.nix incident, now with a WORSE failure mode (not cosmetic: deploy-blocking). Harvested into the existing pipeline row (a7).
3. **Two failed units on the live host** (observed in pre-deploy check §6): `nix-build-cleanup.service` ("builder PID dead, no writes >1h") and — ironically — `service-health-check.service`. Not investigated this session (out of scope per instruction). Needs triage; a dead service-health-check means the safety net it names is down.
4. **Monitor365 (9191) + cv (8098) metrics not responding** at gate time (pre-deploy §10 warnings) — the gate flags them, gatus pats will go absent. Unknown whether pre-existing-known or fresh rot; NOT investigated (scope).

Nothing in this session's own work is in the fucked-up column — the honest caveat: my first `--keep-going` verification pass had sloppy exit-code plumbing (`$?` after a `grep|head` pipeline measured head, not nix; printed a meaningless "EXIT: 0"). Caught it, re-ran with proper capture (`FLAKE CHECK EXIT: 0`). Cost: one wasted cycle, one ambiguous signal that I refused to trust. Lesson encoded in §e.4.

## e) WHAT WE SHOULD IMPROVE

1. **Fix-on-sight rule for tree-wide eval breaks.** A session that observes `nix flake check` red tree-wide should fix a *signature-trivial* one-liner immediately (with content-pin + attribution note) rather than deferring to "the owning session" — the ownership courtesy cost hours of deploy blockage. Nuance: mid-flight UNCOMMITTED foreign work still gets the hands-off treatment; this file was COMMITTED (20:54/21:00), i.e. the owning session had finished. The rule needs that distinction written down.
2. **Gate the call-shape class at commit time.** `tests/default.nix` is the single import fan-out for every test file; a cheap pre-commit/CI leg could `nix eval` each import site (or a selftest that imports every test file with the exact args `tests/default.nix` uses) so `{ inputs }:`-vs-`{ pkgs inputs; }` drift dies at commit, not at deploy.
3. **Daemon commits bypass pre-commit legs — the class needs a structural answer** (queued; this session adds instance #2 and it was eval-BREAKING, not just fmt). Candidate: daemon commits run the flake-check leg post-commit and revert+alert on failure.
4. **Exit-code plumbing discipline in my own verification loops**: capture the real binary's exit (`RC=$?` immediately, or `PIPESTATUS`), never `$?` after a pipeline; a "green" that measures `head` is wallpaper. Applies to every future gate re-run.
5. **Pre-deploy §6 failed-units warning should name the ACTION**: `service-health-check.service` failed is a safety-net outage — the check could escalate it from ⚠ to a listed triage row with `journalctl` first-line. (The gate correctly didn't block — but a failed health-checker deserves louder billing.)
6. **Cosmetic**: pre-deploy output printed the `=== Pre-Deploy Validation ===` banner twice in the user's paste (observed twice now — banner duplication in `scripts/pre-deploy-check.sh`, likely a double-invocation or a re-echo; one-line fix, queued below).

## f) Top things to get done next (evidence-grounded, ranked; ✱ = already queued elsewhere, no new harvest)

| # | Task | Impact | Effort | Category | Disposition |
|---|------|--------|--------|----------|-------------|
| 1 | **Run the deploy train** (`nix run .#deploy`) — gate is green; ~15 fixes flip live | Critical | S | Deploy | owner-gated; deliberately not harvested (P01 owns it) |
| 2 | **Post-deploy geometrikks verify**: `journalctl -u geometrikks \| grep -i 'ingest\|GeoLite2'` → ingestion started, no `Cannot start ingestion`; map populates | Critical | S | Verify | folds into ✱ queued smoke-probe row (TODO_LIST:651 already carries the MaxMind assert leg) |
| 3 | **Execute the queued geometrikks post-deploy smoke probe** (unit + `/health/ready` + provision line + OIDC allow-list surface + MaxMind leg) | High | M | Quality | ✱ already `[ready]` TODO_LIST:651 + services.md:221 |
| 4 | **Gate the test-call-shape class** (selftest importing every `tests/default.nix` site, or pre-commit eval leg) | High | M | Quality | **NEW — harvested** into pipeline.md:165 this session (a7) |
| 5 | **Investigate why daemon commits bypass the eval/fmt legs** (instance #2: test-paperless-gpt.nix, deploy-breaking) + pick structural fix | High | M | Bug | ✱ extends existing pipeline row (updated this session) |
| 6 | **Write the fix-on-sight rule** for committed-but-broken tree-wide evals into CONTRIBUTING/multi-agent doctrine | High | S | Documentation | **NEW — harvested** into pipeline.md:165 wording |
| 7 | **Triage `service-health-check.service` FAILED** — the health-checker being down is a safety-net outage | High | S | Bug | not harvested this session (no diagnosis evidence yet; gate output only) |
| 8 | **Triage `nix-build-cleanup.service` FAILED** (builder-PID dead class) | Medium | S | Bug | same — gate output only |
| 9 | **CARTO key decision** (optional basemap keyless-today risk) | Medium | S | Decision | user-gated step 3, ✱ covered by services.md:151 blocked:user row |
| 10 | **Check whether CI (`nix-check.yml`) caught the 20:54 break on push** — if it ran red and nobody looked, that's an alerting gap; if it didn't run, why | High | S | Quality | not harvested (needs remote/Actions inspection — owner-visible) |
| 11 | **Sweep for other pre-`fmt`-committed nix files** (`alejandra --check` over the tree; geometrikks.nix + test-paperless-gpt.nix are two known) | Medium | S | Cleanup | ✱ extends existing row |
| 12 | **Post-deploy re-baseline of the metric warnings** (monitor365 9191, cv 8098 — real or known-absent) | Medium | S | Verify | post-deploy task; ✱ smoke-baseline stamps row is adjacent |
| 13 | **Fix the doubled `=== Pre-Deploy Validation ===` banner** in pre-deploy output | Low | S | Cleanup | **NEW — harvested?** No: cosmetic, zero-risk-of-loss; deliberately not harvested (one-line polish, fold into any pre-deploy script touch) |
| 14 | **Replace/amend heuristic commit 5fa91613 message** — it carries the deploy-unblocking fix under "auto-commit 8 changed file(s)" | Low | S | Git hygiene | deliberately not harvested: amend forbidden (absorbs foreign files); note stands here |
| 15 | **geometrikks ingestion data-plane Gatus check** (fail-closed on empty pipeline) | High | M | Feature | ✱ already `[ready]` services.md:222 |
| 16 | **geometrikks OIDC scripts fixture as flake check** | Medium | M | Quality | ✱ already `[ready]` services.md:223 |
| 17 | **geometrikks docker-era volume removal** after ≥48h green | Low | S | Cleanup | ✱ already `[watch]` services.md:152 |
| 18 | **bank-sync Wise SCA approval** → clears deploy smoke red | Medium | S | User step | ✱ already `[blocked:user]` services.md:218 |
| 19 | **Verify the sops paste structurally** (key names present + non-empty in `geometrikks.yaml` metadata — NOT values) before/at deploy | Medium | S | Verify | deliberately not harvested: the deploy's journal check (item 2) proves it end-to-end; a pre-check duplicates the proof |
| 20 | **Confirm `5fa91613` lineage pushed** (deploy pulls from working tree, but remote drift matters for CI legs) | Medium | S | Git hygiene | not harvested (single `git status`-class check, owner's push cadence owns it) |
| 21 | **Pre-deploy §6 escalation leg**: failed `service-health-check` renders a journalctl first-line in the gate output | Low | S | Quality | not harvested (design opinion; fold with item 7 triage) |
| 22 | **P01 follow-through rows**: polkit GUI-auth fix, vendorHash wave, thermal rung, forgejo gate, root-prune-guard, caddy batch, netbird, indexer-web — ALL ride the deploy; verify each post-switch per the plan's smoke re-baseline | Critical | M | Verify | ✱ owned by the Pareto plan doc (P01), not duplicated here |
| 23 | **Post-deploy `niri` desktop smoke** (polkit fix rides this train — GUI auth should resurrect) | High | S | Verify | ✱ P01 post-deploy leg |
| 24 | **Paperless 3.2.x ride verification** (3.1.3→3.2.1 flips on this deploy; AI env + dashboard checks) | High | S | Verify | ✱ already queued services.md:34 |
| 25 | **Update `docs/services/geometrikks.md`** go-live step 2 with the live outcome (keys pasted DATE, ingestion line observed) once item 2 lands | Low | S | Documentation | deliberately not harvested: premature until the deploy proves it; fold into item 2's close-out |
| 26 | **Record the `MAXMINDDB_USER_ID` = numeric-Account-ID fact** in the geometrikks runbook (upstream-verified this session; cost a Sourcegraph roundtrip that the runbook could save) | Low | S | Documentation | deliberately not harvested (one-line doc polish; owner permission for trivial on-sight fixes covers it at next runbook touch) |
| 27 | **Decide the amend-or-leave policy for my fix riding a heuristic sweep** — codify: heuristic sweep + content-verified = leave; document in CONTRIBUTING daemon-race section | Low | S | Documentation | not harvested (policy opinion pending owner §g.3) |
| 28 | **GH Actions: does `nix-check.yml` run on the daemon's frequent pushes, and is failure alerted?** (item 10's deeper form) | High | M | Quality | not harvested (needs Actions triage first) |
| 29 | **Add `git diff -w` style-only verification to the fmt-sweep playbook** (this session's alejandra run touched 193 lines of a foreign file; the `-w` proof is what made it safe — write the pattern down) | Low | S | Documentation | not harvested (pattern note; fold into fmt-sweep task when run) |
| 30 | **Post-deploy: confirm geometrikks `restartUnits` fired on the sops rotation** (secret change → auto-restart; validates the wiring claim) | Medium | S | Verify | fold into item 2's close-out journal capture |
| 31 | **Watch the parallel session's `M docs/todo/services.md`** — it was dirty at authoring; expect its commit; do not co-verify silently | Low | S | Hygiene | standing multi-agent discipline, no row needed |
| 32 | **Re-run `nix run .#pre-reboot-check` before any planned reboot** this train might motivate (boot-mirror is live; §11 audited) | High | S | Safety | standing rule (AGENTS.md), no row needed |
| 33 | **Empty-column check**: after items 1–3, flip the MaxMind `[blocked:user]` go-live row to done on BOTH surfaces (services.md:151 + TODO_LIST) with journal evidence | Medium | S | Documentation | ✱ the row exists; flip is item 2's bookkeeping |
| 34 | **Confirm no OTHER test files have outer-lambda signatures diverging from their `tests/default.nix` call** — one awk/grep pass over the fan-out (cheap class-sweep beyond item 4's gate) | Medium | S | Quality | not harvested: superseded by item 4's gate IF gate lands; do the manual pass only if the gate stalls |

(34 items — evidence-bounded to this session's observations per instruction, not a repo audit; the repo's full open-work inventory lives in TODO_LIST.md + docs/todo/*.)

## g) Questions I cannot answer myself

1. **Did you paste the CARTO key too, or MaxMind only?** Determines whether item 2's post-deploy verification should also expect the basemap banner gone, or keyless tiles (current de facto). I cannot infer it from the repo — the encrypted file hides values by design, and you said "done" without specifying scope.
2. **Fire the deploy train now?** The gate is green, but the train carries ~15 fixes (polkit GUI-auth resurrection, paperless 3.1.3→3.2.1 migration, forgejo gate, thermal rung…). That blast radius is a switch-moment decision only you can make (P01 §g explicitly packages this as an owner question).
3. **Gate policy call: pre-commit eval leg vs CI-only for test call-shapes?** A pre-commit `nix eval` leg costs seconds-to-minutes on EVERY commit (and the daemon bypasses it anyway — see item 5); CI catches it only at push latency. My recommendation is the selftest-inside-`nix flake check` (zero new gates, catches at the same place CI does, plus locally at flake-check time) — but the commit-latency tradeoff is yours.

---

**Verification anchors (this session):** pre-fix HEAD `b7665ca1`; fix swept into `5fa91613` (22:01:14, heuristic, 8 files — content-verified via `git show --stat` + working-tree grep); `nix flake check --no-build --keep-going` exit 0; `nix eval .#checks.x86_64-linux.paperless-gpt.name` → `"vm-test-run-paperless-gpt"` (twice: post-fix, post-reformat); `alejandra --check` green; `nix run .#pre-deploy-check` → 76 passed / 9 warnings / 0 failed (exit 0).

**Format note:** `.md` at the user-named path — explicit-instruction override of the skill's HTML-canonical default (flagged per skill contract; not propagated as a default).

**Harvest disposition summary:** items 4, 5, 6 harvested into `TODO_LIST.md:434` + `docs/todo/pipeline.md:165` (both surfaces, one row, no dated sections). Items 1, 2, 9, 15–18, 22–25, 33 deliberately not re-harvested: already queued (owner-gated or existing rows). Items 7, 8, 10, 19, 20, 21, 26–32, 34 deliberately not harvested this session: no diagnosis evidence beyond gate output yet, standing rules already cover them, or they are trivial on-sight polish — reasons recorded inline above per the self-harvest contract.
