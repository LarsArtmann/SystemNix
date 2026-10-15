# VendorHash Unblock Execution — Mid-Flight Status (23-shim wave vs a moving lock)

**Date:** 2026-10-15 03:49 CEST
**Session scope:** execution of the 03:05 diagnosis report's step 4 (deploy unblock), after the owner's "nix switch?" green light. **The deploy is NOT done; shims are written but NOT yet validated against a moving lock.**
**Predecessor report:** `docs/status/2026-10-15_03-05_vendorhash-fleet-wave-diagnosis.md` (root cause, fix layers, first harvest) — this report covers execution progress only.

---

## a) FULLY DONE

1. **Complete consumer-surface map for all 23 failing tools** (the two-surface sweep, `docs/agents/go-ecosystem.md:20` protocol): `lib/lars-packages.nix` flakePkg entries; 8 direct `inputs.<tool>.packages` module surfaces (crm, cv, discordsync, papdashboard, inboxclean, health-dashboard, mr-sync, project-discovery-daemon, PMA); and a THIRD surface class discovered and handled — `mkPackageOption pkgs "<tool>"` options resolving through the input overlays composed in `overlays/linux.nix` (crush-daily, overview, file-and-image-renamer). No config-side package overrides exist, so module-option defaults are live and needed their own shims.
2. **11 fresh got-hashes probed first-hand** (fakeHash `overrideAttrs` probes against the input flakes, zero tree edits): erraudit `sKya91ES`, golangci `YmWGO9br`, go-auto-upgrade `D5DnebMF`, go-humanize-linter `ZenhGNkk`, go-structure-linter `O2hpYHSc`, buildflow `cCl3IWhu`, branching-flow `0IxhvfLi`, discordsync `UnFb4VRS`, crush-daily `AAXq+KGA`, go-health-dashboard `IRv9RBXa`, file-and-image-renamer `nN2cwwLQ`. Cross-checkable against the 11 pairs transcribed from the 02:46 nh enumeration (library-policy, kith-crm, inboxclean, meta, mr-sync, overview, pdd, PMA, samber-linter, pdg, papdashboard).
3. **23 vendorHash shims WRITTEN across 10 files**, all attrset-form `overrideAttrs` (the `.override` dead-end class), all citing first-hand evidence: `flakePkgShim` helper + 14 shimmed entries in `lib/lars-packages.nix`; re-pins/Adds in crm.nix, discordsync.nix, papdashboard.nix, inboxclean.nix, health-dashboard.nix, mr-sync.nix, project-discovery-daemon.nix, projects-management-automation.nix; new `fleetVendorHashShims` overlay (crush-daily, overview, file-and-image-renamer) appended AFTER `crushDailyDoCheckGate` in `overlays/linux.nix` (ordering rule respected).
4. **§11 false-green caught and recorded** (3rd instance of the blindness row, `docs/todo/pipeline.md:59` — row updated this session): the 02:46 deploy failed 23 FODs; §11 minutes later reported "23 uncached go-modules FOD(s) built clean" — a *different* 23. Trusting §11 would have green-lit a broken deploy. The real oracle is the toplevel `--keep-going` build.
5. **cv re-classified twice, ending shim-fixable:** `0750bd6` = go-sum GUARD failure (consumer-unfixable; the local tidy route failed on floor 1.27.1 vs nixpkgs go 1.26.8, then on private-submodule resolution needing git/auth in a bare env) → the third lock float landed `aa637cbf` where the guard is GONE (upstream tidied) and cv is a plain mismatch: shimmed `p7sOpco6…` first-hand. The `--keep-failed`/tidy infrastructure became unnecessary. CV row in `docs/todo/upstream.md` annotated same session.

## b) PARTIALLY DONE

1. **The unblock itself.** All 23 shims exist in-tree but **~12 were invalidated by a THIRD lock wave (~03:39) before ever being built**: cv, erraudit, golangci, go-auto-upgrade, go-humanize-linter, go-structure-linter, buildflow, discordsync, crush-daily, go-health-dashboard, project-meta, pdd, samber-linter, inboxclean all moved to new revs (checked `jq` per node). Their written values measured older revs and will mismatch again. The cure is mechanical (one toplevel keep-going pass gives every fresh specified/got pair), but it has NOT run yet.
2. **The citation log.** `/tmp/got-probe-20261015.log` was captured across the lock move — per-tool entries may mix pre/post-03:39 lock states. Needs one clean re-run at lock quiescence before it can serve as the shims' evidence artifact.
3. **Lock quiescence.** Three waves tonight (00:xx, 02:xx, 03:39; lock mtime 03:39:13, HEAD `7462d112` at 03:47). Not yet confirmed settled.

## c) NOT STARTED

1. Toplevel `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` — THE verification/enumeration oracle.
2. Re-pinning the ~12 invalidated shims from that single pass; iterating until green.
3. `nix run .#deploy` + `readlink /run/current-system` anchor verify + `post-deploy-check.sh`.
4. Wave status report + CHANGELOG row (09-21/10-07 self-document precedent).
5. Upstream paste rows with the FINAL (post-quiescence) hashes — the current values in queue rows are already stale.

## d) TOTALLY FUCKED UP

1. **Three lock waves in one night against a master-tracking fleet.** The tree is a moving target: my first 22 shim values were partially obsolete on arrival. This is the documented "measure at the TARGET lock rev, settle the lock first" trap (`docs/agents/go-ecosystem.md:40`, pdd two-round class) — I shimming-against-a-churning-lock is exactly the failure shape that doc warns about, and it cost a full re-pass.
2. **Concurrent-session churn on my own edits:** the daemon + the parallel tq session swept my in-flight files into heuristic commits (HEAD moved `5f96e462` → `efb3250e` → … → `7462d112` during the work). Content-pinning held (verified each time), but attribution of tonight's three lock waves remains unresolved — the tq session is the prime suspect for at least one wave.
3. **Deploy still blocked.** Nothing is verified; evo-x2 remains on the pre-wave generation.

## e) WHAT WE SHOULD IMPROVE

1. **Quiescence gate before ANY hash measurement** — a 2-minute "lock unchanged + no new lock commits" check before probing/shimming would have saved this entire re-pass. Candidate: fold into the wave-protocol doc + the §11-after-lock-wave tripwire already queued.
2. **The single-enumeration discipline is right and worked**: one `--keep-going` toplevel pass yields every specified/got pair at one consistent lock state — the fakeHash per-tool probes were useful for recon but are redundant when the toplevel pass runs anyway. Next wave: go straight to the toplevel pass.
3. **§11's false-green (3rd instance)** re-proves the queued fix (derive the FOD list from the toplevel dry-run preview, `pipeline.md:59`). Until it lands, §11 output must never be trusted as "the deploy will build" for flakePkg/module/overlay-consumed tools — which tonight is MOST of the fleet.
4. **Master-tracking + active upstream churn needs a maintenance window** — floating locks while upstream pushes every few minutes makes every consumer-side hash a lottery ticket (see g/Q1).
5. The overlay third-surface class (`mkPackageOption pkgs` + input overlays) is undocumented in the two-surface sweep guidance — `docs/agents/go-ecosystem.md:20` should say "THREE surfaces" (harvested to the report record; row update queued below).

## f) Next things (execution ladder — most are continuations of the 03:05 report's §f; new/changed items flagged)

1. [CONTINUES #1] Lock-quiescence check: no lock commits + unchanged mtime for ≥10 min (g/Q1 decides whether to wait or chase).
2. [CONTINUES #1-2] ONE toplevel `--keep-going` pass → complete specified/got table at a single lock state.
3. [CONTINUES #4] Re-pin the ~12 stale shims from that table (values already in shim positions; swap hashes + rev annotations).
4. [CONTINUES #2] Clean re-run of the probe citations into `/tmp/got-probe-20261015.log` (or a toplevel-log citation instead).
5. [NEW] Repeat 2-3 until the toplevel build is GREEN.
6. [CONTINUES #5] `nix run .#deploy` → anchor verify (`readlink /run/current-system` = latest `system-N-link`) → `post-deploy-check.sh` battery (12 services get new binaries tonight).
7. [CONTINUES #7-8] Wave status report + CHANGELOG row.
8. [CONTINUES #13-14 etc.] Upstream paste rows with FINAL hashes → owner pushes → re-lock → shim drops.
9. [QUEUED, re-proven] §11 blindness fix — 3rd instance recorded in `pipeline.md:59` this session.
10. [QUEUED] CI-restoration sweep (`upstream.md` new row from the 03:05 harvest) — the structural fix; tonight's triple-float strengthens the case.
11. [NEW, harvest below] Two-surface sweep doc → three-surface (overlay class) update in `docs/agents/go-ecosystem.md:20`.
12. [QUEUED] Lock-wave tripwire / §11-after-lock-commit enforcement (`pipeline.md:395`).
13. [QUEUED] Shim-comment enumeration-citation selftest (`pipeline.md:479`).
14. [QUEUED] buildflow nix-hash-fix trial on the shim layout (`pipeline.md:392/436`).
15. [QUEUED] Everything else in the 03:05 report §f (unchanged: bank-sync ceiling, overview/bank-sync un-follow decisions, fir/misc drops, per-host §11, etc.).

## g) Questions only you can answer

1. **Who is floating the lock tonight — you, the tq session, or a bot?** Three waves (00:xx, 02:xx, 03:39). Should I treat further floats as intentional (chase HEAD, re-pin per wave) or wait for a declared pause window before the final hash pass? Guessing wrong wastes a full enumeration either way.
2. **The parallel tq session + daemon are committing my in-flight shim edits piecemeal** (heuristic 3-7-file commits). Acceptable to continue under that flow, or should I hold further tree edits until the tq session declares done?
3. **Confirm the switch is still wanted TONIGHT** given the fleet is mid-churn — deploying now pins evo-x2 to the 03:39 lock state; if another wave is coming deliberately, a slightly later switch avoids a second 23-shim cycle.

---

## Self-harvest record

| Item | Disposition at authoring time |
| --- | --- |
| §11 3rd instance (e5/§f9) | ✅ `docs/todo/pipeline.md:59` row updated this session |
| cv guard→gone supersession | ✅ `docs/todo/upstream.md` CV row annotated this session |
| Three-surface sweep doc update (e5) | Deliberately not queued as a new row — one-line doc annotation, to be landed WITH the wave's close-out docs (f7) rather than as a standalone dispatch; recorded here so it cannot be lost |
| Quiescence gate (e1) | Deliberately not queued — becomes moot if g/Q1's answer is "waves are done"; fold into the wave close-out doc instead |
| f1-f8, f10, f12-15 | Already queued at cited locations (03:05 report + pipeline/upstream rows) — no drift edits needed |

## Verification appendix (commands this session, all first-hand)

- Content-pins at each edit round: `git rev-parse HEAD` (5f96e462 → efb3250e → … → 7462d112)
- Two-surface sweep: `rg 'inputs\.<tool>\.packages' modules/ platforms/ systems/ lib/` + overlay composition read (`overlays/linux.nix:287-309`) + upstream module option grep (`services.<x>.package = lib.mkPackageOption`)
- §11: `bash scripts/pre-deploy-check.sh --section-11-only` → false-green caught (`/tmp/section11-20261015-0320.log`)
- 11 fakeHash FOD probes (background loop, conversation transcript) + 11 pairs from the 02:46 nh enumeration
- cv: `--keep-failed` probe revealed rev float `0750bd6`→`aa637cbf` + guard disappearance; local tidy attempts (go 1.26.8 floor fail; go_1_27 private-module fail) documented as dead-ends
- Lock-state audit: per-node `jq` of all 23 tool revs vs the 02:46 FOD names (12 moved)
- 23 shims written; NOT yet built — the toplevel pass is the pending oracle
