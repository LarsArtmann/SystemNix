# gatus (health-check hub)

**Service:** `services.gatus-config` — `modules/nixos/services/gatus-config.nix` (wrapper over nixpkgs `services.gatus`; **DynamicUser**). Port 9110 (`lib/ports.nix`), loopback. URL: `status.<domain>` — **Layer 1 plain** vHost + native OIDC (clientId `gatus`, callback `https://status.<domain>/authorization-code/callback` — path fixed upstream) via the registry entry. DNS `status`.

The fleet's alerting backbone: every endpoint check (infra core here + per-service checks fanned in from `services.integration.<name>.checks`) → Discord (direct fast path) AND PapDashboard `/api/ingest` (LLM insight path). Check design patterns, `pat()` glob traps, and the alert-description charset rule live in [docs/agents/monitoring.md](../agents/monitoring.md) — this runbook covers only the service shape.

## What it serves

| Route                          | Auth               | What                                     |
| ------------------------------ | ------------------ | ---------------------------------------- |
| `/`                            | Gatus OIDC session | Dashboard (status pages, uptime history) |
| `/authorization-code/callback` | OIDC flow          | Login callback (fixed path)              |
| `/api/v1/*`                    | OIDC session       | Status API                               |

## Ops

- **Config source** — `gatus-config.nix` renders endpoints (infra/meta core: DNS functional, node-exporter, cAdvisor, SigNoz*, D-State, self, textfile collector, Immich, Homepage) + `extraEndpoints` from the registry fan-out; a NEW service's checks belong in ITS module (registry entry), never hand-added here.
- **Secret wiring under DynamicUser** — the OIDC client secret loads via systemd `LoadCredential` from the provisioner path (a DynamicUser cannot own files); the PapDashboard ingest key rides the `gatus-env` sops template. `partOf pocket-id-provision` re-loads credentials on regeneration.
- **Self-health probe must use `[STATUS] < 400`** — with OIDC on, an unauthenticated probe gets a 302 redirect (not 200).
- **Monitoring the monitor** — never its own API (OIDC 401s curl): system-health reads `/var/lib/private/gatus/gatus.db` with `sqlite3 -readonly` (sustained-failure + staleness metrics; the DynamicUser hides `/var/lib/gatus` behind the private symlink). Gatus self-prunes retention, so zero-success-ever is the sustained-failure signature.
- **Dual alert paths by design** — if PapDashboard dies, raw Discord alerts still flow (and vice versa). Every endpoint needs the `withPapIngest` custom-alert entry to reach PapDashboard (declared per-endpoint — `default-alert` does NOT auto-apply).
- **vHost is plain reverse_proxy** (native OIDC; protectedVHost would double-auth).

## Related

- [docs/agents/monitoring.md](../agents/monitoring.md) — the pattern library (pat() globs, anchored metrics checks, liveness vs health, phantom-green classes)
- [papdashboard.md](./papdashboard.md) — the ingest + insight path
- [pocket-id.md](./pocket-id.md) — client provisioning
