# PapDashboard Tile-Coverage Enforcement — Full Status & Self-Review

**Session:** 2026-10-25 ~06:30–07:45 CET · **Scope:** this session only (tile-coverage work + what it touched/flagged in passing)
**Trigger:** owner question "Are all my services automatically added to PapDashboard?" → owner pushback ("We have nix for a reason! … changes do not miss things!") → implementation → owner course-correction ("If icon = null WARN!").
**Deliverable in one line:** every web-facing (subdomain-bearing) `services.integration` entry now MUST carry a PapDashboard tile — enforced by an eval-time assertion — tiles default-derive (name/group/href), icon-less tiles WARN (owner directive), and the 3 silently-lost tiles (forgejo, paperless, immich) are restored in-tree.

---

## a) FULLY DONE (verifiably)

1. **Tile-coverage eval assertion** (`modules/nixos/services/integration.nix`): enabled entry with `subdomain != null` and no `homepage` tile fails `nix flake check`/toplevel eval. Gated on `options ? services.papdashboard` (hosts without the dashboard aren't forced). *Evidence: fired live on first run (caught immich), toplevel eval green after fixes; `PASS [tilecoverage/tile-stripped]` harness leg.*
2. **Icon-null WARN gate** (owner directive "If icon = null WARN!"): registry tiles with `icon = null` emit a `config.warnings` entry (monogram renders, eval stays green) instead of failing. First implementation was a HARD assertion — corrected within the session on owner directive. *Evidence: `PASS [tilecoverage/icon-stripped]` — eval green with expected warning; zero warnings on the live tree.*
3. **One-line tile authoring defaults**: `homepage = { icon = "x.png"; }` now suffices — `name` derives from the subdomain (falls back to entry key for headless tiles), `group` defaults to `"Services"`, `href` derives `https://<subdomain>.<domain>`. *Evidence: `defaults-tile-name-derived` / `-group-default` / `-href-derived` checks green in `integration-registry`.*
4. **`noDashboardTile` opt-out option** (bool, default false, justification comment required by docs): lives ON the entry, dies with it. Two live exemptions wired: `papdashboard` ("the dashboard itself — a self-tile is a navigation no-op"), `tq-serve` (its UI's tile is the `tq-agent-pool` entry; same href). *Evidence: matrix shows exactly those two with `noDashboardTile=true`, toplevel green.*
5. **Three recovered tiles** (all icons verified in the pinned dashboard-icons pack, `PAP_ICONS_DIR` derivation builds green):
   - **forgejo** (`forgejo.png`, Development) — tile silently DROPPED in the 2026-09 homepage.nix→PapDashboard merge; its comment still claimed the tile "stays static in homepage.nix", a file that no longer existed. Stale comment replaced with the incident note.
   - **paperless** (`paperless.png`, Productivity) — comment claimed "layer none keeps DNS + tile derivation" while no `homepage` field existed. Comment corrected + tile added.
   - **immich** (`immich.png`, Media) — never carried a tile at all; **missed by my own manual matrix read, caught by the assertion on its first live run** (the audit out-performed my eyes — the strongest possible validation of the owner's "enforce, don't remember" demand).
6. **Tests — `tests/test-integration.nix`** (check `integration-registry` builds green): defaults-resolution assertions (demo-plain exercises the minimal one-line form), `negativeTileFires` (ghost-tile entry → coverage assertion message present), `iconWarnFires` (ghost-icon entry → warning present in `config.warnings`), rendered services.json now also greps the icon. Failure ladder restored intact after a mid-session edit accident (see d.3).
7. **Negative-test harness — `scripts/negative-test-lints.sh`**: new `warn_case` class (eval must stay GREEN and the warnings JSON must contain the marker — a throw = "gate regressed to error", a missing marker = "phantom-quiet gate"), new `eval_warnings` probe, `tilecoverage` group (2 legs + control wiring). *Evidence: `PASS` ×3 on both semantics runs (hard-assertion era and warn era).*
8. **Docs**: `docs/agents/integration-registry.md` step 6 (enforcement + defaults + opt-out), `docs/services/papdashboard.md` (coverage bullet + icon-null semantics), `AGENTS.md` eval-time prevention row (both cells), `CHANGELOG.md` entry (count corrected from a wrong hand-typed 27 to eval-derived 28 — see d.1), `[decision]` row queued: soften §16 pre-deploy monogram BLOCK?
9. **Queue self-harvest** (this report's direct follow-ups): 2 `[ready]` rows in `TODO_LIST.md` **and** `docs/todo/services.md` (registry blind-spot audit; noDashboardTile+homepage mutual exclusivity), 1 `[watch]` library row (deploy + post-deploy verify). `scripts/check-todo-system.sh`: "OK: TODO queue/library structure clean".
10. **Blast-radius verification of every check consuming `integration.nix`**: `integration-registry`, `module-shape-lint`, `gatus-pattern-lint`, `doc-counts`, `signoz-query-lint`, `with-pkgs-lint`, `scrub-exit-contract`, `bridge-exit-contract`, `gitleaks-coverage-selftest`, `catalog`, `caddy-mint` — all green. shellcheck: no new findings in my added ranges (all SC2016 infos are pre-existing harness lines).
11. **Foreign-failure attribution** (flagged, not touched — parallel session's in-flight work): `tests/test-upholds-convergence.nix` fails flake check (`systemd.units."mnt-uph.mount".upholds` option absent on the pinned nixpkgs `fe13242`; file landed 05:48 today) and `dead-guard-lint` reds on `platforms/nixos/desktop/quickshell.nix:50` (committed 05:13 today). Both pre-date my edits, zero overlap with tile files.

## b) PARTIALLY DONE

1. **The change is NOT DEPLOYED** — everything above is eval/check-level only. The 3 tiles do not render on the live Services tab, the assertion does not yet guard the PROD deploy, and §16 pre-deploy has not run against the new tile set (28 iconned tiles — expected green). *Blocked on: the next deploy window (rides the existing PSI-calm `[watch]` batch) AND the two foreign eval reds (d.4) which block `nix flake check`-gated deploys for the whole tree.* Effort: S once unblocked.
2. **`nix flake check --no-build` could not complete** this session — it aborts at the foreign `upholds` option error before evaluating every check. Compensated by individually building all 12 checks that touch my files (all green, a.10) — equivalent coverage for MY surfaces, but the full-tree green claim is not mine to make right now.
3. **Icon-policy layering is coherent but owner-unratified**: eval WARN (new) → §16 pre-deploy BLOCK (2026-10-17) → `icons_ok` Gatus ALERT. An icon-less tile still cannot ship; the eval warn is informational only until §16 is decided on (queued `[decision]`).

## c) NOT STARTED (deliberate, this session)

1. **§16 softening** — owner decision queued, not pre-empted (it has its own incident history: the 2026-10-17 "logos went dark" class).
2. **Headless-service tiling** — entries with ports but no subdomain (crowdsec, gotenberg, tika, …) stay untiled BY DESIGN: subdomain = the web-facing marker. If the owner wants e.g. crowdsec's console tiled, that's a per-entry `homepage` opt-in, no code change needed.
3. **pocket-id registry entry** — auth.home.lan is web-facing but has NO registry entry at all (hand-rolled vHost), so the new assertion literally cannot see it. Not started because registering the identity provider into the registry it consumes (OIDC provisioning fan-out) may be deliberately circularity-avoiding — owner question g.3, queued as a `[ready]` audit row.
4. **icons_ok / dashboard-side coverage metric for web-facing count** — considered, rejected: the host-side web-facing count is only knowable at eval; the eval assertion IS the gate. No runtime duplicate needed.

## d) TOTALLY FUCKED UP (radical honesty — all caught and fixed in-session, none shipped)

1. **CHANGELOG count was wrong**: I hand-typed "27 tiles + 2" in the CHANGELOG entry while the eval-truth was **30 web-facing = 28 tiles + 2 opt-outs**. A count claim in a permanent record, typed from memory instead of derived from the eval I had just run — exactly the class this repo's "show the post-state" rule exists for. *Fixed this session (07:4x): corrected with an explicit "(an earlier draft said 27)" so the correction is visible, not silently rewritten.*
2. **My first matrix read was wrong**: I reported "4 offending entries" (forgejo, papdashboard, paperless, tq-serve) while immich sat tile-less in the very table I was reading. The assertion caught it. My manual enumeration — the thing the owner was implicitly told to trust in my first answer — had a silent miss of its own. Ironic and instructive: the enforcement was worth building precisely because careful humans (and their agents) skim.
3. **Edit-tool accident in the test ladder**: a non-unique `else` match failed, my retry's old_string swallowed the `negativeFires` (DNS) leg entirely — I deleted a passing negative test while adding two. Caught by structure grep, restored. Root cause: editing a 300-line ladder with two large multiedits instead of surgical anchors. Additionally: I briefly wrote `negativeStaleExemptionFires = staleMsgPresent || true` — a **fake always-green test** — caught in self-review before commit and removed. Two near-misses in one file; the discipline that saved both (grep the ladder, re-read the diff) must stay mandatory.
4. **First exemption design was host-sensitive**: a CENTRAL `tileExemptions` table + a stale-row assertion. It failed correctly inside the test fixture (papdashboard disabled there → rows looked "stale") — the test did its job, but the design was wrong: a global table cannot know host-local entry existence. Replaced by the per-entry `noDashboardTile` flag (dies with its entry, no dust, no stale check needed). Cost: one design cycle that should have been the first choice — "state that is a property of the entry belongs on the entry" is Data-Models-101.
5. **Icon gate severity misjudged**: I shipped icon-null as a HARD eval failure; the owner had to spend a message correcting it to WARN. I defaulted to maximal enforcement on a COSMETIC gap against this repo owner's known taste (warn-first for degradation, hard-fail for structure). The tier principle is now written into the module comments (coverage = structural = fail; icon = cosmetic = warn), but I should have asked the tier question myself at design time.
6. **Sloppy verification plumbing, twice**: (a) `nix build | grep -q .` inverted logic — briefly reported 4 green lint checks as FAIL (grep matched nix's warning lines, not failures); (b) queried nonexistent attribute `lint-static` and initially echoed "FAIL" before reading the error ("attribute does not exist" ≠ lint failure). Both self-corrected within a minute; neither touched the tree — but exit-code-first verification one-liners are the fix, permanently.
7. **Hit the documented `rg -r` hook trap** — my attribution command tripped the hook's third-strike warning. The trap is written down in AGENTS.md, I had read it, and I still typed a matching shape. No damage (hook blocked it); recorded as a recurrence data point for the hook's strike counter.

## e) WHAT WE SHOULD IMPROVE (process, not bugs)

1. **Tiered-enforcement doctrine, written down once**: this session's real lesson. STRUCTURAL invariants (service missing from the dashboard, port unmonitored, DNS unregistered) → hard eval assertion. COSMETIC gaps (missing icon, missing description) → eval warning + optional deploy gate. Propose a short table in `docs/agents/integration-registry.md` or AGENTS.md so the next audit author doesn't guess severity per-audit (I guessed wrong once already).
2. **Count claims must be eval-derived, never typed**: my CHANGELOG "27" should have been piped from `nix eval … | jq`. A tiny helper (`scripts/` or just a documented one-liner pattern) for "emit registry counts" would kill the class.
3. **Verification one-liners: exit codes first** (`if nix build …; then green; fi`), output-grep second. The inverted-grep bug (d.6a) is a two-strikes-per-year class for me; make the correct form the copy-paste habit.
4. **Multiedit discipline on ladder/structure-heavy files**: one logical change per edit + structural grep after EVERY batch (not after all batches). d.3 would have been caught a step earlier.
5. **The fixture caught my design bug before any human did** — the minimal-module eval fixture (test-integration) is the cheapest design review this repo has. When adding cross-cutting registry semantics, write the fixture leg BEFORE finalizing the module design; it evaluates host-sensitivity assumptions instantly.
6. **Foreign-red attribution should be timestamped earlier**: I ran the full flake check late and discovered the `upholds` red only at the end; running it once mid-session (instead of only targeted checks) would have surfaced the parallel session's breakage an hour earlier and sharpened my own green claims. Trade-off: mid-session full checks are noisy during parallel work — the repo's quiescent-moment rule exists for a reason; a compromise is one full check right before writing any "verified" claim.

## f) Next tasks (session-derived; NOT padded to 50 — 12 real ones, the rest of the 50-slot budget is better spent honestly empty than filler)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Deploy the batch (rides PSI-calm window + foreign-red clearance), then readlink-anchor + post-deploy: 3 new tiles render, §16 green, tile dots sane (302/401 on auth-fronted vHosts is fine; only ≥500 shows down) | Critical | S | Feature |
| 2 | Owner: §16 monogram-block soften decision (queued `[decision]`) — warn-and-continue vs hard logo bar | High | S | Decision |
| 3 | Registry blind-spot audit: rendered caddy vHosts vs registry subdomains; per-delta register-or-assert (pocket-id is the known delta) — QUEUED | High | M | Quality |
| 4 | Fix the FOREIGN `upholds` test for pinned nixpkgs (owning session) — currently blocks full-tree `nix flake check` and deploy validation | High | S | Bug |
| 5 | Fix the FOREIGN dead-guard red on `quickshell.nix:50` (owning session) — same tree-blocking class | High | S | Bug |
| 6 | `integration.nix`: reject `noDashboardTile = true` set together with a `homepage` tile — QUEUED | Medium | S | Quality |
| 7 | Post-deploy: confirm no tile lands in the default "Services" group unintentionally (all current entries carry explicit groups; the default is future-facing) | Low | S | Verification |
| 8 | Headless tiles audit: fastflowlm / hermes / llama-rag tiles have `href = null` (decorative, no probe) — decide if they want `checkUrl` probes or stay decorative | Low | S | Quality |
| 9 | http(s)-URL icons are unverified at runtime (§16 checks pack-relative names only) — a dead external URL = silent broken logo; optional gatus probe of `/icons/<name>` | Low | M | Monitoring |
| 10 | Tiered-enforcement doctrine table (e.1) — structural=fail / cosmetic=warn, with the two live examples | Medium | S | Documentation |
| 11 | Eval-derived count one-liner documented next to the CHANGELOG conventions (e.2) | Low | S | Tooling |
| 12 | `warn_case` harness class: backfill a leg for any OTHER warning-class gate that currently has no negative test (survey `config.warnings` authors) | Medium | M | Testing |

*Harvest status: #3 and #6 are queued (`TODO_LIST.md` + `docs/todo/services.md`); #1 is a library `[watch]` row; #2 is a `[decision]` row. #4/#5 belong to the parallel session and are flagged, not hijacked. #7–#12 deliberately NOT harvested — owner triage first (this report waits for instructions).*

## g) Questions I cannot answer myself

1. **§16 severity**: when a tile genuinely has no icon, should the pre-deploy gate keep BLOCKING the whole deploy (current behavior — the 2026-10-17 logos-went-dark stance), or warn-and-continue to match the new eval policy? This is pure owner taste about the deploy quality bar; both are defensible; I cannot infer it from code history because both eras have incident-backed rationale.
2. **The web-facing line**: is `subdomain != null` the permanent definition of "must be on the dashboard"? Port-bearing headless services with web consoles (crowdsec's 6061 metrics UI is the live example) are currently invisible to the gate by design — do you want any such surface tiled/covered, or is "no subdomain = no dashboard presence" the covenant?
3. **pocket-id**: is the identity provider's absence from `services.integration` (hand-rolled vHost, no entry, no tile, no assertion pressure) deliberate circularity-avoidance (it provisions the OIDC clients the registry fans out to), or an oversight you want registered like every other web-facing service? I can see the code both ways; only you know the intent.

---

**Format note:** written as `.md` per the explicit request — the status-report skill's canonical format is HTML; explicit user instruction wins, override flagged here per the skill's own rule. Self-review content (the "what did you forget / what could be better" questions) is folded into sections d/e rather than a separate `docs/reviews/` HTML for the same reason.

**Now waiting for instructions.**
