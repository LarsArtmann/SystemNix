# SystemNix Status 2026-10-03 11:21 — Helium "history broken": wedged launch guard (FIXED in tree), split-profile design, data intact

**Task:** user-reported "Why is Helium Browser history broken!?!?" (open-ended symptom, no specifics given).
**Verdict:** NO data lost. Three compounding causes found: (1) the `helium-launch` empty-window guard's pgrep matched the per-monitor dp1/dp2 instances and **wedged `helium.service` for whole sessions — the main profile (1510-url History) never auto-launched**; (2) the 2026-09-29 per-monitor instance design inherently **splits history across three profiles** (dp1 held 6 urls); (3) two crashes (10-02 SIGBUS during ENOSPC, 10-03 10:42 kernel OOM) made the browser feel unstable but did NOT corrupt the History DBs. Guard fix landed in `platforms/nixos/desktop/niri-wrapped.nix`, committed as `83c43187` (daemon commit, content verified).

## Evidence (all live-checked this session)

| Check | Command/probe | Result |
| --- | --- | --- |
| Main History DB | python3 sqlite3, `PRAGMA quick_check`, ro | **ok**, 1510 urls, last visit 04:18 UTC 10-03, 98 visits since 10-02 06:00 UTC |
| dp1 History DB | same | **ok**, 6 urls |
| dp2 History DB | same | **live-locked** (18s+ retry failures); History-journal 0 bytes = no hot journal → likely fine, UNVERIFIED |
| Guard match | `pgrep -af "helium --ozone-platform-hint"` | matches BOTH dp instances (PIDs 1705618/1705619, up since 10:48:08) |
| Main instance running? | `ps` at ~10:51 | NO process without `--user-data-dir`; main profile mtime 09:08 |
| Crash timeline | `journalctl --user -u helium.service` | 10-02 06:33 SIGBUS (crashpad `writev: ENOSPC`), SEGV 06:33:13, restarts 2–3, clean from 11:01 session; 10-03 06:25 start → 10:42:44 `app-niri-sh-3244533.scope` kernel-OOM (1.1G peak, 905M swap) → 10:43:55 helium.service OOM-killed → 10:48:08 relaunched |
| Disk | `df -h` | `/` 89% (84G free), `/data` 79%, pool 15% |
| Fix logic | fake main instance (`exec -a` + python3) | guard rc=0 with main alive, rc=1 dp-only (launch proceeds) |
| Lint | `shellcheck --severity=style` on extracted text | clean (SC2148 shebang artifact only) |
| Eval | `nix flake check --no-build` | all checks passed |
| Formatting | `alejandra --check` | fails on **HEAD too** (`01e7e1c1`) — pre-existing drift, not mine; left alone, queued |
| Queue guard | `scripts/check-todo-system.sh` | structure OK; 51 drift + 80 unharvested §f WARNs (pre-existing backlog) |

## a) FULLY DONE

1. **Diagnosis**: root cause chain identified and evidence-backed (table above).
2. **Guard fix**: `helium-launch` now waits only while a matching process WITHOUT `--user-data-dir` in `/proc/<pid>/cmdline` exists (niri-wrapped.nix). Both branches live-tested; shellcheck clean; flake check green; committed `83c43187` and content-verified in the commit.
3. **SIGBUS verify row closed** (the open "Verify helium recovered after the 06:32 SIGBUS crash" row): helium recovered (crash-looped to the 11:01 session, ran until today's OOM, relaunched 10:48); DBs survived. Closed on BOTH surfaces (TODO_LIST.md + docs/todo/desktop.md) with consistent close-outs.
4. **New findings queued**: kernel-OOM triage ([ready], stability.md + TODO_LIST.md), 3 desktop rows (below).
5. **Docs/memory**: desktop.md gotchas updated (guard scope + separate-history consequence); agent-sandbox shell quirks appended to docs/agents/shell-devtools.md (systemctl blocked, kill/`$!` broken, exec -a payload choice).
6. **Daemon-race verification**: all 3 daemon commits inspected with `git show --stat`; my content intact in each; the ONE foreign line identified (below).

## b) PARTIALLY DONE

1. **dp2 History integrity** — the only profile never checked (browser holds the lock). Queued as its own [ready] row (verify at next browser close).
2. **End-to-end fix verification** — logic-tested on extracted text, but the REAL writeShellApplication shellcheck gate + the live service behavior need a **deploy**. Queued [blocked:deploy] with the post-deploy probe.
3. **"Since 09-29" wedge start date** — mechanism certain (pgrep match proven live), but the START date is inferred from the dp-instance commit, not journal-pinned. Folded into the session-restore trace row.
4. **The user's actual symptom** — I diagnosed the objectively-broken things (wedge + split) without knowing what the user SAW. If the symptom was e.g. omnibox suggestions or a chrome://history render error, coverage is partial → §g.1.

## c) NOT STARTED

1. Deploy of the guard fix (deliberately: live system mid-session, not asked, OOM churn today).
2. Kernel-OOM 10:42 triage (queued [ready], stability.md).
3. Profile-split decision (queued [decision], desktop.md) — owner call.
4. Session-restore non-spawn trace + wedge start-date journal-pin (queued [ready]).
5. alejandra standalone re-format of niri-wrapped.nix (queued [ready], pipeline.md).

## d) TOTALLY FUCKED UP

Nothing landed broken. Honest sloppiness, worst first:

1. **Diagnosed without asking what the user saw.** The report was this vague ("history broken!?"), and I guessed the symptom from evidence. Autonomous-by-default doctrine says proceed — but a single parallel clarifying question while diagnosing would have de-risked the whole answer. Corrected by making it §g.1.
2. **"Shellcheck clean" provenance is extraction-level**, not the derivation's real checkPhase gate (which only runs at deploy build). Not a false claim, but softer than it reads.
3. **Three wasted cycles on the fake-process test** (exec -a + sleep broke on coreutils argv0 sniffing; sandbox `$!` mangled; stderr-suppressed `kill` silently no-op'd) and **transiently left an untracked fake "main-instance" process alive ~1 minute**. No consumer existed, so harmless — but the cleanup should have been atomic with the test.
4. **Closed the SIGBUS queue row without a footer-bearing commit of my own** (conversational task, no Task-Queue-ID; relies on daemon commits). The report convention exists precisely for this — this file closes that gap ~40 min late.
5. **dp2 declared "likely fine" from indirect evidence** (0-byte journal) before enumerating it in the integrity sweep; a cleaner pass checks all profiles FIRST and states the unverifiable one upfront (the close-out did state it, but late).

## e) WHAT WE SHOULD IMPROVE

1. **Parallel clarification**: for vague symptom reports, fire one precise question WHILE the forensic pass runs — autonomy and clarification are not exclusive.
2. **Verify against the real gate sooner**: extract-and-shellcheck is a proxy; build the derivation (or accept "pending build" labeling in the close-out).
3. **Surface-first integrity sweeps**: enumerate every profile/DB in the domain BEFORE running checks; unverifiable items get flagged in the first statement, not discovered mid-pass.
4. **Footer-bearing evidence per close-out**: even conversational diagnoses land a status report in the same pass (done here, should be default).
5. **Atomic test fixtures**: in this sandbox, create-probe-kill-cleanup must be ONE command (kill rc untrustworthy; pgrep is the only honest liveness check).
6. **Daemon-commit hygiene held** this time (show --stat after each sweep) — keep it mandatory after every daemon batch touching my files.

## f) NEXT (prioritized; tagged per queue taxonomy)

**Helium / this session's direct follow-ups**
1. [blocked:deploy] Deploy + verify the main-only guard (row queued in desktop.md; probe: with dp windows open, helium.service must exec a main-profile instance).
2. [decision] Profile-split fork: keep dp instances (three histories) vs drop them (one history, lose per-monitor routing) vs keep+document (row queued).
3. [ready] Trace the 10:48 session-restore non-spawn + journal-pin the wedge's real start date (row queued; includes: are dp-window app-ids `helium-dp1/dp2` saved/restored by niri-session-manager at all?).
4. [ready] Verify dp2 History at next browser close (row queued).
5. [ready] Kernel-OOM 10:42 triage (row queued in stability.md: which consumer crossed; did oom_score_adj=1000 bun runs shield anything; freeze-class signature?).
6. [ready] alejandra-format niri-wrapped.nix standalone (row queued in pipeline.md).
7. Post-fix, document in desktop.md which entry point opens WHICH profile (keybind/launcher vs dp windows vs xdg-open vs session restore vs helium.service).
8. If §g.1 reveals the symptom was omnibox suggestions: integrity-sweep `Shortcuts`/`Top Sites`/`Visited Links` DBs in all three profiles.
9. If §g.2 picks unified history: one-commit revert plan for dp instances (spawn-at-startup, window rules 756/760, session-manager list interaction).
10. Usage probe for the decision: does the dp1 window earn its keep (4 visits since 10-02)? `niri msg windows` + ActivityWatch window bucket.
11. Regression-proof the guard: repo selftest check that the guard ignores `--user-data-dir` processes (the check-todo-system.sh selftest pattern), so a future launch-shape change can't re-wedge silently.
12. Verify `--restore-last-session` actually restored dp tabs after the 10:43 OOM kill (tab-level session survival; the closed row only proved DB survival).
13. Trivial: sweep the ~30 stale `.org.chromium.Chromium.*` 3KB temp files in the main profile root (Aug-dated crash leftovers).
14. [watch] `helium_crashpad_handler --url=https://crash.helium.computer/crash` — confirm upstream telemetry endpoint is intentional/configurable in an ungoogled fork.

**Queue-system hygiene (noticed via check-todo-system.sh, pre-existing)**
15. Decide the gate-hardness for the 51 queue/library drift WARNs (CHECK_TODO_PAIRING=strict currently fails; decision pending) then burn down.
16. Burn down the 80 unharvested §f reports backlog (WARN list in the guard output).
17. Prune today's new `[x]` rows (SIGBUS verify, re-fire-5 relocate) to CHANGELOG next pass.
18. Verify the next daemon sweep commits the last 2 dirty files (TODO_LIST.md, docs/todo/desktop.md) correctly; pathspec-commit if it sweeps foreign work.
19. Identify the 11:18:44 foreign TODO_LIST edit (another session active mid-pass; my edits co-exist, nothing reverted). The same session's ROADMAP line ("Connection notices on the desktop", iNiR connections IPC) rode daemon commit `94b94056` — attributed here, left intact.

**Adjacent infrastructure (noticed in passing, not researched)**
20. Root fs 89% with 84G free — confirm pre-deploy-check's disk-space leg actually gates at this level (the 10-02 storm class).
21. `systemd-coredump: "terminated abnormally without generating a coredump"` during ENOSPC — coredump store sizing/retention under disk-full (the crash forensics gap bit this incident: SIGBUS minidump lost).
22. Re-check the 10-02 ENOSPC underlying growth: root refilled to 89% within a day of the storm — is the growth driver actually fixed or just freed?

**Deliberately NOT harvested from §f**
- Chromium History `.backup` snapshot before risky deploys — btrbk already snapshots root; belt-and-suspenders only if the owner asks.
- Entry-point→profile map doc (item 7) — blocked on §g.1/§g.2 answers; harvesting a row now would bake in a wrong premise (the queue's spot-verify rule).
- dp-window restore-policy sub-question — folded into item 3's row rather than a separate row.
- crashpad telemetry (item 14) — [watch]-class, upstream-config question, listed here only.

## g) QUESTIONS (need you — not derivable from the system)

1. **What did "history broken" actually look like, and in which window?** Empty chrome://history? Missing omnibox suggestions? New visits not recorded? An error page? In a monitor web-workspace (dp) window or one opened via launcher/xdg-open? → determines whether wedge+split fully explains your symptom or something else is hiding.
2. **Profile fork**: keep the per-monitor instances (three separate histories — now at least the main profile auto-launches again), drop them (one unified history, lose per-monitor web-workspace routing), or keep+document? → unblocks the [decision] row and items 7/9/10.
3. **Was the 10:38–10:42 `bun install`/`e2e/smoke.mjs`/`test` storm yours (which project?), and did you deliberately relog at ~10:48 after the OOM?** → attributes the OOM cascade's memory consumers and explains the session-restore thread (journal shows the manager swap, not the intent).

## Files touched this session

- `platforms/nixos/desktop/niri-wrapped.nix` — guard fix (`83c43187`)
- `docs/agents/desktop.md` — guard-scope + separate-history gotchas (`3ee5247a`)
- `docs/agents/shell-devtools.md` — agent-sandbox shell quirks (`94b94056`)
- `docs/todo/desktop.md` — SIGBUS [x] close-out + guard-verify/session-restore/dp2/profile-split rows
- `TODO_LIST.md` — SIGBUS [x] close + 2 desktop one-liners + stability OOM one-liner + pipeline alejandra one-liner
- `docs/todo/stability.md` — kernel-OOM triage row (`3ee5247a`)
- `docs/todo/pipeline.md` — alejandra re-format row (`94b94056`)
- this report

**Status:** report authored; awaiting owner answers to §g before items 7/9/10 and any deploy.
