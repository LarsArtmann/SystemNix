# Status Report — invoices-dashboard module extraction: upstream half written and three checks green, SystemNix half not started

**Date:** 2026-11-28 06:10 CET · **Author:** Crush session (zai glm-5.4) · **Trigger:** owner stop-and-report
**Ask that opened the session:** "`modules/nixos/services/invoices-dashboard.nix` seems like BS. Make sure we use the UI from `~/projects/invoices` and keep as much code as possible over there."

**CLOSED 2026-11-28 (HARVESTED):** both halves landed the same day — upstream half on `origin/master` `35b25c66`, SystemNix half (thin layer, shim dropped, lock `8706f1fc → 35b25c66`, Gatus title "Invoice Ledger") in the shared tree; record: `CHANGELOG.md` 2026-11-28 "invoices-dashboard is integrated through the upstream `nixosModules.default` output". Open follow-ups harvested into `docs/todo/upstream.md` (timesheets extraction; first-backup proof).

---

## Scope line (what this report verified, and what it did not)

**Repos and pins at report time**

| Repo                   | HEAD (short) | Tree  | Note                                                                         |
| ---------------------- | ------------ | ----- | ---------------------------------------------------------------------------- |
| `~/projects/invoices`  | `ede43fe9`   | clean | **13 commits ahead of `origin/master`** (daemon commits, unpushed; last origin push 04:33 at `681c1332`) |
| `~/projects/SystemNix` | `ff84ab102`  | clean | **this session wrote nothing here** except this report                        |

**Verified this session, by command**

- `nix build .#checks.x86_64-linux.module-eval` (invoices) → rc=0, log `~/.cache/invoices-extraction/check-module-eval.log`.
- `nix build .#checks.x86_64-linux.backup-script .#checks.x86_64-linux.backup-script-negative` → rc=0, log `~/.cache/invoices-extraction/check-backup.log`.
- Negative leg for the eval check: throwaway worktree at `ede43fe9` with the `ConditionPathExists` line deleted → rc=1, `missing line …: ConditionPathExists=/var/lib/invoices-dashboard/config.yaml` (`~/.cache/invoices-extraction/neg-module-eval.log`); worktree removed afterwards.
- `nix-instantiate --parse` on the 7 Nix files → OK. `bash -n` + `shellcheck nix/backup-db.sh` → rc=0.
- `buildflow -s nix-fmt --fix` → rc=0 (reformatted `flake.nix`, `nix/checks.nix`, `nix/module.nix`; my files only).
- `nix build .#checks.x86_64-linux.module-vm` → **rc=1, failed before the VM booted** (`~/.cache/invoices-extraction/vm.log:62-64`): `invoices-ede43fe9…-go-modules.drv` hash mismatch, **specified `sha256-Y7HkZSMx…` (the repo's own `flake.nix`), got `sha256-/OE8Z7by…`**.
- `./scripts/check-root-allowlist.sh` → rc=1: `FORBIDDEN root directory: nix/` (new, mine) and `FORBIDDEN root file: .gitleaksignore` (pre-existing).

**NOT verified (and why)**

- The VM test's assertions are unproven (its build died on the stale vendorHash above).
- Upstream `nix flake check`, a plain `buildflow` run, and BuildFlow's own shellcheck step were not run.
- The template round trip for `nix/backup-db.sh` was diffed against the live script with a stand-in path for `@gzip@`: 49 of 50 lines proven by diff, the gzip line by inspection only.
- SystemNix: no eval, no lock move, no parity baseline, no deploy, nothing written.
- The push state after 06:10 is unknown (the daemon pushes on its own cadence; nothing was pushed by this session).

---

## Findings that change the plan (first-hand)

1. **The live dashboard serves a UI that is 21 commits old.** The running process is `invoices-51177112…` (rev `51177112`, pushed 2026-11-22 22:25), generation `system-1033-link`. The repo tip is 21 commits and 38 dashboard files ahead of that (`git diff --stat 51177112..HEAD -- internal/dashboard cmd/dashboard`: +4113 / -6570). SystemNix's lock (`7de5577f`) is 16 commits behind the tip as well. "Use the UI from `~/projects/invoices`" therefore needs a lock float **and** a deploy; neither happened.
2. **The page title contract moved and SystemNix's functional check will go red on the next deploy.** `pageTitle = "Invoice Ledger"` since `b4f32117` (2026-11-28 02:59), pinned upstream by `internal/dashboard/ledger_test.go:350` (`<title>Invoice Ledger</title>`). SystemNix's registry check "Invoices dashboard page" asserts `[BODY] == pat(*Invoice Dashboard*)` (`modules/nixos/services/invoices-dashboard.nix:287`). It is still green at the live rev and at lock rev `7de5577f` and turns red at the tip. Not fixed.
3. **Upstream's baked vendorHash is stale under its OWN lock.** The repo's own flake cannot build its package at `ede43fe9` (finding in the scope line). That falsifies the attribution in SystemNix: `lib/lars-packages.nix:391-398` and the module's option comment say the shim exists because the "2026-11-24 nixpkgs-root float" re-staled a non-follower input. The truth is the reverse: SystemNix's shim carries the true hash, upstream's `flake.nix` carries the stale one. invoices' AGENTS.md already said "currently stale from the 2026-11-08 wave"; I read that sentence and did not act on it before building.
4. **Consequence for the ask:** fix the hash upstream (`buildflow -s nix-hash-fix --fix`), re-lock, and the SystemNix shim becomes pure treadmill on BOTH surfaces (`lib/lars-packages.nix` and the module's `package` default) and can be dropped. That is more SystemNix code removed, which is exactly what the ask wants.

---

## a) FULLY DONE — all in `~/projects/invoices`, local only (daemon commits `d0d87cfa` … `ede43fe9`)

| # | What landed                                                                                                   | Where                                                     | Proof                                                   |
| - | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------- |
| 1 | Portable NixOS module `services.invoices-dashboard`: options, dashboard unit, backup unit, timer, tmpfiles, optional system user, portable hardening | `nix/module.nix` (305 lines)                              | eval check rc=0                                         |
| 2 | The nightly backup script moved out of SystemNix as a tracked, shellcheck-clean template (placeholders for db, data dir, backup dir, retention, sqlite, gzip) | `nix/backup-db.sh`, `nix/backup-script.nix`               | shellcheck rc=0; positive harness rc=0                  |
| 3 | Flake output `nixosModules.default` (imports the module; `package` defaulted to the flake's own build, lazily) | `flake.nix`                                               | eval check renders it                                   |
| 4 | Check `module-eval`: renders the shipped defaults and a layered config under a real `nixosSystem`, expects and rejects unit lines | `nix/checks.nix`                                          | rc=0; negative leg catches a dropped `ConditionPathExists` |
| 5 | Checks `backup-script` + `backup-script-negative`: fixture store run (clean skip without DB, dump, config snapshot, restore, `quick_check`, retention, idempotent rerun) and a mutated script that must fail at the snapshot step | `nix/check-backup-script.nix`, `nix/checks.nix`           | both rc=0                                               |
| 6 | VM test: boot with defaults, `/health` `"status":"healthy"`, `<title>Invoice Ledger</title>`, css and js asset links, loopback-only bind, state dir ownership, backup dump + snapshot + `quick_check`, idempotent rerun, restart | `nix/vm-test.nix`                                         | written, **unproven** (see scope line)                 |
| 7 | Shared defaults for module and checks                                                                         | `nix/constants.nix`                                       | used by both                                            |

**Options the module declares** (the contract the SystemNix layer will use): `enable`, `package` (no default in a bare import), `port`, `dataDir`, `user`, `group`, `createUser`, `home`, `extraArgs`, `onFailureUnits`, and `backup.{enable, directory, createDirectory, calendar, randomizedDelaySec, retainDays, timeout, serviceDeps, timerAfter, onFailureUnits}`.

**Inventory (recipe step 1), the design the SystemNix layer must follow**

| Baseline element (live unit)                 | Owner after delegation                                   | SystemNix supplies it through                                  |
| -------------------------------------------- | -------------------------------------------------------- | -------------------------------------------------------------- |
| Description, After=network.target, StartLimit*, ConditionPathExists, User, Group, WorkingDirectory, Environment=HOME, ExecStart, Restart/RestartSec | upstream                                        | the options `user`, `group`, `home`, `dataDir`, `port`, `package`, `extraArgs` |
| harden{} MemoryMax=1G, ProtectHome=read-only, CPUQuota, ProtectKernel*, SystemCallArchitectures, CapabilityBoundingSet | SystemNix                                    | `harden { MemoryMax = "1G"; ProtectHome = "read-only"; }` + `serviceDefaults {}` + `ioTier.background` |
| ReadWritePaths=dataDir                       | upstream (mkDefault, derived from `dataDir`)              | nothing: the wrapper must pass NO ReadWritePaths into harden{} (two mkDefault lists concat and duplicate the line) |
| OnFailure                                    | upstream renders, SystemNix names the units              | `onFailureUnits = onFailure`                                   |
| Backup unit: Type, TimeoutStartSec=10min (plain, on purpose), script, RequiresMountsFor, ReadWritePaths=backup dir | upstream                                        | `backup.directory`, `backup.timeout`                            |
| Backup After/Wants = dashboard + backup-dir  | upstream renders                                          | `backup.serviceDeps`                                            |
| Backup harden incl. CapabilityBoundingSet=CAP_DAC_READ_SEARCH, serviceOneshotDefaults, ioTier | SystemNix                                  | `harden { … CapabilityBoundingSet = "CAP_DAC_READ_SEARCH"; }`  |
| Timer OnCalendar, RandomizedDelaySec, Persistent | upstream                                               | defaults                                                       |
| Timer After=mnt-pool.mount                   | upstream renders                                          | `backup.timerAfter`                                            |
| `invoices-dashboard-backup-dir` (mkPoolDirUnit, deploy.sh provisioner list, io-tier allowlist `io-tier-coverage-audit.nix:125`) | SystemNix, unchanged (unit name kept)     | `backup.createDirectory = false`                               |
| Registry entry (vHost, gatus, tile, backup freshness, monitored) | SystemNix, unchanged except the page-title condition |                                                                |
| tmpfiles `d <dataDir> 0755 lars users`       | upstream                                                  | mode becomes 0750 (delta, see f.37)                            |

**Expected deltas at parity:** the dashboard unit's `Description=` line (the vHost mention moves out), the tmpfiles mode 0755 → 0750, the package path in `ExecStart=` (new rev). The backup script should render to the same store path it has today when the inputs are unchanged.

---

## b) PARTIALLY DONE

1. **Upstream verification.** Three of four checks are green and the eval check is negative-tested. The VM test did not run.
2. **The backup script template.** Correct by a 49-of-50-line round trip; the gzip line is proven by inspection.
3. **Root allowlist.** I identified that `nix/` must be allowlisted and that `.gitleaksignore` is a pre-existing violation, then the edit was refused by the tool ("you must read the file before editing it") and I did not retry. The guard is now red for two reasons instead of one.

---

## c) NOT STARTED — the SystemNix half (the deployable part of the ask)

Zero edits in `~/projects/SystemNix`.

| Surface                                                        | Planned content                                                                                                                                                                                                                                     | State        |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ |
| `modules/nixos/services/invoices-dashboard.nix`                | `imports = [ inputs.invoices.nixosModules.default ]` + the site facts through the options (port from `lib/ports.nix`, `dataDir`/`home`/`user` = primary user, `group = "users"`, `createUser = false`, backup dir on the pool, deps, timer after, onFailure) + harden/serviceDefaults/ioTier layers + `mkPoolDirUnit` + registry entry | not written  |
| same file, gatus "Invoices dashboard page"                     | condition → `pat(*Invoice Ledger</title>*)` in the same wave as the float                                                                                                                                                                           | not written  |
| `flake.lock`                                                   | `nix flake update invoices --refresh` in a worktree, rev and narHash verified against a `--refresh` prefetch                                                                                                                                 | not done     |
| `lib/lars-packages.nix:391-401`                                | shim drop (after the upstream bake is fixed) and a corrected comment                                                                                                                                                                                 | not done     |
| Parity baseline                                                | rendered units + timer + tmpfiles + script text from a worktree at the pre-change commit                                                                                                                                                            | not captured |
| Probe-before-lock                                              | realise the go-modules FOD and the full package through SystemNix's graph at the floated rev                                                                                                                                                         | not done     |
| `docs/services/invoices-dashboard.md`, `CHANGELOG.md`, `docs/todo/upstream.md`, `TODO_LIST.md`, `docs/agents/integration-registry.md` | owning-module line, surface table (the "no consumer shim needed" package row is wrong today), vendorHash paragraph, reference-implementation list, queue row + library entry                                                                                          | not written  |
| Deploy + smoke                                                 | quiescent window, anchors, `/health`, page title, ExecStart rev equals the floated rev                                                                                                                                                              | not done     |
| Upstream docs (`AGENTS.md` Deployment section, `CHANGELOG.md`, `FEATURES.md`) | module now lives in-repo; SystemNix is a layer                                                                                                                                                                                                      | not written  |
| Upstream vendorHash                                             | `buildflow -s nix-hash-fix --fix`                                                                                                                                                                                                                     | not done     |
| Sibling `timesheets.nix` (same class, same date)               | identical extraction                                                                                                                                                                                                                                 | not touched  |

**TODO harvest:** the follow-ups in §f are deliberately NOT harvested into `TODO_LIST.md` and the domain libraries at authoring time, because the owner ordered report-then-wait. Harvest is step 0 of the resume (≤ 3 new rows; check for an existing row first).

---

## d) TOTALLY FUCKED UP! — incidents (nothing left broken)

1. **I built on a stale premise.** I wrote about 600 lines and launched a VM build before probing whether the upstream package builds at tip. It does not (stale vendorHash, known in upstream AGENTS.md). A one-minute probe would have put "fix the hash upstream" first and saved a failed VM build.
2. **The daemon committed my intermediate states within minutes**: a first `backup-db.sh` without a shebang, a check keyed `moduleEval`, a check calling `pkgs.lib.nixosSystem` (it lives on `inputs.nixpkgs.lib`), a fixture missing `lib`. At least three heuristic commits on local master do not build. Harmless for the tip, wrong for the history, and the push channel is unvalidated.
3. **A refused edit went unnoticed.** The root-allowlist edit was refused by the tool and I moved on to the next command without retrying. Result: my new `nix/` directory violates the repo's own root guard.
4. **Five bugs in my own check code, each caught only by running it:** the camelCase key; the wrong `nixosSystem` location; SQLite 3.54 rejecting double-quoted string literals; GNU grep's basic regex not treating `{32}` as an interval; `grep -qE --pattern` reading `--archive-root …` as an option (fixed with `--`).
5. **The first harness could pass silently.** I ran it as `if harness; then …`, where bash ignores errexit for the whole function body, so only the last line's status counted. Restructured to a plain call between `set +e` and `set -e`, with a traced subshell.
6. **Log truncation interplay** in that harness (an inner `> log` against an outer redirect) could have hidden the real failure line; fixed with a separate `run.log`.
7. **Ordering.** About 70 minutes went into the mandated reading and the upstream module; the SystemNix half has zero lines. The reading was required (integration-registry, nix-flakes, harden, two precedents), but the cheapest decisive probes (live ExecStart rev, title contract, upstream build at tip) came late.
8. **Load.** The host sat at io PSI some 51 % / full 27 %, load 84–112, with six foreign nix builds running (one toplevel keep-going, one foreign VM test). I still launched a VM build. It died early, so the cost was small, but it was not a considered decision.
9. **Evidence gap I left in place:** the round trip used a stand-in path for `@gzip@` and I did not re-run it with the real one.

---

## e) WHAT WE SHOULD IMPROVE! — self-review

**1. What did you forget?**
- The retry on the root allowlist; the upstream docs; the push dependency; the stale upstream hash; the gatus title contract until I stumbled on it; the parity baseline; every SystemNix line; the TODO harvest; re-running the round trip with the real gzip path.

**2. What is something stupid that we do anyway?**
- A consumer-side shim comment that attributes a stale hash to a root-nixpkgs float without ever building the upstream flake at tip. The proof cost one build.
- SystemNix pins upstream page titles in gatus conditions that no upstream test owns. The title check is a coupling with no contract; `/health` (`"status":"healthy"`, pinned by `server_health_test.go`) is the shape that works.
- Intermediate daemon commits of half-written files become history within a minute.

**3. What could you have done better?**
- Probe first: live ExecStart rev, upstream build at tip, title contract. Then write.
- Develop multi-file additions in a worktree under `~/.cache/<topic>/` and copy them in when green, so the daemon never commits a non-building intermediate.
- Read the tool result of every edit before the next command.

**4. What could you still improve?** — see §f.

**5. Did you lie to you?**
- Not knowingly. One correction: I planned the backup-script harness as `if harness` believing errexit would abort the body. It would not have.

**6. How can we be less stupid?**
- Treat every "shim because upstream is stale under our graph" claim as unproven until the upstream flake has been built at the tip under its own lock.
- Keep SystemNix functional checks on contracts an upstream test pins.

**7. Ghost systems?**
- The SystemNix shim comments (two surfaces) describe a mechanism that is not the real one.
- The "Invoices dashboard page" check asserts a title that no longer exists at the tip: green today, false at the next deploy.

**8. Scope creep trap?**
- `backup.retainDays`, `backup.timeout` and `extraArgs` have no consumer today. They are small and documented; a YAGNI review belongs to the first second consumer.
- I planned to allowlist `.gitleaksignore` (pre-existing red, in SystemNix's queue already) while editing the same script. Not done; it is a one-line fix in a file I must touch anyway.

**9. Did we remove something useful?**
- No SystemNix code was removed. The removal targets are named in §f.9 (shim on two surfaces, ~190 lines of module body).

**10. Split brains created?**
- `nix/constants.nix` (defaults) and the module share one source by construction.
- The dashboard page title is asserted in three places now (upstream tests, my VM test, and SystemNix's gatus condition once fixed). All three name the string upstream pins.
- Until the SystemNix module delegates, the old hand-rolled module and the new upstream module describe the same units: two sources of truth for a few more hours. This is why the delegation should land in one wave.

**11. Tests?**
- Upstream: 3 check derivations green, 1 negative leg proven, 1 VM test written and unproven. No `-race` relevance (no Go changed). The negative leg for the eval check mutated one line only.
- SystemNix: nothing run.

**12. Inherited claims re-verified?**
- Two, both corrected: the vendorHash attribution (finding 3) and the page-title contract (finding 2). One confirmed: the backup script's bytes (49 of 50 lines by diff).

---

## f) Next things to get done (impact-ordered; the first five fit the queue's 3-rows-per-session cap with two already queued upstream)

**Unblock the upstream half**

1. `~/projects/invoices`: `buildflow -s nix-hash-fix --fix` → the true hash (`/OE8Z7by…`, first-hand at `ede43fe9`) into `flake.nix`; prove `nix build .#packages.x86_64-linux.default` green.
2. `scripts/check-root-allowlist.sh`: add `nix` to `allowed_dirs` and `.gitleaksignore` to `allowed_files`; run the guard to rc=0.
3. Re-run `nix build .#checks.x86_64-linux.module-vm -L`; read the result (the VM assertions are unproven).
4. Full `nix flake check` and a plain `buildflow` on the final tree; read the findings (shellcheck must see `nix/backup-db.sh`).
5. Upstream docs: `AGENTS.md` Deployment section, `CHANGELOG.md` [Unreleased] → Added, a `FEATURES.md` row under Platform & Utilities.

**Unblock SystemNix**

6. Confirm the push landed (`git -C ~/projects/invoices log --oneline origin/master..HEAD` is empty) before ANY SystemNix edit: the input reads origin, and consumer edits must never reference options that exist only locally.
7. Harvest this section's direct follow-ups into `TODO_LIST.md` + `docs/todo/upstream.md` (≤ 3 new rows, check for an existing row first).
8. Parity baseline from a worktree at the pre-change SystemNix commit: the three units, the timer, the tmpfiles rule, the script text (live script already saved at `~/.cache/invoices-extraction/baseline-backup-script.sh`).
9. Float the lock in that worktree: `nix flake update invoices --refresh`; verify rev and narHash against `nix flake prefetch --json --refresh`; then probe-before-lock: realise the FOD and the full package through SystemNix's graph.
10. Drop the shim from BOTH SystemNix surfaces (`lib/lars-packages.nix:399-401`, module `package` default) once the upstream bake reproduces under SystemNix's graph (drop-protocol: got equals the upstream bake); correct both comments.
11. Rewrite `modules/nixos/services/invoices-dashboard.nix` as the layer (table in §a); `nix-instantiate --parse` in the same tool batch as the edit.
12. Fix the gatus page condition to the title upstream pins (same wave as the float).
13. Parity diff: every hunk byte-identical or one of the three documented deltas.
14. Targeted evo-x2 toplevel eval in the worktree (`nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath`), which runs the host-level audits.
15. `nix fmt -- <paths> --fail-on-change` on the module and the docs.
16. Port atomically into the shared tree after a `git rev-parse HEAD` + `git status --short` pin; re-run the evo-x2 eval there at a quiescent moment.
17. Confirm `checks.registry-matrix-drift` stays green (entry shape unchanged).
18. SystemNix docs: runbook (owning-module line, package row, vendorHash paragraph, title contract), `CHANGELOG.md`, `docs/todo/upstream.md`, `docs/agents/integration-registry.md` reference list, `docs/agents/data-ownership.md` note.

**Deploy and prove**

19. Read why the foreign 03:47 deploy was BLOCKED (pre-deploy exit 1) before firing another; then `scripts/deploy-when-quiescent.sh --fire` at a clean 4×60s window.
20. Anchor by generation number and boot-entry anchor; smoke: `/health` 200 + `"status":"healthy"`, `/` title `Invoice Ledger`, `ExecStart` rev equals the floated rev.
21. Owner-facing proof: open `https://invoices.home.lan` and compare against the repo page (ledger, invoice detail, charts).
22. Next morning: `journalctl -u invoices-dashboard-backup` shows `wrote …` from the upstream-rendered script.

**Debt and decisions**

23. Extract `timesheets.nix` the same way (the 04:33 report's item 35, other half).
24. Re-run the template round trip with the real gzip path for a full byte proof.
25. Confirm through `buildflow -s shellcheck` that the step lints `nix/*.sh`.
26. Decide whether `module-vm` stays inside `nix flake check` (it builds the package and a VM closure under the repo's own nixpkgs); measure, split out if it dominates.
27. Decision row: a nix job in invoices `ci.yml` for the three cheap checks (fleet CI is billing-dead per the probe; may be moot).
28. Decision row: export the health path and page contract as upstream constants so consumer checks stop hard-coding markup.
29. YAGNI review of `retainDays`, `timeout`, `extraArgs` at the first second consumer.
30. Record in invoices `AGENTS.md`: develop multi-file additions in a worktree; the daemon commits intermediates within a minute.
31. Record in `docs/agents/nix-flakes.md`: a consumer shim can carry the TRUE hash while the upstream bake is stale; build the upstream flake at tip before attributing a re-stale to a root-nixpkgs float.
32. Grep SystemNix for other consumers of `/home/lars/invoices` before accepting the tmpfiles mode delta 0755 → 0750.
33. Verify `lib/lock-audit.nix` stays quiet after the float (invoices keeps its three infra follows).
34. Verify `deploy.sh`'s provisioner restart of `invoices-dashboard-backup-dir` still fires after the switch.
35. Annotate `docs/status/2026-11-28_04-33_…` §f.35 as half done once this lands.
36. Sweep the sibling windows (`timesheets`, `journal`) for gatus page conditions that pin titles no upstream test owns.
37. `--archive-root` (staged dunning letters) is not set on evo-x2 today; the module now exposes `extraArgs` for it if wanted (decision, not a task).
38. The reports-system SystemNix half from the 04:33 report is still not started (not this session's scope; listed so it is not lost).
39. Full `nix flake check --no-build --all-systems` before the deploy, in a calm window only (~20 GB RSS).
40. Owner: CI auth for private inputs is red fleet-wide (probe: 3 of 9 workflows green); the new module needs no new key.

---

## g) Questions I cannot answer myself

1. **Push.** The invoices commits are local (13 ahead of origin at 06:10). Nothing in SystemNix can move until they reach GitHub. May I push `~/projects/invoices` myself, or do I wait for the daemon or for you?
2. **Deploy.** Once the SystemNix tree is eval-green and parity-proven: do I fire the deploy in this session (the host was at io PSI ~51 % and a foreign deploy was blocked at 04:08), or do you deploy?
