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

- **sshd** via journald (`_SYSTEMD_UNIT=sshd.service`, `type: syslog`) — collection `crowdsecurity/linux`. **Verified healthy 2026-10-16** (an earlier "100% parse-ko" alarm was noise lines behaving correctly — retracted, docs/todo/services.md): s00-raw parses all lines OK; sshd-logs covers `sshd-session` (OpenSSH ≥9.8). CAVEATS: (a) `sshd-success-logs` hub parser still filters `program == 'sshd'` → successful logins unparsed — hub master verified STILL unfixed 2026-10-16; route = upstream PR #1943 (verify-before-filing done) **+ IN-TREE PATCH-APPLY LIVE 2026-10-16 (crowdsec.nix `pr1943Parser`; deployed + engine-proven: cscli reports the item local, `cs_parser_hits_total{source="journalctl-_SYSTEMD_UNIT=sshd.service"}` accumulating real login hits)**: the PR's parser (fetchurl @ branch head 99985ff6, byte-verified) is re-pointed over the hub item's install symlink by an ExecStartPre at EVERY engine start (switch-to-configuration never runs tmpfiles — boot-only rules were inert); the content mismatch marks the item TAINTED and cscli never clobbers tainted items on install/upgrade without `--force` (source-verified v1.8.1 pkg/cwhub/sync.go) — REMOVE the override when PR #1943 merges (the hub file then equals the PR and cscli's install keeps it); (b) the journalctl source runs `-n 0` — **no backfill**: lines landing while the engine is down/restarting are never analyzed.
- **Caddy access logs** via `/var/log/caddy/*.log` (JSON; covers `access.log` + every `access-<host>.log`) — collection `crowdsecurity/caddy`. **STATUS 2026-10-16: three-layer fix, verify-pending deploy #2** — layer 1 group (crowdsec in `caddy`, `id crowdsec`-verified); layer 2 file mode (caddy vhost logFormat `mode 0640` — CREATE-only: open(2) never re-modes, so pre-override 0600 files stay unreadable; `crowdsec-caddy-logs-readable` re-modes them — its first build interpolated the writeShellApplication DERIVATION (a directory) as ExecStart → 203/EXEC every 5 min from 16:27, fixed to the bin/ executable); layer 3 convergence (crowdsec ExecStartPre `+`-privileged chmod BEFORE engine start — a failed tail setup DROPS the source for the process lifetime, and a running engine does not retry, see the gotcha below). Post-deploy verify: `cscli metrics` Acquisition table carries the caddy source + file-source hits > 0 in /metrics + one synthetic request parsed.

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
  NOT reverted. Keep hub changes declarative. Same-name local OVERRIDES of hub
  parsers are the designed safe path: a content-mismatched install-symlink
  target marks the item **tainted** and cscli never overwrites tainted items
  on install/upgrade without `--force` (source-verified v1.8.1
  pkg/cwhub/sync.go) — the sshd-success-logs PR #1943 patch-apply
  (`pr1943Parser` in crowdsec.nix) rides exactly this; the ExecStartPre
  re-asserts the link at every engine start, so a clobbered link self-heals.
  PLATFORM TRAP (2026-10-16): switch-to-configuration NEVER runs
  systemd-tmpfiles on this NixOS — a tmpfiles rule is boot-only and inert
  after a plain deploy switch; runtime-managed file replacement must ride
  the unit itself (ExecStartPre/preStart) or a boot.
- **www.crowdsec.net / raw.githubusercontent.com must resolve+fetch** through
  dnsblockd (HaGeZi) — if hub update fails with block-page garbage, whitelist
  the domain in `platforms/common/dns-blocklists.nix` (ipify precedent).
- **PrivateUsers=true makes CAP_DAC_READ_SEARCH inert (2026-10-16)** — the
  rendered unit wraps crowdsec in a user namespace, and caps held inside a
  userns do NOT apply to host inodes: the ambient cap granted for the
  0750 caddy:caddy log dir reads nothing, so the file acquisition globs
  ZERO files ("No matching files for pattern /var/log/caddy/*.log" at
  every start) and no HTTP scenarios fire. The sshd journalctl source is
  unaffected. Fix is THREE-layered (2026-10-16): crowdsec in the caddy
  group (extraGroups; auxiliary gids map through the userns — `id crowdsec`
  verified live) + caddy logFormat `mode 0640` on CREATE + a root chmod
  pre-start/timer for pre-existing 0600 files; the ambient cap STAYS until
  file-source hits are proven live in /metrics, then it is a drop candidate.
- **A failed file-source setup is dropped for the engine's LIFETIME
  (2026-10-16)** — crowdsec attempts the acquis glob ONCE at start; a
  permission failure at that moment drops the source with no retry until
  the next restart (the 08:14 process served sshd-only through generations
  910→912). Corollaries: (a) put any access-heal BEFORE engine start
  (crowdsec ExecStartPre `+`-chmod, caddy-logs-hot pattern), (b) `cscli
  metrics` Acquisition table is ground truth for which sources are LIVE —
  zero tail errors in the journal means nothing when the source never
  registered, (c) an engine restart only happens when the crowdsec UNIT
  content changes — a fix that touches only timers/filesystems leaves a
  running engine dark indefinitely.
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
- **Bump drill (nixpkgs crowdsec > 1.8.1)** — when the module/package moves
  past 1.8.1, re-audit ALL THREE local mitigations against the new module
  before trusting the flip: (1) the tmpfiles rootDir rule (upstream may
  have added it — remove ours), (2) the machine-repair orphan delete
  (upstream setup may be idempotent now), (3) the caddy-group acquis fix
  + the ambient cap drop candidate, and (4) the bouncer-register flags
  (`bouncers delete --ignore-missing` / `add --key`) against the new
  cscli. Also re-check PrivateUsers: if upstream drops it, the cap route
  becomes viable again and the extraGroups comment needs a truth-sync.
