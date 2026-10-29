# Contacts & Calendar Ownership — Doctrine Written Down + Bidirectional Mesh Proposal

**Session:** 2026-10-29 ~20:5x → 21:43 (single agent session, no deploys)
**HEAD at authoring:** `3f8e6307b` (a parallel session's row commit landed on top of mine)
**My commits (daemon-swept):** `d9ed387f0` (ownership page + first todo rows) · `42af70367` (AGENTS routing + docs/agents README) · `1b8634ee7` (page edits + CHANGELOG + services rows + the proposal HTML)
**Scope:** documentation and doctrine only. No code, no Nix, no deploy, no credentials, no Google account touched.
**Trigger:** "Who owns my Contacts? Who owns my Calendar? Who should own my X?" → then "two Google accounts hold both; I want bidirectional sync with a real owner I control, data-mesh style; read the pbx-artmann data-ownership doc; create a proposal HTML I can review."

**Artifacts produced**

| Artifact | Path | State |
| --- | --- | --- |
| Fleet ownership doctrine | `docs/agents/data-ownership.md` (117 lines) | committed `1b8634ee7` |
| Bidirectional proposal (reviewable) | `docs/planning/2026-10-29_21-18_contacts-calendar-mesh-proposal.html` (3.5 MB, sha256 `e9027f7cd798e50e…`, 2294+ lines, 2 inlined-mermaid figures) | committed `1b8634ee7` |
| Routing + index rows | `AGENTS.md:24`, `docs/agents/README.md` Files table | committed `42af70367` |
| CHANGELOG entries | `CHANGELOG.md` (2 entries, top of file) | committed `1b8634ee7` |
| Harvested rows | `docs/todo/services.md` (3 rows), `TODO_LIST.md` (1 queue row) | committed `d9ed387f0`/`1b8634ee7` |

---

## a) FULLY DONE

1. **Answered the original ownership question with a stated rule** — "ownership = write authority + a restore path you have actually run + an export path; mirrors and projections are not owners". `docs/agents/data-ownership.md:7-28`. Evidence: file committed; `check-doc-links.sh` OK.
2. **Built a 15-domain ownership inventory** (contacts, calendar, mail, files ×2, photos, documents, tasks, source code, chat, money, RSS, browser history, identity, registry) with owner, class, restore leg and a `file:line` citation per row. `docs/agents/data-ownership.md:30-60`.
3. **Found and documented the real gap behind the question** — contacts truth is declared (Kith journal, `crm.nix:128,372`) but the journal holds **zero** people contacts while 139 sit in a dead Twenty dump (`docs/todo/services.md:363`); calendar has **no owner anywhere** (no CalDAV server, no DAV client, `FEATURES.md:251`), and the offsite backup leg is dormant with the app-dump restic repo pool-local (`offsite-borg.md:9-12`, `restic-app-dumps.nix:6-10`).
4. **Read the pbx-artmann doctrine you pointed me at** (146 lines) and **discovered a doctrine collision** — three ownership documents, two opposite answers, one of them citing the same 2026-10-19 constitution clause: `crm/docs/DATA-MESH.md:18` (Kith owns contacts, Stalwart is an OUT-mirror) + `nix-email/ROADMAP.md:142-155` (same) vs `pbx-artmann/docs/architecture/data-ownership.md:38,66-81` (Stalwart owns personal PII; Kith must never be the book). Recorded as the proposal's headline finding (§03).
5. **Wrote the reviewable proposal HTML** — hero/verdict, evidence table (§02), collision matrix (§03), two end-states with a recommendation (§04), target topology + spoke contract (§05), five sync-semantics rules (§06), calendar hazards (§07), 9-phase dark-launch ladder with per-phase gates and kill switches (§08), risk table (§09), governance/metrics/restore-drill + acceptance criteria (§10), six pre-code verifications (§11), six owner decisions (§12), alternatives dismissed (§13), effort appendix.
6. **Built the HTML the repo's way, not by hand** — copied the kit's editorial template (`cp` + `head -849`), never transcribing CSS (`diff` of head/CSS vs template = identical), inlined the canonical mermaid bundle from `~/.local/state/systemnix/`, spliced the `.mermaid` CSS block and `mermaid.initialize` block out of `docs/planning/2026-10-02_11-51_disk-layout-current-state.html` rather than retyping them.
7. **Verified the artifact with the repo's own gates** — `scripts/verify-html-diagrams.sh` → `PASS (2 diagram(s), 2 SVG(s), 0 error-bombs, anchors OK)`; ad-hoc python structural check → 0 tag errors, 14/14 nav anchors resolve, **0 external refs** (self-contained), 3,663,043 bytes.
8. **Answered "what is the data-mesh answer to bidirectional"** — bidirectional *flows* to a single owner is mesh-legal; two *owners* is not; the adapter is a cache (its 0600 state is disposable and re-derivable), and every spoke gets direction + join key + actor + trust posture declared (§05 contract table extending `DATA-MESH.md` §2).
9. **Harvested the direct follow-ups** — `docs/todo/services.md`: the D1/D2 `[decision]` row (superseding the narrower calendar-ownership row), a `[ready]` TaskChampion restore-path row; `TODO_LIST.md`: the TaskChampion queue row.
10. **Wired discoverability for the doctrine page** — AGENTS.md routing row ("Who owns X?") + `docs/agents/README.md` Files row + 2 CHANGELOG entries.
11. **Ran the formatter gate on everything I edited** — `nix fmt -- --fail-on-change` on the 6 touched markdown files: `traversed 6 files … formatted 6 files (0 changed)`, rc=0. My earlier worry that a prefix-replacement could have left non-canonical markdown is closed by measurement.
12. **Confirmed the HTML is exempt from format churn before it could be damaged** — `flake/parts/formatter.nix:42-43` inserts `docs/**/*.html` into the treefmt excludes (the 2026-09-20 double-inflate class); verified statically and by deliberately *not* running `nix fmt` on the 3.5 MB file.
13. **Kept every claim at least repo-traceable** — the proposal cites `~/projects/crm` (gcontacts, carddav, syncfile), `~/projects/nix-email` (CardDAV probes, 0.16.26 pin, the CalDAV rebrand comment), `~/projects/pbx-artmann`, and this repo's own docs, with "unverified" spelled out where it applies.

---

## b) PARTIALLY DONE

1. **The doctrine collision is documented, not resolved.** I did not reconcile `docs/agents/data-ownership.md`, `crm/docs/DATA-MESH.md`, `nix-email/ROADMAP.md` §5 and `pbx-artmann/…/data-ownership.md`. Deliberate (it is D1/D2, an owner call), but the fleet is still in the state the pbx doc itself calls out: two answers, neither retired. **Remaining:** one canonical decision record; **Effort:** S once decided.
2. **The proposal's discoverability is half-wired.** It is linked from `docs/agents/data-ownership.md` (Known gaps + See also), the todo row and the CHANGELOG — but **not** from `docs/README.md` Key Documents, the root `README.md` docs table, or any index in `docs/planning/` (that directory has none). Today it is findable only by grep or by following the doctrine page.
3. **Six verifications are identified but zero are run** (§11): Stalwart CalDAV behaviour, the mail plan's addressbook/calendar object dialect, Google People write semantics, Google Calendar sync/notification semantics, the two accounts' real inventory, and the adapter's transport/trust path.
4. **Google-side claims are labelled unverified but are still prose.** §07's hazards (recurrence overrides, attendee notification suppression, token-expiry full resync, timezone preservation) come from my knowledge of the APIs, not from a probe transcript or a quoted API doc. §11 admits this; a reviewer still cannot cite a source per hazard.
5. **The "0.16.26" and "CardDAV probe-verified" facts are repo-sourced, not live-probed.** They come from `~/projects/nix-email` (FEATURES/TODO/lock), which is the right authority for its own artifact — but the *deployed* mail host was not probed (out of scope this session, and the host's live state is explicitly tracked as an owner-gated go-live).
6. **The inventory's "should be" column is doctrine, not verified capability** (e.g. Stalwart "should be" the PII owner assumes its CalDAV/provision gaps close — one of the six verifications).
7. **One inventory row is honestly unknown** (`?`): TaskChampion's restore path — no dump leg found in module or runbook; now queued.
8. **Two surfaces in the inventory were never inspected**: `webphone`'s "contacts" feature (listed in `catalog-platform.nix:67`, no direction established) and the FreeSWITCH directory (asserted "not a contact book" from the pbx doc only).
9. **The intermediate build layer lives outside the repo** (`~/.cache/mesh-proposal/`: `body.html`, `s1/s2/final.html`, `mermaid.css`, `mermaid-init.html`). That was a deliberate `/tmp`-avoidance choice, but it is the thing you corrected — see (d)#2.
10. **No decision record exists for the topology.** SystemNix has `docs/adr/`; the proposal is a planning artifact, so nothing durable records "Mesh A vs B" in an ADR-shaped place once you decide.

---

## c) NOT STARTED

1. **D1/D2 (and D3–D6) decisions** — owner-gated; every downstream item waits.
2. **P0 read-only inventory of both Google accounts** — no credential exists, no read performed, no counts/overlap/dedup data. There is no GCP OAuth client wired for the CRM in this fleet (`docs/todo/services.md:364`).
3. **Any adapter code** — deliberately zero lines. No People write path, no Calendar adapter, no merge engine, no conflict queue, no tombstone/undo surface.
4. **The six verifications** — including the one that could invalidate the recommended topology's calendar half (CalDAV).
5. **Cross-repo rows for those verifications** — `nix-email` would own the CalDAV probe row (its CardDAV probe suite is the pattern; it currently has **no** CalDAV row), and `pbx-artmann` already owns `pim-ownership-declare` for the plan dialect. I did not edit sibling repos (see question Q2).
6. **A research-dossier home for the evidence layer** — `docs/research/` has a hand-maintained index with an explicit doctrine (live-probe phase required for audit-style dives); my work produced no dossier there and no index row.
7. **Reconciling the "future owner" story into FEATURES/ROADMAP** — neither repo's FEATURES file states the bidirectional plan.
8. **Any guard for the new docs** — nothing checks that `docs/agents/data-ownership.md` stays true as the fleet changes (its inventory is prose; only my own session verified it).
9. **Real-browser check of the HTML** — headless render only; no dark-mode/second-theme variant; no mobile spot-check.
10. **The two Google accounts' export/Takeout escape hatch** — recommended as P0's deliverable, not yet produced.

---

## d) TOTALLY FUCKED UP!

1. **I damaged a CHANGELOG entry mid-session with a prefix-based replacement, and had to repair it.** *(Severity: moderate — caught and fixed in-session; the risk class is exactly the one AGENTS.md warns about for single-physical-line rows.)* The previous entry's bold title was consumed by my `edit` and its body text was left as an orphan line beginning `" — the Contacts/Calendar question…"`. Root cause: I anchored an exact-match edit on a *substring* (`- **Data-ownership doctrine written down: …**`) instead of the whole line/hunk. Mitigation: repaired immediately (verified both entries intact), and `check-doc-links`/`check-todo-system`/fmt all re-run clean afterwards.
2. **I put the build/intermediate artifacts somewhere you did not want them** (`~/.cache/mesh-proposal/` instead of a repo location such as `docs/research/`) — you had to correct me, and I then kept the final in `docs/planning/` (which you accepted). Compounding factor: `docs/agents/README.md` (which I *did* read) points at `docs/research/README.md` as the repo's index doctrine, and I never opened it. Root cause: I optimized for "keep scratch out of the repo, `/tmp` is volatile" and never asked which repo location owns research-shaped artifacts.
3. **A blocked tool call: `rg -rn …`** — the hook rejected it (the third-strike `-r/--replace` trap that is written into this repo's AGENTS.md). Cost a round-trip and made me re-run as `rg -n`. Root cause: grep muscle memory.
4. **I duplicated a table row in `docs/agents/README.md`** (a second `git.md` row) because I anchored on the wrong neighbouring line, then removed the duplicate. Impact: one wasted edit on a routing surface; a careless second duplicate would have shipped.
5. **A first `multiedit` on `docs/todo/services.md` was rejected** ("you must read the file before editing it") because I had read it with `sed` instead of the View tool. Root cause: treating shell reads as satisfying the read-before-edit contract.
6. **Same prefix-replacement pattern produced two more near-misses** (the todo rows and the second CHANGELOG insert) — both reviewed and confirmed correct, but the pattern, not the outcome, is the finding: on one-line rows my edits were risky by construction.
7. **An unverified premise is printed as fact in the proposal's first evidence row** — "Google … the only place holding the real bytes" rests on your statement plus the *absence* of in-fleet stores. Nothing read a Google account. It is labelled as your premise in the row, but it reads as evidence, and in a review document that is a claim I cannot back.
8. **I asserted upstream capability from a comment, not from behaviour, for the calendar half** — "CalDAV since the 0.12.0 rebrand" comes from a vendored module comment (`stalwart-module/default.nix:65`); no probe, no upstream doc quote. The proposal flags it as unverified, but the *proposal's recommendation* (calendar belongs on Stalwart) leans on it.
9. **`nix flake check --no-build` was not run.** No Nix files changed, so the eval gate has nothing to check — recorded explicitly rather than left implicit, because "I made no Nix changes" is the only reason it is defensible.
10. **I never asked where the proposal should live before writing 3.5 MB into `docs/planning/`.** The kit's category list includes `proposals/`; this repo has none; SystemNix `docs/planning/` was my silent choice, and the cross-repo question ("should this live in the crm repo, whose doctrine it mostly argues about?") was never raised. You ratified planning afterwards, but the choice was unilateral at write time.
11. **Pre-commit legs for the daemon's commits are unverified by me.** My work landed through `chore: auto-commit … (heuristic)` commits; I did not confirm whether the hook ran gitleaks/shellcheck legs or was bypassed. Nothing sensitive was written (docs only, no values), so the risk is process-integrity, not leakage — but "I did not check" is the honest state.

---

## e) WHAT WE SHOULD IMPROVE

1. **Full-line or hunk-anchored edits for single-physical-line files** (`TODO_LIST.md`, `CHANGELOG.md`, library rows). Impact: one damaged entry this session, two near-misses. Fix: anchor on a whole line including its marker (`- [ ] [decision] **…`), or edit with more surrounding context; never replace a bold title prefix.
2. **Add a guard for orphaned continuation lines.** Impact: this is the second documented occurrence of the class in this repo. Fix: extend `scripts/check-todo-system.sh` (or add a leg) to fail on a `TODO_LIST.md`/`CHANGELOG.md` line starting with `" — "`, `"- "`-less fragments, or any line whose predecessor ends mid-sentence without terminal punctuation.
3. **Adopt the View-tool read as the only "read before edit"** — bash `sed`/`cat` output does not satisfy the edit contract and cost a rejected call.
4. **Decide the artifact home *before* writing, and say it out loud in one line.** Concretely: check `docs/README.md`, `docs/agents/README.md`, `docs/research/README.md` for the index doctrine, then state "final → X, intermediates → Y" so a one-word correction is possible before 3.5 MB exists.
5. **Give `docs/planning/` (or the docs tree) an index.** Today a planning artifact is discoverable only by grep; `docs/research/` solved this with a maintained table. Impact: the proposal is the fleet's only written position on a live ownership question and nothing links to it from the top-level docs.
6. **Cross-repo permissions should be asked up front, not assumed away.** I left the `nix-email` CalDAV probe unqueued rather than creating a row in another repo. Better: ask at kickoff "may I touch sibling repos' TODOs?" — a 1-line question that unblocks 3 rows.
7. **Label every unverified premise inline in review documents, not in a section.** Impact: a reviewer of §02/§07 currently has to jump to §11 to learn what is assumed. Fix: a small `<span class="badge badge-medium">unverified</span>`-style marker (or plain `[unverified]`) on the exact sentence.
8. **Fix the stale skill reference.** The status-report skill points at `docs/decisions/2026-10-27_open-decisions.md`; there is no `docs/decisions/` in SystemNix (verified this session). Impact: the next session following that pointer wastes a lookup. Fix: point it at the repo that actually owns that file, or drop the pointer.
9. **Add a "last verified" line to doctrine pages.** My `docs/agents/data-ownership.md` says when it was written but not when its rows were last checked against reality; the pbx doc's `Status: living doctrine` framing plus a date is the better shape, and the fleet's own docs generally need this.
10. **Codify the research-artifact convention in AGENTS.md.** One paragraph: "research/dossier-shaped output → `docs/research/` + index row; throwaway scratch → `~/.cache/<topic>/`; never `/tmp`". Impact: removes the guess that produced tonight's correction.
11. **Proposals should carry a claim ledger.** A short table mapping each load-bearing factual claim → evidence → verified Y/N. Impact: makes the §11 boundary machine-checkable, and makes a future verify pass mechanical instead of a re-read.
12. **Effort estimates in proposals should be ranges with a confidence note.** Mine are qualitative on purpose; giving "S/M/L + uncertainty" per phase would let you slice scope (e.g. "calendar after contacts") with real numbers.

---

## f) Top next tasks (ranked by impact; 34 items)

| # | Task | Impact | Effort | Category |
| --- | --- | --- | --- | --- |
| 1 | Decide **D1** (Mesh A vs Mesh B) — topology gates everything else | Critical | S | Decision |
| 2 | Decide **D2** — amend the CRM mesh "never writes back" rule to field-scoped low-trust writes + conflict queue, or drop the bidirectional ask | Critical | S | Decision |
| 3 | Reconcile the three ownership doctrines into one canonical record and retire the losing claim (this page / `DATA-MESH.md` / pbx doctrine / `nix-email` ROADMAP §5) | Critical | S–M | Documentation |
| 4 | Run the **Stalwart CalDAV probe** on the pinned rev in the demo VM, mirroring the CardDAV suite (discovery, MKCOL, conditional PUT, sync-collection) and land a transcript | Critical | M | Quality |
| 5 | Verify the **mail plan dialect** accepts addressbook + calendar objects at the pin (the pbx `pim-ownership-declare` row); record a refusal as a finding if it does | Critical | S | Quality |
| 6 | Produce the **read-only inventory of both Google accounts** (collections, counts, overlap, duplicate clusters, group vocabulary) + full exports as the escape hatch | High | M | Quality |
| 7 | Index the proposal + the ownership page in `docs/README.md` Key Documents (and consider a `docs/planning/` index) | High | S | Documentation |
| 8 | Add the task-6 dedup report as a pre-condition of any write path (the overlap is the reason the two accounts exist in this shape) | High | S | Quality |
| 9 | Verify the **adapter transport + trust path** (evo-x2 ↔ mail host over the mesh; private CA vs mesh-bound listener — undecided in the pbx repo) | High | M | Quality |
| 10 | Probe **Google People write semantics** on a throwaway account (update + etag/conflict, group handling, photo resources, batch limits) with transcripts | High | M | Quality |
| 11 | Probe **Google Calendar incremental sync** (token expiry → full resync, deleted-item visibility, notification suppression on write) with transcripts | High | M | Quality |
| 12 | Write the **conflict model** on paper before code: merge base per item, field-level provenance, ambiguity → queue, and the exact undo of a creation | High | M | Design |
| 13 | Specify the **tombstone/deletion policy** (review queue, per-run delete ceiling, "never auto-delete") as a written contract | High | S | Design |
| 14 | Specify the **opacity contract** (unmodelled fields + vendor properties round-trip byte-for-byte) with the fixture that will prove it | High | S | Design |
| 15 | Add the **stray-continuation-line guard** to `check-todo-system.sh` (or a new leg) for `TODO_LIST.md`/`CHANGELOG.md` | Medium | S | Quality |
| 16 | Add a **"last verified" convention** to doctrine pages and stamp `docs/agents/data-ownership.md` | Medium | S | Documentation |
| 17 | Codify the **research-artifact convention** in AGENTS.md (docs/research + index row vs `~/.cache/<topic>` scratch vs `/tmp prohibition`) | Medium | S | Documentation |
| 18 | Fix the **stale `docs/decisions/…` pointer** in the status-report skill (path does not exist in this repo) | Medium | S | Cleanup |
| 19 | Ask the **cross-repo permission question** and, if granted, land the CalDAV + plan-dialect rows in `nix-email`/`pbx-artmann` | Medium | S | Process |
| 20 | Decide **D3** — which account stays symmetric, and whether devices keep using Google in phase 1 | Medium | S | Decision |
| 21 | Decide **D5** — duplicate policy for the overlap + the route for the 139 staged Twenty contacts (import into the owner once, at P2) | Medium | S | Decision |
| 22 | Decide **D4** — contacts-only first vs contacts + calendar in one doctrine change | Medium | S | Decision |
| 23 | Decide **D6** — adapter placement (fleet host vs mail host) + cadence (poll vs push channels) | Medium | S | Decision |
| 24 | Write **acceptance criteria** into a testable form (edit appears in owner + other account within 2 cycles, one event, right actor; rerun = zero writes; weird-object round trip) | Medium | M | Quality |
| 25 | Design the **conflict queue surface** (where you actually see it: CRM UI vs dashboard tile) and the metrics it publishes | Medium | M | Design |
| 26 | Add the **metrics/alerts plan wire-up list** (per-spoke lag, conflicts pending, tombstones held, deletions refused) to the monitoring library once the adapter exists | Medium | S | Monitoring |
| 27 | Give the proposal a **claim ledger** (claim → evidence → verified?) so the §11 boundary is mechanical | Medium | S | Documentation |
| 28 | Add a **decision record** in this repo for the topology once D1 is answered (ADR-shaped, not a planning file) | Medium | S | Documentation |
| 29 | State the bidirectional plan in the **CRM's FEATURES/ROADMAP** (the constitution currently reads "never writes back") | Medium | S | Documentation |
| 30 | Add a **doctrine-drift check**: one grep-able assertion that the fleet page, the CRM constitution and the pbx doctrine name the same owner per entity type (or fail loudly) | Medium | M | Quality |
| 31 | Run the **restore drill** for whichever store becomes the owner (restore + re-converge both spokes, no duplicates) | Medium | M | Quality |
| 32 | Document the **Google-side operational risks** (GCP project, consent screen, publishing status, 7-day testing-mode token trap, quotas) in the mesh runbook | Medium | S | Documentation |
| 33 | Decide the **proposal's long-term home** if it should live beside the doctrine it argues about (crm repo) rather than in SystemNix planning | Low | S | Decision |
| 34 | Add a **dark-theme/second-variant or browser spot-check** of the proposal before it is archived as the canonical review artifact | Low | S | Cleanup |

**Harvest status (the handoff, per AGENTS.md → TODO System)**

- **Harvested now:** the three documentation/quality items that live in this repo's own domain (`#7` index the proposal/page, `#15` stray-continuation guard, `#16` last-verified convention) → `docs/todo/pipeline.md` + the `### pipeline` queue section in `TODO_LIST.md`. `#17` (research-artifact convention) rode the same batch.
- **Deliberately NOT harvested (recorded here on purpose):** items 4, 5, 10, 11 and the sibling-repo halves of 19 — their fix-domain is another repo (`nix-email`'s probe suite, `pbx-artmann`'s `pim-ownership-declare` row), and I do not hold a decision to write rows there (question Q2). Items 1–3, 20–23 are owner decisions and already live as the D1/D2 `[decision]` row in `docs/todo/services.md` (the rest await that answer before they are worth rows). Everything else in the table is proposal-scoped work that cannot be specified before D1.
- **Timer: 12 h.** If D1 has not been answered in that window, the sharpest single next action is **#4** (the CalDAV probe): it is independent of the topology decision and it can invalidate half the recommendation.

---

## g) Questions I cannot answer myself

**Q1 — Which two Google accounts, and may the second one be written to?** I can see the *shape* of the ask but not its blast radius: D3 ("personal bidirectional + work read-only" vs "both symmetric") changes the OAuth consent surface, the failure radius, and whether a work IT policy applies. I cannot determine which account is which, or whether writes to the second are acceptable, from any repo.

**Q2 — Which repo owns the single canonical ownership decision from now on, and may I edit the sibling repos to reconcile them?** The collision is cross-repo by construction (SystemNix page, crm constitution, nix-email roadmap, pbx doctrine). I deliberately did not write rows or edits in `~/projects/{crm,nix-email,pbx-artmann}` — that is a permission and an ownership question, not a research one. Without an answer, the reconciliation stays written-down-but-unresolved.

**Q3 — Is there an existing GCP project/OAuth client I should reuse, and are you willing to publish it out of testing mode?** The CRM's Google ladder needs a client secret and a consent ceremony; the fleet's own runbook records the testing-mode 7-day refresh-token trap, and InboxClean's lesson (publishing status) is referenced in-repo. I cannot know what already exists in your GCP estate, and a wrong choice here re-consents every account later.

---

## Verification log (what was actually run)

| Check | Command | Result |
| --- | --- | --- |
| Living-docs links | `bash scripts/check-doc-links.sh` | `OK: no broken relative links or anchors` |
| TODO system structure | `bash scripts/check-todo-system.sh` | `OK: TODO queue/library structure clean` (+ 149 pre-existing harvest WARNs, unrelated) |
| HTML artifact | `bash scripts/verify-html-diagrams.sh <proposal>` | `PASS (2 diagram(s), 2 SVG(s), 0 error-bombs, anchors OK)` |
| HTML structure/self-containment | ad-hoc `python3` parse | 0 tag errors · 14/14 nav anchors · 0 external refs · 3,663,043 bytes |
| CSS/JS provenance | `diff` head-849 + script block vs kit template | identical (no transcription) |
| Formatter | `nix fmt -- --fail-on-change <6 md files>` | `traversed 6 … formatted 6 (0 changed)`, rc=0 |
| Formatter exclusion for HTML | `flake/parts/formatter.nix:42-43` | `docs/**/*.html` excluded (static evidence; deliberately not exercised on the 3.5 MB file) |
| Nix eval / flake check | not run | no Nix files changed |
| Deploy / post-deploy | not run | nothing deployed |

## Side effects and non-effects

- **Touched:** 6 markdown docs in this repo (all committed by the auto-commit daemon) + 1 new HTML artifact + `~/.cache/mesh-proposal/` scratch (5 files).
- **Not touched:** no code, no Nix, no secrets, no Google account, no sibling repo, no service state, no deploy.
- **Parallel-session note:** HEAD moved to `3f8e6307b` (another session's queue rows) while this work was in flight; my files were daemon-swept into `d9ed387f0`, `42af70367`, `1b8634ee7`. Nothing of mine was clobbered; `git status` for my paths is clean.

**WAITING FOR INSTRUCTIONS.**
