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

## ADDENDUM 2026-10-07 ~16:40 — DEPLOYED + LIVE-VERIFIED (same-day execution session)

The owner's "execute until done" instruction answered the report's three open
questions: deploy now (yes), eval-time audit (built), file upstream pre-deploy (done).

- **Deployed & anchored**: generation `system-837` == `/run/current-system`; deployed
  unit carries `AmbientCapabilities=CAP_DAC_READ_SEARCH` beside the bounding set.
- **Kernel-verified grant**: live process `CapEff=0x4` (CAP_DAC_READ_SEARCH effective,
  CapBnd matches) — not just the rendered unit.
- **Pipeline alive**: 61 files logging `Streaming log file events (async)` — the exact
  step that EACCES-died for 8 days; ZERO `does not exist` mislabels, ZERO
  PermissionError, ZERO HTTP 500s since the switch; `/health/ready` `{"ready":true}`.
- **Correction to this report's evidence section**: the "tailer silently swallowing
  per-file OSError" reading was WRONG — v0.19.0 logs every unreadable file at ERROR as
  `Log file does not exist: … - waiting for it to appear` (370 lines on 10-07 alone,
  every restart; `access.log` itself reported "does not exist" 5× while producing
  Errno 13 on the HTTP path). The silence was a diagnosis-grep artifact (this session
  grepped for read errors, not existence messages). Upstream filed as GilbN/geometrikks#302
  (EACCES mislabeled "does not exist"); companion issue #301 (`/api/v1/logs/files` 500
  on EACCES, `_entry()` catches the stat but line-97 `is_file()` re-raises).
- **Strict `processed > 0` counter**: not observable at info level pre-shutdown —
  surfaces at the next ingestion restart's stop line or tonight's nightly backup;
  the streaming + zero-error evidence above is the strongest journal-accessible proof.
- Same-session additions: `modules/nixos/services/capability-grant-audit.nix`
  (eval-time class audit, 4-leg proven, zero current offenders) +
  `checks.x86_64-linux.geometrikks-caps` (render pin, 5 cases) — details in CHANGELOG.
- Deploy note: three switch attempts — (1) aborted at the I/O-pressure gate
  (sustained PSI from parallel sessions; devices measured idle ≤15% util, override
  `DEPLOY_FORCE_PRESSURE=1` justified on evidence), (2) first switch activated but the
  profile anchor lagged (UNANCHORED warning; the script's own re-run remedy), (3) the
  re-run failed on a SHARED-toplevel blocker: the parallel wave4 lock move put cv at
  `cdac11b` whose upstream-baked vendorHash is stale (new go deps download → FOD
  mismatch). Fixed by the sanctioned pin-only move
  `nix flake lock --override-input cv github:LarsArtmann/cv/b3a9172f46c3e88a263618c1385e213ac2cd0c82`
  (the wave-verified-good rev; discordsync-rollback precedent) — cv upstream needs a
  hash re-bake before the pin can advance again (queued in docs/todo/pipeline.md).
