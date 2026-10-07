# GeoMetrikks zero-ingestion root cause: AmbientCapabilities never granted (2026-10-07 12:35)

**Verdict: FIXED IN-TREE, DEPLOY-GATED.** GeoMetrikks has ingested **zero events since the
2026-09-29 native flip** — not because of Caddy, not because of MaxMind, but because the
service unit never actually held the capability it was configured to use.

## Symptom (user question: "why can't Geometrikks read data from Caddy?")

- UI Logs page: `GET /api/v1/logs/files` → HTTP 500, litestar traceback
  `PermissionError: [Errno 13] Permission denied: '/var/log/caddy/access.log'`
  (`geometrikks/services/logfiles.py:97` → `Path.is_file()` → `os.stat()`; pathlib ignores
  ENOENT/ENOTDIR but propagates EACCES) — repeated 12:28–12:30, 2026-10-07 journal.
- Ingestion: `Started log ingestion service (74 files, …)` then
  `Stopped log ingestion service. Total processed: 0` — across every run since the
  GeoLite2 DB landed (first successful start 2026-10-07 02:01). The tailer swallows
  per-file `OSError` (logparser.py:445/680/718), so the data plane dies SILENTLY while
  `/health/ready` stays 200 — exactly the dead-pipeline class queued as the data-plane
  Gatus check.

## Root cause chain

1. Caddy logs are foreign-owned to the service: `/var/log/caddy` is `drwxr-x--- caddy:caddy`
   (now the Samsung hot-tier subvol, 2026-10-04 — ownership semantics unchanged), access
   logs `0600 caddy:caddy`; `geometrikks` (uid 958) is neither owner nor in group `caddy`,
   and group membership would not help against `0600` anyway.
2. The unit (native migration, 2026-09-29) set ONLY
   `CapabilityBoundingSet = "CAP_DAC_READ_SEARCH"` with `User=geometrikks` (non-root).
3. **`CapabilityBoundingSet` only LIMITS; it grants nothing to a non-root `User=`.**
   `AmbientCapabilities` is the grant. The deployed unit has no `AmbientCapabilities=`
   line (verified against `/etc/systemd/system/geometrikks.service`), so the process runs
   with an EMPTY effective capability set and every `stat`/`open` on the logs EACCESes.
4. This repo already learned the lesson on 2026-09-06 (mail-relay textfile collector —
   `modules/nixos/services/mail-relay.nix` "AmbientCapabilities (NOT just the bounding
   set!)"). The geometrikks module comment cited the "cv-backup precedent" — a FALSE
   analogy: cv-backup runs as root, where the bounding set alone does grant.

## Why it surfaced only now

- 09-29 → 10-06: ingestion never STARTED (GeoLite2 mmdb missing, `Cannot start ingestion`
  on every restart) — the missing-MaxMind-keys blocker masked the read blocker behind it.
- 2026-10-06 22:08 deploy: MaxMind keys pasted → GeoLite2 downloads → ingestion STARTS
  (74 files) → the permission failure becomes the live blocker (0 events, 500 on the logs
  endpoint the moment someone opens the UI Logs page — today).

## Fix (this session)

`modules/nixos/services/geometrikks.nix`: `AmbientCapabilities = "CAP_DAC_READ_SEARCH"`
added beside the existing `CapabilityBoundingSet` in the `harden{}` call (harden passes
unknown keys through), comment corrected (mail-relay lesson, cv-backup analogy noted as
root-only). Runbook (`docs/services/geometrikks.md` Logs bullet) corrected — it also
claimed `ProtectSystem=strict`, the deployed unit renders `full` (harden default).

## Verification

- Live evidence: journal PermissionError + `Total processed: 0` lines quoted above;
  deployed unit file grep (no AmbientCapabilities).
- In-tree: `nix eval` of the rendered unit asserts `AmbientCapabilities` +
  `CapabilityBoundingSet` (run post-edit, see command output in session).
- Post-deploy (owner runs `nix run .#deploy`): journal must show ingestion with
  processed events > 0, `/api/v1/logs/files` → 200, map populates. The queued
  geometrikks smoke-probe row was extended on BOTH surfaces (TODO_LIST + services.md)
  to assert exactly this.

## Follow-ups

- Smoke-probe extension harvested into the existing `[ready]` rows (not new rows).
- The data-plane Gatus check row (fail-closed on event-count delta) remains the durable
  guard for this class — today proved `/health/ready` 200 + `ingestion_started` is
  compatible with a totally dead pipeline even AFTER the mmdb blocker cleared.
