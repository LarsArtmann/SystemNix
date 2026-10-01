# CV — Service Runbook

Resume/CV generator (`cv serve`, Go + Typst) from the private
[CV repo](https://github.com/LarsArtmann/CV). Public site at
**https://cv.home.lan**.

## Layout

| Concern           | Where                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Service           | `cv-server.service` (upstream module: CV repo `nix/nixos-module.nix`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| SystemNix wrapper | `modules/nixos/services/cv.nix`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Port              | `8098` (`lib/ports.nix`), loopback only; Caddy `protectedVHost` front                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| State dir         | `/var/lib/cv` (owned `cv:cv`, 0700)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Config            | generated `config.yaml` symlinked into the state dir from `services.cv-server.settings`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Secrets           | sops `platforms/nixos/secrets/cv.yaml` → template `cv-env` (`CV_API_KEY`), owned `cv:cv` 0400                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Persistence       | `/var/lib/cv/data/pipeline.sqlite` (event store; `pipeline.event_store_driver=sqlite`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Backups           | `/mnt/pool/backups/cv/pipeline-<ts>.sqlite`, nightly 03:17 (`cv-backup.timer`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| Scan automation   | `cv-scan.timer` every 6h (:23): POST `/api/pipeline/scan` + `/evaluate-tracked` + `/auto-apply` (X-API-Key)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Session probe     | `cv-profile-probe.timer` weekly Mon 09:41: `cv profile accounts --probe --all` — exit 3 = invalid session → unit fails → `OnFailure=notify-failure@%n` (critical desktop notification via notify-send, syslog-error fallback when the desktop session is absent). Alert routing was journal-only in practice until 2026-09-08: the `XDG_RUNTIME_DIR=/run/user/${uid}` interpolation rendered EMPTY (`users.users.lars.uid` is null at eval and Nix `or` does not catch null) so notify-send could never reach the session bus — fixed by pinning `uid = 1000` in configuration.nix (same root cause as boot.nix's hardcoded user-1000 slice); live on the NEXT deploy |
| Monitoring        | Gatus: `CV` (liveness 60s), `CV Page Renders` (/cv HTML 5m), `CV PDF Export` (%PDF 5m), `CV Funnel Freshness` (sse-stats 30m), `CV Pipeline Store Health` (/health 5m)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Tracing           | OTLP-HTTP → localhost:4318, service `cv-application` (SigNoz)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Upstream pin      | flake input `cv` (rev-locked, git+ssh; no `follows` — vendorHash stability)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Health surfaces   | `/health` (hand-rolled: checks incl. `pipeline-store` ping of the SQLite store; `database` = optional Turso analytics, DISABLED by design — the "Database not configured" message is benign) + go-health probes `/health/live                                                                                                                                                                                                                                                                                                                                                                                                                                         |

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

> **Lock-state breadcrumb (2026-09-17):** the morning `nix flake update`
> moved `cv` `c37b8f59` → `6aba2678`, whose go-modules FOD fails upstream
> (stale vendorHash — CV's CI is dead, so no signal), and local HEAD
> (`b4aeaa0d`, mid-flight in a parallel session) additionally fails at the
> `cv-prepared-source-dev` FOD (`interpreter directive changed` on
> `_local_deps/go-cqrs-lite/scripts/check-error-taxonomy.sh`). Deploy
> unblocked by rolling the lock node back to the last buildable `c37b8f59`
> (FOD re-probed GREEN from our flake). Re-bump once the CV session lands
> a rev with both the vendorHash refresh and the dev-source shebang issue
> fixed — probe first: `nix build --impure --no-link --expr '(builtins.getFlake (toString /home/lars/projects/CV)).packages.x86_64-linux.cv.goModules'`.

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
weekly core: profile verify (session + criteria + baseline diff), then ONE
`funnel --refresh-baseline` fetch (since 2026-09-21 the jobs-feed diff, the
transition ledger, the baseline refresh, and the funnel bridge all fold into
that single polite GET). Registered 2026-09-08 as a systemd USER timer
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
- **Operator sign-in (since the 2026-09-11 deploy, cv 68e5f99)**: the guarded
  operator pages (`/admin`, `/pipeline`) authorize the browser via the
  session cookie from one sign-in at `https://cv.home.lan/admin` (paste the
  `CV_API_KEY` from the sops `cv-env`). Sessions are process-local: every
  server restart signs the browser out, and `/pipeline` now says so honestly
  (server-rendered locked banner + sign-in link) instead of silently 401-ing
  its SSE/stats requests.

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### CV Server (`cv.home.lan`, services.cv-server)

- **Consumes the upstream module** (`inputs.cv.nixosModules.default`, PRIVATE repo via git+ssh) — never hand-roll service logic here; the wrapper (`modules/nixos/services/cv.nix`) only layers sops env, port, GOMEMLIMIT/MemoryMax, onFailure, and the nightly `cv-backup` oneshot (online sqlite `.backup` of `/var/lib/cv/data/pipeline.sqlite` → `/mnt/pool/backups/cv`, registered in backup-coordination).
- **CV uses nixpkgs `go_1_26` directly** (the inline go.dev 1.26.6 source-tarball override was DROPPED upstream 2026-08-31, CV `c24b94c2`, once the locked nixpkgs shipped 1.26.7 ≥ the go.mod floor 1.26.7) — do NOT follow its nixpkgs input (vendorHash stability, discordsync precedent). **BRANCH-REF GOVERNED HOLD (2026-09-17): CV master `65c8fcd5` bumped the go.mod floor to 1.27.1 > nixpkgs `go_1_26` = 1.26.7 → the go-modules FOD dies `go.mod requires go >= 1.27.1 (running go 1.26.7; GOTOOLCHAIN=local)`** (library-policy's upstream solved the same floor by switching ITS flake to `goPkgAttr = "go_1_27"` — nixpkgs DOES ship 1.27.1 — CV upstream needs that one-line fix, not a SystemNix change). The lock deliberately HOLDS the proven `ef1ce387` (FOD verified in the b1b8759 era — the exact realized store path `r3wicl8r` reproduces from our lock); do NOT `nix flake lock --update-input cv` until upstream drops its floor or adopts go_1_27 — probe `nix build github:LarsArtmann/CV/master#default.goModules` first (CV CI is dead, no upstream signal).
- **Runtime shape is upstream-owned**: config.yaml generated from `services.cv-server.settings` (deep-merged over host/port), content synced read-write into `/var/lib/cv` by ExecStartPre (securefs allowlist is CWD-based — store symlinks would be rejected), pinned typst injected via forced service PATH (`/run/current-system/sw/bin:<typst>/bin`; nixpkgs' default PATH is plain-priority, a plain assignment conflicts).
- **Secret**: `platforms/nixos/secrets/cv.yaml` (age-encrypted to evo-x2) → `cv-env` template → `CV_API_KEY`. Read/rotate: sops as your user with the SOPS_AGE_KEY one-liner (Sops + Age section): `SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops platforms/nixos/secrets/cv.yaml`. Plain `sudo sops` FAILS — root carries no age identity (live-verified 2026-09-06). Guard verified: `/metrics` answers 401 without `X-API-Key`.
- **Continuous funnel**: `cv-scan.timer` (every 6h at :23) POSTs `/api/pipeline/scan` (empty body = ALL `pipeline.portals` from settings) + `/api/pipeline/evaluate-tracked` (no-force) + `/api/pipeline/auto-apply` (funnel tail, gate Q2 2026-09-02: tailors top recommendations into the approval queue + sweeps approved-but-unsent; 503 = auto-apply disabled in config → WARN not failure) with `X-API-Key` from the same `cv-env` template. Lease-safe (the server owns the sqlite). Requires the cv input to carry the 2026-08-29 X-API-Key CSRF bypass — older packages 403 `csrf_invalid`. Forced full re-scoring stays MANUAL (docs/services/cv.md) — a periodic force pass is pure event bloat. Portals live in `cv.nix` settings because the generated config.yaml IS the whole config; keep in sync with the CV repo's config.yaml (2026-09-13 sync: the drift ran ~4 days — upstream added the defense-search .de portal + wwr/remotive/remoteok feeds on 09-09/09-12 AFTER the 09-09 05:37 cv.nix sync, so production funneled 15 of 19 portals; now 19/19, deployed + verified in the rendered cv-config.yaml). CV's own GitHub CI is DEAD since ~2026-09-10 (Actions hosted-minutes exhausted for private repos — every job fails runnerless with zero steps; see CV repo AGENTS.md Honest Gaps): input bumps there get NO upstream CI signal — probe the rev locally (`nix build github:LarsArtmann/CV/<rev>#default.goModules`) before moving the lock.
- **Funnel freshness + session probes (2026-08-30)**: the "CV Funnel Freshness" Gatus check hits `/api/pipeline/sse-stats` with `$CV_API_KEY` (rendered into `gatus-env` when cv-server is enabled — same sops key as the scan timer) and string-matches `"funnelStale":false`; `mkHttpCheck` gained an optional `headers` passthrough for it. `services.cv-server.profileProbe` (OFF by default, chromium package parameterized; ENABLED on evo-x2 since 2026-08-30) runs `cv profile accounts --probe --all` weekly as the operator user from the CV checkout — exit 3 (invalid session) FAILS the unit into onFailure alerting on purpose. The one-time IGNITION runbook (deploy -> first tick -> SEED the prod store) lives in docs/services/cv.md.
- **Pipeline-store health check (2026-09-02, pairs with the bump; SHAPE MIGRATED 2026-09-17)**: Gatus "CV Pipeline Store Health" hits `/health` (unauthenticated, GeneralRateLimit only) and body-asserts the SQLite funnel store's check — since the go-health rich-format migration (deployed `ed8b92f`, the 2026-09-15 defense-portal bundle), `/health` returns 40 per-component checks keyed by fully-qualified Go type (`typetostring.GetType`) with compact `{"status":"..."}` values, so the anchored pattern is `pat(*eventstore.PipelineStore":{"status":"pass"*)` — NO leading quote before `eventstore` (the key's quote sits at `github.com/...`; a quoted short-suffix pattern can NEVER match — live-verified against the served body 2026-09-17). The `database` check is the optional Turso analytics DB, DISABLED in prod by design — its "not configured" warn is benign, never an alarm. "warn"/"fail"/absent all fail the pat, and in-memory-backend degradation also fails: production is sqlite by config, so a degraded verdict means the persistence config regressed (the config-validation gap the CV repo flagged). DEPLOY-ORDER: requires a cv input ≥ the go-health migration — older binaries carry the compact legacy key (`"pipeline-store":{"name":"pipeline-store","status":"healthy"}`) and sit permanently red. NOTE: overall `/health` status is `warn` while `ChatService` reports `groq: enabled but api_key empty` (defense-portal chat config, no sops key wired) — no Gatus check pages on the overall status, but it is an owner decision: wire a groq key or disable the provider. NO tmpfiles rule for `/mnt/pool/backups/cv` (removed 2026-09-02 — nofail pool + tmpfiles-setup After=local-fs.target = root-fs shadow dir during DAS outages, the 226 masking class; cv-backup-dir oneshot is the only creator). `pipeline.evaluation.min_day_rate` (EUR/day price floor) is SET to 600 in cv.nix (owner decision 2026-09-03, ratifying the CV repo's proposal — deployed and verified in the rendered config 2026-09-13), see docs/services/cv.md.
- **CI auth for private inputs**: deploy keys ("SystemNix CI (read-only)" on CV + go-cqrs-lite + branching-flow, secrets `NIX_DEPLOY_KEY_CV`/`NIX_DEPLOY_KEY_GO_CQRS_LITE`/`NIX_DEPLOY_KEY_BRANCHING_FLOW`) + ssh-agent step in nix-check.yml AND flake-update.yml (the weekly lock bot — auth ported 2026-09-29; before that the bot failed ALL five weekly runs since 2026-08-31, dying unauthenticated on the first private input); the public go-nix-helpers git+ssh URL is rewritten to HTTPS. **Deploy keys only cover git+ssh ROOT inputs** — 32 private repos ride `github:`-type (api.github.com tarball) lock nodes (root + subtrees pinned by upstream flakes at follows-unreachable depth), which the job-scoped `GITHUB_TOKEN` CANNOT read (repo-scoped; every fetch 404s — CI dark for 120+ runs, root-caused 2026-09-03). The workflows fall back to `NIX_GITHUB_RO_TOKEN` (fine-grained PAT, Contents: Read-only) via nix-installer `access-tokens`; until that secret exists CI stays dark. Local evals work because `~/.config/nix/nix.conf` carries the user's gh OAuth token in `access-tokens` — same fetcher, proof the mechanism works.
- **checks.cv gate disposition (2026-09-25): PASS → stays wired.** First full serialized run on the healed host (post `/run/binfmt` repair): driver builds green, VM test exit 0 in ~93s — server boot, `/health/live`, generated config.yaml, typst content sync, real-PDF export (`%PDF` magic), cv-scan timer + timer-shaped scan-POST live-proven, session-probe timer, pool backup dir self-create + backup landing all verified. Gate placement decision: keep in `nix flake check` (deploy-time verification), NOT pre-commit — a ~90s VM boot is far too heavy for per-commit gating. Re-run evidence procedure: `nix build .#checks.x86_64-linux.cv.driver`, then `<driver>/bin/nixos-test-driver < <driver>/test-script`.
