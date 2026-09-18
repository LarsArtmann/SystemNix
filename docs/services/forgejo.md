# Forgejo — GitHub Mirror Sync Runbook

Self-hosted Forgejo (`https://forgejo.home.lan`, internal `http://localhost:3000`) mirrors every
GitHub repo owned by `LarsArtmann` as **pull mirrors** — a read-only backup with GitHub-outage
immunity for flake inputs. This runbook covers the sync model, reconcile semantics, monitoring,
and break-glass operations. Full audit narrative: `docs/status/2026-09-18_07-43_forgejo-mirror-sync-audit-and-fixes.md`.

## Sync model (who creates what)

| Surface | Cadence | What it does |
| --- | --- | --- |
| `forgejo-github-sync.timer` → `forgejo-mirror-github` | 6h + boot 5m + every deploy (`deploy.sh` starts it `--no-block`) | Lists `GET /user/repos?visibility=all&affiliation=owner` (owned, public+private+forks; **not** org/collaborator repos) and creates any MISSING mirror via `POST /repos/migrate`. Never touches existing mirrors. Fails LOUD if GitHub answers a non-array (rate limit/auth). |
| `forgejo-reconcile-mirrors` (2nd ExecStart, same unit) | same | Heals renames, classifies transfers/deletions (below). Publishes `forgejo_mirror_*` metrics. |
| `forgejo-ensure-repos.timer` → `forgejo-ensure-repos` | daily | Declarative 2-repo list (dnsblockd, BuildFlow) — **redundant** with the general listing since 2026-09-18; collapse pending owner decision. |
| `forgejo-mirror-starred` | manual only | Starred repos into the `starred` org — OUT of reconcile scope (name→upstream mapping ambiguous through dashes). |
| Forgejo internal pull loop | `mirror.DEFAULT_INTERVAL` 8h via 30m `cron.update_mirrors` (PULL_LIMIT 50, oldest-`updated_unix` rotation) | The actual `git fetch` per mirror. |

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
