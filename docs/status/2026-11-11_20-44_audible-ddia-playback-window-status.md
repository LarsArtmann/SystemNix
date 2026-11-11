# Audible playback window: DDIA started, verified, then died silently

**When:** 2026-11-11 20:44 CET · **HEAD:** `2d70f1644` · **Tree:** clean (foreign takeout files excluded) · **Books:** 65 / 28 GB (stable)
**Session window:** 20:04→20:44 — the owner browsed the archive (pasted four `ls` views), asked what M4B is + the biggest book, asked to start *Designing Data-Intensive Applications*, and asked whether the archive works without Audible.

**Owner's opener answered in one line each:**
- **Forgot:** to verify AUDIO actually reached an output device (the IPC said "playing", which is not sound), and to keep mpv's logs — I launched with output discarded, so when it died ~30 min later the death was undiagnosable.
- **Could have done better:** shipped control recipes as raw chat one-liners instead of a committed helper script; the owner can't re-find them and socat (the natural tool) isn't installed on the box.
- **Can still improve:** a `scripts/audible-ctl` helper (status/play/pause/seek/stop/now-playing) with file-logged mpv and `--save-position-on-quit` so a 21-hour book survives restarts with position intact.

**Scope — VERIFIED here:**
- Biggest book: `stat -c '%s'` sorted → **1,196,749,462 bytes** — `B08VL79B2C_Designing_Data-Intensive_Applications…` (runner-up `B09DT83XTV_Secrets_of_Professional_Tournament_Poker…` at 1,185,061,486).
- Playback start: mpv launched detached (setsid, PID 3084218) with IPC socket `/run/user/1000/mpv-audible.sock`; python socket query verified `duration=75404.7s (20h56m)`, `time-pos=16.5s advancing`, `pause=false`, correct media title.
- DRM-free confirmation: the files are plain AAC-in-M4B (RC4 DRM decrypted during the `-c copy` remux); the running playback used a bare filesystem path with zero Audible processes/credentials/network — offline playback proven by construction.
- Playback death: `pgrep mpv` empty at 20:44; stale socket file remains; no user-journal mpv entries; books/ unchanged (65).
- Tree/commits: HEAD `2d70f1644` unchanged this window (no new commits by me); foreign takeout session staged files observed, untouched.

**Scope — NOT verified:**
- **Why mpv died** (~20:15→20:44 window): output was discarded at launch (`>/dev/null 2>&1`) — crash vs owner-kill unknowable. The owner had the kill command in chat, so an intentional stop is plausible.
- **Whether sound reached the speakers** while it played: IPC state is not audio verification; no sink-input check was run.
- Position lost: mpv had no `--save-position-on-quit`; wherever playback died, restarting restarts at 0:00 unless a start offset is passed.

---

## a) FULLY DONE

1. **DDIA playback started and live-verified** — detached mpv + IPC socket; duration/position/pause/title all confirmed via a python unix-socket query (socat absent on the box).
2. **M4B explained + biggest book answered with exact bytes** — 1,196,749,462 B for Designing Data-Intensive Applications; M4B = MP4-variant audiobook container (AAC audio + chapters + bookmarks), DRM-free after the activation-bytes remux.
3. **Offline independence proven and stated** — the archive plays with zero Audible involvement (no account, auth, or network); the live playback itself was the proof.
4. **Control surface documented in chat** — pause/resume/seek/stop recipes via the IPC socket (python3, since socat is missing).

## b) PARTIALLY DONE

1. **DDIA playback** — started, verified playing, then died silently within ~30 min (cause unknown, logs discarded at launch). Restart command ready; position was NOT saved (restarts at 0:00). Remains: relaunch with logging + `--save-position-on-quit` + a start offset if the owner wants to resume. Effort: S.
2. **Playback control ergonomics** — python3 one-liners work but live only in chat; socat absent. Remains: commit `scripts/audible-ctl` (status/play/pause/seek/stop/now-playing/log-tail). Effort: S.

## c) NOT STARTED

1. **`scripts/audible-ctl` helper** (see b.2).
2. **Watch-later/position persistence for the archive** (mpv `--save-position-on-quit` or a bookmarks file per book).
3. **Audiobookshelf-style server** for phone/browser browsing of the 65-book library (roadmap; not requested yet).
4. **The 21 non-downloaded items attribution + skip-if-exists Sunday test** (queued 20:04 report §b.1).
5. **sops skill source-repo persistence** (queued 20:04 §b.2).
6. **Everything queued this morning** (canary start, stamp-counts, deploy-claim, tree-reap, pressure authority, pre-flight codify, is-failed sweep) — untouched since.

## d) TOTALLY FUCKED UP

1. **I launched mpv with `>/dev/null 2>&1`** — when it died ~30 min later there was NO error output, NO log, NO way to diagnose. A 1.2GB/21h playback session with telemetry thrown away. Next launch: log to `~/.cache/audible-fix/mpv.log` + `--save-position-on-quit`.
2. **"Playing" ≠ "audible"**: I verified IPC properties and called it playing without a single sink-input/pactl check. If the owner heard nothing, my "Playing." headline was wrong — I still don't know which.
3. **Control recipes exist only in chat history** — uncommitted, unfindable, unversioned. The harvest rule catches repo docs, but chat-only instructions evaporate.

## e) WHAT WE SHOULD IMPROVE

1. **`scripts/audible-ctl`** (status/play/pause/seek/stop/now-playing + log tail) — one entry point instead of socket-recipe prose; commit it so it survives.
2. **Every long-running launch keeps a log file** — `>/dev/null 2>&1` is diagnosability suicide; default to `~/.cache/<topic>/<name>.log` (the /tmp-volatility lesson, applied to process output).
3. **Position persistence**: `--save-position-on-quit` on archive playback starts, so a 21h book isn't restart-from-zero after any interruption.
4. **Verify perceived output, not just process state** — one `pactl list sink-inputs` (or equivalent) alongside the IPC check when "playing" is the claim.
5. **Install socat** (or ship a tiny python helper) for socket one-liners — python3 works but the recipes are 3× longer than needed.
6. **Stale IPC sockets should self-report**: a dead socket file made the death LOOK like a live-but-silent player until the connect failed; audible-ctl should treat connect-refused as "not running" and say so.

## f) NEXT — up to 50 things to get done next

*(items 1-8 NEW/carried-forward from this window; the queued backbone from today's reports stays live — listed at the bottom; full detail in `2026-11-11_20-04_…` §f.)*

1. **Commit `scripts/audible-ctl`** (status/play/pause/seek/stop/now-playing + log tail; connect-refused = "not running") — High / S / Feature (NEW).
2. **Relaunch DDIA with hygiene**: log file + `--save-position-on-quit` (+ resume offset on request) — High / S / Feature (NEW).
3. **Probe audio output on play** (sink-input check as part of audible-ctl status) — Medium / S / Verification (NEW).
4. **Attribute the 21 non-downloaded library items** — High / S / Verification (queued).
5. **Test skip-if-exists semantics for refused items** (silent-cap risk) — High / S / Bug-risk (queued).
6. **Probe Backup Freshness endpoint + PapDashboard tile post-seed** — Medium / S / Verification (queued).
7. **Persist the sops recipe in its source repo** — Medium / S / Documentation (carried).
8. **Sunday-tick watch (2026-11-15 05:00)**: first real timer run — Medium / S / Verification (queued).
9. **Owner: 128 kbps AAX quality vs Audible-support escalation** — High / S / Owner call (carried).
10. **Owner: Plus borrowals in archive scope?** — High / S / Owner call (carried).
11. **Owner: pma storm kill/pause** (hour ~20) — High / S / Owner call (carried).
12. **Audiobookshelf-style server for the archive** (phone/browser playback of all 65) — Medium / L / Feature (NEW; natural once playback control exists).
13. **Cover/PDF handling decision** (loose .jpg/.pdf in downloads/) — Low / M / Cleanup (queued).
14. **Per-title refusal metric** — Low / M / Feature (queued).
15. **Newer audible-cli evaluation** — Medium / M / Feature (queued).
16. **Pre-deploy build-touched-drvs step** — High / S / Quality (queued).
17. **Multi-agent deploy poll-for-gen protocol** — Medium / S / Quality (queued).
18. **Runtime canary start in deploy battery** — High / M / Quality (queued).
19. **`nix run .#stamp-counts` helper** — Medium / M / Quality (queued).
20. **deploy.sh tree-reap post-rc** — High / M / Quality (queued).
21. **Shared deploy-claim file** — Medium / M / Quality (queued).
22. **Daemon honor-file / index.lock hygiene** — Medium / M / Policy (queued).
23. **DEPLOY_FORCE_PRESSURE authority rule** — High / S / Policy (queued).
24. **Deploy pre-flight codify** — High / S / Quality (queued).
25. **Post-provisioner is-failed sweep** — High / M / Quality (queued).
26. **Poll-loop float-quiescence gate** — Medium / S / Quality (queued).
27. **Smoke battery persistent-vs-self-healed re-probe** — Medium / M / Quality (queued).
28. **forgejo-github-sync exit 6 triage** — High / M / Bug (queued).
29. **forgejo-runner ensure-timer diagnosis** — High / S / Bug (queued).
30. **tq-agent-pool cgroup escape + swap** — Critical / M / Bug (queued).
31. **bank-sync-qonto-corpus unit triage** — Medium / S / Bug (queued).
32. **pim-sync enable flip** — Medium / S / Feature (queued).
33. **google-sync + pim-sync OAuth console unblock** — Medium / S / Owner action (queued).
34. **/data/docker + gcs-staging reclaim** — Medium / S / Owner call (queued).
35. **google-sync + paperless runbook wording** — Low / S / Documentation (queued).
36. **AGENTS.md harden{} caps note** — Low / S / Documentation (roadmap).
37. **PSI-aware battery fast-path** — Medium / M / Quality (roadmap).
38. **Per-provisioner result summary** — Medium / S / Quality (roadmap).
39. **service-health-check storm tolerance** — Medium / M / Bug (queued).
40. **Heartbeat file for long foreign sessions** — Medium / S / Quality (roadmap).
41. **startLimitBurst provisioner note** — Low / S / Quality (roadmap).
42. **nvme by-id re-resolve discipline** — Low / S / Quality (queued).
43. **jq-in-direnv recurrence check** — Low / S / Documentation (roadmap).
44. **eval-cache SQLite busy watch** — Low / S / Watch (roadmap).
45. **Audible: cover/PDF dedupe decision** (same as 13, kept separate if owner wants both formats kept) — Low / M / Cleanup (roadmap).

*(deliberately NOT harvested: 1-3 harvested below as the audible-ctl row + playback-hygiene row; 5-7 owner questions in §g; the queued backbone already has rows.)*

## g) Questions I can NOT figure out yourself

1. **Did you hear the book while it played?** I verified mpv's IPC state, not the audio path — if it was silent, there's an output-device issue to chase; if you heard it, we're done verifying.
2. **Did you stop it, or did it die?** You had the kill one-liner in chat — if you stopped it, that explains the death; if not, I need to relaunch WITH logs to catch whatever killed it.
3. **What playback surface do you actually want long-term?** Raw mpv + a control script (what exists now), or a proper audiobook server (Audiobookshelf-style: phone apps, per-book positions, sync across devices) for the 65-book library? That decides whether `audible-ctl` is the end state or a stopgap.
