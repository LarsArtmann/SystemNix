# Session status — kensaku evaluation + local search-stack comparison (docs/research deliverable)

**Date:** 2026-11-06 03:28
**Session scope:** One question chain — "how does github.com/yjid/kensaku compare to what we already have?" → "write a .md for comparisons" → "OpenCloud × Paperless-ngx × file-and-image-renamer vs kensaku". Docs-only session: two files written, zero eval-relevant surfaces touched, no deploy, no service mutation.

**Verified in this session (artifact, not impression):**
- kensaku repo facts via `gh repo view yjid/kensaku --json` + `gh api repos/yjid/kensaku/readme`: created 2026-10-24T21:00:26Z, latest v1.0.15 published 2026-11-04T19:30:37Z, MIT, Rust, 857 stars, pushed 2026-11-05.
- kensaku release assets enumerated via `gh api repos/yjid/kensaku/releases/latest --jq '.assets[].name'`: AppImage/deb/rpm + `kensaku-cli-linux-x86_64` (static binary) + SHA256SUMS.
- No upstream nix support: `repos/yjid/kensaku/contents/flake.nix` → 404; `search/code?q=kensaku+repo:NixOS/nixpkgs+filename:package.nix` → 0 hits. (First query form was a 422 parse error, corrected to the filename-scoped form.)
- kensaku README (raw, master) + `docs/USAGE.md` (raw, master) fetched in full — every kensaku capability claim in the deliverable traces to these two documents.
- In-tree stack facts read, not remembered: [docs/agents/shell-devtools.md:30-55](../agents/shell-devtools.md) (qmd wiring/MCP scoping), [docs/services/opencloud.md:1-60](../services/opencloud.md) (pilot status, xattrs, OIDC, traps 1-14 incl. bleve trap #10), [docs/services/paperless.md:263-318](../services/paperless.md) (3.1.1, FastFlowLM, bge-m3 :8848, Tika/Gotenberg, paperless-gpt :8106, quarterly cadence), [docs/services/file-and-image-renamer.md:1-40](../services/file-and-image-renamer.md) (providers, CQRS store, DLQ, OTel), grep of the renamer module (ports/dataDir/imports), grep of opencloud.nix for tika/search (empty — no Tika deployed), [modules/nixos/desktop/multi-wm.nix:45-46](../../modules/nixos/desktop/multi-wm.nix) (rofi/niri-DMS), [ROADMAP.md:100](../../ROADMAP.md) + [FEATURES.md:137](../../FEATURES.md) (renamer rows).
- Deliverables on disk: [docs/research/2026-11-06_kensaku-vs-local-search-stack.md](../research/2026-11-06_kensaku-vs-local-search-stack.md) + index row in [docs/research/README.md](../research/README.md) (insert confirmed by reading lines 25-34 back).
- Verification pass: `nix fmt -- <both files>` → "formatted 2 files (0 changed)"; relative-link check → 8/8 OK; `git status` read back.

**NOT verified in this session (and why):**
- **Every kensaku RUNTIME behavior claim** — nothing was installed or executed; the CLI binary was never downloaded. The deliverable self-labels all of Part 1 as README/USAGE-claim level. Reason: scope discipline (compare, don't adopt) + an unknown unsigned binary deserves an explicit owner go rather than a unilateral run.
- OpenCloud 7.2.4 search *depth* without Tika (filename-only vs some content indexing) — the "no Tika deployed" half is grep-verified; the "→ limited" half is an inference from upstream architecture, not an upstream-source check.
- qmd's live MCP set / collection state — cited from its runbook (2026-10-09 rescope note), not re-probed.
- The three concurrently-modified files (`docs/todo/upstream.md`, `modules/nixos/services/buildcache.nix`, `scripts/lib/buildcache-reap-names.sh`) — another session's work; flagged in chat, deliberately not diff-reviewed or co-verified per the shared-tree discipline.
- No `nix flake check` / eval ran — docs-only diff is eval-irrelevant by the repo's own predicate; nothing I wrote can break the build.

---

## Self-critique first (the three questions asked)

**What did I forget?**
1. The **gh-FIRST web-research precedence** (documented at [docs/agents/shell-devtools.md:39](../agents/shell-devtools.md)) — I reached for the fetch tool first: one wasted call on the github.com HTML page (nav chrome only) and one 404 on `raw.../main/README.md` before the correct `gh api` path. Two dead calls, ~15 seconds, doctrine violation anyway.
2. A **live probe of `kensaku-cli`** was feasible this session (single static binary, `download` tool, unprivileged run) and would have upgraded the entire deliverable from claim-level to evidence-level. I chose scope discipline instead and labeled the gap — defensible, but the F08 errata doctrine ("every audit-style deep dive MUST include a live-probe phase") leans the other way. This is the single biggest upgrade left on the table.
3. I did **not check the section-quality-guide pitfall about (f) harvesting until the skill told me** — the §f list below is deliberately NOT harvested (owner demanded WAIT); the why is recorded in this report per the self-harvest rule, but it should have been a conscious decision earlier.

**What could I have done better?**
1. Ask the owner's probe go/no-go **before** writing the evaluation, so the doc could ship at evidence-level in one pass instead of two.
2. The research-README index row I added isn't pipe-aligned with its table neighbors (the formatter accepts it — 0 changed — so it is canonical, but raw-diff aesthetics suffered; the signoz row shows the house look).
3. The OpenCloud "search → limited" phrasing in the capability matrix mixes a verified fact with an inference in one cell; the inference deserves its own label inside the cell.

**What could I still improve (standing)?**
1. For any future external-tool evaluation: default to probe-first (download static CLI → run read-only subcommands → then write), with the owner gate asked in the same message that proposes the comparison.
2. Keep claim-labeling discipline (it worked here — every kensaku fact is traceable), but pair it with a named upgrade path in the doc (done: Part 5 probe protocol).

---

## a) FULLY DONE

| # | What | Evidence | Scope |
| --- | --- | --- | --- |
| 1 | In-chat kensaku-vs-stack comparison answered with live-verified repo metadata | gh api outputs (metadata, assets, flake 404, nixpkgs 0-hit) | chat turn 1 |
| 2 | Full five-surface comparison doc written | [docs/research/2026-11-06_kensaku-vs-local-search-stack.md](../research/2026-11-06_kensaku-vs-local-search-stack.md) on disk; `nix fmt` 0 changed; 8/8 relative links verified | docs/research/ (new file) |
| 3 | Research index row added, newest-first in "Evaluations & comparisons" with refresh trigger | README.md lines 25-34 read back post-edit | docs/research/README.md |
| 4 | Claim-vs-verified labeling discipline held end-to-end | every kensaku fact carries README/USAGE-claim labels; every in-tree fact carries file:line cites | deliverable |
| 5 | Concurrent-session discipline: 3 foreign modified files flagged, untouched, not co-verified | git status output + explicit chat flag | shared tree |
| 6 | House style matched to the newest comparison doc (signoz-gap-analysis pattern): Date/Status/Trigger/Sources header, TL;DR verdict, per-surface analysis, refresh trigger | file structure | deliverable |

## b) PARTIALLY DONE

| # | What works | What remains | Blocker | Effort |
| --- | --- | --- | --- | --- |
| 1 | The evaluation doc answers the asked question completely at analysis level | kensaku runtime evidence gap: no probe of CLI/search/OCR/MCP; doc stays claim-level | owner go/no-go on running the static binary + folder scope for a probe | S |
| 2 | §f next-task list written | items NOT harvested into TODO_LIST/domain libs | owner's explicit "WAIT FOR INSTRUCTIONS" — harvesting now would violate it; recorded here as deliberate | S (once unblocked) |
| 3 | OpenCloud search row in the matrix | "no Tika deployed" verified (grep empty); search-depth-without-Tika unverified | needs one upstream-source check | S |
| 4 | Comparison depth for THIS box | resource-footprint, index-size, macOS-side (Lars-MacBook-Air 256GB) and CJK-relevance angles were consciously out of scope | probe first — these are probe outputs, not desk analysis | M |

## c) NOT STARTED

| # | What | Why not started | Still wanted? |
| --- | --- | --- | --- |
| 1 | `kensaku-cli` v1.0.15 live probe (state/search --json, PDF + screenshot OCR spot-checks, MCP initialize handshake) | owner gate: running an unknown unsigned binary + choosing probe folders | yes — the doc's own refresh trigger |
| 2 | Any kensaku packaging (flake or nixpkgs watch) | deliberately not started — WATCH verdict; qmd lesson says adopt upstream packaging only | yes, passively (row watched) |
| 3 | kensaku MCP ↔ Crush wiring trial + context-cost measurement | depends on (1) | conditional |
| 4 | §f harvest into TODO_LIST + docs/todo | owner instruction gate | yes, on go |
| 5 | Pre-existing adjacent rows NOT mine to start unbidden: ai-meter paperless embedding client (docs/todo/services.md:678), renamer local llama.cpp vision (ROADMAP.md:100), OpenCloud watch-fs decision (runbook trap 5), 2027-01-02 paperless quarterly re-audit | pre-existing, owner-prioritized elsewhere | unchanged |

## d) TOTALLY FUCKED UP

**Nothing — by this session's own work.** Specifically: no broken files (formatter clean), no eval surface touched, no service mutated, no secret touched, no foreign file touched. Honest near-misses, downgraded to (e) because they wasted time but broke nothing: the two dead fetches before gh api, the 422 first code-search query, and the inference-grade OpenCloud search cell. The tree DOES carry three files modified by another session (`docs/todo/upstream.md`, `buildcache.nix`, `reap-names.sh`) — flagged, not mine, and NOT counted here because touching or judging them would be the actual fuckup.

## e) WHAT WE SHOULD IMPROVE

1. **gh-first reflex** (violated once, cost 2 dead calls): for any repo/README/API fact question, `gh api`/`gh repo view` is call #1; fetch/raw-URL is the fallback, never the opener. Already documented in shell-devtools.md:39 — the gap is execution, not documentation.
2. **Probe-first evaluations**: an evaluation of a runnable tool with a static CLI binary should propose (and ask go for) the probe in the same breath as the comparison, so the deliverable lands at evidence-level once. Candidate lesson for `references/lessons.md` in crush-config if it recurs cross-project.
3. **Fact/inference separation inside table cells**: verified facts and inferences got one cell ("no Tika → limited"). Fix pattern: inference gets its own labeled clause or a footnote, even in a matrix.
4. **Index-row aesthetics**: match existing pipe alignment when inserting into hand-aligned tables (formatter won't do it — it accepted the row as-is).
5. **Self-harvest timing**: the "record deliberately-not-harvested-because-X in the report" pattern satisfied the rule cleanly here; keep using it whenever an owner gate legitimately blocks harvest.

## f) Things we should get done next

Ranked by impact. NEW = surfaced by this session; PRE = pre-existing row this session touched but did not start (source cited). This is a brainstorm pool per the status-report skill — harvesting waits for owner go (b2).

| # | Task | Impact | Effort | Category | Origin |
| --- | --- | --- | --- | --- | --- |
| 1 | Owner go/no-go + folder scope for the kensaku-cli live probe (the doc's Part 5 protocol) | Critical | S | Feature | NEW |
| 2 | During any probe: verify sensitive-path default-denials (`.env*`, `.pem`, password-manager dirs) behave before pointing kensaku at real home dirs | Critical | S | Security | NEW |
| 3 | Quantify screenshot-token leakage: index ~10 real screenshots incl. token-bearing ones (redact-argv class), inspect what text lands in the index DB, then decide exclusion/purge policy | High | S | Security | NEW |
| 4 | Draft this-box exclusion policy for kensaku if adopted (nix store, /mnt/pool, buildcache dirs, node_modules-class) — protects QLC IO + bounds index size | High | M | Feature | NEW |
| 5 | Verify OpenCloud 7.2.4 search depth without Tika upstream; correct the runbook + the research doc cell | Medium | S | Documentation | NEW |
| 6 | Post-probe addendum to the research doc upgrading claim labels to evidence (or recording probe refusal) | Medium | M | Documentation | NEW |
| 7 | If adopted: MCP scoping decision — which `.crushrc` project scopes get kensaku's MCP (mirror qmd's CV-only pattern; context-cost note applies) | Medium | M | Feature | NEW |
| 8 | If adopted: niri bind for `kensaku --toggle` + DMS tray coexistence check | Medium | S | Feature | NEW |
| 9 | If adopted: index-store location decision under the storage doctrine (OS config dir default vs hot-tier policy) | Medium | M | Feature | NEW |
| 10 | If adopted: probe the Stats-for-Nerds index-size + RSS numbers on this box before any full-home index | Medium | S | Feature | NEW |
| 11 | Probe task: verify shipped-Linux divergence from USAGE.md claims (Windows-first project — inotify limits, `--toggle` under niri) | Medium | S | Verification | NEW |
| 12 | Cross-session coordination: confirm the foreign buildcache/reap-names/upstream.md changes reached completion by their owning session at a quiescent moment | Medium | S | Coordination | NEW |
| 13 | Decide whether the GUI AppImage (appimage-run) is ever acceptable on this box vs hard-requiring a real nix package | Low | M | Decision | NEW |
| 14 | macOS angle: decide if kensaku should ever run on Lars-MacBook-Air (256GB, 90%+ full — index cost matters) | Low | M | Decision | NEW |
| 15 | If kensaku is ever adopted: add its surface to the right agent doc (desktop.md or monitoring.md) | Low | S | Documentation | NEW |
| 16 | Renamer: probe DLQ/dashboard for stuck dead letters (never probed; habit gap found while reading the runbook) | Low | S | Maintenance | NEW |
| 17 | qmd: collection inventory + staleness review (`qmd state`, index.yml) — nothing probed this session, all runbook-cited | Low | M | Maintenance | NEW |
| 18 | qmd: re-verify the CV-only MCP scoping claim still holds (grep `.crushrc`s) | Low | S | Verification | PRE (runbook 2026-10-09) |
| 19 | Polish the research-README row alignment to house style | Low | S | Cosmetic | NEW |
| 20 | Keep the kensaku flake/nixpkgs watch alive at each research-README touch (refresh trigger already recorded) | Low | S | Watch | NEW |
| 21 | Paperless: queue/confirm the 2027-01-02 quarterly AI re-audit (A24 + decision-triage eval loop) | Medium | S | Maintenance | PRE (paperless.md:307-317) |
| 22 | Paperless embeddings: the `[ready]` ai-meter `paperless` client row (embeddings via :8107) sits unactioned | Medium | M | Feature | PRE (docs/todo/services.md:678) |
| 23 | Paperless: verify RAG embeddings now serve the DECRYPTED statement content post-2026-09-15 decryption (value question from the empty-content incident) | Low | M | Verification | PRE-adjacent (paperless.md:269) |
| 24 | Renamer: ROADMAP local llama.cpp vision-provider trial on the 8060S (ROCm) | Medium | L | Feature | PRE (ROADMAP.md:100) |
| 25 | OpenCloud: next `opencloud-production` pin bump → re-check open PR #2704 (avatar `picture` claim import) | Low | S | Watch | PRE (runbook trap 14) |
| 26 | OpenCloud: cleanup decision for quarantined derived state (`search/bleve.corrupt-20261027`, `idm.boltdb.broken-20261103-…`) | Low | S | Cleanup | PRE (runbook traps 10+13) |
| 27 | OpenCloud: watch-fs enable decision if external-change workflows appear (deliberately off today) | Low | M | Decision | PRE (runbook trap 5) |
| 28 | Harvest this §f into TODO_LIST + docs/todo domains once the owner says go (one pass, both surfaces per row) | High | S | Process | NEW (gate) |

That is 28 substantive items. Items 29-50 are withheld deliberately: without new research (which this report was told not to do), rows beyond ~28 would be padding, and padded harvest pools poison TODO_LIST with vague entries — the exact anti-pattern the docs-health HARVEST rules exist for.

## g) Questions I cannot answer myself (3)

1. **Probe gate:** May I download `kensaku-cli-linux-x86_64` v1.0.15 (SHA256SUMS-verified) and run its read-only subcommands (`state`, `search --json`, MCP initialize) — and if yes, against which folder scope: a throwaway test dir, or your real home?
2. **Harvest gate:** After you read this report — should §f items 1-28 flow into TODO_LIST.md + the matching domain libraries now, or do you want to triage them first?
3. **Concurrent session:** The buildcache/reap-names/upstream.md modifications are another session's in-flight work — is that session expected to continue (I keep those files locked), or is it done (safe for a later session to pick up that thread)?

---

**HARVEST status:** deliberately NOT harvested this session — owner instruction "THEN WAIT FOR INSTRUCTIONS" makes §f routing an owner-gated step (recorded here per the self-harvest rule). On go: route per file ownership — 1-11, 13-20 → `docs/todo/desktop.md` or a new research follow-up row; 21-27 → `docs/todo/services.md`; 12 → this report's chat thread; 28 → this pass.

_Report ends. Waiting for instructions._

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** DONE f.28 (this pass) · already-tracked f.22 f.25 · OBSOLETE f.12 · NEW rowed: 17 rows (merged f.2+3, f.6+11, f.7+8+9+10+15, f.19+20) → desktop 8, services 6, pipeline 1, ai-stack 2, security 1
