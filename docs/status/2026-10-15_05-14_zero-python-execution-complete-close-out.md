# Status: Zero-Python executed end-to-end — UCR rehomed & parity-verified, ruff gone, CI-red triaged

**Date:** 2026-10-15 05:14 CEST
**Scope of this report:** THIS session's run (the zero-Python Pareto plan U-block + G-block execution, plus the mid-session discoveries). Not a whole-project inventory — the per-domain state lives in `docs/todo/*` and `docs/services/*` as usual.
**Repos touched:** SystemNix (`191dd21f..13e33a05` pushed), ucr-archive (created + `v0.1.0` pushed at `427319a`), crush-daily (v0.1.0 tag from the prior leg, already pushed).
**Plan:** docs/planning/2026-10-14_22-08_systemnix-zero-python-pareto-plan.md — now carries an **EXECUTED** banner.
**Prior report:** docs/status/2026-10-15_03-58_zero-python-execution-d-b-done-u-midport-status.md (its 3 open questions answered in §b below).

> **Format note:** the status-report skill is HTML-canonical; this report is `.md` because the
> operator's prompt explicitly demanded the `.md` path — operator instruction wins, divergence
> flagged here per the skill's rule.

---

## a) FULLY DONE

1. **U1–U5, ucr-archive completed as a real repo.** `cmd/ucr/main.go` written (4 command families: `encode`, `rag init|import|embed|ask|stats`, `web`, `contacts derive|decode-vcf`; `--root` on every subcommand, flag > `$UCR_ROOT` > default; usage errors exit 2). First compile surfaced 4 real defects, all fixed: Printf-sink interfaces used where `io.Writer` was needed, `rag.Out` missing `Flush()` in the interface, unexported `embedRequest` called as exported `EmbedRequest`, `Out.Flush` called through the interface. Unit tests written for all 4 packages (stdlib, table-driven): manifest loading, plan building (verdict filter, dedup, per-album track numbering), sanitize/parse-contact, SRT/whisper-JSON/VTT parsing, `TranscriptStem`, `FTSEscape`, `Cosine` (via the float32 blob), vCard unfolding/QP/ITEM-prefix/FN-from-N, `SafeFilename`, `MergeEvidence` (incl. the deliberate Python double-count, pinned by test at 8/8 with an explanatory comment). `go build && go vet && go test` all green.
2. **U4, packaging.** `flake.nix` on the house `mkGoFlake` pattern (go_1_26 — verified nixpkgs ships exactly 1.26.8 matching go.mod; vendorHash pinned in `vendorHash.nix`; ffmpeg in the devShell). `nix flake check` → **all checks passed** (build + sandbox tests + treefmt + vendor-hash FOD).
3. **U6, parity verification — the core deliverable.** Twin sandbox at `/tmp/ucr-parity` (`{py,go}/`), identical inputs (3-row manifest slice with REAL WAVs from the live archive, synthetic VCF + transcript fixtures, then the FULL 591-row real manifest for parse parity). Results, all recorded in the repo's `README-VERIFICATION.md` as ten labeled deviations (D1–D10):
   - FLAC mirror **byte-identical** (md5 + `diff -r`).
   - opus: **decoded PCM bit-identical**; the ~0.2% container-byte delta is the randomized Ogg stream serial + CRC (impossible to match without a `-serial` override neither side uses).
   - contacts output tree **byte-identical** (cards JSON incl. field order and `match: null`, clean VCFs, photos, HTML).
   - rag: `calls` table + FTS segments **row-identical**, `ask`/`stats` stdout **byte-identical**, full-manifest init 591/591.
   - web: `data.js` **byte-identical**; `index.html` functional-equivalent (the Go template is dprint-formatted; logic reviewed line-by-line).
   - **Upstream Python bug found by parity:** `ucr-rag.py`'s `call_vec` INSERT supplies 4 values into a 5-column table — the Python embed leg could never store vectors. The Go port inserts all 5 and works against the live llama-rag bge-m3 server (1024-dim vectors stored; semantic re-ranking verified live).
   - The live archive root was **never written** (verified `derived/` unchanged after all runs).
4. **Parity DROVE four Go fixes** (the port got better because of the golden diffs, not just verified by them): `failures: null` → `[]` and the non-Python `prefix_counts` field dropped from `encode-report.json`; `Card` JSON field order `uid → match → photo_file` with `match` always emitted (Python appends both at runtime); `rag init` output lines got their missing trailing newlines; `data.js` now uses Python `json.dumps` separator spacing (string-aware transform, `pythonJSONSpacing`).
5. **U7, release.** `ucr-archive` committed with a properly-messaged squashed initial commit (`279f239`, 25 files), verification report committed (`427319a`), tagged **v0.1.0**, pushed to `github:LarsArtmann/ucr-archive`.
6. **U8, SystemNix removals.** The 4 UCR `.py` scripts (1,475 LOC) + `ucr-ffprobe-sweep.sh` (259 LOC) `git rm`'d; `scripts/` now holds **zero Python**. Landed as `191dd21f` (proper message; a parallel session swept my staged work into it — contents verified, `pkgs/post-crash-calm-gate.nix` rode along, theirs).
7. **Queue + docs annotations (both surfaces, no drift).** `docs/todo/pixel6.md`: extraction row closed DONE 2026-10-15 with repo/tag/parity pointers, and the **three stale shipped-2026-09-15 backlog rows** annotated SHIPPED + REHOMED (the annotation obligation from the extraction row itself). `TODO_LIST.md`: D-block + UCR extraction one-liners closed. `docs/status/2026-09-15_05-46_…`: REHOMED banner pointing at the new repo + its verification report.
8. **G1, ruff plumbing gone.** Pre-commit ruff leg deleted, `ruff.toml` deleted (`37798e7b`; `bash -n` + shellcheck clean; committed through the real hook — flake-check + gitleaks legs green).
9. **Zero-Python guard assertions (G3).** `rg '\.py$' scripts/` → empty; `writePython3` in `flake/` appears ONLY inside the lint-static guard's own grep pattern (no usage); the guard block itself intact with its incident narratives (it stays — it guards against Python returning, it does not use Python).
10. **G2, docs sync** (`8ebfa505`): AGENTS.md architecture line (`scripts/` → "Shell operational scripts, zero Python…") + daemon-race sentence (ruff removed); CONTRIBUTING lint table ruff row dropped + standalone-re-run note updated; `docs/todo/services.md` rows closed for D-block, G-block, and the crush-daily backfill (B-block close-out); TODO_LIST ruff row closed; CHANGELOG `[Unreleased] → Removed` entry written; plan annotated EXECUTED with the residual list.
11. **G3, gates + push.** `nix flake check --no-build` all-pass; `191dd21f..13e33a05` pushed to origin. My five SystemNix commits this session all carry proper messages (no heuristic message owns my files — see §b Q3).
12. **crush-daily B-block follow-through held.** The v0.1.0 tag + input bump + flake app swap from the prior leg survived the whole session (SystemNix evals green with the Go backfill app; the `.py` is gone with the UCR rehoming).

## b) PARTIALLY DONE

1. **CI green-back (the real open wound).** `Nix flake check` on GitHub Actions is RED and has been on **every** master push tonight (00:11, 01:04, 01:19, 01:48, 02:48, 02:49, 03:11 — long before my push). Two classes, both triaged, neither fixed by me:
   - **(a) All VM tests fail at input fetch:** `unable to download …/LarsArtmann/branching-flow/tarball/aa1611d…` HTTP 404. `flake.nix:517` shows `branching-flow` was converted from an interim local `git+file://` path; the locked rev is either unpushed or the repo is private and CI fetches unauthenticated. Fix needs owner input (token in the workflow vs public/pushed source).
   - **(b) The statix lint leg exits 1:** live findings include `pkgs/geometrikks.nix:43` (inherit) and paren warnings in `lib/lock-audit.nix` / `flake/parts/checks/lint-static.nix` — none of them my files.
   - My local `nix flake check --no-build` is GREEN — the red is fetch-time (VM tests) + the statix leg, invisible locally.
   - **Queued while writing this report** (the report's own harvest obligation): `docs/todo/pipeline.md` + `TODO_LIST.md` row "Un-red the CI Nix-flake-check workflow".
2. **The prior report's 3 open questions — now dispositioned:**
   - **Q1 (keep the dep-sweep completion in crush-daily `16edaae`):** resolved by events — it is inside pushed v0.1.0, which SystemNix's lock consumes; keeping is the only coherent option (rewriting pushed tag history would poison the module proxy). No action.
   - **Q2 (pre-existing `TestLegacySnapshotRow_DecodesUnderNewStack`):** still failing, still fails on the pre-work baseline, still out of my change's blast radius. Left for a dedicated crush-daily dispatch (fixing an unrelated red test inside a release session is how scopes bleed).
   - **Q3 (repair the D/B5 daemon-heuristic commit messages):** decision taken, NOT executed — `ad678174` (D-block) is already **pushed**; rewriting pushed shared history in a multi-agent repo is a worse trade than a heuristic message, and per the daemon-race rule I verified WHAT the daemon staged before ever considering an amend: the two heuristic commits atop my push (`86f1b9c6`, `13e33a05`) contain **only parallel-session files** (crowdsec, tq-agent-pool, a status report, go-ecosystem.md). Amending would have absorbed foreign work. Nothing of mine rides a heuristic message.
3. **ucr-archive AGENTS.md accuracy.** The parallel session wrote a genuinely good AGENTS.md for the new repo but two claims went stale within the hour: "scripts/ is empty / sweep script not rehomed" (it is rehomed, committed in `d912299`) and "`nix run .#test` / `.#lint`" (those flake apps don't exist — no extraApps in the flake). I left the file alone because that session was mid-edit on it (bullet reordering observed live). Needs a 2-line fix at a quiescent moment.
4. **ucr-archive lint.** golangci-lint has ~10 default-linter findings (errcheck on help prints, ineffassign, unused) — noted by the parallel session, not cleaned. Cosmetic; the binary is correct.

## c) NOT STARTED

1. **CI fix for the two red classes** (queued this session, §b1).
2. **CI for ucr-archive itself** — the new repo has ZERO GitHub Actions (no test/build gate on push). Nothing guards v0.1.1.
3. **A repeatable parity harness** — the twin-sandbox parity lived in shell history + the report. It should be `scripts/parity-check.sh` in ucr-archive so v0.1.1 can re-prove itself against any future SystemNix archaeology.
4. **Rest of the pixel6 backlog** (untouched, out of scope): whisper transcription batch over 591 calls, Navidrome, index.csv contact enrichment, SHA256SUMS for non-UCR sets, adb udev rule, btrbk snapshot row, call analytics, human-friendly mirror tree.
5. **ucr-archive as a NixOS service** (serve `derived/web-archive` via Caddy + a regenerate timer) — nowhere on any queue yet; flagging as an idea, not a commitment.
6. **crush-daily test fix** (Q2 above).

## d) TOTALLY FUCKED UP

Nothing delivered is broken — every gate I own is green and the parity evidence is byte-level. The honest failures are process:

1. **I pushed onto a red CI baseline without looking.** My G3 checklist said "watch nix-check.yml" — as a POST-push step. One `gh run list` BEFORE pushing would have shown master red for 3+ hours and changed the push decision (or at least the close-out claim "CI watch" would not have silently inherited someone else's red). The close-out earlier in the session said "watch CI" — I watched AFTER, found red, and the first naive reading ("my push broke CI") was wrong, but I only know that because I dug. The check must run BEFORE the push.
2. **A vacuous verifier nearly produced a false PASS.** The report JSON "diff" early in parity used `jq` — which on this box is a nonstandard shim (`--version` errors with "function not defined"); it emitted nothing on BOTH sides, `diff` compared two empty streams, and I printed "REPORT-MATCH" from a comparison that never happened. Caught it minutes later (the follow-up `cat` showed real content), and the final report diff used `sed`. Lesson recorded: when a golden diff passes, sanity-check that the verifier actually saw the inputs (the FLAC/opustree `cmp`/`diff -r` results were real; this one wasn't, at first).
3. **Minor: I raced the daemon on the U8 commit** — my PATHSPEC commit failed because the parallel session had already committed the tree seconds earlier (`191dd21f`). Harmless (their message was proper, contents verified), but it means the "5 deleted scripts + annotations" commit ALSO carries their unrelated `pkgs/post-crash-calm-gate.nix` change — attribution mixing I could not prevent at commit time, only document.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-push CI baseline check as a standing rule** — `gh run list --limit 3` before any push; a red baseline goes into the close-out explicitly, never discovered afterward. (Candidate for AGENTS.md → Build & Deploy.)
2. **Commit new-repo work BEFORE the daemon slices it.** ucr-archive accumulated 6 heuristic commits before my squash; the squash worked only because the repo had no remote yet. First-commit-early costs nothing.
3. **Parity as a repo artifact, not a session.** `README-VERIFICATION.md` records RESULTS; a `scripts/parity-check.sh` would make them REPRODUCIBLE (next session can re-prove v0.1.x against Python git-history checkouts).
4. **Verify the verifier.** Any golden-diff "PASS" should print the compared byte counts. An empty-vs-empty diff is not a pass. (Cheap: `wc -c` both sides, assert > 0.)
5. **Parallel-session handoff on shared docs.** ucr-archive's AGENTS.md drifted from reality within an hour of being written because two sessions were converging on the same tree. A "claims about the tree get re-verified at commit time" habit (the AGENTS.md author could have `ls scripts/` before writing "scripts/ is empty") would prevent this class.
6. **upstream reporting for the ucr-rag.py embed bug** — it's a real bug in a shipped script (INSERT can never succeed); the script is now deleted here, but the finding belongs in the zero-python plan follow-ups as "noted, mooted by rehoming" so nobody re-imports the pattern. (I recorded it in README-VERIFICATION.md D4; a one-line note in the plan's EXECUTED banner would complete it.)

## f) Up to 50 things to get done next

Sorted by impact. **[Q]** = already a queued/library row (no new filing needed); **[N]** = new this report (the starred ones are harvested; the rest are brainstorm/ROADMAP fuel per the skill's >25 rule).

**Fleet-blocking (do first):**
1. [N★] Un-red CI: give the workflow auth for `branching-flow` (or push/repin the rev) — queued in pipeline.md + TODO_LIST this session.
2. [N★] Un-red CI: clear the statix leg findings (geometrikks.nix inherit + paren warnings) or scope the leg — same row.
3. [Q] Unblock the dispatch verify gate (hermes-agent re-pin + docs-scoped `.tq-verify`) — existing pipeline.md row, still blocking every SystemNix dispatch.
4. [Q] Deploy-intent convention for concurrent deploy loops — existing pipeline.md row, freeze-adjacent.
5. [Q] Verdict-durability rule (write `$TQ_RESULT_FILE` right after the report commit) — existing pipeline.md row.

**ucr-archive hardening (the new dependency deserves gates):**
6. [N] Add GitHub Actions to ucr-archive (go test + nix flake check + tag build) — currently zero CI.
7. [N] Fix the two stale AGENTS.md claims (scripts/ not empty; `nix run .#test/.#lint` don't exist).
8. [N] Zero the ~10 golangci-lint findings.
9. [N] Check in `scripts/parity-check.sh` (repeatable twin-sandbox harness from §c3).
10. [N] Unit-test the embed leg against a mock embeddings server (the only leg with no test).
11. [N] Add a NixOS module option (serve `derived/web-archive` + regenerate timer) — ROADMAP.
12. [N] Shell completions + a short man page (`ucr` has 9 subcommands now).
13. [N] One-line note in the zero-python plan banner: ucr-rag.py's embed INSERT bug is upstream-mooted by the rehoming.
14. [N] `go-release` hygiene for v0.1.1+ (CHANGELOG in ucr-archive — currently none).

**crush-daily:**
15. [Q] Fix/silence `TestLegacySnapshotRow_DecodesUnderNewStack` (Q2, still open).
16. [N] Decide whether `backfill` should also run on a timer for future gap detection (currently manual).
17. [Q] The floating-input watch rows from the dep sweep (templ-components v1.23.0 pin lockstep rule) — existing upstream rows.

**SystemNix docs/pipeline:**
18. [N] AGENTS.md knowledge-routing row for ucr-archive (where UCR questions route now that the scripts are gone).
19. [N] gotchas-archive entry: the parity method + the ucr-rag embed INSERT bug (the method is reusable; the bug is a trap for anyone reading old scripts in git history).
20. [N] Pre-push CI-baseline rule into AGENTS.md → Build & Deploy (from §e1).
21. [N] Check `docs/agents/*.md` for stale `scripts/ucr-*.py` references (storage.md's shellcheck narrative mentions ucr-ffprobe-sweep — historical, fine; shell-devtools.md unverified this session).
22. [Q] FEATURES.md — does it still describe the Python UCR tooling? (Not checked this session; 2-minute verify.)
23. [Q] Budget carve-out for done-prompt/verdict dispatches — existing [decision] row.
24. [Q] hermes-agent lock-drift eval error (pre-existing, documented in flake.nix interim note).

**pixel6 domain (the archive now has a fast Go tool — these get EASIER):**
25. [Q] Whisper transcription batch (GPU) over the 591 calls — feeds `ucr rag import` + embed directly.
26. [Q] Navidrome + FLAC leg (`ucr encode` output is Navidrome-ready; tags already written).
27. [Q] Enrich `index.csv` with call-log contact names (needs the XML pull → `ucr contacts derive` gets real names).
28. [Q] Udev rule for Google USB vendor 18d1 (adb) — single blocker for phone-side pulls.
29. [Q] SHA256SUMS for the Signal/WhatsApp/Cube sets (only UCR has a manifest).
30. [Q] `backups/pixel6` into the btrbk-pool snapshot set + freshness row.
31. [Q] Call analytics + prefix decode (0/1/3/5 = direction?) — pure query work over the Go-built SQLite index now.
32. [Q] Human-friendly renamed mirror tree (hardlink mirror).
33. [Q] `/tmp/pixel6-*.sh` transfer-script recovery into `scripts/` (or MOOT-close: transfer long done).
34. [N] Decide the fate of `/mnt/pool/backups/pixel6/2026-08-20/derived/contacts` (pre-Python-era leftover? the Go tool now owns that path — regenerate or delete).

**Larger arcs (ROADMAP fuel):**
35. [N] The web archive deserves a pass with real contacts (search + cards unify once whisper + VCF land).
36. [N] "Zero shell-rot" sweep: the same treat-the-scripts-as-a-product pass for the remaining `scripts/*.sh` (50+ files, some with drifted docs).
37. [N] Cross-repo input dedup: SystemNix's lock grew `branching-flow` + `crush-daily` + now potentially `ucr-archive` — the lock-audit infraDeps set should cover the new siblings deliberately.
38. [N] ucr-archive: `ucr root doctor` subcommand (validate a root: manifest/index/WAV presence, verdict census) — turns the FATAL messages into a preflight.
39. [N] Document the Ogg-serial non-determinism gotcha in nix/docs somewhere reusable (bit-identity ≠ byte-identity for lossy containers).
40. [N] consider `trash`-safety: `ucr` never deletes, but a `--prune` mode for `derived/` would tempt fate — decide NEVER up front and document.

*(Stopping at 40: items 41–50 would be filler; the top 24 carry the real weight.)*

**Harvest disposition (per the TODO-system rule):** item 1+2 (one row) harvested NOW into `docs/todo/pipeline.md` + `TODO_LIST.md` at report-authoring time. Items 3–5 are pre-existing rows (no action). Item 19's note is folded into item 13's one-liner when done. The rest are deliberately not harvested: they are either foreign-domain brainstorm (needs owner triage), ucr-archive-repo items (that repo owns its own queue once it has one), or pixel6 backlog rows that already exist verbatim in `docs/todo/pixel6.md`.

## g) Questions I can NOT figure out myself

1. **`branching-flow` CI auth:** the VM tests 404 on `github:LarsArtmann/branching-flow/tarball/aa1611d…`. Is that repo private (→ CI needs a token in the workflow — which secret name do you want used), or is `aa1611d` simply unpushed (→ push it / repin to a pushed rev)? I cannot see the repo's visibility or your auth intent from here.
2. **Should ucr-archive get real CI + a NixOS service surface now** (Actions on push + a module that serves/regenerates the web archive), or is it a manual operator tool where flake apps + tags are enough? This decides items 6/11 and whether v0.1.1 needs a release checklist.
3. **crush-daily's pre-existing red test** (`TestLegacySnapshotRow_DecodesUnderNewStack`, fails on the pre-work baseline): dedicated fix dispatch in crush-daily, or document-and-leave? It is the only red unit test in the dependency chain SystemNix now consumes at v0.1.0.

---

**Verification trail for this report's claims:** all commands were run live this session (flake checks local + pushed-SHA CI logs via `gh run view 38674953136 --log-failed`; parity evidence in ucr-archive `README-VERIFICATION.md`; guard greps shown in-session). No claim here is taken from another session's prose without having run it myself.
