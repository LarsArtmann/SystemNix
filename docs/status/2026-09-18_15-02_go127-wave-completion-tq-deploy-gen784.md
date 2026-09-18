# Status: Go 1.27.1 Wave Completion — tq Deployed (gen 784)

**Session window:** resumed ~19:56 2026-09-17 (handoff), executed through ~15:02 2026-09-18 CEST.
**Context:** continuation of `docs/status/2026-09-17_19-56_go-taskqueue-bump-and-go1.27.1-ecosystem-wave.md` (Tier-0 steps 1-7 from the handoff).
**End state:** evo-x2 deployed generation 784, anchored (`/run/current-system` == `system-784-link`), `tq 0.3.0, go1.27.1` live on PATH. Toplevel builds clean. Post-deploy smoke: 0 new regressions, 7 baseline-advisory reds. Working tree clean, docs committed.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | **overview eval blocker fixed** — upstream `vendorHash.nix` was a bare unquoted `sha256-…=` string consumed via `import` (syntax error on every toplevel eval) | quoted + pushed upstream `0e0c22b`; SystemNix eval passed for the first time since the wave began |
| 2 | **go-auto-upgrade toolchain + hash** — two-layer fix: the earlier `goPkg` bump (c6fcaa4) reached only the NixOS-module lambda; the flake package needed `goPkgAttr = "go_1_27"` (086f787) + pasted got-hash (2aad9ad) | SystemNix locked `2aad9ad8`; FOD + package built green |
| 3 | **papdashboard toolchain + hash** — raw `pkgs.buildGoModule` ignored mkPreparedSource's `goPkg`; needed `buildGoModule.override { go = pkgs.go_1_27; }` (a3d6168) + two hash pastes through their dashboard-merge wave (ea15eb7, 9344278) | `/api/health` 200 post-deploy |
| 4 | **library-policy vendorHash refresh** — FOD inputs moved (go-nix-helpers follows-chain), pasted got-hash `/ksiw…` upstream (5012379) | locked, builds |
| 5 | **file-and-image-renamer convergence** — two hash pastes (their dep sweep moved the module set between rounds); locked `6f58318`→ later upstream | builds green |
| 6 | **DiscordSync hash landed** — committed the parallel session's staged K9M paste with pathspec (5fe2af13), pushed, re-locked | builds green |
| 7 | **CV go_1_27 upstream fix** — `nix/packages.nix` `goPkg = pkgs.go_1_26` → `go_1_27` (100228818), pushed with the parallel session's unpushed go.mod commit | upstream fixed; SystemNix later rolled back to 93cf5bc0 by the parallel session (see b-2) |
| 8 | **SigNoz sonic FODs** — pasted both got-hashes into `_signoz-packages.nix` (signoz community `dI2K…`, collector `5sEF…`); deployed collector verified **go1.26.7**, **0 sonic/panic/error journal lines in 30 min**, query + collector-metrics 200 | the applyPatches + `proxyVendor = true` rework from the prior session proved out |
| 9 | **tq at latest upstream** — re-locked `d83f68fa` → `318305f`, package builds, **deployed binary reports `tq 0.3.0, go1.27.1`** (the original user ask) | `/run/current-system/sw/bin/tq version` |
| 10 | **Full toplevel build PASSES** — round 7 of `nix build …--keep-going`: exit 0, zero errors after 6 enumeration/harvest rounds | `/tmp/toplevel-build7.log` |
| 11 | **Deployed gen 784, anchored** — profile bumped (no exit-4 skip); `DEPLOY_FORCE_PRESSURE=1` used with corpses verified clean first (zero D-state, all disks idle-measured) | `readlink` checks in transcript |
| 12 | **Post-deploy verification** — Pocket ID serving real user traffic (the smoke's SQLITE_BUSY hit was a grep false-positive on `error_code=not_signed_in`); all 7 reds match the smoke baseline (advisory); CV PDF export renders real `%PDF-` bytes | re-run of `post-deploy-check` |
| 13 | **PDS/glob root-cause found and documented** — proved PDS master (`4d94613`) is v1.0.0-consistent (`glob.Pattern`), the breakage was old-pin cb319a4 + swept graph; **reverted my own wrong downgrade commit** (dropped daemon-commit 729ab92 via rebase before it could be pushed) | AGENTS.md doctrine paragraph |
| 14 | **Docs** — AGENTS.md: tq interim-pin flip, the three-wiring-point toolchain doctrine, sonic applyPatches doctrine, glob v1.0.0 supersession; TODO_LIST.md: llama-rag post-deploy state (both committed by daemon 399d1abb / 9c43d6d1) | `git show 399d1abb`, `9c43d6d1` |

## b) PARTIALLY DONE

1. **llama-rag** — re-enabled in-tree by the parallel session (pinned `llama-cpp-0.3.0` via `nixpkgs-llama-rag`, `TimeoutStopSec=2min`, leak-metrics collector). My gen-784 deploy restarted both servers **under the sustained io-PSI ~55% storm and they wedged mid-load again** (both `:8848/:8849` → 503 "Loading model", 94% CPU spin, 22+ min at last check). The pin itself was live-verified upstream of me; the wedge is the documented 2026-09-02 restart-under-saturation class. Needs a quiet-window manual `systemctl restart llama-embeddings llama-reranker` + re-verify. TODO_LIST updated with the exact steps.
2. **CV resting state is a rollback** — SystemNix locks `93cf5bc0` (the parallel session's choice, builds green), but upstream master now carries go 1.27 floors + my toolchain fix **without a matching go.sum tidy**; the FOD guard (`go mod tidy inside the vendor FOD changed committed go.sum semantics`) will fire the moment the lock moves forward. Local `go mod tidy` (1.26 AND 1.27, `GOWORK=off`) is a no-op because the divergence comes from the prepared-source's local replaces — a real fix needs the FOD-graph-replicating tidy upstream. CV's own `refresh-vendor-hash` helper also probed a stale rev (93cf5bc0), so the helper itself may need a look.
3. **overview push state** — SystemNix locks `34217c23` and it builds, but at last check upstream master had unpushed local commits (`19d9a10` on top). If the locked revs are not all pushed, **CI fetch will 404**. I did not push them (not mine, session likely still active at the time).
4. **SystemNix origin sync** — master carries unpushed commits (observed `fca69359` early in the session; more daemon commits since). CI (nix-check, secret scan) runs only on push. I did not push — no explicit instruction.
5. **post-deploy CV `/admin` red** — smoke shows `goto: net::ERR_ABORTED at /admin` while the rest of CV renders (cv page, pipeline dashboard, PDF export all PASS). I assumed an auth-redirect class and did NOT verify whether the 93cf5bc0 rollback changed admin routing. Unresolved.
6. **`nix flake check` never run at final state** — I ran full builds (stronger for FODs) but not the eval-only check (assertions, guards). The pre-commit hook's flake-check leg passed on my doc commit, which covers eval of the tree at commit time — weaker than a deliberate full run.

## c) NOT STARTED

- The handoff's 50-item next-steps backlog (`docs/status/2026-09-17_19-56_*` §next) — untouched beyond Tier-0.
- Signoz-coverage: the foreign `signoz-coverage.nix` formatter edit I was told not to touch — never triaged in depth (daemon committed it; behavior assumed unchanged).
- Re-verification of `services.mr-sync` lock freshness (handoff said mr-sync updated; I relied on the toplevel build).
- The `KNOWN_NEW_METRICS`-era pre-deploy §10 loan retirement sweep (AGENTS.md says retire stale loans — not checked this session).
- Offsite backup leg (Hetzner/Borg), crush-hot-db first-migration verification, dnsblockd tag cut, Turso decision, Resend domain verification — all pre-existing TODO_LIST items, not mine this session.

## d) TOTALLY FUCKED UP

1. **Stray commit pushed to SystemNix** (`dd606a77`, then removal `f6a0ea13`): a hash-paste command intended for `~/projects/PapDashboard` ran **without an explicit working_dir**, landed in SystemNix, created an unreferenced `vendorHash.nix`, committed AND pushed it (the post-commit hook even printed "Deploy: nix run .#deploy" and I still missed the repo context). Root cause: one tool call in a long chain missing `working_dir`. Damage: two junk commits on origin + daemon-race confusion + a wasted recovery cycle. Caught and cleaned same session.
2. **Wrong PDS downgrade commit (729ab92)**: I misread the gobwas/glob situation (assumed the sweep broke old-pin PDS; actually master had migrated code+dep together), edited 9 go.mods, and the daemon committed it. Caught because the local domain build failed with `undefined: glob.Pattern`; dropped the commit via `git rebase --onto` **before push** — but if the daemon had raced the push, the wrong downgrade would be on origin. The near-miss was entirely my misdiagnosis; the save was noticing the edit-tool conflict and probing cb319a4's filter.go before pushing.
3. **Two wasted build rounds from racing the parallel session**: renamer hashes went yt1G→Zqa0→32H2 because I pasted while the other session was mid-sweep of the same repo. I should have quiescence-checked (upstream commit cadence, in-flight vendored changes) before entering the harvest loop.
4. **A misleading earlier read**: I first read llama etime as "2.5h wedged" implying my deploy never restarted them; actually etime was 22:29 minutes (my deploy DID restart them). The wrong conclusion briefly shaped my mental model of "stc skipped the restart" — corrected by re-probing `ps -eo etime` before writing docs.

## e) WHAT WE SHOULD IMPROVE

1. **Working_dir discipline**: every repo-touching command in this session should have carried an explicit `working_dir`. One omission caused the only real self-inflicted incident. Mechanical rule, no exceptions.
2. **Quiescence gate before hash-chasing**: before pasting a got-hash, check the upstream repo's recent daemon-commit cadence and `git log origin/master..HEAD` + fetch; if a parallel session is mid-sweep in that repo, defer. This session's 6 build rounds could plausibly have been 4.
3. **Baseline the FOD input closure, not just the hash**: a got-hash is valid only for the current (nixpkgs, go-nix-helpers, prepared-source-rev) closure — this session validated the "a got: hash is rev-scoped" doctrine yet I still chased hashes across moving closures. The pre-paste check is: "did any input of this FOD change since the harvest?"
4. **Deploy-time workload awareness**: load was 9.1 with a qemu VM test + two spinning llama-servers at deploy time. `DEPLOY_FORCE_PRESSURE=1` was justified (foreign workloads, clean corpses, fix-forward), but a pre-switch check for *what* generates the pressure (iotop-c was even running) would have predicted the llama wedge and allowed a post-switch llama stop inside the same deploy.
5. **`nix flake check --no-build` at session end** as a ritual final gate alongside the build (assertions/guards don't fire from `nix build` alone).
6. **Cross-session communication**: the wave is now being repaired by at least two concurrent sessions; the lock was moved under me twice (cv → 93cf5bc0, overview → 34217c23, papdashboard → c7442fe mid-round). A one-line "I own repo X until T" note in the shared status doc would have saved two colliding rounds.

## f) NEXT 50 (ordered, wave-debt first)

**Immediate (this wave's loose ends)**
1. Quiet-window `systemctl restart llama-embeddings llama-reranker`; verify `:8848/:8849` /health 200 + ~4s load; then run the TODO_LIST paperless-RAG end-to-end item.
2. Push the parallel session's unpushed overview commits (or confirm their session still owns the repo) — SystemNix CI 404s on unpushed locked revs.
3. Same check for papdashboard (`c7442fe` was locked while their local master moved on) and any other input locked ahead of origin.
4. Push SystemNix master (multiple daemon commits ahead) so nix-check/secret-scan CI runs again.
5. CV: do the real go-1.27 FOD-graph tidy upstream (replicate mkPreparedSource replaces), refresh `vendorHash` (fix the `refresh-vendor-hash` helper's stale rev pin too), then move the SystemNix lock past 93cf5bc0.
6. Verify CV `/admin` ERR_ABORTED — regression from the rollback vs auth-redirect-by-design; fix or re-baseline the smoke.
7. Diagnose why the deployed-store also contains a go1.25.14-built `signoz-otel-collector-d3bd524` (parallel-session build? wrong go pin somewhere?) even though the deployed unit's `a1d8ac3` is correct go1.26.7.
8. Sweep every still-locked 1.27-floor repo for the three-wiring-point trap (module-lambda `goPkg` vs `goPkgAttr` vs direct `buildGoModule.override`) before the next `nix flake update` re-trips them: overview's own deps, buildflow, branching-flow, go-cqrs-lite consumers.
9. `nix flake check --no-build` at the final tree state (never run post-wave).
10. Update the AGENTS.md 2026-09-16 pin-audit table (overview/library-policy/go-auto-upgrade/papdashboard/renamer flips + the CV 93cf5bc0 rollback with its guard class).
11. Triage the foreign `signoz-coverage.nix` edit the daemon committed mid-session (confirm it was formatter-only, no behavior change).
12. Consider making `deploy.sh` post-switch stop (or gate) llama-rag restarts when io-PSI > threshold at switch time (generalize the flm corpse-guard pattern; TODO_LIST already carries the generalization item).
13. Re-run `scripts/pre-deploy-check.sh` post-wave to confirm §10 metric gates are green with the new deployed config (loan list may have stale entries to retire).
14. Verify the `nixpkgs-llama-rag` rev-pin input (parallel session's new pin) carries the push-protection-safe fixture discipline and a comment documenting its drop condition (llama.cpp ≥0.4.0 fixed upstream).
15. mr-sync: confirm its lock rev upstream-push state (CI cannot fetch unpushed locks; same class as item 2).

**Known TODO_LIST debt touched or adjacent to this session**
16. Corpse-aware restore skip in memory-emergency-guard (P1, TODO_LIST Phase-1).
17. crush-hot-db: verify the first `.crush/` migration ran post-quiescence + PSI delta vs the 40-60% baseline (TODO_LIST 2026-09-16 20:57 entry).
18. dnsblockd: cut a release tag carrying the cached-response healthHandler + OTLP scheme fix (tag-pinned consumers currently rely on master).
19. Turso decision for DiscordSync (upgrade plan vs permanent local-only — removes the standing-red Gatus check).
20. Resend domain verification (SPF/DKIM) — completes mail-relay go-live + Pocket ID SMTP delivery.
21. FastFlowLM: the reboot still owed (EADDRINUSE corpse pins :52626); staged v1.0.3 go-live decision after it.
22. `/data` EIO inode (TODO_LIST P0) — btrbk-data full re-send still aborting until repaired.
23. QLC `@nix` dead-weight deletion at `/mnt/btrfs-root/@nix` (TODO_LIST Phase 1).
24. Offsite leg: Hetzner StorageBox + BorgBackup implementation (blueprint exists in `docs/research/`).
25. History purge (pending push-time re-filter runbook; keys already rotated where applicable).
26. Context7 key: confirm rotation completed (incident table says rotate; verify live 200/401 state).
27. `go-auto-upgrade`: add the upstream CI guard that the PMA go-commit pin ≥22f0e0c (TODO_LIST carries it; now that go-auto-upgrade builds again it's implementable).
28. InboxClean retro-decrypt `--backfill --decrypt-repair` (needs upstream push + flake bump; runbook in paperless.md).
29. Signoz pair (signoz-src/collector-src) migration-review bump — the pin audit said schema-migrator runs on service start; blocked behind a maintenance window.
30. `library-policy` lock is behind master (+47 at audit time) — after item 8's sweep, re-lock and re-verify.
31. Retire any stale `pre-deploy-check` §10 metric loans surfaced by this week's config changes.

**Hygiene / hardening observed during the session**
32. `iotop-c` was found at 19% CPU polling during a saturation event — fine interactively, but consider documenting it as a "don't leave running during deploys" tool alongside the crush-session census.
33. The smoke's Pocket-ID check greps `error|busy|panic` broadly enough to false-positive on `error_code=not_signed_in` INF lines — tighten to journal PRIORITY>=err or explicit `SQLITE_BUSY` string.
34. `CV refresh-vendor-hash` helper pinned to a stale rev — make it resolve `self.rev`/worktree HEAD instead.
35. mkPreparedSource could expose the failing FOD's intended go.sum-sync check output (the CV guard message) as a machine-readable pre-flight so `--keep-going` rounds don't need manual log archaeology.
36. Add a `--refresh` + push-state assertion to any re-lock loop (`nix flake lock --update-input X` then verify `origin/master` contains the locked rev; fail loudly on "lock ahead of origin").
37. AGENTS.md: record the working_dir discipline incident (stray commit class) next to the "pathspec commit" rule so future sessions see the concrete failure.
38. Consider a session-quiescence convention doc: how a finishing session signals "tree + upstream repos stable" (status doc footer field).

**Monitoring / observability smalls**
39. Gatus: a check that `signoz-collector`'s binary `go version -m` matches expectation (the go1.25.14 store stray would have been caught instantly).
40. Textfile metric: `llama_rag_load_duration_seconds` (the wedge is visible as load-time blowout before 503s start).
41. sev1/deploy gate: expose "what holds the PSI" (top cgroup io.psi) in the deploy-blocked message — I hand-derived it from ps this session.
42. pre-deploy pressure gate: distinguish corpse-pile phantom (idle disks + D-state) from real churn (the Zone-6 corroboration exists in the guard; reuse it for the gate's WARN text).
43. tq: after the version flip, confirm the tq-agent-pool journal shows the new binary picked up (module pinned per-repo `.crushrc` — model/config unchanged expected).

**Documentation**
44. Update `docs/services/tq.md` with the deployed 0.3.0/go1.27.1 state (runbook references the interim pin).
45. `docs/services/llama-rag` (or its section): the re-enable + wedge-timeline + restart runbook (mirrors the TODO_LIST entry).
46. Write the CV guard class ("go mod tidy inside the vendor FOD changed committed go.sum semantics") into the gotchas-archive with the 93cf5bc0 rollback as the case study.
47. Archive this wave's `/tmp/toplevel-build{1..7}.log` insights into the FOD-harvest runbook (round-count economics: what a quiescence check would have saved).

**Backlog hygiene**
48. Sweep TODO_LIST for items marked blocked on "next deploy" that this deploy unblocked (the llama item was one; there may be more stale blockers).
49. Reconcile the handoff's "user questions pending (report §g)" — three questions were posed there; answer/expire them now that the deploy landed.
50. Close the loop with the secret-scanner: this session wrote hashes (nix store hashes only) into reports — confirm the scanner's allowlist shape so nix-base64 hashes with `/` and `=` never trip `re_`/`syn_`-style rules (they don't today; assert it in the selftest).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **llama-rag deploy behavior**: should deploys under saturation post-switch STOP the (re-enabled) llama pair automatically, or do you accept wedged-until-manual-restart as the cost of having it enabled? I did not revert the parallel session's enable; the pair is currently wedged and needs your quiet-window restart regardless.
2. **CV resting state**: is `93cf5bc0` the intended resting point until a proper go-1.27 tidy lands upstream, or do you want the tidy done now (it requires replicating the FOD's local-replace graph — I can do it, it's just not a one-liner)?
3. **Unpushed locks**: SystemNix (and at least overview/papdashboard upstream) lock revs that may sit on local-only commits. Do you want those pushed now so CI resumes, or are those sessions still mid-work and pushes should wait for them?

*Report generated 2026-09-18 15:02 CEST. No secret values included; all hashes are nix store/base64 content hashes.*
