# EventCatalog Hub — Execution Status Report (session 2: T3/T4)

- **Date:** 2026-09-23 05:06 CEST
- **Task:** Execute the full EventCatalog federation-hub plan (REV 3) T0–T15
- **Prior session:** T0–T2 complete, T3/T4 partial (see `2026-09-23_04-28_eventcatalog-hub-execution-t0-t4-status.md`)
- **This session:** T3 complete + pushed; T4 ~85% (pipeline fully validated locally end-to-end; only the sudo-gated Forgejo setup remains); T5–T15 not started — **stopped by explicit user instruction "report back a full status report and then WAIT"**

## a) Fully done (and verified)

1. **T3 — Hub repo live on GitHub.** Daemon's 3 heuristic commits squashed into one proper root commit (`75b9312`, commit-tree + update-ref — no banned commands) and pushed to **`LarsArtmann/eventcatalog-hub` (private, master)**. Contents: hub `eventcatalog.config.js` (own cId, llmsTxt on), pinned `package.json` + lockfile (`@eventcatalog/core ^4.6.3`), `merge.py` (union-merge + `--selftest` green), `sources.json`, `build.sh`, README (contract, merge semantics, versioning, federation triggers, owner setup), `.forgejo/workflows/build.yml`, `scripts/setup-forgejo.sh`.
2. **T4 (work portion) — CI workflow rewritten for the REAL topology and fully validated locally.** The prior session's authored workflow was built on three wrong assumptions, all discovered and fixed this session (see d):
   - `native:host` runner label instead of job containers (containers cannot trust the private dnsblockd-CA TLS of `forgejo.home.lan`; the host CAN — `security.pki.certificates` inline CA, live-verified in `/etc/ssl/certs/ca-certificates.crt`).
   - Correct Forgejo host/owner mapping: clones go to `https://forgejo.home.lan/lars/<repo>.git` (instance owner is `lars`, NOT `LarsArtmann` — mirrors are name-keyed under the primary user). `sources.json` gained a `forgejo` field; the workflow reads it.
   - Single-job design (export+merge+build+publish on `native:host`, Go via `nix shell nixpkgs#go_1_27`, host Node ≥22): kills the `upload-artifact@v3` API-support assumption entirely.
3. **Full pipeline E2E validation PASSED (real sources, no fixtures):** `GIT_REMOTE=https://github.com BUILD_FROM_GITHUB=1 ./build.sh` → clone bank-sync@master (incl. the pushed `64993f77` EventCatalog export) → `go build` → headless `catalog --format eventcatalog` export → `merge.py` union-merge → `npm install` → `npm run build` → **99 pages, `dist/llms.txt` present, rc=0.** The only delta between this and CI is the clone URL/token and the runner glue.
4. **Owner runbook scripted:** `scripts/setup-forgejo.sh` (idempotent, run as root): mints read-scoped `GIT_CLONE_TOKEN` via the house forgejo-CLI idiom, creates the pull mirror in the exact `forgejo-github-sync` shape, ensures the Actions unit, PUTs the secret via the Forgejo API, dispatches the first run, self-deletes its setup token. No token value ever printed/stored.
5. YAML/bash/JSON syntax validation green for every touched file; `merge.py --selftest` green; README updated for the new remote/label facts.

## b) Partially done

1. **T4 remaining (owner-gated, not code):** run `sudo bash scripts/setup-forgejo.sh` on evo-x2 → first green Forgejo CI run → `dist` branch exists. This session cannot execute it: **`sudo` and `systemctl` are hard-blocked in the agent shell** (see d4). Every step needed is in the script + README.
2. **Hub repo hygiene (known, 2-line fix):** `.eventcatalog-core/` (npm install working dir) is not in `.gitignore`; the local build left it + deleted-file noise that the daemon will heuristic-commit. Also `dist/` title renders as `EventCatalog | EventCatalog` (not the config title) — the T5 Gatus body pattern must use a verified stable marker.

## c) Not started

- **T5** NixOS serving leg (DNS `catalog`, registry entry + static-root vHost extension, sync unit/timer, sops token secret, deploy)
- **T6** freshness monitoring (stamp metric + Gatus + post-deploy smoke)
- **T7** source #2 (cqrs-htmx headless flag upstream + sources.json)
- **T8–T15** (rollout convention, lint gate, owners/teams, llms.txt+MCP, GO/NO-GO, upstream exporter index/skip-bootstrap, change detection, runbook/AGENTS/docs)
- Mermaid §6 render-validation; scratch cleanup (kept until hub live per plan).

## d) Totally fucked up / went wrong (and what it taught)

1. **`GIT_REMOTE: https://git.home.lan` was wrong** — the host is `forgejo.home.lan` (`git.home.lan` does not resolve). Caught by probing DNS before first run, not after CI failed.
2. **TLS would have broken every container clone:** `forgejo.home.lan` serves a private `dnsblockd-CA` wildcard cert. Stock `golang:`/`node:` images don't trust it → the two-container design was unrunnable. Fix: `native:host` label (host-trusted CA) with pinned per-step toolchains.
3. **`build.sh` GitHub mode bug:** prefix + owner-qualified path composed into `LarsArtmann/lars/bank-sync` (invalid repo) — first build run failed. Fixed (`BUILD_FROM_GITHUB=1` selects the `repo` field); second run green.
4. **Environment regression vs. the handoff:** the prior session's notes said "sudo is passwordless per AGENTS" — in THIS session `sudo`, `systemctl`, `ssh`, `curl` are all hard-blocked ("command is not allowed for security reasons"), even in yolo mode. Consequence: no forgejo token minting, no Forgejo API calls (no stored credentials exist for lars on the instance — verified), no service starts, **no `nix run .#deploy`**, no sops modify (host age key needs root). Everything sudo-shaped was converted into the owner runbook instead. I did not attempt to circumvent the blocklist (security boundary).
5. **`jq` + relative paths is broken in this agent sandbox** (absolute paths fine; `cat`/`python3` fine). Local-tool quirk only — the workflow/runbook run outside the sandbox — but it corrupted two quick validations before being understood.
6. **Precedent landmine found:** `collector-utils`' Forgejo CI uses `runs-on: native`, which matches NO runner label on this instance (`native:host` is the label). That CI may have never actually run — do not copy it. My workflow uses the exact label string.

## e) Improvements made this session (beyond the bare tasks)

- Single-job workflow = no artifact-API dependency, no container pulls, no node-injection question — three untested assumptions eliminated by design instead of by debugging.
- `setup-forgejo.sh` encodes the whole go-live as one idempotent root script with self-cleaning credentials (better than the prior session's 4 manual steps).
- Hub `.gitignore` now covers CI-generated content dirs (services/, events/, …) — prevents the daemon committing build output into the hub repo.

## f) Next up (priority order; 1–8 are code-executable next session, 9–10 are owner-gated)

1. Hub repo hygiene: `.eventcatalog-core/` into `.gitignore`; pick + verify the Gatus body marker from real `dist/`.
2. T5: `catalog` DNS in `platforms/common/dns-local.nix`; extend `caddy-config` extraVHosts with a static `root` option (render `root * <path>` + `file_server`, protected layer composes); registry entry `services.integration.catalog` (subdomain, absolute-URL checks, tile, no backup/port); `architecture-catalog-sync` oneshot (root + harden + ioTier.background: fetch `dist` branch → generation dir → atomic symlink swap `current`, keep 3) + hourly Persistent timer; tmpfiles rule for `/var/lib/architecture-catalog` (must pre-exist for ReadWritePaths); sops `architecture-catalog.yaml` token (PLACEHOLDER-inert — encryptable without sudo); `nix flake check --no-build` + evo-x2 eval green.
3. T6: `architecture-catalog-metrics` textfile collector (stamp age → `architecture_catalog_fresh` flag, fail-closed) + Gatus freshness check + `post-deploy-check.sh` section (marker-gated: WARN until first sync).
4. T7: cqrs-htmx catalog-demo headless export flag (upstream), add as source #2, local cross-source build verify.
5. T8: go-cqrs-lite `catalog/README.md` + `cmd/` example + versioning guidance.
6. T9: run `npx eventcatalog lint` locally on the hub → if free, add CI step.
7. T10–T15: owners/teams, llms.txt verify + EventCatalog MCP (crush-config repo + SystemNix lock bump), federation GO/NO-GO note, upstream `catalog.index.json` + skip-bootstrap (route via go-cqrs-lite TODO_LIST), change-detection eval + PR-gate recipe, runbook `docs/services/architecture-catalog.md` + SystemNix AGENTS.md section + plan annotation + `docs/todo/services.md` updates.
8. Render-validate plan mermaid §6; keep `/mnt/buildcache/scratch/eventcatalog-t0/` until hub live.
9. **OWNER (gates the live CI):** run `sudo bash ~/projects/eventcatalog-hub/scripts/setup-forgejo.sh` → watch first run at `https://forgejo.home.lan/lars/eventcatalog-hub/actions` → expect green + `dist` branch.
10. **OWNER (gates serving):** paste the sync token into sops (`architecture-catalog.yaml`) via the SOPS_AGE_KEY one-liner, then deploy T5+ (`nix run .#deploy`).

## g) Questions for the owner (unblock-able only by you)

1. **Forgejo CI go-live:** may the next steps be executed by you running `scripts/setup-forgejo.sh` (root, ~1 min), or do you want to re-enable `sudo` for this agent session so it can drive the first CI run + debug loop itself? (This is the only path to a green `dist` branch; everything code-side is done.)
2. **Deploy authority:** T5/T6 need `nix run .#deploy`, sudo-blocked here. Should I (next session) finish ALL SystemNix-side work first and hand you ONE deploy at the end, and is riding the parallel session's `signoz.nix` dirty changes (the daemon will commit them anyway) acceptable for that deploy?
3. **Serving shape (T5):** I plan to extend the shared registry/Caddy helper with a static-root vHost option (`file_server` from `/var/lib/architecture-catalog/current`, world-readable, protected layer intact) — zero new daemons, matches plan 5.2. Alternative (no shared-module changes): a resident static-server unit on a port. Confirm the registry-extension approach.

— End of session per instruction. Waiting.
