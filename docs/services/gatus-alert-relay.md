# gatus-alert-relay

Local gate on gatus' Discord webhook path. Built 2026-10-24 (T-007 —
monitoring.md "Gatus boot/restart alert-storm + flap suppression").

## Why

- **Boot-window alert storms**: gatus starts early in userspace; services
  settle minutes later (storm boots run 8-13 min). Every check that hits
  failure-threshold during that window fires a Discord page — ~25 endpoints
  × 2 on the 2026-10-20 double reboot. (Sqlite storage already prevents
  re-sends of PRE-restart failures — gatus 5.37 persists triggered-alert
  state; these were NEW triggers.)
- **Flappers**: Monitor365 ×89 and InboxClean ×73 trigger+resolve pairs in
  24h (2026-10-20/21) burned ~160 Discord pairs.
- gatus has NO native flap suppression; maintenance windows are time-fixed
  and cannot key on "services still settling" or "SEV1 bridge is paging".

## What it does

gatus' Discord provider posts to `http://127.0.0.1:9411/hook` (port
`lib/ports.nix` `gatusAlertRelay`); the relay re-posts pass-through bytes
to the real webhook (from the same `gatus-env` sops secret). Decision
rules, in order:

| rule          | condition                                            | effect                                                        |
| ------------- | ---------------------------------------------------- | ------------------------------------------------------------- |
| boot-grace    | relay process age < 15 min (default)                 | suppress trigger, queue; replay at grace end if still failing |
| sev1-mute     | SEV1 bridge page-tier active + endpoint on mute list | suppress trigger, queue; replay when SEV1 clears              |
| flap-collapse | > 4 forwarded triggers per endpoint per 6 h sliding  | suppress (LOSSY — the point), until 30 min event-free quiet   |
| rearm-guard   | trigger within 10 min of a resolve                   | suppress, queue; replay at deadline if still failing          |

**Contract: a mute may DELAY an alert, never lose it** — every rule except
flap-collapse replays its queued trigger when the condition clears without
an intervening resolve (which cancels the queue). Resolves ALWAYS forward.
Unparseable payloads forward (fail-open — gatus template drift degrades to
today's behavior, never silence). Only FORWARDED triggers count toward
flap-collapse (muted ones must not poison the counter).

- SEV1 source of truth: `/run/systemnix/sev1/alert` (4 lines:
  title/detail/epoch/severity; rewritten every bridge run, removed on
  clear, chmod 0644). Mute requires line 3 fresh (< 10 min) AND line 4 ==
  `page` — warn tiers do NOT mute. Read failure fails open (no mute).
- Storm-attributable mute list (`services.gatus-alert-relay.sev1MuteEndpoints`):
  metrics-scrape family + the two documented flappers, in `Group/Name`
  DisplayName form. Independent service-down checks stay UNMUTED during
  SEV1 — a real second failure must still page.
- Provider-level `webhook-url` is NOT part of gatus' alert checksum —
  switching gatus to the relay does NOT wipe persisted triggered-alert
  state (no re-fire storm at deploy). The relay's own restart grace covers
  the deploy window anyway.

## Incident sink (tq, 1.1 — 2026-11-24)

Every trigger that survives the gates is ALSO reported to the go-taskqueue
incident pipeline (ADR-0021): `POST <tq-url>` with a Bearer token, which the
pool's unconditional `incident-policy` sweeper turns into a prio-120 (first
occurrence) / 150 (regression) agent fix task within one pool tick (~5 min).
Flags `-tq-url` / `-tq-token` (env `TQ_API_URL` / `TQ_API_TOKEN` from the
shared `tq-api-env` sops template, restartUnits-coupled to this unit); an
empty URL disables the sink (startup banner names the state:
`relay incident sink on <url> (project <p>)` or `… disabled`).

Rules:

- **Same gate, second sink** — the report fires only after a forward
  decision and only for parsed TRIGGERS. Resolves are never incidents (a
  recovery is not an error); unparseable payloads stay fail-open Discord
  forwards. Replayed queued triggers are reported too: a mute that DELAYED
  an alert must not lose the fix task.
- **All four gates apply to the sink** — including SEV1-mute (muted
  storm-attributable endpoints mint no agent tasks while the bridge pages;
  intended: known-storm checks should not burn agent budget) and
  flap-collapse (lossy for both sinks by design).
- **Fingerprint stability** — the report Message is always
  `Gatus health check failing: <Group/Name>`; the variable failure detail
  rides Breadcrumbs (clipped 20 × 256 chars) so one flapping endpoint stays
  ONE incident stream instead of fragmenting per-detail fingerprints.
- **Delivery** — 2 attempts, then counted failure; any 4xx is a permanent
  failure (no retry storm against a rejecting API). Counters
  `tq_reports` / `tq_failures` are in `/healthz` (the relay check sees
  liveness only — a sink gone dark quietly needs the counter alert, queued
  in monitoring.md).

Deep context on the receiving side: `docs/services/tq.md` → "Incident
pipeline". Tests: `pkgs/gatus-alert-relay/tq_test.go` (POST shape/auth,
message stability, skip-resolve/garbage/disabled, 4xx counting, breadcrumb
clipping) run in-build via `doCheck`.

## Verification surfaces

- `pkgs/gatus-alert-relay/policy_test.go` — every rule, replay transition,
  cancel-on-resolve, fail-open; runs in-build (`doCheck`).
- Live smoke (2026-10-24, pre-deploy): grace suppress → resolve cancels
  queue → post-grace forwards → flap-collapse at flapMax+1 → /healthz
  counters exact match with journal lines.
- Gatus check **Gatus Alert Relay** (`/healthz`, 2 min): catches a
  wedged-but-running relay; rides the papdashboard custom provider (direct
  localhost ingest) even when the relay itself is down.
- `onFailureP0` on the unit: relay death pages via the independent
  systemd/Discord path.

## Traps

- **Queue is in-memory** — a relay restart loses queued (suppressed)
  alerts. P0 hook fires on restart-loops; accept for clean deploys.
- gatus does NOT retry provider sends: if the relay is down when gatus
  fires, that alert is lost. Ordering: relay `before = gatus.service`.
- Parse anchor: `An alert for **<Group/Name>** has been (triggered|resolved)`
  (gatus 5.37 discord provider). Drift → fail-open forward.
- The relay must be younger-than-grace semantics: grace is measured from
  RELAY start, not system boot — boot AND deploy restarts both get the
  window.

## Files

- `pkgs/gatus-alert-relay/` — Go source (stdlib only, vendorHash null,
  ai-meter doctrine; `tq.go` = incident sink), wrapper
  `pkgs/gatus-alert-relay.nix`
- `modules/nixos/services/gatus-alert-relay.nix` — options + unit
- `modules/nixos/services/gatus-config.nix` — webhook flip + relay check
- Port: `lib/ports.nix` `gatusAlertRelay = 9411`
