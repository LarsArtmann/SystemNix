# EventCatalog Federation Hub — Session 3 Report (T5–T13 executed, T14/T15 remaining)

**Date:** 2026-09-23 13:26 · **Session:** continuation of the "execute T0–T15 one step at a time" directive
**Plan:** `docs/planning/2026-09-22_23-27_EVENTCATALOG-FEDERATION-HUB.md` (REV 3)
**Predecessor:** `docs/status/2026-09-23_05-06_eventcatalog-hub-session2-t3-t4-report.md` (session paused on 3 owner questions; this session proceeded code-side per the standing directive and stages the owner-gated legs at the end)

---

## a) FULLY DONE this session

### Hub repo hygiene (pre-T5)
- Daemon had committed **939 files** of `.eventcatalog-core/` npm working-dir noise + an empty `eventcatalog.styles.css` into unpushed `3ff9e6a`. Untracked both, extended `.gitignore`, amended into a proper message (`188c8fc`), pushed.

### T5 — NixOS serving leg (code complete, deploy owner-gated)
- **DNS:** `catalog` added to `platforms/common/dns-local.nix`.
- **caddy.nix:** `extraVHosts.port` → `nullOr`, new `root` option, `staticVHost` renderer + a protected-static variant (external → forward-auth + `file_server`, LAN → `file_server`), dispatched from `renderVHost` when `root` is set. Rendered output verified via `nix eval` (exact Caddyfile block).
- **integration.nix:** `vHost.root` registry option; `vhostIncomplete` assertion + `vhostEntries` filter relaxed to accept root-without-port; fan-out passes `root`.
- **NEW `modules/nixos/services/architecture-catalog.nix`** (flake-parts wrapper): sync oneshot (root + `harden{}` + `mkDnsGate` for forgejo.home.lan + sops `EnvironmentFile` + PLACEHOLDER-inert skip + index.html sanity gate + atomic `current` symlink swap + keep-3 generations + `chmod -R a+rX` + token redaction from journal), hourly `Persistent` timer, `ioTier.background`, tmpfiles rules, registry entry (subdomain `catalog`, `vHost.layer = "protected"` + root, 3 Gatus checks, homepage tile `mdi-sitemap`, `unit = architecture-catalog-sync`, monitored).
- **sops:** `platforms/nixos/secrets/architecture-catalog.yaml` created + encrypted with the public age key (PLACEHOLDER value), `git add -f` (new sops files need no sudo — the public-key route).
- **configuration.nix:** enable block after geometrikks.
- **Verified:** `nix flake check --no-build` green (all eval audits: shape/port/gate-timeout/deploy-restart/gatus-pattern-lint/sops-key-audit); vHost rendered; 3 gatus endpoints with absolute `https://catalog.home.lan/` URLs; monitored list; hourly timer; tile present. Confirmed `architecture-catalog-sync` matches NO converger pattern → no deploy.sh entry needed (hourly Persistent timer converges after every boot/deploy).

### T6 — Freshness monitoring (code complete)
- `architecture-catalog-metrics` textfile collector (5-min timer, pool-smart-metrics pattern: mktemp + chmod 644 + CAP_FOWNER + fail-closed) emitting `architecture_catalog_{dist_present,fresh,stamp_age_seconds,scrape_errors}`; honest-absence (not scrape-error) pre-go-live.
- Gatus **"Architecture Catalog Freshness"** check — anchored `pat(*\narchitecture_catalog_fresh 1*)` forms (HELP-comment-safe), node-exporter :9100.
- **post-deploy-check.sh §15** — skip-with-WARN until `/var/lib/architecture-catalog/current/index.html` exists; then HTTPS check + `<title>EventCatalog` marker + collector flags.

### T7 — cqrs-htmx source #2 (done end-to-end)
- Upstream `examples/catalog-demo`: **`-export-only`** headless flag (write tree, exit 0, no server). Verified E2E (5 MDX files, no port bind, `go vet` + tests green). Pushed `dd1f6162` (see §d for the pre-commit saga).
- `sources.json`: cqrs-htmx onboarded (demo has its own go.mod; build/export/tree fields).
- `setup-forgejo.sh`: new **mirror-sync step** for every source repo before the workflow dispatch (mirror pull interval is 8h — a freshly pushed exporter flag would otherwise fail the first CI run on a stale clone).
- **Two-source E2E build from GitHub remotes: 123 pages, both services in `llms.txt`, link validation green.** Hub committed + pushed (`da0d304` rode the daemon; content exact).

### T8 — go-cqrs-lite rollout convention (done)
- `catalog/README.md`: **"Feeding the federation hub"** (headless-export contract, 3 working shapes, sources.json onboarding) + **"Versioning your catalog"** (when to bump Version, `Changelog []Change` shape, badge semantics).
- `catalog/cmd/catalog-export/main.go`: copy-paste template (drop in, replace `buildCatalog()`). Verified: builds, vets, exports a 3-file tree.
- Pushed `b95e8b288` (after binary purge, §d).

### T9 — Free governance (done, plan assumption corrected)
- **FALSIFIED:** `eventcatalog lint` does NOT exist in the free CLI (verified against the installed binary: only dev/build/preview/start/export/generate/federate).
- **Found the real free tooling:** `@eventcatalog/linter` v1.1.20 rides WITH `@eventcatalog/core` (`eventcatalog-linter` CLI) — frontmatter + reference validation, free.
- Wired BOTH free layers: strict link validation (`linkValidation: { onBrokenLinks: 'error', onBrokenAnchors: 'error' }` in the hub config — verified rc=0 on the 123-page rebuild) + a CI lint step over the merged tree with a curated `.eventcatalogrc.js` (schema/dup/unknown-field = error; the two documented exporter-format gaps = warn). Verified rc=0 on the merged tree (0 errors / 32 warnings, all the documented classes).

### T10 — Owners/teams (done)
- Verified API availability across published versions: `AddUser`/`ServiceOwners` exist in v4.5.0 AND bank-sync's pinned v4.3.0; `simple.WithServiceOwners` did NOT exist anywhere published.
- **Deliberately avoided cutting catalog/v4.6.0** (28 files of other sessions' unreleased catalog/ work would ride the tag — not mine to vouch for). Sources use the published inner-builder API instead.
- go-cqrs-lite: added `simple.WithServiceOwners` for the NEXT release (api-surface gate caught it → `docs/api_surface.txt` regenerated; 7497 exports). Pushed `49b422849`.
- cqrs-htmx demo + bank-sync: owner-of-record `lars` registered (user + `ServiceOwners`), each verified **standalone (`GOWORK=off`) against its pinned published version** — owners frontmatter + `users/lars.mdx` in both exports. Pushed `70e3e845` (cqrs-htmx) and `84334894` (bank-sync, via daemon).
- Hub rebuilt from fresh GitHub clones with owners: both services carry them, llms.txt present.

### T11 — llms.txt + MCP (done, honest finding)
- `llms.txt` verified live and complete (both services listed; Gatus-checked since T5).
- **The official EventCatalog MCP server is Scale-license-gated** (verified against upstream docs 2026-09-23: BOTH the built-in SSR server and the standalone `@eventcatalog/mcp-server` list a Scale license as prerequisite). License-free hub → **no MCP wiring by design**; README "AI access" section documents llms.txt/schemas.txt as THE agent surface + the revisit trigger.

### T12 — Federation GO/NO-GO (done)
- All four §7 triggers evaluated: un-fired (2 sources < 3, zero silent cross-source breaks, single maintainer, no pinning need, no federation-only upstream feature). **NO-GO, reviewed 2026-09-23**, documented in the hub README.

### T13 — Upstream exporter options (routed per cross-repo rule)
- New TODO_LIST.md section in go-cqrs-lite: `catalog.index.json` emission (M), `skip-bootstrap-files` option (S), + the linter/ref-format finding (unversioned service dirs vs linter ref resolution; message-level owners missing) with re-arm conditions. Section index updated. Pushed `6170c4e76`.

---

## b) PARTIALLY DONE

- **T4 (carried):** CI code + local E2E validation complete (prior session); the sudo-gated Forgejo setup (token → mirror → secret → first CI run) remains OWNER-gated. This session improved `setup-forgejo.sh` (mirror-sync step) and hardened the workflow (lint step).
- **T5/T6:** all CODE done and eval-verified; the deploy + live smoke (plan §5.7) is owner-gated (see §g).

## c) NOT STARTED

- **T14:** architecture change-detection evaluation + PR-gate recipe.
- **T15:** `docs/services/architecture-catalog.md` runbook, SystemNix AGENTS.md section, plan §9 verification-matrix annotation, `docs/todo/services.md` updates.
- **Mermaid §6 render-validation** of the plan's architecture graph.
- **Scratch cleanup decision** for `/mnt/buildcache/scratch/eventcatalog-t0/` (handoff says keep until hub live).

## d) TOTALLY FUCKED UP (and fixed) — lessons

1. **Bare-module shape error:** wrote `architecture-catalog.nix` as a bare NixOS module first — the EXACT AGENTS.md "silently contributes nothing" class. Caught by eval, rewritten as a flake-parts wrapper.
2. **Nix list/function-application parse bug (new, empirically proven):** `serviceOneshotDefaults { }` as a bare element inside a `lib.mkMerge [...]` list parses as **TWO elements** (the function, then `{ }`) — NOT application. `nix eval --expr` proof: `[ f { } f { } ]` has length 4. Fix: parenthesize `(serviceOneshotDefaults { })`. Cost ~4 eval cycles; the error message (`<function, args: {Restart?, RestartSec?}>`) was technically-true but misleading — the failing definition looked already-fixed in the store copy.
3. **Stray 8.1MB binary in git history:** my `go build ./cmd/catalog-export` (run from `catalog/`) dropped the binary at `catalog/catalog-export`; the daemon heuristic-committed it alongside my staged files. Purged from unpushed history via `write-tree` + `commit-tree` + `update-ref` squash (no reset); history-rewrite checklist run (ancestor OK, zero stale refs). Rule reinforced: build with `-o /tmp/...` in foreign repos.
4. **Documented-API hallucination caught:** my first versioning-guidance draft cited `versionEvent` — grep proved it doesn't exist; corrected to the real `Changelog []Change{Version,Date,Summary}` shape before committing.
5. **Incidental go.mod damage:** a `GOWORK=off go run` in bank-sync rewrote the `go` directive `1.27.1` → `1.27` (toolchain normalization). Caught via git status, restored.
6. **`.eventcatalogrc.js` module-system trap:** hub package.json is `"type": "module"` — a `module.exports` rc file silently fails config load (warning printed at log top, easy to miss; ignorePatterns appeared dead). Fix: `export default`. Diagnosed by reading the linter's config loader in `node_modules`.
7. **Pre-commit environment failures (not my breakage, documented class):** cqrs-htmx hook blocked with 21 failed BuildFlow steps (golangci-lint `tool.execution_failed` loops in EVERY module; doctor: system go 1.26.7 < floor 1.27.1). Used the repo-AGENTS-sanctioned `--no-verify` with independently verified content (vet+test+live export) and step names in the message. bank-sync hit 2 similar steps; the daemon committed the (verified) change there anyway.
8. **agentic_fetch backend token expired** mid-T11 research → switched to plain `fetch` (worked).

## e) WHAT WE SHOULD IMPROVE (structural)

1. **Agent-shell deny-list friction is the #1 drag:** `sudo`/`systemctl`/`curl`/`ssh` blocked → every privileged step becomes a staged owner script. If this stance stays, write the owner script FIRST for any sudo-needing task (worked well this session).
2. **jq + relative paths still broken in the sandbox** (known): used absolute paths / python3 everywhere; consider fixing the sandbox shim.
3. **The daemon commits agent build artifacts:** an allowlist-style daemon (ignore untracked binaries >1MB, or ignore what `git status` showed as ignored-after-the-fact) would have prevented §d3.
4. **Eval-error definitions should print the offending LINE:** the `mkMerge` function-element error names the file but not the line — Nix-side, but worth remembering the `--show-trace` + grep-the-store-copy drill.
5. **Flake source snapshotting:** after ANY module edit, `git add` before re-evaluating (the store copy lags unstaged edits) — bit me once this session.
6. **System go 1.26.7 vs fleet floor 1.27.1** keeps breaking every BuildFlow pre-commit fleet-wide (deterministic, documented) — a pinned go 1.27 on PATH or in the devShell default would kill a whole failure class.

## f) NEXT — up to 50 items (priority order)

**Owner-gated (the critical path to LIVE):**
1. Run `sudo bash ~/projects/eventcatalog-hub/scripts/setup-forgejo.sh` (mints token, creates hub mirror, enables Actions, stores GIT_CLONE_TOKEN, mirror-syncs sources, dispatches first run).
2. Watch `https://forgejo.home.lan/lars/eventcatalog-hub/actions` — expect green + `dist` branch. First-run watch-list: nix-shell availability for the runner user, jq on the runner, GITHUB_TOKEN git-push (PUSH_TOKEN fallback documented in the workflow).
3. Paste the minted sync token into sops: `SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops platforms/nixos/secrets/architecture-catalog.yaml` → replace PLACEHOLDER (value format `ARCHITECTURE_CATALOG_SYNC_TOKEN=<token>`).
4. Deploy: `nix run .#deploy` (decide batching with parallel-session changes — §g Q2), then `nix run .#post-deploy-check` (§15 warns until first sync lands).
5. Verify live: Gatus "Architecture Catalog" green, `systemctl start architecture-catalog-sync` converges the first generation immediately.

**Remaining plan tasks (code-side, not started):**
6. T14: evaluate `architecture-change-detection` (EventCatalog governance docs) for the hub; write the PR-gate recipe (diff two exports in CI, fail on breaking message changes).
7. T15: write `docs/services/architecture-catalog.md` runbook (sync flow, token rotation, adding a source, freshness semantics, PLACEHOLDER-inert behavior, rollback = previous generation dir).
8. T15: SystemNix AGENTS.md section for the catalog (module + registry + hub CI + owner runbook pointer).
9. T15: annotate plan §9 verification matrix with what actually got verified (link this report).
10. T15: update `docs/todo/services.md` (harvest the plan's remaining tail into the domain library per the TODO-system rules).
11. Render-validate the plan's mermaid §6 graph (headless render, `scripts/verify-html-diagrams.sh`).
12. Scratch cleanup decision: `/mnt/buildcache/scratch/eventcatalog-t0/` (keep until hub live per handoff).
13. Commit + push the SystemNix tree (module + DNS + caddy/integration extensions + sops + smoke §15 + configuration.nix enable) — currently staged/unstaged for the owner's deploy.

**Follow-ups discovered this session:**
14. go-cqrs-lite: cut catalog/v4.6.0 when appropriate (WithServiceOwners + 28 unreleased files from other sessions — needs their owners' blessing) → then flip the cqrs-htmx demo + hub docs to the simple option.
15. go-cqrs-lite exporter (routed, TODO_LIST): `catalog.index.json` emission — unblocks T14 properly.
16. go-cqrs-lite exporter (routed): `skip-bootstrap-files` option — removes the hub's first-wins merge reliance.
17. go-cqrs-lite exporter (routed): fix ref-format (versioned dirs) + message/container owners → re-arm the two `warn` linter rules in the hub rc to `error`.
18. Onboard source #3+ as services adopt the convention (PMA, discordsync, CV are candidates — CV has the richest event surface).
19. Add `architecture-catalog` VM test (tests/test-architecture-catalog.nix): PLACEHOLDER skip path, fake-dist sync converge, atomic swap, keep-N pruning, collector fail-closed — the module currently has NO VM test (house norm is one per service).
20. SigNoz dashboard tile for catalog freshness (stamp_age trend) once live.
21. Consider `docs/services/` cross-link from the PapDashboard tile description once URL is live-proven.
22. Hub CI: add a second workflow_dispatch input or manual "rebuild without publish" mode for experimenting with new sources.
23. Revisit MCP wiring if upstream frees the MCP server (README trigger documented).
24. Federate GO/NO-GO re-review when the §7 triggers fire (README section is the standing record).

## g) QUESTIONS (cannot figure out myself)

1. **Owner-gated execution:** will YOU run `sudo bash ~/projects/eventcatalog-hub/scripts/setup-forgejo.sh` now (≈2 min, idempotent, no token values printed), or should sudo be re-enabled for agent sessions so I drive steps 1–5 of §f myself?
2. **Deploy batching:** the SystemNix tree carries parallel-session work beyond mine (e.g. `flake.lock` + parts of `configuration.nix` were already modified at session start; possibly `signoz.nix`-era changes). Deploy T5/T6 on top of the current tree as-is, or do you want to review/split the tree first? (I cannot judge other sessions' deploy-readiness.)
3. **catalog/v4.6.0 release timing:** cutting it would publish 28 files of other sessions' unreleased catalog/ work alongside my `WithServiceOwners` — I deliberately did NOT tag. Want a release now (I'd verify the full catalog module first), or does the next planned release train carry it?

---

**Repo state summary:** SystemNix (staged/unstaged: module + DNS + caddy/integration/sops/config + smoke §15 — uncommitted for owner deploy); eventcatalog-hub @ `d88c10b` pushed; cqrs-htmx @ `70e3e845` pushed; go-cqrs-lite @ `6170c4e76` pushed; bank-sync @ `84334894` pushed.

**Session paused. Waiting for instructions.**
