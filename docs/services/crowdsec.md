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

- **sshd** via journald (`_SYSTEMD_UNIT=sshd.service`, `type: syslog`) — collection `crowdsecurity/linux`. **Verified healthy 2026-10-16** (an earlier "100% parse-ko" alarm was noise lines behaving correctly — retracted, docs/todo/services.md): s00-raw parses all lines OK; sshd-logs covers `sshd-session` (OpenSSH ≥9.8). CAVEATS: (a) `sshd-success-logs` hub parser still filters `program == 'sshd'` → successful logins unparsed (queued, docs/todo/services.md); (b) the journalctl source runs `-n 0` — **no backfill**: lines landing while the engine is down/restarting are never analyzed.
- **Caddy access logs** via `/var/log/caddy/*.log` (JSON; covers `access.log` + every `access-<host>.log`) — collection `crowdsecurity/caddy`. **STATUS 2026-10-16: DARK** — `PrivateUsers=true` nullifies `CAP_DAC_READ_SEARCH`, glob matches zero files (fix queued, docs/todo/services.md). The cap-vs-group note below predates that finding; group membership inside the userns is the working fix.

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

## Stage 2 — GeoMetrikks unlock (DECLARATIVE since 2026-10-16)

The key + registration are nix-managed — the old owner-interactive
`cscli bouncers add` (print-once key, manual sops paste) is GONE:

1. **Key**: `geometrikks_crowdsec_bouncer_api_key` in
   `platforms/nixos/secrets/geometrikks.yaml` (machine-generated 2026-10-16,
   sops-only; NO human has ever needed it). Rotation = change that one sops
   value via sops editor — `crowdsec-bouncer-register.service` and
   `geometrikks.service` both restart from template restartUnits and converge.
2. **Registration**: `crowdsec-bouncer-register.service` (oneshot, after
   crowdsec, before geometrikks) runs delete+add per boot so the LAPI DB hash
   ALWAYS matches the sops value (same-key re-register keeps live bouncer
   sessions valid). Graceful-skip with a warning while the sops key is absent.
3. **Consumer env**: the `geometrikks-env` template carries
   `CROWDSEC_LAPI_URL` + `CROWDSEC_BOUNCER_API_KEY` (names verified verbatim
   upstream, study doc 2026-10-14).

Remaining (NOT nix-managed): flip `geo.home.lan/settings/status` → Enabled in
the geo admin UI after the next deploy carries the units + key. Ban/unban from
the UI (stage 3) additionally needs machine creds
(`cscli machines add geometrikks --auto -f -` → `CROWDSEC_MACHINE_ID/_PASSWORD`).

sops env stays off crowdsec's own DynamicUser units (dynamic-user-audit
class): the bouncer env template renders root:root 0400 — systemd's manager
reads EnvironmentFile and injects the var, the engine process never opens it.

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
- **PrivateUsers=true makes CAP_DAC_READ_SEARCH inert (2026-10-16)** — the
  rendered unit wraps crowdsec in a user namespace, and caps held inside a
  userns do NOT apply to host inodes: the ambient cap granted for the
  0750 caddy:caddy log dir reads nothing, so the file acquisition globs
  ZERO files ("No matching files for pattern /var/log/caddy/*.log" at
  every start) and no HTTP scenarios fire. The sshd journalctl source is
  unaffected. Fix queued ([ready] docs/todo/services.md): add crowdsec to
  the caddy group (auxiliary gids map through the userns).
- **cdn-hub.crowdsec.net intermittently TLS-blocked (2026-10-15)** — two
  start attempts failed ExecStartPre (`cscli hub update` → "remote error:
  tls: internal error", dnsblockd-interception class; the 00:54 Oct 16
  download succeeded, so the block is intermittent) → service down ~2h18m.
  The gotcha above whitelists www.crowdsec.net but misses the CDN host —
  cdn-hub.crowdsec.net (+ hub-data.crowdsec.net) needs the same treatment;
  whether a hub-index flap may keep the engine offline at all is queued as
  a decision (same [ready] row).
- **SQLite WAL on the QLC root** — small and fine; decisions are ephemeral
  operational state (expire per profile 4h defaults). No backup entry by design.
