# ci-watchdog

**Module:** `modules/nixos/services/ci-watchdog.nix` (`services.ci-watchdog`)
**Check program (single source of truth):** the domains repo's `ci-watchdog` nix app — wired via the `domains` flake input (`checkProgram = inputs.domains.apps.<system>.ci-watchdog.program`); the app closes over `gh`/`jq`/`coreutils`.
**Enabled:** `platforms/nixos/system/configuration.nix` (evo-x2).
**Created:** 2026-10-17 — the domains Pareto plan T12; detection gap first observed 2026-06→08.

## What it does

Every 30 min (oneshot + `Persistent` timer), queries GitHub Actions for the domains repo's `runner-health.yml` canary run history and exits non-zero when Actions is not healthy — which trips the unit's `onFailure` hook. The canary is a workflow scheduled every 30 min **on GitHub-hosted runners**, so during an Actions outage it is structurally blind to itself; this watchdog is the outside observer.

Detection cases (all exit 1):

- **No runs at all** — Actions disabled or history wiped.
- **Canary run older than 4 h** (`max_age_hours`) — scheduled runs not executing.
- **Failed canary run** — annotations are inspected per-job to separate:
  - **billing block** (`recent account payments have failed or your spending limit needs to be increased`), or
  - a genuinely broken workflow (`gh run view <id> --log-failed` hint).

Run it manually any time:

```bash
nix run ~/projects/domains#ci-watchdog
```

(Current live behavior, verified 2026-10-17 from evo-x2: FAIL — billing block correctly detected, `conclusion=failure age=0h` with the billing annotation.)

## Why (incident class)

The 2026-06→08 Actions billing block killed every GitHub-hosted job at startup for ~8 weeks unnoticed: `runner-health.yml` itself never started, so every watcher that lived inside Actions was blind. An outside canary observer is the only structural fix. The 2026-09-08 recurrence was caught only by a human reading annotations (`gh api .../check-runs/<job>/annotations`).

## Deployment notes

- Runs as the **primary user** (`User = lars`) so `gh` reads its OAuth token from `~/.config/gh/hosts.yml`; `ProtectHome = "read-only"` (token is read, never written), `XDG_CACHE_HOME` redirected into the unit's `StateDirectory` (`/var/lib/ci-watchdog/cache`) so gh's cache never touches the read-only `$HOME`.
- gh must stay authenticated: if the token expires the watchdog fails with `cannot query GitHub Actions (is gh authenticated?)` — that failure is ALSO a trip (a dead observer must not read as healthy).
- **Forgejo transition:** once the domains repo retires GitHub Actions entirely (Forgejo CI burn-in done, GitHub workflows deleted), this watchdog's canary disappears — retire the module in the same change (the Forgejo-side equivalent lives in the domains `.forgejo/workflows/ci.yml` + its own runner-health story).
- Deploy-gated: evaluate + enable landed 2026-10-17; `nix run .#deploy` activation is queued in `docs/todo/services.md`.
