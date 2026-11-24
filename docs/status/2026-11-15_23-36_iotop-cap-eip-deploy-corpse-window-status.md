# Status: iotop `cap_net_admin+eip` — deployed through 9 gate/flock refusals; corpse-window remediation; self-review

**Session scope:** one user ask — _"Make sure the startup iotop gets its cap_netadmin+eip capabilities!"_ — executed end-to-end on evo-x2 (config → eval → deploy → live caps → process-cap proof), plus the deploy-blocking incident it uncovered (a GC-deleted-binary monitor corpse window) and its remediation. Work window ≈16:50–19:11; live re-probe for this report at 23:36.

**VERIFIED (command → artifact):**

- Config renders: `nix eval --json .#nixosConfigurations.evo-x2.config.security.wrappers.iotop-c` → `{"capabilities":"cap_net_admin+eip", …,"permissions":"u+rx,g+x,o+x"}` (~/.cache/iotop-cap/eval.json)
- Deploy landed: `/var/log/systemnix-deploys/2026-11-15_18-02-18.log` → `deploy exited code=0 … after 4132s`; pre-deploy battery **143 passed, 0 failed**; post-deploy smoke **170 PASS / 5 FAIL (all match the pre-existing smoke-fail baseline — advisory) / 16 WARN / 2 STORM-SUSPECT**
- Anchor: `readlink /run/current-system` == newest `system-1015-link` (2026-10-14 discipline; re-verified still true at 23:36)
- Live caps: `getcap /run/wrappers/bin/iotop-c` → `cap_setpcap,cap_net_admin=eip` (18:03 wrapper render; still `eip` at 23:36)
- Functional: `/run/wrappers/bin/iotop-c -b -n 1` prints real taskstats output (no `Netlink error`)
- Process-level: python `subprocess.Popen` of the wrapper → `/proc/<pid>/status` → `net_admin` in **CapInh 0x1100 / CapPrm 0x1000 / CapEff 0x1000** (bit 12 = net_admin)
- Gate forensics: 5 refusal logs read (`2026-11-15_16-59-02`, watcher log, `17-45-04` foreign, my two patient-loop fires); pidstat + per-device io_ticks + per-scope io.pressure crosschecks at 5 moments

**NOT VERIFIED (and why):**

- The **2 STORM-SUSPECT** smoke checks — downgraded because io PSI avg60 was 48.5% at smoke time; the box never went calm before session end (PSI still ~30% at 23:36). Queued for a calm-window re-run (harvested, §f.1).
- The **5 baseline FAILs** — matched the pre-existing smoke-fail baseline; not triaged beyond baseline-match (out of scope).
- **Which 2 checks were STORM-SUSPECT** — seen only in the summary counter; not itemized into the report. Gap.
- **Root cause of the failed units** (btrbk-root, buildcache-gc, forgejo-github-sync, service-health-check) — observed + queued, not diagnosed (§f.2).
- **nvtop window liveness** and **niri session.json restore-form audit** — the corpse recurrence vector; queued, not run (§f.3).
- The **functional delta of `+eip` vs `+ep`** — measured as NONE at process level (ambient mechanism; both yield net_admin in Inh/Prm/Eff; the 17:20 pre-change live process already showed Inh=0x1100). The change is canonical-form parity, not behavior.
- **Actor of the 17:45 foreign deploy** — a parallel crush session (parent pid evidence only); no fish/DB attribution done.
- **nh os switch "exit code 4" tolerated as deploy code=0** — observed in the log tail, semantics not investigated (failed-units-during-activation class; deploy.sh exit-code contract lives in docs/agents/systemd.md, unread this session).

---

## Session timeline (all times 2026-11-15)

| Time        | Event                                                                                                                                                                                                                                                                                                                |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ~16:5x      | Read config (security-hardening.nix wrapper `+ep`, niri autostart `iotop-c -aoP`), read nixpkgs wrapper builder (ambient-raise C wrapper, `cap_setpcap` plumbing), live probe: wrapper live with `=ep`, running iotop-c healthy                                                                                      |
| ~16:5x      | Edited `+ep`→`+eip` (security-hardening.nix:38) + doc sync (docs/agents/desktop.md:92); scoped `nix fmt` clean; eval render verified                                                                                                                                                                                 |
| 16:59       | Deploy attempt 1 → **rc=12**, entry gate: REAL storm (PSI 38%, nvme1n1 95.7%) — driver: `crm-server` reading **186 MB/s** (pidstat)                                                                                                                                                                                  |
| 17:00–17:18 | Armed `deploy-when-quiescent.sh --fire`; watched it wait out a parallel session's `flake.lock` float + `base.nix` edit (daemon-swept by 17:14), 4 stable polls, green-eval, fired 17:18 → **rc=12 in 4s** — storm still live                                                                                         |
| 17:20       | Corpse kill #1: iotop-c pid 3575792 — **exe readlink EMPTY = GC-DELETED store binary**, 100%-stalled scope member; functional probe passes post-change config absence (wrapper not yet redeployed — this was the OLD +ep wrapper, still working)                                                                     |
| 17:21–17:45 | Patient PSI loop (avg10<20 ×2): fired 17:45 → **rc=13** — flock held by a FOREIGN deploy (started same second)                                                                                                                                                                                                       |
| 17:45–17:56 | Foreign deploy (parallel session): passed entry gate, ran the full battery (143/0), died **rc=12 after 714s** at the post-battery pressure gate (REAL burst, nvme1n1 78.3%) — still naming the corpse scope `ghostty-3575046` at 100%                                                                                |
| 17:57       | Corpse kill #2: the ghostty window 3575046 + its stuck `sh` (3575714) — both dead, scope gone; user-scope stalls cleared. NOTE: the title=iotop window (3574895) had already closed itself when its corpse child died in kill #1                                                                                     |
| 18:00       | Patient loop fires again → **rc=12** — NEW scope named: `ghostty-3574898` (the LIVE btop monitor) at 61–73%                                                                                                                                                                                                          |
| 18:01       | Phantom verification: ALL devices ≤4.9% busy, one transient D-state `go` (CV session build), btop running a VALID store binary (not a corpse) → matches the 2026-11-08 owner-endorsed precedent exactly                                                                                                              |
| 18:02       | **`DEPLOY_FORCE_PRESSURE=1` → rc=0, gen-1015** (4132s; smoke 170/5-baseline/2-STORM-SUSPECT); wrapper re-rendered at 18:03 with `=eip`                                                                                                                                                                               |
| 18:19–18:33 | The parallel session bounced **4× rc=13** off my deploy's flock — sequencing held, zero tree interference                                                                                                                                                                                                            |
| 19:1x       | Full verification battery: anchor OK, getcap eip, functional probe, process-cap proof (python Popen after two shell-probe failures), failed-units scan (3 then)                                                                                                                                                      |
| 23:36       | Re-probe for this report: gen-1015 still current, caps still eip; failed-unit set EVOLVED (inboxclean-sync recovered; **btrbk-root failed in the 23:00 window**, service-health-check new); PSI ~30%; `flake.lock` dirty again (parallel float); **a parallel deploy is IN FLIGHT** (23:34:27 log, no exit line yet) |

**Deploy-attempt ledger for the saga: 9 attempts / 1 wave landed.** Mine: rc=12, rc=12, rc=13, rc=12, rc=0. Foreign: rc=12 (714s), rc=13 ×4. (Plus the owner-side 15:34 deploy that landed gen-1014 cleanly at 16:50, pre-saga.)

---

## a) FULLY DONE

1. **The ask itself.** `security.wrappers.iotop-c` capability form `cap_net_admin+ep` → `cap_net_admin+eip` (modules/nixos/services/security-hardening.nix:38). Eval-rendered (`cap_net_admin+eip` in the wrapper attrset), deployed (gen-1015), live (`getcap` → `cap_setpcap,cap_net_admin=eip`), functional (taskstats read works), process-proven (net_admin in Inh+Prm+Eff of a freshly spawned iotop-c).
2. **Mechanism understanding before touching**: nixpkgs `wrapper.c` raises file caps into the AMBIENT set pre-exec (`cap_setpcap` is the enabler, deliberately not propagated); `cap_from_text` accepts `+eip`; the wrapper's own inheritable-widening covers the `i` path — the change is safe and canonical (NixOS-wiki form).
3. **Doc sync**: docs/agents/desktop.md:92 updated to `+eip` (+ canonicalization + incident note), monitoring.md phantom row gained the 2026-15 corpse datapoint, shell-devtools.md gained the o+x-exec quirk bullet — all at discovery time.
4. **Corpse remediation**: the session-restored iotop-c executing a GC-DELETED store binary (100% stalled io_uring CQ-waiter scope, the single biggest deploy-gate blocker across 5 refusals) killed by explicit PID after full-cmdline + exe-deleted confirmation; its dead ghostty/sh chain (3575046/3575714) followed. Per the gate's own printed remediation ("close/kill idle terminal sessions (ghostty) before forcing").
5. **Phantom verification before forcing**: devices ≤4.9% idle, D-state census (1 transient `go`), crosscheck verdict — DEPLOY_FORCE_PRESSURE applied strictly per the 2026-11-08 owner precedent, not as a first resort (it was the 5th attempt and the 3rd after the storm changed class from REAL (crm-server 186 MB/s) to phantom).
6. **Concurrent-session discipline**: 4 foreign rc=13 bounces absorbed without re-fire; tree quiescence + daemon-commit sequencing verified via the watcher's own gates before firing; content-pins (`git rev-parse` + status) before every edit phase.
7. **Formatter/eval hygiene**: scoped `nix fmt` (0 changed = canonical), heavy eval captured once to ~/.cache per the capture-once rule, PSI parses validated against known values (head -1 sanity) per the 2026-11-15 pressure-parsing trap.

## b) PARTIALLY DONE

1. **Post-deploy validation**: 170 PASS but 2 checks sat in STORM-SUSPECT (unverified — box never calm) and the 5 FAILs were accepted via baseline-match only. The smoke's full value is unrealized until a calm re-run (queued §f.1).
2. **The user-visible outcome**: the iotop autostart window is currently CLOSED (collateral of corpse kill #1 — see §d.1); the +eip wrapper will serve it only at the next niri start/login. The user has not yet SEEN the fixed monitor running.
3. **Failed-unit convergence**: inboxclean-sync self-recovered, but the set evolved (btrbk-root @23:00, service-health-check) and nothing was root-caused (queued §f.2). btrbk failing in its snapshot window is the most notable of these.
4. **§f harvest**: 4 direct follow-ups queued (queue + domain libs, mirrors verified); the remaining §f rows are deliberately NOT harvested (brainstorm/ROADMAP fuel — recorded in the ledger below).
5. **The `+eip` intent**: deployed as asked and canonical; whether a deeper inheritance scenario was intended is an open question (§g.3).

## c) NOT STARTED (noticed, deliberately not started this session)

1. Root-cause of any of the 4 current failed units (incl. btrbk-root's 23:00 failure).
2. niri session.json restore-form audit (store-path corpse recurrence vector) + nvtop window liveness.
3. Monitor-terminals-as-systemd-user-services architecture (would eliminate the corpse class AND give a clean kill/restart surface).
4. Deploy-gate monitor-scope auto-classification via io-psi-crosscheck.sh verdict mode (owner-gated, monitoring.md row).
5. Actor attribution of the 17:45 foreign deploy (/proc/fish_history/DB forensics — not needed for the task, skipped).
6. CHANGELOG entry for the wrapper change (SystemNix has a CHANGELOG; commit messages + status reports carry this class of change per convention — judgment call, nothing written).
7. Re-run of the 2 STORM-SUSPECT checks (queued, not run).
8. Upstream investigation of wrapper.c's own TODO (setpcap-propagation semantics) — verify-before-filing territory, untouched.
9. Repo-wide capability-wrapper audit (are other wrappers on non-canonical flag forms?) — grepped nothing beyond iotop-c.

## d) TOTALLY FUCKED UP

**Final system state: nothing.** Deploy green, caps live, docs synced, no reverts. The fuckups are process-level, listed honestly:

1. **Closed the user's live monitor window without a pre-kill parent check.** Kill #1 (corpse iotop-c 3575792) turned out — from PPid, read AFTER the kill — to be the child of the CURRENT `--title=iotop` ghostty (3574895), which then closed itself (ghostty `-e cmd` exits with its child). I had even seen the OTHER ghostty's `; exec fish` fallback and assumed a similar soft-landing; the actual parent had none. The corpse was displaying a deleted binary (frozen garbage), so the window had zero value — but the user lost a dashboard pane mid-session without warning. Pre-kill PPid/parent-fate check was one command away.
2. **Re-hit a documented trap three times because the routing table was skipped.** docs/agents/shell-devtools.md has documented the `$!`-expands-to-garbage quirk since 2026-10-03 ("Agent-sandbox shell quirks"). The AGENTS knowledge-routing table says read the domain doc BEFORE domain work; I read desktop.md and never shell-devtools.md, then burned three probe attempts ($! → "g1", pgrep-after-spawn race ×2) rediscovering it before switching to python Popen. The file even had a bullet pointing at pgrep-instead-of-$!.
3. **Shipped a mislabeled intermediate probe output**: the first device-util check printed raw io_ticks twice under the label `util_ticks_delta=0` (no delta computed — process-substitution re-read). Caught it by cross-reading the two raw values (560ms apart ≈ 43% busy), recomputed correctly on the next probe. It never entered a conclusion, but misleading labeled output is how mangled-readings incidents start (the 2026-10-23 `rg -r` and 2026-10-26 awk-offset classes).
4. **Orchestration latency: 9 deploy attempts / ~2.5h for a one-flag change** (mine + the foreign session's). Two of my four pre-success attempts were predictable refusals at fire time (17:18 watcher into a visibly-live storm; 18:00 loop into the btop scope the gate had just named). The gates did their job; the sequencing could have collapsed two cycles.
5. **Near-miss — the corpse almost got innocent-by-association treatment**: the first gate refusal (16:59) showed the REAL-storm branch (crm-server 186 MB/s, disk 95.7%) and the top stalled scope was the corpse window. Killing it THEN (under a real storm) and forcing would have violated the freeze doctrine. The wait-vs-force sequencing that eventually ran was correct; the margin was discipline, not design — the composite decision (whose IO is this? wait or force?) took 5 attempts to converge. A single upfront composite probe (PSI + device busy + top-readers + scope inventory + flock holder) would have produced the same verdict in one pass.

## e) WHAT WE SHOULD IMPROVE

1. **Upfront monitor-scope inventory when the task touches a monitor**: before ANY kill or deploy, one pass over `app.slice/*.scope` — members, cmdline, `readlink /proc/pid/exe` (empty = GC-deleted corpse), per-scope io.pressure. Would have: classified corpse vs live in one shot (3575792 corpse, 3575046 dead-chain, 3574898 live btop), prevented the surprise window closure, and pre-answered the gate's scope naming in every refusal.
2. **Routing-table discipline**: load `docs/agents/<domain>.md` BEFORE the first shell/process probe, not after the third failure. The file existed precisely for this.
3. **python Popen as the default spawn+inspect tool** in agent shells (owns the pid, no `$!`, no pgrep race, kernel exec bypasses the o+x open trap) — now documented in shell-devtools.md.
4. **Deploy decision composite**: one read that answers "wait / sequence / force" — PSI some avg10 + max-device-busy + top-3 readers (pidstat 2s) + stalled-scope inventory (exe-deleted flag) + flock-holder check + newest deploy-log tail. Every refusal today re-derived this piecemeal.
5. **Gate refusal output could carry the corpse flag**: the gate already names top stalled scopes; adding `exe=<deleted>` detection per member turns "close/kill idle terminal sessions (ghostty)" advice into an exact kill list.
6. **PPid-before-kill rule extension**: the pkill discipline says read the full cmdline; add "check the parent's fate too" (does the window exec a fallback shell or die?) before killing a monitor's child.
7. **STORM-SUSPECT should auto-queue its own re-run**: the smoke knows PSI was >20% at run time; emitting the re-run row (or appending to a standing queue file) would close the loop without a human noticing a counter in a summary.
8. **Parallel-session deploy etiquette worked but was silent**: the 4 rc=13 bounces had no notification channel; a one-line deploy-log/tq ping ("holder pid X since T, eta unknown") would let sequencers back off gracefully.

## f) 50 things to get done next

Tagged: **[Q]** = queued this session (harvested, queue+lib in sync) · **[R]** = ROADMAP fuel (deliberately NOT harvested — brainstorm, needs refinement before it becomes a task) · **[O]** = owner-gated · **[N]** = no-action note (verified fine / informational).

1. **[Q]** Re-run scripts/post-deploy-check.sh when io-PSI calm — clear the 2 STORM-SUSPECT downgrades (gen-1015 smoke).
2. **[Q]** Verify-or-reset the failed-unit set: btrbk-root (23:00 window), buildcache-gc, forgejo-github-sync, service-health-check.
3. **[Q]** Audit niri session.json + monitor-window command forms for GC-corpse-class store paths; confirm nvtop/btop exes live (recurrence prevention).
4. **[R]** Deploy gate refusal: add per-scope `exe=<deleted>` corpse flag to the stalled-scope listing.
5. **[R/O]** Wire io-psi-crosscheck.sh verdict mode into the entry gate as the phantom-branch classifier (the monitoring.md owner ruling).
6. **[O]** Monitor-terminal policy ruling (restart-when-wedged / gate-classify / force-per-deploy) — sharpened by today: the corpse half is mechanically dead; the live-dashboard half remains.
7. **[R]** Monitor terminals as systemd user services (Restart=on-failure, clean kill/restart surface, no session-restore corpse class) — the structural fix behind 6.
8. **[R]** post-deploy smoke: auto-queue STORM-SUSPECT re-runs instead of dangling counters.
9. **[R]** deploy-when-quiescent.sh: exclude the watcher's own pid from its DISARM-LIST (it listed itself today).
10. **[R]** deploy-when-quiescent.sh: opt-in `--wait-calm` PSI mode (script doctrine says don't duplicate deploy.sh gates — keep it explicit).
11. **[R]** Deploy contention telemetry: alert when >2 sessions hit rc=13 within an hour (today: 5 refusals, 2 sessions, 1 wave).
12. **[R]** pre-deploy battery: monitor-scope corpse-scan advisory leg (exe-deleted enumeration).
13. **[R]** system-health textfile: emit top-stalled-scope metrics (the gate computes them already; expose for SigNoz).
14. **[R]** Gatus: deploy-flock holder-age check (today's holder ran 69 min while 4 attempts bounced).
15. **[R]** Identify `gdd-20261113b` — unidentified long-lived writer (388–1533 KB/s) across every probe today.
16. **[O]** What launched crm-server's 186 MB/s read (16:47 restart per its OIDC log; batch? owner session?) — one sentence attributes the day's REAL storm.
17. **[R]** btop phantom-stall: research whether a taskstats-free mode exists; if not, an upstream issue is a candidate (verify-before-filing first).
18. **[R]** iotop-c 2026-10-12 OOM (331 MB RSS, oom_score_adj 100): if terminals become services (7), consider MemoryMax for monitor units.
19. **[R]** wrapper audit: grep all `security.wrappers.*.capabilities` forms; standardize on canonical flag forms with justification comments.
20. **[R]** Process-cap regression leg: assert every rendered wrapper's `getcap` matches its declared capabilities (VM-test or smoke leg).
21. **[R]** Upstream nixpkgs wrapper.c TODO (setpcap ambient-propagation semantics) — understand, maybe file (verify-before-filing gate).
22. **[R]** Why do wrapped processes carry setpcap in CapInh (bit 8, observed 0x1100)? Trace wrapper.c's inheritable-set construction — understanding only.
23. **[R]** iotop-c upstream: does a drop-privileges-after-netlink-setup mode exist? (privilege minimization for the single-user tradeoff noted in desktop.md).
24. **[N]** security-hardening.nix wrapper comment could name the flag choice + canonical source — 2-minute polish, fold into the next touch of the file.
25. **[R]** Pin/normalize ghostty autostart + session-restore commands to wrapper-safe forms (the FIX side of 3).
26. **[R]** Verify niri single_instance_apps dedup unaffected after today's window kills (session.json may hold stale entries).
27. **[R]** Monitor-window respawn helper (one command restoring the nvtop/btop/iotop trio with titles) — QoL after cleanup kills.
28. **[N]** user@1000.service aggregate io.pressure is distorted by monitor scopes (81–83% while devices idle) — noted wherever PSI is read; the fix is 13.
29. **[R]** Entry-gate REAL-storm branch samples a single 1s device window — nvme1n1 flapped 95.7% → 0ms within minutes today; consider a multi-window busy verdict to stop REAL/phantom flapping.
30. **[R]** Deploy-log: record battery duration vs PSI correlation (4132s under storm — which legs stretched? feeds gate tuning).
31. **[N]** nh os switch exit-4 ("failed units") tolerated as deploy code=0 — semantics live in docs/agents/systemd.md; worth a read + maybe a deploy-log annotation next time.
32. **[N]** accounts-daemon homed NameHasNoOwner noise on every activation — pre-existing, benign-looking, uninvestigated.
33. **[Q→covers]** nextd tick + bank-sync reconciliation failed during the 18:02 activation window — folded into 2 (verify refire).
34. **[R]** Chronic-PSI floor: the box sat at 27–50% avg10 from 16:59 to 23:36 — attribution belongs to the stability rows (crm batch? CV session? monitor phantoms?); today's evidence feeds the existing root-cause row.
35. **[N]** `flake.lock` dirty again at 23:36 (parallel float in flight) — the in-flight 23:34 deploy will carry or bounce it; sequencing doctrine applies, no action.
36. **[N]** The 23:34:27 parallel deploy was IN FLIGHT at report time — next session must re-check current-system generation before claiming gen-1015 currency.
37. **[R]** CHANGELOG entry for the wrapper canonicalization (judgment call — commit + this report may suffice per repo convention; decide once).
38. **[R]** DOMAIN_LANGUAGE.md: a "capability wrapper" term (wrapper/ambient/setcap vocabulary used in 3 runbooks already).
39. **[N]** TODO_LIST rows about storm-attribution redos (iotop-c/pidstat instruments) — unaffected by this change; instrument is cap-clean, rows stay valid.
40. **[R]** docs/agents/stability.md or monitoring runbook: write the "monitor-scope inventory" recipe (the 4-scan composite from §e.1) as a named procedure.
41. **[N]** iotop-c argv/caps on the restored window question — resolved by removal (the corpse is dead); no residue.
42. **[R]** If the owner confirms a child-inheritance intent for `+eip` (§g.3), design it explicitly (ambient propagation gives iotop-c's CHILDREN the cap; ghostty→fish siblings do NOT get it — the current config cannot do terminal-wide caps).
43. **[R]** Smoke-fail baseline: when was it last re-derived? 5 standing FAILs matched it today — schedule a periodic baseline triage.
44. **[R]** Capture-once discipline applied to deploys: today's batteries wrote full logs (good) — consider extracting the §-phase timings table per deploy for the 30-day retention window's forensics value.
45. **[R]** `deploy-when-quiescent` + PSI: TODAY'S near-duplicate of the queued PSI-gate row by the parallel session (23-35 report) — when implementing, merge both observations (mine: watcher fired into visible storm; theirs: same fire, PSI-leg proposal).
46. **[N]** iotop-c `-b` batch mode doc row (2026-10-06 "always -b from agents") — still good advice; batch+caps interaction now proven working; no change.
47. **[R]** Consider `oom_score_adj` / memory caps for monitor processes even pre-services-ization (freeze-history box; iotop-c OOM'd once).
48. **[R]** Persist the deploy-saga telemetry (9 attempts / 5 refusals / 1 force) into the deploy-count drift row if one exists — contention is becoming a pattern worth a metric.
49. **[R]** Verify post-23:34-deploy that the wrapper is still eip (the in-flight deploy re-renders /run/wrappers — expect yes, but verify-per-deploy is the rule).
50. **[R]** The umbrella: "monitor terminals vs the deploy gate" deserves a small planning doc (docs/planning/) once the owner answers 6 — today's three incident classes (REAL foreign storm / deleted-binary corpse / live-dashboard phantom) are the case study.

**Harvest ledger**: §f.1–3 harvested (TODO_LIST 3 rows + pipeline/services/desktop mirrors, one tool-verified pass). §f.4–50 deliberately not harvested: brainstorm/ROADMAP fuel per the up-to-50-is-not-a-commitment rule; promote via docs-health HARVEST if picked up.

## g) Three questions I cannot figure out myself

1. **Monitor-terminal policy (docs/todo/monitoring.md, open since 2026-11-08, re-evidenced today):** the corpse half is now mechanically resolved, but the LIVE btop/nvtop scopes still phantom-stall 60–100% on idle disks and WILL re-trip the next deploy gate (they named themselves at 18:00). Do you want (a) me to convert the monitor trio to systemd user services with a clean restart surface, (b) the deploy gate taught to classify monitor-scope self-stall via the existing io-psi-crosscheck verdict mode, or (c) keep per-deploy forcing after device-idle verification?
2. **The iotop window:** it closed as collateral of the corpse kill and will only respawn at your next niri start. Do you want it back immediately (one command — the wrapper is live), or is next-login fine?
3. **The `+eip` intent:** process-level caps are IDENTICAL to the old `+ep` through the ambient wrapper — the change is canonical-form parity, nothing behavioral. Was `+eip` just the canonical incantation you wanted, or is there a specific scenario you're aiming at (e.g. caps surviving into something that execs FROM iotop-c, or caps you expected in the iotop terminal's shells — which this flag does NOT provide; ghostty→fish siblings get nothing)?
