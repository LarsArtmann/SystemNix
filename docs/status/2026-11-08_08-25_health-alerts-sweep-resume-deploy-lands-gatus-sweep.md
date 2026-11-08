# Health-Alerts Sweep (Resumed): Deploy Lands (gen-989), Gatus Side Root-Caused, restic Stale-Lock Fixed

**Session:** resumed 2026-11-08 ~06:13–08:25 CET · **Session type:** continuation of `2026-11-08_03-56_all-health-alerts-sweep.md`
**Headline:** The blocked deploy train finally landed as **gen-989** (unblocked by fixing the SC2034 cross-file lint + completing the lock session's expected-locks wave). The never-started **Gatus-side sweep** is done: every failing endpoint root-caused, one real production bug found and fixed (**restic stale-lock blackout — 3 nights of missed app-dump backups**), the rest attributed to the Sunday restore-drill storm, known owner-gated rows, or red-by-design trackers.

## a. The deploy train (the session's primary deliverable)

1. **SC2034 unblock** — the parallel session's §17 zombie-mount extraction (c32357809, 02:32) left `ZM_PASS=pass ZM_FAIL=fail` in `scripts/pre-deploy-check.sh` with the only readers inside the sourced `lib/zombie-mount-gate.sh` — shellcheck cannot follow that, so staging the file failed the pre-commit warning bar and blocked every deploy. Fixed with the file's own established per-site `# shellcheck disable=SC2034` pattern (mirroring metrics-gate/OB/STH producers ~1200 lines above); the wave's `test-zombie-mount-gate.sh` carried 4 more of the same class (fixture producers read by the sourced lib) — all annotated. Commit `da91d8736`; shellcheck clean, zm-gate selftest rc=0.
2. **Lock wave completion** — the lock-float session (live since 02:26) floated hermes-agent (`flake.lock`, committed 06:21) and left the matching `flake/expected-locks.nix` rev update uncommitted (session stalled post-edit ~06:22). Green-eval probe confirmed the wave was complete-but-uncommitted; daemon swept it (14713a5f0) before my pathspec commit could. Tree quiescent thereafter.
3. **README doc-counts restamp** — my restic-module commit tripped `checks.doc-counts`: README asserted 279 gatus endpoints, eval truth 280. Attribution: the 00:21 nsfw "280→279" stamp under-counted its own tree (verified NOT the hermes float — old-rev override eval also gives 280). Restamped to 280, commit `04e9efd6e`.
4. **Deploy fired 07:0x** after the readiness poll went green (drill done + tree clean + 5-min eval quiescence). First run refused at the ENTRY PSI gate (56% avg10 "REAL I/O storm") — **overridden with `DEPLOY_FORCE_PRESSURE=1` on device-truth grounds printed by the gate's own crosscheck**: all pool disks 0.0% util (the 40G drill read was over), max real device 25.5%, top stalled cgroup = the documented `app-niri-ghostty` io_uring phantom emitter. The switch completed: **`/run/current-system` = `6914jad7…` = system-989, anchored**. Post-deploy smoke: 167 PASS / 5 FAIL — all 5 match the standing baseline (advisory).

## b. Gatus-side sweep (the never-started item — now complete)

Method: read-only sqlite against `/var/lib/private/gatus/gatus.db` (schema: `endpoints`, `endpoint_results`; timestamps UTC; `success=0` + empty errors = condition failure). ~50 endpoints failing at sweep start; every distinct class root-caused:

| Class | Endpoints | Root cause | Verdict |
| --- | --- | --- | --- |
| Sunday-drill storm | Memory Guard Trip Churn, FastFlowLM ×2, I/O Stall Rate, Memory Events/Emergency/Guard storm family, Immich ML, EMEET PIXY, SEV1 bridge, Health Hub Federation, scrapes at 337ms-1s | The **Sun 06:00 forgejo restore drill** (29.5G zip off the HDD pool, 92% CPU unzip, 55min CPU, 9.7G swap peak, timed out at 07:00 at ~1/3 through). Guard in churn_mode 1 (24 zone-6 trips/hr at peak). All by-design storm reporting | Self-resolving; trips decayed 24→10/hr by 08:20 |
| **restic stale-lock blackout** | Backup Freshness: restic-app-dumps, All Backups Healthy | **Real bug — see §c** | **FIXED** (this session) |
| /data + offsite-borg never-succeeded | Backup Freshness: data, offsite-borg | Owned: /data corruption repair ([blocked:user] storage.md — the failure IS the tripwire); offsite-borg go-live prep (2026-11-03 wave) | Known, owner-gated |
| Mail MX STARTTLS | Mail MX STARTTLS (550 "Invalid EHLO domain" since 20:19 UTC Nov 7) | Red-until-live go-live tracker BY DESIGN — but the **error shape progressed**: 2026-10-02 probe was connection-refused on all ports; the SMTP dialogue now CONNECTS and the server rejects the EHLO — mail.artmann.tech:25 answers, the EHLO hostname config is the remaining go-live gap | Design; new intel for the go-live runbook |
| Scrub | BTRFS Scrub Staleness/Incomplete (since 18:28 Nov 7) | `btrfs_scrub_last_completed_seconds{root} 0`, status 3 — owned-adjacent (storage.md corruption-repair gate (b) + row 36 coverage gaps); tonight's windows lost to the storm | Known, quiet-window gated |
| DNS blocker allowlist | DNS Blocker Allowlist Backup Freshness (since 00:27 UTC) | dnsblockd flip domain (owner Q3); forgejo-github-sync fails-fast on the un-flipped pull mirror by design | Owner-gated |
| Root disk | Root Auto-Prune Floor (90%) | Root 648G/723G = 93% (grew ~38G overnight — night builds + storm); known owner rows (unallocated-1MiB [decision], gcs-staging/docker reclaim) | Known, worsening slowly |
| Recovered mid-sweep | Indexer Web (02:32), mr-sync Dashboard (05:02), Monitor365 instances (02:3x), systemd-timer-monitor/graph + External HTTPS + Pocket ID (DNS blips 01:27/03:16) | Transient storm-night windows; parallel sessions' fixes | Green |

**Storm forensics corrected twice mid-sweep** (both worth recording): (1) the drill's extract dir "vanished" from `/tmp` while unzip ran — NOT tmpfiles volatility: the unit runs `PrivateTmp`, the dir lives in the unit's namespace (`/proc/363776/root/tmp/` shows it); outside-view `ls` is namespace-blind. (2) The uniform "72-fail wall" across ~30 endpoints was not one common-mode break at 23:24 UTC — it is the whole overnight storm window, with per-endpoint first-fail times spread 17:28→03:42 and continuous 5m-interval failures since.

## c. restic stale-lock blackout (the real production bug of the sweep)

- **Symptom:** `backup_healthy{restic-app-dumps} 0`, age 999→72h; Nov 7 + Nov 8 05:45 windows insta-failed: `repository is already locked exclusively by PID 1936193` (lock created 2026-11-06 05:56:21 — 48h stale; holder dead, killed by a memory-guard Zone-6 storm stop).
- **Root cause (design flaw):** upstream nixpkgs' restic module emits ExecStart = `backup` → `unlock` → `forget` (unlock lives inside `pruneCmd`). A killed run leaves a lock that makes `backup` exit 11 BEFORE the unlock line is ever reached — the unit can never self-heal. Worse for `restic-backups-storage-history`: no prune step ⇒ upstream emits **no unlock anywhere**.
- **Live remediation:** `sudo …restic unlock` against the repo (password via file reference, no secret on any command line) — "successfully removed 1 locks".
- **Config fix (committed, rides gen-989):** `ExecStartPre = "${lib.getExe pkgs.restic} unlock"` on both units (`modules/nixos/services/restic-app-dumps.nix`, `storage-collector.nix`) — clears dead-holder locks only, no-op when clean, live concurrent holders still correctly fail the run. Verified landed in the LIVE unit post-deploy (grep /etc/systemd/system: 1 hit). Commit message + daemon sweep note: the daemon raced my pathspec commit and took the two module files in `0bb4b4c76` one minute before my `04e9efd6e` (which landed the README restamp); fix content verified in-tree post-sweep.
- **Services.md watch row 705 answered:** the 2026-11-05 "first pickup" DID land (metric last success Nov 5 06:53); the Nov 6+ blackout was the stale lock, not the wave's chain.

## d. Post-deploy verification battery (all green unless noted)

- `bash scripts/vm-top-metrics.sh selftest` rc=0 (pre- and post-deploy); `test-zombie-mount-gate.sh` rc=0.
- **SigNoz: 5 firing (from 11 at previous close; 13 enumerated then).** 58 rules total (parallel waves added 7 since the sweep started). The 5: Systemd Service Failed ×4 + Service Failure Spike + Disk Space Critical + llama.cpp Embeddings Down + CPU Thermal Ceiling — every one attributed: flip-pending (forgejo-github-sync refuses by design until the dnsblockd flip), meta-notifier doing its job (service-health-check exit-1 names the other three), inboxclean ([blocked:user] row), llama-embeddings (guard churn re-arm pending), storm residue (spike/thermal — all sensors <80°C at 08:20).
- **indexer-web: ACTIVE** (burst=0/RestartSec=30 patience posture live).
- **ci-watchdog timer: INACTIVE** (retirement effective).
- restic ExecStartPre: live in the deployed unit.

## e. Remaining alert surface — all owner-gated or decaying

1. **Guard churn drain:** trips 24→10/hr and falling; churn_mode will clear at <6. NOTE: the restore bar (io PSI avg60 < 20%) may be phantom-blocked by the ghostty io_uring PSI class (device truth at 08:20: ALL disks 0.0% util while PSI reads 81% — pure phantom). If llama-embeddings does not re-arm within ~1h of trips hitting 0, the restore bar vs phantom-PSI interaction is the suspect (watch row harvested).
2. **Disk Space Critical (root 93%)** — owner reclaim decisions pending (gcs-staging 24G, docker residue ~10G, sitzung Trash ~6.6G).
3. **dnsblockd flip** — now holding hostage: forgejo-github-sync green, the allowlist freshness check, and the canonicalRepos push-mirror attach.

## f. Owner questions (unchanged from 03-56 report, now with more unpushed work)

(a) **Push?** — 40+ unpushed commits now (deploy fixes, restic fix, README restamp, parallel waves' work: nsfw rework, mirror-repair closeouts, nix-native plan). (b) **Purge ~6.6G sitzung Trash?** (irreversible). (c) **dnsblockd flip now?** `sudo systemctl start forgejo-flip@dnsblockd.service` — the flip unblocks 2 red checks + the github-sync unit.

## g. Follow-ups harvested at authoring time

- [watch] storage.md: restic-backups-app-dumps next window (tomorrow 05:45) lands green + backups.prom row recovers + "All Backups Healthy" converges (the manual unlock + ExecStartPre fix both need this confirmation).
- [watch] services.md: forgejo-restore-drill second consecutive storm-window timeout (2026-10-27 force-run + tonight 60min) — consider quiet-window gating or a load-aware timeout.
- [watch] services.md: mail go-live tracker error-shape progression (refused→EHLO 550) — mail.artmann.tech:25 answers now; EHLO hostname config is the remaining gap (runbook intel).
- [watch] stability.md: guard restore-bar vs ghostty phantom-PSI interaction (llama-embeddings re-arm check).

Deliberately NOT harvested: the doc-counts under-count attribution (one-off, resolved); the PrivateTmp namespace blind-spot (noted here, self-evident from the unit file).

**Verdict:** alert surface 13→5 firing, zero unattributed; deploy train restored; one real bug fixed at root cause; everything else correctly gated on owner decisions or natural storm decay.
