# CrowdSec — Security Engine (agent + LAPI)

**Status:** Stage 1 LIVE (detection only — NO bouncer/enforcement).
**Ports:** LAPI `127.0.0.1:8082` (`crowdsec-lapi`) · Prometheus `127.0.0.1:6061` (`crowdsec-metrics`)
**Module:** `modules/nixos/services/crowdsec.nix` (layers nixpkgs `services.crowdsec`, crowdsec 1.8.1)
**Adoption decision + staged plan:** `docs/planning/2026-10-14_20-25_crowdsec-nixos-study.md`

## What runs

| Unit | Shape | Notes |
| --- | --- | --- |
| `crowdsec.service` | Type=notify, Restart=always (upstream), MemoryMax 1G / High 768M | agent + LAPI + SQLite (`/var/lib/crowdsec/state/crowdsec.db`, WAL) |
| `crowdsec-update-hub.{service,timer}` | daily oneshot | **OFF** (`autoUpdateService` default false) — hub updates happen at every agent start instead |

Every start runs (in order): `crowdsec-wait-dns` (our gate, 180s budget) → `crowdsec-setup`
(unconditional `cscli hub update` + hub installs + `machine add --auto` — nixpkgs
#520206: network+DNS are REQUIRED at every start) → `crowdsec -t` config test.
A failed start is expected during a cold boot until dnsblockd is answering;
`Restart=always` + 60s delay self-heals. The gate makes the wait deterministic.

## Data sources (acquisitions)

- **sshd** via journald (`_SYSTEMD_UNIT=sshd.service`, `type: syslog`) — collection `crowdsecurity/linux`
- **Caddy access logs** via `/var/log/caddy/*.log` (JSON; covers `access.log` + every `access-<host>.log`) — collection `crowdsecurity/caddy`. The unit holds `CAP_DAC_READ_SEARCH` because the dir is `0750 caddy:caddy` and files `0600` (group membership does NOT grant reads — geometrikks 2026-10-07 lesson).

**LAN whitelist (parser s02-enrich):** `127.0.0.1`, `::1`, RFC1918 never become
alerts. This is deliberate — household clients must be un-bannable before the
enforcement stage exists. Removing entries = accepting they can be banned later.

## Ops

```bash
# agent-side cscli wrapper re-execs as the crowdsec user (needs sudo enabled):
cscli alerts list          # decisions/alerts
cscli decisions list       # active bans
cscli metrics              # parsing/acquisition throughput — VERIFY SOURCES HERE
cscli hub list             # installed collections
cscli lapi status          # LAPI up
```

Prometheus metrics: `127.0.0.1:6061/metrics` (Gatus check "CrowdSec", 1m).
LAPI has no anonymous HTTP endpoint — the metrics check is the liveness probe.

## Stage 2 — GeoMetrikks unlock (OWNER-INTERACTIVE)

1. Register a read-only bouncer for GeoMetrikks (sudo, interactive):
   `sudo -u crowdsec cscli bouncers add geometrikks` → prints the API key ONCE.
2. Paste it into `platforms/nixos/secrets/geometrikks.yaml` via `sops` (editor —
   **never on a command line**, fish_history rule). Suggested keys:
   `geometrikks_crowdsec_lapi_url = http://127.0.0.1:8082`,
   `geometrikks_crowdsec_bouncer_api_key`.
3. Wire a sops template → EnvironmentFile on `geometrikks.service` with
   `CROWDSEC_LAPI_URL` + `CROWDSEC_BOUNCER_API_KEY` (names verified upstream).
   Result: Security page + Banned-IPs map go live, `geo.home.lan/settings/status`
   flips to Enabled. Ban/unban from the UI additionally needs machine creds
   (`cscli machines add geometrikks --auto -f -` → `CROWDSEC_MACHINE_ID/_PASSWORD`).
4. Keep sops env on the GEOMETRIKKS unit (static user) — never on crowdsec's
   DynamicUser units (dynamic-user-audit class).

## Stage 3 — firewall bouncer (enforcement; NOT enabled)

`services.crowdsec-firewall-bouncer.enable = true` + `registerBouncer.enable`
(auto-registers at boot, key via LoadCredential — nothing in the store). Runs
**iptables mode** (no nftables on this host; the nftables-migration decision in
`docs/todo/security.md` flips the mode automatically if it lands). Before
enabling: review a week of `cscli alerts list` for LAN false positives; the
parser whitelist above already keeps household clients out of decisions.

## Gotchas

- **Port 6060 is NOT free** — an unidentified Go pprof listener sits on
  `*:6060` (live-probed 2026-10-14; LAN-exposed debug endpoint, finding
  reported in the 2026-10-14 crowdsec status report). Metrics = 6061.
- **Hub state is runtime-mutable** (`/var/lib/crowdsec/state/hub`): declarative
  hub lists only seed installs at start; manual `cscli hub install` drifts are
  NOT reverted. Keep hub changes declarative.
- **www.crowdsec.net / raw.githubusercontent.com must resolve+fetch** through
  dnsblockd (HaGeZi) — if hub update fails with block-page garbage, whitelist
  the domain in `platforms/common/dns-blocklists.nix` (ipify precedent).
- **SQLite WAL on the QLC root** — small and fine; decisions are ephemeral
  operational state (expire per profile 4h defaults). No backup entry by design.
