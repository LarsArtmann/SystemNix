# Status: nixpkgs un-pin wave — harvest landed; dnsblockd drift FIXED UPSTREAM (observed); proof #3 + deploy remain

**2026-11-20 16:55 CET — supersedes `2026-11-20_15-21_nixpkgs-unpin-float-wave-dnsblockd-templ-drift.md` (annotated there). Same session thread: root nixpkgs un-pin (owner directive "nixpkgs SHOULD NEVER be REV-PINNED! NEVER!") + cv-hash deploy fix.**

**Scope line — VERIFIED (command/artifact):** patchelf on tip = **0.15.2** (`nix eval …0bb82723#…patchelf.version`); CV upstream bake at 53e9e8b == the FOD `got:` hash (`git show 53e9e8b:nix/packages.nix:123`); proof 1 + proof 2 complete keep-going toplevels (`~/.cache/lockfloat/toplevel-proof{,2}-20261120.log`; proof 2: PROOF_RC=1, **all 9 errors = one dnsblockd chain**); taskchampion + trunk bare probes on tip RC=0; tip taskwarrior3 carries bd86de7 natively (`nix eval …taskwarrior3.patches`); lock node shapes via python3 (branch original, hermes/llama-rag untouched); **dnsblockd tip bcdd194f committed `_templ.go` headers = `templ: version: v0.3.1100`** (`git -C ~/projects/dnsblockd show bcdd194f:…gateway_page_templ.go`), pushed to origin (ls-remote == bcdd194f), regen wave = 27-file commit + art-dupl/brandid vendor-hash refreshes.
**NOT VERIFIED:** proof #3 / a GREEN toplevel at the new tip (does not exist yet — may be in-flight by a parallel session); anything runtime (no deploy); WHO executed the dnsblockd fix (attribution unknown — observed, not executed, by this session); foreign commit d14e68be4 (`summit-planner` registration in configuration.nix — another project's work on the shared tree, flagged not touched).

**HEAD state:** `7e80d058f` (daemon) — lock carries dnsblockd @ **bcdd194f**; my session's work sits in daemon commits `3da6dfcab` (un-pin + cv drop + audit row), `8b5ac7562` (overlay drop), `761214fc0` (harvest + first report); `c4a29effc`/`7e80d058f` are lock-float commits of parallel provenance; only dirty file = the supersede note on the 15-21 report.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **Root nixpkgs UN-PINNED** — `nixpkgs.url` → `nixos-unstable`, allowlist row removed with REMOVED ledger, lock floated f4a03c00 (2026-11-07) → **0bb82723 (2026-11-19 tip)**; eval accepted both proof rounds | flake.nix + lib/flake-input-pin-audit.nix; python3 lock verify (branch `original`, NO tarball regression) |
| a2 | **cv vendorHash shim DROPPED (25th cycle, drop-safe)** — got `7w2Mw3Mh…` == upstream bake at locked rev 53e9e8b; cv FOD + dependents built green in proof 1 | cv.nix ledger; proof 1 log |
| a3 | **taskchampionPkgConfigOverlay dropped** — taskwarrior3 carries bd86de7 natively on tip (double-apply would fail); taskchampion-sync-server + trunk bare probes RC=0 on tip | overlays/linux.nix lift comment; tip-probe logs |
| a4 | **nixpkgs-hermes correctly KEPT pinned** — tip patchelf 0.15.2 → collapse LIFT unmet; hermes insulated through the whole wave | patchelf probe log |
| a5 | **nixpkgs LIFT's tools observable established** — proof 2 built the entire floated closure green except dnsblockd: cvagent/journal/discordsync/pma, signoz (+ sonic patches), paperless-gpt (python3.14 closure), inboxclean, dms-shell, geometrikks, cv, taskwarrior family | proof 2 error list = 9 lines, all dnsblockd-chain |
| a6 | **Owner directive recorded durably** — docs/agents/nix-flakes.md pin policy now leads with "Root nixpkgs is NEVER rev-pinned (owner directive 2026-11-20…)" | nix-flakes.md |
| a7 | **Harvest ledger EXECUTED (761214fc0)** — docs/todo/upstream.md dnsblockd `[blocked:push]` row (diagnosis + protocol), pipeline.md 1103 EXECUTED-annotation + 1104 RESOLVED (converge, never re-pin) + NEW `[ready]` root-pin-throw guard row, TODO_LIST `[ready]` queue one-liner (push-gated fix deliberately NOT queued — queue is `[ready]`-only) | the four files in 761214fc0 |
| a8 | **cv todo rows closed** — upstream.md:15 paste-upstream row MOOT-closed; FOD-storm row's cv leg annotated | upstream.md |
| a9 | **First report authored + superseded properly** — 15-21 report written, now carries a non-destructive SUPERSEDED-BY pointer to this file | both files |
| a10 | **Formatter-clean** on every edited file across the session | treefmt: 0 changed each pass |

## b) PARTIALLY DONE

| # | Item | Missing half |
|---|------|--------------|
| b1 | **dnsblockd fix chain** — upstream FIXED (bcdd194f: views regenerated at the DECLARED v0.3.1100, pushed; also art-dupl/brandid vendor-hash refreshes); SystemNix lock floated to bcdd194f (daemon-committed `7e80d058f`) — but **no GREEN proof #3 exists**, and I did not execute the fix (observed at 16:5x, attribution unknown) | proof #3 + row closure with verified attribution |
| b2 | **Commit hygiene** — my three daemon commits are unpushed, heuristically messaged; planned consolidation (`git reset --soft` to b365bb9ee → one properly-messaged commit) still deferred until proof green | consolidation post-proof |
| b3 | **Deploy** — blocked on proof #3; §0.5/§11/§16/§19 battery + anchor verification + post-deploy checks all pending | everything post-proof |
| b4 | **upstream.md dnsblockd row** — written against the 232eab3 state; its premise ("tip 232eab37 is build-red") is now stale since bcdd194f landed; closure deferred to avoid co-claiming the parallel session's work | row update with attribution |
| b5 | **pipeline.md 1103** — annotated EXECUTED but its "REMAINING: templ drift gates proof #3" clause is stale post-bcdd194f | final status post-proof #3 |

## c) NOT STARTED

| # | Item | Why |
|---|------|-----|
| c1 | Proof #3 (green toplevel at 0bb82723 + bcdd194f) | **Twin-executor hazard: a parallel session appears mid-flight on exactly this (uncommitted→daemon-swept lock float at 16:4x-16:5x). MUST check ownership before running — the 2026-10-18 twin-executor lesson** |
| c2 | Deploy + full post-deploy battery | blocked on c1 |
| c3 | Root-nixpkgs-pin throw guard implementation | queued `[ready]` (pipeline.md + TODO_LIST) — not implemented |
| c4 | Fleet `_templ.go` header sweep (other owner repos may carry the same v0.3.1123-class drift) | surfaced late, not swept |
| c5 | Tag-immutability audit (`^{}` deref vs lock for qmd/paperless-gpt/templ-components tags) | not built |
| c6 | Pre-float generator-parity probe script | improvement, not built |
| c7 | Darwin-side verification of the float | no `--all-systems` eval this session |
| c8 | nix flake check --no-build --all-systems standalone run | pre-commit will run at commit time |

## d) TOTALLY FUCKED UP (honest, session-wide)

1. **Edited the tree WHILE proof 1 ran** (overlay drop + dnsblockd float mid-proof) — the 2026-11-05 background-edit lesson, violated live; proof 1's tail results were stale by citation time. Caught, killed, relaunched — sequencing was still wrong.
2. **Floated dnsblockd without pre-reading tip's committed generator headers** — one `git show 232eab37:…_templ.go | head -3` (done AFTER proof 2 failed) would have caught the drift in 10 s and saved a full ~25 min proof round.
3. **Empty-read trap hit ME this hour:** `git show bcdd194f5:…` in the WRONG repo with stderr suppressed returned empty and I nearly read it as "the header moved" — an empty read is a FAILED read, not evidence (AGENTS.md 2026-11-14 lesson, repeated by its own author). Re-checked in the dnsblockd checkout minutes later.
4. **First report's harvest ledger claimed a TODO_LIST queue row for a `[blocked:push]` item** — the queue is `[ready]`-only; corrected before damage, but the slip shipped in a committed file and needed a fix edit.
5. **"Sole blocker" headline aged ~90 minutes** — the 15-21 report's central claim was being fixed upstream while I wrote it. Root cause: I didn't check for a parallel executor (status pre-read / repo .crush DB) after the user's long absence — the 2026-10-23 status-report pre-read lesson, missed at report-authoring time.
6. No lock surgery, no foreign files swept into my commits, no red claimed green, eval never bricked — the damage is contained to wasted cycles and one stale headline.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-float generator-parity probe (top lever):** for each floated input, grep committed generator outputs (`templ: version:`, tailwind artifact versions, go.sum tidy) against the input's DECLARED generator pins — seconds, would have caught dnsblockd pre-build. Candidate: `scripts/float-preflight.sh` wired into §11.
2. **Check-for-parallel-executor BEFORE authoring reports/continuing after idle gaps:** `ls -t docs/status/`, newest daemon commits, repo `.crush` DB — the 15-21 report should have been a supplement to another session's work, not a fresh headline.
3. **Kill-then-edit discipline:** a running toplevel proof owns the tree; edits wait or the proof dies first.
4. **Tag immutability policy:** templ-components `v1.27.1` was re-pointed (97c49407 → 07d21051) under a "pinned" tag — either tags become immutable (fresh tag per change) or the audit derefs `^{}` per eval/CI; owner-repo rev-pins are banned, so upstream discipline + a CI leg is the only clean lever.
5. **Make the root-nixpkgs ban mechanical:** pin-audit throw on a root `nixpkgs` URL carrying a SHA/`?rev=`, allowlist cannot register it, negative-tested (queued `[ready]`).
6. **Tip-lag detector:** under never-pin, staleness is the failure mode — WARN when root nixpkgs lock `lastModified` lags > 14 days.
7. **Solo-FOD iteration first:** reproduce single failing drvs standalone before full toplevel rounds (minutes vs half-hours per hypothesis).
8. **Evidence commands fail loud:** suppress stderr only when absence is EXPECTED; my wrong-repo `git show` was silent because I piped 2>/dev/null reflexively.
9. **Attribution honesty before row closure:** the upstream.md dnsblockd row must be closed by whoever's provenance is verified, not by an observer.

## f) NEXT THINGS (up to 50, impact-sorted)

**Critical chain:**
1. **Establish proof #3 ownership first** (ps/proc forensics, newest daemon commits, status pre-read) — if no session owns it, run the keep-going toplevel at bcdd194f; PROOF_RC=0 = the wave's gate.
2. Close the upstream.md dnsblockd row with verified attribution (who pushed bcdd194f + the two lock floats c4a29effc/7e80d058f).
3. Commit the dirty supersede note (15-21 report annotation).
4. Consolidate my three daemon commits: `git reset --soft b365bb9ee` → one properly-messaged commit (post-proof, pathspec-clean, pre-commit runs its legs).
5. `nix run .#deploy` → anchor verification (readlink == newest system-N-link) → full post-deploy battery.
6. Post-deploy dnsblockd functional smoke: `getent hosts`, local zones, blocklist counts, DoT/DoH, gatus dns checks.
7. Post-deploy cv smoke: binary 53e9e8b boot-parse (`journalctl -u cv-server`), /health/live, one send-path probe (first new cv build since 2026-11-19).
8. Post-deploy paperless probes: python3.14 wheel closure went live — search + ocrmypdf + export (big interpreter jump, 10-20-class risk).
9. Post-deploy taskwarrior family: taskwarrior3 (unpatched-upstream build), tq units, taskchampion-sync-server service.
10. Post-deploy hermes negative-check: nixpkgs-hermes untouched — hermes units unchanged.
11. Post-deploy signoz: impersonation check + collector ingest (sonic patches rode the float).
12. §17 memory sweep + §19 storage-history freshness via the battery.

**dnsblockd/templ fallout:**
13. Land pipeline.md 1103 final status post-proof #3 (its REMAINING clause is stale).
14. Diagnose the ORIGINAL v0.3.1123 producer (which binary the 02:02 session used; whether GOEXPERIMENT=jsonv2 affects the header) — the bcdd194f regen may already answer this (verify their method matches the declared recipe).
15. Verify dnsblockd's nested floats are coherent (the lock diff moved 3 nested revs: templ-components/go-datastar/art-dupl-era sources — confirm each is intentional upstream).
16. Ask/resolve the templ-components v1.27.1 tag re-point (deliberate → bump protocol; accidental → restore + fresh tag).
17. Fleet `_templ.go` header sweep vs declared templ pins (templ-components 07d21051's own headers first).
18. Tag-immutability audit leg for CI (qmd v2.8.3, paperless-gpt v0.31.0, templ-components tags: `^{}` deref == lock rev).

**Guards/hardening (queued or candidate):**
19. Implement the root-pin throw guard ([ready] row) + negative-test leg `inputpin`.
20. Build `scripts/float-preflight.sh` (generator-parity) → §11 preview leg (WARN-first).
21. Tip-lag WARN audit (root nixpkgs lock age > 14 days).
22. Proof-log convention: per-round suffixed names + `~/.cache/lockfloat/LATEST` pointer.
23. Append this session's lessons to docs/agents/nix-flakes.md float section (pre-float header probe; kill-then-edit).

**Bookkeeping/cleanup:**
24. Prune pass over the newly-closed cv rows → CHANGELOG (WARN A/B recount discipline).
25. Refresh f4a03c00 comment tense in flake.nix (~1462/1489) once dnsblockd proof lands.
26. Acknowledge/verify d14e68be4 (summit-planner registration — foreign project's work on the shared tree; owner-authored? no action from me beyond flagging).
27. nixpkgs-compat.yml simplification decision (override == root now; value shifted).
28. Darwin chromium parking note refresh (next darwin deploy; tryEval self-revives).
29. inboxclean shim drop-condition test at tip (upstream bake == got?).
30. paperless-gpt hash-ledger comment update (proof 2 built green — ledger it).
31. Archive key probe-log outputs inline into the wave's close-out doc (~/.cache is reboot-volatile).
32. Same-surface drift check: cv.nix ledger vs upstream.md row vs this report (all three cite 53e9e8b/7w2Mw3Mh — already consistent).
33. HARVEST this report's §f at authoring time (ledger below).
34. After deploy: `open new terminal` owner reminder (fish completions for cv/nixos-version rebuilt).

**ROADMAP-class (brainstorm, not commitments):**
35. Fleet generator-inputs registry (templ, tailwind, bun, sqlc…) with declared version sources — the preflight script reads it.
36. Float-risk scorecard per input (FOD-bearing/generator-bearing/python-closure) to order future blanket-float proofs.
37. Codify proof 2's loop as the documented float ceremony (one keep-going enumeration → fix single roots → repeat).
38. nixpkgs-hermes retirement watch: upstream hermes-agent nested-patchelf re-sync is the real LIFT — monthly probe precedent (llama-rag pin-expiry cron).
39. patchelf upstream watch: the moment unstable ships ≥ 0.19, nixpkgs-hermes collapses and the 2026-11-12 topology dissolves.
40. Go-toolchain floors re-check under the new nixpkgs go (2026-10-25 class) — proof 3 covers build-side; ledger the go version in nix-flakes.md.
41. dnsblockd-guards / vm-gateway checks at tip (eval-level verify post-proof).
42. gatus dns-check set review post-deploy (dnsblockd swap is the riskiest unit swap of the wave).
43. Capture proof-3 log reference into the close-out (durable evidence trail).
44. Consider making the 15-21→16-55 supersede pattern standard (one-line pointer, non-destructive) — it worked well.
45. Wave close-out doc once deployed (single narrative: pins → floats → proofs → deploy).
46. Dependabot/PAT surface noted in d14e68be4 belongs to another project — no SystemNix action; skip.
47. Re-verify llamacpp/ai-stack closures untouched by the float (proof 3 enumerates; ledger in the close-out).
48. sops §19 gate will run at deploy — nothing to pre-do, listed for completeness of the battery map.
49. Consider a `docs/agents/nix-flakes.md` "tag churn" gotcha entry once the v1.27.1 question is answered.
50. Longer-term: collapse nixpkgs-llama-rag when llama.cpp ≥ 0.4.x spin regression is fixed upstream (standing LIFT, unchanged by this wave).

## g) Questions I can NOT figure out myself

1. **Who executed the dnsblockd fix** (bcdd194f regen + push + lock floats c4a29effc/7e80d058f)? You in another terminal, or a parallel agent session? This decides attribution for the row closure AND whether proof #3/deploy is already owned elsewhere — I will not double-run.
2. **templ-components `v1.27.1` tag re-point (97c49407 → 07d21051): deliberate or accident?** Deliberate → the fleet's tag-bump protocol needs a note; accidental → restore the tag + cut a fresh v1.27.2.
3. **Is the push-authorization policy for owner repos now open during fix waves?** dnsblockd's fix was committed AND pushed by someone other than me — if that was a session acting without your window, I need the boundary restated; if it was you, the upstream.md row can close as owner-executed.

---

## Harvest ledger (authoring-time)

- Item 3 (commit supersede note) → done in-session (dirty file, will ride the next commit). ✅
- Item 2/§b4 (upstream.md row closure) → deliberately NOT edited: attribution unknown (§g.1) — editing a row another session owns mid-flight is the co-claim hazard; deferred until ownership is verified.
- Item 13/§b5 (pipeline 1103 final status) → deliberately deferred: its clause becomes factual only post-proof #3.
- Items 19/23 → the root-pin throw row is ALREADY queued from the first report (TODO_LIST `[ready]` + pipeline.md row); the nix-flakes.md lesson-append folds into that same pass. ✅ (already landed)
- Items 6–12 (post-deploy checks) → deploy battery re-fires them; not queued as rows.
- Items 14–18, 20–22, 24–33, 35–50 → actionable-but-not-this-session or ROADMAP-class; deliberately not queued (HARVEST anti-patterns: the critical chain 1–5 owns the session's remaining scope).
