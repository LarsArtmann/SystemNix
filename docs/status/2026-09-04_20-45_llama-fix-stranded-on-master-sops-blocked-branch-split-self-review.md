# Status: llama-rag fix stranded on master — deploy blocked by foreign sops key, tree switched to feature branch mid-wait (self-review)

**Date:** 2026-09-04 20:45 · **Session:** continuation of the 2026-09-04 llama-rag/amdxdna-wedge session · **Host:** evo-x2 (192.168.1.150)

---

## Executive summary

The llama-server fix (device cgroup denying `/dev/accel`, stuck-D tripwire metric, Gatus check, metric loan) is **code-complete, committed, eval-clean, and verified to render correctly — but UNDEPLOYED and now STRANDED ON MASTER**: the shared working tree was switched to the `forgejo-hermes-agent` branch (fork point `b8587cea`, before 16:04) by another session while I waited, so the working tree currently contains **NONE** of the fix. Meanwhile deploys from master are blocked tree-wide by a missing sops key (`browser_history_agent_db_token`) from a third session's browser-history go-live. The box still runs with **23 unkillable llama-server corpses**, RAG dark (2+ days), `flm-real` zombie, phantom IO PSI.

Everything I touched this session is safe and verified. The session's real failures were **situational awareness gaps**, detailed below.

---

## a) FULLY DONE (this session)

1. **Todo list reconstructed** — 6 completed items from the prior session carried forward; state tracked throughout.
2. **Tree state verified** — confirmed all 7 fix components present and committed by the auto-commit daemon (deviceCgroup in `lib/rocm.nix:35`, applied at `llama-rag.nix:266,294`, ollama revert intact as comment at `ai-stack.nix:117`, metric emission at `system-health.nix:1044-1046`, Gatus check at `gatus-config.nix:326`, loan at `pre-deploy-check.sh:466`).
3. **Strict eval re-run after ollama revert — PASSES**: `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` → `5lhcxzvy…-nixos-system-evo-x2-26.11.20260831.34ab990.drv`. The DevicePolicy conflict from deploy #2 is gone.
4. **Fix rendering verified at eval level**: `llama-embeddings` AND `llama-reranker` both render `DevicePolicy = "strict"` with `DeviceAllow = ["/dev/null","/dev/zero","/dev/full","/dev/random","/dev/urandom","/dev/dri/","/dev/dri/renderD128","/dev/kfd"]` — no `/dev/accel` anywhere.
5. **Deploy #3 attempted** (`DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`) — correctly refused by the deploy lock because another deploy (started 17:04 by user/another session) was live. Did NOT stack a second deploy or kill the lock holder — correct behavior.
6. **Root-caused the 17:04 deploy's build failure** using the repo's `--keep-going` rule (one pass, one root failure): `sops-install-secrets: manifest is not valid: secret browser_history_agent_db_token … key cannot be found`. It is the browser-history session's go-live wiring (commit `1b690fad`, 16:33) referencing a sops key whose value only the user can mint (browser-session `POST /agents/token` + `sudo sops` paste). NOT my code; nothing of mine failed.
7. **Concurrent-session hygiene**: read the other session's full wiring diff before acting; did not revert, edit, or race their files; asked the user how to unblock instead of inserting a placeholder into their secret myself.
8. **User decision obtained**: wait for the other session to complete its own go-live (placeholder option was available and within my power — sudo works — but was declined).
9. **Watcher maintained** across ~105 minutes (two runs + state snapshots): no sops key, no new deploy, no llama listeners, other sessions actively committing.
10. **Two significant discoveries documented in this report**:
    - **The shared tree is on branch `forgejo-hermes-agent`** (fork `b8587cea` < 16:04, 19 branch commits, master tip `6184f9ce` 17:30). Master-only commits (my ENTIRE fix + browser-history sops wiring + inboxclean changes) are ABSENT from the working tree. A deploy from this checkout would ship WITHOUT my fix — and would NOT hit the sops blocker (the wiring is master-only too).
    - **`lars` has full passwordless sudo**: `sudo -n -l` → `(ALL : ALL) SETENV: NOPASSWD: ALL`. This contradicts repo lore ("sudo blocked in session", "USER-RUN (sudo blocked in session)") and is security-relevant (any agent session can become root).

## b) PARTIALLY DONE

1. **Deploy of the llama fix** — everything up to the switch is done (eval ✓, render ✓, root-cause of blocker ✓); the activation itself is blocked twice over: (a) master deploys need the missing sops key, (b) the working tree is on a branch that lacks the fix entirely.
2. **Stuck-D tripwire end-to-end** — metric + Gatus check + loan are coded and committed (master), but not live on the box; post-deploy steps (metric-live confirmation, loan retirement, red-until-reboot behavior) pending.
3. **"Wait for the other session" instruction executed** — but the wait acquired an unmanaged failure mode (the branch split) that I detected late (see d).

## c) NOT STARTED

1. Post-deploy verification: 2 live llama servers, `:8848/:8849` LISTEN, RSS >1GB (weights loaded), ROCm/GPU residency in journal (not CPU fallback).
2. RAG functional smoke: 1024-dim embeddings + correct rerank order; Paperless-AI semantic search end-to-end.
3. Metric-live confirmation + **retiring the `KNOWN_NEW_METRICS` loan** (set back to `""` — mandatory, "one-deploy loan, not a museum").
4. Reboot-window verification: stuck-D = 0, Gatus green, flm cold-loads on unwedged NPU, load avg sane, GTT ~1-2 GB per llama server.
5. Optional follow-ups (carried): sev1-bridge notify-tier wiring for stuck-D; PSI-distrust logic in deploy gate / memory-emergency-guard; VM test asserting `DevicePolicy=strict` renders on both llama units.

## d) TOTALLY FUCKED UP (honest accounting — all awareness/process, nothing destructive)

1. **74 minutes blind to the branch switch.** The auto-commit messages carried the suffix `on forgejo-hermes-agent` starting 18:34; I displayed them in my 19:26 snapshot and did NOT investigate. I only chased it at 20:40 when preparing this report. The watchers polled for deploy triggers but never checked TREE IDENTITY (branch/HEAD drift). Consequence: my mental model ("the tree contains my fix, any deploy ships it") was silently wrong for over an hour. This is the exact class AGENTS.md warns about ("verify evals of shared surfaces only at quiescent moments", "a NEW module file on disk that is not git add'ed makes EVERY evo-x2 eval fail") extended to branch identity.
2. **First watcher false-triggered in 1 iteration** — I compared `ls -t` (mtime order) output against a filename baseline. The 17-04-15 deploy log was always mtime-newest, so the trigger fired immediately on a stale file. Sloppy ordering-semantics mixup; fixed by filename sort, but cost a round trip and shows the watcher was written carelessly.
3. **105 minutes of passive sequential polling with zero escalation.** Two back-to-back watcher loops consumed the session doing nothing actionable. Better: one state-aware monitor (branch, HEAD, sops key, deploy logs, listeners, llama proc count) with immediate user escalation on ANY drift — the branch drift would have surfaced at 18:34, not 20:40.
4. **The sudo discovery was not reported immediately.** Finding `NOPASSWD: ALL` is security-relevant and contradicts documented assumptions; it sat in my session notes instead of being flagged to the user the moment it was measured (~18:39).
5. (Carried, not mine to fix tonight) **The box's actual outage continues**: 23 llama-server corpses (was 20 at session start — 2-3 more stranded by restarts), 0 listeners, RAG dark ~2 days, `flm-real` zombie, phantom IO PSI still polluting the deploy pressure gate, Gatus alerting the whole time.

## e) WHAT WE SHOULD IMPROVE (systemic, from this session)

1. **Branch-switch tripwire for the shared tree.** A pre-deploy (or watcher) check: `git branch --show-current` == expected branch (master) — or at minimum a loud WARN when the checkout is not the branch that last deployed. Tonight's hazard: a branch deploy would silently ship WITHOUT master's afternoon (my fix + browser-history fix + inboxclean) — the "Deploy generation mismatch" gotcha, now in branch form.
2. **Pre-deploy gate gap: eval passes while the sops manifest build fails.** §2 (drvPath eval) was green at 17:12; the manifest `.drv` failed at 17:18. A cheap `nix build` of the sops manifest derivation (or a grep that every `sops.secrets` key referenced in templates exists as a plaintext key line in the encrypted file — key names are visible without decryption) would catch the "mid-go-live secret reference freezes ALL deploys" class before the slow `nh` build.
3. **Document that referencing a not-yet-pasted sops key is a tree-wide deploy freeze.** The browser-history session wired the key before the value existed; every other session's deploy died on it. Go-live order should be: paste (placeholder at minimum) → wire → deploy. Placeholder-first is established repo doctrine (mail-relay, hermes PAT, google-sync).
4. **Watcher/monitor discipline for agents: watch STATE, not single variables.** Branch, HEAD, key files, logs, runtime signals — anything that invalidates the premises of the current plan should interrupt the wait, not wait for the wait to end.
5. **AGENTS.md lore update on sudo.** Either the NOPASSWD grant is new (→ security review: every crush session is root-equivalent; secret-hygiene assumptions like "agents can't read `/var/lib/private/*`" are false) or the lore is stale (→ fix the lore). Either way the docs and reality must converge. Not changed by me — user decision.
6. **Multi-session coordination protocol is thin.** Three sessions (llama fix, browser-history go-live, forgejo-hermes-agent branch) shared one checkout tonight. The lock file protected deploys, but nothing protected *what* a deploy ships. A lightweight "deploy intent" note (who plans to deploy, from which ref) would prevent tonight's triangle.

## f) NEXT — up to 50 things, grouped by phase

**Unblock + deploy (order matters):**
1. Confirm with the forgejo-hermes-agent session: merge or switch-back plan; NEVER deploy from the branch until master's afternoon commits are in it (my fix + browser-history + inboxclean).
2. Return the shared checkout to master once their session is done (`git switch master`; verify tip `6184f9ce`+).
3. User pastes `browser_history_agent_db_token` (mint via browser-history Agent Tokens UI; `sudo sops platforms/nixos/secrets/browser-history.yaml` FROM REPO ROOT).
4. Re-run `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` on master tip (tree moved since my 17:05 eval).
5. `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` first if anything fails (repo rule).
6. Deploy: `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` (pressure gate still polluted by phantom IO PSI until reboot; escape hatch is the sanctioned path for deploying the fix).
7. Confirm deploy log shows §10 treating `system_stuck_dstate_processes` as known-new WARN, not FAIL.

**Post-deploy verification (my fix):**
8. `pgrep -af llama-server` — corpses PLUS exactly 2 new processes.
9. New procs' RSS >1GB each (weights actually loaded, not wedged pre-bind).
10. `ss -ltn | grep -E ':8848|:8849'` — both LISTEN.
11. `journalctl -u llama-embeddings -n 50` — ROCm/HIP init lines present (GPU residency; if CPU fallback, a DeviceAllow entry is missing — iterate).
12. RAG functional smoke: `/v1/embeddings` returns 1024-dim vector; `/v1/rerank` ranks correctly (post-deploy-check does this — confirm section green).
13. Paperless-AI: trigger a document re-analysis / semantic search — RAG active again after ~2 days dark.
14. Gatus: llama-embeddings/reranker health checks flip green; alert storm clears.
15. Verify deployed unit files carry the device cgroup: grep `/run/current-system` unit for `DevicePolicy=strict` + `DeviceAllow` (systemctl blocked for me; file reads work).

**Metric + loan retirement:**
16. Fetch `http://localhost:9100/metrics` — expect `system_stuck_dstate_processes` ≈ 21-23 (all corpses counted).
17. Retire the loan: `KNOWN_NEW_METRICS=""` in `scripts/pre-deploy-check.sh` (keep the dated comment trail) — MANDATORY same session as confirmation.
18. Confirm Gatus "Stuck D-State Processes" check exists and is RED (correct until reboot — it IS the reboot signal).

**Reboot window (user-scheduled):**
19. Pick the window (questions below); announce to other sessions (they share the box).
20. Post-reboot: `system_stuck_dstate_processes` = 0; Gatus check green.
21. Post-reboot: `flm` cold-loads on the unwedged NPU (`journalctl -u fastflowlm`, `curl /v1/models` via the socket — post-deploy-check owns it).
22. Post-reboot: load avg drops (~40 points of D-state pollution gone).
23. Post-reboot: both llama servers hold ~1-2 GB GTT each (amdgpu collector metrics).
24. Post-reboot: verify `fastflowlm.socket` activation works end-to-end (first connection cold-loads).
25. Post-reboot: confirm the amdxdna wedge does NOT recur on flm start; if it does, guard interaction (below) becomes P0.

**Detection/monitoring hardening (carried + new):**
26. Guard question (carried, user pending): stop `fastflowlm.socket` when stuck-D > 0 — flm is the process that wedges the NPU driver; stopping the socket prevents re-wedge attempts and enricher re-wakes. User decision.
27. sev1-bridge: wire stuck-D as a `notify`-tier condition (non-overlay, cooldown-gated) — reboot-suggestion reaches the desktop without movie-night violations.
28. Deploy pressure gate: distrust IO PSI when stuck-D > 0 (phantom-PSI class) — treat as WARN + require explicit force, or auto-force with a loud log line.
29. memory-emergency-guard: same PSI-distrust input (Zone inputs polluted by D-state).
30. VM test: `llama-embeddings`/`llama-reranker` units render `DevicePolicy=strict` + DeviceAllow without `/dev/accel` (negative test: adding `/dev/accel` to the list fails or is caught).
31. VM test: device-cgroup actually blocks the open (a unit touching /dev/accel under the policy fails EPERM pre-driver).
32. Consider extending `rocm.deviceCgroup` to any future ROCm consumers (audit: current GPU consumers = ollama (nixpkgs-caged), llama-rag ×2 (mine), paperless-ai (client-side, no device access), flm (NPU — different device, intentionally NOT caged… consider whether flm should also get a device cgroup allowing ONLY /dev/accel to protect it from other classes).
33. flm zombie detection: `flm-real` sat as a zombie with the NPU wedged — the stuck-D metric counts D-state, but zombies (Z) are a different state; consider including long-lived Z in the tripwire or a dedicated check.

**Tree/process hygiene:**
34. Branch-switch tripwire in pre-deploy-check (e): WARN/FAIL when `git branch --show-current` != the ref that owns the deployable config.
35. Sops-manifest build probe in pre-deploy-check (e) — catches missing-key class before `nh`.
36. Sops go-live runbook line in AGENTS.md: placeholder-first wiring order (e).
37. AGENTS.md: sudo/NOPASSWD reality vs lore — after user confirms intent (e).
38. AGENTS.md: this incident's branch-split narrative + rule ("never deploy from a checkout whose branch lacks the deployed baseline"; cheap check in deploy.sh).
39. Watch the forgejo-hermes-agent branch for shared-surface changes before it merges (19 commits unseen by me).
40. After merge/switch-back: re-run full `nix flake check --no-build` on the unified tree (two histories converging).
41. Update TODO_LIST.md with the carried P1s (26-33) — several live only in this report.
42. Confirm the auto-commit daemon's branch behavior is understood (it committed to the feature branch — is that intended? It means uncommitted agent work can land on whichever branch is checked out).

**Runtime state worth watching (noticed, not researched):**
43. llama-server corpse count crept 20 → 23 during the session (restarts still stranding pairs) — after deploy, expect exactly +2 live, corpses unchanged until reboot.
44. Phantom IO PSI persists (blocked deploy #3's gate; will block branch deploys too if they run unforced).
45. Gatus has been alerting on dead llama endpoints ~2 days — post-deploy green flip will produce a resolve wave; PapDashboard insight enricher may wake flm (socket) — harmless now, but expect the alert noise.
46. browser-history attribution: even after the sops paste + deploy, historical `user_id=''` rows need the documented `--full-sync` re-stamp (their session's runbook) — not mine, but it rides the same deploy.
47. The 17:04 deploy log's pressure-gate section was never inspected (forced or clean?) — irrelevant now, but if unforced deploys start passing, the PSI phantom has faded (data point for item 28).

**Bigger-picture (from tonight's triangle):**
48. Consider a per-session "deploy intent" convention (file or Discord line): session, ref, ETA — prevents two-session deploy races beyond what the lock catches.
49. Consider making deploy.sh refuse to run when HEAD is detached/on a non-master branch without an explicit `DEPLOY_BRANCH=` override (ties into 34/38).
50. Retire or archive this status report's predecessors once the fix is deployed + rebooted (docs-health HARVEST pass) — three overlapping llama reports now exist (15:59, this one, and the eventual post-deploy one).

## g) Questions for the user (cannot be figured out from here)

1. **Branch coordination:** the shared checkout sits on `forgejo-hermes-agent` (19 commits, without master's afternoon — including my fix and the browser-history wiring). Who returns it to master and when — the other session after merging, or should I switch back once their session is idle? (I will not touch an active session's checkout unilaterally.)
2. **Reboot window:** the 23 corpses, the amdxdna wedge, `flm-real`, and the phantom IO PSI all clear only on reboot. When do you want it — and should I hold the deploy until just before it so the red-until-reboot Gatus check lives for the shortest time?
3. **Sudo posture:** `sudo -n -l` shows `(ALL : ALL) SETENV: NOPASSWD: ALL` for lars — every crush session is root-equivalent, which contradicts the repo's "sudo blocked in session" lore and several security assumptions. Is this grant intended (→ update lore) or accidental (→ tighten sudoers)?

---

*Report scope: this session only (17:00-20:45). No new research beyond the tree/branch state needed to report accurately. Waiting for instructions.*
