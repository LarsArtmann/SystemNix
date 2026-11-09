# SUPERB Phase-2 Resume — F2/F3 Landed, Deploy-2 (gen-991) Live, Tail Mostly Closed

**Session:** 2026-11-08 ~22:40 → 2026-11-09 03:39 CET (resumed from the 21-52 handoff; continuation of plan `docs/planning/2026-11-08_10-44_SUPERB-upstreaming-completion-phase2.md`, tombstone EXECUTING)
**Verdict:** F2 + F3 delegated/proofed/parity-clean, deploy-2 LANDED as **gen-991** (anchor green), close-out tail ~80% done. Unpushed: 7+ commits. EXECUTED flips + CHANGELOG + push remain.

## Scope — verified vs not

- VERIFIED first-hand: all D1 close-out smokes; F2/F3 parity renders (byte-diff vs pre-delegation captures); three toplevel keep-going proofs (media-atlas ×3 revs, papdashboard, dnsblockd bot-float); flake check green ×3; gen-991 anchor by NUMBER; post-deploy NEW-failure re-probes (crm-server settled, monitor365 = known-dead row).
- NOT verified: gatus endpoint states via API (bearer-gated by design — smoke/D1 evidence used); monitor365 upstream internals (existing row owns it); the 4 monitor terminals' internals (owner scopes).

## a) FULLY DONE

1. **Owner-answer check** — no answers found (post-report commits were daemon sweeps + an unrelated CV-audit session); proceeded on conservative defaults (probe, don't touch owner terminals, hold pdd pin).
2. **D1 close-out smokes — ALL GREEN**: forgejo-runner **active/running** since ~19:01 (converged by the ensure timer exactly as designed; my first probe hit a wrong-unit-name phantom — see §d); mr-sync vHost 200 HTML + service running + `~/.cache/mr-sync` present + D1 smoke pass; nsfw stays down (by design); `/run/project-discovery/daemon.sock` live; cvagent-scan.timer armed; anchor gen-990.
3. **F2 media-atlas delegation (end-to-end)**: 908-line module read fully; rewritten as `imports = [ inputs.media-atlas.nixosModules.default ]` + site layer (PG-ro/archive-perms/key-provision convergers, fleet harden 1G/512M/2G, ioTier, backup family, integration); floated `5c6b3d46 → 3b8c7f9` through THREE rounds (see §d); parity on 14 unit renders — only designed deltas (upstream description/ProtectSystem strict/read-only form/RAF add/After reorder; ExecStart flags byte-identical; all 4 site convergers + immich-server overrides byte-identical); flake check green.
4. **F3 papdashboard delegation (end-to-end)**: 968-line module read fully; rewritten (upstream PAP_* env contract + DynamicUser skeleton; site keeps vendorHash shim L4OLuG1F — held at 287f695, tiles/icons renderer, sops gate, drift collector, integration); floated `e00e875 → 287f695`; parity on 3 units — only designed deltas; the §16 icon-pack path is the SAME store path as pre-delegation (2ipkbix8…); flake check green.
5. **Upstream fixes pushed (media-atlas repo)**: `58bb689` fitProgram type fix (nullOr str — the app's .program path, not a package); `3b8c7f9` vendor sync + templ 0.3.1100 regeneration (go build + vet + FULL test suite green before push).
6. **README gatus stamps**: lineage anchor 282→283 + headline 253→283 (the 22:40 sibling session's stamp landed half-done; doc-counts had failed the tree — fixed on sight with the check's own truth).
7. **Z1 verdict**: the 4 `go-health-dashboard_N` lock nodes are DELIBERATE module-tarball pins (discordsync rev-pin, dnsblockd + library-policy v0.13.2 — all three vendor it via mkPreparedSource deps maps); dedupe FORBIDDEN by the vendorHash-FOD doctrine; `[watch]` row queued so nobody re-attempts it.
8. **Runbook sweep**: delegation markers on crm/cvagent/media-atlas/papdashboard/health-dashboard/nsfw-classifier runbooks (revs + what moved upstream vs what stays).
9. **upstream.md ticks**: cvagent row CLOSED (module merged + delegated + VM round 9 + gen-990 live); six-repos row CLOSED 5/6 (journal stays pin-gated, templ regen unmet); nsfw telemetry row CLOSED (pin dropped, floating, delegated); nsfw TimeoutStartSec row CLOSED; **hermes premise-corrected row** (third-party NousResearch → external-contribution PR lane; re-lock 21ae0e12 already done; delegation deferred).
10. **crm alarm ExecStart string→list fix** (×2 units, the render-break class) + **string-Exec sweep row** queued (census: ~35 files remain).
11. **D2 dnsblockd decision card**: `docs/planning/2026-11-08_23-40_dnsblockd-unit-identity-decision-card.md` (unprivileged user + hot-subvol chown heal vs root override; restore-path analysis; recommendation A) + services.md row pointer.
12. **§f harvest**: 6 TODO_LIST queue rows (cvagent YAML-parse leg, media-atlas + PapDashboard minimal evals, journal LIFT probe, smoke-failures triage, papdashboard journal noise) + matching rows in upstream.md/services.md/monitoring.md (incl. the monitor-scope PSI [blocked:user] row mirroring owner Q2). Queue/library pairs, no drift.
13. **§16 scanner fix**: pre-deploy §16 read only the `environment` option attrset; the F3 delegation moved PAP_ICONS_DIR into `serviceConfig.Environment` — scanner now merges both surfaces (+ realize fallback builds the store path directly). Fix-in-scanner doctrine.
14. **Unanchored pat() fix (sibling session's check)**: "Enabled But Inactive Units" conditions matched the metric's own HELP comment verbatim (`…errors 1 if the…`) — rewritten to the anchored fail-closed pair (exists + not-0). Caught by §10 on my deploy battery.
15. **Bot-floated dnsblockd lock landed properly**: a blanket update moved dnsblockd `f57faf8 → 696c73e` (+102 revs) unregistered (blocked the tree mid-commit); my manual revert lost to a re-float race; **float-register proved it GREEN and registered it** — lock + expected-locks pair committed.
16. **DEPLOY-2 LANDED: gen-991**, anchor green (`/run/current-system == system-991-link`). Battery: 165 PASS / 8 FAIL / 15 WARN, 2 "NEW" — both triaged first-hand: **crm-server CPU 136%** = its own 01:43 restart settle window (re-probed: active, 6.6% — the documented stale-by-read class); **Monitor365 API :3001 refused** = the pre-existing 027-migration dead row (2026-10-28, `[blocked:push]` + owner decision pending — baseline drift in the smoke NEW-diff, not a regression).

## b) PARTIALLY DONE

- **Close-out tail**: runbooks/ticks/card/harvest DONE (above), but CHANGELOG entry + EXECUTED flips on BOTH plans + final push NOT done (deferred to keep the deploy moving; see §c).
- **String-Exec sweep**: crm pair fixed; ~35 files remain (row queued — deliberate, each needs parity).
- **Six-repos extraction**: 5/6 live; journal pin-gated (LIFT probe queued).

## c) NOT STARTED (this session's scope)

- CHANGELOG entry for the wave.
- `scripts/plan-marker.sh <plan> done` flips (phase-1 + phase-2 plans).
- Final `git push` (7+ unpushed commits: F2/F3 wave, doc tail, scanner fixes, dnsblockd float pair — all verified contents).
- §f.27 parity-render purge (~/.cache/parity housekeeping).
- This report's own §f items were harvested at authoring time (queue+library rows above) per the standing rule.

## d) TOTALLY FUCKED UP (honest ledger)

1. **My upstream fitProgram option was typed wrong**: `nullOr package` while its own description says "pass the flake app" — apps carry a program PATH. Broken for EVERY consumer, pushed in that state yesterday, caught by MY toplevel proof today. The gate worked; the bug was mine. Fix: eval-instantiate upstream modules with a REAL consumer shape before pushing.
2. **I pushed media-atlas module work on top of a broken-at-build rev**: 691a99f (deps bump) shipped a stale vendor tree (`go build` = 12 undefined symbols, templ 1100 class) and I floated 350dc42 without first probing the package at that rev — cost two extra float cycles (58bb689 → 3b8c7f9). Probe-before-lock is codified; I skipped it for a repo I "knew".
3. **§16 caught me at deploy time, not parity time**: I proved the rendered UNIT byte-level but never ran the cheap `--section-16-only` probe — the env-surface move (attrset → serviceConfig.Environment) was invisible to my render diff and visible to the scanner. Section probes belong in the parity protocol after any surface-moving refactor.
4. **Wrong-unit-name phantom read**: first forgejo-runner probe used the literal-dash name (nonexistent) and printed empty — nearly read as "not converged". Saved by ListUnits showing `\x2d`-escaped real names. "An empty read is never evidence" — applied live.
5. **Two amend windows lost** to sustained index.lock holds (2+ min) and **two daemon races** swallowed commits mid-flight (contents verified each time; one proper-message commit recovered by amend, one by pathspec retry).
6. **Smoke baseline drift**: Monitor365 API flagged "NEW" though it's the documented pre-existing dead service — the harness's NEW-diff baseline doesn't know about known-dead rows. Triaged, but it cost a false alarm on a deploy that was actually fine.

## e) WHAT WE SHOULD IMPROVE

- **Upstream module gate**: every new nixosModules export gets an in-repo eval that instantiates it with the consumer's REAL shape (app program paths, package options) — kills the fitProgram class at authoring time.
- **Probe-before-lock, literally**: build the input's package at the target rev before the FIRST float attempt — including "my own" repos (the vendor-sync class hides in other people's deps bumps).
- **Parity protocol += section probes**: after delegation rewrites, run the deploy's own cheap section probes (§16/§11) — render parity and scanner surfaces differ.
- **Smoke NEW-diff known-dead list**: a suppression list for documented-dead services so pre-existing failures don't read as regressions (monitor365 tonight).
- **Atomic lock-race commits**: restore+add+commit as ONE shell line (learned live); amends only when the index is verified mine.

## f) NEXT (priority order)

1. EXECUTED flips on BOTH plans (`scripts/plan-marker.sh <plan> done`) — the plans still say EXECUTING.
2. CHANGELOG entry (F2/F3 waves, D2 card, deploy-2/gen-991, scanner fixes, dnsblockd float).
3. `git push` the 7+ unpushed commits.
4. pdd root pin roll-or-hold (owner Q3; decision row queued).
5. Monitor-scope PSI verdict (owner Q2; row queued).
6. Monitor365 027-migration upstream fix + the pending owner DB-surgery decision (server dead since 10-28).
7. journal pin LIFT probe (62 commits past pin; row queued).
8. cvagent upstream VM YAML-parse assertion (row queued).
9. media-atlas upstream minimal nixos eval (row queued).
10. PapDashboard upstream minimal nixos eval (row queued).
11. String-Exec sweep, ~35 files (row queued; per-module on touch).
12. Smoke-failures triage by owner (row queued).
13. papdashboard 674 lines/min journal noise (row queued).
14. hermes external-contribution draft (row queued, premise-corrected).
15. §17 memory-throttle WARNs: monitor365 2.1M events (dead service still thrashing a watermark) + forgejo 785k + crush-daily 40k — an audit pass.
16. §18 node-exporter 524 lines/min journal-rate FAIL — classify.
17. §16 negative-test lint leg for the env-surface pair (scripts/negative-test-lints.sh).
18. Smoke NEW-diff known-dead suppression list (§e).
19. Probe-before-lock codification for module waves (§e).
20. The 2 shadow-split WARNs (browser-history/gatus unreadable — owner sudo ticket).
21. forgejo-runner boot-transaction leg verify-pending (forgejo.nix comment).
22. Purge old ~/.cache/parity renders (§f.27).
23. TODO prune pass will unmask WARNs (this session added [x] rows) — recount into the drift row.
24. dnsblockd unit-identity answer → M19-M21 migration wave (card awaiting owner).
25. Upstream-module eval gate skill/recipe generalization (§e, first item).

## g) OWNER QUESTIONS (cannot figure out myself)

1. **pdd root pin** (restated from the 21-52 report): hold at `adb9821` (proven, deployed) or deliberately roll to sibling `b36f7d8` (deps bump v0.21.1, needs a vendorHash re-measure first)?
2. **The 4 monitor terminals** (restated): they trip the deploy PSI gate via self-reported io.pressure with idle devices (verified phantom twice tonight); restart them, teach the gate to classify monitor-scope self-stall, or keep forcing per-deploy after device-idle verification?
3. **The blanket dnsblockd float I registered tonight**: a lock update moved it `f57faf8 → 696c73e` (+102 revs) mid-session; my proof was green so float-register landed it. Was that float YOURS (intended), and should blanket bot floats keep failing the audit until the ceremony runs (current behavior), or auto-register when the proof is green?

— End of report. WAITING FOR INSTRUCTIONS.
