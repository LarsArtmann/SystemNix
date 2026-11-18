# Status: Linked Records / Prod-Data Lineage — Who Owns Linking (Session Review)

**Date:** 2026-11-18 12:01 CET
**Scope:** Single session, report-only. The question: who should have the responsibility to link records together so data lineage is understandable everywhere — where "records" = PROD data stores and UIs (`crm.home.lan` class), deployed from `SystemNix` (evo-x2 fleet) and `pbx-artmann` (pbx VPS). **No code, config, or doc was changed anywhere this session; this report is the only artifact.**

## Verdict up front

The linked-records manager you are missing is **not a new tool** — it is a missing structured layer inside the deployment configs: SystemNix's `services.integration` registry already links *service → serving surface* (vHost, checks, tiles, ports, OIDC, backup) with eval enforcement, but it stops before *service → data store → class → writers/readers → restore*. That second half exists today only as hand-maintained prose (`docs/agents/data-ownership.md`) plus per-service runbooks — doctrine without a gate. The proposal on the table: extend the registry entry with a `data` field, gate it at eval like tile coverage already is, generate the ownership inventory from it (the `registry-matrix-drift` pattern), and carry the edges in `/etc/systemnix/integration-manifest.json`. `project-meta` stays repo-level and must NOT own this (it cannot fail a deploy and never evaluates the fleet).

## a) FULLY DONE

1. **`meta list --tags business` failure diagnosed and reproduced.** The tag argument carried an invisible U+FE0E variation selector from the paste (visible as `︎` in the terminal echo); the clean invocation works (14 projects, table rendered). The invalid-format error fires on `business︎`, not `business`. Reproduced deliberately with an injected U+FE0E.
2. **Existing prod-lineage artifacts located and read.** `docs/agents/data-ownership.md` (ownership rule: write authority + drilled restore + export path; classes truth/mirror/projection; the 7-surface contacts inventory; contact invariants incl. "a surface not in this table is a finding"; the offsite hole), `docs/agents/integration-registry.md` (registry fan-out, eval gates, manifest bridge, generated Service Matrix), `integration-manifest.json` contract (degrade-loudly, port NAMES not numbers, shape selftest).
3. **`crm.home.lan` deployment chain verified in source.** SystemNix `modules/nixos/services/crm.nix` (registry entry `subdomain = "crm"`, upstream `inputs.crm.nixosModules.default`, SystemNix layers only site specifics; live journal stays at `~/.local/share/crm/ledger.db`, no data migration on adoption) and pbx-artmann `hosts/pbx/crm-reachability.nix` (pbx reaches `crm.home.lan` purely through the NetBird mesh; probes DNS resolve + `/healthz` 200 + cert identity).
4. **Ownership recommendation produced with dismissed alternatives.** (1) Deployment layer owns declared prod lineage — pick; (2) project-meta for repo-level links only; (3) a standalone linked-records manager — dismissed as a second truth, the one state the ownership doctrine itself calls never acceptable.
5. **The concrete gap named.** Registry links service→serving surface, not service→data; data-ownership invariant #7 ("a surface not in this table is a finding") has no eval gate; pbx-artmann cross-location links exist as probes (`crm-reachability.nix`), not declarations.

## b) PARTIALLY DONE

1. **Registry `data` field proposal** — designed at concept level only (`{ store, format, class, writers, readers, restore }`), never checked against `integration.nix`'s actual option definitions. Late realization: the registry's existing `backup = { directory, filePattern, maxAgeHours }` field is already a proto-data-edge; the proposal should be framed as extending that field, not adding a parallel one.
2. **pbx-artmann store inventory** — taken from the repo listing only (Stalwart store, `webphone` `system.db`, `dnsblockd_tracking.db`, `trust-anchor.db` + `trust-anchor-tombstones.db`, mail, pocket-id). Its `AGENTS.md` and host-module conventions were NOT read before recommending "declare its own entries the same way" — unverified that the SystemNix registry abstraction fits its `hosts/pbx/` style.
3. **Business-fleet repo-link candidates** (turn 2: telephony/invoicing/networking clusters) — inferred from names/tags, never verified inside the repos; superseded by the scope correction and retained as LOW priority.

## c) NOT STARTED

- Implementation of anything: `integration.nix` options, eval gates, generated ownership table, manifest extension, pbx-artmann declarations, dashboard surfacing of lineage.
- project-meta UX fix (error message should echo the offending tag value with escaped bytes so invisible runes are detectable) — diagnosed here, filed nowhere.
- No AGENTS.md / TODO_LIST / memory updates in any repo (owner instructed report-and-wait).

## d) TOTALLY FUCKED UP

1. **Scope misread twice.** Turn 1 dove into project-meta repo-to-repo lineage; turn 2 doubled down on repo clusters among the 14 business projects. It took the owner's third message ("I care about the PROJECTS' PROD DATA and UIs") to reach the actual domain. Cost: one full exchange analyzing the wrong layer. Missed signal: "understand data lineage well everywhere" pointed at deployed systems, not repositories. Compounding factor: `meta`-command context primed the repo interpretation.
2. **Asserted unverified relationships.** The turn-2 cluster table stated verbs (`feeds`, `config-of`, `experiment-for`) as if established; they were name/tag inference. Plausible, evidence-free.
3. Minor: `rg -rl` hook block (replace-flag trap, third strike on this host per the hook's own message) — corrected to `rg -l` immediately.

## e) WHAT WE SHOULD IMPROVE

1. **Classify ambiguous domain nouns out loud before analyzing.** "Records" had three readings (repo records / business records / data records); the data-ownership doctrine itself demands "name the thing in the domain" first — apply that to the question, not just the answer.
2. **Cross-repo prescriptions require reading the target repo's conventions first.** Recommending a mechanism for pbx-artmann without opening its AGENTS.md violated the fleet's own knowledge-routing rule.
3. **Route small findings at discovery time.** The tag-error echo gap was "parked" verbally instead of landed in project-meta's TODO_LIST — verbal parking is how findings evaporate.
4. **When a repo's AGENTS.md has a "Who owns X?" routing row, start there.** data-ownership.md was reached only after the correction; the routing table would have answered turn 1's question directly.

## f) NEXT (ranked; 43 items — harvest pending owner instruction)

**Decisions / ADR**
1. Owner decision: adopt the `services.integration.<name>.data` extension as the prod-lineage system of record (this report's core proposal).
2. ADR (or amendment to data-ownership.md §The rule): registry declarations = truth for lineage; the markdown table becomes generated output.
3. Pick the pilot service (recommendation: `crm.nix` — richest chain: truth + projection + external truth + auth material + backup leg).
4. Decide manifest exposure: extend `integration-manifest.json` vs a separate lineage manifest file.

**Design**
5. Final option shape, framed as extending the existing `backup` field: `class` (closed enum: truth / mirror / projection / edge / consumer / cache / local-book), `writers`, `readers`, `format`, `restore`.
6. Cross-ref validation: `writers`/`readers` must be registry service names or explicitly `external:<system>`.
7. Decide how "one truth domain, exactly one writer" (invariant #1) is expressed: per-domain grouping key on data entries.

**Implementation (SystemNix)**
8. `integration.nix`: add the `data` option set + types.
9. Eval gate: enabled service with state (`StateDirectory` / `dataDir` / `backup.directory`) and no `data` entry ⇒ eval failure (mirror of the tile-coverage gate).
10. Eval gate: `class = "truth"` requires a `restore` declaration.
11. Eval gate: single-writer check across all enabled entries per domain key.
12. `registry-matrix`: add a DATA column.
13. New derivation + drift check generating the data-ownership inventory table (features-drift pattern); shrink `data-ownership.md` to doctrine + generated table.
14. Manifest builder + shape selftest extended with data edges (extend the fixture; builder/`integration.nix` parity is pinned by existing checks).
15. `crm.nix` pilot entry: `ledger.db` truth (relations/deals/tasks), `identity-*.db` auth material (class: cache/credential — needs naming), Stalwart CardDAV people = `external` truth read via projection, `crm-backup` restore leg.
16. Entries for every enabled stateful service, each verified against module + runbook first: pocket-id, immich, miniflux, taskchampion-sync, timesheets, invoices-dashboard, forgejo, paperless, opencloud, discordsync, bank-sync, browser-history, stalwart (pbx), webphone (pbx), gatus/history, crush-hot-db.
17. post-deploy-check.sh: verify declared stores exist on disk + backup freshness per entry (consume the manifest, degrade-loudly).

**pbx-artmann**
18. Read pbx-artmann AGENTS.md + hosts/pbx conventions before prescribing its mechanism.
19. Inventory its stateful stores with classes (incl. `dnsblockd_tracking.db`, `trust-anchor.db` + tombstones — lifecycle class unknown: truth? cache? rebuildable?).
20. Decide mechanism: own declaration style vs shared lib exported from SystemNix/nixos-modules.
21. Stalwart contacts/calendar provisioning + CalDAV probe verdict (existing Pareto 3-5 gate) — the declared truth is still pending its probe.
22. PII restore drill (existing Pareto task 7).
23. Offsite-borg dormancy (existing known hole, re-surfaced by this review: two copies, one chassis).

**Cross-location**
24. Upgrade `crm-reachability` from probe-only to probe + declared dependency edge (declaration names the mesh + target service).
25. NetBird mesh links as first-class lineage edges (which hosts reach which services).

**Consumers**
26. Dashboard: once the manifest carries edges, surface a lineage view (UI → service → store → class).
27. Gatus/monitoring: alert class on truth-store backup-age drift (backup-coordination already has freshness — wire the class into it).

**project-meta**
28. Error UX: on invalid tag, echo the offending value with escaped bytes (this exact U+FE0E case was undiagnosable from the message alone).
29. Consider flagging/stripping zero-width + variation-selector runes in tag args with a did-you-mean hint.
30. ROADMAP: annotate "Project dependency graph visualization" with the prod-lineage decision pointer (meta stays repo-level).
31. Decide the optional `deploys-via: systemnix | pbx-artmann` pointer field (yes/no; it is a pointer, never lineage itself).
32. (LOW, only if ever wanted) business-cluster repo links from turn 2 — verify before recording any.

**Housekeeping**
33. When items above land: harvest this report's §f per docs-gates doctrine (TODO_LIST + domain libraries), then this note is satisfied.
34. Re-check the docs-gates battery (cadence ≤15 unarchived reports; routing) after this report lands.
35. `data-ownership.md` "Last verified" line: re-stamp ONLY on real re-verification — this report does not re-verify any row.
36. Annotate/archive this report per the status-report ritual once its open items are routed.
37. Confirm no other fleet surface already declares data lineage that this proposal would duplicate (checked: catalog/services + integration + runbooks + data-ownership — none structured; a final grep-sweep for stray `dataDir` inventories belongs to the implementation task).
38. Extend `checks.integration-manifest-shape-selftest` fixture in the same change as the builder (never after).
39. Consider a VM test asserting the eval gates fire (state without data entry; truth without restore; two writers one domain).
40. Decide whether `local-book` (webphone's class) joins the enum or stays prose until the owner decision (question g-2 unblocks it).
41. Naming pass on the field: `data` vs `stores` vs `state` — the entry describes stores+flows, not data itself.
42. Decide where restore-drill status lives (declaration field vs runbook-only) so "drilled" stays honest — an undrilled dump is a hope, not an asset.
43. If adopted, port the contact-surface table's seven rows into declarations as the acceptance test (the doc becomes fully generated).

## g) Questions for the owner (cannot be figured out from the repos)

1. **Adopt the registry `data` extension?** (f-1) Yes with pilot `crm.nix` / yes with a different pilot / no — keep data-ownership.md hand-maintained as the only lineage record.
2. **webphone's local book** (`docs/agents/data-ownership.md` "The webphone decision", recorded as owner-pending): device-local forever, or hub-reader of Stalwart? Its `data` entry cannot carry an honest class until this is answered.
3. **pbx-artmann mechanism** (f-20): should pbx-artmann adopt the same registry-style declarations (shared lib), or record lineage its own way in `hosts/pbx/`? Its conventions were not read this session; the choice shapes whether the fleet gets one lineage view or two half-views.

## Provenance note (docs-gates)

§f items 1-43 are **deliberately not harvested** into TODO_LIST.md / domain libraries because the owner instructed report-then-wait; harvest on instruction. No living doc was modified this session.
