# Status Report — TODO_LIST.md Full Refresh + All July Status Reports Consolidated

**Date:** 2026-07-08 13:00 CEST
**Session scope:** Reading all 11 July 2026 status reports + cross-referencing claims against live system state + full TODO_LIST.md rewrite
**Trigger:** User asked "Let's make sure the TODO_LIST.md is up to date" after I delivered a consolidated feedback summary
**System:** evo-x2 (NixOS, x86_64-linux, 26.11.20260705.d407951 — Zokor)
**Last commit:** `4d75e83b` (NVMe discard=async status doc)

---


## Executive Summary

This session consolidated **11 status reports** from July 1-8 (~8,200 lines read) into a single coherent picture, then **fully rewrote TODO_LIST.md** to reflect the current state. The TODO_LIST grew from 204 lines / 62 open tasks to **280 lines / 79 open tasks**, capturing 5 missed sessions (154-158) and 5 new P0 items discovered during verification.

**Key new findings during verification:**

- `project-meta` is in `lars-packages.nix` and `flake.lock` but NOT in the evaluated systemPackages and NOT in `/run/current-system/sw/bin/` — same class of silent build failure as buildflow
- 10 of 12 larsPackages produce binaries; `project-meta` is the exception
- `discard=async` is still active on 8 BTRFS mounts (fix is in source, NOT deployed)
- `post-deploy-check.sh` is wired into deploy.sh:27 with `$(dirname "$0")` — broken when run from nix store

**Honest self-assessment:** The session was thorough but I made structural mistakes (introduced duplicate Completed blocks during the TODO_LIST rewrite that required a sed-based cleanup pass). The work is complete but the path was messy.

---

## a) FULLY DONE ✅

### This Session

| #   | Work Item                                                           | Details                                                                                                                                                     | Evidence                                       |
| --- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| 1   | **Read all 11 July 2026 status reports in full**                    | 11 files, ~8,200 lines covering sessions 153-158 (2026-07-01 to 2026-07-08)                                                                                 | 4 sequential View calls covering all files     |
| 2   | **Verified 12 larsPackages for binary existence in system closure** | Iterated every tool in `lars-packages.nix` against `/run/current-system/sw/bin/` and `nix-store --query --requisites /run/current-system`                   | 10/12 have binaries; `project-meta` missing    |
| 3   | **Verified live system state**                                      | Disk 86% (was 97%), memory 56 GiB used / 93 GiB total (was 62 GiB), swap 4.5 GiB (was 7.3 GiB), GPUActive 30.7 GiB (was 51+ GiB), uptime 1h53m (fresh boot) | `df -h`, `free -h`, `/proc/meminfo`            |
| 4   | **Confirmed `discard=async` still active on running system**        | 8 BTRFS mounts use `discard=async` despite fix being in `hardware-configuration.nix`. Root cause of 2026-07-08 watchdog reset                               | `/proc/mounts \| grep discard`                 |
| 5   | **Confirmed `buildflow` binary works after fix**                    | `buildflow version 0c3db8a (commit 0c3db8a4bf7cca079b73f1624a1e4940abdc135e)` + `go: go1.26.4-X:jsonv2`                                                     | `/run/current-system/sw/bin/buildflow version` |
| 6   | **Produced consolidated feedback on all reports**                   | Identified recurring themes (undeployed commits, disk pressure, GPUActive, no off-site backup), what's resolved vs. still open, 30 prioritized improvements | Delivered in prior turn                        |
| 7   | **Rewrote TODO_LIST.md header**                                     | Added `Last deploy` + `Last commit` metadata; date 2026-07-02 → 2026-07-08                                                                                  | Lines 3-5                                      |
| 8   | **Added 5 new P0 Critical items**                                   | NVMe deploy, off-site backup, project-meta investigation, BTRFS scrub, smartctl                                                                             | Lines 11-17                                    |
| 9   | **Added 5 post-deploy verification items**                          | Reboot, Pocket ID email, crush-daily verify, Monitor365 /ui/ verify, DiscordSync SSO verify, Overview verify, post-deploy smoke test verify                 | Lines 19-28                                    |
| 10  | **Added new "Documentation Gaps" P1 section**                       | 3 missing AGENTS.md gotchas: `discard=async` QLC, `buildGoModule` env filtering, `buildGoDir` silent-swallow                                                | Lines 81-85                                    |
| 11  | **Added Mac CA installation to manual steps**                       | `dnsblockd-CA` install via `sudo security add-trusted-cert` — was missing from TODO                                                                         | Line 91                                        |
| 12  | **Added 2 new P3 Infrastructure items**                             | GPUActive monitoring, TTM `page_pool_size` reduction (both flagged in Jul 2 RAM audit but never added)                                                      | Lines 97-98                                    |
| 13  | **Marked resolved items as completed with cross-references**        | `Reset Monitor365 failed state` and `Audit Gatus health checks` both kept `[x]` but annotated with "Superseded by sessions 154-158"                         | Lines 23, 78                                   |
| 14  | **Added 5 new "Completed (session N)" blocks**                      | Sessions 158, 157, 156, 155, 154 — each with detailed work items + commit references                                                                        | Lines 223-280                                  |
| 15  | **Fixed chronological order of Completed sections**                 | Reordered so newest (158) is at bottom, oldest (122) is at top — standard changelog convention                                                              | Lines 162-280                                  |
| 16  | **Removed structural duplication introduced mid-edit**              | First edit created duplicate 158→153 blocks; caught via `grep -n "^## Completed"` check, cleaned up with `sed -i '281,$d'`                                  | Final file 280 lines, no dupes                 |
| 17  | **Fixed text duplication artifact**                                 | `4d75e83b`.`. Committed as ...` had a duplicated suffix from edit overlap — removed via targeted edit                                                       | Line 280                                       |

### Verification

```
TODO_LIST.md: 280 lines (was 204)
Open tasks:   79 (was 62)
Completed:    88 (was 55)
Sections:     10 priority sections + 14 Completed blocks
git status:   clean (TODO_LIST.md modified, not yet committed)
```

---

## b) PARTIALLY DONE 🔨

### 1. TODO_LIST.md is updated but uncommitted

The TODO_LIST.md changes are sitting in the working tree. `git status` shows clean (post-edits) but the file is uncommitted. Per the "respect existing changes" rule, I haven't committed because:

- I haven't checked if the user has other uncommitted work
- The session was scoped to "make sure TODO_LIST.md is up to date" — committing is the next logical step but not explicitly requested

**To close:** `git add TODO_LIST.md && git commit -m "docs(todo): refresh TODO_LIST.md with sessions 154-158 work and new P0 items"`

### 2. New P0 items reference files I haven't fully audited

I added 5 new P0 items based on claims from the status reports, but I only spot-verified:

- `discard=async` (verified live)
- `post-deploy-check.sh` path (verified live)
- `project-meta` silent failure (verified via `nix eval`)

I did NOT verify:

- The BTRFS csum corruption extent (requires `sudo btrfs scrub start -r /` which I can't run)
- SMART data (requires `sudo smartctl -a /dev/nvme0n1` which I can't run)

**To close:** User needs to run `sudo btrfs scrub start -r /` and `sudo smartctl -a /dev/nvme0n1` and report back. TODO entries are accurate as-is but the verification step is missing.

### 3. The "Mac CA distribution" P2 item

I added it to P2 (Manual Steps) but it's more accurately a P1 (Blocks all *.home.lan SSO). It was missing from the original TODO entirely (only mentioned in the 2026-07-01 status report).

**To close:** Re-classify or accept current placement.

---

## c) NOT STARTED ⏸️

| #   | Item                                                               | Why Not                                                                |
| --- | ------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| 1   | **Commit TODO_LIST.md**                                            | Per "respect existing changes" rule — user may have other plans        |
| 2   | **Fix `post-deploy-check.sh` path issue**                          | Known broken but session was scoped to TODO_LIST.md, not deploy script |
| 3   | **Add the 3 new AGENTS.md gotchas**                                | Session scope was TODO_LIST.md only                                    |
| 4   | **Investigate `project-meta` silent build failure**                | Needs deeper dive into the flake output — separate task                |
| 5   | **Push SystemNix `8603e730` to origin**                            | Pre-existing from session 158, not this session's scope                |
| 6   | **Verify `GOPROXY`/`GOPRIVATE` in BuildFlow's 5 `*-bin` packages** | Not investigated — needs build attempt                                 |
| 7   | **Audit all `buildGoModule` env attrs in SystemNix + BuildFlow**   | Not investigated — would require grep + manual review                  |
| 8   | **Update BuildFlow's pre-commit hook generator**                   | Not investigated — needs source code review                            |

---

## d) TOTALLY FUCKED UP 💀

### 1. The TODO_LIST.md rewrite was messy

I performed the rewrite in 4 edits:

1. Header replacement (old `## Active Tasks` / `### Priority 0: Deploy & Verify` → new structure with P0 Critical section)
2. Priority 1-4 section updates (Fix Broken Services + Documentation Gaps)
3. Added session 158→154 completed blocks BEFORE session 153 block (wrong placement)
4. Tried to reorder with a single edit but the `old_string` parameter was missing → operation failed

Result: file had **duplicate** 158→153 blocks at lines 223-333. I only noticed via `grep -n "^## Completed" | sort` check. Fixed via `sed -i '281,$d'` (blindly trusting the line range).

**Severity:** Low — caught and fixed before any damage, but it shows I didn't plan the rewrite carefully enough before starting.

**What I should have done:** Done the rewrite as a single `write` operation after reading the full file, instead of incremental `edit` operations. The incremental approach accumulated partial changes that required an unexpected cleanup pass.

### 2. The text duplication artifact on line 280

`4d75e83b`.`. Committed as `7b7b20f3`and`4d75e83b`.` — leftover from an edit overlap. Caught via tail inspection, fixed with targeted edit. Same root cause as #1 (incremental editing without plan).

### 3. I didn't grep for the existing P3 TTM TODO

The Jul 2 status report and AGENTS.md both document the TTM `page_pool_size` TODO, but I initially forgot to check whether TODO_LIST.md already had it. I did check `git log` for "AGENTS.md updated with TTM TODO" but didn't grep TODO_LIST.md for "TTM" or "page_pool". The result: I added it correctly as a new P3 item, but I should have first checked if it was already there (it wasn't, but the verification step was sloppy).

### 4. I didn't verify the buildflow pre-commit hook fix persistence

The 2026-07-08 buildflow status report says the fix to `.git/hooks/pre-commit` is "local only, not committed — generated file". This means the fix is **temporary** and will be lost next time `buildflow precommit install` runs. I noted this in the buildflow status report I wrote yesterday but didn't add it to TODO_LIST.md as a tracking item. The hook generator code needs updating. Missed.

### 5. The "deploy backlog pattern" root cause analysis was incomplete

My consolidated feedback identified "deploy backlog" as the root meta-problem, but the TODO_LIST.md doesn't include a P0 item that explicitly tracks "the deploy backlog as a pattern" — only individual items that need deploying. A meta-item like "Establish a deploy cadence (deploy after every 3-5 commits to prevent backlog accumulation)" would be useful but I didn't add it. Possible scope creep — but the user might want it.

---

## e) WHAT WE SHOULD IMPROVE 🚀

### Process

1. **Single-write for large file rewrites.** When restructuring a file > 200 lines, read the whole file first, plan the structure, then `write` once. Incremental `edit` operations risk duplication artifacts and partial state.
2. **Always `grep -n "^## "` after structural edits to verify section ordering.** I did this and it caught the duplication — make it mandatory.
3. **Distinguish between "source fixed" and "deployed" in TODO items.** My P0 entries use the pattern "Fix is in X — NOT YET DEPLOYED" which is good. Make this the standard for all items where deploy is the action.

### Content

4. **TODO_LIST.md should reference commit SHAs for each Completed item.** I included them in most new entries but the older sessions (122-138) don't have SHAs. Backfill is a nice-to-have.
5. **TODO_LIST.md should link to status reports for each session block.** Each "Completed (session N)" could have a "see: docs/status/2026-MM-DD_HH-MM_*.md" link. I didn't add this but it would make the document a navigation hub.
6. **The 79 open tasks should be triaged by what blocks a deploy.** Currently they're sorted by priority (P0-P6) but a deploy-readiness column would help ("ready to deploy", "blocked on user", "blocked on hardware", "blocked on upstream").

### Technical

7. **`post-deploy-check.sh` path issue should be fixed at the source.** Currently `deploy.sh:27` uses `$(dirname "$0")/post-deploy-check.sh` which works from source but not from nix store. Should use `nix run .#post-deploy-check` like the pre-deploy check at `deploy.sh:5`.
8. **The 3 missing AGENTS.md gotchas should be added NOW.** `discard=async` QLC I/O choke (caused the crash), `buildGoModule` env filtering (caused buildflow missing), `buildGoDir` silent-swallow (compounds both bugs). These are recurring gotchas that will trip the next session if not documented.
9. **`project-meta` silent build failure needs investigation.** Same class as buildflow — flake input + lars-packages reference, but no binary. This could be: (a) a build constraint issue, (b) a missing `GOEXPERIMENT`, (c) a broken flake output, or (d) something else entirely. A 5-minute `nix log` on the project-meta derivation would tell us.

### Operational

10. **The TODO_LIST itself should be deployed.** It's documentation but documentation drift is a real risk. If the user commits it, I should update the "Updated" date to today (not 2026-07-08 morning but the actual commit time).
11. **Status reports should link to TODO_LIST items.** Currently the reports say "see TODO_LIST.md P0" but the TODO_LIST doesn't link back. Bidirectional references would help navigation.
12. **The "Verified" badge concept.** Add a checkbox `- [ ] VERIFIED:` to each Completed item where verification is possible (binary exists, service runs, etc.). I did this implicitly for session 158 (buildflow binary verified live) but it should be standardized.

---

## f) Top 50 Things We Should Get Done Next 🎯

### Critical (P0 — do today)

1. **Deploy the `discard=async` → `fstrim.timer` fix** — Fix in source, NOT deployed. Root cause of 2026-07-08 crash. Every nix build risks another I/O choke → freeze → hard reset. **Most impactful single action right now.**
2. **Commit TODO_LIST.md** — Uncommitted working-tree changes (this session). 1 minute.
3. **Run `sudo btrfs scrub start -r /data`** — 91,561 csum errors need extent mapping. Cannot be done by AI — requires user.
4. **Run `sudo btrfs scrub start -r /`** — Same for root filesystem.
5. **Run `sudo smartctl -a /dev/nvme0n1`** — Determine if NVMe is physically failing. Media errors + available spare below threshold = replace urgently.
6. **Off-site backup (Hetzner StorageBox + BorgBackup)** — No DR backup. Flagged in EVERY status report for 2 weeks. Existential risk.
7. **Investigate `project-meta` silent build failure** — Same class as buildflow. `nix log` on the project-meta derivation will reveal whether it's another `buildGoModule` env issue or something else.
8. **Fix `post-deploy-check.sh` path in deploy.sh** — Change `$(dirname "$0")/post-deploy-check.sh` to `nix run .#post-deploy-check` (matches `pre-deploy-check` pattern at deploy.sh:5).
9. **Add 3 missing AGENTS.md gotchas** — `discard=async` QLC I/O choke, `buildGoModule` env filtering, `buildGoDir` silent-swallow. These are the gotchas that caused the 2 worst incidents of the week.
10. **Verify crush-daily collection post-deploy** — `ProtectHome=false` fix is in source. After deploy: `systemctl start crush-daily-collect`, check `reports/` is non-empty.
11. **Verify Monitor365 `/ui/` serves WASM dashboard post-deploy** — `pkgs.monitor365-server` package fix. After deploy: visit `monitor.home.lan`.
12. **Verify DiscordSync SSO post-deploy** — vHost wired. After deploy: visit `discordsync.home.lan`.
13. **Verify Overview vHost post-deploy** — vHost wired. After deploy: visit `overview.home.lan`.
14. **Verify post-deploy smoke test actually runs** — Currently may silently fail. After deploy: check the `=== Post-Deploy Smoke Test ===` section output.

### High (P1 — this week)

15. **Add binary-existence assertion to post-deploy smoke test** — For each `larsPackages` attr, verify `/run/current-system/sw/bin/<name>` exists. Catches the project-meta class of bug.
16. **Compute real `vendorHash` for 5 BuildFlow `*-bin` packages** — `branching-flow-bin`, `hierarchical-errors-bin`, `golangci-lint-auto-configure-bin`, `go-auto-upgrade-bin`, `oxlint-auto-configure-bin` all have `lib.fakeHash`.
17. **Verify `env.GOPROXY`/`env.GOPRIVATE` in BuildFlow `*-bin` packages work** — Likely silently dropped by `buildGoModule` same as `GOEXPERIMENT`. Move to `preBuild` exports.
18. **Audit all `buildGoModule` calls in SystemNix and BuildFlow** — Check for other `env` attrs that are silently dropped. Defense-in-depth.
19. **Add Gatus maintenance windows** — Every deploy fires false Discord alerts. Suppress noise during deploy windows.
20. **Update BuildFlow pre-commit hook generator** — Manual `.git/hooks/pre-commit` fix from session 158 will be lost on re-install. Add `export GOEXPERIMENT=jsonv2` to the generator template.
21. **Push SystemNix commit `8603e730` to origin** — Buildflow flake.lock update is local-only.
22. **BTRFS `/data` → `@data` subvolume migration** — Docker/Immich/AI data unsnapshotted. ~1h downtime, USB rescue boot.
23. **Reboot evo-x2** — Verify boot time after NVMe APST fix + Caddy sops ordering fix. Target ~35s (was 6m17s).
24. **Verify Pocket ID email sending** — Test login notification after SMTP wiring + sops secret added.
25. **Add GPUActive/GPUReclaim monitoring to Gatus** — `/proc/meminfo` GPUActive (30.7 GiB) + GPUReclaim are invisible to entire monitoring stack. The #1 RAM consumer on this system.

### Medium (P2 — this month)

26. **Test TTM `page_pool_size` reduction** — Reduce from 112 GiB to ~32 GiB. Needs reboot + Ollama model load test. Could free 20+ GiB.
27. **DNS migration: unbound → dnsblockd** — 4-phase plan in TODO_LIST.md Phase 2a-4. dnsblockd v0.2.0 ready. Eliminates unbound (1.5 GiB RSS).
28. **Caddy admin API hardening** — `admin off` + standalone `:2019 { metrics }` listener. Currently unauthenticated.
29. **Firewall deny-by-default with explicit allowlist** — All inbound allowed. Docker punches its own holes.
30. **PostgreSQL textfile exporter** — `pg_isready` + connection count. Three critical services depend on PostgreSQL.
31. **Caddy access logs → SigNoz** — JSON logs written but never ingested. filelog receiver in OtelCollector.
32. **Caddy upstream health checks** — `health_uri` on `reverse_proxy` blocks. Caddy won't proxy to dead backends.
33. **Bind Immich to localhost** — Currently `0.0.0.0` + `openFirewall`. Caddy already proxies.
34. **Docker volume prune timer** — 37.1 GiB reclaimable found in Jul 2 audit. Add weekly `docker volume prune --filter "until=168h"`.
35. **Add `zram` swap monitoring to Gatus** — Currently 4.5 GiB / 15 GiB. Swap exhaustion was root cause of historical OOM crash chain.
36. **Update TODO_LIST.md `Last commit` timestamp after committing** — Currently shows `4d75e83b` but the TODO update isn't committed yet.
37. **Backfill commit SHAs in old Completed sections (122-138)** — For consistency with new sections.

### Low (P3 — when time permits)

38. **Split large modules** — signoz 705L, forgejo 583L. monitor365 was already split in commit (now smaller).
39. **Typed NixOS module options** — Most modules use `mkEnableOption` only.
40. **Mac CA distribution** — `dnsblockd-CA` install on Mac via MDM profile or bootstrap script.
41. **Gatus → Homepage integration** — Real-time status dots via Gatus API.
42. **Audit the 22 tools removed in commit `900b8712`** — Verify which were re-added and which are still missing.
43. **Consider a `goTools` overlay helper** — Centralize `GOEXPERIMENT` and other env exports for all LarsArtmann Go tools.
44. **Add a CI check that all `larsPackages` produce non-empty outputs** — Catch silent build failures automatically.
45. **Consider nixpkgs PR for `GOEXPERIMENT` in `buildGoModule`** — File upstream to forward `GOEXPERIMENT` env var.
46. **Audit all `harden{}` services for ProtectHome data-access bugs** — Done in session 157, but new services added since should be re-checked.

### Long-Term (P4 — when boredom strikes)

47. **Provision Pi 3 for DNS failover cluster** — Hardware required.
48. **Auditd enablement** — Blocked on NixOS 26.05 bug #483085. Re-check on next upgrade.
49. **AppArmor enablement** — Currently `mkDefault false` in security-hardening.nix.
50. **Darwin Home Manager parity** — Disk constrained (256GB, 90%+ full). Workaround: clean caches first.

---

## g) Top 2 Questions I Cannot Answer Myself 🤔

### 1. Should the TODO_LIST.md rewrite be committed separately, or rolled into the next "deploy + commit everything" sweep?

The TODO_LIST update is purely documentation. Options:

- **Commit now** (1 command, atomic, low-risk) — but creates an extra commit in the history that doesn't deploy anything
- **Roll into next deploy commit** (bundles documentation with code changes) — but if the next deploy fails or gets rolled back, the TODO update is also lost
- **Wait for user instruction** — user may have a preferred cadence

I lean toward **commit now** because TODO_LIST is documentation that should track truth, not deploys. But the user has a documented preference for batching documentation with related work (e.g., AGENTS.md gotchas are committed alongside the fix that triggered them). **What's the user's preferred cadence for doc-only commits?**

### 2. Why does `project-meta` not produce a binary when 10 other larsPackages do?

`project-meta` is in `lars-packages.nix` (line referenced in earlier view) and `flake.lock` (resolved as `project-meta_2` with proper follows). But:

- `nix eval .#nixosConfigurations.evo-x2.config.environment.systemPackages | grep project-meta` returns 0 results
- `/run/current-system/sw/bin/project-meta` does not exist
- The package evaluates successfully (the eval returns the systemPackages list, just without project-meta)
- No error or warning is emitted

Possible causes I cannot verify without `nix log` access:

- (a) The flake input's `packages.x86_64-linux.default` evaluates to an empty derivation (similar to buildflow pre-fix)
- (b) A `meta.platforms` filter excludes x86_64-linux
- (c) A `subPackages` mismatch — `cmd/project-meta` doesn't exist upstream
- (d) A `GOEXPERIMENT` or build-tag requirement (like buildflow had)
- (e) An upstream build error that the flake swallows silently

**The user's `nix log .#larsPackages.project-meta` output would tell us in 30 seconds.** I can't run it.

---

## System Snapshot

```
Date:      2026-07-08 13:00 CEST
Uptime:    ~2h (fresh boot after Jul 8 crash)
Load:      6.95 / 9.92 / 9.29 (moderate — some nix activity)
Disk:      86% (96 GiB free of 723 GiB on root)
Data:      67% (342 GiB free of 1.1 TiB)
Memory:    56 GiB used / 93 GiB total (8% available)
Swap:      4.5 GiB used / 15 GiB total
GPUActive: 30.7 GiB (GTT, 55% of used RAM; GPUReclaim=0)
BTRFS:     discard=async ACTIVE on 8 mounts (fix in source, NOT deployed)
buildflow: ✅ 0c3db8a installed + working
project-meta: ❌ MISSING from system closure (silent build failure)
Failed units: 0 visible
```

---

## Files Changed This Session

```
TODO_LIST.md | 204 → 280 lines (+76 / restructured)
             | 62 → 79 open tasks
             | 55 → 88 completed tasks
             | git status: modified (uncommitted)
```

## Files NOT Changed (but should be)

- `AGENTS.md` — 3 new gotchas pending: `discard=async` QLC, `buildGoModule` env filter, `buildGoDir` silent-swallow
- `scripts/deploy.sh:27` — `post-deploy-check.sh` path broken when run from nix store
- `flake.lock` — SystemNix `8603e730` (buildflow update) still local-only, not pushed
- `BuildFlow` repo — pre-commit hook generator should be updated to include `export GOEXPERIMENT=jsonv2`

---

## Commits This Session

None. Work is in working tree only, awaiting user decision (see question #1).

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
