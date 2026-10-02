# Forgejo — GitHub Mirror Sync Runbook

Self-hosted Forgejo (`https://forgejo.home.lan`, internal `http://localhost:3000`) mirrors every
GitHub repo owned by `LarsArtmann` as **pull mirrors** — a read-only backup with GitHub-outage
immunity for flake inputs. This runbook covers the sync model, reconcile semantics, monitoring,
and break-glass operations. Full audit narrative: `docs/status/archived/2026-09-18_07-43_forgejo-mirror-sync-audit-and-fixes.md`.

## Sync model (who creates what)

| Surface                                                | Cadence                                                                                                    | What it does                                                                                                                                                                                                                                                                 |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `forgejo-github-sync.timer` → `forgejo-mirror-github`  | 6h + boot 5m + every deploy (`deploy.sh` starts it `--no-block`)                                           | Lists `GET /user/repos?visibility=all&affiliation=owner` (owned, public+private+forks) **plus every org** (`/user/orgs` → `/orgs/<org>/repos?type=all`, owner directive 2026-10-02) and creates any MISSING mirror via `POST /repos/migrate` — org repos under same-named forgejo orgs (org create-if-missing, org uid resolved per migrate). Never touches existing mirrors. Fails LOUD if GitHub answers a non-array (rate limit/auth) on ANY listing. |
| `forgejo-reconcile-mirrors` (2nd ExecStart, same unit) | same                                                                                                       | Heals renames, classifies transfers/deletions (below) — owner/name PAIR-keyed across the user + org namespaces (out-of-scope namespaces like `starred` are skipped + counted). Publishes `forgejo_mirror_*` metrics (+ `forgejo_mirror_org_mirrors`). Pending-deletes + known-stale-pairs files switched to pairs 2026-10-02 (known-stale.txt stays flat-named for the mirror-health collector). |
| `forgejo-ensure-repos.timer` → `forgejo-ensure-repos`  | COLLAPSED 2026-10-02 (`enable = false`)                                                                      | Was a declarative 2-repo daily belt-and-suspenders (dnsblockd, BuildFlow); redundant since the 2026-09-18 general listing and retired with the org-inclusive extension. |
| `forgejo-mirror-starred`                               | manual only                                                                                                | Starred repos into the `starred` org — OUT of reconcile scope (the reconcile namespace whitelist skips it automatically). |
| Forgejo internal pull loop                             | `mirror.DEFAULT_INTERVAL` 8h via 30m `cron.update_mirrors` (PULL_LIMIT 50, oldest-`updated_unix` rotation) | The actual `git fetch` per mirror.                                                                                                                                                                                                                                           |

Auth: `forgejo-sync.env` (sops template; `FORGEJO_TOKEN` from `forgejo-generate-token.service`,
`GITHUB_TOKEN`, `GITHUB_USER`). The unit runs as `lars` with `ProtectHome=false` (gh CLI fallback auth).

## Reconcile semantics (renames / transfers / deletions)

Forgejo v15 sets `http.followRedirects=false` on pull mirrors (SSRF hardening) and GitHub answers
moved repos with 301 — a rename/transfer FREEZES the mirror silently, and there is **no API to
update a pull mirror's remote address** (verified against the deployed swagger). The reconcile
script probes stale names (mirror exists in Forgejo but not in the GitHub listing) via
`gh api repos/<user>/<name>` redirect-following:

- **Renamed within the account** → stale mirror deleted only when (a) the canonical-named mirror
  already exists, (b) the verdict repeated on the previous run (state file
  `~/.local/state/forgejo-mirror-reconcile/pending-deletes.txt` — two-run confirmation), and
  (c) a final `.mirror == true` re-check. Otherwise: recorded, retried next run.
- **Transferred away** (e.g. `Artmann-Minecraft`) → REPORT ONLY, kept frozen. Owner decision
  pending: delete or re-mirror into a Forgejo org namespace.
- **Upstream deleted** → REPORT ONLY. The Forgejo copy is the **only remaining copy** (32 such
  archives at audit) — never clean these up casually.
- **Probe failure** → `gh api` exit code + owner/name shape check decide (404-JSON bodies on
  stdout are NOT trusted — live bug 2026-09-18, fixed same day). A network blip can
  misclassify as archived for one report-only run; the next run heals.

## Monitoring

- Gatus **"Forgejo Mirror Sync"**: `system_forgejo_mirror_*` (system-health; forgejo's own sync
  queue health — stalled/erroring/scrape errors).
- Gatus **"Forgejo Mirror Reconcile"**: `forgejo_mirror_*` textfile metrics
  (`forgejo_mirror_reconcile.prom`, published by the reconcile script on every COMPLETED run).
  Absent metrics = the unit has never completed a run. Red until the first post-2026-09-18-PM
  deploy's run.
- Unit failure: `forgejo-github-sync` in `system-health` extraMonitoredServices + OnFailure
  (Discord).
- Live counts: `curl -s localhost:9100/metrics | grep forgejo_mirror_` (after first completed run).

## Operational facts

- **First mass migration (private repos): DONE 2026-09-18 09:42–10:09** — 349 repos processed,
  225 mirrors created, 0 failed, 27 min wall. Private coverage went from 2/200+ to full.
- Storage: mirrors live under `/var/lib/forgejo` (root fs, btrbk-snapshotted forever pool-side).
  Size measurement needs the forgejo user (`sudo -u forgejo du -sh /var/lib/forgejo`).
- Transient `pull mirror failed to meet migration URL requirements: migration/cloning from
  'github.com' is not allowed` in the forgejo journal = DNS blip during the per-sync allowlist
  recheck — self-heals, no action.
- `commit-graph.lock` warnings on golangci-lint / DynamicMinecraftNetwork mirrors: stale lock
  files in bare repos; cosmetic. Cleanup: remove
  `/var/lib/forgejo/repositories/lars/<name>.git/objects/info/commit-graph.lock` as forgejo user.

## Break-glass

- **Force a sync now**: `sudo systemctl start forgejo-github-sync.service` (converged runs take
  minutes; watch `journalctl -u forgejo-github-sync -f`).
- **Stop all mirroring**: `sudo systemctl disable --now forgejo-github-sync.timer` (the Forgejo
  internal 8h pulls continue for existing mirrors — set `mirror.DEFAULT_INTERVAL` or stop forgejo
  to halt those).
- **Delete a wrong mirror**: `curl -X DELETE -H "Authorization: token $FORGEJO_TOKEN"
  http://localhost:3000/api/v1/repos/lars/<name>` (or the web UI). The next sync run recreates it
  only if it still exists on GitHub under the same name.
- **Re-mirror at a new address** (after a rename you want to follow manually): delete the stale
  mirror; the mirror script creates the new-name one on the next run automatically.

## Staged-primary capability (Phase 1, shipped INERT 2026-09-18)

Plan: `docs/planning/2026-09-18_16-44_FORGEJO-PRIMARY-STAGED-FOUNDATION.md`. Everything in this
section exists in code + fixture tests but is dormant until the G1/G2 owner gates deploy it.

### Canonical repos + push mirrors (`services.forgejo.canonicalRepos`)

- Default `[]` — the sync unit's third phase (`forgejo-push-mirror`) is absent entirely.
- A listed repo (native, `mirror == false`) gets a GitHub **push mirror** attached idempotently:
  `interval 8h` + `sync_on_commit` (the interval field is mandatory — the pre-2026-09-18 code
  omitted it and every POST 400'd; the fixture check asserts the payload carries it).
- The script REFUSES repos still marked pull-mirror (a push mirror on a pull mirror is incoherent
  — the next pull clobbers forgejo-side commits). Flip first.
- Auth: the PAT from `forgejo-sync.env` is stored by forgejo as the push remote credential.

### Flipping a repo to native (`forgejo-flip@<name>`)

```bash
sudo systemctl start forgejo-flip-check@<name>.service   # dry-run: preconditions + plan
journalctl -u forgejo-flip-check@<name>                  # read the plan
sudo systemctl start forgejo-flip@<name>.service         # EXECUTE (OnFailure paged)
```

What it does: DELETE the disposable mirror → `POST /repos/migrate` with `mirror:false` + FULL
import (issues, PRs, labels, milestones, releases, wiki, LFS) → verify (native flag, default
branch, issue count) → attach the push mirror → verify listed. Refuses: non-mirror repos
(primary data!), pending reconcile verdicts, starred-org repos, repos missing on GitHub.
**Mid-flip failure recovery** (migrate fails after the delete): re-run the flip, or
`forgejo-mirror-github` recreates the mirror — GitHub never lost anything.

**Lossiness of the one-time import** (plan F35): reactions, some review-thread metadata,
cross-repo references, and GitHub-only features (projects, insights) do not transfer. Issue/PR
bodies, comments, labels, milestones, releases, and wiki DO. Reactions/PR-review edge cases are
acceptable for the sovereignty goal; if a repo matters historically, snapshot its GitHub state
before flipping.

### Dead-mirror detection (`forgejo-mirror-health`, 5-min timer)

Detects mirrors whose syncs FAIL persistently (the 12-day redirect-freeze class). Signal:
forgejo's `notice` table — every FAILED pull-mirror sync writes a Type=1 row
(`services/mirror/mirror_pull.go` → `CreateRepositoryNotice`), independent of the TouchMirror
bug that makes `mirror_updated` advance on failures (verified against v15.0.8 source AND live
data: all 385 mirrors incl. the frozen ones carry fresh `mirror_updated`). Known-stale names
(renamed/transferred/upstream-deleted — they 404 forever by design) are subtracted via the
reconcile script's `~/.local/state/forgejo-mirror-reconcile/known-stale.txt` (published atomically
every completed run). Gatus **"Forgejo Dead Mirror Candidates"** fails closed (absent metric =
scrape error = red). Expect ONE red cycle right after the first deploy carrying this batch (the
stale file does not exist until the first reconcile run completes — deploy.sh's post-switch sync
start publishes it within minutes).

Note: the notices table accumulates one row per failed sync (the frozen mirrors generate
~1.6k rows/day). Admin UI → Site Administration → Monitor → Notices has a purge; harmless until
then, but worth a periodic look.

### Census (`forgejo-census`)

`sudo systemctl start forgejo-census && journalctl -u forgejo-census` — native-vs-mirror split
per owner (the flip-rollout tracking numbers; census results land here at gate G2).

### Storage (G1 flip STAGED 2026-09-30)

`services.forgejo.dedicatedSubvolume` (= true since 2026-09-30, staged) mounts the Samsung-TLC
subvol `hot/forgejo` AT `/var/lib/forgejo` (Set-B: own 8h btrbk leg to
`/mnt/pool/backups/forgejo-subvol`, freshness Gatus `forgejo_subvol_backup_fresh`). Migration
runbook: `scripts/migrate-forgejo-subvol.sh` header (prepare → build → finalize → deploy; abort
path included). **Early-deploy safety:** the family condition-gates on the `.subvol-migrated`
marker that `finalize` writes INTO the subvol — a deploy landing before `finalize` leaves
forgejo DOWN (loud, Gatus), never minting fresh state on an empty/stale subvol. deploy.sh
restarts `forgejo-subvol-bootstrap` (is-active-gated, indirect unit) so bootstrap fixes converge.
Until the window runs, storage effectively stays on the QLC root (family down after the first
flipped deploy).

## Themes / UI (Catppuccin, 2026-09-23)

**Architecture:** delta themes in `modules/nixos/services/_forgejo-themes/` — each file
`@import`s the upstream `theme-forgejo-{dark,light,auto}.css` (STABLE unhashed filenames in the
package data output; verified v15.0.9) and overrides CSS variables only. `forgejoThemes`
(forgejo.nix) maps filename → source file; tmpfiles `L+` symlinks install into
`/var/lib/forgejo/custom/public/assets/css/` on every activation (forgejo serves custom assets
over built-ins). `ui.DEFAULT_THEME = "catppuccin-auto"`; picker offers catppuccin trio + forgejo
trio (arc-green removed: never shipped in v15, 404'd in the picker).

**Eval-time audit:** every `ui.THEMES` entry must resolve to a backing `theme-<name>.css`
(custom: `forgejoThemes` keys; upstream: the declared `upstreamThemeNames` list) or the
tmpfiles-rules eval throws naming the dead entry; `ui.DEFAULT_THEME` must be listed. Negative
probe (throwaway expr, no tree mutation):

```bash
nix eval --impure --expr 'let f = builtins.getFlake (toString /home/lars/projects/SystemNix);
  lib = f.inputs.nixpkgs.legacyPackages.x86_64-linux.lib;
  sys = f.nixosConfigurations.evo-x2.extendModules { modules = [ {
    services.forgejo.settings.ui.THEMES = lib.mkForce "catppuccin-auto,arc-green"; } ]; };
  in builtins.length sys.config.systemd.tmpfiles.rules'
# → error: forgejo theme audit: ui.THEMES entries with no backing theme-<name>.css: arc-green ...
```

**Auto-theme dark-mode cascade trap (hit live 2026-09-30, fixed same day):** `@media
(prefers-color-scheme: dark)` grants NO cascade priority — document order wins at equal
specificity, so ANY variable the auto delta's LIGHT `:root` block sets that its DARK block does
NOT re-declare shadows upstream's dark-block value in dark mode (live: delta-light's
`--color-body: #f7f8fc` sat after the imported upstream file and beat its `var(--steel-800)`
→ near-white page body under steel-text = the washed-out half-dark look). The explicit
catppuccin-mocha/latte deltas are immune (single override block, no opposing scheme block).
**Rule:** every var added to the auto delta's light block must be re-pinned in its dark block;
verify with the shadowed-set diff (delta-light ∩ upstream-dark − delta-dark must be empty),
not by eye.

**Adding a theme:** drop a delta css in `_forgejo-themes/`, add it to `forgejoThemes`, add the
name to the `ui.THEMES` CSV, deploy. **Package-bump checklist:** re-verify `upstreamThemeNames`
against the new package's `data/public/assets/css/` (upstream renamed theme files → themes
degrade to base + overrides, visible not fatal). Post-deploy smoke (post-deploy-check.sh) pins:
theme asset 200 + `@import`, `data-theme="catppuccin-auto"`, title slogan (`APP_SLOGAN` renders
in every page title), meta description (`"ui.meta"` quoted flat section key: `settings` is
2-level, a 3-level `ui.meta.DESCRIPTION` fails eval). Settings changes restart forgejo via the
unit's preStart interpolation of the generated app.ini (no restartTriggers needed). Users who
saved a personal theme keep it (account preference beats DEFAULT_THEME).

**Phase 2 (owner-gated):** custom logo/favicon via `custom/public/assets/img/logo.svg` +
`favicon.svg` through the same tmpfiles pattern.

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### Forgejo GitHub Mirror Sync (repo backup mirror, audited + fixed 2026-09-18)

**How the sync works (2 create-only surfaces + forgejo's internal pull loop):** `forgejo-github-sync.timer` (6h + boot 5m) runs `forgejo-mirror-github` (lists GitHub repos — owned + ALL orgs since 2026-10-02, org repos mirrored into same-named forgejo orgs — and creates any MISSING Forgejo pull mirror via `POST /repos/migrate`, never touches existing ones) and `forgejo-reconcile-mirrors` as its second ExecStart (owner/name pair-keyed, org namespaces included, `starred` org out-of-scope); `forgejo-ensure-repos` was COLLAPSED 2026-10-02 (redundant daily declarative list); `forgejo-mirror-starred` mirrors starred repos into the `starred` org (manual). Forgejo itself pulls every mirror every 8h (`mirror.DEFAULT_INTERVAL`) via the 30m `cron.update_mirrors` (PULL/PUSH_LIMIT 50, `ORDER BY updated_unix ASC` rotation). Forgejo is a READ mirror (flake-input GitHub-outage immunity); sync health = `system_forgejo_mirror_*` metrics + Gatus "Forgejo Mirror Sync".

- **Renames/transfers BREAK the mirror silently (forgejo design + fixed by reconcile):** forgejo v15 sets `http.followRedirects=false` on every pull mirror (SSRF hardening, `ModernizePullMirrorConfig`), and GitHub answers renamed/transferred paths with 301 — so the moment a repo moves, its mirror STOPS syncing and freezes. There is NO forgejo API to update a pull mirror's remote address (verified against the deployed `swagger.v1.json` — only `mirror-sync` + push mirrors exist), and the name-keyed mirror script creates a DUPLICATE under the new name while the stale one stays broken. The `forgejo-reconcile-mirrors` oneshot (every 6h after the mirror phase) closes this: stale names (in Forgejo but not in the GitHub listing) are probed via `gh api` redirects — renamed-in-account → stale mirror DELETED only when the canonical-name mirror exists AND the verdict repeats on a second run (state file `~/.local/state/forgejo-mirror-reconcile/pending-deletes.txt`); transferred-away → REPORT ONLY; upstream deleted → REPORT ONLY (the Forgejo copy is the only remaining copy — keep these!). Transient probe failures retry, never classify. Fixture-tested (all 5 branches) via PATH-stubbed gh/curl. Limits: forgejo repo names are assumed == GitHub names (true for everything the scripts created); `starred`-org mirrors are out of scope (owner-name → upstream mapping is ambiguous through dashes).
- **Private repos were NEVER auto-mirrored until 2026-09-18:** the listing endpoint was `GET /users/$USER/repos?type=all` — PUBLIC only (GitHub API limitation; `/user/repos` is required for private). Only the 2 declarative repos (dnsblockd, BuildFlow) of 200+ private repos were covered. Fixed: the listing is now `GET /user/repos?visibility=all&affiliation=owner` (owned, all visibilities, forks included; org/collaborator repos deliberately stay out of scope — every live mirror is LarsArtmann-owned, verified). First post-deploy run migrates ~200 repos at 2-8s each (synchronous migrate API) — `TimeoutStartSec = 2h` on the unit for exactly that; idempotent, converges across timer runs.
- **Push mirrors NEVER worked (18/18 attempts 400) — dead code REMOVED:** the scripts' push-mirror POST omitted the mandatory `interval` field and forgejo's `time.ParseDuration("")` rejected every attempt (`POST .../push_mirrors 400` — the "may already exist" warning was a lie). A push mirror on a PULL mirror is also incoherent (the next pull clobbers forgejo-side commits). If forgejo→GitHub push is ever wanted: re-add the POST WITH `interval: "8h"` and first settle the pull-vs-push clobber design.
- **Live state at audit (2026-09-18): 158 mirrors, 0 renames in flight, 32 upstreams deleted (frozen archives — old Minecraft-plugin era repos; the Forgejo copies are the ONLY remaining copies), 2 transferred to `Artmann-Minecraft` org (DarkBlocks, DialogesWebInterface — frozen + syncing-fails against the redirect; owner decision: delete or re-mirror into a forgejo org).** Transient `SyncMirrors ... pull mirror failed to meet migration URL requirements: migration/cloning from 'github.com' is not allowed` = DNS blip during forgejo's `LookupIP` recheck (external-builtin allowlist can't match an unresolvable host) — self-heals, no action. Two ALIVE mirrors (golangci-lint, DynamicMinecraftNetwork) log a per-sync `commit-graph.lock` warning from a stale lock file in their bare repos — cosmetic, cleanup needs the forgejo user: remove `/var/lib/forgejo/repositories/lars/<name>.git/objects/info/commit-graph.lock`.
- **Continuation hardening (2026-09-18 afternoon, same audit's follow-ups):** (1) mirror-github's GitHub listing now fails LOUD on non-array responses (`jq -e 'type == "array"'` per page) — before, a rate-limited listing made `.[]` yield nothing, `length < 100` broke the loop, and the run "succeeded" with ZERO repos (phantom-green class); (2) the reconcile script PUBLISHES outcome metrics (`forgejo_mirror_{total,stale_names,upstream_deleted_archived,transferred,pending_deletes}`, `forgejo_mirror_reconcile_{scrape_errors,last_run_timestamp}`) directly into the node_exporter textfile dir (sticky 1777, the unit is the ONLY writer of `forgejo_mirror_reconcile.prom` → mktemp+chmod 644+mv needs no CAP_FOWNER; publish is best-effort-warn, `FORGEJO_MIRROR_TEXTFILE_DIR` env override exists for fixture tests) — published ONLY on a completed run, so mid-run death leaves last-good values and the UNIT-state alert owns that failure mode (`forgejo-github-sync` in `system-health.extraMonitoredServices`); (3) Gatus "Forgejo Mirror Reconcile" (registry check on the forgejo entry): absent metrics = no completed run ever = red by design until the first post-ship run; (4) `forgejo-github-sync.service` carries `ioTier.background` + `MemoryMax = 1G` + `startLimitBurst 5/300s` + `serviceOneshotDefaults` (the unit itself only runs curl/jq/gh — migration git clones happen inside forgejo.service's cgroup); (5) deploy.sh STARTS `forgejo-github-sync.service` `--no-block` post-switch (timer-gated — the SERVICE unit is not enabled, only the timer; the indirect-unit `is-enabled` rc=1 trap) so every deploy converges mirrors + reconcile immediately instead of at the next 6h tick, and the first-run mass migration never blocks a deploy. Both scripts fixture-verified end-to-end (PATH-sed-injected stubs — runtimeInputs shadow plain PATH stubs, the DMS lesson): mirror happy-path (existing/new/created/exit 0) + rate-limit (exit 1 with message); reconcile two-run rename delete + archived/transferred classification + prom contents. Residual: `/var/lib/forgejo` size measurement needs the forgejo user (0700 + backup dir unreadable from lars) — measure after the first mass migration to project btrbk root-snapshot growth.
- **Staged-primary Phase 1 SHIPPED INERT (2026-09-18 evening; plan `docs/planning/2026-09-18_16-44_FORGEJO-PRIMARY-STAGED-FOUNDATION.md` §10 addendum has the status table):** `services.forgejo.canonicalRepos` (default `[]` = phase absent) + `forgejo-push-mirror` as sync-unit phase 3 (ALWAYS sends `interval:"8h"` — the missing field that 400'd all 18 historical attempts; refuses repos still `mirror==true`, the pull-vs-push clobber guard); `forgejo-flip-repo` + `forgejo-flip@`/`forgejo-flip-check@` template units (delete disposable mirror → `mirror:false` FULL re-migrate incl. issues/PRs/wiki/LFS → attach push mirror; template units carry the sync env + OnFailure so no secret ever lands on a command line); `forgejo-mirror-health` 5-min collector + Gatus "Forgejo Dead Mirror Candidates". **The plan's dead-mirror heuristic was FALSIFIED before building (source + live-verified): TouchMirror advances `mirror.updated_unix` on FAILED syncs too (v15.0.8 `SyncPullMirror` → `TouchMirror` writes the same column), so ALL mirrors incl. the frozen ones carry fresh `mirror_updated`, and idle-healthy mirrors carry frozen `updated_at` — the pair cannot separate dead from idle. Authoritative per-repo signal: the `notice` TABLE (every failed sync writes a Type=1 `Failed to update mirror repository '<path>.git'` row via `CreateRepositoryNotice`); known-stale names are subtracted via `known-stale.txt`, now persisted atomically by every completed reconcile run.** Fixtures: flake checks `forgejo-scripts-fixture` (stubbed curl/gh/sqlite3, PATH-sed-injected into writeShellApplication wrapper COPIES — the wrapper's own runtimeInputs shadow plain PATH stubs) and `migrate-forgejo-subvol-fixture` (7 guard branches; the checksum-tamper case must preserve size+mtime so rsync quick-check SKIPS the file — a plain tamper is healed by the delta rsync before verification runs). Fixture-authoring traps hit live: never name a capture var `out` in a nix build script (shadows the derivation output path → the final `echo PASS > "$out"` redirects into a garbage filename); the PATH-injection sed must RE-ADD the opening quote it matched; stubs need the store-bash shebang (`/usr/bin/env` is absent in the sandbox). Deploy-order note: expect one red dead-mirror cycle on the first deploy carrying this batch (the stale file appears only after the first reconcile run).

### Forgejo UI/UX (Catppuccin delta themes, 2026-09-23)

**Theme system:** `modules/nixos/services/_forgejo-themes/` holds small DELTA css files that `@import` the upstream `theme-forgejo-{dark,light,auto}.css` (stable unhashed filenames in the package `data` output, v15.0.9-verified) and override variables only; the `forgejoThemes` attrset + tmpfiles `L+` rules install them into `/var/lib/forgejo/custom/public/assets/css/`. `ui.DEFAULT_THEME = "catppuccin-auto"`; arc-green was REMOVED from `ui.THEMES` (never shipped in v15, 404'd in the picker). **Eval-time audit:** every `ui.THEMES` entry must resolve to a backing `theme-<name>.css` (custom = `forgejoThemes` keys; upstream = the `upstreamThemeNames` list, re-verify on package bumps) or the tmpfiles eval throws naming the entry; `ui.DEFAULT_THEME` must be listed. Runbook + negative probe: `docs/services/forgejo.md` "Themes / UI". Settings traps learned en route: `settings` is 2-level ONLY (a 3-level `ui.meta.DESCRIPTION` fails the INI-atom type; use the quoted flat section key `"ui.meta"`); app.ini changes need NO restartTriggers (the generated app.ini store path is interpolated into the unit preStart, so the unit file changes and stc restarts forgejo); `APP_SLOGAN` renders in every page TITLE, `other.SHOW_FOOTER_POWERED_BY=false` kills the footer link, `picture.DISABLE_GRAVATAR=true` stops external avatar fetches. Post-deploy smoke pins the contract (theme asset @import, `data-theme="catppuccin-auto"`, title slogan, meta description). Phase 2 (logo/favicon via `custom/public/assets/img/`) is owner-gated. **Auto-theme dark-mode cascade trap (fixed 2026-09-30): `@media (prefers-color-scheme: dark)` grants NO cascade priority — document order wins at equal specificity, so ANY variable the delta's light `:root` block sets but the delta's dark block does NOT re-declare shadows upstream's dark-block value in dark mode** (live: delta-light's `--color-body: #f7f8fc` sat after the imported upstream file and beat its `var(--steel-800)` → near-white page body under steel-text = the washed-out half-dark look; the explicit mocha/latte deltas are immune — single override block, no opposing scheme block). Rule: every var added to the auto delta's light block must be re-pinned in its dark block; verify with the shadowed-set diff (delta-light ∩ upstream-dark − delta-dark must be empty), not by eye.

- **Forgejo SSH keys** — Forgejo doesn't read NixOS `openssh.authorizedKeys.keys`. Provisioned via admin API (`forgejo-ssh-keys` oneshot).
- **Forgejo `GET /admin/users/{u}/keys` → 405** — Use public `GET /api/v1/users/{u}/keys` for dedup. POST stays on admin path.
