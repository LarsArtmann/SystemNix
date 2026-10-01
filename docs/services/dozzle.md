# dozzle (Docker container log viewer)

**Service:** `services.dozzle` — `modules/nixos/services/dozzle.nix`. Docker container (image pinned in `lib/images.nix`), port 8084 (`lib/ports.nix`), loopback bind. URL: `logs.<domain>` (**Layer 2 protected** via the registry entry). DNS `logs`.

Read-only web UI over `docker.sock` (mounted `:ro`) tailing container logs — `DOZZLE_FILTER=status=running`.

## What it serves

| Route | Auth                     | What                                   |
| ----- | ------------------------ | -------------------------------------- |
| `/`   | forward-auth / open LAN  | Container log viewer (live tail, search) |

## Ops

- **The unit is ATTACH-flavored** — `docker-dozzle.service` runs `docker compose up` ATTACHED (main process = compose). A `systemctl restart docker` kills it: ExecStop runs `compose down` (container REMOVED) and the unit lands inactive(dead) with Result=success until the next boot/deploy. **After any docker daemon restart: `sudo systemctl start docker-dozzle.service`** (detached-flavor units like twenty/manifest ride through fine — verified live 2026-08-31). Converting it to the detached flavor is the standing improvement if daemon-restart resilience matters.
- **No `--log-driver` override** — the daemon default (journald, `default-services.nix`) feeds SigNoz; an explicit json-file override here once silently removed dozzle's own logs from SigNoz (duplicate flag = json-file won). The module comment carries the warning — keep it.
- **`DOZZLE_TAILSIZE` must stay unset** — Dozzle v10.6.6 rejects unknown env vars at boot ("Unexpected environment variable"); 300 is the default anyway (removed 2026-08-31).
- **Container limits** — `--memory=256m --memory-swap=256m`, `no-new-privileges`, `cap-drop=ALL` (the socket mount is the only privilege it needs).
- **Monitoring** — Gatus "Dozzle" (200 + <500ms, registry check, 5m interval) + Homepage tile `logs`.

## Related

- [docs/agents/systemd.md#docker--containers](../agents/systemd.md#docker--containers) — attach vs detached unit flavors, daemon-restart semantics
- [signoz.md](./signoz.md) — where container logs actually land (journald pipeline)
