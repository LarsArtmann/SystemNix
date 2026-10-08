# 2026-10-08 18-10 — ledger-vs-crm closeout + Kith rebrand execution

Session: resumed from the 15-30 CRM follow-through handoff. Two major work
packages executed: (1) the ledger-vs-crm repo question + three owner
decisions closeout, (2) the full product rebrand **Ledger → Kith** across the
crm repo and SystemNix. One pre-existing breakage discovered and isolated
(crm go-module graph). Owner explicitly requested `.md` (repo convention
overrides the skill's HTML default).

## a) FULLY DONE

1. **ledger-vs-crm resolved** — `~/projects/ledger` = checkout of
   `github.com/LarsArtmann/journal` (the accounting kernel); `~/projects/crm`
   = `github.com/LarsArtmann/crm` (the CRM whose product was branded
   "Ledger"). 0 shared commits (intersected full logs). Naming inversion
   documented: dir `ledger` ↔ repo *journal*; repo `crm` ↔ product *Ledger*.
   Multi-RPID draft home CONFIRMED = crm (it owns the identity/webauthn
   code). Annotated `docs/todo/upstream.md:135`.
2. **Three §g owner decisions collected (question tool, 16:40) and executed
   to agent-side limit:**
   - Residue = **volumes-only tar then trash** → recorded in
     `docs/todo/services.md:14` + `TODO_LIST.md:91` (owner sudo steps remain).
   - CV lock = **forward** → discovered ALREADY SATISFIED: live lock at
     `b2cab45` (revCount 7527, 52 commits past e76d638/7475) since the 10-08
     09:11 13-input wave (`5511390f`); the 14:20 cutover deploy switched
     green on it (gen 845). NO lock edit (would be backward). Rows closed:
     services.md 352, TODO_LIST 391, pipeline.md 378. Row 285 (CV checkpoint)
     left fully dispatchable. Bank-sync FOD also proven resolved by the same
     deploy (the 15-30 handoff's blocker item was stale).
   - Dedupe = **agent via CRM API, dry-run first** → services.md 286
     re-tagged `[blocked:deploy]` with explicit sequencing (after checkpoint
     fix deploy).
3. **AGENTS.md lesson landed** — question-time premise check (live-verify
   lock revs/PIDs/state before asking owner-gated questions; this session's
   CV question offered a 7.5h-stale hold-point).
4. **16-45 report written + harvested** (explicit HARVESTED marker; gate
   clean — 89 pre-existing warnings, none mine).
5. **Kith rebrand — crm repo** (~28 files):
   - UI: `layout.templ` navbar brand + page titles ("Kith: …"); regenerated
     via `scripts/regen-ui.sh`; `check-ui-artifacts.sh` byte-equity GREEN;
     compiled `app.min.css` carries the `--kith` tokens.
   - Tests: `main_test.go` + `identity_test.go` brand assertions → "Kith".
   - `flake.nix`: description + pname `ledger-crm` → `kith-crm`.
   - `git mv web/tailwind/ledger.css → kith.css` + token rename
     `--ledger`/`--ledger-deep` → `--kith`/`--kith-deep`; app.css import +
     comments.
   - Docs: README (`# Kith`), AGENTS, FEATURES, ROADMAP (incl. the
     templ-components preset candidate renamed "kith"), 4 ops runbooks
     (CV-SYNC, GOOGLE-SYNC, RESTORE-DRILL, WHERE-IS-MY-DATA).
   - Scripts: smoke-test, restore-drill (login-brand asserts → "Kith"),
     browser-qa/seed, extract-twenty (rehearse, extract), contrast-check
     (docstring, css filename, dict keys, pair labels).
   - deploy/ units: crm-server.service, crm-backup.{service,timer},
     install.sh descriptions.
   - **Contrast audit: 50/50 pairs pass WCAG AA with renamed keys.**
   - DELIBERATELY KEPT: `ledger.db` + `ledger-*.db` artifact names,
     `scripts/backup-ledger.sh` (names its subject DB), planning-doc
     filenames, CHANGELOG/docs-status history, generic-English "ledger"
     usages (bank-sync sqlite comment, InboxClean upload ledger,
     rotations.md "Rotation Ledger", third-party "LedgerBridge").
6. **Kith rebrand — SystemNix** (~15 files): `crm.nix` (descriptions, gatus
   check + alert names → "Kith CRM"), configuration.nix tile/IO comments,
   quickshell.nix, CrmWidget.qml, README + FEATURES rows, ports.nix, flake.nix
   input comment, deploy.sh, cv.nix sync comments, post-deploy-check.sh check
   label, `docs/services/crm.md` runbook, AGENTS/storage "pre-cutover"
   phrasing. **`nix flake check --no-build` GREEN** (expected darwin skip
   only). Package refs untouched (locked input rev still ships pname
   `ledger-crm` until push+relock).
7. **Isolation proof for the go failure** — throwaway worktree at `0268d64`
   (pinned pre-session crm HEAD) fails `go build` IDENTICALLY ("updates to
   go.mod needed") → the module-graph breakage predates the rebrand 100%.

## b) PARTIALLY DONE

1. **Rebrand verification** — go legs (build/test/race, golangci, nix FOD)
   BLOCKED by the pre-existing module-graph issue (see d); restore-drill +
   smoke-test now assert "Kith" but were NOT executed. Verified instead:
   byte-fresh artifacts, contrast 50/50, SystemNix eval, isolation proof.
2. **crm CHANGELOG entry for the rebrand** — NOT started (interrupted
   mid-flight at 18:0x).
3. **crm TODO_LIST row for the module-graph blocker** — checked absent, not
   yet added.
4. **Push-window bookkeeping** (fold rebrand into the queued crm push items)
   — not yet updated.

## c) NOT STARTED (owner-gated / dispatch / future-gated)

- crm push + SystemNix relock + deploy (rebrand goes LIVE; binary becomes
  `kith-crm-<rev>`). Owner push window.
- First DUAL backup verification (ledger + identity) — due 2026-10-09
  ~03:47, watch row owns it.
- Passkey registration (owner; identity.db unchanged since 10-03).
- `/data/docker` residue execution (owner sudo: du → volumes tar → trash).
- CV durable checkpoint fix (row 285 — now fully dispatchable).
- Storage-collector `/data/docker` subtree sizes (queued [ready]).
- Multi-RPID pre-filing bundle (queued [ready]).
- Dedupe delete (after checkpoint fix deploy; agent-API decided).
- Dashboard tile/gatus "Kith" visual + first rebranded deploy verify.

## d) TOTALLY FUCKED UP!

Nothing catastrophic, four honest items:

1. **My buildflow invocation churned go.mod on a broken graph.** BuildFlow's
   workspace-build-verify ran a "module update" (partial tidy) that FAILED,
   leaving modified go.mod/go.sum that the daemon committed at 17:05
   (`3b59c9f`: id/v4 v4.7.1→v4.7.2, metaengine/v4 v4.16.1→v4.17.0 bumps).
   Self-inflicted churn on a surface a parallel session had just touched.
   Should have run `buildflow --dry-run`/baseline `go build` on the foreign
   tree BEFORE the full gate.
2. **Stale-premise owner question** — the CV-lock question presented "hold at
   b3a9172" as status quo while the live lock sat 52 commits past the forward
   target. Caught pre-execution (premise live-verified before editing);
   lesson landed in AGENTS.md.
3. **`rg -rn` phantom-corruption scare** — `-r n` is "--replace n", which
   rewrote OUTPUT only; I briefly suspected file corruption. Lost ~2 min +
   adrenaline.
4. **sed-introduced typo** in app.css ("web/tailwin./kith.css") — caught and
   fixed in the same pass; a symptom of batching edits via `sed -i` instead
   of the edit tool.

## e) WHAT WE SHOULD IMPROVE

1. **Baseline-before-rename**: prove `go build` green on the target tree
   BEFORE a big rename, so verification attribution is trivial.
2. **`buildflow --dry-run` + doctor on foreign trees** before full runs (the
   skill's own step 1 — skipped under time pressure).
3. **Premise live-verify at question time** (landed in AGENTS.md this
   session).
4. **Prefer the edit tool over multi-file `sed -i` batches** — typo risk +
   edit-tracking bypass.
5. **Ripgrep `-r` trap** — never combine `-r` with a bare pattern.
6. **Repo dir naming**: `~/projects/ledger` (repo: journal) invites exactly
   the confusion that started this session — owner-side suggestion: rename
   the dir to match its remote.
7. **Cross-repo rebrands need a one-pager order**: brand strings → generated
   artifacts → gates → CHANGELOG → push-window row, in one pass (I was
   mid-list when interrupted; the missing tail is §b).

## f) NEXT (session-derived, priority-ordered)

1. crm CHANGELOG entry (Unreleased: rebrand Ledger→Kith, pname kith-crm).
2. crm TODO_LIST row: go-module graph blocker (stack/metaengine v4.0.0
   unknown revision) with the isolation-proof evidence.
3. SystemNix push-window row: fold rebrand commits + multi-RPID draft + nsfw
   `46f02bb` into the owner push list.
4. Decide go.mod churn disposition (see §g Q1).
5. Fix module graph (upstream tag vs pin-back stack/sqlite) — then rerun
   `nix develop -c buildflow` in crm for the full green gate.
6. Owner push window: crm master (ahead 6+) + rebrand.
7. SystemNix relock (`nix flake lock --update-input crm` — probe-before-lock
   per doctrine) + deploy; verify binary `kith-crm-<rev>`, navbar "Kith".
8. Post-deploy: tile/gatus "Kith CRM" visual check (post-deploy-check label
   renamed this session).
9. Verify first DUAL backup artifacts 10-09 ~03:47 (ledger + identity, 0600).
10. Owner: register the passkey (identity.db still zero-user).
11. Owner: `/data/docker` residue (du → volumes-only tar → trash).
12. CV durable checkpoint fix (row 285, dispatchable).
13. Dedupe dry-run + delete via CRM API (after 12 deploys).
14. Storage-collector `/data/docker` subtree sizes (queued).
15. Multi-RPID pre-filing bundle (Gate-5 search + citation re-pin, queued).
16. crm repo dir rename consideration (§e.6) — cosmetic, owner-only.
17. Re-run `scripts/smoke-test.sh` + `restore-drill.sh` once go build
    resolves (their "Kith" asserts are unexecuted).
18. templ CLI version skew note (generator v0.3.1020 vs go.mod v0.3.1070
    warning during regen) — worth a bump in the crm devshell.
19. Bank-sync FOD "blocker" backlog item: mark resolved-by-09:11-wave
    wherever it still lives (verified stale this session).
20. Roadmap candidate (crm): templ-components "kith" preset upstreaming.
21. Post-rebrand browser-QA run (`scripts/browser-qa/run.sh full`) once
    builds work — screenshots in README still show "Ledger" navbar.
22. README screenshots: re-shoot after deploy (brand + tile).
23. The 16-45 report's watch row items stay: post-login identity users>0,
    dashboard visual.
24. SystemNix FEATURES row 82/531 dated-historical "Ledger CRM" mentions:
    leave (era references) — revisit only if docs-health flags drift.
25. crm AGENTS.md "Commands" section: add the rebrand note (brand constants
    live in layout.templ only — single source).

## g) QUESTIONS FOR THE OWNER (cannot figure out myself)

1. **The 17:05 go.mod/go.sum churn (from my buildflow run)**: keep the
   partial-tidy bumps (id v4.7.2, metaengine v4.17.0 — direction the graph
   wants) or revert those two files to the pre-buildflow state?
2. **Module-graph fix ownership**: the crm repo's `go build` is blocked on a
   missing upstream tag (`go-cqrs-lite stack/metaengine v4.0.0`, referenced
   by stack/sqlite's tests; dep bump came from the parallel CSP session).
   Take it in a fresh session now, leave it for that session, or wait for an
   upstream tag?
3. **Rebrand push timing**: fold the rebrand into the already-queued crm push
   window (with the multi-RPID draft), or do you want it pushed/tagged
   separately and deployed sooner?

---
Self-harvest: §f items 1-3 landed this session (queue + libraries); the rest
map to existing rows (285/286/14, watch row, upstream bundle) — HARVESTED at
authoring.
