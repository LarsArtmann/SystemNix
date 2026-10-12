# Status: eventcatalog-hub Integration Deep-Dive Session

| | |
| --- | --- |
| **Date** | 2026-10-12, 16:00–16:10 CEST (session ran ~14:05–16:10) |
| **Scope** | Read-only Q&A session on `~/projects/eventcatalog-hub` ↔ SystemNix integration + the dynamic-discovery design question; report authored per owner demand |
| **Repo pin (authoring time)** | `424a0a1ecbff0320baa74de11830df2b04a29e32`, branch `master` |
| **Parallel-session note** | `docs/todo/ai-stack.md` + `docs/todo/stability.md` were dirty at authoring time — NOT this session's edits (shared-tree discipline: flagged, not touched). `docs/services/architecture-catalog.md` had a daemon-commit race mid-edit (`c68e59df`); target sections re-verified unchanged before the edit landed |
| **Predecessors** | `docs/status/2026-10-12_11-43_signoz-collector-catalog-golive-session-status.md` (go-live close-out), `docs/services/architecture-catalog.md` (runbook) |
| **Deliverables this session** | 3 answered owner questions + 1 on-sight doc fix + this report + 2 self-harvested queue rows. **No code, no deploys, no SystemNix module changes.** |

---

## Session narrative

Three owner questions, answered in sequence:

1. **"How is `~/projects/eventcatalog-hub` integrated?"** → Full integration chain mapped: local clone → GitHub upstream → Forgejo read-only pull-mirror (`lars/eventcatalog-hub`) → hub CI on the bare-host runner (`gitea-runner-evo-x2`, PATH-extended with nix/jq/python3 per `forgejo.nix`) → `dist` published to dedicated `lars/eventcatalog-hub-dist` → `architecture-catalog-sync` (hourly oneshot, sops token) atomic-swaps `/var/lib/architecture-catalog/current` → Caddy static vHost `catalog.home.lan`. Zero runtime daemons by design.
2. **"Where does it get its sources from?"** → `sources.json` in the hub repo: **4 sources / 3 repos** (bank-sync; cqrs-htmx; go-cqrs-lite ×2 as `mesh-orders` + `mesh-billing`), each with per-repo build + export commands; CI clones the **Forgejo mirrors** via the read-scoped `GIT_CLONE_TOKEN`; `merge.py` union-merges the exported trees.
3. **"Why not project-discovery-daemon / project-dependency-graph — more dynamic????"** → Answered from both repos' READMEs + the owner-pasted `who-uses` output (10 direct + 17 indirect consumers of `go-cqrs-lite/catalog`): discovery solves the *candidate-set* half; `sources.json` encodes the *build/export contract + curation + CI trust boundary + determinism* half. Proposed the seam: a **CI drift-gate** (`who-uses … --format json` vs `sources.json` + exclusion list, fail-red) and the long-term **per-repo `catalog.json` convention** ("sources.json distributed into each repo", pairs with the routed `catalog.index.json` work).

---

## a) FULLY DONE

| # | Item | Evidence surface |
| --- | --- | --- |
| a.1 | Q1 answered: full hub integration chain (mirror → CI → dist repo → sync → vHost), with module/runner/PATH/token touchpoints named | This report §narrative; runbook `docs/services/architecture-catalog.md` |
| a.2 | Q2 answered: source inventory corrected and complete — **4 sources / 3 repos**, exporter commands per source | `~/projects/eventcatalog-hub/sources.json` (read in full, 82 lines) |
| a.3 | Q3 answered: static-allowlist rationale (curation, per-repo build contracts, CI trust boundary, workstation coupling, determinism) + the two concrete dynamic seams (drift-gate, `catalog.json` convention) | Both READMEs read; owner-pasted `who-uses` output |
| a.4 | **On-sight fix: runbook source-list staleness** — `docs/services/architecture-catalog.md` claimed `sources.json` = "bank-sync + cqrs-htmx demo today" in TWO places (data-flow ¶ line 24-26, Agent Notes line 169) while the live file carries 4 sources. Both claims corrected to the 4-source state (2-line-class fix, owner grant 2026-09-06 — fixed, not queued) | Working-tree diff on `docs/services/architecture-catalog.md` (uncommitted; daemon sweeps it) |
| a.5 | Status report authored per standing format, at owner-demanded `.md` path | This file |

## b) PARTIALLY DONE

| # | Item | Gap |
| --- | --- | --- |
| b.1 | **Drift-gate proposal** — designed (command shape, fail-red semantics, exclusion-list concept) but not implemented, not queued as decided work | Awaiting owner go/no-go (§g.2); queueing was punted with a closing question instead of acted on (see §e.1) |
| b.2 | **Dynamic-onboarding long-term path** (`catalog.json` per-repo convention) — named and motivated, no design doc, no implementation | ROADMAP-shape; depends on go-cqrs-lite `catalog.index.json` landing first (already routed there) |
| b.3 | **Self-harvest** — 2 of this session's direct follow-ups queued (§f.1, §f.3 → `TODO_LIST.md` + `docs/todo/services.md`); the drift-gate deliberately NOT harvested (reason recorded in Harvest Ledger below) | 1 item (drift-gate) parked on owner decision by design |
| b.4 | **Go-live residuals** (NOT this session's work, state re-confirmed from surfaces): VM test, SigNoz tile, orphaned PATs — all pre-existing open rows, none advanced this session | See §c |

## c) NOT STARTED

*(all pre-existing open work in this domain, re-surfaced this session; none started here — owner instruction was report-only)*

| # | Item | Tracked at |
| --- | --- | --- |
| c.1 | `architecture-catalog` VM test (`tests/test-architecture-catalog.nix`) — house norm is one per service; module has none | `docs/todo/services.md` `[ready]` row (line ~184) |
| c.2 | SigNoz dashboard tile for `architecture_catalog_stamp_age_seconds` — condition MET 2026-10-12 (gauge carrying real values), ready to build | `docs/todo/services.md` `[watch]` row (line ~185) |
| c.3 | Delete 4 orphaned all-scope setup PATs (silent-cleanup leak class; v15 `IsPasswordAuthentication` blocks token-authed DELETE) | `docs/todo/services.md` `[blocked:user]` row (~line 35) |
| c.4 | Hub-side: `eventcatalog-hub-dist` keep-N / CI-docs parity treatment | 11-43 report §14 + hub TODO_LIST |
| c.5 | Exporter upgrades to clear the 2 `warn` linter rules (`refs/resource-exists` unversioned dirs; `best-practices/owner-required`) | Runbook §Linter posture; hub TODO_LIST re-arm triggers |

## d) TOTALLY FUCKED UP

**Nothing this session broke, and no session work is fucked** — the session was read-only plus a 2-line doc fix.

Fucked-adjacent things **noticed** (all pre-existing, honestly attributed):

| # | Item | Severity | Why it survives |
| --- | --- | --- | --- |
| d.1 | **4 orphaned all-scope Forgejo PATs live** — every pre-fix `setup-forgejo.sh` run leaked an `eventcatalog-hub-setup-<ts>` PAT scoped `all`; revocation 401s are structural (v15 token routes demand basic auth), so the script's cleanup path can never delete them | High (security debt) | Blocked on owner deletion (UI/password-auth path) — `docs/todo/services.md` row |
| d.2 | **CI-state split-brain across surfaces**: `docs/todo/services.md` `[blocked:user]` row (~line 34) still claims hub jobs "die deterministically at bank-sync build phase, exact error pending owner log paste" while the runbook records run 38 **fully green (173 pages)** + run 51 published `dist`. One of the two surfaces is stale and I cannot tell which from this session (no Forgejo CI access) — did NOT assert resolution, did NOT edit the row | Medium (misleading queue) | Needs either an owner log paste or a live CI check (§g.1) |
| d.3 | **Runbook/source-list drift shipped at all** — the go-live sessions updated the runbook's checklist but not its source inventory; caught only because this session read both files hours later | Low (fixed today, a.4) | Root cause: no cross-surface consistency check when `sources.json` grew from 2 → 4 sources |

## e) WHAT WE SHOULD IMPROVE

**This session's own faults (the headline questions):**

1. **Punted a queueable decision.** I ended the drift-gate answer with "Want me to queue it as a TODO?" — the repo norm is agents queue `[ready]` items autonomously and gate only genuine owner decisions. The gate *design* was mine to queue; only its fail-red-vs-warn shape needed the owner. Cost: the decision now blocks on another round-trip. (Its harvest ledger entry records this.)
2. **Claim hygiene gap:** I presented `sources.json`'s `lint.export` override (the `work/lint/mesh-*` `-plain` trees) as part of the pipeline without ever reading `build.yml` to confirm CI consumes it. Shape-verified ≠ behavior-verified — the repo's own "assert WHICH question your evidence answers" rule. Now queued as §f.1 so the claim gets proven or corrected.
3. **Missed the runbook drift while answering.** I read the full runbook at 14:08 and answered the sources question from `sources.json` — correct — but never cross-checked the runbook's own stale inventory. The catch came from report-writing discipline, not from answering discipline. Cross-surface consistency should be part of answering, not deferred to documentation time.
4. **Content-pin lag under the daemon race:** the runbook edit failed twice (`file modified since read`, mod-time 15:22 vs my 14:08 read) before I re-verified and re-applied. I rev-pinned at *report* time but not at *edit* time — the repo's multi-agent discipline says pin before every write, and the daemon had committed `c68e59df` in between.
5. **Format pre-decision:** the status-report skill is HTML-canonical; I honored the owner's explicit `.md` demand (correct per the skill's own override rule) but note it here so the divergence is visible rather than silent — **this report is `.md` by owner instruction, not by skill default.**

**Process/system improvements surfaced by the session:**

6. **No drift-gate exists between `sources.json` and reality** — the 2 → 4 source growth happened with zero tooling noticing (d.3 is the proof). The drift-gate (§b.1) is exactly this, generalized.
7. **CI toolchain float:** hub `build.yml` shells Go via `nix shell nixpkgs#go_1_27` — a floating channel ref. Deterministic-in-name only; a channel bump changes the CI Go minor silently (§f.8).
8. **Exporter-lib version skew is unrecorded:** the pasted `who-uses` shows consumers pinned from v4.3.0 to v4.7.1 of `go-cqrs-lite/catalog`; each source's catalog output therefore comes from a different exporter generation, and nothing in `dist/` records which — provenance gap (§f.9).
9. **Mirror lag is an unexamined freshness variable:** CI builds from Forgejo *mirrors*, on a nightly 03:23 cadence; nobody has verified the GitHub→Forgejo pull interval can't make CI build day-old sources (§f.3).

## f) Up to 50 things to get done next

**Brainstorm ledger (per skill: >25 = brainstorm, ROADMAP fuel until routed):** items f.1/f.3 are self-harvested now (see Harvest Ledger); f.2 awaits §g.2; the rest are candidates — pre-existing tracked work keeps its rows (§c), the rest route on pickup. Grouped by owner of the fix.

**Direct follow-ups of this session (hub repo):**

| # | Task | Route |
| --- | --- | --- |
| f.1 | Verify hub CI actually consumes `sources.json`'s `lint.export` override (the mesh `-plain` lint trees) — read `build.yml`; if unused, the `lint` keys are dead config | **QUEUED this session** → `TODO_LIST.md` + `docs/todo/services.md` |
| f.2 | Land the CI drift-gate: `who-uses go-cqrs-lite/catalog --format json` vs `sources.json` + exclusion list; fail red on unlisted consumers | Awaiting §g.2 go/no-go (not harvested) |
| f.3 | Verify GitHub→Forgejo mirror sync cadence vs the nightly 03:23 CI trigger — read `setup-forgejo.sh`'s mirror creation (interval flag?) / Forgejo mirror settings; if lag can exceed the freshness budget, tighten or document | **QUEUED this session** → same two surfaces |

**Hub engineering (hub repo, agent-actionable unless noted):**

| # | Task |
| --- | --- |
| f.4 | `eventcatalog-hub-dist` keep-N / CI-docs parity (pre-existing, hub TODO) |
| f.5 | Pin the CI Go toolchain: replace floating `nix shell nixpkgs#go_1_27` with a locked rev |
| f.6 | `build-stamp.json` provenance: add per-source repo rev + exporter lib version |
| f.7 | Provenance surface in catalog/`llms.txt` (which revs served this generation) |
| f.8 | Push-triggered sync via Forgejo webhook on `-dist` push (fresher than hourly timer, fewer spins) |
| f.9 | Generic source-onboarding guide in hub README (export convention today lives only in go-cqrs-lite's `catalog/README.md`) |
| f.10 | Hub README: document the runner PATH contract (nix/jq/python3 come from the runner UNIT, SystemNix-side) |
| f.11 | `dist/` hygiene in the hub clone: confirm gitignored (local repro artifact vs published branch) |
| f.12 | Verify the `stale-sources` workflow still runs/flags post-mirror-fix (existed pre-go-live) |
| f.13 | Branch protection on `eventcatalog-hub-dist@dist` (CI-owned; the 09-24 protection decision predates the dist-repo split) |
| f.14 | Forgejo Actions log/artifact retention + native-runner workspace growth check (depth-1 clones per run) |
| f.15 | Exporter upgrades to clear the 2 `warn` linter rules → re-arm strict (owner-coordinated; = §c.5) |
| f.16 | `sources.json` schema pre-validation in CI with a friendly per-entry error (today a malformed entry dies mid-run) |
| f.17 | `catalog.index.json` structured-diff consumer wiring in hub CI (downstream of go-cqrs-lite shipping it) |
| f.18 | Per-repo `catalog.json` convention design (move build/export contract into each source repo; hub auto-discovers by convention — the real de-duplication) |
| f.19 | CI failure notification: a dead nightly is only caught downstream by the 36h freshness alert — wire a direct Forgejo Actions failure ping (webhook → existing Discord path?) |
| f.20 | `-dist` repo growth policy: every run pushes a full tree to `dist` branch — history bloat over months; decide GC/orphan-commit policy |
| f.21 | Verify `bank-sync` build phase is stable in CI (d.2's contradiction) — closes or annotates the stale row |
| f.22 | Confirm each source repo's PR pipeline actually runs `check-architecture-changes.sh` (runbook claims source-side wiring; unverified per-repo) |
| f.23 | CI: friendly error when a source mirror is behind its GitHub upstream (today it would silently build stale) |

**SystemNix side (this repo):**

| # | Task |
| --- | --- |
| f.24 | `tests/test-architecture-catalog.nix` VM test (= §c.1, `[ready]`) |
| f.25 | SigNoz freshness tile (= §c.2, condition met) |
| f.26 | Orphaned PAT deletion (= §c.3, owner-gated) |
| f.27 | Verify Gatus' 3 catalog checks are GREEN post-go-live (11-43 verified vHost 200 + fresh=1; Gatus state itself not re-verified since) |
| f.28 | Verify `/llms.txt` + `/schemas.txt` serve non-empty post-go-live (AI surface; smoke §15 checked only `index.html` + title marker) |
| f.29 | Positively verify `GIT_CLONE_TOKEN` scope is read-only (the scope watch-item didn't fire at go-live, but scope was never asserted, only "did not fire") |
| f.30 | Rollback drill: exercise the documented atomic-swap `mv -T` rollback once (never drilled) |
| f.31 | Token-rotation drill: confirm sops `restartUnits` converges the sync unit within one tick (documented, never drilled) |
| f.32 | Catalog content QA on the two mesh domains — first federation of go-cqrs-lite content; spot-check pages render (173-page dist predates mesh? verify the serving generation actually contains them) |
| f.33 | ID-collision audit across the now-4 sources (plan §B flagged "ID collisions across sources must be managed by convention (domain scoping)" — never re-checked at 4 sources) |
| f.34 | Alert-text currency: Gatus stale-alert names the hub CI actions URL — add `lars/eventcatalog-hub-dist` as the publish-target debug hint (run-38 moved the target; triage goes there) |
| f.35 | Dedup review: Gatus pats vs SigNoz rules vs freshness metric — confirm no split-brain alerting on the same failure class |
| f.36 | Re-verify the `mkDnsGate` 180s budget survives the next reboot (sync is DNS-gated; budget was sized for dnsblockd boot load) |
| f.37 | Annotate the stale `[blocked:user]` Actions-go-live rows once f.21 answers them (d.2) |
| f.38 | Fold the 11-43 close-out pointers into the runbook's go-live checklist step annotations (steps carry DONE marks; the evidence pointers live only in the status report) |

**Owner-gated / governance:**

| # | Task |
| --- | --- |
| f.39 | Curation: which of the 8 un-added direct consumers become sources (crush-daily, github-local-sync, go-appkit, papdashboard, sec, SwettySwipperWeb, DiscordSync, zlota44) (§g.3) |
| f.40 | Drift-gate shape: fail-red now vs warn-only soak (§g.2) |
| f.41 | Document the `-dist` repo's no-GitHub-mirror status as intentional (ephemeral artifact repo?) or mirror it for backup |
| f.42 | PAT lifecycle fix so future `setup-forgejo.sh` runs can't leak all-scope PATs (v15 API shape blocks token-authed revoke; needs the password-auth path or upstream change) |
| f.43 | Confirm hub TODO_LIST reflects post-go-live state (09-30 report updated it pre-go-live) |
| f.44 | Decide whether "importer of the exporter lib" should eventually mean auto-onboard (once f.18's `catalog.json` convention exists) — changes the opt-in contract |

**ROADMAP fuel (no near-term dispatch):**

| # | Task |
| --- | --- |
| f.45 | `llms.txt` navigability check as source count grows (4 sources now; what's the ceiling before it needs splitting) |
| f.46 | Catalog UI: per-source filter/domain scoping display (mesh-orders vs mesh-billing share one repo — is that visible?) |
| f.47 | Nightly CI + webhook trigger coexistence tuning (dedup push+nightly builds when nothing changed) |
| f.48 | `build-stamp.json` TZ-consistency check between CI writer and collector parser (fixture-tested 09-23; cheap re-assert at first TZ boundary) |
| f.49 | Consider catalog checksum publication (`dist` manifest) so the sync unit can fail-closed on partial trees beyond the `index.html` gate |
| f.50 | Routine: `scripts/check-todo-system.sh` green after this report's harvest edits land |

## g) Questions I cannot figure out myself

1. **Are hub CI runs after #51 green end-to-end — specifically, is the bank-sync build phase stable?** `docs/todo/services.md` (~line 34) claims jobs "die deterministically at bank-sync build phase"; the runbook claims run 38 fully green (173 pages) + run 51 published `dist`. These contradict and one surface is stale. I have no Forgejo CI access from this session (auth-gated API; typed curl is agent-blocked). One paste of the Actions run list (or the failed step log, if any) settles it — and either closes f.21 or re-opens it.
2. **Drift-gate: fail-red in hub CI immediately, or warn-only for a soak period?** And should the exclusion list live inline in `sources.json` (e.g. an `excluded` key) or as a separate file? This decides whether f.2 lands as a gate or a nag — governance call, not derivable from code.
3. **Which of the 8 un-added direct consumers of `go-cqrs-lite/catalog` should become catalog sources — and is "listed in `sources.json`" still the right opt-in contract, or should the eventual `catalog.json` convention flip it to opt-out?** This is pure curation + policy (owners, ID-collision appetite, catalog noise tolerance) — §f.39/f.44 both hang on it.

---

## Harvest Ledger (repo self-harvest rule compliance)

| Item | Decision | Where |
| --- | --- | --- |
| f.1 (lint.export consumption verify) | **HARVESTED** at authoring time | `TODO_LIST.md` queue one-liner + `docs/todo/services.md` catalog cluster row, `Source:` = this report §f.1 |
| f.3 (mirror cadence verify) | **HARVESTED** at authoring time | Same two surfaces, `Source:` = this report §f.3 |
| f.2 / f.40 (drift-gate) | **Deliberately NOT harvested** — awaiting §g.2 owner decision; queueing a half-decided gate would violate the queue's "agent-actionable `[ready]`" contract | This table |
| f.24/f.25/f.26/f.37 (VM test, tile, PATs, stale rows) | **Pre-existing tracked rows** — no new entries; this report adds verification notes only | `docs/todo/services.md` rows cited in §c |
| f.24 routing-gap NOTICED while harvesting: the VM-test row is `[ready]` in `docs/todo/services.md` but has NO queue one-liner in `TODO_LIST.md` — a queue/library drift that violates the "edit both" rule (pre-existing, not introduced here; left for the next harvest pass, not fixed in this report-only session) | noted | `TODO_LIST.md` services section vs `docs/todo/services.md:184` |
| f.4 (dist keep-N) | **Already hub-TODO** (11-43 §14) — SystemNix surface untouched | hub `TODO_LIST.md` |
| §f remainder | **Brainstorm — not harvested** (>25 items = ROADMAP fuel; routing rigor applied at pickup, not bulk-queued) | This report §f preamble |

## Verification appendix (claim → surface)

| Claim in this report | Verified how |
| --- | --- |
| 4 sources / 3 repos, build+export commands, lint overrides | Read `~/projects/eventcatalog-hub/sources.json` in full this session |
| Runbook claimed 2 sources in two places | Read `docs/services/architecture-catalog.md` in full (14:08) + grep re-verify (16:01) before editing |
| Run 38 green / run 51 published / go-live 11:35 / fresh=1 | Runbook step annotations + `docs/status/2026-10-12_11-43_*` (read, not re-probed — no live check this session) |
| 10 direct + 17 indirect consumers | Owner-pasted `who-uses` output (paste_1) — taken as given, not re-run |
| Discovery-daemon / dependency-graph capabilities | Both READMEs, first 40 lines each — capability claims only, no code read |
| Runner PATH (nix/jq/python3) | `docs/services/architecture-catalog.md` gotcha + `modules/nixos/services/forgejo.nix:1203` comment (grep hit, not full read) |
| CI-state contradiction (d.2) | Both surfaces quoted verbatim; contradiction NOT resolved — escalated as §g.1 |
| Explicitly NOT verified this session | Gatus state, `/llms.txt`, token scopes, mirror intervals, `build.yml` contents, Forgejo CI state — each appears in §f only as a verify item, never as a fact |
