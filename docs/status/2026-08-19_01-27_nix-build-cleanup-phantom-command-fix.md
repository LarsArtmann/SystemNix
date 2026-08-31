# Status Report: nix-build-cleanup Phantom Command Fix

**Date:** 2026-08-19 01:27
**Session scope:** Single-issue session — the user asked why `nix run .#deploy` recommends a command (`nix-build-cleanup`) that does not exist. Investigation, fix, self-review correction. Plus observations from the user's pasted deploy log (NOT investigated, per instructions).
**Host:** evo-x2 (deploy log in this session was user-run, 2026-08-19 00:23)

---

## What happened (narrative)

The user's deploy output contained:

```
⚠ 10 stale build sandboxes in /nix/var/nix/builds — run 'nix-build-cleanup' or clean manually
```

`nix-build-cleanup` is **not a PATH command**. Root cause found:

- `platforms/nixos/system/scheduled-tasks.nix:486-512` defines a `writeShellApplication` named `nix-build-cleanup` whose ONLY reference is the `ExecStart` store path of the `nix-build-cleanup.service` systemd unit (`${buildCleanup}/bin/nix-build-cleanup`). It is never added to `environment.systemPackages` or any wrapper — no user shell can run it.
- The unit itself is real and healthy in design: timer fires every 4h + 5min after boot (`scheduled-tasks.nix:86-95`), `btrfs-health.nix:503-507` adds the `btrfsGcGuard` as `ExecStartPre` (aborts when device-unallocated < 10% — metadata-ENOSPC protection), the script removes only sandboxes untouched >60min.
- `scripts/pre-deploy-check.sh:148` quoted the internal binary name as if it were a CLI the user could type. Classic lying-name pattern: the warning's remediation path was impossible to execute.

**Fix:** warning now recommends `sudo systemctl start nix-build-cleanup.service` (the real invocation path, guard included, age-safe) and explicitly warns against blind `rm -rf`.

### Self-review correction (important)

My FIRST version of the fix was itself flawed — I appended a "manual" fallback: `sudo rm -rf /nix/var/nix/builds/nix-*`. That command has **no age guard**: run while a build is in flight (deploys run 13+ min here), it deletes LIVE sandboxes and kills the build. The unit's own script deliberately filters `-mmin +60`. Caught it during this self-review, removed the fallback entirely — the `systemctl start` path is strictly better and safe. Lesson: when transcribing a "manual" remediation, preserve ALL safety filters of the automated path, or don't offer it.

---

## a) FULLY DONE

1. **Root-caused the phantom command** — traced `nix-build-cleanup` from the warning to its only existence: an inline `writeShellApplication` inside the systemd unit's `ExecStart` (scheduled-tasks.nix:512). Confirmed via `command -v` → not on PATH.
2. **Mapped the full wiring** — service unit, 4h+boot timer, `btrfsGcGuard` ExecStartPre gating in btrfs-health.nix:503, `onFailure` notification, `>1h` mmin filter semantics.
3. **Fixed `scripts/pre-deploy-check.sh:148`** — warning now points to `sudo systemctl start nix-build-cleanup.service` with an explicit "do NOT rm -rf blindly" guard note.
4. **Self-review caught and fixed my own dangerous fallback** (the unguarded `rm -rf`) — final message verified below.
5. **Verified** — `bash -n` syntax check passes; warning branch simulated with STALE_BUILDS=10 and =0 (both behave correctly).
6. **Swept `scripts/` for the same class of bug** — no other script recommends non-runnable internal binary names.

## b) PARTIALLY DONE

1. **The 10 stale sandboxes are still on disk** — remediation needs root (`sudo systemctl start nix-build-cleanup.service`); systemctl is blocked in agent sessions. User action pending.
2. **Historical references not touched** — `docs/gotchas-archive.md:62` and ~40 status reports (mostly archived) still say "run `nix-build-cleanup`" / recommend the unguarded `rm -rf /nix/var/nix/builds/nix-*`. Deliberately left: history docs are point-in-time. But gotchas-archive is a LIVING reference — its `rm -rf` line has the same live-build hazard and should get the same age-guard caveat (next-up list).

## c) NOT STARTED

1. **End-to-end re-run of `pre-deploy-check.sh`** — only the edited branch was simulated, not the full script through all 12 sections.
2. **shellcheck on the edited script** — not run (not in the repo's pre-commit pipeline; `bash -n` only catches syntax).
3. **AGENTS.md memory note** — the generalizable lesson (never quote `writeShellApplication` internal names as user commands; manual remediations must preserve the automated path's safety filters) is not yet in the project memory.
4. **Investigation of the timer's effectiveness** — 10 stale sandboxes existed despite a 4h timer; plausible causes (sandboxes <1h old at check time, guard abort due to disk state, nix-gc ecosystem failing) NOT distinguished — needs root/systemctl access.

## d) TOTALLY FUCKED UP

Nothing catastrophic, but two honest mistakes this session:

1. **First fix shipped a dangerous manual command** (unguarded `sudo rm -rf /nix/var/nix/builds/nix-*`) — could have killed in-flight builds if the user had run it during a deploy. Caught in self-review, fixed before this report. This is exactly the class of error the fix was supposed to prevent: a remediation that sounds right but lies about safety.
2. **Initial sweep was too narrow** — first grep pass was repo-wide but my actionable sweep only covered `scripts/`; the gotchas-archive living-doc reference (same hazard) was seen in results and consciously deferred rather than flagged as part of the fix's blast radius.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-deploy warnings must be executable** — every `run 'X'` in check scripts should reference a command that exists on PATH or a documented systemd invocation. A warning whose remediation is impossible is noise that trains the user to ignore warnings.
2. **Preserve safety filters in manual remediations** — any "or clean manually" text must carry the same guards as the automated path (age thresholds, mount checks). Unguarded `rm -rf` in advice text is a landmine (gotchas-archive:62 still has one).
3. **Add shellcheck to the lint pipeline** — `scripts/*.sh` (pre/post-deploy checks are safety-critical gate tooling) currently get zero static analysis; `.githooks/pre-commit` lints only .nix. A missed quoting bug in deploy gating is a deploy-blocker for everyone.
4. **Consolidate stale-sandbox knowledge** — the nix-build-cleanup story is spread across scheduled-tasks.nix, btrfs-health.nix, gotchas-archive, and dozens of status reports with evolving facts (interval changes, permission fixes, guard additions). The living docs should carry ONE canonical paragraph.
5. **Agent sessions cannot verify systemd state** — systemctl is blocked; I could not check whether the timer ran recently, why 10 sandboxes persisted, or whether nix-gc's failure shares the btrfs-guard abort root cause. A read-only allowlist (`systemctl status/list-timers`, `journalctl -u <unit>`) would let sessions close loops like this without user round-trips.

## f) NEXT UP (prioritized)

1. **User runs:** `sudo systemctl start nix-build-cleanup.service` — clears the 10 sandboxes (age-safe, guard-gated).
2. Fix `docs/gotchas-archive.md:62` — add the live-build age-guard caveat to the manual `rm -rf` line (same hazard I shipped and reverted).
3. Investigate why the 4h timer left 10 sandboxes: `systemctl list-timers nix-build-cleanup*` + `journalctl -u nix-build-cleanup.service -n 50` (guard abort vs. young sandboxes vs. unit failure).
~~4. Investigate `nix-gc.service` FAILED (from deploy log) — likely `btrfsGcGuard` abort at <10% device-unallocated → ties into the P0 /data EIO / disk crisis (TODO_LIST P0).~~ done — root-caused 2026-08-21 (the %-gate GC deadlock); guard re-based on absolute 5 GiB floor + META>90
~~5. Investigate `activitywatch-data-to-pool.service` FAILED (from deploy log) — the one-shot migration keeps failing post-deploy restarts.~~ done — migration completed verified 2026-08-18/19 (self-neutralizing unit)
~~6. Investigate smoke FAIL **Bank-Sync body lacks "Bank-Sync Dashboard"** (`:8097` answers, `/metrics` passes, Wise data present) — started right after flake bump `c888f497` (bank-sync 7cd756f). Upstream repo fix per AGENTS.md policy, not a SystemNix patch.~~ done — resolved via the bank-sync upstream chain (SCA/wise-go fixes); bank-sync checks PASS in the 2026-08-31 83/0 run
7. Investigate smoke FAIL **Pocket ID SQLITE_BUSY in recent journal** — per AGENTS.md this is known discordsync-IO-storm collateral; verify it's still that and not a new source (paperless PG migration era is over).
8. Add AGENTS.md gotcha entry: "pre-deploy check warnings must reference runnable commands; internal writeShellApplication names are not commands" (this session's lesson).
9. Add shellcheck to pre-commit/CI for `scripts/*.sh`.
10. Run full `pre-deploy-check.sh` once to confirm end-to-end health after the edit.
11. Consider adding `nix-build-cleanup` (or a `systemd-run`-style alias) to root's PATH via `environment.systemPackages` if manual invocation is a recurring need — better than editing advice text each time.
~~12. Monitor365 metrics endpoint (`:9191`) down in pre-deploy — expected while service is disabled, but the check could auto-skip on disabled units instead of warning (it does for others).~~ done — Monitor365 auto-SKIP when disabled is live (pre-deploy-check §9 gate)
13. The 6 `vendorHash freshness — unable to determine status` warnings in pre-deploy check #11 — the check can't see through mkLarsPackages' indirection; worth wiring or silencing deliberately.
14. Two "ExecStart binary not built yet" warnings (network-local-commands, pocket-id-provision) — known-benign pre-build state, but the check could label them SKIP instead of WARN.
15. `/data` EIO corruption repair (pre-existing TODO_LIST P0) — upstream cause of `btrbk-data` aborts; unblocks nix-gc health too.
16. Root-disk at 91% (64G free) — trending toward the 15G warn threshold; revisit after sandbox cleanup + nix-gc recovery.
17. DMS/quickshell journal shows 1 error line in the last hour (WARN in smoke) — quick look next session.
18. File Renamer dashboard shows 0 operations (WARN) — split-brain or fresh-install; unresolved from prior sessions.
19. PapDashboard "no ingest 200s in last 30 min" WARN — expected when no alert transitioned; consider re-checking after a deliberate test alert to prove the pipeline end-to-end.
20. `activitywatch-data-to-pool` keeps getting restarted by deploy.sh post-switch — if the migration is wedged (item 5), each deploy re-fails it; self-neutralize or fix.

## g) QUESTIONS (cannot figure out myself)

1. **Is the `nix-gc.service` failure known-blocked by the disk P0?** Root-level `journalctl -u nix-gc` is blocked for me. If it's the btrfs-guard abort at <10% device-unallocated, I'll treat it as tracked by the TODO_LIST P0 (disk crisis) and not open a duplicate investigation. Has the /data EIO repair been scheduled?
2. **Bank-Sync dashboard body regression after the `7cd756f` bump — known or new?** The smoke says the port answers and Wise data exists, only the HTML title check fails. Should a session dig into the upstream bank-sync repo (per the "fix application bugs upstream" policy), or is this already being handled by whoever drove commit `c888f497`?
3. **Should `nix-build-cleanup` (and similar unit-internal scripts) be exposed as real CLI commands for root?** One-line `environment.systemPackages` addition vs. keeping advice pointing at `systemctl start`. Preference?

---

**Session verdict:** small bug, real fix, one self-caught safety mistake, clean verification. The deploy-log items (bank-sync body, pocket-id SQLITE_BUSY, activitywatch migration, nix-gc) are NOT investigated — they are logged above as next-up work.
