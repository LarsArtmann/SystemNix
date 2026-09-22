# Status Report — EventCatalog Federation Planning Session

- **Date:** 2026-09-23 01:14 CEST
- **Session scope:** EventCatalog federation research → architecture decision → comprehensive Pareto plan (REV 1 → REV 2) → SystemNix TODO routing → commits/pushes. NOTHING outside this scope is reported.
- **Artifacts of this session:**
  - `docs/planning/2026-09-22_23-27_EVENTCATALOG-FEDERATION-HUB.md` (REV 2)
  - `docs/todo/services.md` +2 entries (decision + blocked:decision)
  - Commits: `2c8f45a2` (plan REV 1), `305c682e` (plan REV 2) — both pushed to origin/master (pushes also carried 4 pre-existing daemon commits: `cc4c60da`, `ef5ba444`, `ef4460bc`, `052a9d5d` — disclosed, normal shared-tree flow)
- **Implementation status: 0% — this session was research + planning by explicit instruction. No hub, no code, no NixOS changes.**

---

## a) FULLY DONE

1. **Federation research, source-verified** — 10 findings (F1–F10) each with evidence: Enterprise license gate (docs), federation mechanics (`federation.sources`/`federate`/lockfile), go-cqrs-lite exporter emits a complete EventCatalog project, no `catalog.index.json` emission, bank-sync = only real consumer today (catalog cmd has asyncapi/d2/markdown, NOT eventcatalog), SystemNix greenfield, legacy generator fallback, `docserver` is per-service only, no Go tree-loader, Forgejo mirrors as GitHub-outage-immune source.
2. **Architecture decision matrix** (plan §2): A Go-native hub REJECTED with code evidence; **B license-free Node hub = default**; C Enterprise federation = upgrade path with 4 explicit triggers (§7).
3. **Comprehensive Pareto plan REV 2** — re-tiered 1%/4%/20% (license-free P0), 16 comprehensive tasks (T0–T15, 30–100 min), 49 micro tasks (≤12 min), mermaid execution graph, 8 risks, per-phase verification checklists, cross-repo TODO routing map.
4. **SystemNix TODO routing** — 2 library-only entries in `docs/todo/services.md` (correctly NOT queue rows: decision/blocked items are library-only per the TODO contract).
5. **Commits + pushes** — pathspec-scoped (dirty `flake.lock` untouched), detailed messages, hooks green.
6. **Incidental repair:** realized the GC'd `treefmt.drv` that failed the first REV 2 commit's pre-commit (`nix build .#formatter.x86_64-linux` — the stale-drv "path is not valid" class).

## b) PARTIALLY DONE

1. **Plan quality** — REV 2 is strong but: mermaid graph never render-validated; T2's "also probes federate behavior later" is hand-wavy (federate CANNOT be probed license-free — probe only matters for option C); micro 1.2's `<out>/eventcatalog` subdirectory assumption vs bank-sync's existing `docs/catalog` layout (asyncapi/d2/markdown already write there) is UNVERIFIED — a 4th format needs a layout decision.
2. **Cross-repo TODO routing** — plan §10 assigns tasks to go-cqrs-lite/bank-sync/hub TODO_LISTs but I did NOT write those entries (deliberate: uninvited cross-repo edits; open loop).
3. **T9 (`eventcatalog lint`) claim** — cited as free governance without verifying it needs no license and runs via npx in CI.

## c) NOT STARTED (all implementation — by instruction)

Every execution task: T0 two-tree merge spike, T1 bank-sync eventcatalog format, T2–T4 hub repo + CI, T5–T6 NixOS serving + monitoring, T7 source #2, T8 upstream convention docs, T9 lint gate, T10 owners, T11 llms.txt/MCP, T12 federation upgrade eval, T13 upstream exporter work, T14 change detection, T15 runbooks. Zero code changed anywhere.

## d) TOTALLY FUCKED UP

**Nothing unrecoverable.** Two self-inflicted design misses, both caught and corrected inside the session:

1. **REV 1 gated P0 on the Enterprise license** without ever evaluating the license-free path — the biggest thinking error; for a single-owner fleet the federation validation adds ~nothing today. Only fixed when the user pushed ("make it EVEN better"). A first-pass decision matrix would have caught it.
2. **REV 1 scheduled Astro builds ON evo-x2** (nightly npm churn) — collides with the house IO/freeze doctrine; REV 2 moved builds to CI. Should have been instinct.

Near-misses (no damage): first REV 2 commit failed pre-commit on a stale GC'd `treefmt.drv` (environment, realized + retried green); two write-tool mtime races from the shared tree (both verified worktree==HEAD before proceeding).

## e) WHAT WE SHOULD IMPROVE (session-honest self-critique)

1. **Decision matrices before commitment** — REV 1 shipped an assumed architecture (Enterprise + fallback). Rule: any plan with a licensing/infra fork gets the matrix on pass 1.
2. **House-doctrine check earlier** — "builds on the box" should have triggered the IO-doctrine reflex at plan time, not revision time.
3. **Validate rendered artifacts** — mermaid in the plan was never render-tested; cheap to do (`mmdc` or GitHub preview) before pushing.
4. **Verify assumptions that tasks depend on** — Node 22 on the forgejo-runner, bank-sync `docs/catalog` layout collision, lint licensing. Three plan tasks rest on unverified environment facts.
5. **Freshness-chain arithmetic** — REV 2 sets an hourly box sync while Forgejo mirrors update every 8h; the freshness budget is mirror-dominated. Daily sync is the honest cadence; hourly is harmless but signals sloppy chain analysis.
6. **Off-by-one bookkeeping** — chat reported "48 micro tasks" once; the doc has 49. Trivial, but numbers in reports should come from the artifact.
7. **Cross-repo loop closure** — routing assignments without executing (or explicitly deferring) them leaves orphan intent; state "deferred, needs owner consent for cross-repo writes" in the plan itself.

## f) Up to 50 things to get done next

All 49 micro tasks from the plan (§5, sorted by phase/impact) + 1 new from this critique. IDs reference the plan doc.

| # | ID | Task | Min | Phase |
|---|----|------|-----|-------|
| 1 | 0.1 | Export two fixture trees into one scratch catalog | 12 | P0 |
| 2 | 0.2 | Scratch build; record relationship/collision findings | 12 | P0 |
| 3 | 0.3 | Define domain-scoping convention if collisions | 10 | P0 |
| 4 | 1.1 | `formatEventCatalog` flag in bank-sync catalog cmd | 12 | P0 |
| 5 | 1.2 | Wire exporter in `renderCatalog` (+resolve output-subdir layout) | 12 | P0 |
| 6 | 1.3 | Golden/fixture test for new format | 10 | P0 |
| 7 | 1.4 | Run export; inspect tree | 10 | P0 |
| 8 | 1.5 | Commit generated tree + gitignore decision | 8 | P0 |
| 9 | 2.1 | `npm run dev` smoke on bank-sync tree (Node 22 check) | 10 | P0 |
| 10 | 2.2 | Inventory bootstrap files hub-vs-source | 10 | P0 |
| 11 | 3.1 | Create hub repo `architecture-catalog` (OWNER GO) | 10 | P0 |
| 12 | 3.2 | Pin `@eventcatalog/core` v4; document why | 8 | P0 |
| 13 | 3.3 | Sources layout (`sources/<name>/`) | 12 | P0 |
| 14 | 3.4 | Hub README: contract, layout, upgrade path | 10 | P0 |
| 15 | 4.1 | Forgejo Actions: mirrors → copy → build | 12 | P0 |
| 16 | 4.2 | Publish `dist/` (artifact or branch) | 12 | P0 |
| 17 | 4.3 | Source-push trigger + nightly fallback | 12 | P0 |
| 18 | 4.4 | CI cache + cold-build timing (verify runner Node 22) | 10 | P0 |
| 19 | 5.1 | `catalog` DNS entry | 5 | P1 |
| 20 | 5.2 | Caddy `file_server` vHost (layer none) | 12 | P1 |
| 21 | 5.3 | Registry entry `services.integration.catalog` | 12 | P1 |
| 22 | 5.4 | `architecture-catalog-sync` oneshot, atomic swap | 12 | P1 |
| 23 | 5.5 | Sync timer (re-time: daily, mirror-dominated) + deploy.sh entry | 10 | P1 |
| 24 | 5.6 | `nix flake check --no-build` green | 12 | P1 |
| 25 | 5.7 | Deploy + smoke | 12 | P1 |
| 26 | 6.1 | Build stamp + Gatus freshness | 10 | P1 |
| 27 | 6.2 | post-deploy-check section | 10 | P1 |
| 28 | 7.1 | Export cqrs-htmx demo tree | 12 | P1 |
| 29 | 7.2 | Add as source #2; rebuild | 8 | P1 |
| 30 | 7.3 | Verify cross-source graph on live hub | 10 | P1 |
| 31 | 8.1 | go-cqrs-lite catalog README section | 12 | P2 |
| 32 | 8.2 | `cmd/catalog-export` example | 12 | P2 |
| 33 | 8.3 | Versioning guidance | 10 | P2 |
| 34 | 9.1 | `eventcatalog lint` in hub CI (verify license-free first) | 12 | P2 |
| 35 | 9.2 | External-catalog lint refs if supported | 10 | P2 |
| 36 | 10.1 | Teams/users convention | 12 | P2 |
| 37 | 10.2 | owners frontmatter + rebuild | 10 | P2 |
| 38 | 11.1 | Enable `/llms.txt` | 8 | P2 |
| 39 | 11.2 | EventCatalog MCP in crushrc | 12 | P2 |
| 40 | 12.1 | Federation triggers GO/NO-GO note | 12 | P3 |
| 41 | 12.2 | If GO: trial license + `federation.sources` migration | 12 | P3 |
| 42 | 13.1 | Upstream: emit `catalog.index.json` | 12 | P3 |
| 43 | 13.2 | Upstream: skip-bootstrap option | 12 | P3 |
| 44 | 13.3 | Route via go-cqrs-lite TODO_LIST | 8 | P3 |
| 45 | 14.1 | Evaluate architecture-change-detection | 12 | P3 |
| 46 | 14.2 | PR pipeline-gate recipe | 12 | P3 |
| 47 | 15.1 | Hub runbook `docs/services/architecture-catalog.md` | 12 | P3 |
| 48 | 15.2 | SystemNix AGENTS.md hub section | 12 | P3 |
| 49 | 15.3 | Plan handoff: ANNOTATE phases done | 8 | P3 |
| 50 | NEW | Render-validate the plan's mermaid graph; fix if broken | 5 | P0 |

## g) Questions I can NOT answer myself

1. **Green-light Option B + the hub repo?** Create `LarsArtmann/architecture-catalog` (name OK?) as the license-free aggregation hub — this is the single decision the whole P0 waits on.
2. **Committed trees or CI-generated?** Should each source repo COMMIT its generated `catalog/` tree (git-native, reviewable, but adds generated-file churn under your auto-commit daemon) or should hub CI run the Go exporters itself from source checkouts (no repo churn, but Go builds in hub CI and docs lag mirrors)? I defaulted to committed; both are defensible.
3. **Exposure of `catalog.home.lan`:** LAN-only plain vHost (like systemd-graph) or Layer 2 `protectedVHost` behind Pocket ID (architecture docs describe private infra incl. hostnames/ports)? Exposure decision, not engineering.

---

*Post-report note: plan tasks are already routed (services.md + plan §10 cross-repo map) — a docs-health HARVEST pass would only duplicate them, so it is deliberately skipped. Report written as `.md` per explicit user instruction (skill default is HTML). Not manually committed — the auto-commit daemon picks it up; no commit was requested for this report.*
