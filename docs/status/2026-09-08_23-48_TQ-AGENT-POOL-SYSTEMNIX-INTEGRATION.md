# Status: go-taskqueue → SystemNix/evo-x2 integration (ROUND8) — 2026-09-08 23:48

**Session scope:** integrate `~/projects/go-taskqueue` (tq agent pool + dashboard)
into SystemNix on evo-x2, executing the upstream ROUND8 plan
(`docs/planning/2026-09-08_22-55_SUPERB-PLAN-ROUND8-SYSTEMNIX-EVO-X2-INTEGRATION.md`
in the go-taskqueue repo). Session worked BOTH repos; parallel agent sessions
were active in both throughout (their churn is noted where it intersected).

**Verdict:** all code shipped and verified to the FULL BUILD level (evo-x2
toplevel builds green, both flake checks green, formatting clean). The deploy
itself is sudo-gated and NOT run — the pool is not live yet. Deploy-blocking
bugs found and fixed during the session: 2 upstream (getExe binary name,
stale vendorHash), 2 integration (dirty-tree lock pin, stale rev pin).

---

## a) FULLY DONE (verified)

| # | Item | Evidence |
|---|------|----------|
| 1 | Upstream NixOS module `deploy/nixos/tq-agent-pool.nix` (`services.tq-agent-pool`: enable/package/user/group/dbPath/poolSettings→pool.conf/extraArgs/serve; drain invariants SIGINT·process·45min·ProtectSystem=full; pool-path mount gating; synthetic-user branch) | module file; `nix flake check` green |
| 2 | Upstream `flake.nixosModules.default` declared | flake.nix; evo-x2 import renders units |
| 3 | Upstream `checks.module-eval` (evals default + deployment shapes, asserts drain invariants + ExecStart wiring) — built and executed green; caught 2 bugs during development | `nix build .#checks.x86_64-linux.module-eval` exit 0 |
| 4 | Upstream vendorHash refresh (`sha256-DCc5L…`, drift from the 13 unpushed commits) | `nix build .#default` green upstream AND through SystemNix nixpkgs (`nix build .#tq`) |
| 5 | SystemNix flake input `go-taskqueue`: rev-pinned `git+file` (ca8a2f4), `nixpkgs.follows`, go-nix-helpers deliberately NOT followed (bank-sync FOD trap) | flake.nix + clean lock node (no dirtyRev) |
| 6 | `tq` in `mkLarsPackages` → `nix build .#tq` + quick-go pre-deploy FOD batch + CLI on PATH | lib/lars-packages.nix; `nix build .#tq` green |
| 7 | evo-x2 imports upstream module (systems/evo-x2.nix, next to bank-sync) | renders |
| 8 | House module `modules/nixos/services/tq-agent-pool.nix`: user=lars, journal `/mnt/pool/services/tq/tq.db`, poolSettings calibrated from the live round-9 window (concurrency 2, budget 30/day, max-per-tick 3, review, dlq-backoff 30m, repo-interval go-taskqueue=10m, log-dir+168h retention, alert-url→PapDashboard), serve 127.0.0.1:8100, `tq-storage-dir` pool-subvol oneshot, `tq-bootstrap` rails-seeding oneshot (model zai/glm-5.3-flash, SystemNix verify gate `nix flake check --no-build`), MemoryMax 8G/CPUQuota 400%, ioTier.build, NO harden{} on pool (documented why), serve hardened | module; ExecStart/poolSettings/EnvironmentFile spot-ev'd |
| 9 | Wiring: `ports.tq` 8100, DNS `tq` subdomain, Caddy `protectedVHost "tq"`, btrbk-pool `services/tq` subvolume | files; flake check green |
| 10 | Monitoring: Gatus "tq Dashboard" (functional body pattern — live-verified against the running round-9 instance) + "tq Agent Pool Service" (system_service_state_failed), system-health monitoredServices ×3 (pool/serve/bootstrap), Homepage AI tile | gatus-config.nix, system-health.nix, homepage.nix |
| 11 | sops template `tq-agent-pool-env` (DEDICATED — agent payloads inherit the pool env; rationale documented), `TQ_DB` session var for lars, `services.tq-agent-pool.enable = true` in configuration.nix | sops.nix, home.nix, configuration.nix |
| 12 | post-deploy smoke section (dashboard body + pool active + journal exists) + deploy.sh provisioner restart list (tq-storage-dir, tq-bootstrap) | scripts; `bash -n` green |
| 13 | Docs: `docs/services/tq.md` (architecture, cutover, misbehavior, rollback, maintenance), AGENTS.md tq section, upstream CHANGELOG entry + TODO_LIST handoff item (FEATURES.md row was done by a parallel session) | files |
| 14 | Verification stack: upstream `nix flake check` + package build + module-eval; SystemNix `nix flake check --no-build` (ALL house audits pass: ports, gatus-pattern-lint, shell-nullglob 1 pre-existing warning, textfile-tmp); **full evo-x2 toplevel `--keep-going` build GREEN**; `nix fmt -- --ci` 0 changed | this session, logged |

## b) PARTIALLY DONE

1. **Live deployment (ROUND8 C4/C5)** — everything up to the switch is done;
   `nix run .#deploy` is sudo-gated in this session. Not run.
2. **Round-9 cutover** — runbook written (`docs/services/tq.md`) but the
   manual pool (`/tmp/tq` PIDs 55731 agent-pool + 682008 serve :8090) is
   STILL RUNNING (belongs to a parallel session; deliberately not killed).
   Until cutover, a deploy creates a SECOND pool (different DB) — double
   LLM spend on the go-taskqueue repo.
3. **DB carry-over decision** — cutover steps support both fresh-journal and
   copy of the dogfood `tasks.db`; not executed, so nothing decided live.
4. **PapDashboard bridge live-proof** — env + alert-url wired and the ingest
   API is proven (gatus uses it), but no tq dead-letter has flowed yet.

## c) NOT STARTED (deliberate skips + gaps)

1. **VM test (ROUND8 E3)** — skipped (plan tier "rest"); upstream bank-sync
   ships one, go-taskqueue does not. Neither a SystemNix `tests/test-tq*.nix`
   nor an upstream `nixos-vm-test` exists.
2. **`--discovery-addr` wiring** — the pool does a local scan; the
   project-discovery-daemon (on this box, `/run/project-discovery/daemon.sock`)
   is not consumed. Skip rationale never documented in the module.
3. **`--status-every N`** — upstream-owner-blocked (N not picked).
4. **`tq api` write API** — not exposed/wired anywhere.
5. **CQA bridge (`--cqa-url`)** — not wired (CQA not deployed here AFAIK).
6. **`--budget-cmd`** — not wired.
7. **Local-NPU model option (FastFlowLM)** — never wired or surfaced; the
   pool pins the PAID zai/glm-5.3-flash per the upstream example. A free
   local option exists and was not evaluated.
8. **DLQ/sidecar log-dir monitoring** — `~/.local/state/tq/logs` has
   age-based retention (168h) but no size metric/alert.
9. **AGENTS.md gotcha entry for the git+file dirtyRev lock trap** — the
   lesson lives only in the flake.nix input comment.
10. **docs/services index check** — `docs/services/tq.md` may not be listed
    in any index (unverified).
11. **`withPapIngest` coverage of the 2 new Gatus endpoints** — assumed
    (they sit in the same wrapped endpoints expression) but never verified
    that they actually receive the pap ingest alert block.
12. **Pre-deploy check additions** — assumed check #12 (ExecStart existence)
    auto-covers the 3 new units; not verified against the script.

## d) TOTALLY FUCKED UP (caught in-session; honest list)

1. **First module draft had 4 eval-level bugs**: invented
   `lib.attrsets.sortAttrsByAttrs` (nonexistent), `documentation` as a string
   (list required), `inputs.self` in perSystem (unresolvable), missing `lib`
   destructure + a paren mismatch. All caught by eval — but the file was
   written too fast, each cost a rebuild round.
2. **`lib.getExe` binary-name bug** — module rendered
   `bin/go-taskqueue` but the binary is `tq`. NOT caught by my module-eval
   check (its regexes matched regardless of the binary name); caught only by
   a manual post-build ExecStart spot-check. The deployed unit would have
   crashed with exec-format error on every start. Lesson: assert the FULL
   ExecStart binary path in the check, not fragments.
3. **First lock attempt recorded a `dirtyRev` narHash pin** — a moving git+file
   input over the constantly-churning upstream repo would break EVERY SystemNix
   eval on the next uncommitted change. Caught by inspecting the lock node;
   fixed with a `?rev=` URL pin.
4. **Pinned a stale rev (7890cc9) without building it through SystemNix
   first** — the full toplevel build failed on a bootstrap test that a
   parallel session fixed in a LATER commit (7acb169). Wasted a full build
   cycle. Lesson: rev pins must be build-verified in the CONSUMING flake
   before moving on.
5. **Duplicate `serviceConfig` key** in the house module first draft —
   caught by re-reading before eval.
6. **rg `-rn` flag slip** (`-r` = replace) mangled file content in output
   ("crush"→"n") — recognized before drawing conclusions, but it's the
   exact class of tool-output misread AGENTS.md warns about.

## e) WHAT WE SHOULD IMPROVE (design risks + process)

1. **`tq-bootstrap` can block/annoy deploys**: it runs at every deploy as a
   wanted unit and does git commits in 3 repos; a repo in a weird state
   (rebase, detached, conflicts) makes the oneshot fail → activation
   friction. Consider: failure tolerance for the oneshot (best-effort +
   alert, like the deploy.sh `|| true` provisioner pattern) or moving
   seeding fully into the runbook.
2. **deploy.sh lacks a pre-check for the manual round-9 pool**: a deploy
   without reading the runbook silently DOUBLE-RUNS pools. A WARN on live
   `/tmp/tq` processes would close it.
3. **Budget/cost extrapolation**: calibrated knobs (budget 30/day,
   max-per-tick 3) were proven for ONE repo (go-taskqueue); I extrapolated
   to CV+SystemNix without live evidence. First live days need watching.
4. **MemoryMax 8G for 2 crush agents is a guess** — crush (bun) + builds can
   exceed it; OOM-killed agents retry and burn budget. Needs live tuning.
5. **Journal on the one-USB-link DAS**: every fact append rides the
   IO-storm-susceptible link (2026-09-06 class). Low volume, but worth an
   eye during pool sends/scrubs.
6. **Single-machine source of truth**: the deployed binary's source (13+
   commits ahead of origin, owner-blocked push) exists ONLY on evo-x2. Disk
   loss = deployed-binary provenance loss.
7. **module-eval check asserts fragments, not full ExecStarts** (see d2) —
   upstream check should pin the exact binary path.
8. **House eval test absent** — upstream covers the module; nothing pins the
   SystemNix house layer (a `tests/test-tq-agent-pool.nix` minimal eval
   would, cheaply).

## f) NEXT — up to 50 things, ordered

**P0 — go-live (user, sudo):**
1. `nix run .#deploy`
2. Cutover: stop `/tmp/tq` agent-pool (SIGINT, let it drain) + serve; copy dogfood `tasks.db` → `/mnt/pool/services/tq/tq.db` (optional) — exact block in `docs/services/tq.md`
3. Verify: `systemctl status tq-{agent-pool,serve,bootstrap,storage-dir}`, `tq stats`, dashboard `https://tq.home.lan`, `journalctl -u tq-agent-pool -f` first harvest tick
4. Confirm Gatus "tq Dashboard" + "tq Agent Pool Service" go green; Discord alert wiring
5. Watch first agent completions end-to-end (agent → verify → review task) and daily-budget burn for 2-3 days
6. Verify `.crushrc`/`.tq-verify` landed in CV/SystemNix/go-taskqueue (tq-bootstrap journal)

**P1 — close the gaps found above:**
7. deploy.sh WARN on running `/tmp/tq` processes (double-pool guard)
8. Decide + implement tq-bootstrap failure tolerance (or document accepted friction)
9. Verify `withPapIngest` covers the 2 new endpoints (inspect generated gatus.yaml)
10. Verify pre-deploy check #12 sees the 3 new units
11. Upstream: module-eval check pins the exact ExecStart binary path
12. SystemNix `tests/test-tq-agent-pool.nix` minimal eval (house layer negative+positive)
13. Upstream or SystemNix VM test (ROUND8 E3) — boot the module, stub agent, `--once` drain
14. AGENTS.md gotcha: "git+file inputs on churning repos MUST be rev-pinned (dirtyRev lock breaks every eval)" — generalize beyond this input
15. docs/services index/README: add tq.md if an index exists
16. Post-deploy smoke: add `tq doctor` (all-green) once it works against the pool DB
17. Smoke robustness: retry/wait around `systemctl is-active tq-agent-pool` (deploy-restart race)

**P2 — upstream coordination:**
18. Push go-taskqueue master to origin (owner decision) → flip SystemNix input to `github:…?ref=master` → CI coverage returns for this input
19. Cut v0.2.0 upstream (CHANGELOG [Unreleased] is fat); tq version stamp alignment
20. Upstream TODO line 101: install smoke in `scripts/smoke/` (repo-level)
21. Adopt `--discovery-addr` → project-discovery-daemon socket (kills the per-tick local scan); document socket permission needs for the lars-run pool
22. `--status-every N` once owner picks N (status-loop reports → TODO_LIST appends)
23. Consider `--prune-stale` upstream (zombie pending tasks on pool-down harvest)

**P3 — operational polish:**
24. Evaluate FastFlowLM (local, free) vs zai/glm-5.3-flash for agent quality/cost; possibly per-repo split (go-taskqueue=flash, CV=flm dry-runs)
25. Tune MemoryMax/CPUQuota after first live week (agent OOM retry signature in journal)
26. DLQ depth + sidecar log-dir size metric (textfile collector or tq stats cron)
27. Budget spend visibility: `tq stats` budget card → Homepage/Gatus (upstream `--json` first: TODO line 89)
28. `repo-interval` for CV/SystemNix once their volume is known
29. Consider auth-token on serve (upstream option) if LAN trust model changes
30. btrbk-pool restore drill for /mnt/pool/services/tq (journal restore = copy file back + watermarks intact)
31. Wire `tq harvest` result into Overview/PMA dashboards if useful
32. Register the journal in backup-coordination IF btrbk-pool freshness proves insufficient
33. Document the agent-commit ↔ PMA auto-commit interaction (two committers on the same trees) if churn conflicts appear
34. CQA bridge if/when CQA deploys here
35. `tq api` exposure decision (write API behind Caddy? probably never — CLI is enough)

**P4 — SystemNix hygiene surfaced by this session:**
36. The one pre-existing nullglob warning (flake.nix:815 `for m in $metrics`) — not this session's, but seen; ticket it
37. Quick-go now includes tq: upstream go.mod bumps will redden the pre-deploy batch — expected, documented here
38. CI remains dark for git+file inputs — the "CI cannot fetch" window is recorded in the flake comment; revisit on flip (item 18)
39. `docs/status/README.md` index sync (upstream pattern) — check SystemNix has one for this report
40. Consider a generic "rev-pinned local input" helper/warning eval-time (prevent the d3 class repo-wide)

**P5 — monitor after live:**
41. First `tq cancel --force` / DLQ rescue drill (runbook §misbehavior) once real dead letters exist
42. Watermark behavior across pool restarts (`tq watermarks show` — upstream TODO line 84 audit applies to our deployment too)
43. SSE dashboard through Caddy under load (fragment streaming, reconnect)
44. Pool behavior during DAS outage (RequiresMountsFor fails loudly — verify the alert path)
45. Interaction with memory-emergency-guard (pool at 8G Max is a candidate victim under storms — acceptable? document)
46. Agent git identity/authorship in repo history (commits by agents vs daemon — attribution hygiene)
47. Review-task loop health (`--review` mints a second agent per completion = 2x budget events; watch burn)
48. go-taskqueue repo self-dogfood while SystemNix harvests it (both repos now feed the same pool — cross-contamination of sessions?)
49. First `nix flake check --no-build` verify gate inside an agent task (SystemNix verify cmd) — measure wall time vs task-timeout 45m
50. Retro: fold the "build the consuming flake BEFORE declaring a pin good" lesson into AGENTS.md deploy doctrine

## g) Questions I CANNOT answer myself

1. **Model economics for autonomous agents**: keep `zai/glm-5.3-flash`
   (paid, cheap, proven by your examples) or try local FastFlowLM
   (`qwen3.6-moe:35b-a3b`, free, NPU, weaker coder) for some/all repos?
   This sets real spend per day at budget 30.
2. **Push go-taskqueue master to origin now?** The deployed binary's source
   exists only on evo-x2 (13+ unpushed commits, push marked owner-blocked
   upstream). Pushing also lets me flip the input to `github:` and restore
   CI coverage for it — but it's your call on repo readiness.
3. **Cutover mandate for the running round-9 pool**: may the deploy kill the
   manual `/tmp/tq` pool + serve (journal copy per runbook), or should it
   keep running until you've seen the systemd pool's first live days
   (accepting double spend on go-taskqueue in the meantime)?

---
*Written by the integration session; awaiting instructions.*
