# CV — Service Runbook

Resume/CV generator (`cv serve`, Go + Typst) from the private
[CV repo](https://github.com/LarsArtmann/CV). Public site at
**https://cv.home.lan**.

## Layout

| Concern           | Where                                                                                         |
| ----------------- | --------------------------------------------------------------------------------------------- |
| Service           | `cv-server.service` (upstream module: CV repo `nix/nixos-module.nix`)                         |
| SystemNix wrapper | `modules/nixos/services/cv.nix`                                                               |
| Port              | `8098` (`lib/ports.nix`), loopback only; Caddy `protectedVHost` front                         |
| State dir         | `/var/lib/cv` (owned `cv:cv`, 0700)                                                           |
| Config            | generated `config.yaml` symlinked into the state dir from `services.cv-server.settings`       |
| Secrets           | sops `platforms/nixos/secrets/cv.yaml` → template `cv-env` (`CV_API_KEY`), owned `cv:cv` 0400 |
| Persistence       | `/var/lib/cv/data/pipeline.sqlite` (event store; `pipeline.event_store_driver=sqlite`)        |
| Backups           | `/mnt/pool/backups/cv/pipeline-<ts>.sqlite`, nightly 03:17 (`cv-backup.timer`)                |
| Scan automation    | `cv-scan.timer` every 6h (:23): POST `/api/pipeline/scan` + `/evaluate-tracked` + `/auto-apply` (X-API-Key) |
| Session probe     | `cv-profile-probe.timer` weekly Mon 09:41: `cv profile accounts --probe --all` — exit 3 = invalid session → unit fails → `OnFailure=notify-failure@%n` (critical desktop notification via notify-send, syslog-error fallback when the desktop session is absent). Alert routing was journal-only in practice until 2026-09-08: the `XDG_RUNTIME_DIR=/run/user/${uid}` interpolation rendered EMPTY (`users.users.lars.uid` is null at eval and Nix `or` does not catch null) so notify-send could never reach the session bus — fixed by pinning `uid = 1000` in configuration.nix (same root cause as boot.nix's hardcoded user-1000 slice); live on the NEXT deploy |
| Monitoring        | Gatus: `CV` (liveness 60s), `CV Page Renders` (/cv HTML 5m), `CV PDF Export` (%PDF 5m), `CV Funnel Freshness` (sse-stats 30m), `CV Pipeline Store Health` (/health 5m) |
| Tracing           | OTLP-HTTP → localhost:4318, service `cv-application` (SigNoz)                                 |
| Upstream pin      | flake input `cv` (rev-locked, git+ssh; no `follows` — vendorHash stability)                   |
| Health surfaces   | `/health` (hand-rolled: checks incl. `pipeline-store` ping of the SQLite store; `database` = optional Turso analytics, DISABLED by design — the "Database not configured" message is benign) + go-health probes `/health/live|ready|startup` + `/admin/health` dashboard |

> **Lock-state breadcrumb (2026-09-03):** the 2026-09-02 bump to `6615eec`
> failed its go-modules FOD upstream (source-only churn; the handoff-era
> `tH3s…` got-hash went stale the same way). A parallel session rolled the
> lock back to `7dee7292` to unblock the 00:3x deploy train — the deployed
> binary therefore predates `pipeline-store`, and the "CV Pipeline Store
> Health" Gatus check + smoke line stayed red BY DESIGN until the next
> deploy. Chain repaired 2026-09-03: fresh got-hash probed lock-free at
> origin/master, pasted upstream (CV `4ac7ca7b`, pushed; CV's own
> `checks.vendor-hash` CI gate validates it), SystemNix re-locked to
> `4ac7ca7b`, hermetic FOD + full package build GREEN, `nix flake check
> --no-build` rc=0. Deploys were pending the IO-PSI gate + the user reboot.

## State dir contract

- `assets/` and the 8 `data/<content>/` subdirs are **wiped and re-copied**
  from the package on every start (ExecStartPre `cv-server-content-sync`).
  Never store anything mutable there.
- `data/` ROOT files (`pipeline.sqlite`, `dead-portals.json`,
  `graphrag.sqlite`) are runtime-mutable and never touched by the sync.

## Continuous funnel automation

`cv-scan.timer` fires every 6 hours and drives the server over HTTP with
the same `CV_API_KEY` the server reads (sops `cv-env` template):

1. `POST /api/pipeline/scan` — empty body scans ALL portals from
   `pipeline.portals` in `cv.nix` settings (the generated config.yaml IS
   the whole config — keep that list in sync with the CV repo's
   config.yaml). Every newly discovered job is evaluated inline (score +
   recommendation + ANÜ/eligibility blockers land in the same pass).
2. `POST /api/pipeline/evaluate-tracked` — no-force pass that only picks
   up rows whose scan-time evaluation failed (idempotent otherwise).
3. `POST /api/pipeline/auto-apply` — funnel tail (gate Q2, 2026-09-02):
   tailors the top recommended applications into the approval queue and
   sweeps approved-but-unsent sends. Never sends un-approved
   (`send_on_approve`: the dashboard Approve click IS the confirmation).
   503 = auto-apply disabled in config (gate Q1 not flipped) — logged as a
   WARN, not a failure.

Both endpoints are async + 409-guarded, so an overlap with a
dashboard-triggered run is harmless. Failures (non-200/409, e.g. a wrong
key after rotation) fail the unit → onFailure alert.

## Weekly gun.io check (user timer, no root)

`scripts/gunio-weekly-check.sh` (CV checkout) is the monitoring cluster's
weekly core: profile verify (session + criteria + baseline diff), jobs-feed
diff, and the funnel bridge. Registered 2026-09-08 as a systemd USER timer
(deadportals no-root precedent), with the rc semantics wired:

- **rc 1 (drift/probe failure) = ALERT** — the unit fails, `OnFailure`
  triggers the user unit `~/.config/systemd/user/cv-gunio-weekly-alert.service`
  (critical desktop notification, syslog fallback).
- **rc 3 (funnel candidates) = TO-DO** — `SuccessExitStatus=3` keeps the unit
  green; the runbook lands in `journalctl --user -u cv-gunio-weekly`.
- Transient timer `cv-gunio-weekly.timer`, Sun 21:00 — dies at user logout;
  re-register with `bash scripts/gunio-weekly-check.sh --print-timer`.

Registration env (the user manager has NO devshell env — verified by live
runs 2026-09-08): `WorkingDirectory=/home/lars/projects/CV`,
`PATH=/run/current-system/sw/bin:/etc/profiles/per-user/lars/bin`,
`CHROMIUM_EXECUTABLE_PATH=<nix-store chromium>` and
`PLAYWRIGHT_BROWSERS_PATH=$HOME/tmp/playwright` (the verify step launches
the session probe). The script itself now pins `GOEXPERIMENT=jsonv2`
(defaulted) — without it `go run ./cmd/cv` cannot compile outside the
devshell and EVERY timer run false-drifts rc 1.

## Evaluation knobs

- **`pipeline.evaluation.min_day_rate`** (default 0 = off, upstream
  2026-09-02): EUR-per-day price floor — an advertised rate whose upper
  bound converts below it skips the verdict regardless of score (hourly
  rates convert at ×8 first; postings without an advertised rate are
  never skipped). Set it in `cv.nix` `settings.pipeline.evaluation` when
  the operator picks a value (CV repo proposed 600; env override
  `CV_EVALUATION_MIN_DAY_RATE` also exists). A forced re-eval pass
  (manual command above) re-stamps stored apps after enabling it.

**Forced re-scoring is manual** — when criteria change (keywords, CV data,
blockers like the 2026-08-29 eligibility axis), run once:

```bash
key=$(sudo cat /run/secrets/cv-env 2>/dev/null | cut -d= -f2)   # or read from sops
curl -s -X POST -H "X-API-Key: $key" -H 'Content-Type: application/json' \
  -d '{"force":true,"workers":8}' http://localhost:8098/api/pipeline/evaluate-tracked
```

A periodic force pass is deliberately NOT timer-driven: it appends one
`job.evaluated` event per tracked application per run even when verdicts
are identical — pure event-store bloat.

**Deploy-order dependency**: the timer's POSTs need a CV package whose
server skips CSRF for `X-API-Key`-bearing requests (CV repo 2026-08-29+).
Older packages answer 403 `csrf_invalid`. Bump the `cv` flake input in the
same deploy that activates this timer.

## Ignition runbook (root on evo-x2, ~10 min, in order)

One-time sequence that takes the funnel from dormant to live. Steps 1–3 are
the deploy chain; step 4 is the production-store decision (default: SEED —
the 755 evaluated dev rows ARE the shortlist; fresh history only if the dev
store is considered noise).

```bash
# 1. Deploy the bumped input. VENDORHASH IS A MOVING TARGET (2026-08-30
#    lesson: re-pinned 4× in one day — MSaj28 → IsEVNQQ → 5fFa31AH → … —
#    because the CV tree moves under concurrent sessions and the go-modules
#    FOD hash tracks tree state). Protocol, never a frozen value: read the
#    CURRENT vendorHash at CV's nix/packages.nix on the rev you are about
#    to push, confirm that rev carries it, and if the FOD still fails it
#    names the truth — paste the `got:` hash into nix/packages.nix
#    vendorHash, let the daemon commit, re-bump the input, build again.
#    Probe the got-hash BEFORE touching the lock (no tree churn, no worktree):
nix build --impure --no-link --print-out-paths --expr \
  'let cv = builtins.getFlake "git+ssh://git@github.com/LarsArtmann/CV?rev=<FULL_REV>"; in cv.packages.x86_64-linux.default.goModules'
#    (fails with `got:` = the hash for EXACTLY that rev; a hash from an older
#    rev is worthless — source-only churn re-invalidates it, 2026-09-03.)
nix flake lock --update-input cv   # verify the lock rev includes the vendorHash fix
nix run .#deploy                   # watch for cv-server + cv-scan units in the switch
nix run .#post-deploy-check        # CV section: /health/live + /export/pdf
curl -s http://localhost:8098/health/live   # version stamp = the new rev

# 2. First-tick proof (the exact timer path, run once by hand)
systemctl start cv-scan.service
journalctl -u cv-scan -n 10                  # two "-> 200 (ok)" lines
systemctl list-timers | grep cv-scan         # next tick at 00/06/12/18:23
journalctl -u cv-server --since "-10 min" | grep 'dashboard scan completed'

# 3. Decide the production store (peek, then SEED unless populated)
ls -la /var/lib/cv/data/                     # pipeline.sqlite present? size?

# 4. SEED path (default): server STOPPED, dev store copied in, lease NOT copied
systemctl stop cv-server
cp /home/lars/projects/CV/data/pipeline.sqlite /var/lib/cv/data/pipeline.sqlite
rm -f /var/lib/cv/data/pipeline.sqlite.lease   # stale dev lease would block boot
chown cv:cv /var/lib/cv/data/pipeline.sqlite && chmod 600 /var/lib/cv/data/pipeline.sqlite
systemctl start cv-server
journalctl -u cv-server --since "-2 min" | grep -iE 'rehydrat|events'   # replay proof
#    then check the dashboard (cv.home.lan/pipeline) shows ~755 applications
```

After step 4, paste the first-tick journal excerpt into the root-proof block
in "Pending root-gated proofs" below (evidence canon) — then the funnel is
live and this section is historical.

## Common operations

```bash
systemctl status cv-server
journalctl -u cv-server -f

# After editing settings in cv.nix (or any new CV rev):
nix flake lock --update-input cv   # only for upstream revs
nix run .#deploy                   # switch restarts changed units

# Verify (no root needed):
curl -s http://localhost:8098/health/live   # {"status":"pass","version":"<rev>",...}
curl -s http://localhost:8098/export/pdf | head -c8   # %PDF-1.7

# Trigger a funnel scan out-of-band (same path the 6h timer uses):
systemctl start cv-scan.service && journalctl -u cv-scan -n 5
journalctl -u cv-server --since "-10 min" | grep -E 'scan completed|bulk evaluation'
```

## Incident playbook

- **`/export/pdf` 404 while `/cv` renders**: the typst template
  (`/var/lib/cv/assets/typst/cv.typ`) went missing under the running
  process (happened 2026-08-27). `systemctl restart cv-server` — the
  content sync re-copies assets. The `CV PDF Export` Gatus check catches
  this class; the HTML check cannot.
- **`concurrency conflict: app <id> version N` on pipeline writes**: a
  CLI process opened the same sqlite store. One writer per file — stop
  one, or drive writes through HTTP.
- **`StoreLeaseHeldError`**: another process holds
  `<dsn>.lease`. Find the pid in the error; stop that process first.

## Pending root-gated proofs (paste into ONE root shell)

Non-root verification completed 2026-09-08 (evidence below): nightly backups
land pool-side through TODAY (`pipeline-20260908T031700.sqlite` 7.3M, 8
artifacts, 14-day retention), `backup_healthy{backup="cv"} 1` in the
backup-coordination textfile metrics (age 17h, maxAge 25h), the prod
`/pipeline` dashboard shows **0 dead portals** with all 14 configured portals
`ok`, OTel spans for `cv-application` are LIVE in SigNoz (12,169 spans in
`signoz_traces.signoz_index_v3`; a hand-triggered `/export/pdf` at 20:34:45
produced its span at 20:34:45.28 — same second), the Gatus `CV PDF Export`
cycle was observed end-to-end (200s at 5m cadence, ~160-170ms each, in the
cv-server journal), and the server's peak RSS under `MemoryMax=1G` /
`GOMEMLIMIT=768MiB` is **187 MiB** (`VmHWM 191852 kB`, `VmRSS` ~71-76 MB
steady-state) with Gatus driving an export every 5 minutes.

Still open for a root shell when convenient:

```bash
# 1. Asset-vanishing incident forensics (2026-08-27, ~10:15–10:45 window):
#    the journal names exactly what vanished; journalctl is NOT volatile
journalctl -u cv-server --since "2026-08-27 10:15" --until "2026-08-27 11:00" --no-pager

# 2. Restart-drill persistence proof (the actual product claim):
#    a tracked application written via HTTP survives a full restart.
curl -s http://localhost:8098/health/live        # baseline healthy
systemctl restart cv-server && sleep 8
curl -s http://localhost:8098/health/live        # back up, same version
#    then compare tracked applications before/after via the dashboard
#    (state-dir listing is the same root shell: ls -la /var/lib/cv/data/)
```

## Restore drill (root)

```bash
systemctl stop cv-server
cp /mnt/pool/backups/cv/pipeline-<ts>.sqlite /var/lib/cv/data/pipeline.sqlite
chown cv:cv /var/lib/cv/data/pipeline.sqlite && chmod 600 /var/lib/cv/data/pipeline.sqlite
systemctl start cv-server   # rehydration replays events, no snapshot needed
```

A real restore drill remains pending (owner root shell; the 8 backup
artifacts above are restorable round-trip-tested upstream).

## Rotating `CV_API_KEY`

1. Generate: `openssl rand -hex 32`.
2. Edit the value in `platforms/nixos/secrets/cv.yaml` via sops
   (`--input-type yaml`!), keeping the key name `cv_api_key`.
3. Deploy — `restartUnits` on the `cv-env` template rolls the service.
4. Present as `X-API-Key` on guarded routes (`/api/pipeline/*`, `/metrics`, …).

## Deliberate non-features

- **`cv` CLI not on PATH**: the sqlite event store takes one writer per
  file; CLI + server on the same DSN fail-fast (lease) by design. Server
  writes go through HTTP; bulk CLI work happens in the dev checkout.
- **GraphRAG/CRM/AI coaching off**: 503-with-hint until their config keys
  are set (each would need its own sops entry).
