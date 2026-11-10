# Status — offline-banner legs deploy: false-OFFLINE collapse + the gen-995 PATH-phantom catch (2026-11-10 ~05:00)

**Mission:** ship the four-leg / phase-ladder offline-banner (built 2026-11-09 evening) to evo-x2, verify the false "OFFLINE — down for 15 s" banner is dead, close out the watch row.

## a. Headline outcomes

1. **The false-OFFLINE class is dead on the live box.** Pre-fix: 206 banner shows in 8 h (~one every 5 min, all `reason=net`, TCP/DNS healthy throughout — the gateway-policing class). Post-deploy (gen 995, pin `55121b2`): **1 show in 2 h** — and that 1 was the GENUINE all-legs outage during the switch itself (dnsblockd restarts on the gen flip → tcp+dns really were down for 8 s; the ladder correctly went offline → alarmed once → ledgered once → recovered to degraded).
2. **The deploy caught a second live bug the entire check suite could not see** (§d): the dns leg failed all 1448 probes on gen 995 because the unit PATH carried `pkgs.glibc` for getent while this nixpkgs ships getent as its own package. Fixed upstream (`a5673f7`) with a new module-contract gate that RESOLVES the rendered PATH; negative-tested at both layers.
3. Upstream CI fully green on both systems at `a5673f7` (run 42750209120) and at `b47022d` (run 42752007734 — the aarch64 probe-transitions hazard class closed for good).

## b. The CI arc — three failure classes, three root causes (commit `55121b2`)

The aarch64 `probe-transitions` red had THREE independent causes stacked (each proven from CI logs, not guessed):

| # | Failure (CI run) | Root cause | Fix |
| - | ---------------- | ---------- | --- |
| 1 | `degradedVisible:false` while `phase:"degraded"` in one state write (ade9779 run) | chained var/computed bindings read STALE inside change handlers and mid-`emitState` cascade | `7949237` (prior session): recompute from raw counters (`rawDownLegs()`) — now an AGENTS hard rule |
| 2 | `banner state=shown reason=link failures=2/2` never found in qs-link.log (7949237 run) | **scenario contamination**: the link-cue scenario reused the main sequence's `control-net` (`tcp fail/dns fail` on disk), so a fresh instance went offline via tcp+dns BEFORE link reached 2/2 — the exact assert was structurally unreachable on slow runners | reset `control-net` at scenario launch; remaining exact counts audited to deterministic positions only |
| 3 | `state.since must clear on recovery` with an EMPTY state file, **on x86_64** (9febffc run) | the state write was a plain truncate-then-write — a reader between truncate and write sees an EMPTY file (write tear); separately, the spawned write can lag the journal line | atomic tmp+mv rename in `emitState` (production fix — waybar polls hit the same window) + `assert_state_jq` polling helper for the three single-read `.since` asserts |

Verification discipline that made this cheap: local **emulated aarch64** (`nix build .#checks.aarch64-linux.probe-transitions` on the binfmt host) before every push — the exact CI surface — so the fix landed green on the first CI run.

## c. Deploy gen 995 — the executor race, handled

- My `nix run .#deploy` (02:25) lost the deploy lock to the parallel CV-session deploy (nested yolo crush, cwd `projects/CV`) — wrapper exited code=13 by design. Forensics via `/proc` (start ticks, cwd, argv; ps TIME columns are CPU time, not clock — first read was wrong, corrected). Their deploy evaluated the SAME shared tree (my bump committed `beec47aff` + their docs), activated ~02:30, ran its smoke battery 82 min, exited code=3 at 03:30.
- **Their 5 smoke FAILs triaged NOT-mine** (Bank-Sync new-vs-baseline, Health-Hub /readyz 503, crm/tq CPU, node-exporter journal rate, borg tripwire) — none plausibly offline-banner-related; they belong to the deploying session. Flagged here for the owner's cross-session picture; not acted on.
- Anchor check GREEN: `/run/current-system` == `system-995-link` == the built toplevel (`a51w2six…f9a75f4`).

## d. The gen-995 PATH-phantom (the deploy's real catch)

- Live journal: `leg down leg=dns failures=1/2…1448/2` — the dns leg failed EVERY probe since unit start while `getent ahostsv4 one.one.one.one` succeeded from an agent shell.
- A/B with the unit's EXACT PATH env reproduced `dns fail`; the glibc store path `/nix/store/…-glibc-2.44-57-bin/bin/` does not contain `getent` at all — **this nixpkgs ships getent as its own package** (`pkgs.getent`, e.g. `getent-glibc-2.44-57`). The PATH line predates the leg feature's grep-based "leg tools in PATH" check, which matches tool NAMES in unit text — a phantom passes it.
- Why it matters beyond a dead widget: with dns permanently down, the ladder reads any single tcp blip as "tcp+dns both down" → the false-OFFLINE class returns through the back door.
- Fix (`a5673f7`): PATH carries `pkgs.getent`; module-contract materializes the rendered unit text (`pkgs.writeText` — `builtins.toFile` cannot reference derivations) and RESOLVES `timeout/getent/ping` against the extracted PATH (`PATH=… command -v`). **Teeth proven at both layers** by atomic neuter/restore cycles: dropping the package trips the string assert; keeping a name-bearing but binary-less PATH trips the execution gate (`FAIL: unit PATH cannot resolve 'getent'` — the live bug, reproduced in CI).
- Probe-level proof pre-push: unit PATH + standalone getent → `dns ok`.

## e. Live verification battery (gen 995)

| Check | Result |
| ----- | ------ |
| Journal tokens | new tokens flowing (`leg down/ok leg=…`, `banner phase=… legs=…`) from first probe post-activation |
| Phase ladder under a real outage | the switch's own dnsblockd restart: offline (all legs) → alarmed ONCE → ledgered ONCE → degraded (icmp,dns) → correct per the ladder contract |
| False-OFFLINE collapse | 206/8 h → 1/2 h (the 1 = genuine) |
| Ledger | exactly one entry (`durationSec:8, reasons:[dns,net,tcp], probeFailures:150`), `since` cleared on recovery — the sandboxed `%h/.local/state` hole's FIRST live append (closes the upstream live-proof row's ledger leg) |
| Atomic state writes | state file reads clean post-deploy; the tear class is CI-covered (§b#3) |
| Unit restart | ExecMainPID 6750 → 2721433 at activation; restartTriggers did their job |
| dns leg | down on 55121b2 (PATH phantom) — fixed by a5673f7, deploy in flight at authoring time (§g) |
| Sound | the 02:31:48 show cue fired; audibility unconfirmed (no ears, pw-play stderr not in journal) — honest 🟡 in FEATURES |
| niri layer | namespace `systemnix:offline-banner` unchanged by the bump (wrapper untouched); layer check rides the post-deploy smoke of the a5673f7 switch |
| Deep-night caveat | 0 icmp flaps 02:30→04:5x — the ladder's verdict under the real evening flap window is still owed (upstream TODO row) |

## f. Harvest (all landed this session)

**offline-banner repo** (pushed `e652a3c`, `b47022d`, `d2599e8`): AGENTS hard rules ×3 (resolve-don't-grep rendered PATH; recompute leg state from raw counters; exact journal counts only at deterministic positions + always poll state reads) · TODO_LIST: live-proof row closed on proven legs, + evening-window observation, + waybar degraded-widget wiring, + vm-smoke additive-key asserts, + website sync row; sticky-dwell row DONE (`b47022d`) · FEATURES: ledger row → 🟢 (live append), + atomic-write row, + PATH-gate row, sound row honest 🟡 · **new gates**: `waybar-consumer` check (12 fabricated-state fixtures — the 2026-11-05 manual battery scripted) + probe-transitions sticky-dwell (dwell=0) scenario.

**SystemNix repo**: `docs/todo/monitoring.md` watch row closed with deployed evidence + a new gateway-side residue row (the underlying icmp policing diagnosis, owner-gated evening captures); `docs/agents/desktop.md` §Offline banner synced to the v4 contract (legs, ladder, atomic writes, PATH-phantom lesson); CHANGELOG row added.

## g. Deploy state + open owner decisions

- **a5673f7 deploy**: committed in-tree (lock + registry consistent at HEAD), gated behind the parallel session's lock-float sweep via a self-firing quiescence gate (4×60 s clean polls → green-eval probe → deploy; eval-red aborts — never deploy a broken mid-sweep tree). **FINAL (2026-11-10 19:3x): the parallel session's float-gate deploy landed gen 997 carrying the final pin d2599e8 (module content = this fix); anchor check green (`/run/current-system` == `system-997-link` == the built toplevel); dns leg honest on the new gen (6 transient downs / 6 recovers); the evening verdict — 179 degraded flaps all silent, 4 genuine offlines each ledgered once — is in the 20-21 session report. The two doc surfaces (monitoring row + desktop.md) are now flipped to deployed-gen-997.**
- **Deploy ride-along blessing**: gen 995 landed via the CV session's deploy carrying my committed bump (shared tree). This session's own deploy attempt lost the lock by design. Ratify "bump commits may ride whichever session's deploy fires next" or mandate dedicated deploy slots.
- **aarch64 CI relax policy**: my rec remains RELAX nothing — the emulated aarch64 gate caught THREE real bugs today (two timing, one logic); it is the highest-value check in the suite. The real fix was local binfmt verification before push.
- **dprint.json zombie (D4)**: BuildFlow resurrected a 29-file docs sweep's config again upstream (foreign commit `6d044c9`, flagged 2026-11-10 00:2x) — re-delete vs adopt `.buildflow.yml` still needs the owner call.
- **Waybar wiring**: the degraded widget consumer is upstream-ready but unwired on evo-x2 (quickshell strip only) — wire it when the evening-window verdict confirms the ladder (cheap: one waybar config block).
