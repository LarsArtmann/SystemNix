# Caddy Session Continuation Status Report (2026-10-01 02:08 CEST)

**Scope:** the work AFTER `docs/status/2026-09-30_15-39_caddy-fix-batch-status.md`
was written (that report's §a-g stands; its §0 self-critique is not repeated
here). The continuation stretch: self-harvest of 11 rows, extension of the
serviceconfig-merge audit guard v1→v2, closure of the parallel session's
half-done "caddy.nix shallow-merge" row with a CORRECTED premise, and the
15-39 report appendix. Wall-clock note: this session spans 2026-09-30 11:33 →
10-01 02:08 with parallel sessions interleaving throughout (their commits
dated 09-30 15:52 → 10-01 01:03; a foreign staged set was live at authoring
time — flagged, untouched).

---

## §0 Self-critique — the continuation stretch

1. **I relied on the edit tool's mid-air-collision guard instead of re-reading
   first.** The CHANGELOG edit bounced ("file modified since read" — parallel
   churn) and only then did I re-read and re-anchor via python. The tool saved
   the edit; the discipline should not have needed saving. Re-read before
   EVERY edit on this tree, no exceptions.
2. **One wasted verification round on inline-awk escaping.** I inlined the
   scanner's awk into a bash command (quoting hell, syntax error) instead of
   immediately extracting `scan_file` from the script under test with sed —
   which worked first try on the retry. Rule: test the REAL artifact via its
   own functions, never a retyped copy.
3. **The scanner behavior change was discovered via fixture failure, not
   designed-in.** v2's per-occurrence `://` stripping makes "URL + genuine
   `//` merge on one line" FAIL where v1's whole-line exemption passed it. I
   only articulated this when the (wrong) v1 fixture tripped. Repo scan proved
   no current tree code trips it (199 files, fail=0), so the change is safe —
   but behavior changes should be enumerated before the first run, not
   reverse-engineered from a red selftest.
4. **The meta-lesson from that fixture: v1's selftest BLESSED a
   false-negative.** The old `env "https://…" // { }` "sanctioned URL" case
   was itself a real shallow merge — the test validated wrong behavior for its
   entire life. Good fixtures need adversarial review as much as evil ones.
5. **I closed ONE stale row but did not spot-verify its siblings.** The
   shallow-merge row came from the 14:32 closeout report alongside several
   other queued rows (storage/boot-mirror domain). Its premise turned out
   FALSE ("the current regex missed at landing time" — v1 caught the shape
   fine). The same-report siblings may carry unverified premises too; that is
   outside this session's mandate ("do not research unrelated stuff") so it is
   harvested as a row, not researched here.
6. **Missed the true root-cause framing on the first pass.** My first CHANGELOG
   draft said the fix commit "replaced shallow merge" without asking WHY it
   landed despite a repo-wide audit wired into pre-commit. Only when testing
   v1-against-historical did the real chain surface: v1 flagged it fine → the
   daemon commits past a FAILING hook (the row's own "every commit now fails
   pre-commit" symptom proves the hook WAS failing). Ask "how did this get
   here" before "how do I prevent recurrence" — the prevention target moved
   from the regex to the daemon.
7. **Kept honest (what went right):** the edit tool guard + python re-anchor
   landed the CHANGELOG cleanly under churn; ANNOTATE-mode appendix (not a
   rewrite) kept the 15-39 report honest; the stale row was verified against
   the REAL historical artifact before closing (the re-dispatch verification
   protocol, applied).

---

## §a FULLY DONE (continuation stretch, all verified)

| # | Item | Evidence |
| - | ---- | -------- |
| a1 | **11-row self-harvest** of the 15-39 report's direct follow-ups: TODO_LIST queue section + 7 `docs/todo/services.md` entries + 4 `docs/todo/pipeline.md` entries | `check-todo-system.sh` OK; both surfaces edited in one pass (no drift) |
| a2 | **Audit guard v1→v2**: bounded (≤6-line) continuation check — `serviceConfig =` with the `//` operator on a FOLLOWING line now fails (v1's documented blind spot) | selftest rc=0 |
| a3 | **Selftest grown to four fixtures**: single-line evil, continuation-line evil, multi-line mkMerge good, plain-continuation good | `--selftest` PASS line |
| a4 | **v1 fixture false-negative fixed**: `env "https://…" // { }` was a real shallow merge blessed as "sanctioned" by the whole-line URL exemption; `://` now stripped per-occurrence (URL + genuine `//` FAILS) | fixture diff; the new good.nix case tests stripping without merging |
| a5 | **Historical verification**: BOTH v1 and v2 flag the real pre-fix source (`f1e703c5~1`, the `(serviceOneshotDefaults { }) // {` line) — correcting the 14:32 row's "regex missed at landing" premise; the true landing mechanism is the daemon committing past a failing pre-commit | v1 scanner run against historical file → FAIL; v1 script content at `3ce86d9b` inspected |
| a6 | **Repo scan clean under v2**: 199 files, fail=0 — the legit own-line `//` attrset merges (caddy.nix virtualHosts) and all mkMerge forms do not false-positive | `audit-serviceconfig-merge.sh` full run |
| a7 | **Stale row closed**: removed from TODO_LIST (queue-only — no library entry existed, the 14:32 session's drift, noted); CHANGELOG entry under [Unreleased] → Changed with the corrected premise | surgical diff; `check-todo-system.sh` OK |
| a8 | **15-39 report annotated** (end-of-file appendix, ANNOTATE mode — never a rewrite) with the post-authoring work | appendix in the report file |
| a9 | **Gates**: `bash -n` + `scripts/shellcheck.sh` clean on the extended script; all session files daemon-swept (`4d06a0a7`, `aaece76d`, `dfdd83b6` — contents verified via `git show --stat`) | command outputs |

## §b PARTIALLY DONE

| # | Item | State |
| - | ---- | ----- |
| b1 | Caddy fix-batch deploy legs (from 15-39 §b: live QUIC probe, derived smoke on live system, mint SAN journal line, first restart under new caps) | unchanged — still `blocked:deploy`, queued as services.md row 1 of the 15-39 harvest; NOT re-harvested here |
| b2 | negative-test-lints 18/5 pre-existing failures (cv/hermes dead-guards; signoz/binary-coverage pristine controls) | queued in the 15-39 harvest; not started |
| b3 | The foreign parallel work visible in this stretch (`geometrikks-pocketid-allowlist-fix-session`, `caddy-logs-tlc-hot-tier-staged` reports; the 02:08 staged set touching TODO_LIST/home.nix/heal-breadcrumb) | theirs, mid-flight — flagged only |

## §c NOT STARTED

Everything in §f below that is not H1-H3; plus the still-open 15-39 §f backlog
(rows 12-25 there — review of foreign geometrikks edits, nsfw/index 502-window
check, alerts explicit redirect, per-vhost roll bounds, etc.).

## §d TOTALLY FUCKED UP

**Nothing in this stretch broke.** The two honest candidates for the label:

1. **The daemon-commits-past-failing-hooks class — now CONFIRMED TWICE**
   (caddy shallow-merge landed 14:30 past a red pre-commit; heal-breadcrumb
   landed 09-28 past skipped lint legs). The pre-commit layer is a control
   that the repo's own automation does not obey. Nothing THIS session fucked
   up — but a prevention layer that its own tooling bypasses is the closest
   thing to fucked in the pipeline, and it is owner infrastructure (§g Q1).
2. **The 14:32 closeout row shipped a false premise through the queue** — a
   queued ask asserted a tool-rejection claim ("the current regex missed")
   without running the tool (the exact violation of the existing
   "commit-message evidence rule" Critical Rule, one surface over). Cost me a
   v1-vs-historical verification round to untangle. The rule exists; nothing
   enforces it at queueing time (harvested, §f H2).

## §e WHAT WE SHOULD IMPROVE

1. **Re-read before edit as reflex** — the tool's stale-read guard is a
   seatbelt, not the discipline (hit once this stretch on CHANGELOG).
2. **Test real artifacts via their own functions** — extract, don't retype
   (one awk-quoting round wasted).
3. **Enumerate scanner behavior changes before running** — strictness deltas
   (URL+merge now fails) should be a designed, documented list, not a
   fixture-failure discovery.
4. **Adversarially review GOOD fixtures** — a selftest can bless a
   false-negative for its whole life (v1 did).
5. **"How did this land?" before "how do I prevent it?"** — the prevention
   target (regex) was wrong; the real gap was the daemon/hook contract.
6. **Queue-time evidence enforcement** — the "tool X rejects Y" Critical Rule
   needs a queueing-time spot-check habit (or lint), or false premises keep
   riding the queue into future sessions.

## §f Things to get done next (continuation-specific; the 15-39 §f table remains the caddy backlog)

| # | Item | Impact | Effort | Cat |
| - | ---- | ------ | ------ | --- |
| 1 | **H [ready] Daemon-past-failing-hooks guard** — 2nd confirmed instance (caddy 14:30, heal-breadcrumb 09-28); the daemon should refuse to commit when pre-commit fails, or at minimum record hook-failure state in the commit (owner-infra decision rides §g Q1) | HIGH | 1h | pipeline |
| 2 | **H [ready] Spot-verify the remaining 14:32-closeout queued rows' premises** — the shallow-merge row's premise was FALSE (proven); its same-report siblings (storage/boot-mirror domain) get the same "run the tool against the artifact" check before anyone dispatches them | MED | 45m | pipeline |
| 3 | **H [ready] E2E the extended audit through the REAL hook** — plant a continuation-shape defect on a throwaway worktree, run `.githooks/pre-commit`, prove the block (the hook's exact two commands ran green manually; the hook itself unexecuted) | LOW-MED | 20m | pipeline |
| 4 | [watch] awk scanner's 6-line continuation cap — longer continuations escape silently; documented in the script header, revisit only if a real shape ever hits it | LOW | — | pipeline |
| 5 | Caddy deploy + post-deploy verification legs (15-39 §b/§f row 1 — queued, unchanged) | HIGH | 30m | services |
| 6 | The 15-39 §f rows 2-11 (fallback smoke test, geometrikks runtime logs, log storage/rolls, lint 18/5, caddy-mutant case, AGENTS SSO table, voice/whisper, layer classification, h3 pin) — queued, unchanged | MED | — | services/pipeline |
| 7 | The 15-39 §f rows 12-25 (foreign geometrikks review, nsfw/index 502 window, alerts redirect, and the ROADMAP-fuel rows) — dispositioned, unchanged | LOW | — | services/ROADMAP |
| 8 | Two foreign sessions are visibly working rows harvested from MY 15-39 report (`caddy-logs-tlc-hot-tier-staged`, `geometrikks-pocketid-allowlist-fix`) — watch for double-close-out drift on those queue rows (two sessions closing the same row = premise-check both) | MED | — | process |

(8 rows: 3 harvested H, 5 referenced/dispositioned — the heavy backlog lives
in the 15-39 report and is already queued; padding this table past the new
signal would duplicate the queue, which is its own anti-pattern.)

## §g Three questions I can NOT figure out myself

1. **Should the auto-commit daemon REFUSE to commit when pre-commit fails?**
   Two confirmed landings past red hooks (caddy 14:30; heal-breadcrumb 09-28).
   The daemon is your infrastructure — I can't know whether commit-past-red is
   a deliberate availability tradeoff (never block the sweep) or a gap to fix
   (refuse + retry loop, or commit with a machine-readable hook-failure
   marker). This decides H1's shape.
2. **Ratify the three autonomous calls from the caddy fix batch** (still
   unanswered from the 15-39 §g): UDP/443 opened for HTTP/3 vs pinning
   `h1 h2`; `request_body max_size 10GB` kept global vs scoped per-vHost;
   caddy file logs staying on QLC root vs moving to `/mnt/hot` (1.7G,
   snapshot-pinned). Silence-so-far — take it as ratification, or redirect?
3. **Row ownership across parallel sessions**: two other sessions are working
   rows my report harvested (caddy-logs hot-tier; geometrikks runtime-logs).
   Is "first session to dispatch owns the row" the convention (I stay off),
   or do you want explicit claiming (a row picks up an owner tag) to prevent
   double-close-outs with divergent premises?

---

## Harvest Log (self-harvest at authoring time)

**Harvested (3 rows → TODO_LIST.md + `docs/todo/pipeline.md`):** §f rows 1-3
(daemon-past-hooks guard; 14:32 sibling-premise spot-verify; audit E2E through
the real hook). Queue one-liners + library entries land together in this pass.

**Deliberately NOT harvested:**
- §f row 4 (scanner cap): documented in the script's own header comment — the
  code is the annotation; a queue row would restate it.
- §f rows 5-7: already queued/ dispositioned by the 15-39 harvest — re-adding
  would duplicate the queue.
- §f row 8: process observation; no actionable artifact until a
  double-close-out actually collides.

## Provenance

- Report moment: `date` → 2026-10-01 02:08 CEST.
- Session commits carrying continuation work (daemon-swept, verified via
  `git show --stat`): `4d06a0a7` (report + CHANGELOG + todo prunes),
  `aaece76d` 15:52 (audit script v2), `dfdd83b6` 01:03 (fixture fix + CHANGELOG
  + AGENTS line).
- Verification: selftest rc=0 (4 fixtures); v1 (content at `3ce86d9b`) run
  against `/tmp` copy of `f1e703c5~1` caddy.nix → FAIL (line 435); v2 same →
  FAIL (line 580 in the later revision); repo scan 199 files fail=0;
  `shellcheck.sh` clean; `check-todo-system.sh` OK.
- Foreign state at authoring: staged set touching TODO_LIST.md,
  platforms/nixos/users/home.nix, scripts/heal-breadcrumb.sh,
  scripts/lib/buildcache-reap-names.sh, docs/CONTRIBUTING.md, docs/services/jan.md,
  docs/todo/storage.md + two foreign untracked status reports (01:03, 01:04) —
  flagged, untouched.
