# Task-Queue Window RE-VERIFICATION — 2026-11-15 14:21 (5th fire of the 2026-11-10 → 14 window)

> **SAME-WINDOW HIT — verification-only pass.** The dispatch-time dedup grep matched on the first probe: `2026-11-14_09-23_task-queue-window-closeout.md` (canonical, 4th fire) plus its two predecessor artifacts (`2026-11-14_08-42_task-queue-closeout-window.md`, `2026-11-14_09-14_task-queue-closeout-window-refire.md`) already cover this exact window — task IDs `…c14f087910`, `…c14f087b6ab`, `…c7a258eff`, `…d23e580d67`, `…d5d871644a`, verdict task `000001a1d8cbc3ff68f9d852788500000000`. Sections a)–d) are satisfied BY CITATION to the canonical report; every headline landing was re-grepped at HEAD `13da09cfd` and is marked green below; §h reads the journal fresh (with a design-limitation correction); the 5th dispatch itself is recorded as an improvement finding (§e.1).

Window: 5 completed tasks spanning 2026-11-10 → 2026-11-14. This file is the **5th artifact for one window**. Verification method: all four task closeout reports' headline claims re-grepped at HEAD (config settings, ticked rows by CONTENT grep — the canonical's cited TODO_LIST line numbers have all shifted as parallel sessions ticked+pruned rows); window commits re-verified via `git cat-file -e` + `git merge-base --is-ancestor` (all 11 ancestor-of-HEAD: `377a242f7`, `64c124592`, `316362190`, `d7963ea17`, `042f1044be`, `42fb02c17`, `fd42bde67`, `070eb35cf`, `889ee2b84`, `754320dce`, `4bb4a39e0`); journal via `tq facts` (see §h caveat).

## a) FULLY DONE

By citation to [2026-11-14_09-23_task-queue-window-closeout.md](./2026-11-14_09-23_task-queue-window-closeout.md) §a (its five items). HEAD re-checks — **all five GREEN**:

1. Task `…c14f087910` time_series_v2 library-row tick drift — commit ancestor; batch-parity claim holds (docs/todo/monitoring.md v2 rows ticked); gate-gap rows re-verified open (§c below). GREEN.
2. Task `…c14f087b6ab` gatus count drift — commit ancestor; README:82 prose still reads 302 (the canonical's live-eval re-stamp held); residue row 3480 still owns FEATURES L97 "133" / L637 "100" (both still stale — verified, not fixed since, correctly queued). GREEN.
3. Task `…c7a258eff` adb mDNS verified intentional — commit ancestor; TODO_LIST row (now line 386, was 383) still `[x]` with the VERIFIED INTENTIONAL verdict + `ADB_MDNS=0` note. GREEN.
4. Task `…d23e580d67` undersized budgets — code commit ancestor; **cvagent.nix:221 `MemoryMax = lib.mkForce "1G"`** (serve unit) with **:202 scan oneshot still 512M**, **forgejo.nix:553 `MemoryMax = "1G"`** — all green at HEAD (line numbers drifted ~+15 from the canonical's cites via parallel edits; settings intact); queue row 393 `[x]` with the full DONE narrative. GREEN.
5. Task `…d5d871644a` ai-stack 5-item batch — all 5 commits + closeout ancestors; **llama-rag.nix:94–95 + nsfw-classifier.nix:172–173 still carry `RestartSteps = 5` / `RestartMaxDelaySec = "15min"`**; monitoring.md:84 carries the pid-churn probe rule (resolve MainPID at start + post-assert liveness); re-embed design doc exists (docs/planning/2026-11-14_06-15_re-embed-calm-window-batch-design.md — post-canonical citation fix `1f04026ba`, benign). GREEN.

**Green drift since the canonical fire (landed, not in it):** the canonical's §f.11 next-item "llama-chat crash-loop backoff" is DONE — TODO_LIST row 3605 `[x]` (DONE 2026-11-14) and **llama-chat.nix:239–240 carries the same RestartSteps=5/15min settings**, riding the 2026-11-14 crash-loop-fix wave (CHANGELOG entry 27). Cited-not-re-minted.

## b) PARTIALLY DONE

By citation to the canonical report §b; drift re-check at HEAD:

1. Budget-fix verification half — still open: queue row 3582 (was 3565) `Post-restart re-read of the cvagent + forgejo memory.watermark counters`, deploy-gated behind the foreign-breakage deploy block (row 3596 lineage). Row 393's DONE note carries the same re-read obligation inline. Consistent — not faked.
2. Re-embed work design-only — unchanged: implementation row 3604 open, design row 417 `[x]` with "implementation remains a follow-up row".
3. Write attribution inner mechanism unpinned — unchanged: io.stat instrumentation row 3602 open; Samsung 16.6 TiB write-rate attribution row 3603 open.
4. pid-churn evidence mechanism-level — unchanged (journal vacuumed; monitoring.md:84 documents it).
5. Restart backoff spec deviation — still blocked:user, row 3618 (was 3600). Owner has not ruled.
6. Count-consistency class — the canonical's FRESH instance persists verbatim: **README:18 services table still says 298** while README:82 says 302 (re-grepped this pass); row 3625 open. FEATURES L97/L637 still stale under row 3480.
7. Shellcheck residue on test-psi-percent-semantics.sh — row re-verified open (shellcheck-skip class; bash -n + 38-leg execution evidence stands).
8. The closeout loop itself — **see §d.1: the chain grew a fifth artifact.**

## c) NOT STARTED

By citation to the canonical report §c. All cited rows re-located BY CONTENT and verified open at HEAD (line numbers moved as parallel sessions ticked/pruned — content is authoritative): tick-state parity 3477, same-report Source resolution 3478, check-todo-system `--selftest` → flake check + CI 3479, FEATURES re-stamp + doc-counts anchors 3480, SigNoz 52/10 vs 54 mkRule 3481, AGENTS.md count-citation rule 3482, io_warning 10.00-exact legs 3583, mutation-leg audit 3584, post-restart counter re-read 3582 (deploy-gated), re-embed implementation 3604, Samsung 16.6 TiB attribution 3603, io.stat instrumentation 3602, README:18 re-stamp 3625, AGENTS.md ritual row (canonical 3599 → current 3599-area, open in pipeline.md:1096), backoff regression test (canonical 3589) + fixed-RestartSec fleet sweep (canonical 3588) — present in the ai-stack/pipeline libraries per the canonical's §c inventory, not individually re-grepped (low churn risk). Also still open from the canonical's §c: llama-embeddings gated-fleet DARK streak (canonical 3595 — the report's highest-value item), CI red cluster, audiblesync deploy-path rows. One canonical row pair NOT re-located by content grep: the IO-counters-doc duplicate pair (canonical 3593/3597) — flagged in §e.5, not re-minted (dedup discipline).

## d) TOTALLY FUCKED UP

By citation to the canonical report §d (items 3–8 re-verified still accurate at HEAD; the daemon-footless-commit and tick-co-ride history cannot change). New instances this pass:

1. **The window's closeout chain is now FIVE artifacts.** The 4th fire applied the verdict-immediately-post-commit rule (row 1485) and recorded its verdict — and the queue STILL re-fired this window ~29 h later (2026-11-15 14:21). From a dispatched shell I cannot distinguish the two surviving hypotheses: (a) the verdict write failed silently again (the 0-byte `$TQ_RESULT_FILE` class, row 1778), or (b) the pool re-dispatches done prompts regardless of recorded verdicts (row 1479's guard still unbuilt; the 2026-10-15 done-prompt re-fire is the prior instance). Either way rows 1479/1778/3624 just gained their strongest live reproducer: a recorded verdict did not prevent the 5th dispatch. Dispatch-side note: THIS fire's dispatch prompt carried a NEW explicit dispatch-time dedup instruction (grep the index + window reports for the task IDs BEFORE deriving), and it worked — one grep produced the same-window verdict. The queue side still owes its guard.
2. **Canonical §h overclaim correction:** the 4th fire's §h said band-drift "verified live at 09:3x (0 facts)". This pass discovered `tq show` refuses with the verbatim hint _"resolved db: tasks.db — in a dispatched agent shell TQ_DB is stripped, so this is the cwd fallback, likely not the dispatching queue's journal"_ — the readable `./tasks.db` here is a stale 2026-10-10 artifact. A dispatched shell structurally CANNOT verify the live journal; "(0 facts)" reads describe the stale fallback, not the queue. The canonical's §h conclusion is directionally plausible but its "verified live" label overstated what the read could prove. This report's §h states the limitation explicitly.
3. **This pass's own near-miss (self-inflicted, caught):** a shell `case`-pattern state-check used the glob `'- [ ]'*`, in which `[ ]` is a CHARACTER CLASS — every row came back "UNEXPECTED" and the broken output nearly read as "all cited rows drifted". Caught by the quote-scrutiny known-value rule before it entered any report; re-verified with `rg -F` content greps. Lesson recorded in docs/agents/shell-devtools.md (this pass) and applied throughout: checkbox-state checks use grep -F/rg, never case globs. (Sibling of the documented `rg -r` and jq-in-direnv traps.)
4. **Line-number citations in the canonical report are all stale** (rows pruned/shifted by the intervening audiblesync/takeout sessions — e.g. its 3460/3461/3462 now sit at 3477/3478/3479; its 3565 at 3582). Expected decay, no action beyond this report citing content-anchored state; the citation-rot lint row already owns the class.

## e) WHAT WE SHOULD IMPROVE

1. **Close the done-prompt re-fire loop at the queue layer** — rows 1479 (queue-side guard: window IDs all footer-committed + existing window-closeout report ⇒ verified no-op) and 1778 (0-byte verdict diagnosis) now have a fifth-fire reproducer where a recorded verdict preceded re-dispatch. The agent-side dedup instruction added to this fire's dispatch prompt is half the fix; the queue-side guard is the other half and is still unbuilt. Cite; not re-minted.
2. **Re-verification passes write their own short report (this contract); row 3626's adopt-and-amend protocol stays scoped to UNFILLED-skeleton re-fires** — this fire followed the newer dispatch-time dedup contract (verification-only pass, short same-shape report naming the earlier report); conflating the two shapes would either bloat the canonical file or skip the landing re-greps. One sentence of scope clarification in docs/CONTRIBUTING.md's re-dispatch section would prevent the next fire from guessing (cheap doc edit, foldable into row 3626's dispatch).
3. **§h band-drift honesty:** window reports must label journal reads as design-limited in dispatched shells (TQ_DB stripped) — "none recorded in the readable journal", never "verified live", unless the shell demonstrably resolves the queue's DB. One sentence for the next report template; no separate row (covered by this report + §d.2).
4. Canonical §e items 1–9 stand as written (batch-closeout hygiene stays top pipeline priority: rows 3477–3479; doc-counts widening 3625/3480/797; verdict timing 1485/3624; query-premise discipline 3594-lineage; spec-deviation flagging; daemon-swept shellcheck 3598-lineage).
5. **Dedupe the IO-counters-doc row pair at its next dispatch** (canonical §f.17; not re-located by this pass's content greps — one of the twin rows may already be pruned/ticked; verify before dispatching either).

## f) NEXT THINGS

Dedup-checked against the queue — **zero new rows minted for items 1–14; every high-value next item already exists as an open row** (current line numbers, content-verified this pass):

1. **3595-lineage: gated-fleet DARK streak** (llama-embeddings dependency-failed since 11-08) — still the highest-value item; re-verify it survived the intervening sessions before dispatching.
2. 3582 post-restart cvagent/forgejo counter re-read (deploy-gated; closes task 4's verification half).
3. 3604 implement the calm-window re-embed batch per the landed design.
4. 3477 + 3478 + 3479 the pairing/selftest gate legs (kill the reviewer-found drift class behind two of the window's five tasks).
5. 3625 README:18 298→302 re-stamp + anchor widening (the drift is still live, re-verified today).
6. 3480 FEATURES L97 "133" / L637 "100" re-stamp + anchors (both still stale, re-verified today).
7. 3481 SigNoz 52/10 vs 54 mkRule reconciliation.
8. 3482 AGENTS.md batch-final count-citation rule sentence.
9. 3618 restart backoff spec ruling (blocked:user) — one-line owner answer unblocks.
10. 3619 / 382 time_series_v2 drop ruling (blocked:user; the parked tq question expired 2026-11-12 per row 382 — needs a fresh ruling channel, owner action).
11. 3603 Samsung 16.6 TiB/7d write-rate attribution (wear-rate alarm).
12. 3602 io.stat instrumentation of the next serving window.
13. 3605-adjacent: verify the llama-chat backoff's extendModules render claim at the unit's next enable decision (blocked on the owner's disable-or-pin ruling — cited, no new row).
14. 2550 CHECK_TODO_PAIRING strict-default decision (blocked:user).

**NEW this pass (appended to TODO_LIST, 1):** the dispatched-shell journal-access question — see §g.1, appended as a blocked row (queue-contract design, owner-owned).

## g) QUESTIONS FOR THE OWNER

1. **NEW — BLOCKED**: Should dispatched closeout shells get read-only access to the live tq journal (TQ_DB currently stripped by design), so §h band-drift attestations are verifiable instead of design-limited? Every window report's band-drift section (including the canonical's "verified live" claim) has been reading a stale cwd-fallback DB. — appended to TODO_LIST as a blocked row; owner decides the pool contract (sibling of row 3624's contract theme, distinct ask).
2. Cited, not re-minted (already dispatched as blocked rows): gate hardness / CHECK_TODO_PAIRING strict default (row 2550); restart backoff 5/15min-vs-4/10min+jitter ruling (row 3618); time_series_v2 DROP ruling (rows 382 + 3619 — the original tq question expired 2026-11-12 while the DROP still awaits you; a fresh answer re-arms the row).

## h) BAND DRIFT

`tq facts --type task.reprioritized` → **(0 facts)** — read fresh this pass (2026-11-15 14:2x), **with the design limitation stated per §e.3**: in this dispatched shell TQ_DB is stripped (per `tq show`'s own hint), so the read resolves the stale cwd fallback `./tasks.db` (mtime 2026-10-10) — **none recorded in the readable journal; the live journal is unreadable from here**. No priority move is recorded anywhere this fire could observe, and the dispatch sequence (5 fires, one window) is lease/verdict mechanics (§d.1), not reprioritization. This corrects the canonical §h's "verified live" phrasing (§d.2).

## Docs-health pass notes (2026-11-15 14:2x)

- TODO_LIST: dedup check run BEFORE appends (content greps, not line numbers — the canonical's cited numbers have all shifted); 1 new blocked row appended (§g.1); no reworded duplicates minted; the llama-chat backoff upgrade (row 3605 `[x]`) recorded here rather than re-minted.
- CHANGELOG: the window's user-visible entry is present (line 37, AI-stack resilience wave) and the intervening crash-loop-fix wave entry (line 27) already covers llama-chat's backoff — nothing to append from this docs-only pass.
- README.md: line-82 prose at 302 (current); line-18 table at 298 (stale, row 3625 — the compliant fix needs a doc-counts anchor extension, a flake edit outside the docs-only hard scope; left queued, consistent with the canonical's ruling).
- FEATURES: header re-stamped 2026-11-15 09:0x by the audiblesync wave (module row current); the two gatus assertions stay owned by row 3480 (anchor coupling, same scope rule).
- docs/status/README.md: live-pool addendum appended at top for this re-verification, following the window-closeout precedent.
- Archive: no moves — the two predecessor files (08-42, 09-14) are referenced by live reports and each other's fold-into annotations; the canonical carries open routed rows; docs/status/archived/ untouched.
- Reports under docs/status/ dated 2026-11 read this pass: the four window closeouts + spot checks of the intervening audiblesync/takeout reports for harvest state (their follow-ups ride rows 3625-lineage and the audiblesync cluster — consistent with the tree).
- docs/agents/shell-devtools.md: one new trap bullet (shell `case` glob character-class vs literal checkbox patterns), cited in §d.3.

Task-Queue-ID: 000001a1d8cbc3ff68f9d852788500000000
