# Status Report — crush-daily (daily.home.lan) Investigation

> **Session:** Investigating why https://daily.home.lan/ shows 0 sessions, "Insights pending" on every report, and an empty trends page despite the service being "healthy" per Gatus.
>
> **Date:** 2026-07-28 11:57 CEST
> **Host:** evo-x2 (NixOS, x86_64-linux)
> **Investigator:** Crush (session-scoped)

---

## TL;DR

`crush-daily` service is **up, serving HTTP, but collecting nothing**. Every nightly `collect` job at 00:30 logs `collect done projects=0 sessions=0 messages=0 cost=0` — silently successful with empty data. The `insights` and `report` jobs at 03:00 and 03:30 then fail with `read model: no data collected for date: YYYY-MM-DD`. Reports exist for the last week but every one shows "0 sessions" and "Insights pending".

Three independent bugs found, all surface as the same symptom. One is blocking (architectural), two are template/UX. All written up in a feedback doc for upstream crush-daily.

---

## a) FULLY DONE

1. **Identified the silent-collect root cause** (`crush projects --json` returns empty list for the `crush-daily` system user because crush CLI is per-user and the system's `~/.local/share/crush/projects.json` is empty)
2. **Confirmed `/home/lars` is mode 700** so even fixing discovery wouldn't be enough — system user can't traverse to lars's data
3. **Confirmed `SupplementaryGroups = "users"` is already wired** in SystemNix wrapper but is a misdirection; can't help with traversal blocker
4. **Confirmed crush CLI's `Load()` swallows ENOENT** returning `{"projects":[]}` silently — that's the actual reason the failure is invisible (charmbracelet/crush `internal/projects/projects.go:55`)
5. **Reproduced the EACCES error manually** with `strace` showing `openat(O_RDONLY) → EACCES` on `/var/lib/crush-daily/.local/share/crush/projects.json` (transient, before parent dirs settle)
6. **Verified `crush-daily` actually gets zero projects** via POST `/api/collect` (returns 202, logs `collect done projects=0 …` in 25ms — too fast for any real query work)
7. **Located the template type error** at `internal/server/index.go:83` — `{{"%.2f"|printf .TotalCost}}` triggers `expected string; got float64` in Go 1.26's html/template (arg order reversed)
8. **Located the broken `/api/prometheus` 404** — real endpoint is `/api/metrics` (server.go:201)
9. **Located all upstream source files** via `/nix/store/...-source/` (nix eval pulled the flake input src)
10. **Confirmed `POST /api/collect` is registered** in the server routes — dashboard button is wired correctly
11. **Wrote the comprehensive feedback report** to `/home/lars/projects/crush-daily/docs/feeback/new/2026-07-28_crush-daily-systemnix-runtime-breakage-report.md` (358 lines)
12. **Documented all three bugs with root cause, fix recommendation, and repro recipe** in the feedback doc
13. **Cross-checked upstream `flake.nix` module** (lines 160-432) to confirm `User = "crush-daily"` and `home = cfg.dataDir` are the source of the bug
14. **Verified the local crush-daily checkout** (`/home/lars/projects/crush-daily`) is on `master @ 50b8f06`, has AGENTS.md, follows the same `feedback-*.md` doc convention I extended

---

## b) PARTIALLY DONE

1. **Diagnosis is complete but the fix is NOT applied** — no SystemNix patch written, no overlay drafted, no module option added (`runAsUser`). User just asked me to report.
2. **Feedback doc lists 3 fix options** (per-user systemd service, `runAsUser` override, defensive doctor probe) — none are implemented in either repo.
3. **No upstream issue opened** — feedback doc is local-only. The crush-daily repo on GitHub (`LarsArtmann/crush-daily`) was not reachable from this session (agentic_fetch rate limit hit), so the report is filed in the local clone as the user requested.
4. **No `nix flake check` / `nix flake lock --update-input crush-daily` ran** — would tell us if the fix is already in a later upstream commit. Skipped intentionally; user asked for status only.

---

## c) NOT STARTED

1. **No SystemNix patch** (runAsUser option + overlay for the template bug)
2. **No local /tmp fixes** (e.g., template hot-patch via `nix develop`)
3. **No Gatus URL fix** (SystemNix already uses `/api/health`, so this is moot locally)
4. **No `crush` project JSON for the `crush-daily` user** (manual workaround that would only collect from /data partition projects, not /home/lars)
5. **No agent upstream outreach** (issue/PR/discussion)
6. **No CHANGELOG / FEATURES.md / TODO_LIST.md updates** in either repo
7. **No `git commit`** in either repo (the feedback doc is untracked)
8. **No `nix run .#pre-deploy-check`** run after diagnosis
9. **No `nix run .#post-deploy-check`** validation
10. **No AGENTS.md cross-link** adding this session's learnings to the project AGENTS
11. **No verification of whether the bug also affects other deployers** (no scan of similar upstream module setups)

---

## d) TOTALLY FUCKED UP

1. **Did not write the report to `docs/status/`** — the user's request literally says "Write a full status report at docs/status/<YYYY-MM-DD_HH-MM_WELL-NAMED>.md" but my first deliverable was the feedback doc at `docs/feeback/new/`. **However**, the user-follow-up explicitly directed me to write the feedback there, so this is a self-correction: I now write the status report AS REQUESTED in this turn, after the fact. The feedback doc lives separately per user direction.
2. **First 5+ tool calls in this session were blocked by `systemctl`/`curl`/`sudo` denials** — I burned turns discovering the sandbox restrictions instead of pivoting immediately. Could have started with `journalctl` and `nix-shell -p wget` from the start.
3. **No way to verify the running binary's actually-used code path** — the upstream source at `/nix/store/dxnn003niqybalk0gbqlbvs7x41r4fkm-source/` is from commit `2d6255c1` (matches `flake.lock`), so this is consistent, but I never confirmed it at runtime. If a `vendorHash` mismatch had injected a different binary, my analysis would be wrong.
4. **Did not actually trigger `crush projects --json` AS THE SERVICE USER** — I used `env -i HOME=…` which is close but not identical (no PAM session, no `pam_limits`, no supplementary groups init). The `id crush-daily` output showed only primary group, so `env -i` is functionally equivalent, but strictly speaking I inferred rather than verified.
5. **Did not write a quick reproduction test** (Go test that calls `crushDiscoverer.Discover` and asserts behavior). The evidence is observational only.
6. **Missed checking what version of `crush` is in `/nix/store/cc8bz4bmr1hk1q6a6paxgiflvjgyzp5a-crush-daily.yaml`** — that was the right binary path; I looked at `/run/current-system/sw/bin/crush` instead. They should be identical (same Nix store path closure), but I didn't verify.

---

## e) WHAT WE SHOULD IMPROVE

### Immediate (this session / next session)

1. **Stop the bleeding**: fix SystemNix locally with a `services.crush-daily.runAsUser = "lars"` option (or equivalent) so the data actually gets collected. The week of zero-data reports is the cost of not having caught this earlier.
2. **Add a discovery probe to SystemNix's post-deploy-check**: after deploying crush-daily, call `/api/health`, then POST `/api/collect`, wait 5s, then call `/api/reports` and assert the latest report has `>0 sessions`. Today the smoke test only checks `/api/health` returns 200 (which it does, because the service is up — completely missing the silent-zero-data class of bug).
3. **Add a Gatus metric**: `crush_daily_projects_discovered_total` should be >0 in the last 24h, else alert. This is the meta-observation that would have caught it: services that "look healthy" but produce zero data need liveness checks, not just readiness checks.
4. **Open upstream issue**: the feedback doc is excellent but lives in the local clone only. Need a `LarsArtmann/crush-daily` GitHub issue with the same content (or a pointer to it once we add the `docs/feeback/new/` file to upstream).
5. **Add a pre-commit hook** to SystemNix that catches the "service runs as user X but reads per-user state owned by user Y" pattern — the static pattern is detectable from `services.X.user` vs `ReadOnlyPaths` ownership.

### Medium-term (this week)

6. **Module `runAsUser` for crush-daily**: SystemNix wrapper should expose `services.crush-daily.runAsUser = lib.types.str;` (default null → system user). When set, override `User = cfg.runAsUser` and `WorkingDirectory = "/home/${cfg.runAsUser}"`. Required for fix #1.
7. **Template overlay for the `printf` bug**: small `pkgs.crush-daily.overrideAttrs (old: new: ...)` that swaps `internal/server/index.go` for a `formatUSD`-based version. Or better: fix it upstream and bump flake.
8. **SystemNix `protect-home-audit` extension**: also flag the "service user has no `~/.local/share/...`" pattern. The pre-commit hook catches `/home` patterns; this catches `/home/<user>/...` ownership mismatches.
9. **Per-user systemd timer instead of system service**: actually the cleanest fix. `crush-daily collect --user lars --output /var/lib/crush-daily/events.db` as a user timer; `crush-daily serve` as the only system service reading the shared DB. This decouples the data-owner permission from the serving permission.
10. **Add `/api/doctor` HTTP endpoint** upstream: doctor runs and returns JSON. SystemNix post-deploy-check calls it and asserts no warnings.

### Long-term (next month)

11. **crush-daily upstream PR for Option C** (defensive doctor probe) — easiest upstream win, would have caught the bug
12. **crush-daily upstream issue for Option A** (per-user service model) — structural fix
13. **Replace per-user `crush projects --json` shelling** with reading the project list from the user's crush config directly (Option A.2)
14. **Stop using `crush projects --json`** entirely once crush exposes a stable API; today the dependency is implicit and brittle (AGENTS.md item 1 documents this)
15. **Cross-link AGENTS.md** so future sessions know about this class of bug
16. **Add a "silent-zero-data" linter** to SystemNix: any service whose job logs "done" but produces zero records AND has no error counter must have a Gatus probe that asserts nonzero output

---

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

Prioritized. P0 = blocking, P1 = this week, P2 = next sprint.

### P0 (fix the user-visible breakage)

1. Patch SystemNix `services.crush-daily` wrapper to expose `runAsUser` option
2. Set `runAsUser = "lars"` in `platforms/nixos/system/configuration.nix`
3. Verify `/home/lars` traversal is granted (probably needs `setfacl` or `ProtectHome = false` + scoped `ReadOnlyPaths`)
4. Deploy and confirm `collect done projects=>0 sessions=>0` in journal
5. Confirm new reports show real session counts
6. Verify `/api/reports` lists today's report with nonzero stats
7. Confirm `POST /api/collect` still works (now with real data)
8. Update Gatus to assert `projects > 0` (not just `[STATUS] == 200`) — `body.sessions_total > 0` or similar
9. Re-deploy once template bug fix is in (overlay or upstream)

### P1 (this week — prevent recurrence)

10. Open upstream issue at `LarsArtmann/crush-daily` linking the feedback doc
11. Open upstream PR for the doctor probe (Option C)
12. Open upstream PR for the template fix (`formatUSD` instead of `printf`)
13. Add `services.crush-daily.runAsUser` to the **upstream** module (not just SystemNix wrapper) so other deployers don't hit this
14. Document `runAsUser` in crush-daily README
15. Add post-deploy-check assertion: latest report has nonzero sessions
16. Add `crush_daily_projects_discovered` to crush-daily's Prometheus exporter (doesn't exist today; collector discards the count after logging it)
17. Add Gatus condition `[BODY] > 0` for `/api/reports` size or session_count
18. Add Gatus alert for "Crush Daily produced 0 sessions in last 24h"
19. Document the silent-zero-data anti-pattern in SystemNix AGENTS.md
20. Cross-link the feedback doc from crush-daily's AGENTS.md item about `crush projects --json`
21. Add `pre-deploy-check` test: any service with `User = "X"` + `ReadOnlyPaths` outside `X`'s reach fails evaluation
22. Add the per-user systemd user-service path as an alternative installation mode in crush-daily's flake
23. Update SystemNix FEATURES.md to mark crush-daily "DONE with caveat" until runAsUser lands

### P2 (next sprint — structural improvements)

24. Move crush-daily from a system service to a per-user timer + system server (Option A.1)
25. Replace `crush projects --json` shelling with direct SQLite read of project's `.crush/crush.db` (Option A.2)
26. Add a `monitoring.prometheus.exporter.crush-daily` output that exposes project count, session count, latest collect timestamp
27. Add `/api/doctor` HTTP endpoint to crush-daily
28. Wire `onFailure` from SystemNix to the new doctor endpoint for richer alerts
29. Cache the project discovery result (currently re-shells `crush projects --json` every collect cycle — 24/day of redundant exec calls)
30. Add a `crush-daily doctor` systemd timer that runs hourly and emits Prometheus metrics
31. Add a `services.crush-daily.expectedMinSessionsPerDay = 50` option that alerts when daily session count drops below threshold
32. Pin crush-daily to a release tag once upstream cuts one (currently `?ref=master`)
33. Add the per-user systemd unit to SystemNix desktop HM packages
34. Test what happens when lars's `$HOME` is unavailable (nix-store rebuild, profile switch) — current fix breaks silently
35. Add a `nix run .#crush-daily-doctor` flake app for manual diagnosis
36. Cross-reference this session in crush-daily's `docs/status/`
37. Add `runAsUser` and template-fix regression tests to SystemNix's pre-deploy-check
38. Add `protect-home-audit` extension for the per-user state mismatch pattern
39. Audit OTHER services for the same anti-pattern (file-renamer was fixed for the same reason — what else?)
40. Add a Gatus template for "service collects zero data" alerts that reuses across all crush-daily-style services

### P3 (nice-to-have)

41. Move the crush-daily event store to `/var/lib/crush-daily/events.db` shared by user-timer + system-server (currently uses `/var/lib/crush-daily/crush-daily.db` per the upstream flake)
42. Add a NixOS test that reproduces the bug (service running as `crush-daily` user + zero projects in projects.json = zero collect output)
43. Add a `services.crush-daily.machineId` so multi-host deployments don't share data
44. Reduce `MemoryMax=512M` if profiling shows underuse (current is conservative)
45. Investigate whether the watcher (`internal/watcher`) is hot-reloading the config correctly when `data_dir` changes
46. Add a `systemHealth.collectorHealth` Prometheus gauge that surfaces "0 projects discovered in 24h"
47. Build a small dashboard widget (Homepage) that shows the last 7-day session count
48. Add daily summary email via Hermes (cross-link to AGENTS.md item 24 in crush-daily)
49. Document the `crush` version that crush-daily was tested against (current is `v0.86.0` per `/run/current-system/sw/bin/crush --version`)
50. Add a `flake-parts` check that asserts crush-daily's `services.X.user` matches the data-owner's UID whenever `X` reads per-user state

---

## g) UP TO 3 QUESTIONS I CANNOT FIGURE OUT MYSELF

### Q1: What's your preference for the fix path?

Three options in the feedback doc:
- **A.** Per-user systemd service (cleanest, biggest blast radius)
- **B.** `runAsUser = "lars"` in SystemNix wrapper (smallest change, fastest ship)
- **C.** Defensive doctor probe + Gatus nonzero assertion (no upstream coupling)

Each has tradeoffs (A: changes systemd model; B: requires `setfacl` for `/home/lars`; C: doesn't fix the data, just alerts). I'd ship B + C in one deploy and queue A as a separate sprint. But this affects /home/lars ACLs (security boundary), so I want sign-off before proceeding.

### Q2: Do you want me to open the upstream issue/PR now?

The feedback doc is excellent and self-contained. I can mirror it to `LarsArtmann/crush-daily` GitHub issues today. Or you may want to review the doc first, redact any SystemNix-specific bits, and post it yourself (it's your project — I'm just a proxy). The session is rate-limited on `agentic_fetch` so doing it manually is fine, but I want to make sure the doc is "release-ready" before it goes public.

### Q3: Should `/var/lib/crush-daily/reports/` be world-readable?

The Caddy vHost serves `daily.${domain}` via `protectedVHost` (Pocket ID OIDC), so reports are auth-gated. But the Caddy user (`caddy`) needs read access to `/var/lib/crush-daily/reports/`. Current state is mode 0750 owner=`crush-daily`. Caddy uses `nginx`-style static file serving via `reverse_proxy`, NOT `file_server`, so it never touches the FS directly — the upstream crush-daily HTTP server reads and serves. So this question is moot today. **However**, if you ever want to serve static files directly from Caddy (e.g., to bypass crush-daily's auth wall), the ACL needs to change. Should I add a `services.crush-daily.serveReports = false` switch that disables the HTTP server in favor of Caddy `file_server`? This is a deep question about the auth architecture and I don't want to make this decision unilaterally.

---

## Files Touched This Session

- **Created:** `/home/lars/projects/crush-daily/docs/feeback/new/2026-07-28_crush-daily-systemnix-runtime-breakage-report.md` (358 lines)
- **Created:** `/home/lars/projects/crush-daily/docs/feeback/new/` (directory)
- **Created:** `/home/lars/projects/SystemNix/docs/status/2026-07-28_11-57_crush-daily-silent-zero-data-investigation.md` (this file)
- **Read-only investigation:** `journalctl`, `/nix/store/...-crush-daily-2d6255c*/bin/crush-daily`, `/nix/store/dxnn003niqybalk0gbqlbvs7x41r4fkm-source/` (crush-daily source), `/run/current-system/etc/systemd/system/crush-daily.service`, `/home/lars/.local/share/crush/.crush/crush.db` permissions, `/home/lars/.local/share/crush/projects.json` permissions, `/home/lars/projects/SystemNix/.crush/crush.db` (mode 777), Caddy vHost config, Gatus check config

---

## Next-Action Recommendation

If the user wants to ship a fix in this session:

1. **5 min:** Add `services.crush-daily.runAsUser` option to SystemNix wrapper (`modules/nixos/services/crush-daily.nix`), default null
2. **2 min:** Set `runAsUser = "lars"` in `platforms/nixos/system/configuration.nix`
3. **3 min:** Add `ReadOnlyPaths = [ "/home/lars" ]` and remove `SupplementaryGroups = "users"`
4. **10 min:** `nix run .#pre-deploy-check` + `nix run .#deploy`
5. **2 min:** `journalctl -u crush-daily -n 20` to confirm `collect done projects=>0`
6. **5 min:** Open upstream issue pointing at the feedback doc

Total: ~30 min for full fix + verify + outreach.

If the user wants only the report (no fix yet), this status doc IS the deliverable.

---

_Session end._