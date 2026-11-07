# Freeze #51 triage — emergency-mode teardown by automount activation conflict; OWNER power cut (first non-WDT reset of the retained series)

**Session:** 2026-11-07 01:07–01:2x CET, dispatched by the owner's "Why did we crash but not really? All SSH connects got broken, monitor black for 5+ minutes until I hard crashed it." Read-only forensics; journal pulls cached under `~/.cache/incident-20261107/` (prevtail/preverr/window-tail). Boot 0 live conditions throughout: chronic recovery re-storm (io PSI some avg10 28–34, load 30–39, 2 IO-PAUSE trips + 6 DEEP-THROTTLE ENTERs by minute 11 — freeze-#52 watch). Sibling sessions landed two 01-15 reports mid-investigation (quick-wins batch); no harvest overlap with this report's rows.

## a) The answer

**The box did not crash.** A deploy activation at 00:53:22 failed one automount unit, `local-fs.target` cascaded to **emergency mode**, and systemd's emergency teardown stopped `sshd` (00:53:22 — every `sshd-session` SIGTERMed in the same second, the owner's "all SSH broke"; never restarted, so new connections were refused too), forgejo (00:53:23, `:3000` refused to the last line), `display-manager` (00:53:24) and the whole user session (00:54:52–57; niri page-flip `Permission denied` storm → SIGTERM = the black monitor). The kernel, journald and a handful of daemons stayed alive the entire time — forgejo-runner logged every 2 s right up to the final journal line 01:06:21. The WDT never fired (nothing kernel-level was wedged). After ~11 minutes of headless-but-alive emergency mode the owner power-button-held the box: boot 0's kernel log reads `Previous system reset reason [0x00200800]: ACPI power state transition occurred` — the owner's cut, not the watchdog.

Timeline (all lines quoted from boot `6d2a69e4` journal / deploy logs):

| Time | Event |
| --- | --- |
| Nov 5 22:14 | commit `99af6e0d4` "Move Go build caches to Samsung hot tier (disko + automount + env)" lands |
| Nov 6 ~12:04 | First activation of the automount config (the storm-slow ~1 h switch behind gen-984; profile set 13:04:48). `home-lars-.cache-go\x2dmod.mount` fails status 32 (EBUSY-class) on EVERY trigger → automount **start-limit-hit 12:10:41**; go tooling rides `/tmp/bc-fallback` all day (direnv guard catch working as designed) |
| Nov 6 22:48 → Nov 7 00:40 | 8 deploy attempts: 1 float-register build failure + **6 pressure-gate exit-12 refusals** (23:25/23:40/23:55/00:10/00:25/00:40) |
| 00:43:13 | Deploy re-fired **FORCED**: `DEPLOY_FORCE_PRESSURE=1` at io PSI some avg10 60.42 % / disk 101.1 % (sdb 101.1, sda 100.1) — below the ≥80 extreme band, so tier-2 legally cleared; top-stalled cgroup at gate entry: a ghostty terminal scope (sudo journal puts the deploy in a local session in this repo; same-terminal identity unproven) |
| 00:51:05 | Activation begins (`systemd Reloading…`) |
| 00:52:19 | DEEP THROTTLE re-ENTER (k10temp 96 °C) |
| **00:53:22** | stc reconciliation starts the start-limit-dead automount → `home-lars-.cache-go\x2dmod.automount: Path /home/lars/.cache/go-mod is already a mount point, refusing start.` → `Failed to set up automount` → **`Dependency failed for Local File Systems` → `local-fs.target: Job … failed with result 'dependency'` → `Triggering OnFailure=`** → sshd stopped (all sessions same second), 00:53:23 forgejo SIGTERM |
| 00:53:24 | `display-manager.service` Deactivated |
| 00:54:52–57 | Session teardown: niri page-flip EACCES storm → SIGTERM; dms, user@1000, logind, dbus-broker all stop; `Started Emergency Shell` / `Reached target Emergency Mode` (emergency.service then fails to find `plymouth` — cosmetic) |
| 00:55–01:06 | **11 min alive in emergency mode**: kernel + journald healthy (forgejo-runner 2 s cadence), every user surface dead |
| 01:06:21 | Owner power-button hold → journal ends mid-forgejo-runner-error; boot 0 starts 01:06:40 (19 s gap) |

**Pressure was NOT the kill mechanism.** The automount conflict is config-shape, not load: an unforced, PSI-clean deploy would have hit the same refusal. The `=1` force chose the moment (and rode a 457-ENTER thermal/storm background — census: 384 trips #7437→#7820, ~20.1/h, 0 OOM), but the gates working perfectly would only have delayed this death.

## b) State after (boot 0, verified live)

- Both automounts set up CLEAN at boot (01:06:45; go-mod properly under autofs from 01:07:04; `findmnt` shows both as `systemd-1 autofs` + Samsung btrfs subvols beneath).
- **Anchor INTACT**: `readlink /nix/var/nix/profiles/system` → system-984-link → `hwjmwvin…` == `/run/current-system`. The 00:43 build never reached profile-set (its activation hung), so **the evening tree (22:15→00:15 sessions' changes) is still PENDING deploy** — the standing "re-run the pending deploy when io PSI < 20" row carries it; expect a refusal until the storm drains.
- Storm: chronic recovery re-storm (numbers above); freeze-#52 watch stands.
- Evidence pulled BEFORE any vacuum work (7.8G/8G, 0.2G headroom): `docs/status/tasks/2026-11-07_00-29_boot-6d2a69e4-evidence-pull.md` (rc=0).

## c) Verified vs NOT verified

**VERIFIED here:** reset reason (boot 0 kernel log, ACPI not WDT); the full 00:53:22 failure chain (journal lines quoted verbatim above); sshd stop + zero restart after 00:53:22 (window grep); emergency-mode entry + session teardown lines; deploy log sequence incl. the `=1` line and gate readings (8 logs read from `/var/log/systemnix-deploys/`); census via `scripts/crash-triage.sh --boots 4`; anchor + automount health via `findmnt`/`readlink`; commit lineage via `git show 99af6e0d4`.

**NOT verified here:** (1) the exact **non-unit holder** of `/home/lars/.cache/go-mod` in boot -1 — no systemd unit line ever mounts it, and the dead boot's mount table is unrecoverable post-reset; the status-32-forever + "already a mount point" pair proves SOME mount held it from before 12:04:45; the VM-repro row (§e.3) owns identifying the class. (2) Whether the sibling 01-15 tree edits touch the automount units for the next deploy (the pre-flight row §e.1 is the guard regardless). (3) The human/agent actor of the 00:43 force — sudo journal shows `lars`, PWD=this repo, top-stalled ghostty scope (a local desktop terminal); the owner can name it. (4) `nix flake check` not run (storm; CI owns the walk — no config changed by this session).

## d) Follow-ups

§e.1–§e.3 harvested at authoring time → `docs/todo/stability.md` rows + `TODO_LIST.md` queue one-liners. Deliberately NOT harvested: the missing-`plymouth`-for-emergency.service cosmetic (folded into §e.3's blast-radius scope); the "5+ min" vs 11-min black-screen perception gap (no action — the journal bounds it 00:55→01:06).
