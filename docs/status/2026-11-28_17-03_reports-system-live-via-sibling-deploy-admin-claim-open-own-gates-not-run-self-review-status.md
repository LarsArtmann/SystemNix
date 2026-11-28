# Status 2026-11-28 17:03: reports-system is live (carried by another session's deploy), the first account is still unclaimed, my own gates never ran; self-review

**Date:** 2026-11-28 17:03 CET · **Author:** Crush session (glm-5.4) · **Trigger:** owner order (full status, self-review, then wait)
**Task:** "smartly integrate `~/projects/testing` (product reports-system) into SystemNix", upstream-first. Owner: "Get it all done", later "get is done", twice "status, then WAIT".
**Predecessor:** `docs/status/2026-11-28_11-33_reports-system-upstream-gates-green-systemnix-layer-committed-eval-green-deploy-not-fired-status.md`
**This session (resume, 14:11 to 17:03):** read-only probes, one todo-list restore, this report. No file edited, no service touched, no deploy fired, no subagent dispatched.

## Act now

**Register the administrator account at `https://reports.home.lan/auth/register`.**

- The page answers `200` with `<title>Create Account - Reports System</title>` (loopback GET, 17:00). No account exists.
- The live unit runs `REPORTS_SECURITY_REGISTRATION=auto` with `REPORTS_SERVER_ENVIRONMENT=production`, which the upstream option documents as bootstrap outside development: "admits exactly one account, the initial administrator, and closes once it exists". The first form submission from any device on the LAN becomes the administrator.
- The window opened at 16:24:33, when another session's deploy started the unit. It is open for 39 minutes at report time.
- Contract, not re-verified live: once the account exists, `GET /auth/register` answers `303` (the upstream VM test asserts it).
- If you are not at a keyboard: say so and I stop `reports-system.service`. A stop by command holds until the next activation; nobody uses the service yet.

## Scope line

**Repos at report time**

| Repo                   | HEAD (short) | Tree                                                                                                          |
| ---------------------- | ------------ | ------------------------------------------------------------------------------------------------------------- |
| `~/projects/SystemNix` | `bbff692f9`  | dirty from other sessions: `modules/nixos/services/signoz.nix`, `scripts/deploy.sh` (both 16:54), two untracked sibling reports |
| `~/projects/testing`   | `d3305c7`    | clean, equal to `origin/master`                                                                               |
| `~/projects/invoices`  | `1da590c5`  | ahead 2, `internal/paylinks/token.go` edited 16:51 (that line is active)                                     |

**Labels used below**

- **[L] live:** run by this session between 14:11 and 17:03.
- **[A] artifact:** read from a log under `~/.cache/reports-system-integration/` (written 03:19 to 10:40, not re-run).
- **[I] inherited:** quoted from the 11:33 report, the handoff summary or sibling reports, not re-run.

**Verified [L], by command**

- `scripts/session-start-probe.sh` (14:11, rc=0): CI 3 of 9 workflows green, 5 red, 1 never ran; open rows 3557 (ready 2428); 4 failed units.
- Host: boot `56ba232e`, uptime 22,205 s; `/run/current-system` and the profile (17:00); `ss -ltnp`; `ps -p 952010`; `journalctl -u reports-system.service` and `-u reports-system-backup-dir.service`; the unit files in `/etc/systemd/system/`; the unit's cgroup `memory.current` and `memory.events`.
- HTTP: loopback GETs on 8113 for `/live`, `/ready`, `/version`, `/`, `/auth/register`; `https://reports.home.lan/{ready,auth/register}` through `openssl s_client` to 192.168.1.150:443 with SNI; `getent hosts reports.home.lan`.
- Git: `rev-parse`, `status`, `log --name-only` (testing, 9 commits), `diff --stat ce4abf1..d3305c7`; lock revs of `reports-system` and `invoices` in `flake.lock`.
- Invoices: `merge-base --is-ancestor b4f32117 8706f1fc` (true at 14:1x), `git grep -c 'Invoice Dashboard'` on the then-locked rev (0 in `internal/dashboard`).
- Deploy log `/var/log/systemnix-deploys/2026-11-28_16-01-45.log` (824 lines at 16:56; grep for my unit and secret names).
- Skill file: `readlink -f`, `git check-ignore`, `git ls-files .crush` (0), `git -C /mnt/hot/crush/SystemNix rev-parse` (not a repository).

**Not verified, and why**

- Every number from the earlier run that I did not re-run: upstream test and lint counts, the mutation proof, the evo-x2 toplevel eval, the session-boot-audit check. They are [A] or [I].
- The carrying deploy's outcome: `deploy exited` and `✓ Boot-entry anchored` lines not read (the deploy was still running at 17:00:54).
- Gatus: rendered checks and their results not read (config path not found from `ExecStart`); `gatus.service` started 16:49:40 after two restarts. The Reports tile was not looked at.
- Whether `/metrics` (the journal says `metrics_enabled=true metrics_path=/metrics`) is scraped.
- The backup directory's content (permission denied for an unprivileged agent; only the directory's owner and mode were read).
- The manifest: only `ports["reports-system"] = 8113` was read; other entries not.
- Whether upstream's VM test is red at `ce4abf1`: supported by `module-vm3.log` (05:52, rc=1, the test file of `c9c3100`, which is the version inside `ce4abf1`); not re-run at that revision.
- Whether the testing repo has a Markdown formatter; whether the three SystemNix gate steps (`nix fmt`, lint, `--all-systems` check) would pass on my files. None was run.
- `busctl`: four reads failed (see d.9). The calm gate's state rests on the probe's failed-units list (14:11) and the journal (failed 11:47:37, no later start through 16:2x), not on a busctl read.
- CI, the storm and freeze #66: not my work; see the sibling reports of 14:10, 16:40 and 16:52.

## TL;DR

1. **reports-system runs on evo-x2 since 16:24:33**, built from `ce4abf1`, store path `pb0k0r20…-reports-system-0.26.0`, loopback only, healthy on `/live` `/ready` `/version`, reachable as `https://reports.home.lan`.
2. **It went live through another session's deploy** (log 16-01-45, activation from 16:23), not through mine. I never fired one.
3. **The administrator account is unclaimed and open to the LAN** (Act now).
4. **None of my own gates ran before it went live:** no `nix fmt`, no lint, no `--all-systems` check, no battery run by me. The carrying deploy gated the tree, not me.
5. **Upstream is green and pushed** at a tree between `6dbcda8` and `53be7cd` (`flake-check.log` 09:26). SystemNix locks `ce4abf1`, where the VM test was still red. Same Go behaviour; the lock bump is outstanding.
6. **Backup is wired, never run** (timer 03:25); no restore drill exists.
7. **The invoices question from 14:2x is closed by facts:** the other session landed the thin layer at 14:27 and 14:44 and is still active.
8. **Self-review in one line each:** forgot that any deploy carries my module and that a backup needs a restore drill; could have done the input before the module and the gates at write time; can still improve the module so a safe go-live never depends on the deployer knowing something.

## a) FULLY DONE

### Upstream (`~/projects/testing`, all on `origin/master` = `d3305c7` [L])

| # | What                                                                                                      | Where                                                          | Proof                                                                                                                                                                                          | Label      |
| - | --------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| 1 | Both secrets are read from the environment (`BindEnv` for `security.session.secret` and `security.jwt.secret`) | `internal/config/config.go`, test `TestLoadReadsTheSecretsFromTheEnvironment` | `fix-bindenv-test.log` (05:04): binding removed, then "RESTORED identical", `ok reports-system/internal/config`. Live: the unit starts from an `EnvironmentFile` and refuses empty secrets         | A, L       |
| 2 | Memory CQRS driver refused outside development; production and staging YAML carry `cqrs.driver: sqlite`   | `internal/config/config.go`, `configs/config.{production,staging}.yaml` | Live journal 16:24: `CQRS composition root built driver=sqlite dsn=/var/lib/reports-system/cqrs.db`                                                                                            | L          |
| 3 | Composition-root log line in key=value form                                                               | `internal/container/cqrs.go`                                   | the same journal line                                                                                                                                                                          | L          |
| 4 | VM test follows the auth contract: one cookie jar per client, CSRF on logout, `303` once registration closed | `nix/vm-test.nix`                                              | `flake-check.log` (09:26): "all checks passed!", rc=0; `local-flow3.log` (09:17): `live=200 ready=200 version=200`, `register2=403`, `logout no token=403`, `logout with token=200`             | A          |
| 5 | Lint 519 findings (baseline 531); the two `wsl_v5` findings fixed                                          | `cmd/server/main.go`, `internal/handlers/auth_handler_identity_test.go` | `lint.log` (09:26, rc=1 from the standing findings), `lint-targeted.log` (10:40, empty, rc=0)                                                                                                 | A          |
| 6 | Docs: CHANGELOG, ROADMAP, TODO_LIST, AGENTS, FEATURES, README                                             | commits `958f457` to `d3305c7`                                 | written, not re-read line by line, not formatted                                                                                                                                                | I          |

**Commit map [L] and what the SystemNix lock contains.** `git diff --stat ce4abf1..d3305c7` is 4 files, +11/−6.

| Commit    | Time   | Files                                              | In the lock `ce4abf1`? |
| --------- | ------ | -------------------------------------------------- | ---------------------- |
| before 05:27 |      | Go fixes, YAML, tests (not listed individually)   | yes                    |
| `958f457` | 05:27  | `CHANGELOG.md`                                     | yes                    |
| `b81dc05` | 05:31  | `ROADMAP.md`, `TODO_LIST.md`                       | yes                    |
| `54e3e0f` | 05:34  | `AGENTS.md`, `FEATURES.md`                         | yes                    |
| `0f38948` | 05:39  | `AGENTS.md`, `README.md`                           | yes                    |
| `c9c3100` | 05:49  | `nix/vm-test.nix`                                  | yes                    |
| `ce4abf1` | 07:14  | `AGENTS.md`, `FEATURES.md`                         | this is the lock        |
| `6dbcda8` | 09:19  | `nix/vm-test.nix` (the fix)                        | **no**                 |
| `53be7cd` | 10:18  | `cmd/server/main.go`, `auth_handler_identity_test.go` (one blank line each) | **no**  |
| `d3305c7` | 11:31  | `ROADMAP.md`                                        | **no**                 |

So the live build has every Go fix. What the lock lacks is the VM-test fix, two blank lines and one ROADMAP line.

### SystemNix

| #  | What                                                                                                              | Proof                                                                                                                                                                                                                             | Label |
| -- | ----------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| 1  | Port 8113, DNS name `reports`, flake input + lock + lock-audit row, module, secrets file, enabled, matrix row, runbook, data-ownership row, CHANGELOG entry, two todo rows, sops recipe | 11:33 report [I]. [L]: lock rev `ce4abf1`; all files tracked (`git ls-files`); `reports-system` found in `TODO_LIST.md` (1 line), `docs/todo/services.md` (lines 13 and 14), `CHANGELOG.md`, `FEATURES.md`, the runbook (26 lines)         | I, L  |
| 2  | Service live                                                                                                      | PID 952010 since 16:24:33; `/version` = `{"service":"reports-system","version":"0.26.0","git_commit":"ce4abf1cd9ad537df65390a31d458c685d75989b","build_time":"2026-11-28T06:14:06Z","go_version":"go1.27.3"}`                           | L     |
| 3  | Health                                                                                                            | loopback: `/live` `/ready` `/version` `/` all `200`; `https://reports.home.lan/ready` and `/auth/register` `200` via 192.168.1.150:443                                                                                         | L     |
| 4  | DNS                                                                                                               | `getent hosts reports.home.lan` → `192.168.1.150`                                                                                                                                                                                | L     |
| 5  | Unit rendered as designed                                                                                         | `EnvironmentFile=/run/secrets/rendered/reports-system-env`, `MemoryMax=1G`, `ProtectSystem=strict`, `StateDirectory=reports-system`, `User=reports-system`, `REPORTS_SERVER_HOST=127.0.0.1`, `REPORTS_SERVER_PORT=8113`; listener on `127.0.0.1:8113` only | L     |
| 6  | Secrets rendered                                                                                                  | deploy log 16-01-45 line 793: `adding rendered secrets: pim-sync-dav-env, reports-system-env`; the server starts, which it refuses with empty secrets                                                                                              | L     |
| 7  | Journal clean                                                                                                     | 83 lines, 2,149 bytes since 16:20; 8 INFO, 0 WARN, 0 ERROR; systemd: `Started reports-system web server` 16:24:34                                                                                                                 | L     |
| 8  | Backup wiring                                                                                                     | `reports-system-backup-dir.service` ran 16:24:35 to 16:24:36; `/mnt/pool/backups/reports-system` is `reports-system:reports-system`, mode 750; timer `OnCalendar=*-*-* 03:25:00`, `Persistent=true`                                | L     |
| 9  | Memory                                                                                                            | cgroup `memory.current` 40,058,880 bytes; `memory.events` all zero                                                                                                                                                               | L     |
| 10 | Fixed on sight: `session-boot-audit.nix` `splitTokens` kept the separators that `lib.split` interleaves           | `bootaudit-check.log` (10:40) rc=0; the test is wired through `tests/default.nix:83` into `checks.<system>.session-boot-audit` [L]                                                                                                 | A, L  |
| 11 | No em dash left in my module                                                                                      | `grep -c '—' modules/nixos/services/reports-system.nix` → 0                                                                                                                                                                       | L     |

## b) PARTIALLY DONE

1. **The deploy that carries the module is not finished and is not mine.** Log `2026-11-28_16-01-45.log`; activation from 16:23:17 [I, 16:40 sibling report]. At 17:00:54: profile `system-1034-link`, equal to the newest generation by number; `/run/current-system` `c25v4icr…`; one deploy holder alive, last lines "Restarting provisioner: tq-bootstrap.service, boot-mirror-sync.service". Not read: the exit line and `✓ Boot-entry anchored`. The 16:40 sibling report says the boot mirror is divergent until one re-sync.
2. **Upstream gates**: green at the 09:26 tree; never re-run at `d3305c7`.
3. **Upstream docs**: written; the repo's formatter was never run over them.
4. **My SystemNix gates**: none ran. `nix fmt`, deadnix, statix, lint-static, `nix flake check --no-build --all-systems`, the pre-deploy battery, the sops gate: all outstanding since 06:08. The carrying deploy gated the whole tree, but I neither ran it nor read its output.
5. **Lock**: `ce4abf1`, not `d3305c7`.
6. **Runbook** `docs/services/reports-system.md`: exists; no live facts, no first-account procedure, no secret rotation, no restore procedure.
7. **Gatus and tile**: three checks declared ("Reports live" `/live`, "Reports ready" `/ready`, "Reports version" `/version`); rendered config and results not read; tile not looked at.
8. **Manifest**: `ports["reports-system"] = 8113` present; other entries not read.
9. **Metrics**: the app serves `/metrics`; scraping not checked.
10. **Sops recipe**: on disk, outside git (d.8).
11. **Docs I wrote or assigned**: CHANGELOG entry, todo rows, data-ownership row, matrix row, FEATURES line: not re-read line by line.

## c) NOT STARTED

1. First backup: the timer fires at 03:25; not started by hand; directory content unreadable for me.
2. Restore drill: not planned before this report.
3. Lock bump to `d3305c7` and the re-worded lock-audit row.
4. Two lessons into `AGENTS.md` and `docs/agents/nix-flakes.md`: module only after its input; multi-token fixtures for text-walking audits.
5. A `reports-system` term in `docs/DOMAIN_LANGUAGE.md` (0 mentions today).
6. Non-destructive annotation of the 11:33 report.
7. A guard that pages when registration reopens.
8. Upstream README: the first-account window, in plain words.
9. A SystemNix test for the thin layer; `probe-units.nix` stayed a throwaway.
10. Upstream `nix flake check -L` and lint at `d3305c7`.

## d) TOTALLY FUCKED UP

1. **The service went live with the administrator claim open, and nobody was told at that moment.** [L] I knew the window existed (11:33 report, question 2; 14:2x answer) and tied the warning to "my" deploy. Another session fired the deploy at 16:01. Nothing in the module, the runbook or the unit's log says "register now". That is a design miss of mine: a safe go-live depended on the deployer knowing something only my session knew. No harm observed: the page still answers 200 at 17:00.
2. **Module on disk before its flake input existed.** [I] Every evo-x2 eval failed for about 50 minutes; the 08:07 deploy exited rc=1 (`attribute 'reports-system' missing`, quoted in the sibling's 11:36 report); one gate of the 09:33 deploy failed.
3. **Edited `flake.nix` and `lib/lock-audit.nix` from stale reads.** [I] Both edits were caught by the parse step and restored; no damage, twice.
4. **Missed the 06:10 report deadline.** [I]
5. **Wasted one VM cycle** by reusing one cookie jar for two clients. [I]
6. **Seven em dashes in the module**, removed at 09:27. [I, L]
7. **Shipped without my gates** (b.4). The live unit is healthy, so nothing broke; the proof of that is the live probe, not a gate.
8. **The sops new-file recipe is outside git.** [L] `.crush/skills/sops-secret-management/SKILL.md` resolves to `/mnt/hot/crush/SystemNix/skills/sops-secret-management/SKILL.md`; `git check-ignore` says "beyond a symbolic link"; `git ls-files .crush` is empty; `/mnt/hot/crush/SystemNix` is not a git repository. The 11:33 report lists the row as done. It exists on one disk, edited by someone else at 16:23, still carrying my one mention.
9. **This resume:** four `busctl` reads failed (two hand-built escaped paths, then a mistyped bus name on the unit and on the control). No busctl evidence exists. And a `git grep -l … | head -12` list nearly became "no code file wires the session-boot-audit test"; the untruncated run found `tests/default.nix:83`.
10. **Two premises of the handoff I resumed from were stale:** "3 commits unpushed" (caught at 14:11) and "deploy not fired" (caught at 16:54, when this report was ordered). Both were true when written.

## Self-review (the three questions, answered straight)

**What did you forget?**
- That any deploy on the shared tree carries my module, so the admin warning could not wait for "my" deploy.
- That a backup without a restore drill is a claim, not a capability.
- The gates at write time: format, lint, `--all-systems` check. Still not done.
- To write the lessons down when I learned them. Still not done.
- The line-by-line read of the docs I generated. Still not done.
- A domain-language term.
- That `.crush/skills` is not in git; I reported the recipe as done.

**What could you have done better?**
- Order: input, lock, eval proof, then the module file. The reverse cost 50 minutes of fleet-wide eval outage and two deploys.
- One read and one edit in a single step on shared files, with `git rev-parse HEAD` in between.
- Fewer questions: of the three I put at 14:2x, two dissolved on their own (the deploy happened; the invoices session finished its SystemNix half at 14:27). The one that matters is "is this for you alone, and register now".
- Timestamp every quoted state: "3 commits unpushed" went stale within a minute.
- One cookie jar per client in the VM test; a known-value control before any busctl path.

**What could you still improve?**
- The module, so that an unclaimed install cannot be claimed silently (e.1).
- My gate discipline at write time (e.2, e.3).
- The lock, the backup location, the docs and the lessons (section f).

**Did you lie?** Not knowingly. Three earlier statements were imprecise: the sops recipe was "done" on disk only; the handoff's "docs written by the subagent, `nix/vm-test.nix` rewritten" dated the wrong commits (the Go fixes and most docs were locked before the VM-test fix); "deploy not fired" was true only until 16:01.

**Split brains?** Two by design, both small: `MemoryMax = "1G"` is written upstream and in SystemNix (both `mkDefault`, so they must stay equal); the backup lives in SystemNix while invoices moved its backup upstream.

**Ghost systems?** None found in what I wrote. Unchecked: `/metrics` may be served and never scraped.

**Tests?** Upstream gained three unit tests and a true VM test. SystemNix gained one regression leg for a module that was not mine. My own thin layer has no test; the live probe is its only proof.

**Scope creep?** One detour, the session-boot-audit fix: foreign, fleet-wide, it blocked every eval and both deploys. I would take it again.

**Removed something useful?** No.

## e) WHAT WE SHOULD IMPROVE

1. **No silent first-come administrator.** Ranked: (a) a Gatus check on `/auth/register` expecting `303` once the account exists, which pages when registration reopens, for example after a database loss; (b) a runbook rule plus a log line at unit start: "no administrator yet, registration open"; (c) upstream, an admin-provisioning command or invite tokens, so a fresh install never has an open window.
2. **A new-module checklist in `docs/agents/nix-flakes.md`:** input, lock, eval probe, module file, `nix fmt`, lint, `--all-systems` check, battery. The 2026-11-28 outage is its negative test.
3. **Gates at write time, not at "my deploy" time.** On a shared tree the next deploy is always someone else's.
4. **Lock only revisions whose upstream checks are green**, and cite the green artifact in the lock-audit row.
5. **Move the backup upstream** into the portable module, as invoices did.
6. **`MemoryMax` once:** upstream owns it, or names it through an option.
7. **Use the cheap subagents the owner named** (zai `glm-5.3-flash`, reasoning on or off) for docs, formatting and read-throughs. Used twice in about twelve hours.
8. **Promote `local-flow2.sh` upstream:** it replays the VM test's HTTP flow against the built package in 30 seconds.
9. **Promote `probe-units.nix` into a SystemNix test** of the rendered units.
10. **One verified busctl recipe in `AGENTS.md`,** with its known-value control. All four of my reads failed.
11. **Not mine, noticed:** a failed `post-crash-calm-gate.service` is started again by every switch, holds the activation up to 60 minutes and forces exit 4 (AGENTS.md gen-1030; today 10:47 to 11:47). It belongs outside the switch's critical path.
12. **Not mine, noticed:** `scripts/deploy-when-quiescent.sh` loops back on rc=13 only; rc=12 (pressure gate) stops it, so "fire at the next quiet window" needs a human per attempt.

## f) Next, ranked

**Now**

| #  | Item                                                                                                     | Who        | Effort |
| -- | -------------------------------------------------------------------------------------------------------- | ---------- | ------ |
| 1  | Register the administrator at `https://reports.home.lan/auth/register`                                    | owner      | 1 min  |
| 2  | Confirm registration closed: `GET /auth/register` answers `303`                                          | me         | S      |
| 3  | Read the end of deploy log 16-01-45: exit code, `✓ Boot-entry anchored`; profile by number equals running | me         | S      |
| 4  | Gatus: the three Reports checks green, no false alert; Reports tile renders                               | me         | S      |
| 5  | First backup by hand, then read both dumps as a privileged user                                           | me or owner | S      |
| 6  | Restore drill: gunzip into scratch, `PRAGMA quick_check`, compare table lists                             | me         | S      |

**This line, next session**

| #   | Item                                                                                                                   | Effort |
| --- | ---------------------------------------------------------------------------------------------------------------------- | ------ |
| 7   | Lock bump to `d3305c7` (`nix flake update reports-system`, verify the rev moved, re-word the lock-audit row); rides the next deploy | S      |
| 8   | Upstream `nix flake check -L` and lint at `d3305c7` at a calm time; record the counts                                    | M      |
| 9   | `nix fmt -- <my files> --fail-on-change`; deadnix, statix, lint-static over the same files                              | S      |
| 10  | `nix flake check --no-build --all-systems` from a worktree                                                              | M      |
| 11  | Two lessons into `AGENTS.md` and `docs/agents/nix-flakes.md` (e.2, plus the multi-token fixture rule)                   | S      |
| 12  | New-module checklist (e.2)                                                                                              | S      |
| 13  | Read the generated docs line by line: CHANGELOG entry, todo rows, data-ownership row, matrix row, FEATURES line        | S      |
| 14  | Runbook: live facts (store path, generation, lock rev, registration mode), first-account procedure, secret rotation, restore procedure | S      |
| 15  | Gatus guard: `/auth/register` must answer `303` (e.1a)                                                                   | S      |
| 16  | Unit start log line when no administrator exists (e.1b)                                                                  | M      |
| 17  | Check that `/metrics` is scraped; if not, wire it or switch metrics off                                                 | S      |
| 18  | Read the whole manifest entry, not only the port                                                                        | S      |
| 19  | Check backup retention and pruning in my backup unit; compare with the pool's conventions                              | S      |
| 20  | Watch journal growth under real use: the startup log carries multi-line OTel attribute dumps (83 lines in 33 minutes) | S      |
| 21  | `reports-system` term in `docs/DOMAIN_LANGUAGE.md`, or a written reason it needs none                                   | S      |
| 22  | Decide where the sops skill is version-controlled and commit the new-file recipe there (d.8)                            | M      |
| 23  | Annotate the 11:33 report without rewriting it (push landed, service live, invoices question closed)                    | S      |
| 24  | SystemNix CHANGELOG: add the go-live with its generation number                                                          | S      |
| 25  | Thin-layer test from `probe-units.nix` (e.9)                                                                             | M      |
| 26  | After the next reboot: unit active, `/ready` 200, account still the only one                                             | S      |
| 27  | After real use: `memory.events high` still zero; both database files present in the state directory                       | S      |
| 28  | Fan out items 9, 13 and 23 to zai `glm-5.3-flash`, at most three at a time                                               | S      |
| 29  | Harvest this section into `TODO_LIST.md` and `docs/todo/services.md` once you answer (see harvest note)                  | S      |

**Upstream (`~/projects/testing`)**

| #   | Item                                                                                                                     | Effort |
| --- | ------------------------------------------------------------------------------------------------------------------------ | ------ |
| 30  | Viper defaults for `database.max_open_conns`, `max_idle_conns`, `conn_max_lifetime`; the live log shows zeros (queue row `docs/todo/services.md:14`) | S      |
| 31  | README and module option docs: the first-account window in plain words (c.8)                                               | S      |
| 32  | Admin-provisioning command or invite tokens (e.1c), ROADMAP row                                                           | L      |
| 33  | Format the doc edits with the repo's formatter                                                                             | S      |
| 34  | `local-flow2.sh` as a fast pre-check next to the VM test (e.8)                                                            | M      |
| 35  | VM leg for an environment-only deployment (secrets as unit environment, no `EnvironmentFile`)                               | M      |
| 36  | Own the memory ceiling, or expose it as an option (e.6)                                                                   | S      |
| 37  | Backup script and timer in the portable module (e.5)                                                                      | M      |
| 38  | Startup log: one line per event instead of the OTel attribute dump (item 20)                                              | S      |
| 39  | OIDC login through Pocket ID, if you want one IdP for the system (question 2)                                              | L      |

**Noticed, not mine (route, do not do unasked)**

| #   | Item                                                                                                                      | Route                      |
| --- | ------------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| 40  | Calm gate inside the switch transaction (e.11)                                                                             | `docs/todo/stability.md`   |
| 41  | `deploy-when-quiescent.sh`: bounded wait on rc=12 (e.12)                                                                   | pipeline                   |
| 42  | CI deploy key for the private input, already queued as `[blocked:user]` at `docs/todo/services.md:13`                      | owner                      |
| 43  | Storm and freeze #66: load 137 at 16:40, guard trips #13914 to #13916, deploy crawling (16:40 sibling report)                | sibling reports            |
| 44  | Boot mirror divergent until one re-sync (16:40 sibling report)                                                              | sibling reports            |
| 45  | 95 reports with an unharvested §f section (`todo-gate.log` 10:1x; standing backlog)                                         | `docs-health` HARVEST      |

A larger list than 25 is a brainstorm, not a commitment list; items 1 to 6 and 7 to 12 are the commitment.

## g) Questions I cannot answer myself

1. **Is reports-system for you alone?** Then keep the live mode (bootstrap) and register now. If other people need accounts, I switch the module to `open` until they have registered, then to `closed`; that is one deploy each way. And if you are not at a keyboard in the next minutes: stop the unit until you are, or accept the open window?
2. **Accounts or single sign-on?** reports-system keeps its own login (session, JWT, CSRF) and sits behind the Caddy forward-auth for external clients, so from outside you sign in twice. The domain language names Pocket ID the sole IdP. Intended, or should an OIDC login become an upstream work item (item 39)?

The third question from 14:2x (invoices) is closed: the other session landed the SystemNix half at 14:27 and 14:44 (182-line thin layer over `inputs.invoices.nixosModules.default`, Gatus pattern now `pat(*Invoice Ledger</title>*)` at line 159) [L] and is still editing that repo.

## Harvest note

Section f is **deliberately not harvested at authoring time**: you ordered report-then-wait; items 1 to 6 depend on the account being registered first; the queue takes at most three new rows a session and already holds the two rows of this line (`docs/todo/services.md:13-14`). On your answer I harvest items 7 to 12 and 15 into `docs/todo/services.md` with matching queue lines, after checking for existing rows.

## Timeline of this session

| Time   | Event                                                                                          |
| ------ | ---------------------------------------------------------------------------------------------- |
| 14:11  | Session-start probe; state pinned: SystemNix `575daf79d`, generation 1033, no listener on 8113 |
| 14:12  | Found: upstream pushed (`origin/master` = `d3305c7`); lock still `ce4abf1`                       |
| 14:15  | Found: the invoices Gatus check would go red at the next deploy (then still unfixed)             |
| 14:21  | Answered "Any questions?" with three questions                                                   |
| 16:01  | Another session starts the deploy that carries my module (log 16-01-45)                          |
| 16:24  | reports-system starts (PID 952010); backup directory created                                      |
| 16:54  | Report ordered; found the service live and the registration page open                            |
| 17:03  | This report                                                                                     |
