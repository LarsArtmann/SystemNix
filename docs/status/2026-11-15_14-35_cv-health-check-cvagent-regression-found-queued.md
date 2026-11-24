# CV Health Check — cv-server green on the new wave, cvagent dashboard regression found + queued

**Session type:** ad-hoc health check ("Check CV health!") — no plan file, no code changes to the
config tree. One queue commit + this report.
**Executor:** Crush session (glm-5.3-flash), started ~14:00, report authored 2026-11-15 14:35 CET.
**HEAD at report time:** dfdf6c4e4 (queue rows landed in c4cd41538 under the prior HEAD ed17352c9).
**Surfaces read:** `docs/services/cv.md`, `docs/services/cvagent.md`, `docs/AGENTS.md` routing table,
live systemd/busctl/journal/cgroup/HTTP probes. No other research.

---

## Environment context the findings live inside

- **An active deploy wave ran THROUGH this health check.** The 13:52:04 deploy holder
  (`/var/log/systemnix-deploys/2026-11-15_13-52-04.log`) was still "Activating configuration" at
  14:35 — its `switch-to-configuration test` is parked behind `post-crash-calm-gate.service`
  (designed PSI-drain hold; io some avg10 32–50% all session, `sdc` at 102.7% util in the entry
  gate dump, the owner's ghostty scope the top stalled cgroup). Six deploys today 09:17→13:52.
  cv-server + cvagent + dnsblockd all restarted under this wave — the :8098/:53 "down" windows
  observed at 14:06–14:11 were the switch, not failures.
- **Memory-emergency-guard FIRED at 14:10:12/14:10:42** (its own journal lines) — the box crossed
  emergency thresholds mid-wave; the calm gate refused heavy maintenance at 14:11/14:21 citing it.
- **Boot identity:** boot 0 started 02:25:35 today; boot −1 ended 02:24:48 (reboot); boot −2
  ended 15:41:18 yesterday (the freeze-#54 WDT cut). Boot id re-checked once mid-session; no
  reboot during the session.

---

## §a FULLY DONE

1. **Runbook + routing pre-read** — cv.md (655 lines) + cvagent.md + the knowledge-routing table
   before any probe; known-failure classes loaded (SIGSEGV loop, bind-after-sync, unseeded-store
   relogin semantics, Gatus check contracts).
2. **cv-server full health battery — GREEN on the new rev.** Unit active/running; binary
   `/nix/store/…-cv-e6fb98c/bin/cv serve` (today's cv input bump deployed); `/health/live` 200
   `version=e6fb98c`; `/health` 200 overall-warn carrying EXACTLY the four known-intentional rows
   (database, graphrag, two go-health plumbing keys); `/cv` 200 HTML; `/export/pdf` 200
   `%PDF-1.7` 6 pages in 0.24 s; vHost `https://cv.home.lan/{,/pipeline,/health/live}` all 200
   via LAN bypass (after I fixed my own IP-SNI probe error, §d.3).
3. **Known-bug sweep:** SIGSEGV count 24h = 0 (the 2026-11-02 nil-deref loop stays dormant);
   0 err-level journal lines; cgroup oom/max = 0; post-restart throttle `high=634` (low).
4. **Timer inventory:** cv-scan last 12:23 SUCCESS (802 new jobs, 0 scan errors; ONE bulk-eval
   timeout appId=app-248, self-retries), cv-agent 04:41 SUCCESS (yesterday's Usage-limit death
   recovered), cv-relogin 09:11 SUCCESS, cv-backup 03:17 SUCCESS (pool artifact fresh: 287 MB),
   cv-profile-probe armed for Monday 09:41, cvagent-scan armed for ~05:58. All six verified via
   busctl Timer properties.
5. **First-exec failure root-caused:** 14:08 exec died exit 1 on `migrate sqlite event store:
   context deadline exceeded` (287 MB pipeline.sqlite vs the 5 s sqlite timeout, under the io
   storm) — the documented storm class, NOT a regression; Restart=always recovered at 14:11:42.
6. **cvagent diagnosis to root-cause depth:** 500-on-`/` started 2026-11-12 (per-day counts
   0/0/0/1485/6006/4974/2949); durations p50 4.9 s / p90 7.2 s / max 981.5 s today against the
   Gatus `<1000 ms` gate; store at **725 MB + 166 MB WAL** (~+65 MB/day); go-health doc shows
   `startup: fail — startup latch not set` (17 min uptime, same as 11.5 h on the prior
   generation) → `/health` 503 → "cvagent Health" red; `engines` deadline warn CLEARED in the new
   generation; renders improved 44 s+ → ~5 s. The `/health`-503 half of stability.md:46's
   coupling question is ANSWERED: it is the latch, not the by-phone poll.
7. **Two follow-up rows minted + committed** (`c4cd41538`, pathspec commit, pre-commit gates
   green): upstream read-scan/latch row + serve-unit git-PATH row, each with a TODO_LIST twin.
8. **Concurrent-session discipline held:** content-pin before writes (`ed17352c9` → re-read
   tails), pathspec commit that did NOT absorb the parallel session's staged status report or its
   integration.nix / negative-test-lints.sh edits, `/proc/pressure` sanity-checked before loops,
   boot id re-checked, redact-argv used on pgrep output.

## §b PARTIALLY DONE

1. **Deploy close-out verification** — I verified the NEW generation is live and serving
   (cv-e6fb98c + cvagent ed807315 + cvagent MemoryMax=1G confirmed), but the **anchor check is
   INCOMPLETE by design of the wave**: `/run/current-system`=vqi67vah while the newest profile
   link is still gen-1012→pf9iri4bc (the 13:52 holder has not created gen-1013 yet — its profile
   set lands after stc drains). A reboot before drain = the documented UNANCHORED revert class.
   Left as a queued watch row (harvested, §f.1).
2. **cv-agent brain pass detail** — unit Result=success at 04:41 recorded, but the findings/
   lessons-distill content of the pass was not inspected (Result-only). Folded into §f.7.
3. **cvagent-scan per-repo outcomes** — timer SUCCESS + finished 07:17 recorded, but today's
   `scanned=23 failed=?` line was not pulled (my first journal grep pattern missed it). §f.6.
4. **Dashboard functional check** — `/` 200 in 5.2 s verified; the startup-latch mechanics
   (WHY it never sets, and whether tomorrow's 05:58 scan lets it set) unverified — upstream code
   reading required (§f.3).

## §c NOT STARTED (noticed, deliberately not probed this session)

1. **CRM-mirror dead-letter/syncErrors** (`/api/pipeline/crm-status`, X-API-Key-gated) — I
   forgot the secret-FREE alternative the playbook implies: journal-grep for the dead-letter WARN
   lines. Not done; queued (§f.4).
2. **`backup_healthy{backup="cv"}` textfile metric + full 14-artifact retention window** — only
   the 2 newest pool artifacts were eyeballed. Queued (§f.5).
3. **OnFailure notification path** for cv-profile-probe (Monday's exit 3 → did the desktop
   notify actually reach the session bus?) — not verified. Queued (§f.8).
4. **SigNoz-side verdicts** (CV Server Down rule, Gatus Discord delivery receipts) — out of
   session scope; no probe attempted.
5. **Gatus API pull** — attempted, 401 (auth by design); check colors were derived from the
   check contracts + direct endpoint probes instead. Accepted limitation.

## §d TOTALLY FUCKED UP (all caught; own them)

1. **False "17-minute stall" verdict on cv-server — clock misread.** I read
   `ExecMainStartTimestamp` as 14:31:42 (it was 14:11:42), concluded "no journal since 14:21 →
   stalled" and nearly shipped "cv-server startup sync STALLED" while my query
   `--since 2026-11-15 14:28` was legitimately empty because **real time was 14:23** — the
   timestamp was in the future. Caught by the global-journal freshness check (`date` said
   14:23:59, last global line 14:23:59). Lesson recorded in §e.4. No wrong verdict shipped, but
   two commands ran on the false premise first.
2. **`rg -rn` hook trip** — the documented `-r`=REPLACE trap, third strike on this host per the
   hook's own message. Cost: one blocked call, zero damage. Inexcusable at strike three.
3. **vHost TLS probe with IP-SNI** — first HTTPS battery failed `TLSV1_ALERT_INTERNAL_ERROR`
   because I connected to `192.168.1.150` without `server_hostname`; self-corrected to hostname
   SNI (and dnsblockd was back by then). Cost: one wasted round trip.
4. **`getent hosts a b c` misread** — I initially read the multi-arg getent output (only evo-x2
   IPv6 lines) as "dnsblockd local zone broken" while dnsblockd was mid-restart from the switch;
   the follow-up probe (:53 listener count) was the correct verification and the restart
   explanation was confirmed before any conclusion shipped. The first read was still a
   conclusion drawn from an incomplete probe.

## §e WHAT WE SHOULD IMPROVE (process lessons from THIS session)

1. **`date` before every "silence" verdict** — a bare `--since HH:MM` a few minutes ahead of
   real time returns silently empty (midnight-trap cousin). First command of any
   timeline-sensitive diagnosis: `date` + the journal's last global line. Encode as a habit, not
   a rule-bullet only.
2. **Deploy-aware health checks need a pre-flight "is a switch in flight" probe** — the
   cv-server :8098 ECONNREFUSED + :53 gap + cvagent 500s were ALL switch artifacts for ~5
   minutes. The right first probe is `busctl ListJobs` + `pgrep -f 'switch-to-configuration'`
   BEFORE reading service failures, mirroring the deploy-flock-holder rule from the AGENTS
   pre-deploy side.
3. **Derive monitor verdicts from check CONTRACTS when the monitor API is auth-gated** — the
   Gatus check definitions (interval/conditions in-tree) + direct endpoint probes reproduced the
   red/green state exactly; no 401 retry loop needed.
4. **Post-restart counter re-reads are cheap and decisive** — memory.events reset verification
   (cvagent high=40772/16 min with max=0 at the new 1G cap; cv-server high=634) closed row
   393's re-read obligation in one command. Fold "post-restart counter read" into every unit
   we restart for a fix.
5. **Use the canonical battery when it exists** — I hand-rolled the endpoint probes; the
   productized `scripts/post-deploy-check.sh` (with its CV legs) is the durable surface and
   should run once the wave drains (§f.2), not a second hand-rolled pass.

## f) UP TO 50 THINGS TO GET DONE NEXT (new = harvested this session into TODO_LIST + services.md; existing = already queued, cited not duplicated)

**New this session (harvested, commit pending below):**

1. [new→services.md] Verify gen-1013 anchor equality (`readlink /run/current-system` == newest
   `system-N-link`) + run `scripts/post-deploy-check.sh` once the 13:52 wave drains; block any
   reboot until then.
2. [new→services.md] cvagent startup-latch watch: re-probe `/health` after tomorrow's 05:58
   cvagent-scan and after 24 h — does a fresh scan set the latch, or does it never set in any
   generation? (also pull that scan's `scanned=23 failed=?` line).
3. [new→services.md] Secret-free CRM-mirror health: `journalctl -u cv-server --since -24h |
   grep -i 'dead-letter'` + sync-error WARN sweep (replaces the X-API-Key-gated crm-status probe
   for routine checks).
4. [new→services.md] Backup freshness depth: read `backup_healthy{backup="cv"}` from the
   textfile metrics + count the full 14-day artifact window on /mnt/pool/backups/cv.
5. [new→services.md] Alert-routing proof: verify Monday's cv-profile-probe exit 3 actually
   reached a surface (desktop notify log / notify-send fallback line), not just OnFailure=
   dependency triggering.

**Existing — cv/cvagent service rows (cited, already queued):**
6. Seed freelancermap + gun.io in the sealed store (services.md:1081, blocked:user — owner act;
Monday probe will keep failing exit 3 until then).
7. First cv-relogin success proof after seeding (services.md:1082, watch).
8. cvagent dashboard read-model cache + settable startup latch (upstream.md, c4cd41538 — the
session's main find).
9. cvagent serve unit git-on-PATH (upstream.md, c4cd41538).
10. cv-server real-readiness assertion (ExecStartPost wait-for-port / Type=notify) — TODAY
re-proved the need: unit "active" for 15 min with :8098 unbound (services.md:638).
11. cv↔crm boot-sync storm upstream legs: bind-before-sync + StreamMarker leak
(services.md:637; today's storm-window sync is another datapoint).
12. CV render smoke IO-pressure-aware gate (services.md:267 — the /de/cv false-FAIL under io PSI
55% class; today's storm is the same shape).
13. CV browser render smoke clean-window rerun (services.md:363, watch).
14. CRM dedupe ~10,489 duplicates (services.md:295, blocked:deploy — sequences after the
checkpoint fix).
15. crm-server API token off ExecStart argv (services.md:296, bundles with CV rev bump).
16. CV analytics DB: provision or accept the permanent warn (services.md:640, decision).
17. CV graphrag: enable or accept the warn (services.md:641, decision).
18. Optionify cv.nix:86 `/home/lars/projects/CV` (+nsfw) (services.md:440).
19. cvagent post-deploy-check §-leg (TODO_LIST 1872).
20. cvagent preflight `cvagent health` before the scan loop (TODO_LIST 1873).
21. cvagent module VM YAML-parse assertion (TODO_LIST 693).
22. cvagent MaxCommitSample config-tunable upstream (upstream.md:252).
23. cvagent/cv-agent z.ai direct-traffic ai-meter visibility gap (runbook; routing row in
pipeline.md).
24. stability.md:46 by-phone read-storm premise — the /health half is answered (this report);
the 30 s io-delta measurement half remains open.
25. cvagent post-restart throttle counters after 24 h at the 1G cap (row 393's cadence; today's
post-restart baseline: high=40772/16 min, max=0 — recorded here as the re-read).

**Environment-level observations worth follow-up elsewhere (not CV-queued here):**
26. The 2 Hz /health federation poll journals one INFO line per poll per remote — journal-volume
question adjacent to monitoring.md:190's fetch-load row.
27. `sdc` 102.7% util in today's deploy entry-gate dump — ties storage.md:217's saturation-job
identification row (device naming by-id).
28. Memory-emergency-guard fired twice at 14:10 during the wave — worked as designed; freeze-risk
context for any NEXT deploy decision today (the calm gate is still refusing at 14:21+).

**(Stopped at 28 honest items — the instruction allows up to 50; padding to 50 with invented
work would violate the one-ask/real-work discipline. Every item above is real and
source-pointer-backed.)**

## §g QUESTIONS FOR THE OWNER (not answerable from the tree or live state)

1. **Who owns the 13:52 deploy wave, and is its close-out yours?** Six deploys today + a
   parallel session's staged status report + a second deploy process appeared and vanished
   mid-session. I will NOT anchor-verify or run the post-deploy battery while another session
   owns the drain — confirm whether I should pick up §f.1 or leave it to that session.
2. **cvagent dashboard: is ~5 s per render acceptable in the meantime?** The upstream fix
   (cached read-model + latch) is queued; a site-side WAL checkpoint on the 166 MB WAL might
   shave render time but MUTATES the live store (scan writes + dashboard reads) — want me to
   attempt it, or leave the store untouched until the upstream fix?
3. **Seeding intent for freelancermap + gun.io:** the Monday 09:41 probe will keep failing
   exit 3 (and paging) until the passwords are seeded at `cv.home.lan/admin/credentials/`. Do
   you intend to seed this week, or should the probe's OnFailure be muted (WARN instead of
   desktop-critical) until seeding happens?

## Self-harvest record

- §f.1–§f.5 → appended to `docs/todo/services.md` + TODO_LIST.md twins, committed with this
  report (pathspec; parallel session's staged files untouched).
- §f.6–§f.28 → all pre-existing rows, cited in place; deliberately NOT re-queued (no drift).
- §d/§e lessons: session-scoped (the `date`-before-silence + switch-in-flight pre-flight habits);
  not written to global memory (project-scoped lesson, lives in this report per doctrine).
