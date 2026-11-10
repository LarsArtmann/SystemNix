# Status Report — deploy-rescue session (the 2026-11-10 DOA-deploy stack)

**Date:** 2026-11-10 13:3x
**Session:** dispatched with the 09:47 `nix run .#deploy` failure paste ("error: expected a set but found a function: lambda @ customisation.nix:873")
**Result:** the deploy LANDED — `/run/current-system` anchored on
`p9vr42mq…-nixos-system-evo-x2-26.11.20261105.f9a75f4` == `system-996-link`
(formal readlink comparison, both sides identical). Post-deploy smoke exits 3
(one NEW regression-signal failure: `llama.cpp Embeddings` on 8848 — fleet
still settling; 170 PASS / 7 FAIL / 4 SKIP / 16 WARN). One eval-time unit
FAILED and stays red: `post-crash-calm-gate` (60-min timeout, below).
**Concurrent sessions:** a sibling SystemNix session (timesheets/invoices
wave, report `2026-11-10_06-25`) was executing the same eval-fix loop all
morning; four more `crush -y` sessions were live on the box. Attribution per
item below.

## a) FULLY DONE (verified this session)

| # | Item | Evidence |
|---|------|----------|
| a1 | **Root cause #1 diagnosed + fixed: patchelf overlay poisoned ALL nixpkgs bootstrap stages.** The 05:00 restore overlay (`patchelf = prev.patchelfUnstable`) breaks stage evals because `pkgs/stdenv/linux/default.nix` `stageFun` passes `inherit overlays` into `all-packages.nix` PER STAGE, and patchelfUnstable's fetchFromGitHub src cannot evaluate where stage fetchurl = `fetchurl/boot.nix`. The sibling session's `isFunction` guard was ineffective (stages see patchelfUnstable as a fully-applied callPackage derivation). Fix: gate on `prev.stdenv.name == "stdenv-linux"` (final set only). | my commit 779c65a67; full `--show-trace` at ~/.cache/systemnix-eval/deploy-eval.log; deploy-app eval green post-fix (real store path) |
| a2 | **Root cause #2 diagnosed: offline-banner module-shape error** (`services` + `config.assertions` mix in the exported module — unifyModuleSyntax throw). Built a per-module shape scanner (~/.cache/systemnix-eval/scan-modules.nix, replicates the unifyModuleSyntax allowlist + recurses imports) that localized it to the offline-banner export chain. FIXED BY THE SIBLING SESSION (a93db7373, moved the assignment into `config.services…`) seconds before my bisect landed; scanner confirms CLEAN post-fix. | scanner output "offline-banner:anon-1:anon-1:anon-1: unsupported attrs: services" pre-fix; zero INVALID rows post-fix; toplevel eval green |
| a3 | **Root cause #3 diagnosed: darwin brave removal.** nixpkgs f4a03c00 removed brave AND has no Chromium-family browser on aarch64-darwin (chromium + ungoogled-chromium + vivaldi all `platforms = linux`; HM extension mgmt does not work with Google Chrome). Fix: park `programs.chromium` behind `(builtins.tryEval pkgs.brave).success` — a bare `pkgs ? brave` is TRUE for removed-package throw aliases (probed). First attempt (`ungoogled-chromium`) was wrong for darwin and reverted. Darwin eval green. | my fix in f301c9534 (daemon sweep); darwin eval rc=0 at ~/.cache/systemnix-eval/darwin-4.log; nixpkgs browser.nix `platforms = lib.platforms.linux` read at the pinned rev |
| a4 | **Root cause #4: orphaned lock floats.** The daemon committed flake.lock floats without their expected-locks rows (cv at 09:36) and floated timesheets past the sibling session's probe-proven rev onto a broken-upstream rev (e415cd3a: upstream flake unions `./go.sum` they deleted). My `nix run .#float-register` ran the ceremony properly: adopt → keep-going toplevel proof → proof RED surfaced the offline-banner error → rows reverted per contract ("never commit an unproven float"). The sibling session then completed adoption (96bafa7bc, 2eedca6ff lineage). | float-register log rc=1 with the module error; the 09:36 lock diff (cv node) vs empty registry diff |
| a5 | **Root cause #5: the nixpkgs f4a03c00 patchelf regression itself is NOT coverable by any consumer-side overlay.** hermes-agent's overlay is a PURE ALIAS for their own legacyPackages-built package (`nix/overlays.nix`: "NOT a re-instantiation against the consumer's nixpkgs") — first deploy died at `nh os switch` on patchelf-0.15.2 (hermes pm-packages #672 patch fails 4/6 hunks on 0.15.2). Additionally the fix commit 59acc3d9 is ALREADY INSIDE patchelfUnstable's snapshot (verified via bare-clone ancestry: merge-base --is-ancestor), so NO external patchelf value can satisfy their patchelfFixed overrideAttrs — passing patchelfUnstable would fail the patch as already-applied. | deploy-run.log lines ~904-934 (patchelf-0.15.2.drv, src/patchelf.cc.rej); ancestry probe; hermes nix/overlays.nix + nix/pm-packages.nix:60 read at the pinned rev |
| a6 | **The pin revert ceremony: nixpkgs re-landed on f9a75f41** (the deployed system's own pin; patchelf 0.19.2 default verified by `nix eval github:NixOS/nixpkgs/<rev>#patchelf.version` for both candidate revs). I first patched nixpkgs_9 → 1d060086 (also 0.19.2); the sibling session simultaneously re-floated to f9a75f41; I converged on theirs (better target: minimal closure delta, the running system proves it). Lock + registry + overlay LIFT landed together (daemon-swept as 6c67ddf48 + 2eedca6ff; tombstone correction mine, 34504c318). | lock diff nixpkgs_9 only; toplevel eval green at 26.11.20261105.f9a75f4 (toplevel-6.log); overlay LIFT tombstone in overlays/linux.nix |
| a7 | **Root cause #6 fixed: project-meta vendorHash re-stale.** The pin re-land moved the shared Go toolchain project-meta builds with → go-modules FOD content changed (spec HfNEpdS, got hmFRcgHq, first-hand from the deploy's keep-going enumeration — the ONLY root failure of deploy attempt 2). Shim re-staled per the established protocol. Second deploy attempt then reached the switch. | my commit 1e83dc58d; `nix build .#packages.x86_64-linux.project-meta` green; deploy-run-2.log hash-mismatch lines |
| a8 | **Full eval health restored:** `nix flake check --no-build --all-systems` rc=0 (check-7) after re-stamping README (nixosModules 150→153, gatus 286→295) + FEATURES (modules 150→153, packages 50→52, audible-sync row 🔧→✅ per its own completed go-live checklist — real sops secret verified at platforms/nixos/secrets/audible-sync.yaml). Three doc-counts assertions + one features-drift row, each re-derived against live eval truth, provenance appended in the house style. | flake-check-7.log rc=0; the doc-counts/features-drift error sequence (checks 2→6 of ~/.cache/systemnix-eval/flake-check-*.log) |
| a9 | **The deploy landed:** attempt 3 (deploy-run-3.log) passed the battery (check 0 "running nixpkgs == pinned nixpkgs" ✓ — the pin-mismatch advisory from attempts 1-2 is gone), built the toplevel (5206→5251 paths, +120 MiB), switched, provisioner convergence ran (incl. the two new `timesheets-backup-dir` / `invoices-dashboard-backup-dir` provisioners the sibling session wired), and `/run/current-system` == `system-996-link` == p9vr42mq (f9a75f4). | deploy-run-3.log; anchor comparison above |

## b) PARTIALLY DONE

| # | Item | Missing |
|---|------|---------|
| b1 | **post-deploy smoke exit 3 (regression signal).** 170 PASS / 7 FAIL / 4 SKIP / 16 WARN; the NEW baseline regression = `llama.cpp Embeddings` (localhost:8848) — llama-embeddings was still job-`waiting` in the transaction at verdict time (fleet settling under the calm-gate aftermath). Likely transient; needs a re-probe now that activation settled. | re-run `nix run .#post-deploy-check`; triage if 8848 still down (llama-embeddings is config-disabled-adjacent? — the 2026-11-03 freeze disabled llama-chat + paperless-gpt endpoints; embeddings state needs a live look) |
| b2 | **post-crash-calm-gate FAILED and stays red:** "still storming after 60 min / 241 probe(s) — refusing admission" → transaction reported failure. Deploy.sh continued (provisioner phase ran; the profile landed anyway). NOTE: the post-deploy PSI readings carry the **corpse-pile D-state phantom signature** ("PSI 52%/43% with IDLE disks, busy 1-9%" — the crash3 class), so part of what the gate chased for 60 min was phantom pressure. | decide: manual `systemctl reset-failed post-crash-calm-gate` / re-run admission now that IO calmed (PSI avg300 45→55% band, partly phantom), vs wait for the next deploy/boot to re-attempt. The gate's 60-min timeout may need deploy-awareness (see §g1) |
| b3 | **This status report.** §f harvest deliberately deferred (recorded here, not silently): the wave spans two+ sessions and the sibling session landed further module waves AFTER the switch (06079542e at 13:23: cvagent.nix 362-line rework, crm, offline-banner, lars-packages ±6, 21 files) — queueing follow-ups now would drift against a still-moving tree. Harvest after the sibling session's wave lands. | owner go-ahead |
| b4 | **Undeployed tree drift.** The deployed generation = the 12:12 tree (a1e3b3bac). The sibling session's post-switch waves (54677dff7, ffcf94af7, 06079542e — 21+ files incl. the cvagent rework) are committed but NOT deployed. The next deploy carries them. | next `nix run .#deploy` |
| b5 | **Unpushed commits:** the branch is ~20 commits ahead of origin/master (owner-gated push; never pushed by agents). | owner |

## c) NOT STARTED

- c1 CHANGELOG entry for the day's wave (patchelf overlay add→gate→lift arc, nixpkgs pin re-land, brave park, doc re-stamps, project-meta re-stale, the deploy rescue).
- c2 AGENTS.md / docs/agents updates for the two durable lessons: (1) pure-alias consumer packages (hermes pattern) are unreachable by consumer overlays — a float breaking them needs a pin revert or an upstream fix (recorded in the overlay tombstone, worth promoting to docs/agents/nix-flakes.md); (2) pin-level re-lands re-stale prepared-source vendorHashes for the whole following-consumer family (recorded in the project-meta shim comment).
- c3 TODO_LIST harvest of §f (see b3 deferral).
- c4 crm-server IO attribution: crm-server carried 67 GB cumulative IO and the box sat at PSI ~45-70% for two hours; partly phantom (b2), but the real component is unattributed (io-psi-forensics snapshot exists as the tool if the storm recurs).
- c5 Verify timesheets + invoices-dashboard services are actually LIVE post-switch (the sibling session's runbooks claim deployed; my session verified eval+build+unit-add, not live endpoint health — that is post-deploy-check territory and its smoke exited 3 on an unrelated unit).

## d) TOTALLY FUCKED UP (my own failures this session, honest list)

- d1 **Committed too slowly, three times.** The daemon swept my patchelf fix (e2aea6394), chromium fix (f301c9534), and doc stamps (bf6cc1dbe lineage) into footless heuristic commits. Per the daemon-race policy I should have committed each edit within minutes; two of the three sweeps also mixed MY files with the sibling session's, which made amend-forward WRONG (absorbing their files) — the mess was avoidable entirely by prompt PATHSPEC commits.
- d2 **Misread the lock node topology.** `.nodes.nixpkgs` is a follower-target node (1d060086, stale noise); the root pin lives at `nixpkgs_9`. I briefly pursued a 1d060086 rollback and attempted a commit in a mixed state (my patch + their concurrent float) that failed the hook's audit. `jq '.nodes.root.inputs.nixpkgs'` first, always.
- d3 **Hit the jq DIRENV file-arg trap AGAIN** (silent no-op patch, `cp` of a nonexistent file) despite the AGENTS.md entry — the first rollback patch silently did nothing; ground truth only recovered via git diff.
- d4 **Trusted, then had to disprove, a "probe-proven green" claim** (the isFunction guard, ef7875d6b). I verified everything afterward, but the correct move per the docs was to distrust the comment from minute one and re-run the probe before building on it.
- d5 **Late status-report pre-read.** The 06:25 midflight report existed and answered half my questions (what the sibling session had wired, what was never evaluated); I read it only mid-investigation. The 10-second `ls -t docs/status` should have been step 2, not step 20.
- d6 **Started deploys during live churn** (attempt 1 launched as a hermes-agent float landed; attempt 2 hit the project-meta re-stale I had not pre-probed). The quiescence protocol was applied for attempt 3 only — it should have gated attempts 1-2 too.
- d7 **rc-reading confusion:** my first two eval probes printed `rc=0` while the evals had failed (stdout/stderr interleave in the background-shell output); I initially trusted the rc line. Ground truth was re-established by foreground reruns — but the "assert WHICH question your evidence answers" rule was grazed.
- d8 **Wrong first fix for brave** (ungoogled-chromium is linux-only — platforms check came AFTER the edit). The tryEval park is correct, but I shipped a platform-infeasible substitution first.
- d9 **Typo in a permanent commit message** ("Verifit", 1e83dc58d).
- d10 **Scanner iteration cost:** my module-shape scanner needed three fix rounds (builtins.range, null call, mapAttrsToList arity) before its first useful output — the 06:25 report read would have pointed me straight at the modules under suspicion.

## e) IMPROVEMENTS (what this session's pain says the repo should do)

- e1 **Float-proof must cover pure-alias consumers.** The 04:37 float proof passed while hermes was broken by the same pin — because the proof built the SystemNix set, and hermes builds from their own legacyPackages. A proof that enumerates per-input consumer packages (hermes-agent, other pure-alias inputs) would have caught it before the deploy. Candidate: extend the §11 vendorHash preview's consumer list.
- e2 **The calm gate needs deploy-awareness.** A 60-min timeout that fails a switch transaction mid-activation (after the profile landed!) leaves the deploy "succeeded-but-red" — the gate should either extend its window while a switch transaction is pending, or the transaction should treat gate-timeout as a WARN (admission retryable) rather than a FAIL. See §g1.
- e3 **Phantom-PSI awareness in the gate.** The gate refused for 60 min partly on corpse-pile phantom pressure (post-deploy check's own classifier said "IDLE disks — D-state phantom"). If the gate can read the same idle-disk classifier, phantom storms should not count toward its timeout.
- e4 **Daemon sweeps of lock floats need the registry half.** Twice today the daemon committed a flake.lock node without expected-locks (cv 09:36; timesheets past the probe rev). The float-register automation exists; the daemon's heuristic sweep bypasses the pair-commit contract. A post-commit hook check ("flake.lock changed → expected-locks must change or match") would close the class.
- e5 **The pin-rollback playbook should be first-choice for consumer-breaking floats.** Today's fastest path to green was the revert (doctrine-sanctioned), not the adaptation overlay — and the adaptation (patchelf overlay) was provably impossible for the blocking consumer. The float doctrine's "fix the roots upstream-first, or revert" ordering deserves: revert-first when the breaking consumer is a pure-alias input.
- e6 **Five concurrent sessions on one box need an IO budget.** The storm that failed the gate was five sessions' concurrent evals/builds. Nothing coordinates them. The no-heavy-builds shim was removed by owner direction (2026-10-14) — but some cross-session build serialization (flock-scoped, not banned) may be worth revisiting.

## f) NEXT 50 (dispatch-ready items, newest-wave first)

1. Re-run `nix run .#post-deploy-check` and triage llama-embeddings :8848 (the exit-3 regression signal).
2. Decide + execute post-crash-calm-gate recovery: reset-failed + re-run admission vs ride to next deploy (b2).
3. Deploy the sibling session's post-switch waves (cvagent 362-line rework et al — 06079542e lineage, b4).
4. §g1 decision: calm-gate deploy-awareness (e2).
5. §g2 decision: nixpkgs pin endgame — stay on f9a75f41 vs re-float after hermes gates the #672 patch upstream (patchelf >= 0.19.2 conditional).
6. Land the hermes-agent upstream fix: gate pm-packages' #672 patch on patchelf version (the fix commit 59acc3d9 is already in patchelfUnstable; the patch is dead weight on any 0.19.2+ base).
7. Harvest this report's §f into TODO_LIST + domain libraries (b3, after the sibling wave lands).
8. CHANGELOG entry for 2026-11-10 (c1).
9. Promote the pure-alias-lesson into docs/agents/nix-flakes.md (c2.1).
10. Promote the pin-re-land → vendorHash-treadmill lesson into docs/agents/go-ecosystem.md (c2.2).
11. crm-server IO attribution if the storm recurs (c4).
12. Verify timesheets.home.lan + invoices.home.lan live endpoints + tiles (c5).
13. Confirm the two new backup timers fired/armed (timesheets-backup 03:20, invoices 03:50 — next window 2026-11-11).
14. Verify post-crash-calm-gate's 60-min timeout constant vs the observed 241-probe window (is 60 min even reachable under 5-session load? tune or document).
15. Add the flake.lock↔expected-locks pair-check to a commit hook (e4).
16. Audit OTHER pure-alias consumers in the tree (grep `overlays.nix`-style aliases across LarsArtmann inputs) and list which floats they shadow (e1 groundwork).
17. Re-check the 12:12-deployed generation's provisioner outcomes live (the log says restarted; the runbook says verify).
18. Confirm bank-sync fish-completions REMOVED entry is expected (the activation diff showed it removed — vendored into the new bank-sync rev?).
19. Re-run the full flake check on the post-06079542e tree (my check-7 greened an earlier tree; the sibling's 21-file wave needs its own green).
20. The 06:25 session's leftover b1-c3 items from their own report (integration-registry doc rows for timesheets/invoices — verify landed in their later commits).
21. registry-matrix regeneration check (their c2 item — `nix build .#registry-matrix` + commit the table) — confirm done or pick up.
22. README gatus-count provenance: my 286→295 entry attributes 9 endpoints to the billing wave — spot-verify the number against the integration entries (I stamped from the gate's eval truth, not an endpoint-by-endpoint diff).
23. project-discovery-daemon shim history says "DROPPED (2026-11-03 night)" — confirm upstream baked the hash (the pattern: drop must equal bit-neutral).
24. Chromium park: decide the OWNER browser story for the Mac (Chrome-with-manual-extensions? wait for nixpkgs?) — the parked module needs a human answer.
25. Consider `mkLocalDerivation`-style stage-safe fetch for patchelfUnstable (e1-adjacent: make bootstrap-stage eval of unstable inputs impossible-by-construction) — upstream-nixpkgs material.
26. The 5 crush sessions: document the concurrency reality in docs/agents (crash3 phantom + gate interplay — the 12:5x storm was multi-session).
27. Anchor-discipline automation: today's readlink-vs-996 check was manual; post-deploy-check could assert it (it may already — verify).
28. Timesheets/invoices: first nightly backup tomorrow 03:20/03:50 — check freshness markers + backup-coordination endpoints on 2026-11-11 morning.
29. hermes-github-verify provisioner: confirm it passed in deploy-run-3 (it restarted during provisioner phase; verify green).
30. offline-banner: the sibling's later edits (13:23 wave ±4 lines) — confirm the env-contract assertion still passes with the new unit env (the assertion they added this morning is self-checking at eval, but the LIVE unit env needs the gen-995-style check).
31. Sweep for remaining "probe-proven" claims without attached evidence in this week's commits (the ef7875d6b class — the docs already gate on this; an audit row for claims-vs-evidence in status reports may be worth a docs-gates check).
32. Check whether deploy.sh's exit code for attempt 3 (rc=3, smoke regression) should block or WARN given the named failure is a settling unit — the baseline-compare semantics may need a settling-window (e.g. units younger than N minutes exempt).
33. llama-embeddings: confirm whether it is intended-enabled post-freeze #41-44 (the 2026-11-03 containment disabled llama-chat + paperless-gpt; embeddings state unclear from this session).
34. io-tier allowlist: the two new backup-dir entries are allowlisted — confirm mkPoolDirUnit units SHOULD get ioTier fragments instead (the allowlist may be papering over a generator gap — e.g. give mkPoolDirUnit an ioTier arg).
35. CV Agent tile icon: verify the sibling's fix (cvagent.nix ±2 at bb7c59134) uses a pack-file icon, and the tile renders.
36. Add a status-report-first-step reminder: `ls -t docs/status | head` at session start is in AGENTS.md already — consider a hook that surfaces untracked reports at session start.
37. expected-locks.nix: consider a header note that follower-target nodes (`.nodes.nixpkgs`) differ from root pins (`nixpkgs_9`) — my d2 misread cost 20 minutes; a comment in the registry header prevents the next one.
38. git history hygiene: 20 unpushed commits with interleaved daemon attribution (6c67ddf48/2eedca6ff splits of one ceremony) — the push will fragment the rollback story; consider squash-before-push IF the owner wants it.
39. patchelf-bare clone cleanup (~/.cache/systemnix-eval/patchelf-bare) — small, but the .cache hygiene rule says sweep stale artifacts.
40. The scan-modules.nix diagnostic is reusable — consider promoting it to scripts/ (module-shape scanner as a lint-style check, catching unifyModuleSyntax violations at eval before they hit the host config).
41. Check whether nh os switch left the gate in failed state blocking FUTURE switches (post-crash-calm-gate failed → does the next switch's transaction wait on it again → 60-min fail loop? — model the repeat behavior).
42. project-meta: the re-stale was TOOLCHAIN-driven, not upstream-driven — when nixpkgs moves again, project-meta re-stales again; consider having project-meta upstream pin its own nixpkgs (non-follower) like timesheets does, ending the treadmill for it.
43. Same audit for the OTHER following Go consumers (overview, journal, inboxclean…) — which would re-stale on the NEXT pin move; pre-emptive vendorHash probes after any pin change.
44. The deploy's PATHS delta +196/-151 — sanity-review the -151 (removals expected? bank-sync completions + f4a03c00-era leftovers).
45. Confirm no OTHER unit failed in the activation besides the gate (systemctl --failed equivalent via busctl; the deploy smoke's 7 FAILs were mostly WARN-class + the named regression).
46. The 06:25 sibling session should write its completion report (their mission: timesheets+invoices deploy — DONE by this session's switch, but their report is still MID-FLIGHT-titled).
47. docs/services/hermes.md (if it exists): note the pure-alias fact + "pin reverts are the fix" for the next person.
48. The deploy-run logs in ~/.cache/systemnix-eval are session-local evidence — the durable copies per convention belong in the deploy log dir (/var/log/systemnix-deploys already has the gate/run logs — confirm attempt 3's log exists there).
49. Re-check `nix eval .#nixosModules` count after the sibling's NEXT module wave (doc-counts will trip again — expected, just re-stamp).
50. Owner decision queued from the start of this session: none new — but §g1-§g3 below are the live ones.

## g) QUESTIONS FOR THE OWNER (cannot answer myself)

1. **post-crash-calm-gate semantics:** should the gate's 60-min timeout be deploy-aware (hold the switch transaction open longer while `nh os switch` is pending, admitting late), or should its timeout failure be downgraded to WARN in the switch transaction (the profile lands anyway — today the gate failed AFTER the switch was already effective)? And do you want admission re-attempted NOW (reset-failed + start) or at the next deploy/boot?
2. **nixpkgs pin endgame:** stay parked on f9a75f41 (Nov 5, the deployed pin) until upstream hermes gates its #672 patch (patchelf >= 0.19.2), or re-float forward now and accept hermes breakage until their fix lands? I reverted per doctrine; the endgame cadence is yours.
3. **The concurrency reality:** four other `crush -y` sessions ran alongside this one today and their combined builds likely drove the IO storm the gate refused on (partly corpse-pile phantom, per the post-deploy classifier). Is the multi-session load permanent baseline you want the calm gate to TOLERATE (raise its band / extend timeout), or should heavy sessions be sequenced manually by you?

_Development note: the deploy evidence logs live in ~/.cache/systemnix-eval/ (deploy-run{,-2,-3}.log, toplevel-*.log, flake-check-*.log, scan-modules.nix, float-register.log); /var/log/systemnix-deploys/ holds the script-side run logs._
