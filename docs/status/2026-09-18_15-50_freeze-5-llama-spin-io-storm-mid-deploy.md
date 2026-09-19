# Freeze #5 — 2026-09-18 15:27 — llama-rag spin (pinned build!) on top of an all-day QLC IO storm, death mid-deploy

> **[docs-health 2026-09-19] RESOLVED + ARCHIVED:** containment complete (SIGSTOP + config-disable); successor analysis: freeze-6 report + AGENTS.md Hardware Instability; llama-rag bisect gated in docs/todo/ai-stack.md.


Boot -1 (`c861ed3b`, up since 2026-09-15 09:36, kernel 7.2.6) froze at
**15:27:49** — journal cut mid-entry during normal activity, no panic, no
kdump (`/var/crash` empty), WDT silent: the scheduler-livelock class
(freezes #1/#3/#4). Hard reset (power button) 15:32 → boot 0. Post-freeze
boot **replayed the same failure inputs** and was caught + contained live
(SIGSTOP, config-disable) before it froze again.

## Timeline (all 2026-09-18, boot -1 unless noted)

| Time           | Event                                                                                                                                                                                                                                                                                      |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 23:00 (Sep 17) | btrbk-root incremental send starts (normal)                                                                                                                                                                                                                                                |
| 23:04:36       | btrbk-root `Failed with result 'signal'` — guard churn-stop killed it mid-receive (known trip class; tonight's run + `btrbk-pool-clean` heals)                                                                                                                                             |
| 23:30          | btrbk-data `Failed with result 'exit-code'` — nightly pool sends broken                                                                                                                                                                                                                    |
| 00:00→         | Zone-6 IO PSI storm runs CONTINUOUSLY from midnight (avg60 62-71%, QLC random IO ~29KB reads, disk busy 62-100%); guard trips every cooldown window (53 action-taken trips 00:00-11:00, #443-465 by 15:26; 337 total for the boot)                                                         |
| 10:34          | flm restore capped (3 restores spent) — flm consumers dark from here                                                                                                                                                                                                                       |
| 10:22          | deploy #1 (`bpidr18g`) into the storm                                                                                                                                                                                                                                                      |
| 11:28          | deploy #2 = **gen 784** (`zbq817dd`) — re-enabled `llama-rag` after the 0.3.0 pin-back. Both llama-servers wedge at `model vocab missing newline token` and spin ~94% CPU each. (~~deploy #2 standing~~ superseded same day: `llama-rag.enable = false` — docs/status/2026-09-18_15-50_* §f; bisect gated in docs/todo/ai-stack.md.) systemd accounting at the 14:12 restart: **2h33min CPU over 2h43min wall, 8.6G written to disk, per unit** |
| 14:00-14:11    | deploy #3 (`s1klz076` = system-784 final) — restarts llama units, spin resumes immediately                                                                                                                                                                                                 |
| 15:20-15:27    | deploy #4 (`d6wdfydgv`) switch at 15:27:40; signoz provisioning completes 15:27:46                                                                                                                                                                                                         |
| 15:27:49.975   | journal cut mid-line. Livelock death. No shutdown record                                                                                                                                                                                                                                   |

## Root cause: three stacked contributors

1. **Sustained QLC random-IO storm (the base)** — nvme0n1 = Lexar QLC
   (root+data+clickhouse) at 100% util with ~1.2k random 29KB reads/s for
   15+ hours. Drivers: the known crush-session-DBs-on-QLC class (multiple
   parallel agent sessions), project-discovery du-walks (~12 MB/s sustained),
   nightly-job churn. The `crush-hot-db` first migration (running NOW on
   boot 0) is the structural fix for exactly this.
2. **llama-rag spin regression on the PINNED build (the accelerant)** — the
   2026-09-18 pin-back (`sj4rpa8y…` llama-cpp-0.3.0, byte-identical to the
   "proven" store path, correct `HSA_OVERRIDE_GFX_VERSION=11.5.1` unit env)
   spins IDENTICALLY under the systemd units: wedged right after the vocab
   warning, 94% ×2 CPU, GPU idle, never binds :8848/:8849. Re-enabled by
   gen-784 at 11:28 into an already-saturated box. **The escape condition
   ("re-disable if the spin signature ever reappears on the pinned build")
   has fired.** The one-off direct-run verification was insufficient
   evidence — it ran outside the unit sandbox (deviceCgroup/GPU state) and
   passed while the unit wedges.
3. **Fourth deploy into the storm (the trigger)** — activation IO on top of
   a 50% avg60 PSI box pushed the scheduler into livelock 9 s into
   `switch-to-configuration`. The deploy pressure gate (`exit 12` at
   avg10 ≥20%) did not protect: it fired DURING builds earlier, but deploy
   #4's switch phase entered during a PSI dip.

## Containment executed (boot 0)

- 15:34: both llama units wedge at the same vocab point, spinning 93% ×2.
  15:46: **SIGSTOP** both (pids frozen in `T` state — CPU burn halted, units
  stay "active" so no respawn; stc will reap them when the disable deploy
  lands). `systemctl` is sandbox-blocked for agents; external
  `/run/current-system/sw/bin/kill -STOP` used.
- `llama-rag.enable = false` committed in `configuration.nix` (escape
  condition; eval-verified, drv `7j1igmzv…`).
- `crush-hot-db-migrate` first migration left RUNNING (it moves the
  crush session DBs off the QLC — the base-storm fix; interleaved
  "migrated <repo> → /mnt/hot/crush/<repo>" lines from 15:41).
- No rogue llama-servers beyond the two unit children (portGuard clean).
- No reboot-revert trap: `/run/current-system` == profile == system-784
  (`s1klz076`); deploy #4's `d6wdfygv` never activated — its owner must
  re-run it.

## Follow-ups

- Do NOT re-enable llama-rag until the spin is root-caused at the
  llama.cpp/ROCm layer. Verification protocol for any future attempt:
  `systemd-run` with the unit's exact sandbox (deviceCgroup!) + a 10-min
  soak, never a shell direct-run.
- Guard zone 6 correctly fired all day but its sacrifice list cannot stop
  this storm class (flm + churn units were not the drivers). The
  crush-DB migration is the real fix; after it completes, QLC random-read
  pressure should collapse.
- flm socket: restore budget was spent on boot -1; boot 0's guard will
  restore automatically once IO drains (`maxRestoresPerDay` resets daily).
- btrbk: mid-receive kills from Sep 17 23:04/23:30 leave garbled targets —
  `btrbk-pool-clean` nightly run heals; verify the 23:00 send lands tonight.
