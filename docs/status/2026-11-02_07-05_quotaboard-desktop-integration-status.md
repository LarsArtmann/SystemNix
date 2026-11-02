# quotaboard → SystemNix desktop integration — full status

**Date:** 2026-11-02, session 03:5x–07:0x
**Scope:** integrate the quotaboard AI-quota dashboard into evo-x2's DankMaterialShell bar with maximal code residency in the quotaboard repo; publish it Forgejo-primary with a private GitHub twin.
**Result:** INTEGRATION COMPLETE AND VERIFIED PRE-DEPLOY; deploy queued behind a parallel-session IO storm.

## a. What landed

### quotaboard (github:LarsArtmann/quotaboard, commits `16df156` + `c18cba9`)

- **`GET /api/quotas`** — machine-readable JSON projection of the same cached snapshots the HTML renders (`internal/dashboard/api.go` + `MountJSONRoute`; `state` ∈ ok/error/unconfigured, windows with tone/percent/resetsAt, unconfigured OMITS the windows key so "no data" can never read as "zero usage"). Two httptest suites.
- **DMS 2.0 plugin** (`dms-plugin/quotaboard/`) — `plugin.json` (id `quotaboard`, schema-validated against the deployed DMS store path's `PLUGINS/plugin-schema.json`) + `QuotaWidget.qml` (curl+JSON.parse poll every 30s, severity-RANKED colors — no color equality in JS —, muted `·` unconfigured / `!` error-color server-down, click opens the dashboard via `Quickshell.execDetached`) + `QuotaSettings.qml`. Every QML symbol verified against the LIVE DMS 2.0 store path (`PluginComponent` contract: `pluginData`/`iconSize`/`textSize`/`pillClickAction`; `qs.DCommon.Widgets.DIcon` exists). `qmllint -I <dms-share> -I <quickshell-qml>` = zero errors.
- **Nix flake** — `nix/packages.nix` (server via `buildGoModule.override { go = pkgs.go_1_27; }` + templ/tailwindcss_4 generated in-build; plugin derivation), `homeModules.quotaboard` = `module.nix` (user systemd service + DMS plugin registration + optional bar placement; dms-paste contract: only ASSIGNS into `programs.dank-material-shell.*`), `nix/checks.nix` (manifest structural gate), treefmt check — `nix flake check` all green. Module eval proven in isolation (stubbed DMS option tree, dms-paste evalModule pattern): unit ✓ plugin ✓ barConfigs ✓ env templating ✓.

### Publishing (Forgejo-primary, media-atlas/pingen-spike precedent)

- Forgejo canonical: `forgejo@evo-x2.home.lan:lars/quotaboard.git` via SSH push-to-create → PRIVATE (anonymous API 404s, `git ls-remote` green).
- GitHub twin: `gh repo create --private` + hand seed-push → PRIVATE (visibility verified via API).
- Remotes: `origin` = forgejo, `github` = mirror — byte-identical pattern to the flipped repos. No `.github/workflows` in the repo → repo-scoped sync PAT suffices. `canonicalRepos += "quotaboard"` → phase 5 attaches the 8h + sync_on_commit push mirror on the next deploy.

### SystemNix (HEAD `fa62a316d` + daemon batches `298cfbd1d`/`1e7ad4389`/`b663efa04`)

- flake input `quotaboard` (PRIVATE → `git+ssh` form, `?ref=refs/heads/master` float) + infra-follows (nixpkgs, treefmt-nix) + expected-locks row (locked `c18cba99a65e`).
- `lib/ports.nix`: `quotaboard = 8791` (the app's own default — registry becomes owner of record).
- `desktop/quickshell.nix`: imports `quotaboard.homeModules.quotaboard`, enables `services.quotaboard { port = ports.quotaboard; dmsPlugin.placeInBar = true; }`.
- Docs: desktop.md gotcha bullet + CHANGELOG entry.

## b. Verification receipts

- **Dual-nixpkgs FOD probe:** vendorHash probed green against TODAY's unstable AND the consumer's pinned `fe13242` (throwaway worktree + `--override-input nixpkgs`) — the attr-existence question (templ/tailwindcss_4/go_1_27 on the old pin) answered empirically, not assumed.
- **evo-x2 toplevel** `nix build …toplevel --keep-going --no-link` → SUCCESS (incl. `quotaboard.service.drv`, home-manager-generation).
- **Rendered artifacts inspected** (green eval ≠ rendered unit): unit text exact (`QUOTABOARD_ADDR=127.0.0.1:8791` from the registry, ExecStart = flake binary, graphical-session.target), HM `dms/plugins/quotaboard/` populated, `plugin_settings.json.quotaboard = {enabled:true, apiUrl:…8791/api/quotas}`, `settings.json.barConfigs[0].rightWidgets` contains `quotaboard` before `controlCenterButton`, and the other 36 declarative settings keys intact (37 total).
- **Runtime smoke of the flake binary:** mock-mode server up, `/api/quotas` JSON verified via fetch (both providers, windows, tones, resets).

## c. Deploy status — BLOCKED, by design

PSI io some avg10 = **92%**, load 112–143, `ld.mold`/`compile`/`golangci-lint` in D-state on `blk_mq_get_tag`: the 2026-10-29-class parallel-session compile storm (a CV/crush session was running its own buildflow battery + an armed PSI-gated deploy watcher of its own). Deploying into that is exactly what the entry gates forbid. A PSI watcher (calm <25% avg10, 30-min budget) is armed; `scripts/deploy.sh` carries the T13 flock guard, so a race with the parallel session's watcher serializes safely — one switch serves both change sets (everything is already in HEAD).

## d. Decisions worth remembering

1. **"my waybar" = the DMS bar.** Waybar is retired on this host (desktop.md: "DMS is the sole shell"); the DMS plugin system is the sanctioned bar-extension surface.
2. **Bar placement is barConfig widget lists**, and the 12 embedded systemnix plugins are installed-but-unplaced (default lists carry only built-ins). quotaboard becomes the FIRST plugin placed declaratively (`placeInBar` → `settings.barConfigs` mkDefault; overrides UI bar customization on rebuild — the standing declarative-settings contract, made explicit in desktop.md).
3. **`buildGoModule { go = …; }` silently does NOT retarget the go-modules FOD** — nixpkgs runs its default `go` (1.26.10) and dies on the 1.27.2 floor under GOTOOLCHAIN=local. The working form is `buildGoModule.override { go = pkgs.go_1_27; }`. Recorded in quotaboard AGENTS.md; proposed for crush-config lessons.md.
4. **Forgejo 404-anonymous = private-exists** (verified via ls-remote) — the cheapest liveness check without a token.
5. Keys stay OUT until the owner provides them: the dashboard + widget render honest "not configured" states; `environmentFile` is the one-option hookup (asked of the owner twice now, 2026-11-02).

## e. Not done / risks

- No live verification of the running service/plugin yet (deploy-gated; all pre-deploy legs green).
- `qmllint` clean ≠ visual correctness; the widget's runtime behavior (JSON parse path, pill layout) gets its first live look post-deploy — journal `component error` + `dms ipc call plugins list` + `settings get barConfigs` are the three checks.
- quotaboard has NO CI (dms-paste had the same gap at extraction; queued below).
- The plugin polls unauthenticated loopback HTTP — fine for a single-user desktop; must NOT gain a vHost.

## f. Follow-ups (self-harvested at authoring time)

1. **Deploy + live-verify quotaboard** → `docs/todo/desktop.md` + `TODO_LIST.md` as [blocked:deploy] (PSI storm at authoring time; checklist in the row).
2. **Wire provider keys via sops + `services.quotaboard.environmentFile`** → [blocked:user] in desktop.md (owner provides `ZAI_API_KEY`/`SYNTHETIC_API_KEY`).
3. **Verify the Forgejo push mirror attached** after the deploy (phase 5) → [ready] row in desktop.md.
4. **quotaboard CI workflow (`nix flake check` + go test)** → lives in the quotaboard repo, noted here for provenance; dms-paste CI sibling.

## g. Storm addendum (08:06) — deploy window did NOT open

The 60-min PSI watcher expired with io some avg10 at 91–98% the whole time (readings 07:01→08:06: 92→94→97%). Load climbed 112 → **288**; by 08:06 DESKTOP processes were blocking on `blk_mq_get_tag` (helium, quickshell-wrapper) alongside fresh `ld.mold`/`go` build batches from parallel sessions, and the 01:04-deploy re-armed **nsfw-classifier is still the known-sick 46%+ CPU eater** (its `[ready]` triage row predates this session). Verdict: freeze-class precursor, owner/stability-runbook territory — this session deliberately did NOT deploy, did NOT kill foreign processes, and left the queue row + staged verification script (`/tmp/qb-post-deploy-verify.sh`, syntax-checked) as the complete handoff. quotaboard master moved to `b2a3490` (docs-only) AFTER the lock pinned `c18cba99a65e` — expected-locks still matches the locked rev, so eval stays green; the next float wave registers the docs rev.
