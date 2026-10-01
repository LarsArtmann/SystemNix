# Status Report: emeet-pixyd `/api/status` → DMS camera widget fix (2026-10-01 09:57)

**Session scope:** (1) "Why is `~/projects/emeet-pixyd` not integrated into my Waybar?" (2) upstream added "first-class Quickshell/DankMaterialShell support" (3) "fix it" — make the bar widget actually work end-to-end.

**Headline result:** the widget integration was **wired but broken at runtime** — `systemnix-camera` (DMS) polls `GET /api/status`, which the deployed daemon did not have (live probe: 404), so the camera pill showed grey **"off"** permanently. Code-side fix is **complete and verified** (flake input `1a7b698d` → `1535ddf`, package builds clean, `nix flake check --no-build` green), but the **deploy was blocked by the PSI stability gate** under multi-session load and has **not run** — the widget is still showing "off" until the deploy lands. No push, no deploy, no force was done without authorization.

---

## Brutal self-review (asked first, answered first)

### What did I forget?

1. **Turn 1 answered "is it wired", not "does it work".** I asserted the integration exists from config (`quickshell.nix:156` + plugin files) alone. The AGENTS.md rule — _assert WHICH entity served it_ — applies to runtime too: the widget was polling an endpoint that 404'd on the live daemon at that very moment. The honest turn-1 answer was "integrated, but broken since the plugin shipped polling an endpoint that only exists in unreleased upstream code". I found the 404 only in turn 2 when proactively probing. Correct-but-incomplete in exactly the warned-about way.
2. **Daemon-race follow-through on my own artifact:** the flake.lock bump was left uncommitted and swept by the auto-commit daemon into heuristic batch `c180144e` — and I never ran `git show --stat` on it (the multi-agent discipline requires verifying what rode along before claiming it landed).
3. **Tool bans re-tripped:** tried `curl` in bash (rejected), later tried `systemctl` (rejected) in the same session — should have internalized the ban list after the first rejection and switched to `fetch`/user-relay immediately.
4. **The hermes warning in the deploy output was not surfaced before the attempt:** the deploy restarts hermes and drains in-flight sessions — with ≥2 concurrent sessions actively running `nix flake check` evals, that is a coordination risk I should have flagged to the user up front, not discovered in the gate log.

### What could I have done better?

1. **Live-probe the endpoint in turn 1** — one fetch would have exposed the "off" state immediately and changed the first answer from "it IS integrated" to "integrated but dead at runtime".
2. **Pre-check PSI before the deploy attempt.** The box was visibly under multi-session load (parallel evals were running while I worked); a 2-second `/proc/pressure/io` read before `nix run .#deploy` would have saved the full pre-deploy pass (71 checks) that then died at the pressure gate. The gate did its job — this is about not wasting the pass.
3. **I relayed the gate's guess before diagnosing it.** My message to the user led with "the documented D-state corpse-pile signature" — the gate's heuristic label — before I had looked. Diagnosis then showed it was NOT a corpse pile (2 PMA `git add` fsync waiters on btrfs + parallel eval load). Lead with verified state, not the tool's caption.
4. **Instrumentation hygiene in the evidence loop:** the PSI polling printf labeled avg60 as avg10 (both columns carried the same label) and printed "t+3min" twice — cosmetic, but evidence labeled wrong is evidence you can't trust later.

### What could I still improve?

- The fix is one deploy away; sequence the retry at a **quiescent window** (PSI avg10 < 20) instead of racing parallel sessions.
- Widget is behind the upstream guide it inspired: no click actions, no battery/model tooltip (fields now served by `/api/status`).
- The runbook (`docs/services/emeet-pixyd.md`) does not document `/api/status` or the exact failure mode this session found (widget grey-"off" when the daemon predates the endpoint).
- Upstream carries a large `[Unreleased]` changelog including this feature; no release tag cut (owner decision pending).

### Did I lie / overshoot?

- No false completion claims: "fix it" was reported as **blocked**, not done. No pushes (origin already had the endpoint — pushed by a parallel session, verified before acting). No forced deploy. One imprecision: my first answer's "it IS integrated" implied health it did not have (see forgot #1) — corrected in turn 2, but it should never have needed correcting.

---

## a) FULLY DONE

1. **Turn-1 diagnosis** — Waybar retired 2026-06-24 (`5b13b4d3` deleted `waybar.nix`); the bar is DankMaterialShell via Quickshell; the emeet-pixyd integration is the `systemnix-camera` DMS plugin wired at `platforms/nixos/desktop/quickshell.nix:156` (`daemonUrl` → `127.0.0.1:8090`). Upstream's `waybar.go` output mode is vestigial on this machine.
2. **Turn-2 delta analysis** — upstream "first-class support" = `GET /api/status` (handlers.go:445 at origin tip; always-200 while daemon runs so widgets can tell daemon-down from camera-offline) + website guide `website/src/content/docs/guides/quickshell.mdx` whose ready-to-paste widget is essentially identical to our plugin (the guide even cites the systemnix-camera declarative pattern). Found the widget↔endpoint mismatch: locked rev `1a7b698d` predates the endpoint; **live probe of `/api/status` returned 404** → widget's `curl -sf` fails every 8s → `daemonUp=false` → permanent grey "off".
3. **Lock bump** — `nix flake lock --update-input emeet-pixyd`: `1a7b698d` → **`1535ddf`** (origin tip, carries the endpoint; deliberately NOT the unpushed `8c7b0ee` — a concurrent session's in-flight go.mod/go.sum churn). Committed by the daemon in heuristic batch `c180144e` (contents not yet `git show`-verified — see forgot #2).
4. **Package build gate** — `nix build .#emeet-pixyd` against `1535ddf`: **clean, no go-modules FOD drift** (the class that repeatedly broke deploys; the stale services.md claim "emeet-pixyd go-modules FOD broken" is now healed at this rev).
5. **Eval gate** — `nix flake check --no-build`: all checks passed (expected aarch64-darwin omission only).
6. **Deploy-block diagnosis** — pre-deploy checks 71 passed / 16 warnings / 0 failed, then the memory-pressure gate blocked: io PSI some avg10=35.35% with idle disks (3.6%). Verified against `/proc`: NOT a corpse pile — 2 PMA `git add` processes in D on btrfs `write_all_supers`/`wait_log_commit` + two parallel sessions running `nix flake check` + tq-ladder + a bun smoke test = real fsync/eval load on the QLC root. **Chose wait-over-force** per the crash-class doctrine.
7. **Drain monitoring** — 4.5-min PSI poll: avg10 46.7→32.6→42.6→38.1→21.3→24.7; avg60 collapsed to <6 at the end; D-procs 0 at most samples. Confirmed transient load, not a stuck mount.

## b) PARTIALLY DONE

1. **THE FIX** — code side complete (lock + build + eval all green), **deploy not executed** (blocked by gate, then this status request interrupted). Note: the toplevel build with the new lock is **unexercised** — the deploy died at the pre-deploy pressure gate, before nh built the toplevel. Until a deploy runs, the daemon still 404s `/api/status` and the widget still shows "off".
2. **Lock-bump attribution** — rode heuristic daemon commit `c180144e`; not pathspec-committed by me, not `--stat`-verified (pending, §f.5).

## c) NOT STARTED

1. Post-deploy verification chain: `/api/status` → 200 + camera JSON; `version` field proves the user unit restarted onto the new binary; eyeball the DMS camera pill (tracking/idle/privacy instead of grey "off").
2. Widget enhancements (click actions, battery/model tooltip) — owner-scope question pending (§g.3).
3. Runbook update (`docs/services/emeet-pixyd.md`: `/api/status` contract + the grey-"off" failure mode).
4. Upstream release cut (tag + CHANGELOG `[Unreleased]` → release) — owner decision (§g.2).
5. TODO harvest of this report — **done now** (§f rows landed in queue + services/stability libraries).

## d) TOTALLY FUCKED UP

Nothing destroyed, nothing wrongly pushed, no secrets touched, no force-deploy. The worst honest entries, already owned above: the runtime-blind first answer; the mislabeled PSI columns; two banned-tool attempts; one wasted pre-deploy pass that a 2-second PSI pre-check would have avoided.

## e) WHAT WE SHOULD IMPROVE

1. **"Answer the question asked" extends to runtime** — "is X integrated" deserves a live probe, not a config grep. This is the same lesson as the 2026-09-18 browser-history gate: the variable separating the two answers (here: does the served daemon have the endpoint) is exactly the one to check.
2. **Pre-flight PSI read before any deploy attempt on this shared box** — the gate enforces correctness; a habit of checking first saves whole deploy passes under multi-session load. (Consider: cheap `scripts/` helper or just discipline.)
3. **Daemon-sweep verification is not optional** — `git show --stat` after the daemon commits my artifact; do it at sweep time, not report time.
4. **Evidence loops need label discipline** — instrumentation written in a hurry (duplicate/mislabeled columns) undermines the very verdict it collects.
5. **Stale FOD claims in todo libraries cost attention** — services.md still asserts the emeet-pixyd go-modules FOD is a standing deploy blocker; it builds clean at `1535ddf` (proven this session). The FOD-wave row should be re-verified/pruned in the next docs-health pass (not edited by me — not my item, parallel ownership).
6. **The widget's failure mode is silent by design** — grey "off" is indistinguishable from "camera off". Post-deploy, the widget could distinguish daemon-down from camera-offline (the endpoint exists precisely for this; upstream guide's widget does it via `daemonUp`). Folded into the widget-parity item.

## f) Next (impact-sorted; harvested per TODO contract)

1. **Retry `nix run .#deploy` at a PSI-quiescent window** (io avg10 < 20; at 09:57 it was **55.28 and rising** — parallel sessions still grinding). This single step completes the fix.
2. **Post-deploy verify `/api/status`** — fetch `127.0.0.1:8090/api/status` → expect 200 + `camera`/`online`/`version` JSON; `version` proves the user unit picked up the new binary (unit is `WantedBy`/`PartOf=graphical-session.target`; switch restarts changed user units — unverified assumption, the version field is the probe).
3. **Confirm the DMS camera pill** shows real state (owner eyeball or screenshot) — the user-visible end of the whole chain.
4. **`git show --stat c180144e`** — verify what rode the heuristic commit carrying the lock bump.
5. **Ride the same deploy window:** the already-queued emeet-pixyd registry live-verify (TODO_LIST 577 / services.md:181) — same generation, same graphical-session requirement.
6. **Widget parity** (harvested, `[ready]`): click actions per the upstream guide table (L: toggle-privacy, R: toggle-auto, M: center) + battery/model tooltip from `/api/status`.
7. **Runbook** (harvested, `[ready]`): document `/api/status` + the grey-"off" failure mode in `docs/services/emeet-pixyd.md`.
8. **Upstream release cut** (harvested, `[decision]`): emeet-pixyd `[Unreleased]` → tagged release (Quickshell support + the big HID/protocol changelog); flake tracks `ref=master` so not blocking.
9. **PSI watch** (harvested, `[watch]`): if io PSI avg300 stays ~60+ once sessions quiesce, that is a stability-domain investigation (QLC fsync wall vs. something new).
10. **Monitor the concurrent emeet-pixyd session** — repo was `ahead 3` again at 09:57 (go.mod/lock churn mid-flight); its landing must stay build-consistent for the next SystemNix bump.
11. **docs-health pass:** prune/re-verify the stale "5 FOD drift" claims in services.md after the next successful deploy proves them healed.
12. **Consider (LOW):** silent Gatus check for `/api/status` next to the two existing silent endpoint checks — probably a no-op (the session-aware meta check already owns paging); note-only, do not build without a reason.

## g) Questions I cannot answer myself

1. **Deploy timing/authorization:** PSI is worse now (avg10 ~55, avg300 ~66; two parallel sessions mid-eval, hermes active). Should I poll for a quiescent window and auto-fire `nix run .#deploy` (restarting hermes and draining in-flight sessions), or do you want to fire it yourself / pick a window? (DEPLOY_FORCE_PRESSURE=1 is on the table but I recommend against it under this load.)
2. **Cut an emeet-pixyd release now** (tag + CHANGELOG cut — the `[Unreleased]` section is large and includes this feature), or keep shipping off `master` untagged as today?
3. **Widget scope:** keep `systemnix-camera` minimal (state text only), or upgrade to full guide parity (click actions + battery/model tooltip)?

---

_Report format note: written as `.md` per explicit user instruction — the status-report skill's HTML default was deliberately overridden for this one-off._
