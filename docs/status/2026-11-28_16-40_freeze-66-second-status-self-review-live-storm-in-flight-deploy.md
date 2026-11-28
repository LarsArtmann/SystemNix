# Freeze #66, second status 2026-11-28 16:40: self-review of the crash session, a live storm, and a deploy crawling through it

**Created:** 2026-11-28 16:55 CET · agent session (crush, glm-5.4) · basis: this session's own commands and artifacts only

Round two of the status for "Why did we crash ~20 minutes ago?" (cut 2026-11-28 10:43:28). Round one: `docs/status/2026-11-28_14-10_freeze-66-status-watchdog-resets-without-dumps-breakers-retries.md` (called "the 14:10 report"). Autopsy: `docs/status/2026-11-28_12-15_freeze-66-llama-chat-idle-ttl-engine-panic-last-pre-fix-capture-cut.md` ("the autopsy"). Repo state described: `git rev-parse --short HEAD` = `bbff692f9` (16:51). Still boot `56ba232e` (gen-1033 booted; a newer generation is mid-activation, see below).

## Scope line

**Verified in this round (command + artifact, 16:40-16:51 CET):** `date`; boot id and `journalctl --list-boots` (same boot, no further cut); `/proc/pressure/{io,memory}`, `free`, `uptime`; guard trip count and the last three IO-TOP attribution lines of boot 0; llama-chat load count, idle-probe error count, thermal ENTER count of boot 0; the cgroup `io.pressure` ranking (stability.md step 0); process states and the 22 highest-CPU processes; build-process counts (`go`, `compile`, `link`, `nix`, `crush`); `scripts/pre-vacuum-evidence-gate.sh` (rc 0, `pass`, boot `0737ecd7` "evidence committed"); `scripts/session-start-probe.sh --gate` (rc 0, run late); `git log`/`git status`; the deploy logs `/var/log/systemnix-deploys/2026-11-28_{15-24-12,16-01-45,16-05-26,16-10-44,16-16-27}.log` (gate lines, phase headers, tails); the live deploy process tree (`pgrep -af` through `scripts/redact-argv.sh`); `ListJobs` over busctl; `journalctl -u boot-mirror-sync.service`, `-u forgejo.service`, `-u dnsblockd.service`, `-u forgejo-oidc-setup.service` since 16:23; read-only `sudo -n` reads of `/boot` and `/boot-mirror` (entry lists, `loader.conf`, `diff -rq`, `sha256sum` of the two `systemd-bootx64.efi`, the preferred entry's `init=` line); the gate-placement comments of `scripts/deploy.sh` (lines 201-229, 358).

**NOT verified in this round:** anything about the generation `c25v4icr…` that is being activated (what it changes, whether it carries the idle-activity fix); who started that deploy; who runs the Go and nix build battery; the four llama-chat pollers; the main kernel's panic reason; everything listed as not verified in the 14:10 report and the autopsy. Statements about earlier cuts (#34-#65) are quoted from the ledger, not re-run.

## TL;DR (16:51)

1. **The box is in a storm again right now.** Load 137 at 16:40 (50 at 16:49), io PSI some avg60 40-44 %, guard trips #13914 / #13915 / #13916 within 7 minutes, deep thermal throttle entered 16:39:40, 36 processes in stopped state (T; the guard's pauses, not attributed one by one). This is the pressure level of the 10:43 cut.
2. **A deploy is crawling through that storm.** Another session's `nix run .#deploy` (log 16-01-45) passed both gates legitimately (entry 16:01 at io PSI 1.21 %, pre-switch 16:21 at 2.66 %), built for 19 minutes, and is activating since 16:23:17: 28 minutes, forgejo needed one failed 10-minute start and a restart, dnsblockd came up at 16:49:10, 9 jobs were still pending at 16:49 (gatus, oauth2-proxy, miniflux, miniflux-oidc-setup, monitor365-server, media-atlas, three targets). Profile still `system-1033`, `/run/current-system` already `c25v4icr…`. If the box cuts before it finishes, it boots gen-1033 again.
3. **The boot mirror is currently divergent:** at 16:24:37 the activation installed a new `systemd-bootx64.efi` (systemd 262.2) on `/boot-mirror` only; `/boot` still has the older binary (different sha256), so `boot-mirror-sync` failed its diff gate at 16:24:54 ("refusing to call the 2nd boot disk current"). Entry sets on both ESPs are identical (50 each, `diff -rq` clean) and both prefer gen-1033, so the next boot is safe; the mirror needs one re-sync after the activation ends.
4. **The storm's engine this time is builds, not llama-chat alone:** 9 `go`, 3 `compile`, 6 `link` and 15 `nix` processes at 16:44, 47 `crush` processes alive, two `crush-daily.tes…` processes above 100 % CPU each; collectors again among the top readers (system-health-metrics 80 MB/s, usb-flap-metrics 50 MB/s, llama-vlm-cap-idle 45 MB/s, overview 101 MB/s). llama-chat has loaded 16 times on this boot, 30 idle-probe errors.
5. **What I did about it: nothing but look.** No service stopped, no signal sent, no file outside `docs/status/` touched in this round. The decisions are yours (§g).

## a) FULLY DONE

- Crash class, mechanism, drivers, evidence pull, ledger row #66: see the autopsy and the 14:10 report (a). Evidence: files under `docs/status/`, `docs/agents/stability.md`.
- TODO updates of round one (verified present at 14:32 by grep): `docs/todo/stability.md` rows "Deploy the llama idle-check fix and verify…" and "Make kdump capture one cut" updated, new `[decision]` row "Make hangs leave a dump…"; `TODO_LIST.md` NOW bullets 5 and 8 rewritten, kdump queue line updated, one new queue line. All auto-committed by the daemon.
- Pre-vacuum evidence gate: `pass`, the crashed boot is "guarded … evidence committed in docs/status/". This was the open "next" step of the evidence pull.
- Session-start probe (late, 16:42): CI 3 of 9 workflows green (`dns-blocklist-drift`, `nixpkgs-compat` today, `llama-rag-pin-expiry` 2026-11-01), 5 red, `hermes-bump` never ran; open rows 3559 (ready 2429), +97 in 7 days; pool budget spent today 15 of 30; SystemNix pool tasks last 7 days 105 (cancelled 74, completed 23, dead 5, pending 3); 6 failed units (boot-mirror-sync, crm-liveness, forgejo-hermes-token, inboxclean-sync, service-health-check, signoz-provision).

## b) PARTIALLY DONE

- Live-storm attribution: process classes and per-cgroup pressure are measured (16:44), the owning sessions are not named. Blocker: none, only that this round was a report. Effort: S.
- Boot-anchor check: both ESPs compared read-only; the re-sync after the activation is not done (not mine to trigger). Effort: S, owner or the deploying session.
- TODO harvest: 3 rows touched in round one; the 40 items of §f are routed and labelled, not harvested (reasons per item).

## c) NOT STARTED

- Naming the four llama-chat pollers.
- Reading what generation `c25v4icr…` changes and whether it carries the idle fix (one `git log` on the other session's work; not done because I do not know which tree it was built from).
- Isolating the 10-minute collector stall.
- Any fix or configuration change (capture cage, detector timeouts, runner gate, collector watermarks): decisions first.

## d) TOTALLY FUCKED UP

| What | Severity | Root cause | Mitigation |
| ---- | -------- | ---------- | ---------- |
| A deploy activation has been running 28+ minutes inside a 40 % storm with the anchor still on gen-1033 | HIGH, live | gates were green twice; the storm formed after them (activation restarts dozens of units, a build battery runs in parallel) | let it finish or intervene: owner call; then verify anchor + boot entry + mirror |
| `boot-mirror-sync` fails its gate since 16:24:54 (mirror has the new bootloader binary, `/boot` the old one) | MEDIUM, live | activation wrote to the mirror first; nothing retries the sync | one `systemctl restart boot-mirror-sync` after the activation, then the documented three checks |
| Build batteries from agent sessions and CI run beside an activation and beside the llama engine | HIGH | no admission gate covers `go build` / `nix build` started by sessions; runner has no PSI gate in `forgejo.nix` | none in place |
| The llama-chat idle engine is still live: 16 loads, 30 failed probes on this boot | HIGH | fix in tree (`2818c0751`), undeployed | the in-flight generation may carry it: unverified |
| Collectors are top readers in every trip: system-health-metrics 35-157 MB/s (morning) and 80 MB/s (16:39), usb-flap-metrics 50, llama-vlm-cap-idle 38-45, overview 101-111 MB/s | MEDIUM | collector watermarks and cadence | known since #56 and the 2026-11-27 storm anatomy; not fixed |
| Every panic since 2026-11-17 lost its vmcore; hang-class cuts can never dump | HIGH | capture boot = full NixOS in 512 MiB; watchdog 90 s beats hung-task 120 s | decision row added; unproven fix live |
| My round-one report called the remaining 33 of your "up to 50" padding | LOW (process) | laziness | this round lists 40 |
| Six failed units after the crash, two of them in the activation's job chain (forgejo-hermes-token, signoz-provision) | MEDIUM | not investigated | listed, not diagnosed |
| `session-start-probe.sh` reports the TODO gate times out after 60 s on this box | LOW | the gate is too slow under load | none |

## Self-review

**What did you forget?**

- The session-start probe at session start (ran at 16:42, six hours late) and the pre-vacuum gate after the evidence pull (ran at 16:42). Both pass; both were open all day.
- For two hours after "waiting" I did not look at the box again. The state changed under me: five more deploy attempts, one in flight, a new storm, a failing boot mirror. A status from 14:33 would have been false at 16:40.
- In round one I re-used the 10:57 anchor reading in my head; only the re-read at 16:45 showed the in-flight switch. Rule I broke: re-check before every status claim.
- The `kdump=` column of `crash-triage.sh` on the dying boot's row describes the PREVIOUS cut's pstore intake (pstore is archived at the next boot's start); the dying boot's own verdict sits on the boot-0 row. I read it correctly only after opening the archive.
- The TODO gate's ratchet: this session added one queue row and closed none.

**What is stupid that we do anyway?** Fail-closed idle probes; saving memory by spending IO on an IO-starved box; a capture kernel that boots a whole OS in 512 MiB; a watchdog faster than every detector; a guard that trips hundreds of times a boot and mostly finds nothing to pause; collectors that read 50-160 MB/s during the storms they measure; deploys whose activation restarts the DNS resolver and Forgejo while a storm builds.

**What could you have done better?** The five class probes and an interim answer inside ten minutes; python for the journal instead of awk; the full next-task list the first time; no status claim from memory.

**What can you still improve?** §e and §f: the pollers, the storm attribution per session, the collector review, the deploy-window admission lock, the capture cage, the detector order.

**Did you lie?** No. Three sentences of mine were wrong or ahead of the work today (ledger draft "longest since #52"; "9 ENTER→EXIT episodes"; "harvested" in the autopsy before the rows were edited); all corrected in place; the daemon had committed the first two.

**Ghost systems?** `watchdogd` has warning-level checks and a repair hook; `meminfo` is on, `loadavg` and `filenr` off, no repair configured: it pats the dog through every storm. `psi-wait-gate` exists for llama-chat, its refuse is undone by `Restart` 10 s later. `deploy.sh` runs its pressure gate twice, both times before the activation that produces the pressure.

**Scope creep?** None into code. The TODO harvesting in round one took longer than the diagnosis.

**Removed something useful?** Nothing.

**Split brains?** Watchdog contract (docs 30 s, live 90 s); idle-check row "deployed" versus broken (fixed); NOW bullet 5 stale after the reboot (fixed); evidence file names in UTC, reports in CET; the triage `kdump=` column reads forward one cut.

**Tests?** The `Is a directory` defect is pinned by one test per the module comment (not read). Nothing tests "idle check keeps a backend with a live bridge", "start contract under a slow load", or "a store directory spliced as a command".

**Re-verified inherited claims?** Watchdog timeout (differs from the docs), crm latency baseline (ledger #39 says 20 µs, live 0.50 ms, original not annotated), pre-vacuum gate (passes), the rest quoted.

**How can we be less stupid?** Fail-open probes; reload budgets; condition-based resumes; detector timeouts below the watchdog; one deliberate crash as acceptance for any capture-path change; no build batteries beside an activation.

## e) WHAT WE SHOULD IMPROVE

- A deploy-window admission lock: while a switch transaction runs, CI and agent builds wait (the gates cannot see what starts after them).
- Do not restart `dnsblockd` on a switch unless its unit changed; today it sat 26 minutes in the job queue while everything behind it waited.
- Collectors: PSI-gate their heavy legs, cap their bytes per run, and never SIGSTOP the monitoring.
- Idle checks fail open; llama-chat gets a reload budget; IO-RESUME by condition.
- `crash-triage.sh`: class probes first, census second, and label the `kdump=` column as "pstore archived at this boot's start".
- `boot-evidence-pull.sh`: `crash_kexec_post_notifiers` line, bounded guard section, one timezone in file names.
- Agent-shell footguns met today (bare `cat` with several paths, `rg -E`, busctl unit escaping twice, `kill -0`, `${PIPESTATUS}`): each cost a round trip; they belong in the shell-trap list.

## f) Next tasks, 40, routed

Routing: **H** harvested (already in the TODO system), **E** existing row named, **D** needs your decision, **P** premise not verified, **A** after task 1, **T** tooling or test, **R** roadmap fuel. Everything not H is deliberately not harvested: this session already minted one queue row and one decision row under the incident exception and closed none; say "harvest n, m" to add items.

| # | Task | Impact / effort | Route |
| --- | --- | --- | --- |
| 1 | Deploy the idle-activity fix (`2818c0751`), then run the six verification checks | Critical / S | H: row "Deploy the llama idle-check fix and verify…" (library, queue line, NOW bullet 8) |
| 2 | Deliberate crash test on the capture path, on a boot that carries the fix | Critical / S | H: row "Make kdump capture one cut" (owner) |
| 3 | Capture cage 2 GiB; detector timeouts below the watchdog | Critical / S | H: decision row "Make hangs leave a dump…" |
| 4 | After the in-flight activation ends: verify profile = current-system, the boot entry of `c25v4icr…` on both ESPs, and re-run `boot-mirror-sync` until its gate passes | Critical / S | P: the deploying session's close-out; mint if nobody owns it |
| 5 | Read what generation `c25v4icr…` changes and whether it carries the idle fix | High / S | P: step inside 1 and 4 |
| 6 | Decide llama-chat residency: resident (32.9 GB), keep-alive of several hours, or 60 min | High / S | D |
| 7 | Name the four llama-chat pollers (one `ss` read on port 8850) | High / S | P: step inside 6 |
| 8 | Reload budget for llama-chat: N cold loads per hour, then stay down and raise SEV1 | High / M | D |
| 9 | Start contract: stop killing and remapping a load that outlasts the curl budget under a storm | Medium / S | A |
| 10 | Socket cool-down after a failed start; give pollers a retry hint instead of a 30-minute bridge | Medium / M | A |
| 11 | `psi-wait-gate`: admit on two or three consecutive calm samples, not one | Medium / S | P: check the refuse-mode row first (stability.md "psi-wait-gate refuse mode") |
| 12 | IO-PAUSE: make page-in engines pausable when they are the top reader by bytes | High / M | D |
| 13 | IO-RESUME by condition; at the 3600 s cap stay paused and alert | Medium / M | D |
| 14 | IO-PAUSE DISARMED escalation: stop the attributed unit, not only headless process groups | High / M | D |
| 15 | `system-health-metrics`: PSI-gate heavy legs, leave the pause set (80-157 MB/s in five trips today) | High / M | P: look for the #56 amplifier row first |
| 16 | `llama-vlm-cap-idle` heavy path: 38-45 MB/s in two of the last three trips | High / S | E: remaining scope of the idle-check row |
| 17 | Collector review: usb-flap-metrics (50 MB/s), overview (101-111 MB/s), btrfs-balance-watch and niri-health-metrics (10-11 MB/s) | Medium / S | P: join the 2026-11-27 "collector watermarks" work |
| 18 | Stagger the 10-minute collector pile; re-measure crm p95 | Medium / S | P |
| 19 | Deploy-window admission lock: no CI or agent builds while a switch transaction runs | High / M | D |
| 20 | Do not restart `dnsblockd` on a switch unless its unit changed | High / S | P: check `restartTriggers` |
| 21 | Admission gate for `go build` / `nix build` started by agent sessions (9 `go`, 15 `nix` at 16:44 beside an activation) | High / M | P: the #64/#65 rows may already own it |
| 22 | Gate the host Forgejo runner (PSI or admission) or move CI off the box | High / M | P: do the workflows self-gate? |
| 23 | CI re-run cadence in storms (nix invocations about every 2 minutes, 10:26-10:36): cancel-in-progress or concurrency limits | Medium / M | P: in the CI'd repositories |
| 24 | `watchdogd`: evaluate the repair hook (shed load at warning); enable `loadavg` and `filenr` | Medium / M | D: I have not read what its critical level does |
| 25 | Minimal capture init instead of a full boot for kdump | Medium / L | R |
| 26 | Deliberate hang test once the detector order is changed | Medium / S | D: after 3 |
| 27 | Durable forensic bundle location (`/var/tmp` is volatile) | High / S | E: row queued per AGENTS.md |
| 28 | `crash-triage.sh`: class probes before the census; print live watchdog timeout and detector thresholds; relabel `kdump=` | Medium / S | T |
| 29 | `boot-evidence-pull.sh`: `crash_kexec_post_notifiers` line; guard section bounded to counts plus the last 200 lines | Medium / S | T |
| 30 | One timezone in evidence file names (UTC today) and reports (CET) | Low / S | T |
| 31 | Annotate ledger #39's crm baseline (20 µs versus 0.50 ms live) | Low / S | T |
| 32 | Fix the watchdog-contract drift (30 s in the stability text, 90 s live) | Low / S | T |
| 33 | Runbook `docs/services/kdump-capture-path.md`: add the signature "reset `0x02000800` with a capture-kernel pstore dump = panic class too" | Low / S | T |
| 34 | Shell-trap list: bare `cat` with several paths, `rg -E`, busctl unit escaping | Low / S | T |
| 35 | TODO gate times out after 60 s under load (`session-start-probe.sh` WARN) | Low / M | T |
| 36 | VM test: idle check keeps a backend that has a live bridge; a failed probe counts as activity | Medium / S | T |
| 37 | VM test: start contract under a slow load does not remap | Medium / S | T |
| 38 | Eval-time lint: a store path spliced as a command must be a file, not a directory | Medium / M | T |
| 39 | Diagnose the six failed units after the crash (crm-liveness, forgejo-hermes-token, inboxclean-sync, service-health-check, signoz-provision, boot-mirror-sync) | Medium / M | P: first re-check after the activation |
| 40 | Library rows carry several UPDATE clauses on one physical line (stability.md, 393 rows); move per-row history out | Low / M | R |

## g) Questions only you can answer

1. **The in-flight deploy:** it is another session's, 28+ minutes into an activation inside a 40 % storm with the anchor still on gen-1033. Let it finish, or do you want it stopped? And once it ends, do you run the anchor and boot-mirror verification yourself, or should the next session do it as task 4?
2. **llama-chat residency:** resident at 32.9 GB, a keep-alive of several hours, or the 60-minute idle unload? And may the idle-fix deploy be preceded by about 30 minutes with `llama-chat.socket` stopped so the gates pass without forcing?
3. **Evidence against stability:** may I reserve 2 GiB for the capture kernel and put the hung-task and lockup timeouts below the watchdog, accepting that a false detector hit becomes a reboot?

## Artifacts

- `docs/status/2026-11-28_12-15_freeze-66-llama-chat-idle-ttl-engine-panic-last-pre-fix-capture-cut.md` (autopsy)
- `docs/status/2026-11-28_14-10_freeze-66-status-watchdog-resets-without-dumps-breakers-retries.md` (round one)
- `docs/status/tasks/2026-11-28_11-04_boot-0737ecd7-evidence-pull.md`
- `~/.cache/crash-20261128/`: `pv-gate.txt`, `probe.txt`, `todo-gate-before.txt`, `todo-gate-after.txt`, pstore copies, journal dump
