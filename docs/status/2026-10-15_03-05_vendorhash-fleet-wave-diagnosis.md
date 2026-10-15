# VendorHash Fleet Wave — Diagnosis Session (23-FOD Deploy Blocker)

**Date:** 2026-10-15 03:05 CEST
**Session scope:** diagnosis only — zero tree edits, zero shims, deploy still blocked.
**Trigger:** user's 02:46 `nh` deploy attempt failed with 23 build failures (22 `*-go-modules` FOD hash mismatches + 1 cv buildPhase exit 1); user asked "how do we fix this properly as upstream as possible?"

---

## Executive summary

The evo-x2 toplevel is **unbuildable** as of the 02:46 deploy attempt. Root cause is **NOT** the toolchain-drift class: root nixpkgs has been static at `7fd4004d` (2026-10-11) across every lock commit since 2026-10-14 (verified, 10-commit history sweep). What moved is the **tool inputs themselves**: overnight auto-commits (`a6fc86d7` → `30c3bbdf`) floated ~23 master-tracking (`?ref=master`) LarsArtmann tool inputs onto fresh upstream master HEADs, and upstream master routinely ships stale `vendorHash` because **nothing upstream verifies the Nix build**. Spot-check: erraudit has no real CI at all (only dependency-graph bot runs); cv's Go-test CI is red right now (dependabot career-pipeline bumps failing in ~5s).

`cv` is a **different, harder failure**: its FOD fired the `go mod tidy changed committed go.sum semantics` guard — upstream committed a dep-wave go.mod without the matching go.sum (reproduced first-hand, error captured). No consumer-side hash value can fix that FOD; only an upstream tidy-commit does.

This is the **8th+ fleet-wide vendorHash wave since 2026-10-01** (10-03, 10-05, 10-07 ×2, 10-09, 10-11, 10-13, tonight). Every prior wave produced the same protocol and the same treadmill verdict. The upstream-most durable fix is **restoring Nix-build CI on the private repos** — without it, master-tracking inputs guarantee recurrence on every `nix flake update`.

---

## a) FULLY DONE (this session)

1. **Root-cause class exclusion (toolchain drift ruled out).** Root nixpkgs `7fd4004d` unchanged across all recent lock commits (`git log -- flake.lock` + per-commit jq of the nixpkgs node). Trigger = input rev floats, not go/toolchain drift.
2. **Trigger surface identified.** Failing FOD names match exactly the input revs moved in tonight's lock commits (`30c3bbdf`, `bcd47bc5`, `a8b9e1e1`, `4b913e0b`, `65507c91`, `adbf7449`, `a6fc86d7`): cv `0750bd6`, kith-crm `a0341a0`, papdashboard `c8d0cf92`, buildflow `d9f63e8`, crush-daily `bc765f8`, discordsync `cac57aa`, erraudit `bb57433`, overview `4b48040`, meta `a00c6dae`, mr-sync `f1a13263`, inboxclean `7e23ec6`, library-policy `e8e3667`, project-dependency-graph `5315ae0`, project-discovery-daemon `df32945`, projects-management-automation `3149585`, samber-linter `1ab1333`, + the summary-listed remainder.
3. **cv failure correctly differentiated and reproduced first-hand.** `nix build --impure --expr '(builtins.getFlake …).inputs.cv.packages.x86_64-linux.default.goModules'` reproduced the guard: `ERROR: go mod tidy inside the vendor FOD changed committed go.sum semantics beyond the prepared (locally replaced) modules — the committed go.mod/go.sum pair is out of sync (the daemon dep-wave class)`. Consumer-side unfixable; the error text itself prescribes the upstream fix.
4. **Layered fix plan delivered, upstream-most first:** (1) restore upstream Nix-build CI (deploy-key recipe proven 2026-09-16, `docs/agents/go-ecosystem.md:24-30`); (2) per-repo vendorHash convergence — paste upstream → owner push → re-lock → drop shim (waves 3–8 protocol); (3) cv upstream tidy + go.mod AND go.sum committed together; (4) consumer-side `overrideAttrs { vendorHash = …; }` shims at BOTH surfaces as the NECESSARY bootstrap exception to unblock tonight.
5. **cv consumer wiring located.** `modules/nixos/services/cv.nix:56-58` — shim `XLIgHM1V…` re-added 2026-10-14 @ `0ad2a6b`; now dead at `0750bd6` (and would stay dead even with a fresh value until upstream tidies).
6. **TODO_LIST.md:866 verification row — 3 of 4 legs closed:** erraudit shim EXISTS (`lib/lars-packages.nix:104-113`, `LzoxcvFT…` @ 492c233 — now stale at `bb57433`); crm shim EXISTS (`crm.nix` consumer-side, `AtAQS+x0Oj…` @ a410024b — tonight's kith-crm mismatch shows exactly that value as *specified*, i.e. stale at `a0341a0`); cv shim EXISTS (`cv.nix:56`, stale + unfixable consumer-side). Remaining leg: golangci-lint-auto-configure shim (not yet located/verified this session).

## b) PARTIALLY DONE

1. **Shim-existence verification (TODO_LIST.md:866).** erraudit + crm + cv legs verified today (all three exist, all three now stale at tonight's revs); golangci leg not checked.
2. **Upstream CI health claim.** Two-repo spot-check only (erraudit CI-less — verified; cv CI present-but-red — verified). The "private repos have no CI since ~2026-09-10" claim (`docs/todo/upstream.md`, 2026-09-13 interim-pins row) is partially stale — the 2026-10-13 eight-repo push wave has a CI-watch row, so some repos have CI. A per-repo audit is required before scoping the CI-restoration sweep.
3. **Got-hash table.** 11 of 22 mismatch pairs fully transcribed from the user's deploy paste (below); the other 11 failing tools appear in the dependency-graph summary without their specified/got values — the full nh log (user's terminal) or one `--section-11-only` re-run is the canonical source (`docs/agents/go-ecosystem.md:20`).
4. **The fix itself.** Nothing landed: zero edits, zero shims, deploy blocked. The session ended at the plan + offer ("run step 4 now?") per the asked-how protocol.

## c) NOT STARTED

1. Consumer-side shim sweep (the offered unblock): flakePkg surfaces in `lib/lars-packages.nix` + the two-surface sweep `rg "inputs\.<tool>\.packages" modules/ platforms/ systems/` (`docs/agents/go-ecosystem.md:20`).
2. `bash scripts/pre-deploy-check.sh --section-11-only` (real-FOD preview; canonical got-hash oracle).
3. Deploy + post-deploy battery + `/run/current-system` anchor verify.
4. Per-repo upstream pastes (22 tools) → owner pushes → re-lock → shim drops.
5. cv upstream tidy + green Go-test + re-lock + shim replacement.
6. Upstream CI restoration sweep.
7. Wave status report + CHANGELOG row (09-21/10-07 precedent: wave sessions self-document).
8. Attribution of tonight's lock floats (which session/actor ran them — see g/Q1).
9. `docs/agents/go-ecosystem.md` annotation: tonight's instance for the shim-re-stale mechanism (rev moves re-stale shims too, not only root-nixpkgs waves — see d4).

## d) TOTALLY FUCKED UP

1. **Deploy blocked, fleet-wide.** 22 stale-vendorHash FODs + 1 cv source-desync FOD; evo-x2 toplevel unbuildable since 02:46. No service changes have shipped tonight.
2. **cv is consumer-unfixable.** The go-sum guard fires regardless of the pinned hash; upstream must run `go mod tidy` and commit go.mod AND go.sum together, and their Go-test CI must go green first (it is red right now).
3. **The 2026-10-14 master-tracking flip created same-day-lived shims.** erraudit `LzoxcvFT…` lived ~12h before `bb57433` re-staled it; crm `AtAQS+x0Oj…` likewise. Master-tracking inputs + no upstream CI + consumer-side shims = shims that are stale on arrival of the next float. This inverts the flip's own premise ("shims keep the toplevel green") into a per-float maintenance tax.
4. **Mechanism note in the 2026-10-14 row is too narrow.** It says erraudit's shim "re-stales on every root-nixpkgs re-vendor wave" — tonight re-staled it via a plain **input rev move** with root nixpkgs static. The re-stale trigger is *any* lock movement of a master-tracking input, which is strictly worse.
5. **No gate ran between the overnight floats and the deploy attempt.** The §11-after-lock-wave enforcement gap (`docs/todo/pipeline.md:395` [decision]) has a third live instance: the 13:14 10-07 wave, the 2026-10-14 waves, and tonight's floats all landed with no §11 pass; the deploy build itself was the detector (~3 min of nh work to learn what §11 says in seconds).

## e) WHAT WE SHOULD IMPROVE

**This session:**
1. I answered "how do we fix" and stopped without running the read-only `--section-11-only` probe — it would have produced the complete 22-pair got-hash table as a durable artifact instead of 11 pairs transcribed from a terminal paste.
2. I did not read the overnight session reports (`2026-10-15_00-39` geometrikks deploy-storm, `01-07` crowdsec, `02-06` inboxclean) — any of them may name the actor and intent behind the lock floats; attribution is unresolved (g/Q1).
3. I verified CI on only 2 of ~23 repos before basing the headline recommendation on the CI-less claim.
4. I verified 3 of 4 shim legs (TODO_LIST.md:866) but not golangci's while I was in the file.

**Systemic (recurring, evidence-backed):**
5. **Upstream CI is the actual fix.** Eight waves in two weeks, each repaired by hand, all share one root: stale hashes can land on master unverified. Restore `nix-check.yml` + deploy keys per the proven recipe; the treadmill ends there, not in `lib/lars-packages.nix`.
6. **Master-tracking vs no-CI is a contradictory policy.** Either CI everywhere (preferred) or master-tracking is unsafe and pins come back — but hard `?rev=` pins are the silent-NO-OP class the 2026-10-14 pin audit was built to kill. The policy needs an owner ruling (g/Q2, Q3).
7. **§11 must run when locks move, not when deploys do** — mechanize the tripwire ([watch] row `upstream.md:161` + [decision] `pipeline.md:395`).
8. **The shim comment discipline is about to become load-bearing:** the queued selftest row (`pipeline.md:479` — fail shims lacking enumeration-log citations) would have caught hand-paste drift in earlier waves; land it before the next wave.

---

## Got-hash pairs transcribed from the 02:46 enumeration (11 of 22)

| Tool @ locked rev | specified (stale) | got (fresh, canonical paste source) |
| --- | --- | --- |
| library-policy @ `e8e3667a` | `sha256-c/8gK23GJIg9+FizUuxHTFfq+Dmes64WjdglqCelFC4=` | `sha256-LNKl6MJs31DOTzZ1ThMIfvJ3+XOgFlS2KhXWKL2ncMY=` |
| kith-crm @ `a0341a0e` | `sha256-AtAQS+x0OjID6udRi88RD+OYPBT582IKTexudscI0/I=` | `sha256-WOZ2IwqwAaI+Y7EBZyWGRfMPZ13p8rGWaHrMTDOxcE0=` |
| inboxclean @ `7e23ec6` | `sha256-oZk9R6cnbA3pds0LpNlKbrxZxQvwC5b9IsoBQvilHec=` | `sha256-xekigUvjNAYMr/BdJSGcjzkkgP5CbtOaBzisW78+Zuc=` |
| meta @ `a00c6dae` | `sha256-G/lV5jG4SGJiMJOHIayWe2WOIdgRICbAEkydciBfe3Y=` | `sha256-RxJS6cpJ3x9VTvcroUeA2gMRNdbcD8xuRTzNUDSGYd0=` |
| mr-sync @ `f1a13263` | `sha256-P94o4NRlC/nmSzvm55oLHb8wRh2iXT2bPaFg4MA3pWQ=` | `sha256-cFy4AGocSu4kSWQZSjkcmGA8ZpNbm+QamGaq8n5zyis=` |
| overview @ `4b48040` | `sha256-I+gcCYgOz4WeBc69KOODZFIeDoJO2LZHdWARbFkX4hg=` | `sha256-NXdLbWt+UbnP2boe/1sE1LR1qIg/EMHXBtPFZgLAoJk=` |
| project-discovery-daemon @ `df32945` | `sha256-6ZDAkBBDARH+s31t8BY/eB3r9eymMcvji4O4IhkEnPA=` | `sha256-nNKXDH5NoVlkjJMQbYICImrthGVxMvZybQgf5QcJBkY=` |
| projects-management-automation @ `3149585c` | `sha256-uS4pKh4PBIkhhud7SwJCOt1j9R9OHa9eLyhy8nRr+sg=` | `sha256-lPN1fqTDp3jxmThsmdXIlbFpiM10h6qK1ksUYE1HvY8=` |
| samber-linter @ `1ab13330` | `sha256-wH3k7WiK5HPzpY8IQlF/aw9l0nVCkSWSAMwCHudM4PY=` | `sha256-79YZ0u7C+7oFhZS4YTMJzi3qroanbYTYbOkA2oDiKqY=` |
| project-dependency-graph @ `5315ae0a` | `sha256-ADzN0+X0UmHTPTXMXdQNYXxArU4IR1i0vh5yLpR8CN4=` | `sha256-lSE3snyu9xFnSekT4pBX23qaKeI22GI+R8rQzEFC3Bw=` |
| papdashboard @ `c8d0cf92` | `sha256-pg/a63hgLN2X6akLO9DLMVGaqSpGuXirBVq0BCaCbdc=` | `sha256-CzxGeRncao0r7hc6mbzsAvpjs8WlBCXFl82KpsVP0NU=` |

**Also failing, got-hashes NOT yet transcribed (pull from the full nh log or §11):** health-hub `93d13fd`, discordsync `cac57aa`, crush-daily `bc765f85`, go-structure-linter `bfb7518`, golangci-lint-auto-configure `104b54e`, file-and-image-renamer `21a0ef5`, go-humanize-linter `d24bd274`, go-auto-upgrade `93cb7cd`, erraudit `bb57433`, buildflow `d9f63e8`, branching-flow `0.6.7`.

**cv @ `0750bd6` — NOT a hash mismatch.** Guard failure, first-hand reproduced:
```
ERROR: go mod tidy inside the vendor FOD changed committed go.sum
semantics beyond the prepared (locally replaced) modules — the
committed go.mod/go.sum pair is out of sync (the daemon dep-wave
class). Run 'go mod tidy' in the repo, commit go.mod AND go.sum
together, then re-pin vendorHash (nix run .#refresh-vendor-hash).
```

---

## f) Up to 50 things to get done next

Tags: **[NEW]** born this session · **[QUEUED]** already queued, spotted/updated this session (location cited) · ownership tags per queue convention.

**Deploy-unblock path (do first, in order):**
1. [NEW] [ready] Pull the 11 missing got-hashes (full nh log or `--section-11-only`) into this table.
2. [NEW] [ready] Two-surface sweep for all 23 tools: `rg "inputs\.<tool>\.packages" modules/ platforms/ systems/` (go-ecosystem.md:20 protocol).
3. [NEW] [ready] Shim flakePkg surfaces in `lib/lars-packages.nix` — `overrideAttrs { vendorHash = …; }` attrset form ONLY, each comment citing the first-hand enumeration log (pipeline.md:479 makes this mandatory soon).
4. [NEW] [ready] Shim direct module consumers (PMA service module, discordsync, buildflow `configuration.nix` PATH entry, overview linux.nix overlay leg, bank-sync module+HM legs, …) — same form, same citation rule.
5. [NEW] [ready] `bash scripts/pre-deploy-check.sh --section-11-only` — real FOD preview, warms the cache, canonical oracle.
6. [NEW] [ready] Deploy → verify `readlink /run/current-system` = latest `system-N-link` (anchor discipline) → `post-deploy-check.sh`.
7. [NEW] [ready] Write the wave status report (09-21 precedent: wave sessions self-document).
8. [NEW] [ready] CHANGELOG row for the wave (services.md:351 precedent row pattern).
9. [QUEUED] [blocked:deploy] Post-deploy service battery after the wave switch (services.md:321, monitoring.md:98).

**Upstream convergence (owner directive 2026-10-11: "fix upstream, overlay only when NECESSARY"):**
10. [NEW] [blocked:push] Paste tonight's got-hashes upstream per repo (22 tools) — owner pushes; agents never push.
11. [NEW] [ready-after-push] Per tool: `nix flake lock --update-input <tool>` → re-verify FOD → DROP the shim whose drop condition fired (waves 4–8 protocol).
12. [NEW] [blocked:push] cv: upstream `go mod tidy`, commit go.mod AND go.sum together, green the red Go-test CI, push, re-lock, replace the dead `cv.nix:56` shim note.
13. [NEW] [blocked:push] erraudit: upstream paste at `bb57433`+ — UPDATE appended to upstream.md:13 row this session.
14. [QUEUED] [blocked:push] a7868a7-wave upstream re-pin sweep row (upstream.md:120) — tonight's table is its freshest input data.
15. [QUEUED] [ready] Verify the vendorHash shims cited by lifted pins exist (TODO_LIST.md:866) — 3 of 4 legs closed today; golangci leg open.
16. [QUEUED] [ready] Verify upstream CI green for pasted pushes after this wave converges (upstream.md:136/588 pattern).

**Systemic — the actual "as upstream as possible" fix:**
17. [NEW] [ready/blocked:push] **CI-restoration sweep**: audit every private repo consumed via a master-tracking SystemNix input for a real Nix-build CI; restore via the deploy-key recipe (`docs/agents/go-ecosystem.md:24-30`, proven 2026-09-16 on file-and-image-renamer + BuildFlow). erraudit verified CI-less 2026-10-15; cv CI red. Harvested to upstream.md this session.
18. [NEW] [decision] Master-tracking policy vs no-CI reality: restore CI fleet-wide, or scope master-tracking to CI-covered repos only (hard pins are the silent-NO-OP class — pin-audit 2026-10-14).
19. [NEW] [decision→ready] Mechanize the lock-wave tripwire: run §11 when `flake.lock` moves, not at deploy time (upstream.md:161 [watch] + pipeline.md:395 [decision], third live instance tonight).
20. [QUEUED] [ready] Trial `buildflow -s nix-hash-fix` on SystemNix's shim layout, dry-run first (pipeline.md:392, 436 — never attempted on green tree or these surfaces).
21. [QUEUED] [ready] lars-packages.nix selftest: enumeration-log citation required on every shim (pipeline.md:479).
22. [QUEUED] [ready] lars-packages.nix header: shim-form one-liner (pipeline.md:98).
23. [QUEUED] [ready] §11 is blind to `flakePkg`-imported FODs (pipeline.md:1026) — tonight's failure set is dominated by flakePkg-consumed tools; re-proves urgency.
24. [QUEUED] [ready] Per-host §11 gate (rpi3-dns + darwin parity) (pipeline.md:358).
25. [QUEUED] [ready] Shim-drop-protocol amendment: drop-comment lock-rev stamp + drop-condition re-verify (pipeline.md:448).
26. [QUEUED] [ready] Auto-queue "re-probe upstream, drop shim if converged" on every non-follower re-pin (pipeline.md:435).
27. [QUEUED] [ready] Pre-deploy eval-failure leg must surface root cause stderr (pipeline.md:315).

**Follow-ups spotted and still open (already queued — cited to avoid drift):**
28. [QUEUED] [ready] Attribute tonight's lock floats (actor + intent) — /proc forensics + `.crush/crush.db` per AGENTS.md session discipline (g/Q1).
29. [NEW] [ready] Read the three overnight session reports (00-39 geometrikks deploy-storm, 01-07 crowdsec, 02-06 inboxclean) to close attribution.
30. [QUEUED] [ready] DiscordSync goModules FOD hash invariance root-cause (TODO_LIST.md:523, upstream.md:176).
31. [QUEUED] [decision] overview: un-follow root nixpkgs to kill shim churn (TODO_LIST.md:552, upstream.md:135).
32. [QUEUED] [decision] bank-sync: un-follow its nixpkgs input — toolchain-skew class (services.md:322, TODO_LIST.md:1042). NOTE: tonight was NOT this class (root nixpkgs static) — un-follow would NOT have prevented this wave; the CI row (17) is the lever for it.
33. [QUEUED] [ready] bank-sync fix-locus verification, deploy-blocker row (services.md:391, TODO_LIST.md:516).
34. [QUEUED] [ready] docs/services/*.md stale-rev sweep for the 10-14 master flips (services.md:480).
35. [QUEUED] [ready] go-ecosystem.md vendorHash guidance refresh to §11 oracle (pipeline.md:355).
36. [QUEUED] [ready] Input-graph diet audit, 420+ lock nodes (pipeline.md:230).
37. [QUEUED] [ready] Nested art-dupl consumer closure check (pipeline.md:1027).
38. [QUEUED] [watch] health-hub/papdashboard first-boot watch after the wave switch (services.md:321).
39. [QUEUED] [ready] niri libdisplay-info shim drop-check (upstream.md:164).
40. [QUEUED] [ready] bunMemoryLimitOverlay + monitor365SwaggerUiFixOverlay drop re-verify (upstream.md:166).
41. [NEW] [ready] Annotate tonight's cv guard instance onto the 2026-09-18 guard-failure record in go-ecosystem.md:18 (same class, second documented occurrence).
42. [NEW] [watch] R&D: nixpkgs-upstream question — goModules FOD toolchain/source-independence (ROADMAP fuel; low priority — tonight was source churn, not toolchain).
43. [QUEUED] [blocked:push] Kith CRM rebrand chain (upstream.md:153).
44. [QUEUED] [blocked:push] InboxClean dead-grant honesty chain (upstream.md:51).
45. [QUEUED] [blocked:push] go-commit `OPENAI_TIMEOUT` release + PMA re-vendor (upstream.md:31).
46. [QUEUED] [blocked:push] clean-wizard → evo-x2 wiring (upstream.md:89).
47. [QUEUED] [blocked:push] BuildFlow master repair → lock forward-move + shim drop (upstream.md:90).
48. [QUEUED] [ready] go-nix-helpers lock bump: dynamic go-toolchain auto-select (upstream.md:91).
49. [QUEUED] [blocked:push] Fleet-wide infra follows in tool repos (upstream.md:18).
50. [QUEUED] [blocked:push] erraudit/crm/golangci upstream refresh row (upstream.md:13) — UPDATE appended this session: all three shims re-staled overnight via plain rev moves.

---

## g) Questions only you can answer

1. **Who ran tonight's lock floats?** Commits `a6fc86d7`→`30c3bbdf` moved ~23 master-tracking inputs overnight (heuristic auto-commits, ~00:00–02:46). Did you or one of the overnight sessions (00-39 geometrikks, 01-07 crowdsec, 02-06 inboxclean) run `nix flake update` deliberately — or was this an unintended ride-along? This decides shim-forward (floats intentional) vs `--override-input` rollback to last-good revs (floats accidental). I cannot attribute this from git alone.
2. **Deploy urgency ruling:** shim-forward now (consumer-side shims = the NECESSARY bootstrap exception, deploy tonight, converge upstream over days) — or hold evo-x2 on the current generation until upstream pastes land (no shims, cleaner history, services stay on last-known-good)?
3. **CI-restoration scope:** shall I draft `nix-check.yml` + deploy-key wiring for the CI-less private repos as local [ready] work across the fleet, or start with the small set that breaks most often (erraudit, cv, crm, overview, library-policy)?

---

## Self-harvest record (AGENTS.md mandate)

| §f item | Harvested at authoring time |
| --- | --- |
| 17 (CI-restoration sweep) | ✅ NEW row in `docs/todo/upstream.md` + `TODO_LIST.md` one-liner |
| 13/50 (erraudit re-stale) | ✅ UPDATE appended to `upstream.md:13` row |
| 12 (cv guard instance) | ✅ UPDATE appended to `upstream.md:140` CV row |
| 1–8, 10–11 (execution steps) | Deliberately not queued — they ARE the immediate next actions awaiting your g/Q1–Q3 rulings; queueing an offered-not-approved action would front-run the owner decision |
| 19 (tripwire mechanization) | Deliberately not queued as new — [decision] already live at `pipeline.md:395`; tonight cited there as third instance is enough until you rule |
| 28–50 | Already queued at cited locations — no drift edits needed |

## Verification appendix (commands run this session)

- `git rev-parse HEAD` + `git status --short` (content-pin; foreign changes: maintenance-entry-gate.nix + 4 migrate-* scripts — not mine, untouched)
- `git log --oneline -12 -- flake.lock`; per-commit `jq .nodes.nixpkgs.locked.rev` sweep (root static at `7fd4004d`)
- `rg vendorHash` (100 hits), `view lib/lars-packages.nix` (shim architecture + drop records)
- `gh run list -R LarsArtmann/erraudit` (CI-less: dependency-graph bot only) · `-R LarsArtmann/cv` (Go-test red)
- `nix build --impure --expr '(builtins.getFlake …).inputs.cv.packages.x86_64-linux.default.goModules'` (cv guard reproduced; NIX_HEAVY_GATE_FORCE=1 export per chaining rule)
- `rg inputs\.cv` → `modules/nixos/services/cv.nix:56-58` (shim located, read)
