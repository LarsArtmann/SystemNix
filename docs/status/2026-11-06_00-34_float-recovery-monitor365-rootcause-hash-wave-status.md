# Float recovery: monitor365 root-cause + 22-tool vendorHash wave + plan execution — status report

**Scope.** Report of the resume session (tombstone `crush-glm53-resume-2244`, active 22:44–00:34 CET with an idle 22:46→23:49 gap; predecessor: the 22-27 close-out + the pareto plan it authored). VERIFIED this window, live: the 23:15 deploy attempt's float proof RED root (read from `/var/log/systemnix-deploys/2026-11-05_23-15-34.log` + `~/.cache/lockfloat/float-roots-20261105-231622.md`); the cp-mode failure mechanism REPRODUCED empirically (cp -r from a store path → 0555/0444 → rm EACCES); monitor365 fix committed locally (`164e159a4`, unpushed=1); flake.lock monitor365 pinned back to proven `ebfa4056` (jq-verified); float-register proof #1 run to completion rc=1 (log `~/.cache/lockfloat/float-proof-20261106-000533.log`, 22 distinct vendorHash mismatches extracted with specified/got pairs); 14 shim edits applied to `lib/lars-packages.nix` (edit tool confirmed); fleet floor inventory + toolchain-directive + GOEXPERIMENT audits (live greps/probes); fresh-shell `go env`/`go version` probe (GOTOOLCHAIN=auto, go 1.26.8 at `/etc/profiles/per-user/lars/bin/go`); boot-list + boot-tail journal reads for the 03:05/03:13 pair; push-state + got-hash-presence check for all 22 failing repos. NOT VERIFIED / not done: the module-surface shim updates and the 3 remaining lock pin-backs are EDITED-PLANNED but NOT yet applied (interrupted by this report); float-register proof #2 not yet run (so the float gate is STILL RED box-wide); every T9/T10 runtime check (blocked behind the gate); the VM-test extension is written but never executed; PSI waiter exited (calm window arrived) but was not consumed.

---

## a) FULLY DONE

1. **Plan tombstone** — `**EXECUTING**` marker written via `scripts/plan-marker.sh` + committed (`71555841a`); the plan file additionally gained the `**Created:**` anchor line the script requires (it had only `**Authored:**`).
2. **D1 ownership check (µ1.1)** — no parallel session mid-float-procedure at resume (pgrep + status sweep); surfaced that a 23:15 owner/parallel deploy attempt had already hit the same RED (deploy log + `2026-11-06_00-08` parallel report noted).
3. **T1 root cause — FOUND, FIXED UPSTREAM, PINNED BACK**: monitor365@215cd79's `makePreparedSrc` does `cp -r <store-src> $out/<dir>` which propagates 0555/0444 store modes; the later `rm -f $out/*/Cargo.lock` (and stripGit's `rm -rf .git`) die EACCES — exactly reproduced locally on a store path. Fix `chmod -R u+w $out` committed in monitor365 (`164e159a4`, **push pending — owner gate**). SystemNix lock pinned back to last-proven `ebfa4056` via the documented `--override-input` ritual (also correctly dropped the `monitor365/storage-collector` sub-edge that ebfa4056 doesn't declare).
4. **Float proof #1 fully enumerated** — float-register regenerated the registry, ran the keep-going proof, reverted rows on RED exactly per protocol, and the per-run roots file + my awk extraction produced the complete 22-tool specified→got table (the canonical paste source, log-attributed per the 2026-10-29 rule).
5. **lib/lars-packages.nix swept (14 edits)** — 11 re-staled shims re-pinned with tonight's got values (cqrs-lint, erraudit, go-auto-upgrade, golangci-lint-auto-configure, go-structure-linter, journal, project-meta, mr-sync, project-dependency-graph, PMA, samber-linter) + 3 NEW shims (library-policy, md-go-validator, project-discovery-daemon), each with a RE-STALE comment naming the locked rev + source log.
6. **T6 fleet audits (µ6.1/6.3/6.4/6.5 + re-scope of µ6.2)** — floors: ~18 repos @1.26.x, ~110 @bare 1.27, 14 @1.27.1, ~48 @1.27.2, 6 @1.27.3; `toolchain` directives: only 2 (knowledge-graph, ChastityAPI, both go1.27.3) → the plan's "1.27.2 drop list" is EMPTY; GOEXPERIMENT: clean (the only env setting is the deliberate global `jsonv2` key-unifier, home.nix:709; repo linters deny jsonv2 usage in code — coherent policy); fork evidence: 4 auto-downloaded toolchains (go1.27.0–1.27.3) in GOMODCACHE. **Key re-scope: the fork driver was the deployed profile go (1.26.8) below the 1.27 floors — after the next deploy (go_1_27=1.27.3 ≥ every floor) auto stops downloading and the fleet converges to ONE cache key; floor-alignment drops to hygiene.** Audit entry landed in docs/agents/go-ecosystem.md.
7. **T8 DONE** — canonical incident note `docs/status/2026-11-05_go-build-storm-freeze-49-incident-note.md` (timeline incl. the overnight pair, 3 root causes, open ends) + one-line merge pointers added in-place to all five phase reports (19-50, 21-00, 21-03, 21-43, 22-21; no content rewritten) + AGENTS.md Session Discipline gained the **consumer-grep-before-env-var-change / env↔guard coupling** bullet (µ8.3+8.4).
8. **T14 µ14.1 + µ14.2 DONE, both surfaces** — GOTOOLCHAIN follow-ups row (pipeline.md:217 + TODO_LIST queue row) and fork-watch row (pipeline.md:218) ticked `[x]` with live-probe evidence; the live probe itself is a finding: `GOTOOLCHAIN=auto` ✓ but profile `go` = **1.26.8** (deployed generation nixpkgs@fe13242 lags the tree's go_1_27 pin → the exact fork driver; `go version` verify folded into post-deploy battery µ4.1). ef6bf1b51 message-debt annotated PERMANENT in the 22-27 report §b.4 (pushed history, rewrite forbidden).
9. **T23 DONE (duplicate-confirmed)** — the 03:05/03:13 8-minute boot pair = freezes #47/#48 (already ledgered by the 04-46 calm-gate report); both boot tails verified raw-traffic/zero-shutdown-marker via full boot IDs; recorded as a timeline row in the incident note. No new ledger row (correctly).
10. **T25 DONE** — merge pointer appended to the stability.md:340 deploy row (row keeps ownership of the ask).
11. **T10 µ10.1–10.3 WRITTEN** — VM test extended: hot-fmt provisions the 3 go subvols; new tripwire §7 asserts all three automounts answer (`go\x2dbuild` unit-name escaping handled for the Python driver), btrfs fs type, write-through to `/mnt/hot/users/lars/cache/*`, and the 90s mount-timeout posture. Formatted clean (`nix fmt -- <path>`, 0 changes). NOT yet run (µ10.4).
12. **Live T15 evidence captured** — first `fish -lc` after boot redirected CARGO_HOME/SCCACHE_DIR to `/tmp/bc-fallback` (login-probe beat the automount's first trigger; direct `ls` mounts fine) — the exact silent-fallback race T15 exists to measure.
13. **Docs batch committed** `1d279723e` (hook green: living-docs, gitleaks, eval-skip correctly applied).
14. PSI calm-waiter (armed twice — see d) eventually completed; io PSI avg10 was ~31–64 through the window; load 45→14.

## b) PARTIALLY DONE

1. **T1 float recovery** — the spine is done (root cause, upstream fix, pin-back, proof #1 enumeration, lars-packages sweep). REMAINING: 8 module-surface shim value updates (crm.nix:117, journal-serve.nix:73, journal-backup.nix:79, inboxclean.nix:136, mr-sync.nix:72, projects-management-automation.nix:101, discordsync.nix:53, papdashboard.nix:90 — all carry the OLD spec values, jq-verified lines in hand); NEW shim sites still to write (bank-sync at systems/evo-x2.nix:74 + mirror in bank-sync.nix:153; visionreviewd.nix:47 `.visionreviewd` pull; emeet-pixyd + overview whose packages are pulled INSIDE their upstream nixosModules — option-name discovery was mid-flight, upstream `types.package` grep returned empty); 3 lock pin-backs (art-dupl, art-dupl-src → 308d8d75…, branching-flow → d17cb1a2… — both are source-broken/go.sum-inconsistent or stale-FOD-cache classes at the drifted tips, pure CLI tools with zero option coupling, registry revs proven green at 07:04); then float-register proof #2 + iterate to green + verify the lock+registry pair commit (the false-GREEN trap check).
2. **Upstream push-state matrix** (fresh evidence for the coordination gates): upstream already bakes tonight's got hash at PUSHED tips for erraudit, go-auto-upgrade, golangci-lint-auto-configure, project-meta (their shims are bit-neutral; prune on next float cycle); baked-but-UNPUSHED: emeet-pixyd (+1), mr-sync (+7), go-cqrs-lite (+6, not baked); no local checkout: discordsync, inboxclean, papdashboard (shim at module sites is the only lever).
3. **T14** — µ14.3 (prune-done dry-run pass) not started.
4. **T22 storm runbook** — not started (S-0035 probe set already codified; the runbook wraps it).
5. **T24** — langserver count recorded (8 at 22:44); billing-block owner reminder not re-raised.

## c) NOT STARTED

T2 Phase B prepare (owner sudo; the speed win), T3 the deploy (+6 parked riders), T4 post-deploy battery + CHANGELOG, T5 builder-cap (D3 unratified), T7 Samsung watermark leg, T9 deferred eval-proof suite (hard-blocked on the float gate), T10 µ10.4 VM-test run, T11 benchmark (harness armed; no calm+idle window big enough yet), T12 name-list single-source (D4 unratified), T13 reclaim-usb (~126G), T15 login-probe measurement (evidence in hand, measurement not run), T16 speed quantification, T17–T21 hygiene tail, T26 docs-health HARVEST, T27 post-cutover re-verification.

## d) TOTALLY FUCKED UP (this session's own faults, honestly)

1. **`rg -rn` typed THREE times** — twice hook-blocked, once inside a compound command that died mid-pipe. The exact trap AGENTS.md documents (third strike host-wide, and I added strikes). The hook saved the reads; the habit is still live in my fingers.
2. **PSI waiter shipped broken twice** — first the `printf`-built script died (`invalid format char: .`, % in format string), then the heredoc rewrite had an awk bug (`avg10=avg10=64` → the `-lt` comparison never matched) — the waiter guarded nothing for ~65 minutes until I read its log. Shell one-liners built without a smoke test.
3. **Read-before-edit rejections ×5** (plan header, TODO_LIST row, stability.md, two status reports) — every parallel-writer mtime shift cost a re-read round trip; the discipline worked but I kept attempting edits on files I'd only grepped, not viewed.
4. **Commit subject 89 > 72 chars** — hook reject, rewrite round trip (same class the PMA upstream row describes).
5. **mvdan/sh panic** — associative-array syntax unsupported in the tool shell; my hashcheck probe died and had to be rewritten as a heredoc loop.
6. **Misread the registry early** — called dnsblockd's `8b5352f` "monitor365's registry rev" from a drift-diff eyeball before grepping the actual registry row (real value `ebfa4056`); caught in-session, no edit was based on it.
7. **Plan premise inherited, not challenged**: T1 was estimated as a 90-minute mechanical regen+proof+commit. Reality (as the deploy log already showed at 23:15): broken upstream FOD + a 22-tool hash wave. I verified the premise BEFORE acting (good) but the 22-27 plan's T1 row should have carried a "proof-RED branch: hash-wave protocol" pointer from the start.
8. Scratch litter: `~/.cache/lockfloat-{lock,reg}-body.txt`, psi-wait scripts/logs under `~/.cache/float-recovery/` — durable by doctrine but unpruned.

## e) WHAT WE SHOULD IMPROVE

1. **The shim treadmill is structural**: 11 of tonight's 22 pastes are RE-pastes of shims that re-stale on every float wave (some are on their 4th documented RE-STALE line). The durable fix is upstream-baked hashes on every rev (BuildFlow nix-checker auto-commit; `nix run .#update-vendor-hash` is the blessed path per the buildflow drop note) — SystemNix-side shims should be wave-emergency-only. Consider a small script: parse the newest keep-going log → emit the per-surface paste diff automatically (the extraction I did by hand tonight, twice).
2. **plan-marker.sh anchor rigidity**: it refuses plans lacking `**Created:**` — tonight's plan used `**Authored:**` and needed a header edit before the guard could run. Accept both (queued as µ-item in f).
3. **Background-waiter smoke tests**: every ad-hoc monitor script gets one known-value check before being trusted as a gate (the quote-scrutiny rule, extended to gate scripts).
4. **My rg flag hygiene**: `-rn` muscle memory needs the hook to stay on; do not weaken it.
5. **Upstream push coordination**: four repos now hold unpushed fixes that BLOCK lock-forward motion (monitor365 chmod, emeet-pixyd hash, mr-sync hash ×7, go-cqrs-lite ×6) — the float cannot converge past them until pushed; a standing "unpushed blocker" line in the daily report would keep this visible.
6. **emeet-pixyd/overview packaging**: packages pulled inside upstream nixosModules with no SystemNix-side override seam — add an explicit `*.package` override (or upstream option) so hash waves don't require upstream-module archaeology at 01:00.

## f) NEXT (up to 50, impact-ordered; 1–10 finish T1 tonight)

1. Apply the 8 module-surface shim value updates (lines verified in hand).
2. Write the bank-sync shim (systems/evo-x2.nix:74 governing + bank-sync.nix:153 mirror).
3. Write the visionreviewd.nix:47 `.visionreviewd` overrideAttrs.
4. Resolve emeet-pixyd + overview shim placement (find/set their package options; fallback = pin back to registry revs cc5f133d/b4b36c73).
5. Pin back art-dupl + art-dupl-src + branching-flow in flake.lock (registry revs).
6. Re-run float-register (proof #2; PSI-gated) — iterate stragglers to green.
7. Verify lock+registry committed TOGETHER + `git status` of the pair (false-GREEN trap).
8. Commit the shim wave (PATHSPEC, message names the proof log).
9. Post-green: T9 suite (toplevel drvPath eval, disko-samsung-tlc check, negative-test groups usertmpguard/tilecoverage, check-todo-system, treefmt --fail-on-change).
10. T10 µ10.4: build the VM test, fix reds.
11. OWNER: push monitor365 `164e159a4` (unblocks the pin-back lift: update-input + re-proof).
12. OWNER: D2 → run `sudo bash scripts/migrate-go-caches-hot.sh prepare` (overnight window; PSI ~30–60).
13. OWNER: T3 deploy (`nix run .#deploy`) once float green + Phase B done; then `finalize`, anchor check by generation NUMBER.
14. T4 battery incl. the NEW `go version` == 1.27.3 verify (µ4.1 extension) + CHANGELOG.
15. T7 Samsung watermark leg (tlc-side usage guard for unbounded go-build).
16. T5/D3 builder-cap (flock wrapper; the last freeze-#49 lever — owner declined PSI gate).
17. T22 storm runbook in stability.md (wrap the S-0035 probes + containment ladder).
18. T11 benchmark in the next calm window (harness armed; add USB leg).
19. T12/D4 name-list single-source refactor (5+ surfaces; tonight's AGENTS bullet is the interim guard).
20. T14 µ14.3 prune-done dry-run (rev-pinned WARN A/B).
21. T15 login-probe latency measurement (bc-fallback evidence already captured).
22. T16 warm/cold build probes + lint fast-only trial + shared-cache hit verify.
23. T13 reclaim-usb after soak (~126G back; stale-env `/proc/*/environ` sweep first).
24. Push coordination for emeet-pixyd/mr-sync/go-cqrs-lite unpushed fixes (owner).
25. Shim-prune pass for the 4 upstream-baked tools on the next float cycle.
26. plan-marker.sh: accept `**Authored:**` as anchor (small PR to this repo).
27. Keep-going-log → shim-diff helper script (kills the hand-extraction treadmill).
28. emeet-pixyd/overview: expose package override seams.
29. Append the vendorHash-wave leg to the incident-note timeline (it's the third stacked failure of the night).
30. CHANGELOG entry for the float wave + GOTOOLCHAIN ticks + incident merge.
31. Monitor365 runbook note: preparedSrc chmod fix + the pin-back drop condition.
32. T17 ec-hub 54G refill attribution; 33. T18 ~/.cache regrowth wave 2; 34. T19 /tmp cleaner residue; 35. T20 upstream rows (BuildFlow naming, ghostty io_uring, go-taskqueue sqlite); 36. T21 skill notes; 37. T26 docs-health HARVEST (188 unharvested §f reports — validator WARN live); 38. T27 post-cutover re-verification; 39. scratch cleanup under ~/.cache/float-recovery; 40. billing-block owner reminder (T24 residue); 41. GOTOOLCHAIN purity-predicate single-sourcing row (TODO_LIST:953) still open; 42. LIFT-watch: expected-locks pin-back rows (monitor365/art-dupl/branching-flow) need drop-condition comments in the float commit message — done in 8/6 above; 43. dq check that no daemon sweep landed flake.lock or lars-packages.nix mid-edit before the proof-#2 commit; 44. verify the 22-27 §g→D1–D4 mapping is answered where owner decisions landed (D1 resolved: agent, in-flight); 45. expected-locks header regen-note (the file's own lineage comment) refreshed with round-10; 46. kill/close stray session background jobs at close-out; 47. feed the /tmp-bc-fallback observation into the buildcache dead-mount redirect design (direnv smart-lib already warns — log the events?); 48. the parallel 00-08 dio report is UNHARVESTED (validator flagged) — its session owns it, do not poach; 49. re-run `scripts/check-todo-system.sh` after the next TODO edits (structure green as of 00:0x); 50. after deploy: `nix run .#pre-reboot-check` before any planned reboot (house rule, part of T3).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Push authorization**: may I push the four unpushed upstream fixes (monitor365 `164e159a4` — mine; emeet-pixyd, mr-sync, go-cqrs-lite — parallel sessions' work) so the lock can float forward past them, or do you want to review/own those pushes? (My standing rule: never push without an explicit ask; without pushes the pin-backs + shims carry the box indefinitely.)
2. **D3 builder-cap**: ratify the flock slot-cap shape (max 2 concurrent golangci-lint fleet-wide, wired where the direnv cache guard already redirects) or defer? It is the only remaining freeze-#49 lever after the owner declined the PSI gate.
3. **D4 name-list single-source**: refactor the 5-surface blessed-cache name list now (rides tonight's momentum, ~100 min) or keep the consumer-grep rule as the only guard until after the cutover has soaked?

---
**Self-harvest note (deliberately minimal):** §f items 1–10 are the in-flight T1 sweep (owned by the plan's EXECUTING annotations, not new asks); 11–25 map to existing rows (stability.md:337/340/341/342, storage.md, pipeline.md, upstream.md) or the plan's T-table; 26–28 are genuinely new small asks — queued here for the next HARVEST pass rather than editing TODO surfaces mid-red-float (the tree is one edit away from a clean proof #2; TODO edits can wait for green).

**Next action on resume:** finish §f 1–5, launch float-register proof #2.
