# Status: catalog.home.lan + SigNoz "so few services" diagnosis → sources.json auto-fill generator

**Date:** 2026-10-17 08:45 CEST · **Session scope:** (1) owner question "why do catalog.home.lan and SigNoz report so few services?" answered with live probes; (2) owner directive "sources.json should be auto-filled from `project-dependency-graph who-uses`" implemented end-to-end in the hub repo; (3) this report (requested previous turn, delivered after two interjections). All work verified live unless marked.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a.1 | **Diagnosis answered — neither surface is broken; both are opt-in surfaces and everything wired is flowing** | catalog.home.lan: `200` via the `.150:443` chain, `dist_present 1`, `fresh 1` (stamp 2026-10-16T15:31Z, served gen `20261017-080000`), `scrape_errors 0` (textfile + raw HTTPS probe). SigNoz: coverage textfile `missing 0 / scrape_errors 0 / logs_age 2 s`; ClickHouse 7d = 11 serviceNames (10 real + `dnsblockd-test` ghost) |
| a.2 | **Root cause catalog side: 4 sources by design** — llms.txt/live dist list exactly bank-sync (the only production service) + order-service (cqrs-htmx example) + orders-svc/billing-svc (go-cqrs-lite mesh-demo); fleet inventory (67 `services.integration`, 20 `services.catalog` entries) is NOT rendered there | `~/projects/eventcatalog-hub/sources.json`, live `llms.txt`, `nix eval` counts |
| a.3 | **Root cause SigNoz side: Services page is TRACE-driven** — 13 registered, 10 reporting (span ages seconds old), 3 known upstream gaps (hermes: Python SDK unwired; papdashboard: metrics-only, no trace SDK; projects-management-automation: TracerProvider with zero span sites); logs pipeline covers 716 distinct `service.name` in 24h — the fleet IS observable, just not on the APM page | `/var/lib/prometheus-node-exporter/textfile_collectors/signoz-coverage.prom`, direct ClickHouse queries |
| a.4 | **`scripts/generate-sources.sh` implemented + verified** (hub repo): auto-fills sources.json from `project-dependency-graph who-uses go-cqrs-lite/catalog --dir ~/projects --direct-only=false`; consumer WITH root `.eventcatalog-hub.json` → source (fields verbatim), without → `excluded`; `sources.manual.json` for undiscoverable sources; per-file CI-contract validation (build.yml's expression embedded); deterministic `jq -S` output; `--check` drift mode; `--self-test` fixture harness (direct/indirect tree parsing, display-paren strip, case-insensitive clone-dir fallback `papdashboard`→`PapDashboard`, manual merge) | self-test PASS; real run: **4 sources, 26 excluded**; re-run `--check` = up to date |
| a.5 | **Verification battery on the regenerated sources.json** | diff vs committed: sources array content IDENTICAL (order normalized alphabetical; `\u0026`→`&&` cosmetic); build.yml's contract jq **verbatim** PASS; **`check-sources-coverage.sh` now CLEAN** ("every direct consumer is a source or excluded" — was warning on 8 drifters); CI-side effects: none until pushed |
| a.6 | **Convention files seeded**: `~/projects/bank-sync/.eventcatalog-hub.json`, `~/projects/cqrs-htmx/.eventcatalog-hub.json` (entries mirror the hand-curated ones verbatim; foreign untracked work in bank-sync left untouched) | files written; validated by the generator's contract check live |
| a.7 | **Hub docs updated**: README "Adding a source" rewritten (convention-file flow, generated-never-hand-edited, alphabetical collision precedence); AGENTS.md sources.json contract + "Where to change what" table; hub TODO_LIST: llms.txt formatting bug queued, drift-gate `--strict` flip row stamped (WARN list now EMPTY — precondition changed) | git diffs in hub repo |
| a.8 | **SystemNix memory extended**: AGENTS.md jq-trap bullet now covers the FILE-ARG form — `jq '.x' file.json` → "open file.json: no such file" with `DIRENV_DIFF` set, even short filters; stdin forms and child scripts unaffected; A/B-verified `env -u DIRENV_DIFF` this session | AGENTS.md:124 |
| a.9 | **§f harvest**: services.md `[blocked:push]` onboarding row landed (push + CI verify + next cohort); queue deliberately untouched (push-blocked items are library-only by rule) | docs/todo/services.md tail |

## b) PARTIALLY DONE

| # | Item | State |
|---|------|-------|
| b.1 | **This status report** — requested the turn before; two interjections (a factual question, then the auto-fill directive) landed first | delivered now, folded into one report |
| b.2 | **Generator + convention files are LOCAL and UNCOMMITTED** — no commit instruction; the hub auto-commit daemon may sweep them; CI never sees the regenerated sources.json until origin advances | verification of a real nightly build on the new file is pending the push |
| b.3 | **First diagnosis todo was marked complete on partial execution** — "read integration-registry + monitoring docs" completed having read integration-registry.md only; docs/agents/monitoring.md was never opened (the signoz-coverage.nix runbook header carried the needed facts) | disclosed; lesson in §e |
| b.4 | **Parallel-session tree changes flagged but not audited** — crm.nix/systemd-graph.nix/systemd-timer-monitor.nix diffs (not mine) named to the owner; contents not reviewed | another session owns them |

## c) NOT STARTED

- c.1 Onboarding any repo beyond bank-sync/cqrs-htmx (convention files for crm, browser-history, overview, …) — gated on the push + owner's cohort/confidentiality call (§g.2).
- c.2 The `--strict` flip of the sources-coverage gate (soak runs to 2026-10-19, hub TODO row).
- c.3 llms.txt list-formatting fix (queued hub-side, f.3).
- c.4 The three SigNoz upstream trace gaps (hermes/papdashboard/pma) — pre-existing tracked debt (monitoring.md rows), deliberately not duplicated.
- c.5 architecture-catalog VM test + SigNoz freshness tile — pre-existing services.md rows (201/202), untouched.

## d) TOTALLY FUCKED UP

| # | Failure | Handling |
|---|---------|----------|
| d.1 | **Generator first write shipped a quoting bug** — closed `consumers="$(…)` with `)'` (single quote) instead of `)"`; the stray quote swallowed lines until an apostrophe, producing a misleading "syntax error near `('" three blocks later | caught by immediate `bash -n`; fixed; self-test then caught the NEXT bug (d.2) |
| d.2 | **Contract jq precedence bug** — copied build.yml's field checks without its full per-field parenthesization; `.name | … and .repo` indexed the piped STRING ("Cannot index string with string 'repo'") | fixed; self-test PASS |
| d.3 | **Wasted bisect cycles on confounded methods** — head-truncation "FAILS" (unbalanced constructs always fail) and grep surgery with literal `\t` warnings, before diffing against a clean known-good repro (which found the 1-char bug instantly) | lesson §e.3 |
| d.4 | **Wrong formatting-parity claim** — asserted jq would reproduce `\u0026` escapes byte-identically; it does not (new file has literal `&&`) | harmless: valid JSON, CI-contract PASS, diff cosmetic |
| d.5 | **Todo hygiene** — b.3: a todo marked completed that was only partially executed | disclosed; don't do this |

## e) WHAT WE SHOULD IMPROVE

1. **Diagnose parse failures by differential, not bisection**: diff the failing text against a hand-typed known-good minimal repro FIRST (m3-vs-frag diff located d.1 in one step; the bisect ladder burned 5 steps on artifacts).
2. **Never mark a todo complete on partial execution** — mark it partial or split it (b.3).
3. **Read the routing-table doc before answering in its domain** (monitoring.md for SigNoz questions) — got lucky that the module header carried the facts.
4. **jq in agent shells: always stdin or `env -u DIRENV_DIFF`** — now encoded in AGENTS.md (a.8); scripts are exempt.
5. **Two failed-then-passed jq invocations in the verification battery were initially attributed to the file** ("no such file") — the tool's error text pointed at the file while the environment was the bug; the A/B control (env -u) is the cheap decisive probe. Reach for it earlier on "file not found" claims that `ls` contradicts.

## f) NEXT (12 items; every actionable one harvested or explicitly accounted)

| # | Item | Home |
|---|------|------|
| f.1 | Push hub commit + both convention files; verify the next nightly CI run builds green off regenerated sources.json; then onboard next cohort (candidates: browser-history, crm, overview, papdashboard, dnsblockd) | **harvested**: services.md `[blocked:push]` row |
| f.2 | Fix llms.txt list formatting (entries run together on one line, live build 2026-10-16) | **harvested**: hub TODO_LIST [ready] |
| f.3 | Flip sources-coverage gate `--strict` after soak (earliest 2026-10-19; WARN list now empty) | **harvested**: hub TODO_LIST row (stamped) |
| f.4 | Add `lint` blocks to bank-sync + cqrs-htmx convention files once `--plain`/`-plain` flags are pushed | pre-existing hub TODO row; convention-file era means the blocks land in the REPO files now, not sources.json |
| f.5 | hermes: wire Python OTel SDK → flip `wiring=upstream`→`env` | pre-existing monitoring.md debt (referenced, not duplicated) |
| f.6 | papdashboard: add trace SDK (upstream repo) | same |
| f.7 | projects-management-automation: add actual span sites | same |
| f.8 | `dnsblockd-test` ghost spans (12 spans, last 2026-10-13) — registry note or cleanup | pre-existing: 2026-10-10 report §f.34 (referenced) |
| f.9 | architecture-catalog VM test | pre-existing services.md row 201 |
| f.10 | SigNoz catalog-freshness tile (condition already met) | pre-existing services.md row 202 [watch] |
| f.11 | Decide whether the platform inventory (20 catalog / 67 integration entries) should render anywhere user-facing (fleet "what exists" page) | **deliberately not harvested**: owner product decision (§g.1) gates it |
| f.12 | After gate flip: a NEW catalog-consumer repo without a convention file will FAIL CI — consider a one-line CONTRIBUTING note in go-cqrs-lite's catalog README pointing at the convention file | rides f.4's flag-push window; noted in the services.md row's scope |

## g) QUESTIONS (cannot be answered from the tree)

1. **Scope of catalog.home.lan:** stay an EventCatalog (events/commands of go-cqrs-lite services — today effectively bank-sync + demos), or grow into a full fleet inventory page (the 20-entry `services.catalog` / 67-entry `services.integration` surface)? This decides whether "4 services" is a problem to fix or the design working as intended.
2. **Client repos on the catalog:** Rolls-Royce-mtuGoHelpCenter, Zlota44, SwettySwipperWeb, sec all consume `go-cqrs-lite/catalog` — may their events/commands land on catalog.home.lan (LAN-protected vHost, dist pushed to a private Forgejo repo), or is onboarding restricted to LarsArtmann-canonical repos?
3. **What prompted the question:** was there a specific service you EXPECTED to see on catalog.home.lan or the SigNoz Services page? Name it and I can trace its exact gap (convention file missing vs trace wiring vs both).

---

**Surfaces touched this session:** hub repo (sources.json [generated], sources.manual.json [new], scripts/generate-sources.sh [new], README.md, AGENTS.md, TODO_LIST.md), bank-sync + cqrs-htmx (`.eventcatalog-hub.json` [new, untracked]), SystemNix (AGENTS.md jq bullet, docs/todo/services.md row, this report). Nothing committed; nothing pushed; no deploys; SystemNix config surface untouched.

---

## h) ADDENDUM (same session, ~09:15): the platform-inventory leg — §g.1 answered "everything"

Owner answered g.1: **everything** in catalog.home.lan, every page stating **known deployment locations (zero allowed)**. Implemented end-to-end and verified with a full local EventCatalog build:

| # | Piece | Evidence |
|---|-------|----------|
| h.1 | **SystemNix `scripts/catalog-inventory.sh` + flake app `catalog-inventory`** (apps.nix) — evals `services.catalog` ∪ `services.integration` across evo-x2/rpi3-dns/Lars-MacBook-Air (darwin legitimately contributes zero: imports no service modules; `or {}` guards keep it a live fact; zfs-vm excluded as test scaffold) | live run: **74 services, 66 deployments (65 evo-x2 + 1 rpi3-dns), 9 zero-deploy**; bank-sync spot-check carries url/port/layer |
| h.2 | **Hub `scripts/generate-inventory.sh`** → committed `inventory.json` (`--check` ignores `generatedAt`) | real generation + idempotent `--check` PASS |
| h.3 | **Hub `scripts/render-inventory.py`** — inventory → EventCatalog service pages: green badge chip per deployment host, orange "not deployed" chip + body table at zero; YAML-safe scalars (`yaml_str()` — the crowdsec `summary: …: …` build breaker, caught by the real build) | `--self-test` PASS (incl. slug gate); 74 pages rendered |
| h.4 | **merge.py badges union** (`extract_badge_blocks`) — deployment chips survive collisions with go-exported pages (first-source body wins, badges union by content) | `merge.py --selftest` PASS (2 new cases); real-collision test: bank-sync page keeps `sends:` + gains the `evo-x2` chip |
| h.5 | **Build wiring** — build.sh + build.yml render the committed inventory.json into `work/out/systemnix` and merge it LAST | both files patched (parity) |
| h.6 | **DECISIVE end-to-end**: merged union (real CI content + inventory) into a throwaway EC project → `npm run build` → **602 pages, link-validation green**; `evo-x2` green chip + `not deployed` orange chip verified in the built dist HTML | /mnt/buildcache scratch build (trashed after) |
| h.7 | Docs: hub README "Platform inventory" section + AGENTS.md (contract bullet + ops-table row); SystemNix runbook architecture-catalog.md inventory leg; services.md push row widened to cover both legs | edits landed (daemon-swept) |

Honest residuals: the EC render was verified on a LOCAL build only — the nightly CI run on the pushed tree is the remaining proof (blocked:push, services.md row). Badge color tokens (`green`/`orange`) render correctly in the built CSS vars. Zero-deploy pages include 9 services (alerts, auth, crm, dnsblock, monitor365, monitor365-server + 3 more) — several look like registry drift worth an owner glance (e.g. `dnsblock` vs the deployed `dnsblockd`).
