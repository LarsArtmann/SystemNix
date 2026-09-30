# dnsblockd Tracking-Dial Decision Memo (owner: Lars)

**Status:** OPEN — prepared by the max-adoption plan (M09), never to be flipped by an agent.
**The dial:** `tracking_mode` in the wrapper render block (`modules/nixos/services/dns-blocker.nix`, beside `temp_allowlist_path`).

## The decision in one line

Stay on `METADATA_ONLY` (current) or move to `METADATA_AND_DNS` so the dashboard's
domain analytics light up. This is a privacy stance, not a technical one — both modes
are fully functional at the deployed binary.

## What each mode stores (source: `internal/tracking/mode.go`, v0.9.3)

| Mode | Metadata (method, path, IP, user agent) | DNS domain + category | HTTP headers | Payloads |
|------|---|---|---|---|
| `METADATA_ONLY` (current) | ✅ | ❌ | ❌ | ❌ |
| `METADATA_AND_DNS` (proposed) | ✅ | ✅ | ❌ | ❌ |
| `METADATA_AND_DNS_AND_HEADERS` | ✅ | ✅ | ✅ | ❌ |
| `FULL` | ✅ | ✅ | ✅ | ✅ |

Both rows above the proposal exist but are **not on the table** — they add header/
payload capture with no dashboard feature we use today requiring them.

## What METADATA_AND_DNS unlocks (currently data-starved)

- **Top Domains** — the dashboard's headline table; needs the domain on each track row
- **Query Log** — per-domain drill-down
- **Likely-Broken Sites** — false-positive detection: which blocked domains do
  household devices keep retrying (the bulk-allow workflow's input)
- **Day maps / domain analytics** — per-day domain breakdown
- **Device × domain attribution** — with the device registry now declared, "which
  device queried what" becomes answerable (rows carry device id + domain)

## What it does NOT store

- No HTTP headers, no request/response payloads (two full rungs below `FULL`)
- Domain names land ONLY in the local SQLite (`/var/lib/dnsblockd/tracking.db`),
  root-readable, never exported (OTel spans carry no domain payload today)
- The `BLOCKS_ONLY` alternative (blocked events only) was considered and rejected:
  it starves Top Domains of allowed-domain data — the most valuable rows

## Cost

- Disk: one domain string per track row. Retention bounds everything (defaults,
  hourly cleanup): **tracks 30d, aggregated metrics 90d, block-rate trend 365d**
- The tracking.db hot-tier migration (docs/todo/storage.md) already accounts for growth

## Prepared flip (NOT applied — the owner applies or sanctions it)

```nix
# modules/nixos/services/dns-blocker.nix, render block:
-  tracking_mode = "METADATA_ONLY";
+  tracking_mode = "METADATA_AND_DNS";
```

**Two coupled edits required with the flip:**

1. `tests/test-dns-blocker-render.nix` asserts `tracking_mode == "METADATA_ONLY"`
   as an owner-gate regression guard — the flip must update that assertion in the
   same commit (the assertion is the guard, not an obstacle).
2. Verify after deploy: dashboard Top Domains populates within minutes;
   `GET /health` stays green; `tracking.db` growth stays within retention cleanup.

## Recommendation (agent's, non-binding)

Flip it. The marginal privacy cost is domain names in a local, root-only,
30-day-bounded SQLite on a single-user household server — and the entire
household-intelligence layer the v0.9.x line was built around is dark without it.
Revisit if the server ever gains untrusted LAN residents.
