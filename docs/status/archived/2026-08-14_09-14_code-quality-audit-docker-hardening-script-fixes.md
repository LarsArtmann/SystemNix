# Status Report: Code Quality Audit + Docker Hardening + Script Fixes

**Date:** 2026-08-14 09:14
**Session scope:** Review all Priority 4 code-quality TODO items, execute fixes, resolve stale items, audit for safety

---

## a) FULLY DONE

### Code Changes (6 files, committed-ready)

1. **Manifest container memory limits** (`modules/nixos/services/manifest.nix`)
   - Added `memswap_limit = "1g"` on manifest app container (had `mem_limit` but no swap limit)
   - Added `mem_limit = "1g"` + `memswap_limit = "1g"` on postgres container (was completely unbounded)
   - All Manifest containers now bounded

2. **Dozzle container memory limits** (`modules/nixos/services/dozzle.nix`)
   - Added `--memory=256m --memory-swap=256m` via `extraOptions` (Dozzle uses `oci-containers` abstraction, not compose)
   - Added log rotation (`max-size=5m`, `max-file=3`) — was unbounded
   - Dozzle was the least-hardened container on the system (no limits, no logging caps, no security opts)

3. **Pocket ID provision retry resilience** (`modules/nixos/services/pocket-id.nix`)
   - Added `--retry 3 --retry-delay 2` to `api_put` and `api_post` curl calls
   - `api_get` already had `--retry 3 --retry-delay 2 --retry-all-errors`
   - Did NOT add `--retry-all-errors` to PUT/POST — safer for non-idempotent operations (only retries on transient transport errors, not HTTP 4xx)

4. **vendorHash pre-deploy check** (`scripts/pre-deploy-check.sh`)
   - Added check #11: dry-runs `.goModules` FOD for all 6 local Go packages (dnsblockd, monitor365, netwatch, emeet-pixyd, file-and-image-renamer, crush-daily)
   - vendorHash mismatches are FOD failures invisible to `nix flake check --no-build` — this check catches them pre-deploy

5. **test-home-manager.sh counter fix** (`scripts/test-home-manager.sh`)
   - Removed 5 duplicate `TESTS_TOTAL` increments across 4 error branches
   - Starship not found: +2 → +1
   - Fish command not found: +2 → +1
   - Fish shell not active: +3 → +1
   - Tmux not found: +2 → +1
   - Each test now counts as exactly 1 regardless of pass/fail outcome

6. **TODO_LIST.md + CHANGELOG.md updated**
   - 9 TODO items marked `[x]` done with resolution summaries
   - 6 CHANGELOG entries added under `[Unreleased] > ### Added`

### Audit Results — No Code Changes Needed (5 items)

7. **StartLimitBurst placement audit** — COMPREHENSIVE: Scanned ALL `.nix` files under `modules/nixos/`. Zero violations found. Every `startLimitBurst`/`StartLimitIntervalSec` is correctly placed at top-level (`systemd.services.<name>.startLimitBurst`) or in `unitConfig` (=[Unit] section). The browser-history.nix fix (`a941f88d`) was the only instance of this bug class. `overview.nix` uses intentional `lib.mkForce null` to null out upstream's incorrect placement — correct remediation pattern.

8. **IO-heavy journalctl patterns** — ALREADY FIXED: All 6 `journalctl` call sites across `scripts/` already use safe patterns: `--grep` flag (in-process filtering), `-n` caps (early termination), write-to-file-then-grep, or capture-to-variable. Zero `journalctl | grep` pipe traps remain.

9. **GOTOOLCHAIN=local** — ALREADY HANDLED BY NIXPKGS: `buildGoModule` injects `GOTOOLCHAIN = "local"` via `pkgs/build-support/go/module.nix` env attrset automatically. Pre-commit hook (`.githooks/pre-commit`) guards against the dangerous opposite (`GOTOOLCHAIN=auto`). CI (`check-flake-inputs.sh`) has the same guard. Template devShell correctly sets it.

10. **crush-daily-backfill.py SQL schema** — VERIFIED SAFE: The `INSERT INTO events` specifies 7 columns (`id, aggregate_id, aggregate_type, version, event_type, payload, occurred_at`). Cross-referenced against the canonical DDL in `go-cqrs-lite/storage/sql/migrations/sqlite.sql` — all 7 columns exist with correct types. The 3 omitted columns (`schema_version`, `payload_encoding`, `metadata`) all have defaults. Insert is safe.

11. **port-uniqueness VM test quoting** — STALE TODO: Investigated `tests/test-port-uniqueness.nix`. No nested `''${}` escaping issues exist. The `testScript` is a pure static Python string with no Nix interpolation. No fix needed.

### Verification

- `nix flake check --no-build` — **all checks passed**
- `nix fmt -- --fail-on-change` on 3 modified .nix files — **0 changed** (formatting clean)
- `bash -n` syntax validation — **OK** for both modified shell scripts

---

## b) PARTIALLY DONE

### Twenty CRM (from prior session, carried over)

- Twenty Docker memory limits were committed by the auto-commit daemon in a prior session
- PG role issue was transient (verified healthy at runtime)
- Twenty backup already registered in `backup-coordination` (maxAgeHours=31)
- **NOT DEPLOYED** — the running containers match by coincidence (prior ad-hoc runtime changes), not because Nix config is authoritative. `nix run .#deploy` is needed to make the config authoritative. **→ RESOLVED:** deployed in the 09:30 session (`7afab3f8`)
- **Server NODE_OPTIONS=768M untested under load** — only at-rest memory (480MB) was observed. Bulk imports or heavy GraphQL queries may exceed 768M heap.

### vendorHash pre-deploy check

- Check added to script but **NOT yet run end-to-end** at deploy time. The `nix build .#<pkg>.goModules --dry-run` invocations have not been tested against actual stale-hash scenarios. The grep patterns for "would build" vs "would copy/fetch" are based on nix CLI output conventions but not verified at runtime.
- **→ RESOLVED (partially):** exercised during the 09:30 deploy; the 7 failures it raised were dismissed as "pre-existing" without investigation (see `2026-08-14_09-30` §f.7) — pattern behavior under a REAL stale hash remains unproven

---

## c) NOT STARTED (from paste_1.txt Priority 4 items)

1. **VendorHash CI check across LarsArtmann repos** — The upstream dnsblockd repo has a `vendor-hash` check (`nix/checks/default.nix:57`) that verifies vendorHash matches go.sum without compiling. This pattern should be replicated across browser-history, crush-daily, file-and-image-renamer, and all other Go repos. This is UPSTREAM repo work, not SystemNix.

2. **PMA `GenerateMessage` handler leak** — Same `defer Close()` pattern as the fixed `Commit()` site, but `GenerateMessage` was missed. Upstream fix needed in PMA repo (`/home/lars/projects/projects-management-automation`).

3. **Systemd hardening consistency audit** — Audit `TimeoutStopSec`, `RestartSec` consistency (5s/10s/30s variation), `ProcSubset`, `RestrictAddressFamilies`, `SystemCallArchitectures`, `LockPersonality`, `UMask` across all service modules. Add missing primitives to `harden()` helper.

4. **Implement cgroup I/O throttling for dev builds** — QLC NAND I/O contention from `cargo`, `go test`, `nix build` caused Helium video to drop to 3 FPS. Wrap dev commands with `IOSchedulingClass=idle` or `IOWeight` limits.

5. **GOMEMLIMIT runtime validation** — Values (75% of MemoryMax) are reasonable defaults but actual Go GC behavior depends on heap live-set. Verify via `runtime.MemStats` or GC logs after deploy.

6. **Create dep-audit script for LarsArtmann Go repos** — Cross-reference ALL `go.mod` require lines against flake.nix pinned revs before deploy.

7. **Add eval-time assertion for `StartLimitBurst` placement** — In systemd 261+, `StartLimitBurst`/`StartLimitIntervalSec` in `serviceConfig` are SILENTLY IGNORED. Create `start-limit-audit.nix` that catches this pattern at eval time. The manual audit (item #7 above) confirmed zero violations NOW, but an eval-time assertion would prevent future regressions.

---

## d) TOTALLY FUCKED UP

### Nothing destructive — but several mistakes in approach:

1. **Did not deploy.** All changes are in the working tree, pass eval, but are NOT live. The Manifest postgres container is still running unbounded in production because the config change hasn't been activated. This is the biggest gap. **→ RESOLVED:** deployed in the 09:30 session (`7afab3f8`); Manifest postgres verified live at 1G

2. **Did not test the vendorHash check at runtime.** The check #11 in pre-deploy-check.sh was added blind — the grep patterns (`"would build"`, `"would (copy|fetch)"`) were written from memory of nix CLI output, not verified by actually running the command. If the patterns don't match real output, the check silently warns on everything.

3. **Dozzle `extraOptions` approach is inconsistent.** Manifest and Twenty use Docker Compose (`mkDockerServiceFactory`) with `mem_limit`/`memswap_limit` keys. Dozzle uses NixOS `oci-containers` abstraction with `extraOptions` flags (`--memory=256m`). This is correct for each abstraction but means there's no single pattern for "add memory limits to a Docker container" — future contributors must know which abstraction each service uses.

4. **The `--retry` on POST/PUT without `--retry-all-errors` may not actually retry on SQLITE_BUSY.** curl's default retry behavior only retries on transient HTTP errors (5xx) and connection failures. If Pocket ID returns HTTP 500 with a SQLITE_BUSY body, curl WILL retry. But if it returns HTTP 400 (which some frameworks do for busy errors), curl will NOT retry. The `--retry-all-errors` flag on `api_get` retries everything. The asymmetry is intentional (safer for writes) but may not fully solve the SQLITE_BUSY resilience goal.

5. **Forgot to check whether the `criticalSystemServices` list in `scheduled-tasks.nix` still references `qmd-mcp`** — qmd was retired in a prior session. The TODO_LIST.md diff accidentally shows this line was modified (removed `qmd-mcp` from the description), but the actual `scheduled-tasks.nix` file was NOT checked or fixed. If `qmd-mcp` is still in the list, the health check may be failing silently. **→ CHECKED (08-14):** the list is clean — caddy/forgejo/dnsblockd/postgresql only (`scheduled-tasks.nix:197-202`)

---

## e) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Deploy after changes.** This session made 6 file changes that pass eval but are not deployed. The pattern of "make changes, verify eval, don't deploy" creates config drift. Either deploy at the end of every session or explicitly call out "NOT DEPLOYED" as a blocking item (which this report does).

2. **Test new script checks end-to-end.** The vendorHash check was added without running it once. Every new script check should be run at least once to verify the grep patterns match real output.

3. **The audit-first approach was correct and valuable.** Spending time investigating before fixing prevented wasted effort on 5 items that were already resolved (StartLimitBurst, journalctl, GOTOOLCHAIN, crush-daily schema, port-uniqueness). This should be the default approach for TODO items that describe problems — verify the problem exists before fixing it.

4. **Consider adding eval-time assertions instead of relying on manual audits.** The StartLimitBurst audit found zero violations today, but there's no guard preventing a future commit from adding one. The `start-limit-audit.nix` TODO item (Priority 3) would catch this automatically.

### Technical Improvements

5. **Standardize Docker container hardening.** Create a helper (like `harden {}` for systemd) that applies standard memory limits, log rotation, security options, and cap_drop to Docker containers regardless of whether they use Compose or oci-containers.

6. **The Dozzle container is still missing `security_opt`, `cap_drop`.** Memory limits were added but it still runs with default capabilities and no `no-new-privileges`. It mounts the Docker socket read-only, which is a significant attack surface — a container with socket access can escape to the host.

7. **Unify curl retry patterns.** Pocket ID provision now has three different retry configurations across GET/PUT/POST. Consider a shared curl wrapper function with consistent retry behavior.

---

## f) Up to 50 Things We Should Get Done Next

### Critical / Immediate

1. ~~**Deploy all changes** (`nix run .#deploy`) — Manifest postgres running unbounded in production~~ done — deployed in the 09:30 session (`7afab3f8`)
2. ~~**Run pre-deploy-check.sh end-to-end** — Verify check #11 vendorHash patterns match real nix output~~ done — exercised at the 09:30 deploy (failures dismissed uninvestigated; real stale-hash case still unproven)
3. ~~**Verify Manifest postgres memory after deploy** — `docker inspect mnfst-postgres-1 --format '{{.HostConfig.Memory}}'`~~ done — verified live 08-14: 1073741824 (1G)
4. **Verify Dozzle memory after deploy** — `docker inspect dozzle --format '{{.HostConfig.Memory}}'` — **live counter-evidence 08-14: still 0 (unbounded)** despite `--memory=256m` in `dozzle.nix:39`; the running container predates the limit and was never recreated
5. ~~**Check `scheduled-tasks.nix` for stale `qmd-mcp` reference** — qmd was retired~~ done — list verified clean (caddy/forgejo/dnsblockd/postgresql)
6. ~~**Reboot evo-x2** — Nixpkgs tarball registry override not active until reboot (Priority 0)~~ done (moot) — last boot (08-13 21:42) post-dates the 08-06 registry fix (`d2443c29`)

### Deploy Verification

7. **Test Twenty CRM under load** — Bulk import or heavy GraphQL to verify 768M heap is sufficient
8. ~~**Run `nix run .#post-deploy-check`** after deploy to verify all 53 checks pass~~ done — ran in the 09:30 session
9. ~~**Check Twenty backup freshness** — `ls -la /var/lib/twenty/backup/` — verify pg_dump succeeding~~ done — verified live 08-14: dumps through 08-14 02:06, `backup_healthy{backup="twenty"}=1`
10. **Verify Pocket ID OIDC client provisioning with new retries** — Restart pocket-id-provision, check journal for retry behavior

### Infrastructure (Priority 0-1)

11. **Off-site backup** — No DR backup exists. Forgejo, Immich, Twenty, DiscordSync all at risk on SSD failure
12. **Free disk space** — Root filesystem at 90-93% on QLC NAND, increases crash risk
13. ~~**Run foreground BTRFS scrub on `/`** — Has NEVER been scrubbed, same physical NVMe as `/data` which had corruption~~ done (superseded) — weekly `autoScrub` (`snapshots.nix:104`, `ab7c331a`) + scrub metrics; both mounts currently show status=interrupted (frequent reboots cut scrubs short)
14. **Browser-history DB backup** — `/var/lib/browser-history/data.db` NOT in backup-coordination
15. **Create Attic cache + CI token** — Module deployed but cache not created — **live evidence 08-14: `attic_storage_gb 0`**, cache still empty

### Code Quality (Priority 3-4)

16. **Add eval-time StartLimitBurst assertion** — `start-limit-audit.nix` module to catch misplaced directives automatically
17. **Add `security_opt` + `cap_drop` to Dozzle** — Container has Docker socket access, needs hardening
18. ~~**Systemd hardening consistency audit** — `TimeoutStopSec`, `RestartSec`, `ProcSubset`, `RestrictAddressFamilies`, `SystemCallArchitectures`, `LockPersonality`, `UMask`~~ done at `0fce1ed9` (documented-rationale closure in `lib/systemd`)
19. ~~**Add missing primitives to `harden()` helper** — Based on audit results~~ done at `0fce1ed9` — deliberate omissions documented; no primitives added by design
20. **VendorHash CI check across LarsArtmann Go repos** — Replicate dnsblockd pattern upstream (open: crush-daily, PMA, erraudit)
21. **PMA `GenerateMessage` handler leak** — Upstream fix in PMA repo
22. **Create dep-audit script** — Cross-reference go.mod requires against flake.nix pinned revs
23. ~~**Implement cgroup I/O throttling for dev builds** — Prevent build storms from freezing desktop~~ done at `9a56c1a7` (`wrapWithMemoryLimit` wrappers + ionice'd crush wrapper)
24. ~~**GOMEMLIMIT runtime validation** — Verify Go GC behavior under load~~ done at `0fce1ed9` (`scripts/validate-gomemlimit.sh`)
25. **Standardize Docker hardening helper** — Single pattern for memory/log/security across Compose + oci-containers

### Service Issues (Priority 2-3)

26. **Fix browser-history `expires_at` session reaper** — Every 5 min error, upstream migration gap — **live-verified 08-14 16:38: STILL FAILING**; TODO_LIST item correct
27. **Fix browser-history `CheckpointStore` upstream** — 4-min projection drain on every restart (tracked in TODO_LIST)
28. ~~**Fix OTel endpoint URL scheme upstream** — browser-history uses `127.0.0.1:4317` without `http://` scheme~~ done — endpoint now `127.0.0.1:4317` (gRPC) via `otelEndpoint` (`browser-history.nix:86`); CHANGELOG [2026-08] Fixed
29. **Hermes: install SSH deploy key** — Blocked on manual step
30. **Hermes: set fallback model** — Blocked on manual step
31. **Hermes runtime verification** — Bot presence, cron, gateway never verified
32. **Test browser-history OAuth2 login end-to-end** — Visit `history.home.lan`, complete Pocket ID flow
33. **Verify dnsblockd dashboard auth** — Restart service, visit dashboard, confirm token works
34. **WebAuthn `.lan` RP ID browser validation** — May be rejected by Chrome/Firefox
35. **Turso plan decision** — DiscordSync on sqlite-only backend after crash-loop
36. ~~**Browser-history registration lock** — `POST /auth/register` open to anyone on LAN~~ done at `17731861` (`MAX_USERS=1`)
37. ~~**Evaluate oomd pressure threshold** — 50%/20s may be too aggressive for build+Docker+AI workload~~ done at `17731861` (raised to 60%/30s)
38. **Clean up orphaned dnsblockd tracking DB** — 724 MB old database
39. **Deploy to macOS** — Darwin registry override written but not deployed
40. **Caddy reload root-cause fix** — `PrivateTmp=true` blocks `systemctl reload caddy`
41. **Declarative health-check** — `criticalSystemServices` hand-maintained, missing active services
42. **SigNoz dashboard JSONs v1→v2 migration** — 5 files in v1 format, non-fatal warnings
43. **ClickHouse backup before SigNoz upgrade** — No backup taken before schema migrations
44. **SearXNG streaming exploration** — User wants progressive rendering
45. **BTRFS `/data` subvolume migration** — Currently toplevel, needs ~1h downtime

### Desktop / Long-Term

46. **Enable niri blur** — Transparent terminals hard to read without blur
47. **Test removing `--enable-zero-copy`** — May prevent display hotplug crashes
48. **file-and-image-renamer: pin 3 inputs from `ref=master` to tags**
49. **file-and-image-renamer: `GOTOOLCHAIN=auto` → `local`** — In both preBuild blocks
50. **Monitor365 event-store compaction** — 597M backlog events, compact after drain

---

## g) Questions I Cannot Answer Myself

### 1. Should I deploy now, or are you planning to batch these with other changes?

~~The Manifest postgres memory limit change is not live — the container is running unbounded in production. But deploying requires a full NixOS switch which takes 5-15 min on this hardware and restarts services. If you're planning other changes, it may be better to batch. If not, this should deploy now.~~ **answered:** deployed in the 09:30 session (`7afab3f8`) — Manifest postgres live at 1G; note Dozzle's runtime container was never recreated and is still unbounded (§f.4)

### 2. The Twenty server `NODE_OPTIONS=--max-old-space-size=768` was set based on at-rest memory (480MB). Should I raise it to 1024M for safety, or is 768M intentional?

The prior session chose 768M as "2x headroom over observed 480MB at rest." But NestJS apps can spike significantly during bulk imports, GraphQL queries with deep joins, or background job processing. The worker has 1536M. If you've seen Twenty server OOM in the past, 768M may be too tight. I cannot determine the right value without observing under load.

### 3. Should the eval-time `StartLimitBurst` assertion module be prioritized?

The manual audit found zero violations today, but there's no automated guard preventing a future commit (by you, another agent, or the auto-commit daemon) from placing `StartLimitBurst` in `serviceConfig` again. The TODO item for `start-limit-audit.nix` exists at Priority 3. Given that this exact bug caused the 2026-08-11 WDT crash chain (browser-history 592 restarts), should I build the eval-time guard now?
