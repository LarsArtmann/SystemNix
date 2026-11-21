# Mic-Monitor Wave DEPLOYED + Full Post-Deploy Battery GREEN; Shared Chain Verified; Summit Fix Committed Behind the Armed Watcher — 2026-11-21 23:12 CET

Session: resume of `docs/status/2026-11-21_17-08_mic-monitor-collectors-pool-audio-archives.md` under the owner directive "finish the whole todo list". Content-pin at authoring: HEAD `69e2851d4` (my row-tick commit on top of sibling commits `168cf4875` summit float + `2987392a8`/`8b425f0d3`), tree dirty ONLY with other sessions' files (AGENTS/CHANGELOG/TODO_LIST/14-37 report — not mine to land).

**Bottom line:** the deploy I was waiting for was fired by a parallel session at 19:27:50 (root actor via `/tmp/psi-deploy-fire.sh`, after their resume3 orchestrator died on a root-owned `/tmp/.systemnix-deploy.lock`), landed as **gen-1021 anchored 20:48** (deploy exit 3 = smoke regressions, all triaged below). **The ENTIRE mic battery is green** — collectors live and producing, pulse bridge proven inside the agent's mount namespace, audio's pool home proven inside the server's. The deploy's two real casualties (summit-planner seeder crash-loop, cv-server killed mid-switch) are triaged to root cause; cv-server is back healthy, summit's fix is committed upstream + floated and rides the armed patient watcher (`deploy-when-quiescent --fire`, pid 2366748, holding on tree-dirty from OTHER sessions).

## a) FULLY DONE

1. **The deploy landed (gen-1021)** — fired 19:27:50 by a parallel session, 4856s duration, anchored by number (`readlink /run/current-system` == `system-1021-link` == f7qlsnwg0). My role: detected it mid-switch, did NOT double-fire, monitored to drain.
2. **Mic battery — ALL 6 LEGS GREEN (live evidence, ~20:0x):**
   - (1) journal: both collectors registered, no EACCES; the 19:39 `mic_monitor` silence-warning proves a live loop (change-detection is quiet with no app using the mic — correct).
   - (2) `:9421/metrics`: `collector_events_collected{mic_monitor}=229`, `{audio_stream}=7`, ZERO `collector_errors` for both.
   - (3) pulse bridge: PROVEN in `/proc/<agent>/mountinfo` — `/pulse/native` (uid=1000 tmpfs) → `/run/monitor365/pulse/native`; `PULSE_SERVER` + `pulseaudio-17.0/bin` in the unit env. The `-`-prefix/late-login caveat never bit (session up since 11-19). NOTE: from OUTSIDE the namespace `/run/monitor365/pulse/native` shows as a root-owned empty regular file (systemd's target node) — that is EXPECTED, the bind is private to the unit.
   - (4) pool dir `drwxr-x--- monitor365-server` + the server-side bind PROVEN in `/proc/<server>/mountinfo`: `/services/monitor365/archives` → `/var/lib/monitor365-server/archives` (btrfs, zstd). Audio's durable home IS the pool.
   - (5) first `audio.stream` well inside the 5-min window (7 events in the first 40 min; uploads confirmed server-side: `POST /api/v1/events/upload/binary 200` every minute).
   - (6) deployed agent runs a fresh monitor365-0.1.0 store path with both collectors; SystemNix lock `6696b8a47` verified on origin/master.
3. **Shared chain legs (mine per the 17:08 §f):** paperless-gpt **active/running** (was start-limit-dead since Nov 20 23:22 — recovered exactly as designed via the deploy's unit restart); DisallowedHost **0** since deploy vs the 25,638/48h baseline; InboxClean battery FAIL was transient (re-probe: 200, 142KB body); Health Hub /readyz 503 = CV-remote-dark knock-on; crm-server active.
4. **Casualty triage (the deploy's exit-3 regressions):**
   - **cv-server**: died 20:28:04 to a STOP requested ~20:26:34 mid-start (control process TERM'd; main was healthy and crm-syncing; default 90s TimeoutStopSec → SIGKILL — stop-class death, so Restart=on-failure never fired). Origin consistent with the 19:27:42/19:27:50 deploy-attempt race (rc=14 attempt ran 32s into the other's switch). NOT a code bug. **RESOLVED ~22:11** by parallel-session/owner work: /health 200, version aa7a492 (new binary), status warn = the known groq-key warn, not a failure.
   - **summit-planner**: deterministic — seeder fatals `[conflict:event_exists]` against the adopted dev DB → 5× restart → start-limit-hit 19:38:58. Root cause upstream (sibling's wording, better than mine: projections fold asynchronously at boot so the reconcile read misses streams the journal already holds). Fixed upstream `3e26dea` (pushed 19:43), floated by sibling commit `168cf4875`, awaiting the armed watcher's deploy.
5. **Row ticked + committed**: `docs/todo/services.md` mic battery row → `[x]` with the full evidence (commit `69e2851d4`).
6. **Cleanup**: `~/.cache/micmon/` (probe builds/logs/evals, 100K) trashed.
7. **Upstream repo legs**: mic-monitor C20 note daemon-committed (76d30d8); monitor365 locked rev 6696b8a47 on origin (5 newer commits still daemon-push-pending — irrelevant to the deployed lock).

## b) PARTIALLY DONE

1. **summit-planner revival** — fix committed + floated at HEAD, but the armed watcher (pid 2366748, up ~2h) is holding on "tree dirty (6 entries)" — ALL six are OTHER sessions' files (AGENTS.md, CHANGELOG.md, TODO_LIST.md, 14-37 report, …). It fires the moment they land + PSI calms; the deploy then restarts summit-planner (unit store path changes) and it must come up clean (seeder now skips recorded events). Verification: unit active + `http://127.0.0.1:7612/healthz` 200.
2. **Post-deploy battery re-run + diff vs `baseline-pre-resume2-20261121.txt`** — expected drops (Paperless, paperless-gpt) confirmed via direct probes; the formal `post-deploy-check.sh` capture-once re-run deliberately deferred until the watcher's deploy lands (running it mid-wave would poison the self-updating baseline with the summit-down state — §f.50 discipline).

## c) NOT STARTED (deliberately)

1. Battery items needing the NEXT deploy (summit healthz, gatus summit check green).
2. Night-2 monitor365 retention legs (~03:1x 2026-11-22, tq session's rows 3813/3814 — theirs).

## d) TOTALLY FUCKED UP (honest self-review)

1. **Misread the clock once**: read `10:47:43 PM` as 23:47 — a downstream "2 hours passed?" confusion about the flake.lock mtime until I re-ran `date`. The `date`-first rule exists for evidence FILES; it applies to reasoning about mtimes too.
2. **Two self-match pgrep loops**: my drain watchers polled `pgrep -f` patterns that my own background shell's cmdline contained — the loops never printed DRAINED while matching themselves, and I briefly concluded "processes gone but no exit line" from a pattern artifact. The `/proc/<pid> -d` liveness check (second watcher) was the fix; pattern-splitting (`'bin/depl'"oy"`) is the general one.
3. **Initial cv-server theory (TimeoutStartSec < ExecStartPost patience) was wrong** — the unit has TimeoutStartSec=21min covering the 20-min wait. Corrected by reading the unit file before proposing a fix; the real cause was the stop-class kill. Good: I discarded the theory on evidence instead of shipping a "fix" for it.
4. **Nearly duplicated the sibling's summit wave**: I had a commit message drafted for the staged float when the sibling's live `git commit --amend` showed up in my lock-failure probe. The lock contention itself saved me from a colliding commit — luck, not design. The `pgrep -af 'git (commit|add…)'` check should be part of ANY takeover of orphaned staged work, BEFORE composing the commit.

## e) WHAT WE SHOULD IMPROVE

1. Orphaned-staged-work takeover needs a first step: `pgrep -af 'git (commit|add|amend)'` — a live sibling amend is invisible in `git status` (staged state looks identical to dead-session residue).
2. Deploy-attempt rc=14s (19:30/19:35) raced the live switch and are the leading suspect for cv-server's stray stop job; the flock guard refuses NEW deploys but two nearly-simultaneous fires (19:27:42 + 19:27:50) both reached switch territory. Worth one pipeline row: serialize deploy invocations harder (flock acquire BEFORE any switch-adjacent phase) or document the rc=14 partial-switch hazard.
3. cv-server's default 90s TimeoutStopSec SIGKILLed a healthy process mid-sqlite-sync — a graceful-drain `TimeoutStopSec` remains a legitimate hardening row for the cv module owner (I did NOT ship it: cv is healthy now and the change would force an extra unit restart in another session's wave).

## f) NEXT

1. **The armed watcher's deploy** (pid 2366748): once the tree settles it fires; verify summit-planner active + `/healthz` 200 + the gatus check green, then run `post-deploy-check.sh` capture-once and diff vs `~/.cache/lockfloat/baseline-pre-resume2-20261121.txt` (expect summit-planner absent from NEW failures; CV legs green now that cv is up).
2. Night-2 retention journal read (~03:1x) — tq session's rows.
3. First `audio.stream` Parquet lands ~2027-02-20 (90d cutoff) — empty pool archives dir until then is CORRECT.

## g) QUESTIONS FOR THE OWNER

None new. The 17:08 §g trio resolves as: (1) deploy authority — exercised by parallel sessions all evening under your standing directive; (2) audio scope — periodic sampling is live; the continuous-capture question stays open in mic-monitor C20 (upstream product decision); (3) retention — 100d grace deployed and documented; revert to 90d only if you prefer accepting the archive-skip edge.

— Session close: mic wave fully verified live, row ticked, cache cleaned, shared chain green, summit leg explicitly handed to the armed watcher with its verification steps written down.
