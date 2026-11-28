# reports-system integration: upstream gates green (VM test fixed, flake check passed), SystemNix layer committed and eval green; deploy NOT fired

**Date:** 2026-11-28 11:33 CET (this session: 04:52 to 06:11 and 09:09 to 11:33; paused in between on the owner's stop order)
**Repos:** SystemNix @ `44a19b11a` (tree clean at report time); `~/projects/testing` @ `53be7cd` + the ROADMAP edit (daemon commit pending), `origin/master` = `ce4abf1`
**Previous report:** [2026-11-28_04-33 reports-system upstream-first integration, upstream half landed, SystemNix half not started](./2026-11-28_04-33_reports-system-upstream-first-integration-upstream-half-landed-systemnix-half-not-started-status.md)
**State in one line:** everything for the integration is written, committed and eval-proven on both repos; the switch is not fired, so nothing is live yet (generation 1033, no `reports-system` unit on the host).
**Evidence directory:** `~/.cache/reports-system-integration/` (every log named below lives there)

---

## §0 The three questions

### What I forgot

1. **The report the owner asked for at ~06:10.** I gathered state and my turn ended; this file is that report, five hours late.
2. **The flake input, before the module that references it.** I staged `modules/nixos/services/reports-system.nix` at 06:08 so eval could see it, while `inputs.reports-system` did not exist. Every evo-x2 eval of every session died on `attribute 'reports-system' missing` until another session neutralised the file at 08:59 and registered the input at 09:08 (§d.1).
3. **The pre-deploy battery on the final tree.** I proved eval (rc=0) and rendered units; I did not run `scripts/pre-deploy-check.sh`, nor the sops pre-deploy gate, on the tree that would be deployed.
4. **Formatting and lint of my SystemNix files.** No `nix fmt -- <paths>`, no deadnix/statix/lint-static, no `nix flake check --no-build --all-systems` (darwin unproven).
5. **A proper commit message for either repo.** I never ran `git commit`; both repos carry this work as daemon "chore: auto-commit N changed file(s) (heuristic)" commits.
6. **The forward bump of the SystemNix lock.** The lock sits at `ce4abf1`, the last PUSHED upstream rev; the VM-test fix and two whitespace fixes are three unpushed commits on top (same Go behaviour, the package path is unchanged in content terms only by the whitespace line in `cmd/server/main.go`).
7. **Review depth of generated docs.** I read the runbook and corrected it; the CHANGELOG entry, the two todo rows, the data-ownership row and the sops skill row I checked by grep only.

### What I could have done better

- **Re-read before every edit.** At 09:08 I applied a scripted edit to `flake.nix` and `lib/lock-audit.nix` from anchors read at ~05:30. Another session had already registered the input. My parse gate caught the duplicate attribute and restored both files, so nothing broke, but the gate should not have been the thing that saved the tree.
- **One VM cycle wasted on an unverified assumption.** My first rewrite of the VM test reused one cookie jar for both registrations. Registration signs the new account in and issues the `csrf_token` cookie, so the second POST hit the CSRF gate (`csrf_token_invalid`) instead of the bootstrap gate. A 30-second local replay would have shown it; I wrote that replay only after the cycle failed.
- **Read the contradicting result first.** My first local replay printed `REGISTRATION_CLOSED` for that same request and I could not explain it; I should have stopped on the contradiction instead of running on.
- **Time per verification.** Under the host load of this morning (load 18 to 112, io PSI 27 to 47 percent) each evo-x2 eval took 2 to 10 minutes. I ran four full evals; three of them died on breakage that was not mine (§a.6). A single `nix eval` of the rendered units answered the questions I actually had.

### What I can still improve (concrete)

1. Fire the deploy at a quiescent window and carry it through the verification list in §f.
2. Run `nix fmt -- <my files> --fail-on-change`, deadnix, statix, lint-static, and `nix flake check --no-build --all-systems` from a worktree.
3. Forward-bump the lock to the final upstream rev once the push daemon publishes it, after a green `checks.module-vm` at that rev.
4. Write the two lessons of §e.1 and §e.2 into `AGENTS.md` and `docs/agents/nix-flakes.md`.
5. Give the remaining generated docs a real read (CHANGELOG entry, todo rows, data-ownership row).

---

## §a FULLY DONE

### a.1 Upstream root cause of the red VM test (found by the test, fixed in Go)

- Failure: the unit crash-looped with `session secret must be at least 32 characters` although the environment file carried a 40-character secret (`module-vm.log`).
- Cause: Viper reads an environment variable into `Unmarshal` only for a key it knows (a default, a config-file entry or an explicit binding). `security.session.secret` and `security.jwt.secret` carry none on purpose, so an environment-only deployment started with EMPTY secrets. With a config file the YAML's empty `secret: ""` entry made the key known, which is why development never showed it.
- Fix: `BindEnv` for both keys in `load()` (`internal/config/config.go`), constants `jwtSecretKey` / `sessionSecretKey`.
- Proof: `TestLoadReadsTheSecretsFromTheEnvironment`; mutation run with the binding removed fails with "session secret is 0 characters" (`fix-bindenv-test.log`), restored byte-identical.

### a.2 Upstream hardening that rode the same finding

- `cqrs.driver = memory` is refused outside development (`validateConfig`): the memory driver forgets every account at restart, and none of the shipped YAML files selected a durable driver. `configs/config.production.yaml` and `configs/config.staging.yaml` now ship `cqrs.driver: sqlite` + `dsn: ./cqrs.db`. Tests: `TestLoadRefusesTheMemoryDriverOutsideDevelopment`, one new case in `TestValidateConfigRejectsNonsense`.
- The `CQRS composition root built driver=%s dsn=%s` log line used printf verbs with a key-value logger and printed a literal `%s`; it now passes `driver` and `dsn` as pairs (`internal/container/cqrs.go`). The VM journal shows the corrected line.

### a.3 Upstream VM test (`nix/vm-test.nix`) now models the real auth contract

- Anonymous POSTs pass the CSRF gate; the `csrf_token` cookie is issued with a session, never by the login page.
- First registration: 201, `"role":"admin"`, and the response signs the account in (`reports-session` cookie in the jar).
- Second registration from a session-less client: 403 `REGISTRATION_CLOSED`; `/auth/register` answers 303.
- Login 200, demo password 401, logout without `X-CSRF-Token` 403 `csrf_token_invalid`, with the header 200.
- Probes, embedded assets, loopback-only bind, state ownership, restart persistence (unchanged, passing).
- Local replay against the nix-built package confirmed every step before the VM run (`local-flow2.log`); the same flow against the go-built binary (`local-flow3.log`).

### a.4 Upstream gates

- `nix flake check -L`: **all checks passed** (`flake-check.log`): `module-eval`, `module-vm` (VM ran 26.6 s), the test check (go test in the build's check phase, 1 min 20 s), the package build.
- `nix run .#lint`: 519 findings (`lint.log`), against the 531 baseline of 2026-11-27. Two `wsl_v5` whitespace findings in files of this work (`cmd/server/main.go`, `internal/handlers/auth_handler_identity_test.go`) fixed; a targeted re-run over `cmd/server`, `internal/handlers`, `internal/config`, `internal/container` reports none (`lint-targeted.log`). The full count after the fix was not re-measured.
- `buildflow -s nix-fmt --fix` on the Nix files: clean (`nixfmt3.log`).

### a.5 Upstream docs (zai subagent `glm-5.3-flash`, reviewed and corrected by me)

- `CHANGELOG.md` `[Unreleased]`: Added / Changed / Fixed for items a.1 to a.3 and the previous session's work.
- `ROADMAP.md` "Deployment story": annotated as partly resolved; corrected by me to name the SystemNix layer that now exists.
- `TODO_LIST.md`: new section "P1 - Deployment (2026-11-28)" with three rows (OTLP exporter behind the dead `tracing.endpoint` key, red pre-commit BuildFlow gate, demo change-password dead end).
- `AGENTS.md`: four gotchas (Viper env binding rule, charm.land/log key-value pairs, memory-driver refusal, NixOS module contract) and the two checks in the checks table.
- `FEATURES.md`, `README.md` (new "NixOS" section).

### a.6 SystemNix layer (all committed by the daemon; full eval green)

| Piece | Where | Commit |
| --- | --- | --- |
| Port `reports-system = 8113` | `lib/ports.nix` | `7a6500cd0` |
| DNS name `reports` | `platforms/common/dns-local.nix` | `b08489cbf` |
| Flake input `reports-system` (git+ssh, follows flake-parts and root go-nix-helpers), locked at `ce4abf1`, lock-audit row | `flake.nix`, `flake.lock`, `lib/lock-audit.nix` | `a5142e25a` (written by the deploy session that my 06:08 staging had blocked) |
| Service layer: port, sops template `reports-system-env` (root 0400), `harden` + `serviceDefaults` + `ioTier`, `onFailure`, backup pair (runs as the service user, both stores, 14 days), timer 03:25, registry entry (protected vHost, 3 Gatus checks, tile, backup freshness), catalog entry | `modules/nixos/services/reports-system.nix` | `ff84ab102`, `e90c42f1d` |
| Secrets file, two random 64-character values, decrypt verified by length only, force-added | `platforms/nixos/secrets/reports-system.yaml` | `302b7981e` |
| Enabled; service matrix regenerated (byte-identical to the generated artifact) | `platforms/nixos/system/configuration.nix`, `docs/agents/integration-registry.md` | `d7b483887` |
| Runbook, data-ownership row, CHANGELOG entry, two todo rows (CI deploy key `[blocked:user]`, pool defaults `[ready]`), sops skill row + new-file recipe | `docs/services/reports-system.md`, `docs/agents/data-ownership.md`, `CHANGELOG.md`, `docs/todo/services.md`, `.crush/skills/sops-secret-management/SKILL.md` | `af6a78233`, `f97fd95f4`, `51e5471b4`, `f023f568c`, `f0f9f9f08` |

Proof:
- **Full evo-x2 toplevel eval rc=0** at `44a19b11a` (`sn-eval3.log`): `/nix/store/2189dy135skafpsjsz9kcwbf83h6617f-nixos-system-evo-x2-26.11.20261124.58d0d3e.drv`. This forces `config.assertions`, so every eval audit passed with the service enabled (port registry, systemd shape, Gatus coverage, io tier, sops key audit, lock audit, tile coverage).
- **Rendered units** (`probe-units.json`): service = package `/nix/store/pb0k0r20...-reports-system-0.26.0` (the same path `nix build .#default` gives at `ce4abf1`), `User=reports-system`, `EnvironmentFile=/run/secrets/rendered/reports-system-env` (root, 0400, restart on change), `REPORTS_SERVER_PORT=8113`, `ProtectSystem=strict`, `MemoryMax=1G`, `Restart=always`, io tier best-effort 6, `onFailure`; backup oneshot as the service user with `RequiresMountsFor` on the pool dir; backup-dir unit with the chown caps; timer `03:25` + 5 min jitter, persistent; registry entry and catalog entry as designed.
- **todo gate**: `OK: TODO queue/library structure clean` (`todo-gate.log`; the 95 unharvested-reports warning is the standing backlog).

### a.7 A foreign eval break fixed on sight

- Every evo-x2 eval (and the 09:33 deploy of another session, `2026-11-28_09-33-12.log` line 265) died with `cannot coerce a list to a string: [ ]` inside `modules/nixos/desktop/session-boot-audit.nix`.
- Cause: `splitTokens` filtered `lib.split` output with `t != ""`; `lib.split` interleaves the separators as EMPTY LISTS, which that filter keeps. The first user unit whose directive line carried two tokens crashed the audit. Latent since 2026-08-18.
- Fix: filter `builtins.isString t && t != ""` (`c8bb36eba`); proven on the expression itself (`["a",[],"b"]` before, `["a","b"]` after).
- Regression leg `multi-token-directive-line-not-caught` in `tests/test-session-boot-audit.nix` (`057ac28cc`); `nix build .#checks.x86_64-linux.session-boot-audit` rc=0 (`bootaudit-check.log`).

---

## §b PARTIALLY DONE

1. **The integration itself is not live.** Written, committed, eval-proven; not built to a toplevel, not switched. Generation is still 1033.
2. **Pre-deploy proof.** No `pre-deploy-check.sh` run on the final tree (the 09:33 run of another session predates the boot-audit fix and was refused: toplevel dry-run red, sops manifest red on an ai-meter manifest string).
3. **Lock currency.** SystemNix locks `ce4abf1`; upstream HEAD is three unpushed commits ahead (`6dbcda8` VM test, `53be7cd` whitespace, ROADMAP edit). The Go behaviour is identical; upstream's own `checks.module-vm` is red at `ce4abf1` and green from `6dbcda8`.
4. **Upstream lint.** 519 findings of the standing debt classes remain (varnamelen 152, noctx 73, gofumpt 58, exhaustruct 42).
5. **Generated docs.** Runbook read and corrected (restore procedure now removes stale WAL sidecars and requires one backup date for both stores; the registration bullet names the `registration` option). The other four surfaces were checked by grep.
6. **Service matrix.** The regeneration also re-stamped two rows changed by other sessions (llama-rag 3 checks, pim-sync service row). Correct per the generated-truth rule, not my change.

---

## §c NOT STARTED

1. Deploy, anchor check (profile generation and boot entry), post-deploy smoke.
2. First-run administrator registration (owner, right after the switch; until then the admin account is claimable by anyone who reaches the app).
3. First backup run and its verification.
4. CI deploy key for the private input (owner step; row exists).
5. Lock forward bump to the final upstream rev.
6. `nix fmt`, deadnix, statix, lint-static over my SystemNix files; `nix flake check --no-build --all-systems`.
7. Upstream: pool defaults (row exists), OTLP exporter (row exists), BuildFlow gate repair (row exists), a brand mark for the tile (generic `text-document.png` today).
8. Invoices-dashboard and timesheets module extraction: not this session's work (the 06:10 report of another session says the invoices module is written upstream, SystemNix half open).

---

## §d TOTALLY FUCKED UP

1. **I broke every evo-x2 eval on the host for about 50 minutes.** Mechanism: `git add` of a module that references a non-existent input at 06:08. Blast radius: every session's evals, the 08:07 deploy (the other session's wording: "broke EVERY evo-x2 eval for every session plus the 08:07 deploy"), and it is one of the two red gates of the 09:33 deploy. The deploy session spent its time neutralising my file and registering the input instead of deploying. I had read the tracked-files trap that morning and applied it in the wrong direction.
2. **I edited two shared eval-critical files from stale reads** (§0). Saved by a parse gate, not by discipline.
3. **I did not deliver the 06:10 report.**
4. **Seven em dashes stayed in the new module** after a partial cleanup (the house rule bans them in source); fixed at 09:36.
5. **Three VM cycles** were spent where one local replay would have sufficed (two of them before this session, on the same unverified CSRF assumption).

---

## §e WHAT WE SHOULD IMPROVE

1. **Order of operations for a new module (doctrine candidate).** flake input first, lock second, `git add` of the module last; or keep the module body behind `lib.optionalAttrs (inputs ? <name>)` until the input is registered (the neutral shape the deploy session used). Candidate `AGENTS.md` line under "Concurrent agent sessions share this tree".
2. **Text-walking audits need a multi-token fixture.** `session-boot-audit` crashed on its first two-token directive line after three months. The same `t != ""` idiom may exist elsewhere: worth one `rg 'filter \(.*!= ""\)' ' over `lib/` and `modules/`.
3. **Local replay before VM cycles.** A 30-second curl flow against the built package found in one run what cost 15 minutes per VM cycle. Candidate: extend upstream `scripts/smoke.sh` with the auth flow, or add `scripts/smoke-auth.sh`.
4. **Deploy sequencing with five or more sessions on one tree.** Two deploys this morning were lost to breakage from sessions that were not deploying. The `deploy-when-quiescent.sh` gate cannot see eval breakage; a cheap `nix eval ...toplevel.drvPath` inside deploy.sh before the battery would fail in two minutes instead of seven.
5. **Upstream commit hygiene.** Every commit of this work is a daemon heuristic commit. A properly-messaged commit per logical change needs a session that commits before the daemon does (pathspec commit right after each edit batch).
6. **Upstream push cadence.** Three commits have been unpushed since 09:19; the SystemNix lock cannot move past `ce4abf1` until they are.

---

## §f Up to 50 things to get done next

**Close-out of this integration (in order)**

1. Fire the deploy at a quiescent window (`bash scripts/deploy-when-quiescent.sh --fire`), then confirm the anchor by generation number and `✓ Boot-entry anchored` in the deploy log.
2. Post-deploy smoke: `reports-system.service` active, journal clean, `/live` `/ready` `/version` 200 on 8113, `https://reports.home.lan` answers, three Gatus checks green, the Reports tile on the dashboard.
3. Owner: register the administrator account at `https://reports.home.lan` immediately after the switch.
4. Run the first backup by hand (`reports-system-backup.service`), confirm both files in `/mnt/pool/backups/reports-system` and `quick_check` on a copy.
5. Forward-bump the lock: after the push, `nix build 'git+ssh://git@github.com/LarsArtmann/testing?ref=<rev>#checks.x86_64-linux.module-vm'` green, then `nix flake update reports-system`, verify the lock rev moved.
6. Re-word the `lib/lock-audit.nix` `reports-system.nixpkgs` row with the VM-test evidence at the final rev.
7. `nix fmt -- <my files> --fail-on-change`; deadnix, statix, lint-static over the same files.
8. `nix flake check --no-build --all-systems` from a worktree.
9. `bash scripts/pre-deploy-check.sh --section-11-only` once, to see the reports-system FODs in the realised set.

**Docs and memory**

10. Write §e.1 and §e.2 into `AGENTS.md` and `docs/agents/nix-flakes.md`.
11. Read the CHANGELOG entry, the two todo rows, the data-ownership row and the sops skill row line by line; correct what grep could not show.
12. Add `reports-system` to the reference list in `docs/agents/integration-registry.md` ("Consuming LarsArtmann Flakes") if the house list wants it.
13. Tick the two `docs/todo/services.md` rows when their asks are met (deploy key, pool defaults).

**Upstream (`~/projects/testing`)**

14. Re-run `nix flake check -L` and `nix run .#lint` at the final rev (the whitespace fixes came after my green run); record the new lint count in the TODO row that quotes 531.
15. Pool defaults: `database.max_open_conns` / `max_idle_conns` / `conn_max_lifetime` have no Viper defaults, so an environment-only deployment logs `max_open_conns=0 max_idle_conns=0`; give them defaults or bindings, with a test that keeps the `:memory:` test databases working.
16. OTLP trace exporter behind `tracing.endpoint`.
17. Repair the BuildFlow pre-commit findings so commits stop bypassing the hook.
18. A brand mark (favicon or logo) and a `brandAssets` passthru, so the SystemNix tile stops borrowing a generic glyph (timesheets precedent).
19. Decide the version bump for the release that carries the NixOS module (CHANGELOG is under `[Unreleased]`).
20. Add the auth flow to the smoke script (§e.3).

**Owner decisions**

21. Registration policy: keep `bootstrap` (first account is the admin, then closed) or open registration on the LAN.
22. Whether external clients should keep the double login (oauth2-proxy, then the app) or the app should adopt Pocket ID.
23. CI deploy key for `LarsArtmann/testing` (bundle 2).
24. invoices-dashboard and timesheets: finish their extraction in the line of the 06:10 report, or park it.

**Noticed, foreign, left alone**

25. `caddy: dns-local subdomain(s) with no vHost and no registry entry (ghost entries): nsfw` warns on every eval (`sn-eval3.log`).
26. The 95 unharvested §f-bearing reports (`todo-gate.log`), two of them from this morning.
27. `ai-meter.nix`, `tests/test-ai-meter.nix` and the monitor365 delegation changed under this tree while I worked; the monitor365 delegation briefly produced a duplicate option declaration (`enableClipboard`) that failed my 10:18 eval and was gone by 11:33.

---

## §g Three questions I cannot answer myself

1. **Registration policy:** keep the default I shipped (bootstrap: the first account becomes the administrator and registration closes, so you must register right after the deploy), or should registration be open on the LAN (everyone with access gets a viewer account)?
2. **The switch:** do you fire `nix run .#deploy` yourself so you can register the admin account in the same minute, or do I fire it at the next quiescent window and you register afterwards (the account is claimable from the LAN until it exists)?
3. **Scope after that:** should I also carry the invoices-dashboard and timesheets extraction to its SystemNix half (another session wrote the invoices module upstream, per the 06:10 report), or leave it with that session?

---

## §h Harvest log (§f, at authoring time)

- §f.15 (pool defaults) and §f.23 (CI deploy key): HARVESTED as rows in `docs/todo/services.md` (`51e5471b4`), Source pointing at the 04:33 report.
- §f.14, §f.16, §f.17, §f.18: upstream TODO_LIST / ROADMAP already carry the OTLP, gate and release rows; §f.18 and §f.20 are deliberately not harvested here (they belong in the upstream `TODO_LIST.md`, queue budget of this session spent).
- §f.1 to §f.9: the in-flight close-out of this integration, executed on the owner's go, not backlog rows.
- §f.10 to §f.12: deliberately not harvested at authoring time (two one-line lessons and one optional list entry); they are the first edits of the next session on this line.
- §g: owner questions, not rows.
