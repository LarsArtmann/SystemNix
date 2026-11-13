# Status: W3b Landed Tree-Side (All Gates Green) — Deploy Pressure-Blocked, Watcher Armed

**2026-11-13 01:00 CET — session span ~22:45 → 01:00 (resumed from the 22:05 pause under the re-issued blanket GO) · evo-x2 live gen system-1004 (qy2wimc5, foreign pin-move deploy) · collection locked 9deac014 → `726c2bb`**

## Scope line — what this report VERIFIED vs what it did NOT

**VERIFIED (command / artifact, fresh at report time):**

- Collection: negative groups `hottier,hotdirmigrate` **11/11 PASS** (`~/.cache/neg-w3a.log`); full `nix flake check --no-build --all-systems` **green** (`~/.cache/fc-collection.log`, rc=0); pushed `fc5ed3d..726c2bb`; **probe-before-lock at `726c2bb` from GitHub: ALL FOUR W3 checks green** (hot-dir-migrate-vm, hot-tier-contract, hot-tier-journal-vm, hot-tier-caddy-vm — rc=0 each).
- SystemNix: **rendered-unit parity GREEN** — `fileSystems."/var/log/journal"|"/var/log/caddy"`, `systemd-journald`, `caddy` **zero deltas** (store-hash-stripped); `crush-hot-db-migrate` + timer differ ONLY in the six documented delta classes (below). Full `nix flake check --no-build` **green** (`~/.cache/fc-systemnix-w3b.log`); the surviving `checks.x86_64-linux.crush-hot-db` VM test **green through the delegated wrapper** (80 s, `~/.cache/crush-vm-w3b.log`); `crush-hot-db-migrate` verified IN the rendered `system-health.extraMonitoredServices` (59-unit list) — the collection module's wiring works.
- Deploy attempt: quiescence 4×60 s PASSED (23:34) + fresh drv eval green (`akbpznzz…drv`) → deploy FIRED 23:35:07 → **pressure-gate REFUSAL exit 12** (`~/.cache/w3b-deploy-chain.log`). Storm class verified REAL, not phantom: Samsung nvme0n1 94-100 % busy, 1 D-state task.
- The 04:10 migrate timer is STOPPED (live `systemctl is-active` → inactive; sudo verified `sudo -n true` rc=0 first) — the blind-guard risk window is closed; the deploy re-arms it with the fixed unit.
- monitor365-ui-sdk (probed live): `.crush` → `/mnt/hot/crush/monitor365-ui-sdk`, copy intact at 21:48-era content, NO live session on it now; 32 live crush processes on other projects.

**NOT verified (and why):**

- The W3b deploy LANDING — blocked by the pressure gate under sustained REAL IO storms from ~24 parallel sessions (PSI avg10 20-50 since 23:35; 45.3 at authoring). A conditional watcher is armed (`~/.cache/w3b-deploy-watch.log`): fires the deploy on any ≥30 s window of PSI < 20 + quiet eval-relevant tree; ceiling ~02:47. NO override used — deploying into real saturation is exactly the stranding class the gate exists for.
- The live skip-line verification (`skip <project>: live crush session holds it open` from the FIXED unit) — needs the deploy live + a live crush session.
- Whether a session WAS live on monitor365-ui-sdk at 21:48 — post-hoc unverifiable from process state (processes gone); §g.2 asks the owner directly.
- TODO row ticks — deliberately held until the deploy anchors (W3 is not done until live; rows would claim ahead of truth).

---

## a) Done and VERIFIED

1. **W3b tree state is COMPLETE and fully gated.** The three delegation layers are in: `platforms/nixos/system/journal-hot.nix` + `caddy-logs-hot.nix` (plain fleet layers over `inputs.nixos-modules.nixosModules.hot-tier`; both mounts byte-identical rendered) and `modules/nixos/services/crush-hot-db.nix` (two-stage wrapper feeding `services.hot-dir-migrate`: historical unit name `crush-hot-db-migrate`, `CRUSH_HOT_DB_DRY_RUN`, projectsDir/owner facts; public `services.crush-hot-db` option surface unchanged — configuration.nix's `.enable = true` untouched).
2. **The live-defect fix travels the lock.** Collection `726c2bb` carries `CAP_SYS_PTRACE` in the migrate unit's bounding set + the yama-regression comment + the `cap-stripped` negative leg + the hardcoded contract assertion. Parity diff proves the ONLY hardening delta on the SystemNix side is exactly this cap add (`CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE` → `+ CAP_SYS_PTRACE`).
3. **Documented parity deltas (complete list, crush svc + timer):** (1) the cap add [the fix]; (2) unit/timer descriptions ("session DBs to the hot-DB disk" → "session dirs to the hot disk"); (3) summary echo prefix `crush-hot-db:` → `crush-hot-db-migrate:` (2 lines — runbook greps updated); (4) WARN text "(stays on the QLC root)" → "(stays on the OS disk)"; (5) internal variable renames `crushDirs`→`sessionDirs` etc. (consistent both sides); (6) the per-fd `DBG: fd` echo line DROPPED (journal-noise reduction; the two load-bearing DBG lines — `DBG: scanning … pid` + `DBG: readlink FAILED` — travel, verified in the rendered script). Every executable line otherwise byte-identical; every skip/lock/heal message the runbooks grep is unchanged.
4. **Test moves:** `tests/test-journal-hot.nix` + `tests/test-caddy-logs-hot.nix` RETIRED (git rm'd; boot-behavior coverage lives in the collection's `hot-tier-journal-vm`/`hot-tier-caddy-vm`, both GitHub-proven at the locked rev). `tests/test-crush-hot-db.nix` STAYS, drives the delegated wrapper green (import now takes `inputs`, wifi-failover precedent; tests/default.nix updated).
5. **Y1-mini docs DONE:** CHANGELOG W3 entry (top); runbooks — `docs/services/crush.md` (delegation + yama/CAP_SYS_PTRACE narrative + timer-pulled shape + the echo-prefix change), `hot-db.md` (test reference repointed), `journal-hot.md` (owning-module header), `caddy.md` (delegation note); `docs/agents/integration-registry.md` recipe hardened with 3 W3 lessons (scanner-passes-`self` ellipsis trap; the parity `--apply` removeAttrs list for service units; W3 trio added to reference implementations).

## b) PARTIALLY done

1. **The deploy itself** — every gate green, fired once, pressure-refused; watcher armed (see scope line). Anchor-by-generation-number + smoke + timer re-arm check remain.
2. **TODO surface ticks** — held for the anchor (rows identified: TODO_LIST 662 annotation stays-open-with-W3-done; upstream.md:402 same; TODO_LIST 72 gets the crush-hot-db-half-done note — its VM test is green on the current tree, hot-db half untouched).
3. **Next waves scoped but not started** (deploy payload must stay pure W3b): A1's 8 pure audit files enumerated + coupling-checked (`timeout-audit` is 20 lines zero-coupling; `systemd-shape-audit` is 793 lines whose 4 allow* options travel cleanly); P1 pool-recovery located (535 lines); D1 dual-wan file located; C1 collection CI EXISTS (parallel session, `check.yml`: full check + aarch64 eval leg) but shows no runs yet and lacks the plan's `--override-input` nixpkgs matrix.

## c) NOT started

- A0–A3 (audit-gate migration), P1, D1 (RETIRE, GO default), C1 verification + matrix leg, C2 (options.json drift check + README polish), C3 (decide at ≥5 modules), Y1 final close-out (EXECUTED flip, TODO prune + WARN recount).
- The fleet-wide fd-inspecting-unit sweep (are there OTHER units needing CAP_SYS_PTRACE under yama?).

## d) Totally fucked up (honest)

1. **Three failed parity-baseline rounds** (startLimitBurst → +startLimitIntervalSec → +runner) before the working `--apply` removal set. W2's recipe already said path units need `--apply`; I should have anticipated service units too. ~15 min of eval cycles. Lesson now banked in the recipe (step 6).
2. **The wrapper ellipsis miss** — `{inputs}` instead of `{inputs, ...}` cost one full evo-x2 eval cycle ("called with unexpected argument 'self'"). The wifi-failover precedent I transcribed from HAS the ellipsis.
3. **The deploy chain fired without a PSI pre-gate** — the 23:35 fire was guaranteed-refused (PSI was ~30). v2/v3 loops added the pre-gate; the wasted fire also burned the quiescence window (re-armed afterwards).
4. **Probe sequencing slip** — probed `726c2bb` from GitHub BEFORE pushing it (404). One probe cycle wasted; re-probed correctly after push.
5. Minor: `git rm` blocked twice by daemon index.lock (waited out); `tail -1 file1 file2` multi-file form mangled in this shell (used grep instead).

## e) What to improve

1. **Deploy chains must pre-gate on PSI, not just tree quiescence** — tonight proved a quiet tree says nothing about disk pressure. Should be encoded beside the 2026-10-25 quiescence doctrine (integration-registry or AGENTS deploy section).
2. **Parity capture should be a script, not hand-rolled eval strings** — W2 and W3 both improvised; a `scripts/parity-render.sh` with the removeAttrs list baked in would kill the 3-round class from (d.1).
3. **Multi-session deploy contention needs a convention** — ~24 sessions, three separate editing sessions re-poisoned the quiescence window tonight, and the 22:45 report hit a twin-deploy lock race. A deploy-intent lock/file (one deploy owner at a time) would serialize this class.
4. **The 5-minute-mtree quiescence proxy is gameable by burst editors** — consider adding "daemon-clean git status on eval-relevant paths" as a second signal.

## f) Next tasks (not padded — the real list)

1. Land the W3b deploy when the watcher's window opens (or per §g.1 ruling) → anchor by generation NUMBER (`ls /nix/var/nix/profiles/ | grep '^system-[0-9]*-link$' | sort -V | tail -1` vs `readlink /run/current-system`), smoke `journalctl -u crush-hot-db-migrate -u wifi-failover --since <deploy>`, verify the timer re-armed.
2. Live-skip verification: with a live crush session on some project, the next migrate run must print `skip <project>: live crush session holds it open`.
3. Tick the TODO surfaces (b.2 rows) full-line, both files, one edit.
4. A-wave: A1a timeout-audit first (trivial), then start-limit/tmp-cleaner/systemd-shape; A1b mount-gating/memory-watermark/dynamic-user/capability-grant; A1c delete originals + imports + both-repo full checks; A2 option-ify the 6 coupled gates (port-registry/stray-unit/deploy-restart/gatus-coverage/script-port/otel-endpoint); A3 re-point negative-test-lints + CI.
5. P1 pool-recovery extraction (options: pool devices, restart set) per the X0 recipe.
6. D1: RETIRE dual-wan (git rm module + scripts; enable-site cleanup; the wifi-failover assertion's `or false` shape tolerates the absent option tree).
7. C1: verify the collection's first green CI run; add the `--override-input` nixpkgs matrix leg (26.05 + unstable).
8. C2: options.json drift check wired into checks; per-module README polish. C3: decide once P1 makes it 5 modules.
9. Y1: EXECUTED flip, TODO prune + WARN recount, CHANGELOG both repos.
10. Fleet sweep: grep every unit script that reads `/proc/<pid>/fd` — anything fd-inspecting needs the CAP_SYS_PTRACE audit (this defect class may have siblings).
11. (deliberately NOT harvested into TODO_LIST.md at authoring: items 1-3 are deploy-gated rows whose queue one-liners already exist via the 662 continuation row; items 4-9 ARE the plan's own rows (TODO_LIST 662 + upstream.md 402 already carry them verbatim); items 10-11 are new and belong in the services/monitoring libraries — queuing them tonight would race the three active parallel sessions' TODO edits; owner instructed report-and-wait.)

## g) QUESTIONS (max 3 — cannot be figured out from the tree)

1. **Deploy pressure override authority:** the box has sat at REAL IO PSI avg10 20-50 for ~90 minutes (parallel-session builds; Samsung 94-100 % busy — verified NOT the phantom class). The W3b deploy is fully gated, tiny (module-code closure delta), and carries a safety fix; the timer is stopped meanwhile so nothing is at risk by waiting. If no natural window opens (watcher ceiling ~02:47): authorize `DEPLOY_FORCE_PRESSURE=1`, or keep waiting for calm? (This is the still-uncoded authority question from 2026-11-11 §g3, now with a concrete case.)
2. **monitor365-ui-sdk stranding:** were you running a crush session on monitor365-ui-sdk around 21:48 tonight? The blind guard relocated its `.crush` then; IF a session was live, its post-21:48 writes went to an unlinked inode (gone); the migrated copy is 21:48-era either way. Your answer decides whether I diff the whole fleet's `.crush` migration history for other silent strandings from the blind era.
3. **The 22:05 §g defaults stood in for your answers** (re-issued GO): W3b-as-fix-vehicle (executed), timer-stopped-until-deploy (executed), test retirement (executed). Confirm all three, or flag now — the tree is still un-deployed, so reversal is cheap at this moment only.

---

*Session attribution: W3a code (collection modules/checks/docs) authored by the prior instance of this conversation; W3b delegation, parity, gates, docs, and this report by this session. The 20:47/21:56 gen-1004 deploy is FOREIGN (the pin-move session). The collection's in-flight `wifi-failover-contract` work is a parallel session's — untouched, rides a later push.*
