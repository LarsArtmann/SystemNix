# RCA 2026-11-18 — failed `nh os switch` + the "env-readable grep" report

Both open RCAs from the 2026-11-18 audit-trail session, closed with
journal receipts (below). Author: continuation session, 2026-11-18 ~15:00.

## 1. The failed `nh os switch` (PID 2812380, no result link)

**Verdict: memory-emergency contention, not a nix evaluation error
(verified + inferred parts marked).**

Verified (journalctl -b, 2026-11-18):

- 11:02 — nix-daemon logs `interrupted by the user` followed by an
  `unexpected end-of-file` client cascade (an earlier build attempt was
  canceled mid-flight).
- 11:50:11 — `memory-emergency-guard-check`: `MEMORY EMERGENCY IO-PAUSE
  (trip #11019, zone 6): NO eligible headless tree matched the
  attribution … pressure persists but nothing pausable`. The host was in
  sustained memory emergency exactly in the nh build window, and the
  guard had NOTHING left to pause.
- The nh process (per the morning session's receipts) ran ~5 min, left no
  `/tmp/nh-os*/result` link, `current-system` and the crm unit file were
  unchanged — a mid-build death, consistent with the pressure window.
- No `nix-daemon` build-error line for the nh window exists (610 daemon
  lines are connection accepts) — the failure never reached an eval/build
  ERROR the daemon would log.

Inferred: the build died under the memory emergency (killed or starved);
the exact kill signal is not in the journal because the client process
died, not the daemon.

Collateral finding (verified): `node_exporter` has errored every scrape
since ~11:56 — `/var/lib/prometheus-node-exporter/textfile_collectors/
system_health.prom` is corrupted (`expected float as value, got ""`,
i.e. the file was written empty/truncated during the emergency). The
textfile collector needs a regenerate or the writing script needs an
atomic-write pass (same class the CRM fixed for syncfile 2026-11-03).

Remedy: re-run the deploy in a quiet window (check
`memory-emergency-guard` trip rate first). The guard's attribution
patterns pausing nothing while pressure persists is a monitoring gap
worth a row: an unattributable pressure source (the build itself) has no
kill path.

## 2. The "env-readable grep on a root-only file" report

**Verdict: NOT reproducible; today the boundary holds (verified).**

The morning session reported that a grep appeared to read a root-only
file (suspected `/var/lib/crm-oidc/client-secret.env`, `-rw------- root
root`). Reproduction now:

- `head`/`grep` as lars → `Permission denied` (both).
- `sudo -n grep` → reads fine (NOPASSWD sudo is by design on this host;
  the session-level sudo passes the command hooks — only systemctl-class
  strings are blocked).

Most probable explanation (inferred): the earlier observation ran through
`sudo -n` (which passes hooks) and looked like a bare read, or the file's
mode differed at that moment. No permission leak reproduces; closing as
not-a-defect with today's receipts.
