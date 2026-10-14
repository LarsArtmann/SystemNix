# Status: Stray `db/modification_history.db` — Identification, Origin Forensics, Verdict (Record-Only Session)

**Session:** 2026-10-14, ~21:25–22:08 CEST · **Owner questions:** "What is db/modification_history.db?" → "Then why do we have it in ~/projects/SystemNix?" → full status order · **Scope discipline:** this report covers ONLY this session's run and what it directly observed. **This session made ZERO mutations to the repo tree** — every command was read-only (stat, sqlite reads, rg, git log/show, crush.db SELECTs). The report itself is the first write.

---

## a) FULLY DONE

1. **The artifact identified and fully characterized.** `db/modification_history.db` at the repo root: 36,864 B, created 2026-10-02 17:11:05.535 +0200, untracked, gitignored via `.gitignore:173` (`*.db` — `git check-ignore -v` proof). SQLite containing exactly three application tables — `modification_histories`, `ocr_runs`, `ocr_page_results` (plus `sqlite_sequence`) — **all zero rows**: schema only, no data ever written. Never committed under any rev (`git ls-files db/` empty; `git log --all -- db/` empty). Evidence: `stat`, python3-sqlite schema dump (the `file` and `sqlite3` CLIs are absent/guarded in the agent shell — python3 used instead).
2. **Upstream attribution verified at source level: icereed/paperless-gpt.** Its `local_db.go` → `InitializeDB()` creates `dbDir := "db"`, `dbPath := filepath.Join(dbDir, "modification_history.db")` via GORM `AutoMigrate` on every startup. All three table shapes match its models exactly (`ModificationHistory` incl. `mod_field`/`previous_value`/`new_value`/`undone`; `OCRRun` incl. `process_mode`/`upload_pdf`/`replace_original`/`copy_metadata`/`prompt_override`/`provider`/`pdf_action`; `OCRPageResult` incl. `ocr_limit_hit`/`generation_info`). Source quotes pulled via agentic_fetch. The alternative candidate **clusterzx/paperless-ai was ruled out with evidence** (its DB is `data/documents.db` via better-sqlite3 with entirely different tables: `processed_documents`, `openai_metrics`, `history_documents`, `original_documents`, `users`, `processing_status`).
3. **The exact origin session and minute recovered from `.crush/crush.db`.** The 2026-10-02 paperless-gpt **packaging session in this repo**:
   - 16:54:14 — commit `8eb3e272` (heuristic): `pkgs/paperless-gpt.nix` (v0.28.0, 94 lines) + flake input + hermes files.
   - 17:09:51 — agent edit to `pkgs/paperless-gpt.nix` (the pdfcpu `/homeless-shelter` test-phase fix).
   - 17:09:55 — `nix build .#paperless-gpt` kicked off.
   - 17:10:53 — reasoning: "A7 BUILD GREEN! `/nix/store/fqfj65n5…-paperless-gpt-0.28.0`. Now B28 — binary smoke."
   - 17:10:58 — smoke-run output captured (startup tag banner "Using paperless-gpt as manual tag…"); first invocation died on missing `PAPERLESS_BASE_URL`, second passed dummy env vars.
   - **17:11:05 — `db/modification_history.db` created**: GORM `AutoMigrate` fires at startup and writes `./db/` relative to CWD = repo root.
   - 17:22:41–17:23:04 — `modules/nixos/services/paperless-gpt.nix` written/edited.
   - 17:27:37 — commit `ba14fb07` (heuristic): VM test `tests/test-paperless-gpt.nix` + post-deploy-check legs + module tweak.
4. **The "why only `db/` and not `prompts/ config/`" question answered:** the smoke run died during startup, right after DB init — `prompts/` and `config/` never materialized at the repo root (verified by ls). In production the module pre-creates all three dirs via `ExecStartPre` `mkdir -p prompts config db` (`paperless-gpt.nix:369`) and sets `WorkingDirectory = /var/lib/paperless-gpt` (`:383`), which is what confines the same behavior in prod.
5. **Verdict delivered:** dead, schema-only artifact with zero repo references — safe to `trash db/`. The production counterpart is `/var/lib/paperless-gpt/db/modification_history.db` (config-derived; see d2 for the honesty caveat).
6. **The module's own source confirms the mechanism:** `paperless-gpt.nix:28` and `:366` document that the app "writes to its CWD on first run … prompts/, config/, db/" — the failure mode was known at packaging time and correctly neutralized for the service, just not for the ad-hoc smoke run.

## b) PARTIALLY DONE

1. **The prod counterpart was never live-probed.** "The real production DB lives at `/var/lib/paperless-gpt/db/modification_history.db`" is **config-derived** (WorkingDirectory + ExecStartPre), not verified against the running system (`pgrep`/`ss`/readonly sqlite). Per the live-verify discipline a "verified" label must cover every fact asserted — this one is tagged, not probed. Blocked only by the report-only order.
2. **Same-class repo-root artifacts noticed but not examined:** during the `ls` that found `db/`, two more gitignored/untracked items surfaced at the repo root — **`tasks.db`** (73,728 B, mtime 2026-10-10 04:02, owner/tool UNKNOWN — never opened) and six `result-N` store symlinks (Oct 12–14, normal build artifacts). `tasks.db` is the same gitignore-blind-spot class as `db/`; identification not started.
3. **Forensics completeness gaps:** I verified no other smoke-run side effects remain at the repo root, but did NOT (a) sweep the day's heuristic commits for other stray files, (b) check whether the Oct 2 session itself ever noticed the `db/` leak (one targeted crush.db query would settle whether it was an unnoticed side effect or a deliberate leave), (c) run `nix flake check` at a quiescent moment to confirm the Oct 2 surfaces still eval green.

## c) NOT STARTED

1. **The cleanup itself** — `trash db/` (whole dir). Zero tree mutations this session by scope.
2. **Queue harvest** — no `TODO_LIST.md` / `docs/todo/services.md` rows written for the cleanup, the tasks.db investigation, or the process lessons (see the harvest note under §f).
3. **Documentation** — no gotchas-archive incident entry, no paperless-gpt runbook CWD-mutation warning, no AGENTS.md session-discipline bullet, no CHANGELOG line.
4. **Prod verification** — paperless-gpt enabled? unit active? port serving? prod DB rows? Nothing probed.
5. **`tasks.db` investigation** — not started (noticed only).
6. **Repo-wide gitignored-drift listing** (`git clean -nXd`) — not run.

## d) TOTALLY FUCKED UP

1. **(Mine) crush.db epoch mishandling cost ~4 wasted query rounds.** The `messages` schema comment says "Unix timestamp in milliseconds" but the values are **SECONDS**. My first two batches queried with `/1000` division and a hand-computed Oct-2 window that was also boundary-off — every one returned empty, each guarded at up to 115 s on the 6.3 GB DB — before I sampled raw values (`1792006726` = today) and decoded the true unit. The misleading comment is crush-internal (not repo-fixable); the decoding method is the reusable lesson.
2. **(Mine) I asserted the prod DB location from config while presenting the overall answer as "verified"** — precisely the "a verification close-out must answer the question ASKED / assert WHICH question your evidence answers" class. Caught during this report's self-review; corrected here by downgrading the claim to config-derived and queueing the live probe (§f2). No harm done — nobody acted on the claim — but the label was wrong for one turn.
3. **(Mine, minor) Tool-selection waste:** three `sourcegraph` queries returned zero results for code-schema text searches before I switched to agentic_fetch, which found the answer in one call. Cost ≈ 2 minutes; pattern to remember: sourcegraph is poor for "which repo creates this SQL schema" lookups.
4. **(Pre-existing, discovered — the actual 12-day persistence cause) The gitignore blind spot.** The Oct 2 packaging session smoke-ran a CWD-mutating binary from the repo root and never noticed the side effect; the artifact then sat invisible for 12 days because `.gitignore:173`'s blanket `*.db` removes the entire class from `git status`. Root cause of the persistence is the visibility hole, not the smoke run. Severity: low (36 KB, zero data), but the *class* is what let it live — and `tasks.db` proves the class is populated.
5. **(Pre-existing, adjacent) `tasks.db` at repo root — same class, owner unknown**, present since Oct 10 04:02, silently ignored by the same blanket rule. Unexamined; if it holds tool state someone cares about, blanket-ignoring it is how it gets accidentally `trash`ed later.

## e) WHAT WE SHOULD IMPROVE

1. **Smoke-run discipline:** any binary whose startup mutates its CWD (databases, config dirs, prompt files, caches) must be smoke-run from a scratch dir (`mktemp -d`) or an explicit WorkingDirectory — never from the repo root. One sentence in AGENTS.md session discipline would have prevented this entire investigation.
2. **Gitignore blind spots need a counter-instrument.** Blanket ignores (`*.db`) are correct policy but make drift invisible; pair them with a periodic `git clean -nXd` review (or a non-blocking CI annotation) so "tree is clean" never silently means "tree is clean *for tracked and non-ignored files only*".
3. **crush.db forensics recipe should be documented** — `created_at` is SECONDS (sample raw values; do not trust the ms schema comment), windowed LIKE scans on the 6.3 GB DB need explicit timeout guards, and `sqlite3`/`file`/`curl`-class binaries are unavailable in the agent shell (python3 works). This also corrects the 21-47 report's side-claim that message timestamps are "broken" — they are not broken; the unit is seconds.
4. **Label config-derived vs live-probed explicitly** in any verdict (this report's d2 is the local example of the fix).
5. **The identify-unknown-artifact flow worked and is repeatable** — file → `stat` → schema dump → `git check-ignore` → upstream source verification → crush.db timeline. Worth codifying as a repo script or a cross-project lesson entry (by commit) so the next unknown artifact costs minutes, not a session.

## f) Up to 50 things we should get done next

Ranked by impact. Effort: S <30 min, M 30 min–2 h, L >2 h.

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | `trash db/` (verify nothing holds it open, re-run the zero-references check, confirm `git status` stays clean) | Critical | S | Cleanup |
| 2 | Live-probe prod: `pgrep -af paperless-gpt`, port via `ss -ltnp`, `sudo sqlite3 -readonly /var/lib/paperless-gpt/db/modification_history.db` tables + row counts | High | S | Quality |
| 3 | Determine paperless-gpt's actual deployment state on evo-x2 (enabled in config? unit active? — closes b1/b2 config-vs-live gap) | High | S | Quality |
| 4 | If deployed: verify `ba14fb07`'s post-deploy-check +25 lines actually cover paperless-gpt and a deploy followed Oct 2 17:27; if not deployed: record the parked state + integration order | High | S | Quality |
| 5 | Investigate `tasks.db` at repo root (owner tool, contents, keep/trash/relocate decision) | High | S | Cleanup |
| 6 | Run `git clean -nXd` full listing and adjudicate every gitignored-but-present artifact | High | S | Cleanup |
| 7 | Queue rows (cleanup + tasks.db + lessons) into `TODO_LIST.md` + `docs/todo/services.md` — both surfaces, per the two-surface rule | High | S | Documentation |
| 8 | Write the gotchas-archive incident entry (mechanism, `8eb3e272`/`ba14fb07`, 17:11:05, 12-day invisibility cause) | Medium | S | Documentation |
| 9 | Ensure `docs/services/paperless-gpt.md` runbook exists (enabled-service rule) and carries the CWD-mutation warning + prod DB path (once live-verified in #2) | Medium | S | Documentation |
| 10 | AGENTS.md session-discipline bullet: smoke-run CWD-mutating binaries from scratch dirs, never the repo root | Medium | S | Documentation |
| 11 | Document the crush.db forensics recipe (seconds-epoch, timeout guards, available substitutes) in `docs/agents/shell-devtools.md` | Medium | S | Documentation |
| 12 | ANNOTATE (non-destructive appendix) the 21-47 report's "broken timestamps" side-claim with the seconds-not-ms decode | Medium | S | Documentation |
| 13 | One crush.db query to check whether the Oct 2 session ever noticed the `db/` leak (closes the narrative: unnoticed vs deliberate-leave) | Medium | S | Quality |
| 14 | Sweep the Oct 2 heuristic commits (`git show --stat` across the day) for other stray files | Medium | S | Quality |
| 15 | Confirm `tests/test-paperless-gpt.nix` is wired into CI (nix-check or nightly) and green | Medium | S | Quality |
| 16 | `nix flake check --no-build` at a quiescent moment to confirm the Oct 2 surfaces still eval green (shared-tree rule) | Medium | S | Quality |
| 17 | Add drift visibility: non-blocking CI annotation running `git clean -nXd` (level per g3) | Medium | M | Quality |
| 18 | Narrow `.gitignore`: comment the `*.db` blanket, whitelist legitimate DBs (e.g. `tasks.db` if it earns its place) so the class stops being invisible | Medium | S | Quality |
| 19 | `scripts/crush-db-forensics.sh` — parameterized actor-attribution helper (pattern, time window, role) for repeatable session archaeology | Medium | M | Quality |
| 20 | Decide prod-DB policy from #2's row counts: zero rows + unused feature → record in the PAPERLESS-AI-MAX plan; rows present → OCR feature is live, document model/provider in the runbook | Medium | S | Quality |
| 21 | Probe whether the 17:11:53 env-var'd smoke run wrote anything besides `db/` (dotfile/config pollution check) | Medium | S | Quality |
| 22 | If paperless-gpt is deployed and lacks gatus coverage, confirm the eval-time gatus-coverage audit fired (or add the check) | Medium | S | Quality |
| 23 | Upstream ask (icereed/paperless-gpt): env var/flag for the DB path so CWD mutation is avoidable — after verify-before-filing | Low | M | Upstream |
| 24 | Sibling-checkout stray sweep: `go-paperless/` + `paperless-ngx/` for the same artifact class | Low | S | Cleanup |
| 25 | Cross-project lessons (crush-config repo, by commit): identify-unknown-artifact recipe + smoke-run CWD rule + sourcegraph-zero-for-schema-searches limitation | Low | S | Documentation |
| 26 | Verify `.crush/.gitignore` actually covers the 6.3 GB `crush.db` (it has its own 83-byte ignore file — confirm, don't assume) | Low | S | Quality |
| 27 | CHANGELOG entry once the trash lands | Low | S | Documentation |
| 28 | If `tasks.db` turns out to be live tool state: relocate it to a state dir or add an ownership comment next to the `.gitignore` rule | Low | S | Cleanup |
| 29 | Post-trash daemon-race check: confirm the auto-commit daemon doesn't sweep unrelated staged files; PATHSPEC commit if needed | Low | S | Quality |
| 30 | Record "schema-comment timestamps lie — sample raw values before trusting units" as a general forensics gotcha (merge target: #11) | Low | S | Documentation |

**Harvest note (per AGENTS.md self-harvest rule):** §f items are **deliberately NOT harvested** into `TODO_LIST.md` / domain libraries this session — the owner's order was "write the report, THEN WAIT FOR INSTRUCTIONS", so the queue edit (item #7) is itself an item awaiting go. On owner go, docs-health HARVEST routes: #1–#6, #13–#14, #18, #21 → `docs/todo/services.md` (+ queue one-liners); #8–#12, #27 → documentation dispatch; #15–#17, #19, #22, #26, #29 → quality/cleanup; #23–#25 → ROADMAP/upstream.

## g) Questions I can NOT figure out myself

1. **Execute now or wait for a dispatch?** Shall I proceed immediately with `trash db/` (+ the #7 queue rows), or leave the tree untouched until a dedicated task? (Deletion, even of a provably dead 36 KB artifact, is yours to trigger — and I will not act on §f without your go.)
2. **What is paperless-gpt's intended deployment status on evo-x2?** The Oct 2 session built, VM-tested, and wired the module — but "deploy now" vs "parked until the PAPERLESS-AI-MAX llama-rag soak completes" is an owner-sequencing decision I cannot reconstruct from artifacts. This decides whether §f #2–#4/#20 are verification-only or real integration work.
3. **What enforcement level do you want for gitignored drift?** CI annotation (non-blocking `git clean -nXd`), a pre-deploy gate, or manual periodic sweeps only — each has a different false-positive cost, and the right level is your risk call, not mine.

---

*Evidence artifacts for this report: this session's tool transcript; `git show --stat 8eb3e272` / `ba14fb07`; `.crush/crush.db` message rows 1790953791–1790954584 (2026-10-02 17:09:51–17:23:04 CEST); python3 sqlite dumps of `db/modification_history.db`; agentic_fetch source quotes from icereed/paperless-gpt `local_db.go`, `ocr_runs.go`, and clusterzx/paperless-ai `models/document.js` (fetched 2026-10-14).*
