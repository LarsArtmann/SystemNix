# Band-80 takeover: deploy-waiter re-arm, gen-1008 live battery, immich caps fix

**Session:** 2026-11-14 ~18:33 → ongoing (continuation of the 14-03 shadow-split / 16-55 band-80 arcs; owner directive: execute the queued next steps). **State at authoring (21:15):** storm waves continue (session-26 linker battery, 90-96 linkers per wave since 15:46), gen-1008 live and anchored, deploy waiter re-armed through 02:00 carrying the immich fix, btrbk catch-up fully automatic.

## a) Executed this session

1. **Takeover of the dead deploy waiter** (the 18-30 crash-loop report's takeover branch): confirmed the old waiter died at its 18:23 horizon without firing, no other deploy process existed, then re-armed as `~/.cache/band-waiter3.sh` logging to `~/.cache/band-deploy3.log` — conditions: io avg10<20 ∧ mem avg10<20 ∧ zero `MEMORY EMERGENCY action taken` in 60 min (deploy.sh's exact trip predicate) ×2 consecutive 60s samples, eval-relevant-path quiescence (>5 min), no deploy in flight (bracket-escaped pgrep pattern — an inline pattern would self-match), then green-eval probe, then `nix run .#deploy`; exit 12/13 re-arms, horizon extended 22:45→02:00 when the battery proved wavelike. It correctly held through every wave and through the parallel deploy (nh=YES).
2. **cvagent P0 row 15:41 misread corrected** (a595d0304): journal-verified the unit was cleanly stopped in the 15:39:43 shutdown cascade and Started 15:41:54 on recovery boot b8f909cd — boot re-arm, not an exit-2 crash restart.
3. **AGENTS.md reboot-signature checklist landed** (24d40aa25): PSI total-counter reset + suddenly-low PIDs + load discontinuity → `journalctl --list-boots | tail -2` FIRST — the freeze-#54 missed-~70-min lesson, placed next to the boot-evidence rules.
4. **projects-subvol runbook Phase F synced** (rode daemon commit 827704547): burn-in-satisfied status, storm-refusal history, band-80 directive, remaining sequence (quiet-window green run → owner shadow-cleanup); services.md row ticked.
5. **Monitored the parallel session's forced deploy through activation**: DEPLOY_FORCE_PRESSURE=2 at 19:03 (refused-path print but =2 set) and 19:39 (io PSI 54.24 / disk 101) — the twice-fatal class; it survived a 75-min activation (post-crash-calm-gate waited, 65-min timeout bound) and **anchored gen-1008** (~21:05). current-system == system-1008-link == 16nq29bk. The switch carried band-80, the crash-loop fix wave, the forgejo cache-repair decoupling, and the pin-doctrine floats.
6. **Live battery verdicts** (gen-1008): audiblesync PASS (Result success — env-quoting works); monitor365 PASS (zero new core.dmesg.966 post-deploy, last 15:43); immich FAIL root-caused (below); bank-sync NOT serving (below); llama-chat dormant N/A; activation-time failed units (service-health-check, system-health-metrics, tq-agent-pool, post-crash-calm-gate) all self-healed to inactive/success via the reset-retry phase.
7. **immich converger root-caused + fixed in tree** (d8b7b4baa): past the StateDirectory 226 leg, the unit died `runuser: cannot set groups: Operation not permitted` — `harden`'s empty `CapabilityBoundingSet` (rendered unit confirmed `CapabilityBoundingSet=` bare) leaves runuser no caps; fix = `CapabilityBoundingSet = "CAP_SETUID CAP_SETGID"` at the harden call site (the helper's designed parameter — no mkForce needed). Full `nix flake check` green in the commit hook. **Rides the next deploy.**
8. **bank-sync live verdict**: at 8e170d05 (pin-doctrine float) the daemon logs its 2 boot lines then never opens a port; the 90s readiness gate times out and the unit restart-loops (15+ by 21:05). The pin-doctrine CHANGELOG claims "boots and serves" — verified outside the storm; under io PSI ~98 the journal-preflight startup read plausibly exceeds the gate. Quiet-window start disambiguates storm-slowness vs regression (if calm start still hangs: bank-sync repo — listen-before-preflight or a storm-budget gate). Recorded in both battery rows; NOT deep-dived this session (foreign repo domain).
9. **Close-outs** (530d09ca1): stability.md watch row + storage.md precondition carry the LIVE-at-gen-1008 state; crash-wave rows (services.md + TODO_LIST) carry the battery verdicts and stay open for the immich deploy + bank-sync verdict; CHANGELOG entry added.

## b) Armed automation at handoff

- **Deploy waiter** (band-deploy3.log): fires the next deploy (carries d8b7b4baa + any later tree state) at the first genuine calm; horizon 02:00.
- **btrbk-projects catch-up**: band-80 admission LIVE (wrapper `cy2kd8f4…` passes `--psi-max 80`; guard binary carries btrbk-projects in ioChurn+backup lists — both probed on the live system). Paths: 23:10 timer (fires when io<80 ∧ trip-free), starvation slot (avg60<50 after 6h starvation), manual start. Metric baseline: `projects_subvol_backup_fresh 0`, last_age ~589731s (Nov 7).

## c) Owner-gated items (unchanged)

Session-26 SSH battery (untouchable, still running); cvagent stays stopped (P0 fix session owed); shadow-cleanup stays owner-run after the first green receive.

## d) Self-review

1. I typed `rg -rn` AGAIN this session (4th personal strike class) — the host hook blocked it with the explanation; the handoff had warned three times. The hook is the only reason the displayed output wasn't mangled.
2. First waiter launch forgot the log-file redirect (stdout-only) — the cross-session coordination surface was missing until I noticed via the missing file and relaunched. The old waiter's file was the coordination contract; I nearly broke it.
3. The waiter's `pgrep -c ld.mold || echo 0` double-prints "0" (count prints 0 AND rc=1 triggers echo) — cosmetic, left as-is in a running job.
4. A daemon race swept my runbook-sync commit into heuristic 827704547 together with a parallel session's flake trio — I did NOT amend (foreign in-flight work absorbs under a misleading message); the heuristic label is the honest one.
5. The bank-sync CHANGELOG contradiction ("boots and serves" vs never-listens live) was recorded rather than resolved — the disambiguating experiment (quiet-window start) was not available this session and deep-diving a foreign repo mid-storm was out of scope.

## e) Sources

journalctl (cvagent, bank-sync, immich-api-key-provision, post-crash-calm-gate, memory-emergency-guard), /var/log/systemnix-deploys/2026-11-14_19-39-13.log, live unit files + busctl, waiter log ~/.cache/band-deploy3.log, battery checklist ~/.cache/post-deploy-battery.md.

## f) Follow-ups (self-harvested)

1. immich fix deploy + converger verify — covered by the updated [blocked:deploy] rows (both surfaces); the armed waiter carries it automatically.
2. bank-sync quiet-window verdict — same rows.
3. First green btrbk-projects receive + `projects_subvol_backup_fresh 1` — covered by the stability.md watch row UPDATE.
4. 80-band send storm-feeding observation — same watch row.
5. Stale PSI sampler (`~/.cache/systemnix-deploygate.log`, the 18-30 session's job 06E) — NOT harvestable as a row: unidentifiable via pgrep/fd (open-per-write loop), harmless (one PSI read/min), and likely dies with its owning session. Deliberately not harvested beyond this note.

**EXECUTING (crush continuation session, 2026-11-14 21:20 CET, HEAD 530d09ca1):** report authored mid-watch; deploy waiter + catch-up paths armed per §b; outcome appended below if tonight's window opens.

## Outcome appendix (23:50, session watch ended — automation continues)

1. **gen-1009 landed** (second parallel forced deploy, 22:12 at io PSI 65 / disk 101, survived; anchored ~23:20): carried d8b7b4baa — the immich caps fix advanced the converger one full leg (pam session now OPENS as postgres) but died the next: `pam_limits` raising RLIMIT_MEMLOCK requires CAP_SYS_RESOURCE. **Leg 2 fixed in tree (8e3b24a84, flake check green)** — rides the next deploy; the armed waiter carries it. Two-leg pattern recorded in the battery rows.
2. **23:10 btrbk-projects timer: REFUSED — on the guard-trip window, not the band.** Zone-6 IO-PAUSE trips (#10153-#10155, storm tail: io avg60 67%+, disk 100%, nothing pausable) put the fire inside the 60-min trip window; the PSI leg PASSED (io ~70 < 80) — **first live proof the band-80 directive admits exactly what the owner asked for**. Green receive still owed; automatic paths own it (next 23:10, starvation slot at avg60<50, or a manual start once trip-free ≥60 min ∧ io<80).
3. **Storm re-waved through the evening** (96/90/93-linker waves at 19:43/21:08/23:37, sdc=/mnt/rust-cache at 101% util — the owner's ghostty-scope Rust battery; gaps dipped io to 28-70 but never under 20). The waiter (band-deploy3, horizon 02:00) held correctly through all of it and through both foreign deploys (nh=YES single-deploy invariant).
4. **Session ends its active watch here**: everything actionable is done or armed — waiter (deploy cargo: 8e3b24a84), catch-up paths, battery rows honest, bank-sync verdict pending storm drain. If the waiter fires before 02:00 it deploys autonomously; its log is the trail. Next session picks up: immich converger verify post-deploy, bank-sync quiet-window verdict, first green receive + `projects_subvol_backup_fresh 1`.
