# Status report — cvagent dead-unit discovery, PATH fix, storm-gated deploy

**When:** 2026-11-04 20:46 CET
**Session:** single crush session on evo-x2, started ~20:0x as a Q&A about Code-To-CV-Agent ("what did it already do?"), escalated into live state verification, a systemic unit bug discovery + fix, and a storm-gated deploy queue.
**Scope of work:** SystemNix only (module fix, runbook, todo surfaces); Code-To-CV-Agent repo touched READ-ONLY.

---

## Scope line — what this report VERIFIES vs does NOT verify

**Verified with fresh commands/artifacts this session:**

| Claim | Evidence |
| --- | --- |
| cvagent.service has NEVER completed a cycle | `journalctl -u cvagent.service --since 2026-10-25 \| grep 'systemd\[1\]'` → exactly ONE run ever (2026-11-04 05:56:35–38), zero `done:`/success lines |
| First (and only) timer fire failed systemic | journal 05:56: `ERROR: every repository scan failed (systemic)`, exit 1, `Failed to start cvagent`, `Triggering OnFailure=` dependencies; root cause on every scan: `exec: "git": executable file not found in $PATH` on `git log -1 --format=%aI` |
| Timer IS armed and will re-fire | `busctl get-property … cvagent_2etimer … LastTriggerUSec NextElapseUSecRealtime` → last 1793768195179807 (2026-11-04 04:56:35 UTC = 05:56 CET), next 1793854569384405 (2026-11-05 ~05:56 CET) |
| No cvagent mesh artifacts ever landed in the CV repo | `ls /home/lars/projects/CV/data/cv/` → no `lars_artmann-en-cvagent.patch.json` (only the repo's own curated `*-app-*.patch.json` set); `ls data/projects-v2/` → 4 hand-curated pages (hornbach, rolls-royce, wolt, README); `git -C ~/projects/CV log --since 2026-10-30 -- data/projects-v2 data/cv` → no export commits |
| The event journal itself works | `~/.local/state/cvagent/cvagent.db` 4.9 MB; during today's failed run the per-scan journal replay counts grew 66→68→70 (failure events ARE recorded; the runbook's "empty-repo failure recording" claim is true) |
| Root cause | `modules/nixos/services/cvagent.nix:46` read `runtimeInputs = [ cfg.package ]` — unit PATH carries ONLY runtimeInputs; `Environment` sets just `HOME`. Convention check: sibling `github-auto-assign.nix:46-49` lists `pkgs.gh` + `pkgs.coreutils` explicitly |
| Fix applied + swept | `runtimeInputs = [ cfg.package pkgs.git pkgs.coreutils ]` + why-comment; daemon-swept into commit `024794b75` (10 insertions / 1 deletion, `git show --stat` verified); working tree == HEAD for the module |
| Fix evals green | `nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` → `/nix/store/21qbxf2…-nixos-system-evo-x2-….drv` (EVAL-OK; warnings in output are pre-existing, cvagent-unrelated) |
| Fix formats canonical | `nix fmt -- modules/nixos/services/cvagent.nix` → "formatted 1 files (0 changed)" |
| Fix verified at BUILD level, not just config level | built the actual unit script (`nix eval …serviceConfig.ExecStart` → `/nix/store/anvh45…-cvagent-scan-mesh/bin/cvagent-scan-mesh`, `nix build` + `head`) → `export PATH="…cvagent…/bin:…git-2.55.0/bin:…coreutils-9.11/bin:$PATH"` |
| Deploy correctly REFUSED | live `/proc/pressure/io` → `some avg10=83.03 full avg10=54.48`, `/proc/loadavg` → 95.31 (freeze-#46 storm day, parallel sessions active); tree clean of eval-relevant dirt; flake.nix/lock mtimes 20:20 (>5 min old) — quiescence heat-check FAILS on PSI alone |
| Docs + queue updated | runbook TRAP + busctl line in `docs/services/cvagent.md`; deploy row on `TODO_LIST.md` + `docs/todo/services.md` (20:44); 3 self-harvest rows queued (20:49, ledger below) |

**NOT verified here (and why):**

- **The fix in the LIVE unit** — deploy is storm-gated; build-level proof only. The timer fires again 2026-11-05 05:53; without a deploy it fails identically.
- **cvagent's complete external-binary surface** — git proven (journal + FEATURES health rows); sqlite is pure-Go modernc per FEATURES.md (source not re-read); a future CLI change could add another exec (motivates the queued eval audit, not a re-read today — out of session scope).
- **Why the 2026-11-01 smoke test didn't cover the unit** — the 2026-11-01 status reports (`2026-11-01_01-45/01-54`) were not re-read; the runbook's "verified end-to-end" claim demonstrably referred to MANUAL shell runs (user directive: no unrelated research).
- **system-health metric behavior for this oneshot** — `extraMonitoredServices` includes `cvagent`, but whether the metric actually flips on a oneshot failure was not probed (§f item 5).
- **aarch64 eval** — `nix flake check --all-systems` not run (x86_64 toplevel eval only).
- **Parallel-session work witnessed but NOT verified** — pim-sync wave reports (20:41), storage close commit `9bbbcafd3`, monitor365 tmpfiles rows: cited from queue/git tails only.

---

## Context: what triggered this session

Owner asked what Code-To-CV-Agent had accomplished (answered from its `FEATURES.md`, audited 2026-11-02), then whether it was deployed in SystemNix, then "it has no timers? event-based AI analytics?". The live-state probes those questions demanded uncovered that the deployed unit is **dead** — answered the questions AND produced the fix.

Answers delivered: (1) it HAS a timer (`cvagent.timer`, daily 05:53 ±10 min jitter, `Persistent`, next fire 2026-11-05); (2) the store is event-sourced (append-only sqlite journal, one stream per repo, self-healing read-model replay — today's failed runs still appended failure events), but the deployed pipeline is **rule-based, not AI**: `--ai` is opt-in, the unit never passes it, no `OPENAI_API_KEY` is wired.

---

## a) FULLY DONE

| Work | Evidence | Scope |
| --- | --- | --- |
| Root-caused the dead unit: unit PATH = `runtimeInputs` only, no `git` | journal 05:56 systemic failure + module line read | `modules/nixos/services/cvagent.nix` |
| Fixed: `runtimeInputs += pkgs.git + pkgs.coreutils`, why-comment added | commit `024794b75` (daemon-swept, contents verified via `git show --stat`); eval green; fmt canonical (0 changed) | same file |
| Build-level proof of the fix | built the rendered `cvagent-scan-mesh` script; its `export PATH` line carries cvagent + git-2.55.0 + coreutils-9.11 | store derivation (not yet live) |
| Runbook trap recorded | `docs/services/cvagent.md:17` — "the unit's PATH carries only `runtimeInputs`" with the 2026-11-04 incident | docs |
| Runbook agent trigger line added | busctl `StartUnit` alternative next to the `systemctl` line (agent shells ban systemctl) — fixed on sight | docs |
| Deploy row queued on BOTH surfaces (no drift) | `TODO_LIST.md` + `docs/todo/services.md`, QUIESCENCE-GATED, with post-switch verify ladder | todo surfaces |
| Timer/timer-state live verification | busctl properties read; "timer exists, fires tomorrow" answered from live state | live system |
| Event-sourced-vs-AI question answered accurately | journal event growth + unit script (no `--ai`) + FEATURES.md | live system + docs |
| Code-To-CV-Agent capability inventory delivered | its `FEATURES.md` (audited 2026-11-02): 9 commands, Go rewrite 2026-08-15, event-sourced core, web UI, golden snapshots | read-only |

## b) PARTIALLY DONE

1. **cvagent production capability** — integrated (2026-11-01) and now fixed in tree, but the service has never delivered its purpose.
   - Works: flake input + PATH package (`lib/lars-packages.nix`), timer armed (`Persistent`, next 05:53), module evals, event journal writes, per-repo WARN tolerance semantics in the script, OnFailure routing (paged today).
   - Missing: a deploy carrying the fix → first verified unit cycle (`done: scanned=6 failed=0`) → mesh artifacts in `~/projects/CV` → PMA commit → `cv-server-content-sync` ship. That final ship leg has NEVER happened for a unit-driven export.
   - Blocker: 2026-11-04 storm (IO PSI some 83%, load 95, freeze #46, SECCOMP crash loops, multiple parallel sessions). Effort to finish once a window opens: **S** (deploy + one busctl start + journal/artifact checks).

2. **External-binary safety net** — git is fixed, but the *class* is open: nothing in the prevention layers catches "unit script shells out to a binary not in runtimeInputs".
   - Done: this instance fixed; audit designed (§f item 3, queued).
   - Missing: the eval-time audit itself, the health preflight, the post-deploy §-leg. Effort: **M** total.

## c) NOT STARTED

| Planned | Why not started | Priority |
| --- | --- | --- |
| cvagent §-leg in `scripts/post-deploy-check.sh` (§f 2) | designed this session, queued; needs the fix deployed first to have something green to assert | High |
| Eval-time `runtimeInputs` coverage audit (§f 3) | new lint class, queued into pipeline.md; nothing written | High |
| `cvagent health` preflight in the unit script (§f 4) | queued; one-line change after next deploy window | Medium |
| system-health oneshot-failure metric verification (§f 5) | rides the deploy; never probed | Medium |
| Everything else already queued fleet-wide | storm day consumed the fleet's capacity (freeze #46 triage, monitor365 SECCOMP loop, tmpfiles mystery) | see TODO_LIST.md |

## d) TOTALLY FUCKED UP

1. **cvagent.service is a dead man walking — and was dead on arrival.** The 2026-11-01 integration shipped a timer whose unit could never succeed: every scan execs `git`, the unit PATH never had it. First fire 2026-11-04 05:56 failed all 6 scans systemic, OnFailure paged Discord, mesh never ran, zero artifacts in the CV repo. Severity: the service's entire purpose (grounding the CV in code reality) has been unfulfilled since integration; data loss: none (event journal intact, 4.9 MB). Root cause: unit PATH = `runtimeInputs` only. Workaround until deploy: manual shell runs — **which is exactly the blind spot that let it ship broken** (see 2).
2. **The "verified end-to-end" claim masked the breakage (process failure, mine to flag).** The runbook + CHANGELOG said "verified end-to-end 2026-11-01" — TRUE only for a manual CLI run where the shell's PATH had git; the UNIT was never smoke-tested, and nobody noticed for 3 days because the first timer fire was only this morning. This is the AGENTS.md verification-surface class ("assert WHICH question your evidence answers") applied to integrations: manual-run success ≠ unit success. The alerting layer DID work (page fired) — the gap was no first-fire verification task queued at integration time, unlike the ci-watchdog and pim-sync integrations which queued theirs.
3. **My own first answer repeated the same mistake (self-critique).** I answered "fleet citizen, verified end-to-end" from the runbook WITHOUT live-probing the unit — the exact "never assert a service capability from a doc claim alone" rule in AGENTS.md. The live journal probe only happened because the owner's follow-up questions pushed on deployment reality. Caught in-session; the discipline exists precisely because doc claims rot.
4. **Tomorrow 05:53 re-fails unless deployed** — the timer is armed against the unfixed unit if no quiescence window opens tonight; a second Discord page is the truthful outcome until the fix ships. Not a new bug; stated so nobody mistakes it for a regression.

## e) WHAT WE SHOULD IMPROVE

| Pattern | Impact | Concrete fix |
| --- | --- | --- |
| Integrations adding a TIMER queue no first-fire verification task | cost 3 dead days here (integration 2026-11-01 → first fire 2026-11-04 → failure); ci-watchdog/pim-sync did queue theirs | rule + checklist line in `docs/agents/integration-registry.md`: "timer integration = first-fire verification row queued at integration time" (§f 47) |
| Verification claims don't name their SURFACE | "cvagent works" (manual CLI) vs "cvagent.service works" (unit) were conflated for 3 days | the AGENTS.md rule exists; extend integration-registry docs with the manual-vs-unit example (§f 48) |
| Eval-time layer blind spot: PATH coverage of `writeShellApplication` scripts | one systemic prod failure; silently future-recurring for any new external binary | the queued audit (§f 3), negative-tested like its siblings |
| Runtime layer blind spot: unit never invokes the CLI's own health check | failure surfaced as 6 confusing per-repo errors instead of 1 actionable health line | queued preflight (§f 4) |
| Oneshot deploys have no post-deploy surface | a deploy that BREAKS a oneshot surfaces only at its next fire + page | queued post-deploy leg (§f 2) |
| Storm-day discipline worked — keep it | tq gate, quiescence-gated rows, refused deploy all prevented a repeat of freeze #46 | no change; the pattern held |
| Agent-shell probe discipline worked — mostly | journal `--since` midnight trap and case-sensitive grep both nearly produced false "no runs" reads; both caught in-session by re-querying (empty read is never evidence) | no change; discipline reconfirmed live |

## f) 50 things to get done next (ranked by impact; disposition-marked)

**HARVESTED-NOW** = queued this session into TODO_LIST.md + domain library. **QUEUED** = already in the queue, listed for completeness, NOT re-harvested. **RIDES-DEPLOY** = verification leg of the already-queued deploy row (deliberately not queued separately — see ledger). **UPSTREAM** = Code-To-CV-Agent repo owns it (its own status reports track these). **ROADMAP** = brainstorm fuel per docs-health routing, recorded here only.

| # | Task | Impact | Effort | Category | Disposition |
| --- | --- | --- | --- | --- | --- |
| 1 | Deploy the cvagent PATH fix in the first quiescence window; then busctl-start the unit, verify `done: scanned=6 failed=0`, artifacts land, anchor check by generation NUMBER | Critical | S | Bug | QUEUED (20:44) |
| 2 | Add cvagent §-leg to `post-deploy-check.sh` (unit result + `done: scanned=` + artifacts) | High | S | Quality | HARVESTED-NOW |
| 3 | Eval-time audit: writeShellApplication scripts shelling out to binaries not in `runtimeInputs` | High | M | Quality | HARVESTED-NOW |
| 4 | `cvagent health` preflight before the scan loop in the unit script | Medium | S | Quality | HARVESTED-NOW |
| 5 | Verify system-health metric flips on cvagent oneshot failure (extraMonitoredServices semantics) | Medium | S | Quality | RIDES-DEPLOY |
| 6 | After first good cycle: verify the read model replaced today's failure facts (journal 66→70 self-healing proof on the real store) | Medium | S | Quality | RIDES-DEPLOY |
| 7 | First happy-path E2E: PMA auto-commits the export → `cv-server-content-sync` ships `data/projects-v2/` on next CV deploy | High | S | Verify | RIDES-DEPLOY |
| 8 | Upstream cvagent: document/wrap the git runtime dependency (verify-before-filing gate first) | Medium | S | Docs | UPSTREAM |
| 9 | Runbook: agent-shell busctl trigger line | Low | S | Docs | DONE this session |
| 10 | Journal-growth note in runbook (failure events accumulate; ~5 MB today, bounded growth) | Low | S | Docs | ROADMAP |
| 11 | Deploy monitor365 tmpfiles `mkBefore` fix + tmpfiles-apply pre/post legs | High | S | Bug | QUEUED |
| 12 | Determine why `systemd-tmpfiles-setup` didn't re-run on gen-977/978 switches; deploy-pipeline guard | High | M | Bug | QUEUED |
| 13 | Triage monitor365-user dmesg SECCOMP crash-loop (name the unit, fix filter or drop the dmesg call) | High | S | Bug | QUEUED |
| 14 | Start tq-agent-pool in the first sub-30% PSI window | Medium | S | Ops | QUEUED |
| 15 | PMA post-deploy stale-binary standing check (running rev == pinned rev) | High | S | Quality | QUEUED |
| 16 | OTel localhost:4318 refusals — name the owning unit, check it is up | Medium | S | Bug | QUEUED |
| 17 | Freeze-#46 residual attribution (diskstats split, hermes-perms-heal convergence, foreign du pid) | Medium | M | Bug | QUEUED |
| 18 | Stalwart CalDAV authenticated round-trip probe (stale premise row) | Medium | S | Verify | QUEUED |
| 19 | Deploy the All-Backups-Healthy gatus fix (26 freshness endpoints, in tree) | High | S | Bug | QUEUED |
| 20 | Audit mkPoolDirUnit owner/mode pairing + eval invariant | Medium | M | Quality | QUEUED |
| 21 | pim-sync owner-gated flip ladder (sops values, dry-run review, live flip) | High | M | Feature | QUEUED (blocked:user) |
| 22 | indexer-web post-deploy smoke + ioTier assignment | Medium | S | Quality | QUEUED |
| 23 | paperless-tasks-collector fixture test (both 2026-10-03 bug classes) | Medium | M | Quality | QUEUED |
| 24 | buildcache-recovery VM legs: foreign-fs refusal, zombie, concurrency, mutation negative | Medium | M | Quality | QUEUED |
| 25 | Productize `scripts/fod-probe.sh <input>` + document the flake.lock node-name gotcha | Medium | S | Tooling | QUEUED |
| 26 | Upstream: commit the uncommitted 2026-11-03 humanize work (9 files were uncommitted at 23:10) | High | S | Hygiene | UPSTREAM |
| 27 | Upstream: re-propagate the `technologys` fix into exported CV-repo artifacts | Medium | S | Bug | UPSTREAM |
| 28 | Upstream: fix the "1 repos" pluralization copy bug in web goldens | Low | S | Bug | UPSTREAM |
| 29 | Upstream: `watch` two-pass E2E spec (FEATURES ⚠️ row) | Low | M | Quality | UPSTREAM |
| 30 | Upstream: web-UI accessibility audit (axe/vnu pass) | Low | M | Quality | UPSTREAM |
| 31 | Upstream: hermetic CSS rebuild (`scripts/build-css.sh` not reproducible) | Low | M | Quality | UPSTREAM |
| 32 | Upstream: CI unblock (Actions billing) | Medium | — | Infra | UPSTREAM (blocked:user) |
| 33 | Upstream: determinism E2E — two consecutive mesh runs byte-identical | Low | S | Quality | UPSTREAM |
| 34 | Upstream: AI-extraction path E2E against a mock OpenAI server | Low | M | Quality | UPSTREAM |
| 35 | Decide the scan repo list (currently 6; the projects tree holds many more) | Medium | — | Decision | ROADMAP (owner, see §g Q2) |
| 36 | Decide the extraction backend: rule-based vs `--ai` (OpenAI key vs local llama-server) | Medium | — | Decision | ROADMAP (owner, see §g Q1) |
| 37 | Decide: `cvagent serve` dashboard as an internal vHost/tile (conflicts with daemon-less doctrine) | Low | — | Decision | ROADMAP |
| 38 | Decide: rev-pin the cvagent input for build-hash stability (the `cv` input precedent) | Low | — | Decision | ROADMAP |
| 39 | Decide: backup leg for `cvagent.db` or declare it regenerable-by-rescan | Low | — | Decision | ROADMAP |
| 40 | mesh export diff-preview (review the delta before PMA commits it) | Low | M | Feature | ROADMAP |
| 41 | Per-oneshot duration metric in system-health (scan runtime visibility) | Low | M | Feature | ROADMAP |
| 42 | Decide: does the darwin host need cvagent (its repos in the CV narrative?) | Low | — | Decision | ROADMAP |
| 43 | facts-explorer tile on dash.home.lan (read-only serve behind the auth gateway) | Low | M | Feature | ROADMAP |
| 44 | Event-journal retention/GC policy (unbounded append per repo) | Low | S | Quality | ROADMAP |
| 45 | Keyword drift report: mesh patch vs curated base divergence over time | Low | M | Feature | ROADMAP |
| 46 | Check the 05:53+jitter slot for collisions with other 05:xx timers | Low | S | Verify | ROADMAP |
| 47 | Integration-registry rule: "timer integration ⇒ first-fire verification row queued at integration time" | High | S | Process | ROADMAP (process change; registry is the right home) |
| 48 | Integration-registry rule: "manual-run verification ≠ unit verification" with this incident as the example | High | S | Process | ROADMAP (same home) |
| 49 | Upstream: `cvagent mesh --dry-run` (plan-mode export) | Low | M | Feature | ROADMAP |
| 50 | Upstream: prove or retire `watch` (FEATURES lists it; no evidence of use) | Low | S | Cleanup | ROADMAP |

## Self-harvest ledger (report-authoring obligation)

- **Harvested NOW (20:49)**: §f 2 → `TODO_LIST.md` + `docs/todo/services.md`; §f 3 → `TODO_LIST.md` + `docs/todo/pipeline.md`; §f 4 → `TODO_LIST.md` + `docs/todo/services.md`. All rows cite this report as Source.
- **Harvested EARLIER (20:44)**: §f 1 (the deploy row) → both surfaces, before this report existed; rows updated to cite this report at write time? NO — the 20:44 rows cite the journal/module evidence directly, which remains accurate; no drift.
- **Deliberately NOT harvested**: §f 5–7 because they are verification legs OF the already-queued deploy row — queueing them separately would double-row one dispatch (the media-atlas battery-in-deploy-row pattern, 2026-11-04). §f 9 was fixed on sight instead of queued (trivial, understood). §f 10, 35–50 are ROADMAP fuel per docs-health HARVEST routing (brainstorm ≠ commitment; the larger N was the owner's explicit ask). §f 26–34 belong to the Code-To-CV-Agent repo, whose own `docs/status/2026-11-03_23-10` report already tracks them — cross-repo rows are not SystemNix queue material.

## Deployment ladder for the pending deploy (for the executor)

1. Quiescence: tree clean of eval-relevant changes + no eval-relevant mtime <5 min across ≥4 consecutive 60 s polls + IO PSI comfortably <30% some avg10 (storm gate) + green cheap eval probe (`nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath`).
2. `nix run .#deploy`.
3. Anchor check by generation NUMBER (`ls /nix/var/nix/profiles/ | grep '^system-[0-9]*-link$' | sort -V | tail -1`), repair + `boot` if unanchored.
4. `busctl … StartUnit "cvagent.service" "replace"` → journal must show `done: scanned=6 failed=0`.
5. `ls ~/projects/CV/data/cv/lars_artmann-en-cvagent.patch.json` + `data/projects-v2/` gained generated pages.
6. §f 5–7 legs (system-health metric, read-model self-healing, PMA/content-sync ship).

## g) Questions I cannot answer myself

See the three questions surfaced to the owner at report time: (1) extraction backend (rule-based vs AI, and which backend); (2) the CV-worthy repo list; (3) deploy policy for tonight's storm-gated window. Details inline in the question prompts — each is an owner value/risk call I cannot derive from code or docs.

---

*Then wait for instructions.*
