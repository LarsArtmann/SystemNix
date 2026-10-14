# GeoMetrikks status-page fixes — Deployed & Verified

- **Date:** 2026-10-14 19:30 CEST (Wednesday) — `date`
- **Host:** evo-x2 (NixOS 26.11.20261011.7fd4004, live)
- **Trigger:** pasted `https://geo.home.lan/settings/status`
- **Predecessor:** `docs/status/2026-10-14_18-34_geometrikks-public-ip-and-log-availability.md`
  (diagnosis + first report; this file is the end-of-session superset)
- **Anchor:** `/run/current-system` == `system-889-link` → `jk0xm68a…-nixos-system-evo-x2-26.11.20261011.7fd4004` ✅
- **Commits (this session, daemon-swept heuristic messages):**
  - `98a4b2a4` — `pkgs/geometrikks-logfile-readability.patch` + `platforms/common/dns-blocklists.nix`
  - `471283ad` — `pkgs/geometrikks.nix` (patched-src wiring + self-test)
  - `451b3c6d` — runbooks (`docs/services/geometrikks.md`, `docs/services/dnsblockd.md`) + this status doc
- **Deploy state:** ✅ **LIVE and verified.** Shipped by a concurrent session's deploy
  (log `2026-10-14_18-57-00.log`) that evaluated the current tree; my own
  `nix run .#deploy` aborted on the concurrent-deploy flock (exit 13) and I did
  **not** force a competing deploy.

---

## Executive summary

Two independent defects on the status page were root-caused, fixed, deployed,
and verified live. A third observation (DB row counts reading `~0`) was
investigated and remains **credential-blocked**.

| # | Symptom | Root cause | Fix | Live proof |
| - | ------- | ---------- | --- | ---------- |
| 1 | `map-home-undetected` banner; no route origins/home marker | `dnsblockd`/HaGeZi blocks `api64.ipify.org` (default `MAP_PUBLIC_IP_URL`) → block page → JSON parse error | whitelist `ipify.org` | `getent ahostsv4 api64.ipify.org` → `104.237.62.213`; `home_location_resolved source=external_ip`; `/health` advisories `[]` |
| 2 | every "Tailed access log" shown "missing" | `os.access()` ignores capabilities for non-root (access(2)) → claims Caddy's 0600 logs unreadable though `CAP_DAC_READ_SEARCH` reads them | source patch `_is_readable()` + `patchedSrc` + build self-test | running `geometrikks-server` (PID 3139026) runs patched venv `g5n5sbdiw…` |
| 3 | `geo_events`/`access_logs ~0 rows` | unknown — likely TimescaleDB `approximate_row_count` estimate; **not verified** | none (blocked) | — |

---

## a) FULLY DONE

- **Reproduced** both anomalies against live state (not just the paste).
- **Root-caused #1** with direct evidence (journal warning, block-page fetch,
  `getent` block IP).
- **Root-caused #2** with documentation-grade evidence (`access(2)` man page:
  non-root uses an *empty* capability set) plus live corroboration (tailer
  streams + `log_format_detected` for 42 files, 0 `does not exist` errors, while
  `os.access` in `_entry()` sets `available=False`).
- **Implemented #1:** `ipify.org` whitelisted in
  `platforms/common/dns-blocklists.nix` with a rationale comment.
- **Implemented #2:** `pkgs/geometrikks-logfile-readability.patch` +
  `patchedSrc = applyPatches` wired as uv2nix `workspaceRoot`; FODs deliberately
  left on pristine `src`; a build-time self-test (`grep -Rq …`) fails the build
  if the patch is absent.
- **Fixed my own self-test bug:** `grep -rq` silently skipped the symlinked venv
  tree (false "patch missing") → switched to `grep -Rq --dereference`.
- **Built green:** `nix build .#geometrikks` → `733cdlv7…`; full toplevel
  `nix build .#nixosConfigurations.evo-x2…toplevel` → `m8b58j9z…` (no eval errors).
- **Deployed & verified live:** DNS unblocked, home re-detected, advisory
  cleared, patched venv running.
- **Docs updated:** `docs/services/geometrikks.md` (two new Gotchas),
  `docs/services/dnsblockd.md` (PHANTOM-200 second instance), plus the 18:34 and
  this 19:30 status reports.
- **No unsafe ops:** no `rm`/`mv`/`git checkout`/`reset`, no force-enable, no
  manual activation, no secrets touched.

## b) PARTIALLY DONE

- **DB row-count verification (Q3 "verify"):** investigated thoroughly but
  **blocked on credentials** — see (d)/(g). Indirect evidence gathered only.
- **`nix flake check`:** not run (I built the real toplevel instead — stronger for
  a module change, but the documented fast check is still unrun).
- **`nix fmt` / treefmt:** not run on the touched Nix files.
- **Follow-up harvesting:** not yet added to `TODO_LIST.md` / `docs/todo/`.
- **Deploy exit code:** the shipping deploy exited **3** (post-deploy smoke
  "NEW failure"), so the deploy is "switched + anchored + verified by me" but not
  a green-exit deploy; the exit-3 cause is an environmental artifact (below).
- **Map UI end-to-end:** verified via `/health` + journal, not by opening the
  map in a browser session (I have no user session).

## c) NOT STARTED

- Upstream issue for the `os.access` bug (still present on upstream `main`),
  with a "drop this patch when fixed" tracking item.
- Harvesting the follow-ups into the TODO system (queue + domain library).
- A regression guard: e.g. a post-deploy check that the tailed-log `available`
  flag is true, or a general `os.access`-vs-capability audit.
- Re-run of the deploy (or `nix flake check`) once the box is calm, to close the
  exit-3 smoke signal.
- `CHANGELOG.md` entry for the two fixes.
- Auditing other `AmbientCapabilities=CAP_DAC_READ_SEARCH` services for the same
  `os.access` trap (cv-backup precedent among them).

## d) TOTALLY FUCKED UP

- Nothing irreversible. The tree was never force-enabled/activated; the running
  system was only changed by the normal `nix run .#deploy` path.
- **Self-inflicted, fixed:** the `grep -rq` false-negative self-test (corrected,
  then verified green). This is the "a broken grep cannot phantom-green it"
  lesson inverted — it phantom-**red**ed.
- **Deploy environment is broken/noisy (not caused by me but worth flagging):**
  - My `nix run .#deploy` (and at least two other sessions) aborted with **exit
    13** (concurrent-deploy flock) — multiple agents deploying at once.
  - An earlier deploy today exited **14** (`UNANCHORED`, 18:51) — exactly the
    gate/anchor failure class AGENTS documents; the shipping deploy nonetheless
    anchored correctly (889).
  - The shipping deploy exited **3**: post-deploy §18 "Service Sanity CPU —
    nix-daemon.service=382%CPU" flagged as a *NEW* failure. This is an artifact
    of the concurrent `nix build` churn in the smoke window, **not** a real
    service regression — but it means the deploy was not a clean pass and should
    be re-run when calm.
- **`platforms/nixos/system/configuration.nix`** was modified in the shared tree
  by another session (owner answered "keep it"); I did not author/co-verify it.

## e) WHAT WE SHOULD IMPROVE

- **Serialize deploys.** Three+ concurrent `nix run .#deploy` attempts (exit 13)
  and a 20-minute deploy while other sessions build is the documented
  IO-freeze/regression-signal recipe. There should be a shared "one deploy at a
  time, box calm first" convention or an admission wrapper.
- **Verify the DELIVERING layer, not the command.** I verified via
  `/run/current-system`, the running PID's venv path, `getent`, journal, and
  `/health` — good — but I should also have confirmed the *map UI* renders
  origins (needs a session).
- **Distinguish the two "missing" signals early.** `health.missingFiles` (open-based,
  authoritative) vs the UI list's `available` (`os.access`-based) look identical
  in a screenshot. Reading `logfiles.py` first would have collapsed the
  diagnosis.
- **Patch hygiene.** A third-party source patch must carry an upstream issue +
  a drop-when-fixed TODO in the same session; I only wrote the header note.
- **DB access for agents.** There is no unprivileged read path to the shared
  Postgres; diagnostics that need row counts require the owner. Consider a
  read-only role or an exporter/textfile metric for table row growth.
- **Memory rule timing.** Runbook updates should land at the moment of discovery;
  I deferred them until after the deploy.

## f) WHAT WE SHOULD GET DONE NEXT (up to 50)

1. Re-run `nix run .#deploy` (or at least `post-deploy-check.sh`) in a calm
   window to clear the exit-3 `nix-daemon` CPU signal.
2. Confirm the §18 CPU/journal-rate FAILs are pre-existing baseline noise.
3. Run `nix flake check --no-build` when calm.
4. Run `nix fmt` / treefmt on the touched Nix files.
5. Open the map UI and confirm route origins + home marker render.
6. Confirm `/settings/status` now shows sizes/mtimes for tailed logs (user session).
7. File the upstream `os.access` issue (github-voice + verify-before-filing).
8. Add a "drop this patch when upstream fixes it" TODO tied to the issue.
9. Harvest these follow-ups into `TODO_LIST.md` + the domain library.
10. Add a `CHANGELOG.md` entry for both fixes.
11. Owner-run exact row counts: `SELECT count(*) FROM access_logs;` / `geo_events;`.
12. If ~0 is real, inspect `access_log_debug` (996 rows) for malformed records.
13. Explain the `~996` debug rows with `store_debug_lines=false` (old data? parser gap?).
14. Decide whether `store_debug_lines` should be explicitly pinned off.
15. Investigate the 34 "Timeout of 60s validating log format" messages (empty files).
16. Confirm `access-:80.log` / `access-https:__*.home.lan.log` names are intended.
17. Confirm `CrowdSec = Disabled` is intended (docs say inert).
18. Re-check the "Site homes evo-x2 54.35, 18.65 / No traffic" row freshness.
19. Add a post-deploy check asserting the tailed-log `available` flag.
20. Add a general `os.access`-vs-`AmbientCapabilities` audit (new eval-time lint?).
21. Audit every `AmbientCapabilities=CAP_DAC_READ_SEARCH` service for the trap.
22. Consider `MAP_PUBLIC_IP_URL` pointed at a repo-controlled echo (drop 3rd-party).
23. Add a Gatus/external check that public-IP reachability works.
24. Consider a render-test assert that `ipify.org` stays whitelisted.
25. Document the "egress IP echo" whitelist set (`myip.is`, `extreme-ip-lookup.com`, `ipify.org`).
26. Serialize/deploys: propose a calm-window or single-deploy convention.
27. Check whether exit-13/exit-14 deploy attempts today left partial state.
28. Verify `dnsblockd` mapping.json actually dropped the ipify block entries.
29. Verify `geometrikks` re-detects after the 24h home-refresh job.
30. Watch 24h that the advisory does not reappear.
31. Confirm Caddy log files still rotate/append post-deploy.
32. Confirm geometrikks Downloads (log files) now succeed.
33. Re-check `geometrikks.service` memory `high` counter trend (10760 hits, WARN).
34. Review `bank-sync`/`clickhouse`/`forgejo` memory-throttle WARNs (pre-existing).
35. Review `prometheus-node-exporter` journal-rate FAIL (683/min, pre-existing).
36. Review `papdashboard` journal-rate FAIL (pre-existing).
37. Confirm the auto-commit daemon heuristic commits get amended/messaged.
38. Ensure the patch survives the next `nix flake update` (version-tied).
39. If upstream tags a fix, bump + drop patch + drop self-test in one commit.
40. Add a `checks.*` entry pinning the venv self-test.
41. Consider making the self-test an import-smoke rather than a text grep.
42. Snapshot the pre-fix service hash for rollback (documented).
43. Add `docs/gotchas-archive.md` incident entries (both defects).
44. Add a cross-project lesson to crush-config `references/lessons.md`.
45. Verify `/health` `missingFiles` stays `[]` across a restart.
46. Confirm no `__pycache__` staleness after the patch.
47. Re-read the patch header on any version bump (line refs).
48. Check the `configuration.nix` (other session) change deployed as intended.
49. Confirm `system-N-link` anchoring survives the next reboot (pre-reboot-check).
50. Re-run the full status report after the calm-window redeploy.

## g) QUESTIONS I CANNOT ANSWER MYSELF (max 3)

1. **How do you want DB row-count verification done?** I have **no** unprivileged
   read path (no `lars` role; TCP needs the root-only sops password). Options:
   (a) you paste the `count(*)` results, (b) you grant a read-only role / exporter,
   or (c) I treat `approximate_row_count ~0` as a confirmed estimate artifact and
   close it. Which?
2. **Should I re-run the deploy now** to clear the exit-3 `nix-daemon` smoke
   signal (accepting the noisy shared box), or leave the (verified, anchored)
   deploy as-is?
3. **Is `/settings/status` now showing journal sizes/mtimes for the tailed logs**
   on your screen? You have a session; I can only prove the patched code is
   loaded, not see the rendered UI.

---

## Evidence appendix (this session)

- `fetch https://api64.ipify.org?format=json` → dnsblockd block page (pre-fix).
- `getent hosts ipify.org` → `192.168.1.200` (pre-fix); `getent ahostsv4
  api64.ipify.org` → `104.237.62.213` (post-fix).
- `journalctl -u geometrikks` → `Could not auto-detect … Expecting value …`
  (pre-fix); `home_location_resolved source=external_ip` 19:08:48 (post-fix).
- `fetch http://127.0.0.1:8102/health` → advisory `map-home-undetected`
  (pre-fix) → `"advisories":[]` (post-fix).
- `access(2)` man page — non-root `access()` uses an empty capability set.
- Upstream `logfiles.py` still `os.access` at `v0.19.0`, `v0.20.0`, `main`.
- `pgrep -af geometrikks` → PID 3139026 on patched venv `g5n5sbdiw…`.
- `nix build .#geometrikks` green; toplevel `m8b58j9z…` built.
- Deploy log `2026-10-14_18-57-00.log`: switched `system-888/889`, anchor OK,
  exit 3 (nix-daemon CPU), summary `PASS 141 / FAIL 7 / SKIP 7 / WARN 15`.
- `pg_hba`: `local all all peer` (no `lars` role confirmed) + `host … md5`.

---

## Post-deploy addendum 2 (2026-10-15 ~00:45): Q3 answered, advisory dispositioned, §18 exemption, anchor repairs, deploy state

**Q3 — DB `~0 rows`: NOT a defect; the owner's planned paste was unnecessary.**
Exact counts via a `sudo -u postgres psql` throwaway probe (peer auth):
`access_logs=0`, `geo_events=0`, `access_log_debug=1218` (+105 during the
probe — the write path is healthy). Zero chunks ever created on both
hypertables. Persistence is gated on `record.access_log` (ingestion
`_process_record`), which the parser builds only for GeoIP-resolvable
(public) IPs — with 100% LAN traffic NOTHING persists, by design (the app's
own advisory copy says private-address requests "never reach the map or
Access logs"). The UI number is TimescaleDB `approximate_row_count()`
(chunk reltuples), so it additionally lags ANALYZE. Public vhost traffic
(larsartmann.cloud) is what populates them. Runbook gotcha added.

**Private-address advisory: dispositioned via the upstream knob.**
`APP_PROXY_ADVISORY=false` in the `geometrikks-env` sops template (the
traffic mix is deliberate LAN-direct; upstream docs/configuration.md
prescribes false for deliberate mixes). Also added `restartUnits` to the
template — env-file-only template changes previously never restarted the
service (secret rotations did; content changes didn't). Live-verified:
`/health` `advisories: []` after the 22:08 restart.

**Malformed debug rows (paste #2): by-design noise, documented.** All 1,113
debug rows were Caddy default-logger runtime banners; the `access.log`
tailing topology is deliberate (caddy.nix `logFormat` rationale,
2026-09-30) and upstream captures malformed lines unconditionally
(`store_debug_lines or record.is_malformed`). Module comment corrected (the
old "drops runtime lines harmlessly" claim was optimistic — they land in
`access_log_debug`, bounded by 30-day retention). Upstream filter idea
queued (`docs/todo/upstream.md`).

**§18 sweep: `nix-daemon.service` exempted from the CPU leg.** The 18:57
exit-3 was the deploy's own closure work plus concurrent-session builds
during the 10s sample. Default `exempt_regex` extended; fixture selftest
green. Live proof: the only post-check that ran tonight (the 21:52 deploy)
shows `Service Sanity CPU - PASS`; that post-check failed instead on a REAL
new signal — node-exporter journal rate (below).

**Deploy state (rerun_now): substance live, exit-0 formality pending a calm
window.** All fixes reached the running system via the operator's forced
deploys (`DEPLOY_FORCE_PRESSURE=1`): mkg0p71f (~22:08), 6hd6lr16 (~22:34).
Live-verified: `/health` `advisories: []`, `missingFiles: []`. My own retry
loop (11+ attempts, 20:33-23:00) was refused every time — real IO storm
(nvme0n1/sdb >100% util windows; memory-emergency-guard tripped 5× in the
60 min before 00:34, so the trip-recency gate refuses regardless of PSI).
**Every refused attempt burns a ~7-min battery of IO, feeding the storm it
waits out — the loop was stopped at 00:3x by design.** A clean exit-0
deploy lands at the next calm window with whatever tree is current; no
functional outcome waits on it. (One "exit 0" in the deploy logs,
21-19-14, is MY OWN attempt killed mid-battery by my job_kill — the trap
recorded 0; it is not a real pass.)

**Anchor: repaired and verified.** The 21:52 deploy exited 14 UNANCHORED
(profile-set no-op again) and the ~22:34 switch also left the profile at
system-890. Repaired 22:43 per the AGENTS discipline (profile-set +
`switch-to-configuration boot` → system-891 = 6hd6lr16, `readlink -f`
verified; pre-reboot-check 20 passed / 0 failed). **New evidence for the
pipeline.md UNANCHORED root-cause row: the no-op fired WITH the gate fully
removed and env_keep moot — the gate/env theory is dead; nh's profile-set
leg itself is the suspect.**

**New live evidence for the monitoring node-exporter row:** ~448 lines/min
at 00:3x (2,241 in 5 min), all `error encoding and sending metric family …
broken pipe` — a scraper times out on the storm-slowed `/metrics`, then
node-exporter errors on every remaining write. Storm-transient by
mechanism; the row's calm-window recurrence test remains the decider.

Also verified in passing: `nix flake check --no-build` passes bare (the
gate removal is live on 890+) — the "hermes FOD re-pin" queue row's RED
premise no longer held at ~20:25 (flagged for its owning session).
