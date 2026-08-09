# Session: Attic Cache Bootstrap, Deploy Fixes, and Disk Pressure

**Date:** 2026-08-02 17:07
**Branch:** master (6 commits ahead of origin/master)
**Host:** evo-x2

---


## Context

This session resumed from a prior session that completed test infrastructure
work (SearXNG VM test, statix cleanup, CI hardening). The resume brief had 7
todos focused on: fixing a SC2004 shellcheck blocker, deploying, verifying
atticd, bootstrapping the Attic binary cache, and configuring the public key.

---

## A) FULLY DONE

### 1. SC2004 Blocker — Already Fixed by Parallel Session
- The `$(( $VAR ))` → `$(( VAR ))` shellcheck error in `btrfs-health.nix`
  was already resolved by a parallel auto-commit session before this run.
- Verified: `rg '$\(\(\s*\$' btrfs-health.nix` → no matches.
- Pre-deploy checks (`nix flake check --no-build`, statix 0 warnings) all
  passed clean.

### 2. Pre-existing scheduled-tasks.nix Nix String Escaping Bug (FIXED)
- A parallel session commit (`3b26c8b9`) introduced `${before_kb:-0}` in Nix
  `''...''` strings across 5 locations in `platforms/nixos/system/scheduled-tasks.nix`.
- Nix interprets `${...}` as string interpolation, causing:
  `cannot coerce a function to a string` evaluation errors.
- **Fix:** escaped all 5 instances to `''${before_kb:-0}` / `''${after_kb:-0}` /
  `''${new_size_kb:-0}`. The auto-commit daemon picked up 4 of them; the 5th
  (`new_size_kb`, line 377) was in a different code path and only surfaced
  during full `nix eval` — caught by my `nix flake check`.
- **Root cause:** the parallel session "hardened shell scripts against empty
  pipeline results" but didn't account for Nix string interpolation syntax.

### 3. Attic Storage Directory Mount Race (FIXED)
- **Problem:** `/data` has `nofail` mount option (per AGENTS.md gotcha
  "Non-`nofail` mounts = boot hazard"). systemd-tmpfiles runs before `/data`
  mounts, creating `/data/atticd/storage` on the root filesystem (hidden
  under the mountpoint). When atticd starts with `ReadWritePaths=/data/atticd/storage`,
  systemd can't find the directory → `status=226/NAMESPACE` → crash-loop →
  `start-limit-hit`.
- **Fix:** Added `atticd-storage-dir.service` — a oneshot that runs AFTER
  `/data` mounts (`RequiresMountsFor=/data`), creates the real directory,
  and is a `wants`/`after` dependency of `atticd.service`.
- **Pattern:** same class as the DNS network interface boot race — services
  that depend on `nofail` mounts need explicit mount ordering.

### 4. atticd Running and Verified
- atticd process confirmed running (PID 1005093), listening on `127.0.0.1:8200`.
- Migrations completed: `Migrating NARs to chunks...`, `Migrating NAR schema...`,
  `Starting API server...`, `Listening on 127.0.0.1:8200...`
- Storage directory created at `/data/atticd/storage` (on the real `/data`
  partition, not root).
- **Caddy proxy verified:** `https://cache.home.lan/` returns HTTP 200 with
  the Attic HTML landing page. `http://127.0.0.1:8200/` also returns 200.
- Post-deploy smoke test: **30/30 PASS** (multiple deploys).

### 5. Attic Cache Bootstrapped — Fully Automated
- **Cache created:** `monitor365` (public cache)
- **Public key:** `monitor365:/vu56vS4pTdjoltqqqj80dJ6freEdzEEf4ugdZUPpY8=`
- **Retention configured:** 604800 seconds (7 days)
- **Bootstrap service:** `atticd-bootstrap.service` — a declarative oneshot
  that runs on every boot/deploy, creates the admin token via `atticadm`,
  logs into the local server, creates the cache (idempotent), configures
  retention, and prints cache info. No manual `sudo atticd-atticadm` needed.
- **Key implementation detail:** `atticd-atticadm` (the nixpkgs wrapper)
  uses `systemd-run` which requires root/interactive auth. The bootstrap
  service runs `atticadm` directly, sourcing the RS256 secret from the
  sops-rendered env file, and extracting the server config path from
  atticd's unit file via sed.

### 6. Public Key Configured in configuration.nix (UNCOMMITTED)
- `configuration.nix` line 220: `cachePublicKey` set to the real value.
- This enables `nix.settings.substituters` + `trusted-public-keys` so
  LAN machines can pull from the cache.

---

## B) PARTIALLY DONE

### 1. Bootstrap Service — Functional but Failing on tee (LAST RUN)
- The bootstrap service **successfully creates the cache, configures
  retention, and prints cache info to the journal** — but exits with
  status 1 because the final `tee /var/lib/atticd/cache-info.txt` fails
  with Permission denied.
- The `CapabilityBoundingSet=""` from `harden {}` strips `CAP_DAC_OVERRIDE`,
  so even as root, writing to the DynamicUser-owned `/var/lib/atticd/` fails.
- **Last edit (uncommitted):** removed the `tee` entirely — cache info now
  only goes to the journal. But this edit was NOT yet deployed (blocked by
  95% disk space).
- After the fix deploys, the service should exit 0 and stop triggering
  `onFailure` alerts.

### 2. Deploy with Public Key — BLOCKED by Disk Space
- Root filesystem at **95% (42 GiB free, 660 GiB used of 723 GiB)**.
- Pre-deploy check hard-fails on 95% usage.
- The deploy with `cachePublicKey` + `tee` fix is staged but not deployed.
- `nix-collect-garbage --delete-old` was started but killed (needs sudo
  for system-level GC; user-level GC may not be enough).

---

## C) NOT STARTED

1. **CI token generation** — after cache is live, need to generate a
   CI-scoped token (`atticadm make-token --sub ci --pull monitor365 --push monitor365`)
   and add `ATTIC_ENDPOINT` + `ATTIC_TOKEN` to Forgejo Actions secrets.
2. **monitor365/flake.nix** `extra-trusted-public-keys` — the public key
   needs to be filled in the consumer flake (line 9-12 per the resume brief).
3. **Push to origin** — 6 commits ahead of origin/master, none pushed.
4. **Squash auto-commit noise** — auto-commit daemon created several
   low-quality commits during this session (e.g., `f42fee2f` has an empty
   message).

---

## D) TOTALLY FUCKED UP

### 1. Bootstrap Service Took 4 Iterations to Get Right
- **Iteration 1:** Used `atticd-atticadm` (the nixpkgs wrapper) but forgot
  to add it to `path` → `command not found`. Should have checked the wrapper
  mechanism first.
- **Iteration 2:** Switched to `atticadm` directly but forgot `wantedBy` →
  service existed but never started. Should have included `wantedBy` from
  the start (basic NixOS service knowledge).
- **Iteration 3:** Retention period `"7 days"` wasn't shell-quoted → `attic
  cache configure` saw two args (`7` and `days`). Classic word-splitting bug.
  Should have quoted from the start.
- **Iteration 4:** `tee /var/lib/atticd/cache-info.txt` → Permission denied
  because `CapabilityBoundingSet=""` prevents root from writing to
  DynamicUser-owned dirs. Should have known this from the AGENTS.md gotcha
  about DynamicUser + sops patterns.
- **Lesson:** I debugged these one at a time across 4 deploys (~3 min each).
  I should have traced the full script mentally first — the hardening
  constraints, the PATH, the shell quoting, and the filesystem permissions
  are ALL predictable from reading the code.

### 2. Killed nix-collect-garbage Too Early
- Started `nix-collect-garbage --delete-old` to free disk space, then the
  user interrupted with the status request. I killed the GC job.
- User-level GC may not free much — the bulk of `/nix/store` garbage comes
  from system-level builds. System GC needs sudo.

---

## E) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Trace shell scripts mentally before deploying** — the 4 bootstrap
   iterations were ALL predictable from the code. PATH, quoting, hardening
   constraints, filesystem permissions — read the script as if systemd
   would execute it, catch issues on paper.

2. **The parallel session coordination is fragile** — the auto-commit daemon
   + parallel sessions create commits that break evaluation (the
   `${before_kb:-0}` Nix string escaping bug). I fixed it, but this is the
   second time a parallel session has broken `nix flake check` with
   shell-script-in-Nix-string escaping bugs.

3. **Disk space management is reactive, not proactive** — the system has
   been at 90-95% for weeks. A proactive GC timer or a disk-pressure alert
   would prevent deploy-blocking situations.

4. **The `tee` to DynamicUser-owned directory pattern should be in the
   gotchas table** — it's the same class as the Gatus LoadCredential and
   SearXNG secrets patterns. Writing files as root to DynamicUser-owned
   paths fails without `CAP_DAC_OVERRIDE`.

### Architecture Improvements

5. **The bootstrap service should be a NixOS test** — the cache creation
   flow (token → login → create → configure) is now automated but has no
   regression test. A VM test that boots atticd + bootstrap and asserts
   the cache exists would catch future breakage.

6. **`atticadm` direct invocation should be documented** — the nixpkgs
   `atticd-atticadm` wrapper needs systemd-run (root + interactive auth).
   Running `atticadm` directly with the sops env file sourced is simpler
   for automated services but isn't documented anywhere.

7. **Disk pressure should trigger Attic GC** — the `atticd-size-guard`
   restarts atticd to trigger GC, but the ROOT filesystem (not `/data`)
   is what's at 95%. These are different filesystems. The size guard only
   protects `/data/atticd/storage`, not the nix store on root.

---

## F) Up to 50 Things to Do Next

### Immediate (blocks the current deploy)

1. **Free root filesystem space** — run `sudo nix-collect-garbage --delete-old`
   or `sudo nix-env --delete-generations old && sudo nix-collect-garbage -d`
2. **Deploy with `cachePublicKey` + `tee` removal** — the staged changes in
   `configuration.nix` and `attic.nix`
3. **Verify `atticd-bootstrap.service` exits 0** — after tee removal
4. **Verify nix substituter active** — `nix config show | rg substituter`
   should list `https://cache.home.lan/monitor365`

### Cache Integration (after deploy)

5. **Generate CI token** — `atticadm make-token --sub ci --validity 365d
   --pull monitor365 --push monitor365` (needs sudo for atticd-atticadm,
   or run atticadm directly in the bootstrap-style)
6. **Add Forgejo Actions secrets** — `ATTIC_ENDPOINT` + `ATTIC_TOKEN`
7. **Fill monitor365/flake.nix** `extra-trusted-public-keys` with the
   public key (`monitor365:/vu56vS4pTdjoltqqqj80dJ6freEdzEEf4ugdZUPpY8=`)
8. **Push a test path** — `nix build .#monitor365-cli && attic push monitor365 result`
9. **Verify pull from another machine** — configure macOS or rpi3 to use
   the cache as a substituter
10. **Verify GC works** — push a path, wait 7d, confirm it's collected

### Disk Space Management

11. **Run `sudo nix-collect-garbage -d`** — delete old generations + unreachable
12. **Clean stale build sandboxes** — `sudo rm -rf /nix/var/nix/builds/nix-*`
    (13 stale dirs, 1.9 GiB)
13. **Consider a disk-pressure Gatus alert** — alert when root > 92%
14. **Audit large nix store paths** — `nix path-info -rS --all | sort -k2 -rn | head -20`
15. **Consider shrinking the nix store retention** — currently keeping
    generations from weeks ago

### Code Quality & Testing

16. **Add AGENTS.md gotcha row** for the `nofail` mount + DynamicUser
    storage race (the `atticd-storage-dir.service` pattern)
17. **Add AGENTS.md gotcha row** for `tee`/file-writes to DynamicUser-owned
    directories under `harden {}` (CapabilityBoundingSet="")
18. **Add AGENTS.md gotcha row** for `atticadm` direct invocation vs
    `atticd-atticadm` wrapper (systemd-run needs interactive auth)
19. **Write VM test for atticd-bootstrap** — assert cache exists after boot
20. **Write VM test for atticd-storage-dir** — assert the oneshot creates
    the directory after the mount
21. **Add `atticd-bootstrap` to post-deploy-check** — assert cache
    `monitor365` exists and has the expected public key

### Git Hygiene

22. **Push to origin** — 6 commits ahead, none pushed
23. **Review auto-commit `f42fee2f`** — empty commit message, investigate
24. **Consider squashing** the 4 bootstrap-fix commits into 1 logical commit

### Monitor365 Cache Integration (downstream)

25. **Configure monitor365 CI** to push to Attic after builds
26. **Test that monitor365 builds are faster** with cache hits
27. **Monitor cache hit rate** — add Attic metrics to Gatus/Overview

### Broader SystemNix Improvements

28. **Audit all services with `/data` storage** — do they all have
    `RequiresMountsFor` or an equivalent dir-creation oneshot?
29. **Add pre-deploy disk space cleanup** — `deploy.sh` could auto-run
    `nix-build-cleanup` before the disk check
30. **Consider `nix.settings.auto-optimise-store = true`** — hardlink-based
    dedup may save space
31. **Add the `atticd-bootstrap` service to the deploy.sh provisioner
    restart list** — it's a `Type=oneshot + RemainAfterExit=true` which
    `switch-to-configuration` won't restart on config change
32. **Review if `ProtectHome = false` on bootstrap is needed after removing
    `attic login`** — if the token is used inline, no config file is written
33. **Consider a read-only token for nix clients** — the current setup uses
    the substituter URL with the public key, but a pull-only token might be
    needed for non-LAN clients
34. **Document the Attic cache in README** — it's a user-facing feature
35. **Add Attic cache size to Homepage** — the metrics endpoint exists
36. **Review the `atticd-size-guard` logic** — it restarts atticd to trigger
    GC, but does it actually work under disk pressure on `/data`?
37. **Consider `attic watch-store`** — auto-push newly built paths to the
    cache (may be too aggressive for a homelab)
38. **Add a CI smoke test** that pushes and pulls a dummy path
39. **Review retention period** — 7d might be too short for weekly CI cycles
40. **Add Attic to the backup coordination module** — `/var/lib/atticd/server.db`
    (SQLite metadata) should be backed up
41. **Consider Attic HA** — not needed for homelab but document the limitation
42. **Review if the RS256 key needs rotation** — it's in sops, add it to the
    `pocket-id-secret-rotation` monitor (different mechanism but same concern)
43. **Add Attic logs to Dozzle** — the service runs under systemd, should
    appear automatically
44. **Test cache resilience** — kill atticd mid-push, verify no corruption
45. **Document the nix-cache-info endpoint** — `curl http://127.0.0.1:8200/monitor365/nix-cache-info`
46. **Review `RestrictAddressFamilies` on atticd** — nixpkgs allows AF_INET/
    AF_INET6/AF_UNIX, which is correct for localhost binding
47. **Consider adding Attic to the SSO architecture table** — it uses no
    auth (public cache), which is a deliberate decision
48. **Review if the bootstrap token validity (1h) is appropriate** — if
    atticd restarts within 1h, the token is still valid (it's in
    `~/.config/attic/server.json`)
49. **Add a Gatus check for cache push/pull** — not just the landing page,
    but an actual `nix path-info` against the cache
50. **Write a runbook** — "how to rotate the RS256 key", "how to migrate
    the cache to a new path", "how to destroy and recreate the cache"

---

## G) Questions for User

### Q1: How should I free root filesystem space?
Root is at 95% (42 GiB free). I need `sudo nix-collect-garbage --delete-old`
which I can't run (no sudo). Should you run it, or should I try an
alternative approach (user-level GC, clearing profiles, etc.)?

### Q2: Should I push the 6 unpushed commits to origin now, or wait until
the `cachePublicKey` + `tee` fix is deployed and verified?
The public key is in the uncommitted `configuration.nix` change. If I commit
it, the push would include the key. If the cache needs to be recreated (key
rotation), the committed key would be stale.

### Q3: The `atticd-bootstrap` service currently re-creates the admin token
and re-logs in on every boot (overwriting the attic client config). Should
it instead check if the cache already exists and skip the token/login
entirely? The cache creation is idempotent (`already exists` message), but
the token generation + login are wasteful on every deploy.

---

## Session Statistics

| Metric | Value |
|--------|-------|
| Commits this session | ~8 (6 pushed-ready + 2 auto-committed by daemon) |
| Deploys | 5 (4 successful, 1 blocked by disk space) |
| Post-deploy smoke tests | 5 runs (30/30, 28/2, 29/1, 30/0, blocked) |
| New services | 2 (`atticd-storage-dir`, `atticd-bootstrap`) |
| Bug fixes | 3 (scheduled-tasks escaping, storage mount race, retention quoting) |
| Files modified | 4 (`attic.nix`, `scheduled-tasks.nix`, `configuration.nix`, `gatus-config.nix` already had checks) |
| Iterations to bootstrap | 4 (PATH, wantedBy, quoting, permissions) |

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
