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

- **sshd** via journald (`_SYSTEMD_UNIT=sshd.service`, `type: syslog`) — collection `crowdsecurity/linux`. **Verified healthy 2026-10-16** (an earlier "100% parse-ko" alarm was noise lines behaving correctly — retracted, docs/todo/services.md): s00-raw parses all lines OK; sshd-logs covers `sshd-session` (OpenSSH ≥9.8). CAVEATS: (a) `sshd-success-logs` hub parser still filters `program == 'sshd'` → successful logins unparsed — hub master verified STILL unfixed 2026-10-16; route = upstream PR (verify-before-filing done), arrives via the hub update at an agent start after the merge (which needs the cdn-hub whitelist, deployed); (b) the journalctl source runs `-n 0` — **no backfill**: lines landing while the engine is down/restarting are never analyzed.
- **Caddy access logs** via `/var/log/caddy/*.log` (JSON; covers `access.log` + every `access-<host>.log`) — collection `crowdsecurity/caddy`. **STATUS 2026-10-16: fix landed in-tree, verify-pending deploy** — the RUNNING generation is still DARK (`PrivateUsers=true` nullifies `CAP_DAC_READ_SEARCH`, glob matches zero files); the fix puts crowdsec in the `caddy` group (crowdsec.nix — auxiliary gids map through the userns). Post-deploy verify: file-source hits > 0 in /metrics + one synthetic request parsed.

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

When verifying parsing health, read the NODE-LEVEL counters
(`cs_node_hits_ok_total` / `cs_node_hits_ko_total` with their stage labels),
NOT the aggregate `cs_parser_hits_*`: a 100%-ko aggregate can simply mean the
window contained only noise lines no parser should match (the 2026-10-16
false-alarm lesson — see docs/status/2026-10-16_04-16_* §d).

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

### Ban/unban machine creds (stage-3 UI unlock; staging shape, NOT landed)

The old `-f -` print-once flow is superseded by a declarative shape that
mirrors §Stage 2: pre-create `geometrikks_crowdsec_machine_password` in sops
(machine-generated 48-hex, paste inside the sops editor — no plaintext in
history), then converge per boot with
`cscli machines add geometrikks --password "$KEY" --force` (flags verified
v1.8.1 `cscli machines add --help`: `--password` replaces the print-once
flow entirely; `--force` re-adds over an existing row; `-f -` only feeds the
old interactive path). Render `CROWDSEC_MACHINE_ID=geometrikks` +
`CROWDSEC_MACHINE_PASSWORD` into the `geometrikks-env` template (rotation
restarts geo via restartUnits). Rides the stage-3 enable decision — do not
land while enforcement is off (an unused machine row is drift).

### Alert-review cadence (the stage-3 gate)

Weekly, before any stage-3 flip: (1) `cscli alerts list` — count + sources;
(2) `cscli decisions list` — anything stale/sticky; (3) scenario hit-rate
skew (`cscli metrics` → top triggered scenarios) — a LAN-only box should
show ~zero; (4) verdict line appended to
[docs/services/crowdsec-alert-review-log.md](crowdsec-alert-review-log.md).
Stage 3 unlocks after **7 consecutive clean-informed days** (window opened
2026-10-16); a single LAN false-positive resets the window.

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
  unaffected. Fix landed in-tree 2026-10-16 (crowdsec.nix extraGroups,
  verify-pending deploy): crowdsec in the caddy group (auxiliary gids
  map through the userns); the ambient cap STAYS until the group is
  proven live in /metrics, then it is a drop candidate.
- **cdn-hub.crowdsec.net intermittently TLS-blocked (2026-10-15)** — two
  start attempts failed ExecStartPre (`cscli hub update` → "remote error:
  tls: internal error", dnsblockd-interception class; the 00:54 Oct 16
  download succeeded, so the block is intermittent) → service down ~2h18m.
  RESOLUTION (2026-10-16): cdn-hub.crowdsec.net + hub-data.crowdsec.net
  whitelisted in `platforms/common/dns-blocklists.nix` (landed in-tree,
  verify-pending deploy). Hub-update stays START-FATAL by decision: the
  whitelist makes the fetch deterministic, and a real hub outage keeping
  detection down is honest — a degrade-to-warning start would leave a
  BLIND engine that gatus liveness still calls healthy. Revisit the
  fatality only if the flap recurs through the whitelist.
- **SQLite WAL on the QLC root** — small and fine; decisions are ephemeral
  operational state (expire per profile 4h defaults). No backup entry by design.
