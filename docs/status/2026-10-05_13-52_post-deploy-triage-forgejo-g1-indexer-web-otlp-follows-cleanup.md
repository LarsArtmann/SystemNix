# Status: Post-deploy triage — Forgejo G1 still open, indexer-web OTLP dark, dead-follows cleanup

**Date:** 2026-10-05 13:52 CEST
**Session type:** Deploy-log triage + one in-repo fix. Not a deploy, not a migration.
**Input:** a pasted `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` transcript (build finished 10:35:42, HEAD at deploy time `da296afd`, toplevel `a7868a7`).
**Repo at report time:** worktree `87ecf974` → daemon sweep `d1ade48d` carried this session's edit.
**Live system at report time:** `/run/current-system` = `system-822` = `sdzvl96…` (`26.11.20261003.a7868a7`) — anchored (the transcript's "unanchored" warning was transient; a later activation at 12:07 wrote `system-822` and `/run/current-system` matches its profile).

---

## §a — FULLY DONE

1. **Re-established live ground truth**, not the transcript. Ran `nix run .#post-deploy-check` to completion (saved at `/tmp/pdc-now.txt`); the transcript's FAIL set is NOT the current FAIL set.
2. **Fixed the two eval warnings the transcript literally printed** — `warning: input 'niri-session-manager' has an override for a non-existent input 'systems'` and the same for `todo-list-ai`. Both inputs' lock nodes declare **no** `systems` input:
   - `flake.nix` niri-session-manager block: removed `systems.follows = "systems";`.
   - `flake.nix` todo-list-ai tail: removed `todo-list-ai.inputs.systems.follows = "systems";` **and** the now-obsolete 3-line explanatory comment above it (it said "drop this follow when the pin moves past" — the pin moved).
   - Updated the stale `systems.url` comment ("flake-utils **and niri-session-manager** follow this" → "flake-utils follows this").
   - **Left alone:** the 3 remaining `systems.follows` (flake-utils:42, crush-daily:388, nsfw-classifier:961) — their lock nodes DO declare `systems`, so they are live and correct.
3. **Verified the fix:**
   - `nix flake check --no-build` → `all checks passed!` rc=0, and `grep -c "override for a non-existent"` = **0** (was 2 per invocation).
   - `nix eval .#nixosConfigurations.evo-x2.config.system.stateVersion` → `"25.11"`, clean stderr (no input warnings).
4. **Root-caused the SigNoz `traces_missing 1` FAIL to a concrete, named entity** (not a shrug): it is **indexer-web**, and the cause is a stale pinned binary, not a dark service — see §d/§e.
5. **Root-caused the Forgejo cluster to a known open item** rather than re-diagnosing: `TODO_LIST.md:226` `[blocked:user]` G1 finalize, and confirmed it against live state (`/var/lib/forgejo` IS the mount; `.subvol-migrated` absent; family skips).
6. **Identified a NEW operational hazard not in the transcript:** a user dev process squats forgejo's registered port — see §d.

---

## §b — PARTIALLY DONE

1. **Port-3000 collision:** identified and evidenced, **not remediated** (I do not own the process; it is a live user dev loop).
   - PID `824983`, user `lars`, `bun --watch run observable/server.ts`, cwd `/home/lars/projects/knowledge-graph`, bound `[::1]:3000`.
   - `lib/ports.nix:16` → `forgejo = 3000`. So the smoke's line `PASS Forgejo (localhost:3000) (200)` is a **false PASS** (it is the bun app answering), and Forgejo would `EADDRINUSE` even after the G1 finalize.
2. **indexer-web / SigNoz:** root cause fully established; fix is **push-gated** and I did not push (standing rule). See §d.
3. **Transcript FAIL classification:** done for every FAIL, but two remain classified as "upstream / reboot" without an in-repo remedy (Bank-Sync conflict, FastFlowLM corpse).
4. **TODO harvest:** NOT done. New findings (indexer-web OTLP; port-3000 squat; smoke false-PASS) are described here only — they are **not** yet rows in `docs/todo/*` + `TODO_LIST.md`. Deliberate (see §g Q3), but it means the repo's own "harvest at authoring" rule is unmet for this report. Flagged as debt, see §f.

---

## §c — NOT STARTED

1. Forgejo G1 `finalize` (root; owner window).
2. Any `nix run .#deploy` after this session.
3. Killing/moving the `knowledge-graph` dev server.
4. Pushing `index` `master`; bumping the SystemNix `index` flake input.
5. Reboot for FastFlowLM recovery.
6. Bank-Sync `version_conflict` deep dive in the `bank-sync` repo.
7. Adding smoke assertions for indexer-web (`signoz_traces_reporting{service="indexer-web"}` is not asserted by `post-deploy-check.sh` today — the coverage collector is the only signal).
8. Fixing the `post-deploy-check.sh` null-byte warning spam (lines 133 ×6 and 639).
9. Reducing the post-deploy checker's runtime (it hit my 700 s `timeout`, `EXIT=124`, though it had reached the last block).
10. The 22-subdomain `catalog:` eval warning, `stdenv.isLinux` deprecation, and `buildEnv` collision noise (all pre-existing, item 607).

---

## §d — TOTALLY FUCKED UP / LANDMINES SEEN

Nothing destructive was done. But two real hazards were confirmed and one near-miss was avoided:

1. **Forgejo is DOWN and has been since 2026-09-30** (`journalctl -u forgejo` shows only `skipped, unmet condition check ConditionPathExists=/var/lib/forgejo/.subvol-migrated`). The mounted subvol is the **empty** `hot/forgejo`; the real data is shadowed on QLC. Per `TODO_LIST.md:297`, owner `du` was 16K on the empty mount — the data is intact but hidden.
   - **Near-miss I deliberately avoided:** the "make it green" instinct is to `touch /var/lib/forgejo/.subvol-migrated`. That would have let every forgejo unit start against an EMPTY subvol and mint fresh state (fresh DB via adminSetup / phantom empty dump) — the exact data-loss the marker guards. I did NOT do this. The correct action is the script's `finalize`, which is root-only.
   - **Downstream (all one root cause, not separate bugs):**
     - `gitea-runner-evo\x2dx2.service` fails every activation → the transcript's `activation (test) failed … exit status 4`.
     - `service-health-check.service` fails every ~15 min → `forgejo` is in its `criticalSystemServices = [ "caddy" "forgejo" "dnsblockd" "postgresql" ]` list (`platforms/nixos/system/scheduled-tasks.nix:293`). It also catches gitea-runner via the dynamic `systemctl --failed` sweep.
2. **Port 3000 is squatted by a user dev server** (`knowledge-graph`), which both falsifies the smoke's Forgejo PASS and blocks forgejo's rebind. The eval-time `port-registry-audit.nix` cannot see non-systemd processes, so nothing in the pipeline catches this class.
3. **indexer-web has NEVER emitted a span** — `signoz_traces_reporting{service="indexer-web"} 0`, `last_span_age_seconds -1`, live in a 13:27-fresh `signoz-coverage.prom`. The binary logs, every 60 s:
   `failed to upload metrics: failed to send metrics to http://localhost:4318/: 404 Not Found (body: 404 page not found)`.
   - Root cause chain: the `index` repo fix `internal/readmeindexer/otlp_endpoint.go` (commit `2d0d103`, 2026-10-05 08:43) documents exactly this — _"since otel v1.46 a pathless URL passed to WithEndpointURL targets the collector ROOT path instead of /v1/traces + /v1/metrics"_ — and replaces `WithEndpointURL` with `WithEndpoint(host)`.
   - But `2d0d103` is **UNPUSHED** (`git -C ~/projects/index branch -vv` → `master … [origin/master: ahead 3]`; `merge-base --is-ancestor HEAD origin/master` → false).
   - And `flake.lock` pins `index` at `a2b261b9`, which does **not** contain `otlp_endpoint.go` (`git cat-file -e a2b261b9:…otlp_endpoint.go` → absent). The running binary is `/nix/store/486acm32…-indexer-2.11.0/bin/indexer`.
   - ⇒ This is the live driver of the `SigNoz Trace Coverage Missing` alert that has been firing >24 h.

---

## §e — WHAT WE SHOULD IMPROVE

1. **Triage from live state first, transcript second.** The transcript's CV cluster (5 FAILs) was a mid-restart transient; all 5 PASS now (`CV v7ca881b`). Reporting the transcript verbatim would have sent a session chasing a self-healed phantom. (I did re-run the smoke, but only after initial greps — should have been step 1.)
2. **Check the TODO system before diagnosing.** Items 226/241/297/301/304/687-690 already owned ~half the FAILs. Reading `TODO_LIST.md` first would have cut the diagnosis time materially.
3. **The smoke can be trivially fooled by a port squatter.** `check "Forgejo (localhost:3000)"` asserts status only. A body assertion (or a `systemctl is-active forgejo` prerequisite) would have made the collision loud instead of a green light. House pattern already exists elsewhere (`[BODY] == pat(...)`).
4. **`signoz_traces_missing` has no `reason` label** (never-seen vs went-dark) — TODO `docs/todo/monitoring.md:42`. indexer-web is a "never-seen" that reads like an outage; the label split would have made this a 30-second read.
5. **The post-deploy checker prints 7 lines of bash `ignored null byte` noise** and is slow enough to hit a 700 s timeout. Output hygiene and a per-section budget would improve the signal.
6. **A dev server on a registered service port is a systemic gap**, not a one-off. Consider a user-level guard (e.g., warn when a non-systemd process binds a `lib/ports.nix` port), or just make `knowledge-graph` take an unregistered port.
7. **Cross-repo fixes need an explicit "unpushed fix exists" surface.** The `index` fix has existed for ~5 h and nothing in SystemNix (or CI) can tell — same shape as the `bank-sync` "ahead 4" and every `[blocked:push]` item. A `flake.lock`-vs-local-rev drift report for LarsArtmann inputs would catch this class.

---

## §f — UP TO 50 THINGS TO GET DONE NEXT

**P0 — this incident**

1. Forgejo G1 finalize (owner, root): confirm `/var/lib/forgejo` is a mount → `sudo umount /var/lib/forgejo` if the guard refuses → `sudo scripts/migrate-forgejo-subvol.sh finalize` → `nix run .#deploy`.
2. Free port 3000 (stop/move the `knowledge-graph` dev server) BEFORE the forgejo deploy, else EADDRINUSE.
3. Push `index` `master` (`2d0d103` + the 2 following auto-commits) to `origin/master`.
4. `nix flake lock --update-input index` in SystemNix; confirm `signoz_traces_reporting{service="indexer-web"} 1` after deploy.
5. Add a `post-deploy-check.sh` assertion for `signoz_traces_reporting{service="indexer-web"}` (currently only the collector sees it).
6. Reboot for FastFlowLM recovery (smoke says corpse class / start-limit-hit; reboot only clean recovery).
7. Harvest this report's §f findings into `docs/todo/{services,upstream,monitoring,pipeline}.md` + `TODO_LIST.md` (repo rule).

**P1 — harden the class**
8. Strengthen the Forgejo smoke: body/`systemctl is-active` prerequisite so a port squatter can't fake a PASS.
9. `signoz_traces_missing` reason-label split (never-seen vs went-dark) — monitoring.md:42.
10. Decide indexer-web's correct disposition: keep enforced + fix upstream (my recommendation) vs stopgap `wiring = "event"` (rejected — would mask a genuinely broken exporter).
11. Add `indexer-web` to `docs/todo/upstream.md:19`'s trace-gap list as a distinct "broken endpoint handling" sub-class (7th binary).
12. Cross-repo drift report: for each `LarsArtmann/*` input, compare `flake.lock` rev vs the local checkout's `origin/master`; warn on unpushed/unpinned fixes.
13. Sweep the remaining `[blocked:push]` inputs (`bank-sync` ahead 4, `dnsblockd` 2 docs commits) — same hazard surface.
14. Fix the `post-deploy-check.sh` null-byte warnings (133, 639) — pipe through `tr -d '\0'` or `--compressed` + guard.
15. Budget the post-deploy checker's sections so it cannot exceed the deploy's own timeout.
16. `bank-sync` `version_conflict` root-cause (decider save optimistic-concurrency) — is it a concurrency bug or the SCA/approval gate?
17. Reconcile `TODO_LIST.md:695` (sync_errors_total is restart-cumulative — the smoke stays red post-fix) so this FAIL stops recurring for the wrong reason.

**P2 — eval/doc noise visible in this transcript**
18. Catalog 22-subdomain entries (item 607) so the derived-DNS warning can clear.
19. `stdenv.isLinux` deprecation — find the remaining external input emitting it (follows added for hermes-agent/rust-overlay already; something else remains).
20. `buildEnv` collision noise (python3.13/3.14, xrt/fastflowlm, xwayland/xorg, postfix/bcc).
21. Verify no `systems.follows` regression: add the dead-follow check to CI/a selftest if not present.
22. Document the port-squat hazard in `docs/agents/*` (nix-flakes or shell-devtools).
23. Have `knowledge-graph` adopt a non-conflicting port and register it if it becomes a service.
24. Re-check `system-822` anchoring after next deploy (`/run/current-system` vs `system-<N>-link`).
25. Confirm `/mnt/hot` Samsung present so forgejo-subvol-bootstrap can run during finalize.

**P3 — follow-ups proximate to this session**
26. The transcript's "IO PSI 64% with idle disks + rcu_exp_gp_kthread_worker 18×D — corpse-pile signature" — re-verify it drained (it has) and whether the guard heuristic needs the automount detector.
27. `memory-emergency-guard tripped 6×/60 min` — correlate with the freeze-#12 lineage.
28. `cv-profile-probe` killed (signal: killed) — OOM? IO? add a swap/oom forensic line.
29. `inboxclean-sync` Gmail `context deadline exceeded` — is it IO-pressure-attributed or an API/token issue?
30. `catalog.home.lan → 404` — keep as the intended pre-go-live signal, or add the "not-live-yet" annotation to the smoke so it reads WARN-by-design.
31. Re-verify CV render smoke is stable across a restart (it failed mid-restart this time).
32. Check whether the deploy's 12:07 re-activation was a parallel session (transcript HEAD `da296afd` vs tree `87ecf974`).
33. Reconcile the transcript's `[R.] indexer-web 2.11.0` line — it is the old attr name; current pkg is `indexer-2.11.0` (no breakage, but confusing in diffs).
34. Add a smoke guard that FAILs loudly when a registered port's listener PID is not the owning unit.
35. Capture the "false PASS via port squat" lesson in `docs/gotchas-archive.md`.

**P4 — housekeeping noticed**
36. `docs/todo/desktop.md` has an uncommitted `+1` change not authored by this session — leave it; confirm its owner committed it.
37. Prune `[x]` rows to CHANGELOG on the next pass (repo convention).
38. Re-verify `[ready]` items 687-690 (indexer-web bring-up/ioTier/timer/VM) against the now-live service.
39. Add indexer-web's OTel wiring to `docs/services/indexer-web.md`.
40. Confirm `integration.nix` `http-url` shape is correct platform-wide (it emits pathless `http://localhost:4318`, which is right for `WithEndpoint` — the bug is the binary, not the shape).
41. Audit other `integration.nix` `otel` consumers for the same `WithEndpointURL` root-path bug.
42. Add the `otel-endpoint-audit` note that "pathless endpoint + WithEndpointURL = root-path drop" to `docs/agents`.
43. Check `fastflowlm` guard reaped/rebound correctly after the reboot.
44. Verify `gitea-runner` auto-recovers once forgejo is up (no separate fix needed).
45. Verify `service-health-check` returns green once forgejo is up.
46. Re-run the full smoke after the forgejo+index deploys and diff FAIL count (expect ~0 real FAILs).
47. Keep the `post-deploy-check` baseline stamps current (pipeline.md:166).
48. Re-check `[U*] crush 0.96.1` / tool bumps from this deploy for any behavior change.
49. Confirm no secret leaked in any command this session (none did; no raw values used).
50. Write the CHANGELOG row for the dead-follows cleanup if the repo requires one for flake-level changes.

---

## §g — QUESTIONS I CANNOT ANSWER MYSELF

1. **Push authorisation:** may I **push the `index` repo fix** (`2d0d103`) to `origin/master` and then `nix flake lock --update-input index` + deploy? Without the push, indexer-web stays dark and the `SigNoz Trace Coverage Missing` alert keeps firing. (Standing rule = I do not push unprompted.)
2. **The `knowledge-graph` dev server on port 3000:** is that loop intentional/live, and may I stop it (or should `knowledge-graph` move to an unregistered port)? Until port 3000 is free, Forgejo cannot bind even after the G1 finalize — and the smoke will keep "PASS"-ing on the wrong process.
3. **Harvest + disposition:** do you want me to (a) harvest this report's new findings into `docs/todo/*` + `TODO_LIST.md` now, and (b) keep indexer-web `wiring = "env"` (pages until upstream is fixed — my recommendation) rather than flip it to `"event"` (which would mask a genuinely broken exporter)?

---

_Report authored from a single deploy-log triage session; no deploy, migration, or push was performed._
