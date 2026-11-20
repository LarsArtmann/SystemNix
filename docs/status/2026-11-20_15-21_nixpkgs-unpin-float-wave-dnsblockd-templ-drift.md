# Status: nixpkgs UN-PIN + float wave — dnsblockd templ drift is the sole blocker

> **SUPERSEDED 2026-11-20 ~16:55** by `docs/status/2026-11-20_16-55_nixpkgs-unpin-wave-harvest-landed-dnsblockd-fixed-upstream.md` — the dnsblockd templ drift was fixed UPSTREAM ~1 h after this report (tip bcdd194f: views regenerated at the declared v0.3.1100, pushed; attribution parallel-session/user, observed not executed by this session). Sections a/c/d here remain accurate for the 15:21 snapshot.

**2026-11-20 15:21 CET — session: root nixpkgs un-pin (owner directive "nixpkgs SHOULD NEVER be REV-PINNED! NEVER!") + fix the cv-hash deploy failure.**

**Scope line — what this report VERIFIED and how:**
- VERIFIED: patchelf on nixos-unstable tip = **0.15.2** (`nix eval …0bb82723#legacyPackages…patchelf.version`, `~/.cache/lockfloat/patchelf-tip-probe-20261120.log`); CV upstream bake at locked rev 53e9e8b = exactly the failing FOD's `got:` hash (`git show 53e9e8b:nix/packages.nix`, line 123); proof 1 (full keep-going toplevel at pre-float dnsblockd): sole root failure dnsblockd-9fe62ce tailwind inversion (`~/.cache/lockfloat/toplevel-proof-20261120.log`); proof 2 (full keep-going toplevel at floated tip): **PROOF_RC=1 with ALL 9 failures = one root chain, dnsblockd-232eab3 templ drift** (`~/.cache/lockfloat/toplevel-proof2-20261120.log`); taskchampion/trunk bare probes on tip RC=0 (`~/.cache/lockfloat/*-tip-probe-20261120.log`); tip taskwarrior3 already carries bd86de7 natively (`nix eval …taskwarrior3.patches`); lock node shapes post-float (python3 json: branch original, hermes/llama-rag untouched); dnsblockd tip committed `_templ.go` headers = `templ: version: v0.3.1123` vs its flake's declared `templ-src v0.3.1100` (`git show 232eab37:…`).
- NOT VERIFIED: live/runtime behavior of anything (no deploy ran); darwin host (no `--all-systems` eval this session); WHAT produced the v0.3.1123 templ headers at dnsblockd tip (unresolved — no such tag exists upstream, ls-remote shows only v0.3.1100/v0.3.1118 in that range); whether GOEXPERIMENT=jsonv2 affects the header line.

**One-line state: root nixpkgs floats again (f4a03c00 → 0bb82723, 2026-11-19 tip); the ENTIRE floated closure builds green except ONE root failure — dnsblockd's upstream tip is self-inconsistent (committed views generated with templ v0.3.1123, its own flake declares v0.3.1100), needs an upstream regen + owner push before the deploy can pass.**

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **Root nixpkgs UN-PINNED** — flake.nix URL → `github:NixOS/nixpkgs/nixos-unstable`, pin-audit `nixpkgs` allowlist row removed (REMOVED ledger written), lock floated **f4a03c00 (2026-11-07) → 0bb82723 (2026-11-19 tip)** | flake.nix:38-area comment block; lib/flake-input-pin-audit.nix; lock nodes verified via python3 (branch `original`, NO tarball regression) |
| a2 | **Eval accepted the lift end-to-end** — pin-audit guard (stale-row + unregistered-pin legs) passed both proof evals | proof 1 + proof 2 both reached build phase |
| a3 | **cv vendorHash shim DROPPED (25th cycle closes upstream-side)** — drop-safety test passed verbatim: `got: 7w2Mw3Mh…` (12:06 deploy FOD mismatch) == upstream bake at locked rev 53e9e8b (`nix/packages.nix:123`) | cv.nix ledger entry; cv FOD built GREEN in proof 1 (`cv-relogin`, `cv-server-content-sync`, `cv_fish-completions` all realized) |
| a4 | **taskchampionPkgConfigOverlay dropped** — all three legs fired on tip: taskwarrior3 already carries the bd86de7 system-SQLite patch natively (duplicate fetchpatch would double-apply/fail); bare probes `taskchampion-sync-server` RC=0 + `trunk` RC=0 on 0bb82723 | overlays/linux.nix lift comment; `~/.cache/lockfloat/taskchampion-tip-probe-20261120.log`, `trunk-tip-probe-20261120.log`; taskwarrior3 unpatched build green in proof 2 |
| a5 | **nixpkgs-hermes correctly KEPT pinned** — tip still ships patchelf 0.15.2, so the collapse LIFT (≥ 0.19) is unmet; hermes stayed insulated from the root float and its units built green | patchelf probe log; flake.nix + pin-audit rows updated with probe date |
| a6 | **dnsblockd floated per the pipeline.md "coherent pair" row** — lock 9fe62ce → 232eab37 (upstream tip, pushed); the TAILWIND half of the inversion is fixed at tip (failure moved past tailwind to templ) | lock verify; proof 2 error signature change |
| a7 | **The nixpkgs LIFT's tools observable essentially established** — proof 2's keep-going enumeration built the entire floated closure green except the dnsblockd chain: the four 2026-11-11 tool floats (cvagent/journal/discordsync/pma), signoz (+ sonic patches), paperless-gpt (tag-pinned, python3.14 wheel closure), inboxclean, dms-shell, geometrikks, cv, taskwarrior family | proof 2 error list = 9 lines, all dnsblockd-chain |
| a8 | **Owner directive recorded durably** — docs/agents/nix-flakes.md pin policy now leads with "Root nixpkgs is NEVER rev-pinned (owner directive 2026-11-20…)" | docs/agents/nix-flakes.md |
| a9 | **Moot cv todo rows closed** — upstream.md:15 paste-upstream row `[x]`-closed (MOOT: upstream re-baked on their own treadmill, no push ever needed); the cv leg of the 2026-11-18 FOD-storm row (line ~435) annotated MOOT | docs/todo/upstream.md |
| a10 | **Formatter-clean** — all 6 edited files through `nix fmt -- <paths>`: 0 changed | treefmt output |

## b) PARTIALLY DONE

| # | Item | Missing half |
|---|------|--------------|
| b1 | **dnsblockd float** — lock moved to tip 232eab37, tailwind leg fixed; tip is BUILD-RED: its committed `_templ.go` files carry `templ: version: v0.3.1123` headers while its own flake declares `templ-src v0.3.1100` — the fail-closed regen gate refuses every view file. Needs upstream regen at the DECLARED generator + owner push, then a re-float. Note: the `templ-components/v1.27.1` TAG itself was re-pointed (97c49407 → 07d21051, 2026-11-19) — tag churn under a "pinned" tag | upstream fix + push + proof #3 |
| b2 | **Toplevel proof** — round 1 complete (dnsblockd sole root, pre-float tree), round 2 complete-but-red (PROOF_RC=1, 9/9 errors = dnsblockd chain); a GREEN proof #3 does not exist yet | proof #3 after dnsblockd resolves |
| b3 | **Commit hygiene** — my 6 files sit in two unpushed daemon auto-commits (3da6dfcab: flake.lock+flake.nix+pin-audit+cv.nix; 8b5ac7562: upstream.md+linux.nix); verified clean (no foreign files); planned repair = `git reset --soft` to b365bb9ee (your cv-float commit) + ONE properly-messaged commit — deliberately deferred until proof green (never commit green claims pre-proof) | the soft-reset + recommit after proof #3 |
| b4 | **Deploy** — never attempted (blocked on green proof); post-deploy battery (anchor verification, §17 memory sweep, §19 freshness) unstarted | everything post-proof |
| b5 | **pipeline.md rows 1103/1104** — the coherent-pair row and the float-ceremony decision row describe this exact float; updates drafted but not landed (1104's decision is now answered by your directive: converge, never root-pin) | row edits (queued as harvest) |

## c) NOT STARTED

| # | Item | Why |
|---|------|-----|
| c1 | nixpkgs-hermes collapse to root | pre-req unmet: tip patchelf = 0.15.2 (probed) — correctly not started |
| c2 | nix flake check --no-build --all-systems standalone run | pre-commit hook will run it at commit time; not yet run this session |
| c3 | Post-deploy functional checks (dnsblockd resolution/DoT, cv boot-parse, paperless on python3.14, taskwarrior/tq units, hermes units) | deploy never ran |
| c4 | Fleet-wide `_templ.go` header audit (other owner repos generated with drifted templ?) | new risk surfaced late; not swept |
| c5 | Tag-immutability audit for the other tag-pinned inputs (qmd v2.8.3, paperless-gpt v0.31.0: `^{}` deref vs lock) | discovered the tag-churn hazard only via dnsblockd |
| c6 | TODO_LIST queue harvest at authoring time | landed right after this report (see harvest ledger) |

## d) TOTALLY FUCKED UP (honest)

1. **Edited the tree WHILE proof 1 was running** — the taskchampion overlay drop and the dnsblockd float both landed mid-proof; proof 1 kept building a graph that no longer matched the tree when I read its results. Exactly the 2026-11-05 AGENTS.md lesson (edit-while-background-job-runs) — I should have killed proof 1 BEFORE touching overlays/linux.nix. Cost: proof 1's tail results were stale by the time I cited them; I caught it and killed/relaunched, but the sequencing was sloppy.
2. **Floated dnsblockd without pre-reading tip's committed artifact headers** — one `git show 232eab37:internal/server/views/gateway_page_templ.go | head -3` (done AFTER the proof failed) would have shown the v0.3.1123 drift in 10 seconds and saved a full toplevel round (~25 min). The lock now sits on an upstream tip whose fix requires an upstream push — both pre- and post-float dnsblockd states were upstream-fix-gated, but I floated into the worse-documented of them blind.
3. **The pre-float probe that WOULD have caught this doesn't exist as a habit or a script** — dnsblockd's own gates encode generator-parity, but nothing at the SystemNix float layer checks "does the candidate tip's committed output match its declared generators". Listed as improvement #1.
4. Nothing else broken: no foreign files swept, no lock surgery, no red claimed green, eval never bricked.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-float generator-parity probe (biggest lever):** a script that, for each LarsArtmann input at candidate tip, greps committed generator outputs (`templ: version:` headers, tailwind artifact versions, go.sum tidy state) against the input flake's DECLARED generator pins — runs in seconds, would have caught dnsblockd before any build. Candidate: `scripts/float-preflight.sh` feeding §11.
2. **Kill-then-edit discipline for proofs:** a running toplevel proof owns the tree; edits wait or the proof dies first. Codify next to the 2026-11-05 background-edit lesson.
3. **Tag churn is a live hazard:** templ-components `v1.27.1` moved under a "pinned" tag. Either tags become immutable by policy (fresh tag per change) or generator inputs must be addressed by rev — but owner-repo rev-pins are banned by the 2026-11-14 directive, so the only clean lever is upstream discipline + a CI `^{}`-deref audit leg.
4. **Suffixed proof logs per round** (`proof-20261120-<n>.log`) instead of overwriting one name — proof 1's log survived this time only because proof 2 got a new filename by luck of my own convention.
5. **Solo-FOD iteration:** reproduce a single failing drv standalone (`nix build /nix/store/…-dnsblockd-….drv^*`) before full toplevel rounds — minutes, not half-hours, per hypothesis.
6. **The pin-audit should know the directive:** `nixpkgs` row removed ✓, but a guard against RE-introducing a root nixpkgs pin (eval throw on `github:NixOS/nixpkgs/<40hex>` as ROOT input URL) would make "NEVER" mechanical. The pin-audit already classifies rev-pins; it needs a root-input special case that fails even WITH an allowlist row.
7. **Tip-lag detector:** with the never-pin directive, the new failure mode is staleness (silent float no-ops, daemon races) — a WARN when root nixpkgs `lastModified` lags > 14 days belongs in an audit.
8. **Status-surface breadth of the fleet templ story:** if other owner repos also regenerated with the mystery v0.3.1123 templ, the same drift bomb is ticking in their locks — sweep before the next blanket float.

## f) NEXT THINGS (up to 50, impact-sorted; ⊞ = harvested to TODO surfaces at authoring time)

**The deploy path (critical chain):**
1. ⊞ Fix dnsblockd upstream: diagnose which templ produced the v0.3.1123 headers (02:02 regen session's provenance — their repo .crush DB / shell history), then either regenerate the committed views with the DECLARED v0.3.1100 generator (their buildPhase recipe: snapshot → `GOEXPERIMENT=jsonv2 templ generate ./internal/server/views/` → goimports fixup → commit) or bump `templ-src` to the generator that matches. [blocked:push — your call]
2. ⊞ You push the dnsblockd fix → SystemNix `nix flake update dnsblockd` → proof #3 keep-going toplevel green (PROOF_RC=0).
3. Consolidate my two daemon commits: `git reset --soft b365bb9ee` + one properly-messaged commit (pathspec-clean) — AFTER proof #3.
4. `nix flake check --no-build --all-systems` (capture-once → grep) before the commit hook burns a round.
5. `nix run .#deploy` (§0.5 quiescence advisory, §11/§16/§19 gates) → anchor verification (readlink == newest system-N-link) → post-deploy battery.
6. Post-deploy dnsblockd functional smoke: `getent hosts` via dnsblockd, local zones, blocklist counts, DoT/DoH, gatus dns checks green.
7. Post-deploy cv smoke: new binary 53e9e8b boot-parse (`journalctl -u cv-server`), /health/live, one send-path probe (shim drop = first new cv build since 2026-11-19).
8. Post-deploy paperless: python3.14 wheel closure went live with the float — search + ocrmypdf + export probes (big interpreter jump, the 10-20-class risk surface).
9. Post-deploy taskwarrior family: taskwarrior3 (now unpatched-upstream build), tq units, taskchampion-sync-server service.
10. Post-deploy hermes sanity: nixpkgs-hermes untouched — verify hermes units unchanged (negative check: nothing should have moved).
11. Post-deploy signoz: sonic patches rode the float — impersonation check + collector ingest probe.
12. §17 memory sweep + §19 storage-history freshness (deploy battery) — confirm no new `MemoryHigh` throttling on the new kernel/userland.

**dnsblockd/templ fallout (secondary):**
13. ⊞ Resolve the v0.3.1123 mystery: check whether GOEXPERIMENT=jsonv2 changes templ's generated header/version line, and what binary the 02:02 session used — the regen must land on the RIGHT generator, not just a consistent one.
14. ⊞ Ask/inspect the templ-components v1.27.1 tag re-point (97c49407 → 07d21051): deliberate re-tag (then dnsblockd should bump to a fresh tag deliberately) or accidental (restore the tag)? Tags MUST be immutable — policy note for the owner repos.
15. Sweep ALL owner repos' committed `_templ.go` headers vs their declared templ pins (the drift bomb may not be dnsblockd-only) — templ-components 07d21051's own headers first (its files compile today, but generator parity for the NEXT regen matters).
16. After dnsblockd resolves: land the pipeline.md row 1103 update (coherent pair executed: nixpkgs 0bb82723 + dnsblockd 232eab37+, patchelf leg still delegated to nixpkgs-hermes).
17. Land pipeline.md row 1104 resolution: float-ceremony decision answered — converge, root NEVER re-pins (your 2026-11-20 directive).
18. Check dnsblockd-guards / vm-gateway checks still pass at tip (eval-level; --no-build skips the VM builds).
19. Verify dnsblockd's nested go-datastar float (f909928e) didn't re-stale anything else in its closure (proof 3 covers).

**Guard/hardening (builds on this session's evidence):**
20. ⊞ Add the root-input pin throw to flake-input-pin-audit (root nixpkgs URL carrying a 40-hex path = eval failure even with an allowlist row — make "NEVER" mechanical) + negative test leg in scripts/negative-test-lints.sh group `inputpin`.
21. Build the pre-float generator-parity script (§e.1) + wire into pre-deploy §11 as a preview leg (WARN-first, then BLOCK once proven).
22. Add the tip-lag WARN audit (§e.7) — root nixpkgs lock `lastModified` > 14 days → warning (staleness is the new failure mode under never-pin).
23. Tag-immutability audit leg: for every tag-pinned input, `ls-remote <tag>^{}` deref must equal the lock rev — CI-able, would have caught v1.27.1 churn.
24. Proof-log naming convention: per-round suffixed logs + a pointer file `~/.cache/lockfloat/LATEST` (stop referencing a mutable single filename).

**Cleanup/bookkeeping:**
25. Prune pass over docs/todo/upstream.md's newly `[x]` cv rows + the closed FOD-storm cv leg → CHANGELOG (with the WARN A/B recount discipline).
26. Re-grep `f4a03c00` post-wave: remaining hits are comments/history only (flake.nix:1462/1489-area comments describe the old pin — refresh their tense once dnsblockd lands).
27. Darwin-side sanity (next darwin deploy, not today): chromium parking tryEval on tip (brave may have returned on aarch64-darwin — the block self-revives by design; verify + refresh the parking comment).
28. Consider simplifying nixpkgs-compat.yml now that override-input nixpkgs == the floating root (it's identity; the workflow's value shifted to "unstable-vs-unstable" — decide keep/simplify).
29. Archive the two probe logs' key outputs inline into the eventual close-out doc (~/.cache is reboot-volatile; the §11/§16 patterns demand durable evidence).
30. AGENTS.md drift check: the nix-flakes.md pin-policy lead now carries the directive — confirm AGENTS.md's critical-rules table still routes correctly (it does; no edit planned — avoid duplicating the policy in two surfaces).
31. After deploy: `open new terminal` reminder is owner-side; fish completions for cv/nixos-version rebuilt — note in close-out.
32. Once dnsblockd tip builds: re-check whether `paperless-gpt`'s npmDepsHash held on python3.14-era nixpkgs (proof 2 built it green — ledger the evidence in its pkgs/ comment).
33. Same ledger pass for inboxclean's still-standing vendorHash shim (inboxclean.nix:156) — proof 2 built it green at tip; consider testing the drop condition (upstream bake == got) next float.
34. The §f list beyond 34: see ROADMAP-class items below (brainstorm, not commitments).

**ROADMAP-class (from this session, unrefined):**
35. Fleet "generator inputs" registry: one file listing every input that GENERATES committed artifacts (templ, tailwind, bun, sqlc, protoc…) with its declared version source — the pre-float script reads it.
36. Rethink tag-pin policy for owner repos: tags that move are pins that lie; either CI enforces immutability or the pin-audit traces tag derefs per eval.
37. Explore nixpkgs-hermes retirement path: upstream hermes-agent re-syncing their nested patchelf pair is the real LIFT — a tracking row exists; consider an upstream issue draft (verify-before-filing first).
38. A float-risk scorecard per input (FOD-bearing? generator-bearing? python-closure?) to order future blanket floats' proof effort.
39. Consider `nix flake update` sessions adopting proof 2's "capture full enumeration, fix single roots" loop as the documented ceremony (it worked: one command, one root, full fallout list).
40. Long-term: replace the patchelf 0.15.2 wait with an upstream nixpkgs fix watch (patchelf version bump in unstable) — the moment it lands, nixpkgs-hermes collapses and the 2026-11-12 topology dissolves.

## g) Questions I can NOT figure out myself

1. **dnsblockd 02:02 regen provenance:** did you (or a session you ran) regenerate dnsblockd's views this morning with a templ binary that reports `v0.3.1123`? If you know WHICH binary (a devshell build? templ built from master? a local `go run`?), I can regenerate the artifacts to MATCH the committed state instead of flipping the whole view set back to v0.3.1100 style — this decides the fix direction (bump `templ-src` vs regen-with-declared).
2. **templ-components v1.27.1 tag re-point:** did you deliberately move the tag (97c49407 → 07d21051) to ship the toast fix without a version bump? If deliberate, I'll treat moved tags as canonical and only align the templ generator; if accidental, the tag should be restored and a fresh v1.27.2 cut.
3. **Push authorization for LarsArtmann/dnsblockd:** the fix (regenerate views at the declared generator, commit) must be PUSHED before SystemNix's float can pick it up and the deploy can pass. Do I have your push window (like the 2026-11-10 CV `dd201874b` precedent), or will you push it yourself?

---

## Harvest ledger (authoring-time, per TODO-system rule)

- Item 1 (dnsblockd upstream regen fix) → docs/todo/upstream.md new `[blocked:push]` row; deliberately NOT queued in TODO_LIST.md (the queue is `[ready]`-only — push-gated work is excluded from tq harvest by design). ✅ landed
- Item 13/14 (v0.3.1123 mystery + tag re-point) → folded into the same upstream.md row's diagnosis steps. ✅ landed
- Items 16/17 (pipeline.md rows 1103/1104) → edited in place now (1104 resolved; 1103 half-executed status). ✅ landed
- Item 20 (root-input pin throw) → docs/todo/pipeline.md new row. ✅ landed
- Items 6–12 (post-deploy checks) → covered by the deploy battery + this report; deliberately NOT queued as separate rows (they re-fire per deploy).
- Items 21–24, 35–40 → ROADMAP-class, deliberately NOT queued (brainstorm per HARVEST anti-patterns).
