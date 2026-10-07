# Status Report: tq `done-preflight` Crash-Loop — Fix Committed, Deploy Deliberately Deferred

**Authoring time:** 2026-10-07 02:43 CEST · **Session scope:** diagnose + fix the failed 01:48 deploy (failing units `tq-agent-pool.service`, `service-health-check.service`), attempt activation, stand down under a foreign IO/thermal storm.

**Live at authoring:** load1 122 (peaked 203 at 02:37), Tctl 92.1 °C (pinned 94–99 °C for most of 02:24–02:39), IO PSI some avg10 60.33 / avg60 73.74. The parallel session's compile battery is still running. `tq-agent-pool` remains safely parked (start-limit-hit), `service-health-check` red on its `systemctl --failed` catch-all.

**Format note (skill divergence, flagged per spec):** status-report skill is HTML-canonical; the user explicitly demanded `.md` at this path — user instruction wins.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **Root cause diagnosed** for both failed units — one causal chain: `done-preflight = true` pool-config key landed 2026-10-06 23:57 (`0fc924fd`, foreign session) for a tq feature that exists **only in local unpushed go-taskqueue master** (ahead 13, `cmd/tq/agentpool.go:194` + `internal/harvest/donepreflight.go`); locked tq 0.3.1 fail-fasts on unknown settings keys → crash-loop 02:01:18–02:03:49 → start-limit-hit; `service-health-check` went red via its dynamic `systemctl --failed` catch-all (its static list caddy/forgejo/dnsblockd/postgresql was green) | journalctl 02:01:18 `unknown key "done-preflight"`; store conf diff; binary string search (0.3.1 AND 0.3.2 lack the flag); `git log -S` |
| a2 | **Fix landed:** premature key removed from `modules/nixos/services/tq-agent-pool.nix`; comment replaced with an anti-refire pointer | commit `3ba0ba6a` — daemon-swept, `git show --stat` verified = exactly my 3 files, **on origin/master** (verified `git branch -r --contains`) |
| a3 | **Config-delta proof:** new deployed conf differs from last-good conf (`nlgsz6r0…`) by exactly one line (`done-preflight = true`) — so the fix restores byte-equivalent settings; no second unknown-key surprise lurking | `diff` of both store paths |
| a4 | **Both queue surfaces synced with the module** (no drift): `TODO_LIST.md:331` now carries "RE-ADD the done-preflight key" in the post-push consumption row; `docs/todo/upstream.md:14` row updated (ahead 7→13, incident narrative, re-add obligation) | edits in `3ba0ba6a` |
| a5 | **Eval green after edit:** `nix flake check --no-build` rc=0 | shell 017 |
| a6 | **Runbook trap upgraded** in `docs/services/tq.md:149`: poolSettings keys are VERSION-COUPLED to the locked binary — gate keys land in the SAME commit as the flake.lock bump, never earlier | commit `e586f3f6` (daemon sweep) |
| a7 | **`check-todo-system.sh` structure clean** after my edits | rc=0 (83 pre-existing unharvested §f warnings are other sessions' reports, untouched) |
| a8 | **Deploy-hold decision made on live evidence, not vibes:** 27-sample PSI/Tctl/load monitor series 02:23:41–02:37:31 showing the box in the freeze-#15/#19/#20/#22 pre-cut signature while a foreign battery ran | monitor log (job 01E) |
| a9 | **Daemon-race discipline held:** verified daemon commit contents before touching HEAD; when HEAD moved past my commit (foreign bank-sync commit `caa17f14`), I correctly **skipped the amend** (would have absorbed foreign files) and verified my fix was already pushed | `git show --stat`, `git status -sb`, `git branch -r --contains` |

## b) PARTIALLY DONE

| # | Item | Gap |
|---|------|-----|
| b1 | **Mission "make the deploy work"** — fix is committed and pushed, but the failing units are still failed on the LIVE box | Activation (redeploy) deliberately deferred; see d2/d3 |
| b2 | **`tq-agent-pool`** — contained (start-limit park = no crash-loop running, no journal spam), not running | Pool down since 02:03:49; TODO harvest paused (arguably protective during the storm) |
| b3 | **`service-health-check`** — root cause understood (pure reporter), zero code changes needed there | Goes green only after tq returns; until then Gatus "tq Agent Pool Service" + OnFailure chain fire every tick |
| b4 | **Post-push `done-preflight` landing** — fully queued with re-add obligation and spec pointer (spec lives in the go-taskqueue repo: `docs/planning/2026-10-06_18-50_dispatch-done-preflight-gate.md`, unpushed) | Blocked:push (owner); nothing executable this session |
| b5 | **§f harvest discipline** — the session's direct follow-ups ARE on queue surfaces (a4); the §f brainstorm below is NOT yet harvested | User said "WAIT FOR INSTRUCTIONS" — harvest tension flagged, not resolved |

## c) NOT STARTED

| # | Item | Why |
|---|------|-----|
| c1 | The redeploy itself (`nix run .#deploy`) + post-deploy verification battery (tq green, health-check green, rendered conf byte-identical to `nlgsz6r0…`) | Box under foreign storm; deploy.sh's 13-section pre-deploy battery was the freeze-#22 terminal trigger |
| c2 | DLQ/`tq tail` sweep for the agent task interrupted at 02:01:13 (the unit had consumed 42 min CPU — something was mid-flight) | Pool down; needs tq back first |
| c3 | Eval-time tq poolSettings schema validation (audit every settings key against the locked tq binary's flag list — port-registry-audit precedent) | New prevention-layer proposal born from this incident; see f5 |
| c4 | `service-health-check` errexit bug fix (see d4) | Discovered this session, not mine to fix uninvited |
| c5 | deploy.sh load/PSI gate BEFORE the 13-section battery (freeze #22's "deploy #2 died mid section-1" would have been gated) | Proposal; owner-scale behavior change |
| c6 | nh 4.4.2 semantics question: the 01:48 log shows `switch-to-configuration test` — `nh os switch` should activate as switch (test+boot-link). Noted, deliberately not researched (user scoped the session) | Open question, f4 |

## d) TOTALLY FUCKED UP

| # | Item | Honesty |
|---|------|---------|
| d1 | **The premature landing itself** — `0fc924fd` (23:57, **NOT my session** — attribution per concurrent-session rules) put a gate key into prod config whose binary didn't exist anywhere fetchable; the key's own comment said "takes effect at the next input bump + owner deploy", i.e. the author knew and landed it anyway. Any deploy in between was a guaranteed crash-loop. That's exactly the AGENTS.md "land the replacement BEFORE removing the old source" class, inverted: never land the CONSUMER ahead of its DEPENDENCY | Fixed by this session; rule now in runbook (a6) |
| d2 | **tq-agent-pool is still down at authoring time** (1h+ since the crash-loop) and TODO harvesting is paused | Contained and arguably protective, but it is a live degraded state, not a green one |
| d3 | **My session did NOT complete the deploy** — the correct call given the storm (I will defend it: PSI 60–95% + Tctl 99 °C is the exact death regime, and the deploy's own battery was freeze #22's terminal trigger), but "everything works" was the bar and the bar is not met | Deferred with evidence + exact resume conditions |
| d4 | **Latent bug found in `service-health-check` (unfixed):** `set -o errexit` + bare `check_service caddy` means if caddy/forgejo/dnsblockd/postgresql is ever the down service, the script DIES at the first static check — **before `notify-send`, before the FAILED report, before anything**. The notify/report path only executes when all four static services are up. The one service meant to scream silently swallows its own scream for exactly the static-list failures | f7 |
| d5 | **My own process errors this session (brutal list):** (1) ran `rg -rn "done-preflight"` — `-r` is the REPLACE flag; the output showed matches rewritten to "n" and I nearly concluded the key wasn't in the tree; one bad flag from a wrong diagnosis. (2) Ran the health-check binary manually, got silent RC=1, and FIRST framed it as "checker confirmed symptom-reporter" — the sandbox had blocked `systemctl` inside the script and errexit killed it silently; my evidence answered no question (the 2026-09-18 rule: a close-out must answer the question the item ASKED). Self-caught one step later by reading the script, but the first claim was evidence-free. (3) My quiescence gate (Tctl<85 AND load1<40) omitted **IO PSI** — the machine's actual kill signal per every freeze autopsy; a PSI-86 moment could have "passed" my gate. (4) Picked the 20-min monitor cap arbitrarily, then killed it — no real exit strategy for "battery that doesn't drain" | Process lessons in e-section |
| d6 | **Unanswered oddity I let slide:** `switch-to-configuration test` in an `nh os switch` run (c6/f4). If nh 4.4.2 changed activation semantics, "boot default generation" assumptions in runbooks (boot-mirror, pre-reboot-check) deserve a re-look | Flagged, not investigated (scope) |

## e) WHAT WE SHOULD IMPROVE

1. **Version-coupled config landing discipline** — tonight's incident in one line: config keys are not freeform; they are API calls against a binary rev. The eval-time schema audit (f5) turns this from "discipline" into a prevention layer. Every freeform `key = "value"` blob fed to an external binary deserves the port-registry-audit treatment.
2. **Quiescence gates must include IO PSI** — Tctl and loadavg are lagging/co-mingled signals; PSI-some is what every freeze autopsy names. Any future "wait for calm" logic (human or script) gates on PSI-some avg10 < ~20.
3. **Cross-session coordination has no surface.** Two sessions, one box: I held a deploy against a battery I couldn't see the purpose or end of; its session presumably doesn't know a deploy is waiting. A tiny convention (e.g. `/run/systemnix-battery-note` or a docs/status heartbeat) would let sessions signal "battery in flight, ETA unknown" instead of each guessing.
4. **"Assert WHICH question your evidence answers" applies to mid-session probes too,** not just close-outs — d5(2) cost me one false confirmation. Cheap fix: after any probe, state the question and the answer in one sentence before moving on.
5. **Verify surprising tool output at the source.** The `rg -r` garbage was self-evidently wrong ("n" = "true") and I re-checked immediately — but the failure mode (misread flag → confident wrong conclusion) is the expensive kind. The store-diff cross-check that saved the diagnosis should be the default second look.
6. **Deploy-log warning debt is compounding:** the 01:48 log carries eval warnings (20-name catalog subdomain list, `stdenv.isLinux` deprecation, llama-vlm soak reminder) and a wall of `buildEnv` colliding-subpath warnings (python 3.13/3.14, fastflowlm/xrt libxrt, postfix/bcc man, xwayland/xorg). Each individually trivial; together they bury real signals. A periodic warning sweep (f20–f26) would restore signal-to-noise.
7. **The auto-commit daemon pushes to origin/master in batches** (3ba0ba6a was on origin within ~35 min of creation). That means every session's mid-flight work becomes public/pushed history without an explicit push act. If that's intended policy, fine — but it deserves being stated in AGENTS.md rather than discovered.

## f) Up to 50 things we should get done next

Tagged: `[NEW]` = born this session · `[ROW]` = pre-existing queue row, cited · `[OWNER]` = owner-gated · `[LOG]` = noticed in the pasted 01:48 deploy log this session. Ordered by impact; N>25 items are brainstorm fuel per skill spec, not commitments.

**Immediate — this incident's tail:**
1. `[NEW]` **Deploy when quiescent** (PSI-some avg10 <20, load1 <40, Tctl <85): `nix run .#deploy` — deploy.sh's `reset-failed` clears tq's start-limit state automatically.
2. `[NEW]` **Post-deploy verification battery:** tq-agent-pool active; rendered tq-pool.conf byte-identical to `nlgsz6r0…`; service-health-check rc=0; Gatus "tq Agent Pool Service" self-resolved.
3. `[NEW]` **DLQ sweep for the interrupted 02:01 task** (`tq dlq`, `tq tail`) — a task died mid-flight with 42 min CPU spent; rescue or confirm dead-letter + autopsy.
4. `[NEW]` **Resolve the nh `switch-to-configuration test` semantics question** (c6) — confirm nh 4.4.2 still sets boot-default generation on `os switch`.
5. `[NEW]` **Eval-time tq poolSettings schema audit** — new `*-audit.nix` validating every settings key against the locked tq binary's `agent-pool --help` flag list; would have caught tonight's crash at eval, not in prod. Port-registry-audit precedent.
6. `[NEW]` **Fix `service-health-check` errexit bug** (d4): static check failures must still reach notify+report (pattern: `check_service X || true` + rely on FAILED accumulation, or conditional calls). Repo has a self-testing-script precedent to copy.
7. `[NEW]` **Make service-health-check journal its FAILED list** (`logger`) so a failed notify-send or blocked tty never loses the diagnosis again.
8. `[NEW]` **deploy.sh: PSI/load gate before the 13-section battery** — freeze #22's deploy #2 would have been refused; gate must be skippable with an explicit owner flag.
9. `[NEW]` **Confirm the OnFailure/PapDashboard alert path actually delivered** during the 02:01–02:03 window (journal shows triggers fired; delivery unverified).
10. `[OWNER]` **Push go-taskqueue master** (ahead 13, incl. done-preflight + verify-gate classification) — `docs/todo/upstream.md:14`.
11. `[ROW]` **Post-push consumption:** bump lock → verify FOD/package → redeploy → **re-add `done-preflight = true`** → confirm `tq --version` stamps the landing rev — `TODO_LIST.md:331` + `upstream.md:14` (both updated this session).
12. `[ROW]` **Upstream tq fix while bumping:** move `startLimitBurst`/`startLimitIntervalSec` out of `serviceConfig` (systemd rejects lowercase `[Service]` copies every unit load) — `docs/todo/services.md:119`.

**tq/stability context read this session (rows I touched or sat next to):**
13. `[ROW]` Guard coverage for tq-agent-pool (ioChurnUnits membership is an owner policy call) — `docs/todo/stability.md:14`.
14. `[ROW]` Per-unit io.stat top-consumer sampler — `stability.md:15`.
15. `[ROW]` IO admission (cgroup `io.max`) for tq pool + parallel build slices — `stability.md:91`.
16. `[ROW]` Write freeze #8–#22 entries into the stability taxonomy — `stability.md:103` (I added to the pile this session: tonight's near-#23 series is draft material with a 27-sample PSI series).
17. `[ROW]` Post-deploy wave battery for the a7868a7 batch (bank-sync unshimmed FOD proof first) — `docs/todo/services.md:274`.

**Noticed in the pasted 01:48 deploy log (this session's input, all `[LOG]`):**
18. Eval warning: catalog integration subdomains without catalog entries (20 names listed) — fix the derivation or the entries.
19. Eval warning: `stdenv.isLinux` deprecated — fix source.
20. Eval warning: llama-vlm SOAK-TEST obligation before decommissioning manual llama-server — schedule the soak.
21. buildEnv collisions: python3-3.13.15 vs python3-3.14.7-env (whole bin/lib/man set) — one python too many in system-path.
22. buildEnv collisions: fastflowlm vs xrt `libxrt*.so*` set — investigate which owns the libs.
23. buildEnv collisions: postfix vs bcc `trace.8.gz`; xwayland vs xorg-server `protocol.txt`/`Xserver.1.gz`/`Xserver.fish`.
24. Journal file truncated (`system@…journal~`) — journald rotation/health check.
25. `[NEW]` Add a tq-version + conf store-path stamp comment into the rendered tq-pool.conf for faster incident triage (tonight I needed a store-path diff to prove the delta).

**Process/system improvements born this session:**
26. `[NEW]` Encode quiescence-with-PSI as a tiny reusable script (or document the gate) so the next "hold or deploy" decision isn't re-derived ad hoc.
27. `[NEW]` Cross-session battery/heartbeat convention (e-section #3) — minimal viable version first.
28. `[OWNER]` Confirm/declare auto-push-to-master policy for the daemon (e-section #7) — AGENTS.md currently documents auto-COMMIT, not auto-PUSH.
29. `[NEW]` tq.md runbook: add crash-loop/start-limit recovery one-liner (deploy.sh does `reset-failed`; manual recovery path deserves the same three lines).
30. `[NEW]` When the done-preflight key is re-added (item 11), document its signals/verdicts in tq.md from `donepreflight.go` (doneReasonAbsent/doneReasonReport class names already read this session).
31. `[NEW]` TODO-system tension rule: when a session ends in WAIT-for-instructions, §f actionable items still get queued at authoring time OR the report explicitly records the deferral reason — this report chooses explicit recording (b5); make that pattern a named convention.
32. `[ROW]` Boot-mirror PartUUID/BootCurrent decode verify half still open — AGENTS.md Build & Deploy section.
33. `[ROW]` nvme0↔nvme1 enumeration flip + first `/data` read-csum movement (freeze-22 collateral) — stability/storage follow-up I read tonight.
34. `[ROW]` Browser-history read-model count-gap prod probe — `TODO_LIST.md:332` (read this session while editing :331).

**Hygiene (small, from what I touched):**
35. `[NEW]` tq-agent-pool.nix: the settings blob is freeform strings — once the schema audit (5) exists, type the values (durations as ints-with-units, booleans as bool) so bad values fail eval too.
36. `[NEW]` `check-todo-system.sh` strict mode currently exits 0 with 83 unharvested §f warnings — either the rc is the contract and the WARN text overstates ("fails"), or the rc is wrong. One or the other.
37. `[LOG]` Deploy log's "NOT restarting the following changed units: dbus-broker, polkit" — verify that skip is intended (changed-but-not-restarted units can drift from their unit files until next restart).
38. `[NEW]` 29 users / 20+ sessions on the box at 02:40 — session hygiene census (who's holding ttys at night during freeze season).
39. `[NEW]` My monitor scripts and ad-hoc poll loops die with the session — if hold-decisions matter overnight, they belong in a systemd timer/script, not a shell session.
40. `[OWNER]` The cooling deficit itself (chronic Tctl ceiling under any battery) — hardware/owner territory, every queue row points at it.

**Smaller notes:**
41. `[NEW]` tq pool's 30/day budget: verify the crash-loop window didn't burn enqueue budget on dead letters (post-deploy `tq stats`).
42. `[LOG]` The switch stopped+restarted 14 units at 01:48 — normal, but `gatus.service` among them: confirm checks re-converged (post-deploy-check covers this; only listed because the storm interrupted the usual battery).
43. `[NEW]` done-preflight feature flag: when re-added, consider exposing its verdict counts in `tq stats`/dashboard so the zero-spend savings are visible (feature's own ROI evidence).
44. `[NEW]` tq-pool.conf keys I verified against 0.3.1's flag list by eye during the diff — the audit (5) should also cover `tq-serve`/`tq-bootstrap` conf surfaces, not just agent-pool.
45. `[NEW]` AGENTS.md candidate line (owner call): "settings-file keys for external binaries are version-coupled — land with the bump" is a generalization of tonight's lesson beyond tq (bank-sync/papdashboard conf blobs share the shape).
46. `[LOG]` `accounts-daemon.service` stopped+restarted at 01:48 — no action, recording in case of desktop oddities tomorrow.
47. `[NEW]` pre-deploy-check: consider a fast "foreign battery detector" section (PSI sample) so the 13-section battery refuses to START under the death regime — sibling of item 8 but at check level, not deploy level.
48. `[NEW]` tq-serve dashboard (`tq.home.lan`) could surface pool state (running/parked/start-limit) — tonight the only truth was journalctl.
49. `[NEW]` The `reviving group/user 'netbird-evox2'` lines at 01:48 (foreign session's first boot) — their battery's verification duty, flagged for their close-out (services.md:274 row covers it).
50. `[OWNER]` Decide who owns freeze-season deploy policy: tonight a deploy was swept into prod at 01:48 during storm-hour with the battery still hot — the deploy-time PSI gate (8/47) needs an owner decision, not just an implementation.

## g) Questions I can NOT figure out myself

1. **Deploy authority + storm ETA:** Do you want me to run `nix run .#deploy` automatically the moment the quiescence gate passes (PSI-some avg10 <20, load1 <40, Tctl <85), or are you/another session holding the box for the compile battery? Related: is that battery's duration known — and is it *supposed* to be running at 02:00–03:00 during freeze season?
2. **Auto-push policy:** my fix commit `3ba0ba6a` reached origin/master ~35 min after the daemon created it, without any explicit push act by me. Is daemon auto-push to master intended policy (and if so, should AGENTS.md say so), or is something else pushing?
3. **The interrupted task:** tq was SIGINT'd at 02:01:13 mid-task (42 min CPU consumed). Is there a specific dispatch/agent you expected to finish tonight that I should prioritize rescuing from the DLQ after redeploy — or is the standard sweep enough?

---

**Harvest note (per status-report skill):** items 1–2 are the session's direct follow-ups and are recorded HERE + in the final message rather than queued to `TODO_LIST.md`, because the user ordered WAIT-for-instructions before any further action; items 5–9, 25–31, 35–36, 39, 41–45, 48 are `[NEW]` proposals awaiting routing on instruction; `[ROW]` items already live on their cited surfaces; `[OWNER]` items are the user's.

**WAITING FOR INSTRUCTIONS.**
