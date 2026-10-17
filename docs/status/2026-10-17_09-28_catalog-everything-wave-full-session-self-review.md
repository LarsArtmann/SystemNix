# Status: catalog.home.lan "everything + deployments" wave — full-session self-review (diagnosis → sources-autofill → platform inventory)

**Date:** 2026-10-17 09:28 CEST · **Scope:** the entire 3-wave session. Wave 1 (diagnosis) and wave 2 (sources.json auto-fill) were reported at [2026-10-17_08-45](2026-10-17_08-45_catalog-signoz-coverage-diagnosis-sources-autofill.md) — this report consolidates the session and covers wave 3 (platform inventory, owner directive "Everything should be in catalog.home.lan and it should say something about known deployment locations (which can be zero)") in full, plus the honest self-review demanded of the whole run.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a.1 | **Wave 1 — diagnosis answered, live-probed:** catalog.home.lan showed 4 sources BY DESIGN (only bank-sync production; 3 demo trees) and SigNoz's Services page is TRACE-driven (10/13 reporting, 3 known upstream gaps, `missing 0`); both surfaces healthy — "so few services" is a coverage property, not an outage | raw HTTPS 200 via `.150` chain, freshness textfiles, direct ClickHouse queries, `nix eval` counts (67 integration / 20 catalog) |
| a.2 | **Wave 2 — sources.json is now GENERATED, never hand-edited:** `scripts/generate-sources.sh` (who-uses discovery → `.eventcatalog-hub.json` convention files → sources / `excluded`), self-tested + real-run: 4 sources, 26 excluded, CI contract (build.yml jq verbatim) PASS, **drift gate CLEAN**, idempotent `--check` | hub repo, live runs |
| a.3 | **Wave 3 — platform inventory end-to-end:** SystemNix `scripts/catalog-inventory.sh` + flake app `catalog-inventory` (evals catalog ∪ integration across evo-x2/rpi3-dns/Lars-MacBook-Air; darwin = zero by construction, kept a live fact via `or {}` guards; zfs-vm excluded) → **74 services / 66 deployments / 9 zero-deploy** → hub `inventory.json` (committed, `--check` idempotent) → `render-inventory.py` (green chip per host, orange "not deployed" at zero, YAML-safe scalars, slug gate) → merge.py badges union → build.sh + build.yml wiring | live evals, real generation, self-tests |
| a.4 | **DECISIVE verification — full local EventCatalog build on the merged union:** **602 pages, link validation green**; `evo-x2` green chip and `not deployed` orange chip verified in the built dist HTML (`docs/services/<id>/<version>/index.html`); real-collision test proved go-exported pages keep rich bodies while deployment chips union through | /mnt/buildcache scratch build (trashed after) |
| a.5 | **Docs + memory:** hub README (Adding-a-source rewrite + Platform inventory section), hub AGENTS.md (contract + ops table), hub TODO_LIST (llms.txt bug queued, drift-gate flip stamped WARN-list-now-EMPTY), SystemNix AGENTS.md **jq file-arg trap** (A/B-verified new form), runbook `docs/services/architecture-catalog.md` inventory leg, services.md push row widened to both legs | edits landed (daemon-swept) |
| a.6 | **Harvests at authoring time (this report):** TODO_LIST queue + services.md `[ready]` rows for zero-deploy triage + catalog-inventory self-test; hub TODO rows for inventory staleness check + llms.txt deployments section | §f table marks each item's home |

## b) PARTIALLY DONE

| # | Item | State |
|---|------|-------|
| b.1 | **Everything is LOCAL and unpushed** — agents never push; the hub commit(s), bank-sync + cqrs-htmx convention files sit in local trees awaiting the owner push; **CI has never run the generator-era sources.json nor the inventory leg** — the 602-page proof is a local build, not a nightly | [blocked:push] services.md row carries the push + CI-verify chain |
| b.2 | **inventory.json regeneration is manual-on-change only** — no staleness alarm exists yet (queued hub-side, §f.6); until then, deployment chips can go quietly stale if regeneration is forgotten | `--check` exists; automation does not |
| b.3 | **Interim report 08-45 covered waves 1-2; wave 3 only as an addendum** — this report supersedes/consolidates; the 08-45 file stays as the wave-1/2 record | both reports cross-linked |
| b.4 | **Parallel-session changes flagged but never audited** — crm.nix/systemd-graph/systemd-timer-monitor.nix diffs named to the owner twice; the crm description change ("passkey"→"Pocket ID") was ABSORBED into inventory.json mid-flight without reviewing the parallel session's full intent (regeneration is honest, attribution is theirs) | shared-tree discipline followed; audit not mine to do uninvited |

## c) NOT STARTED

- c.1 Client-repo confidentiality decision (§g.1) — gates which repos may onboard as go sources.
- c.2 Zero-deploy registry triage (§f.2 — freshly harvested).
- c.3 `--self-test` for catalog-inventory.sh (§f.4 — harvested).
- c.4 inventory.json staleness check (§f.6 — harvested hub-side).
- c.5 llms.txt formatting fix + deployments section (hub TODO — queued, not started).
- c.6 `--strict` flip of the sources drift-gate (soak to 2026-10-19; WARN list already empty).
- c.7 lint blocks in the two convention files (blocked on `--plain`/`-plain` flag pushes upstream).
- c.8 hermes / papdashboard / projects-management-automation trace gaps (pre-existing monitoring.md debt — untouched this session).
- c.9 architecture-catalog VM test, SigNoz freshness tile, dnsblockd-test ghost spans (pre-existing rows).

## d) TOTALLY FUCKED UP (all caught, all fixed in-session; listed so they teach)

| # | Failure | Lesson |
|---|---------|--------|
| d.1 | **Generator first write closed `$(…)` with `)'` (single quote)** — stray quote swallowed lines until an apostrophe, producing a misleading "syntax error near `('" three blocks away | `bash -n` on write caught it; bisecting by truncation was confounded (unbalanced constructs ALWAYS fail) — diff against a clean known-good repro found the 1-char bug in one step, but only after 5 wasted rounds |
| d.2 | **Contract jq precedence bug** — copied build.yml's field checks without its per-field parenthesization; `.name \| … and .repo` indexed the piped STRING | caught by the self-test (why self-tests exist) |
| d.3 | **Renderer argv bug** (`argv[:1]` vs `argv[1:2]`) — self-test invocation fell through to usage text | trivial, but shipped broken |
| d.4 | **YAML breaker shipped in the renderer** — unquoted summary containing `: ` (crowdsec) broke the astro build; my self-test fixture lacked hostile strings | fixed with `yaml_str()`; **fixtures must include hostile data** (I HAD included display-parens and case-mismatch — the colon was the miss) |
| d.5 | **False-positive verification echo** — `grep -o X file \| head -1 && echo RENDERED` printed "RENDERED" for a file that did not exist (pipe masked grep's exit code) | caught by inspecting the dist layout; violated assert-which-entity discipline in the moment — use `grep -q` against a path that must exist |
| d.6 | **Wrong expectation encoded in the union test** — asserted mesh-demo pages should carry deployment badges; they are library examples with no inventory entry (the test was wrong, not the code) | expectations must derive from the contract, not vibes |
| d.7 | **Two failed scratch-copy strategies** (`cp -al` to /tmp cross-device; `cp -al` over protected-hardlink .git packs) before landing on tar+cp to buildcache | check `df`/mount topology and sysctl protection BEFORE hardlink copies |
| d.8 | **Wrong formatting-parity claim** (`\u0026` escapes) — harmless, but I asserted byte-parity I hadn't proven | the git diff disproved it cheaply; claim what was checked |
| d.9 | **Session-opening todo marked complete on partial execution** (monitoring.md never read) — disclosed at 08-45, repeated here because it is the pattern to kill | never mark partial as complete |

## e) WHAT WE SHOULD IMPROVE

1. **Hostile-data fixtures as a rule** — every emitter self-test gets at least one hostile string (colon, unicode, quotes, case-mismatch) — the crowdsec YAML breaker is the template (d.4).
2. **Verification greps: `grep -q` + must-exist path, never piped-masked echoes** (d.5) — and learn the artifact layout BEFORE asserting presence/absence (the unversioned-page stub cost a wrong near-conclusion).
3. **Parse errors: differential-first** — diff failing text vs a hand-typed known-good repro before any bisect ladder (d.1).
4. **Cross-fs copying: check mounts first** (d.7).
5. **Committed-data freshness needs an alarm** — anything regenerated-on-change by convention (sources.json, inventory.json) deserves a staleness check; generator + `--check` covers correctness, nothing covers FORGETTING (§f.6).
6. **The inventory now makes registry drift VISIBLE — use it** — zero-deploy near-misses (dnsblock vs dnsblockd) surfaced for free; a generation-time near-miss warning could catch naming drift automatically (parked inside §f.2's scope).
7. **Multi-repo waves: enumerate the push manifest precisely** (repo → files) in the blocked row — done for this wave; keep the pattern.

## f) NEXT (14; every actionable item harvested or explicitly accounted)

| # | Item | Home / status |
|---|------|---------------|
| f.1 | Push the wave (hub commits + 2 convention files); verify nightly CI green on BOTH legs; then onboard next go-source cohort (client repos gated on §g.1) | services.md `[blocked:push]` row (harvested 08-45, widened) |
| f.2 | Triage the 9 zero-deploy entries: disabled-by-design vs stale catalog declarations (dnsblock/dnsblockd, monitor365/monitor365-server, alerts, auth, crm…) | **harvested**: TODO_LIST queue + services.md |
| f.3 | Regeneration cadence for inventory.json (owner question §g.2 gates the shape) | rides §g.2 |
| f.4 | `--self-test` for catalog-inventory.sh (fixture jq assembly) | **harvested**: TODO_LIST queue + services.md |
| f.5 | llms.txt list-formatting fix (live defect, build 2026-10-16) | hub TODO (harvested 08-45) |
| f.6 | inventory.json staleness check (generatedAt vs N days) | **harvested**: hub TODO |
| f.7 | llms.txt "deployments" line per service (post-f.5 decision) | **harvested**: hub TODO |
| f.8 | `--strict` flip of sources drift-gate after soak (earliest 2026-10-19; WARN list empty) | hub TODO (stamped) |
| f.9 | lint blocks in bank-sync/cqrs-htmx convention files once `--plain` flags are pushed | hub TODO (existing row) |
| f.10 | hermes / papdashboard / pma trace instrumentation (SigNoz gaps) | pre-existing monitoring.md (referenced, not duplicated) |
| f.11 | dnsblockd-test ghost spans cleanup | pre-existing 2026-10-10 §f.34 |
| f.12 | architecture-catalog VM test | pre-existing services.md row |
| f.13 | SigNoz catalog-freshness tile | pre-existing services.md [watch] row |
| f.14 | Consider a PapDashboard tile/hint that the full fleet inventory lives on catalog.home.lan (the services tab and the catalog now answer different questions) | deliberately not harvested: cosmetic, owner taste — say the word |

## g) QUESTIONS (cannot be answered from the tree)

1. **Client repos on the catalog:** Rolls-Royce-mtuGoHelpCenter, Zlota44, SwettySwipperWeb, sec consume `go-cqrs-lite/catalog`. May their events/commands land on catalog.home.lan (LAN-protected vHost; dist pushed to a private Forgejo repo), or is go-source onboarding restricted to LarsArtmann-canonical repos? Gates f.1's cohort.
2. **inventory.json regeneration cadence:** manual-on-change (current), or do you want an alarm when it goes stale (f.6, N days), or even a scheduled reminder? Determines whether f.6 ships as CI-warn or something stronger.
3. **Zero-deploy semantics:** when a service is declared-but-not-deployed (the 9), is "not deployed" the wording you want on the page (vs "no known deployment locations" / host-count badge)? Trivial to change while the renderer is young (f.2's triage may change the population anyway).

---

**Surfaces touched this session (all local, nothing pushed, no deploys):** SystemNix (scripts/catalog-inventory.sh, flake/parts/apps.nix, AGENTS.md jq bullet, docs/services/architecture-catalog.md, docs/todo/services.md ×3 rows, TODO_LIST.md ×2 rows, 2 status reports), eventcatalog-hub (sources.json [generated], sources.manual.json, inventory.json, scripts/generate-sources.sh, scripts/generate-inventory.sh, scripts/render-inventory.py, merge.py [badges union], build.sh, .forgejo/workflows/build.yml, README.md, AGENTS.md, TODO_LIST.md ×2 rows), bank-sync + cqrs-htmx (`.eventcatalog-hub.json` convention files). Parallel-session diffs (crm.nix, systemd-graph.nix, systemd-timer-monitor.nix) untouched and unaudited.

**Verification battery at close:** all four self-tests green (merge.py, render-inventory.py, generate-sources.sh, …), both `--check` drift gates green, `bash -n` clean, flake app evals green (x86_64-linux), 602-page EC build green.
