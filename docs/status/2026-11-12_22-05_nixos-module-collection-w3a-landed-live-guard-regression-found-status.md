# nixos-module-collection W3a landed + live guard-regression found — session status

**Created:** 2026-11-12 22:05 CET
**Session:** continuation of the plan-execution instance (owner blanket GO directive at resume: "the WHOLE TODO LIST, do not stop"; ≈21:35–22:05)
**Plan:** `docs/planning/2026-11-10_05-07_SUPERB-nixos-module-collection-extraction.md` (EXECUTING marker live)
**Prior report:** `docs/status/2026-11-12_18-26_nixos-module-collection-w1w2-landed-deploy-pending-status.md` (its §g owner questions answered by the blanket-GO directive: deploy GO, D1=RETIRE default, triage stays queued)

---

## 🔴 LIVE FINDING FIRST (session's most important discovery)

**The crush-hot-db live-writer guard is BLIND on the live host RIGHT NOW** — a pre-existing regression, found and root-caused this session:

- **Mechanism:** yama `ptrace_scope=1` (host confirmed: `/proc/sys/kernel/yama/ptrace_scope` = 1) makes `readlink /proc/<pid>/fd/*` of FOREIGN processes return EACCES even for root unless the reader holds CAP_SYS_PTRACE. The migrate unit's sandbox (harden{}) strips all caps except CHOWN/FOWNER/DAC_OVERRIDE → the per-project liveness sweep finds the crush processes (comm match works) but reads ZERO fd targets → `skip <project>: live crush session holds it open` never fires → **the unit can relocate the session dir of a LIVE crush session** (the exact writer-stranding incident the guard was built to prevent, 2026-09-21).
- **Live evidence:** the 20:47 deploy restarted the unit; journal 21:48:15 shows `migrated monitor365-ui-sdk` (and `skip legal-cases: … manual merge` — a target-exists skip, NOT a liveness skip). Whether monitor365-ui-sdk had a live session at 21:48 is unverified; the RISK is live for every future run (04:10 daily + every deploy restart).
- **Proven pre-existing:** SystemNix's OWN `checks.x86_64-linux.crush-hot-db` fails IDENTICALLY on its pinned nixpkgs (f4a03c00, ran it this session: `migrated late` — guard blind). So this is not my port; the collection VM test merely exposed it on current unstable.
- **FIX (already written + tested collection-side):** `CapabilityBoundingSet += CAP_SYS_PTRACE` in `modules/hot-dir-migrate` (the capability is semantically exactly what an fd-inspecting guard needs) + a hardcoded contract assertion (`CAP_SYS_PTRACE` must be present) + a `cap-stripped` negative leg proving the check bites. VM test GREEN after the fix (full behavior matrix incl. `skip late` guard).
- **SystemNix heals via W3b delegation** — the delegation carries the fixed engine. Until W3b deploys, every migrate run (timer 04:10) risks stranding a live session. This RAISES W3b urgency from "dedup wave" to "live-defect remediation".

## a) FULLY DONE (verified this session)

1. **§g questions resolved by owner directive** (blanket GO): deploy at fresh window, D1 = RETIRE, TODO-gate triage stays queued.
2. **W1+W2 deploy verified LIVE** — a foreign session's deploy (monitor365 fix, flipped 20:47, gen **system-1004**) carried W1+W2: tree-eval'd wifi-failover ExecStart == live PID store path (`sxhs0v94…`); boot-mirror-sync running the collection module (de-Samsung-ified description visible). **Smoke green**: wifi-failover restarted 20:47:27 ("starting carrier watch", "eno1 carrier UP"); boot-mirror-sync boot-installed + syncing.
3. **Deploy anchor verified**: watched the in-flight `nh os switch` drain to completion; profile `system-1004-link` == `/run/current-system` (the mid-flight "profile behind" reading was the known nh-late-profile-set behavior — no repair needed). My deploy todo closed WITHOUT firing a deploy (drv-equality recon showed the live system already carried the wave; remaining tree drift is docs-only).
4. **W3a — collection modules written** (all committed via daemon, tree clean at `9beb204`):
   - `lib/filesystems.nix` (mkFilesystem cross-fs guard moved in from SystemNix) + `lib/default.nix` export + header/README split-contract updates
   - `modules/hot-tier/` — the mount family: attrsOf instances (device/subvol/mountPoint/fsType/mountOptions/tmpfiles ownership), after+wants (never requires) wiring per declared service, `dropLogsDirectory` neutralization + `+`-privileged ownership-heal chown (the VM-proven `*Directory=` trap), subvol auto-prepend, nofail+5s-timeout degradation defaults
   - `modules/hot-dir-migrate/` — the crush-hot-db engine generalized: unitName/dirName/dbName/matchComm/projectsDir/mountPoint/destName/ownerUser/ownerGroup/dryRunEnvVar/discoveryDepth/freshWriteMinutes/timer options; all behaviors travel (per-project live-writer guard, fresh-write window, depth tripwire, empty-target auto-heal vs populated refusal, dry-run, single-flight flock, fail-loud exits, timer-pulled never boot-gated, guarded system-health hook)
   - Both module READMEs (consumption snippets + contract lists)
5. **W3a — 5 new checks, ALL GREEN**: `hot-tier-contract` + `hot-dir-migrate-contract` (fixture-host eval + hardcoded throwIfNot chains, drv-forced) and `hot-tier-journal-vm` + `hot-tier-caddy-vm` (2-node healthy+degraded each — the caddy degraded node proves the *Directory= dependency-death class) + `hot-dir-migrate-vm` (full behavior matrix: 5 relocated + tripwire + auto-heal + live-writer guard + dry-run + convergence + idempotency).
6. **Negative harness extended**: `hottier` group (green control, wants-dropped, neutralization-dropped, heal-renamed, nofail-dropped) + `hotdirmigrate` group (green control, liveness-stripped, rwpaths-narrowed, bootgated-restored, **cap-stripped**, flock-dropped) — legs WRITTEN against the contract checks' hardcoded markers (phantom-leg discipline).
7. **CAP_SYS_PTRACE regression fix** (see 🔴 above) — fix + contract pin + negative leg, VM-proven.
8. **Docs**: collection CHANGELOG entry (incl. the recursion design lesson), README Modules section (4 modules), FEATURES.md rows.

## b) PARTIALLY DONE

1. **W3a close-out NOT done**: the new negative-harness groups are written but NOT yet RUN (`bash tests/negative/run.sh` with `CASES=hottier,hotdirmigrate` pending); full collection `nix flake check --no-build --all-systems` not run on the final tree (individual checks proven individually); **push + probe-before-lock pending** — SystemNix still locks the collection at `9deac014` (W2 rev).
2. **Commit hygiene**: all W3a work sits in daemon heuristic commits (`85753fe`, `9beb204`, …) — no amend-forward into a properly-messaged commit yet (deliberately deferred to push time; unpushed commits must be verified all-mine first).
3. **W3b design finalized, zero SystemNix edits made**: journal-hot/caddy-logs-hot become plain `platforms/` layers (recipe §5 — inputs via specialArgs, boot-mirror precedent); crush-hot-db becomes the two-stage `flake.nixosModules` wrapper layer (wifi-failover precedent) feeding `services.hot-dir-migrate` with fleet names (`unitName = "crush-hot-db-migrate"`, `dryRunEnvVar = "CRUSH_HOT_DB_DRY_RUN"`); SystemNix test-crush-hot-db.nix import line updates to the applied-wrapper form; test-journal-hot/test-caddy-logs-hot RETIRE (scenarios now live as collection checks — boot-mirror doctrine: no SystemNix VM test for delegated modules, host eval selftests carry the lock-side pin); test-hot-db.nix + test-hot-db-assertions.nix STAY (they test `services.hot-db` — the /mnt/hot subvol-manager, NOT in W3b's ×3 list); migrate-journal-hot.sh / migrate-caddy-logs-hot.sh STAY (one-time, already-run; documented in layer headers).

## c) NOT STARTED

- W3b execution (parity baselines → 3 layers → re-lock → deploy + anchor + smoke) — now URGENT (🔴 live guard defect heals only via it)
- A0 (harness generalization — partially obsoleted: the harness IS per-group now), A1 (8 pure audit gates), A2 (6 coupled option-ify), A3 (audit close-out)
- P1 (pool-recovery), D1 (dual-wan RETIRE — owner-defaulted), C1 (collection CI), C2 (options.json docs), C3 (search site decision), Y1 (close-out pack)

## d) TOTALLY FUCKED UP (honest near-misses; nothing destructive shipped)

1. **Three test-file syntax round trips**: `\+` is an invalid Nix string escape → invalid regex (fixed via `lib.hasPrefix "+"` + separate match); paren-count miscounts on two throwIfNot chains (11 vs 12 vs 13) — each caught by the next build, never claimed green.
2. **Edit-tool mtime rejections ×2**: read CHANGELOG/README via `bash head` instead of the VIEW tool → edit refused ("modified since read") → wasted round trips. Standing rule for myself: only VIEW counts as a read.
3. **`rg -rn` typed TWICE** (hook-blocked both times — the display-mangling replace flag). The muscle memory is the enemy; `rg -n` only.
4. **Wrong check attr name** for the SystemNix crush test (`crush-hot-db.test`) — killed the job, relaunched with `crush-hot-db`. Cheap but sloppy.
5. The initial hot-tier module hit **infinite recursion** (dynamic config keys `fileSystems.${m.mountPoint}` computed from `cfg.mounts` at config top level) — cost 4 bisect round trips. The lesson is now in the CHANGELOG; arguably I should have recognized the canonical-shape rule (static top-level keys, dynamic structure inside values) BEFORE writing the module.

## e) WHAT WE SHOULD IMPROVE

1. **Bisect empirically, but bound it**: the recursion took 4 experiments; a minimal-fixture repro harness (`~/.cache/ht-bisect/`) built ONCE and reused made each iteration fast — keep that pattern for module-system mysteries.
2. **Port tests carry their target's regressions — that's a feature**: the collection VM test exposing the yama blindness (and the SystemNix original failing identically on its own pin) proves the extraction doctrine (fix once upstream, both sides heal). Rule: when a port fails, run the ORIGINAL before touching the port.
3. **DBG lines in proven-prod scripts are load-bearing forensics** — I initially dropped them as noise and lost the first diagnosis round; restoring them named the root cause immediately (readlink EACCES + yama=1 visible in one line).
4. **The live-defect discovery path was accidental** (port test → original also red → host check). A standing "run the fleet's own checks on its pin" probe would have caught the guard blindness days earlier — worth a TODO row.

## f) NEXT (execution order)

1. **[ready] Run the new negative-harness groups** (`CASES=hottier,hotdirmigrate bash tests/negative/run.sh`) + full `nix flake check --no-build --all-systems` on the collection final tree (tee `~/.cache/fc-collection.log`).
2. **[ready] Amend-forward W3a into a properly-messaged commit** (verify unpushed commits all-mine first) + `git push` + probe-before-lock (`nix build github:LarsArtmann/nixos-modules/<rev>#checks.x86_64-linux.hot-dir-migrate-vm`).
3. **[ready — URGENT, live defect] W3b delegation ×3**: same-lock parity baselines (`journal-hot`, `caddy-logs-hot`, `crush-hot-db` units + fileSystems, `~/.cache/parity/`), rewrite the 3 SystemNix files as layers, update test-crush-hot-db.nix import, retire test-journal-hot/test-caddy-logs-hot from tests/default.nix, `nix flake update nixos-modules`, parity diff (store-hash-strip + build-level script-tree diff; DOCUMENTED deltas this time: DBG-line restoration, the CAP_SYS_PTRACE addition — the fix itself), evo-x2 eval green.
4. **[ready] W3b deploy + anchor + smoke** — carries the guard fix LIVE; then `journalctl -u crush-hot-db-migrate` behavior check at next fire + the SystemNix crush VM test goes green through the layer.
5. **[ready] Y1-mini for W3**: CHANGELOGs (both repos), runbook headers (docs/services/hot-db.md, crush.md), TODO rows ticked both surfaces, WARN-aware.
6. **[ready] A-wave**: A1a-c (8 pure audit gates move + selftests), A2a-c (6 coupled gates option-ify, negative leg FIRST each), A3 (negative-test-lints.sh re-point, CI wiring, full sweeps ×2 repos).
7. **[ready] P1** pool-recovery extraction + delegation.
8. **[ready, owner-defaulted] D1** dual-wan RETIRE (`git rm modules/nixos/services/dual-wan.nix` + scripts; the wifi-failover `or false` assertion shape already tolerates it).
9. **[ready] C1** collection CI (F6 eval-matrix stable+unstable via --override-input, pinned-lock full check, aarch64 eval leg, negative-harness job).
10. **[ready] C2** options.json + per-module README snippets wired into checks (`nixosOptionsDoc`, warningsAreErrors as description lint).
11. **[decision at ≥5 modules — we have 4 post-W3] C3** NuschtOS/search site on GitHub Pages.
12. **[ready] Y1 full close-out**: runbook headers sweep, TODO prune + WARN recount (`prune-done-todos.sh` dry-run-first), plan EXECUTED flip via `plan-marker.sh`, queue rows ticked full-line both surfaces.
13. **[watch] monitor365-ui-sdk 21:48 migration**: verify no live session was stranded (session DB integrity: open crush in that project once; if it was mid-session at 21:48 the symlink+mv may have stranded fds — check `find /proc/*/fd -lname '*monitor365-ui-sdk*'` while a session runs).
14. **[ready] TODO row**: "run fleet checks on its pin weekly" probe idea (e-finding 4) — harvest decision owner's.

## g) OWNER QUESTIONS (cannot figure out myself)

1. **Live-defect urgency vs wave order:** the blind live-writer guard means every `crush-hot-db-migrate` run (next: timer 04:10 tonight) can relocate a LIVE crush session's dir. Do you want the W3b deploy TONIGHT as the fix vehicle (my plan — it lands ~1-2h of work), or a minimal hotfix first (backport just the CAP_SYS_PTRACE line into `modules/nixos/services/crush-hot-db.nix` + fast deploy) with W3b following on the normal wave order? The hotfix is strictly faster to live but forks the fix (W3b then replaces it hours later anyway).
2. **Risk appetite for tonight's 04:10 timer:** if W3b (or hotfix) does NOT land before 04:10, should I stop/disable the `crush-hot-db-migrate.timer` until the fix deploys (one `systemctl stop` — but polkit: needs owner hands or a deploy), or accept the risk (the guard's skip set was ALREADY blind for an unknown number of days/weeks — tonight is not a new risk class, just a known one)?
3. **Retire-vs-keep the SystemNix journal/caddy VM tests:** plan-default (boot-mirror doctrine) says RETIRE them from tests/default.nix (scenarios now live as collection checks; SystemNix keeps eval-level selftests through the lock). Alternative: keep them driving the delegation layers with `inputs` plumbing (extra test-maintenance for near-zero added coverage). I default RETIRE — confirm?

---

**Tone-verified self-check**: every "GREEN" claim above cites its command+rc in this session's logs (`~/.cache/htc.log`, `hdmc.log`, `vm-*.log`); the two claims I could NOT verify are marked (monitor365-ui-sdk session state; negative-harness new groups unrun). The 20:47 deploy attribution is FOREIGN (not mine) — stated as such in a)2.
