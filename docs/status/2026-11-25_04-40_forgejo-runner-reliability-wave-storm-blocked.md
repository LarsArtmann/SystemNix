# Forgejo-Runner Reliability Wave — coded + eval-green, deploy storm-blocked overnight

**Session:** 2026-11-24 ~23:47 → 2026-11-25 04:40 (evo-x2, concurrent foreign sessions throughout)
**Trigger:** owner question "Why is not at least 1 forgejo-runner not always available?" → answer delivered → owner directive **"Make it more reliable!"**
**HEAD at authoring:** `cd85d2b01` (tree clean; my wave committed in daemon sweep `d38466003` at 23:59:25)
**Deploy state:** still **gen-1029** (`gwfgxm1vy9`) — the wave is INERT until a switch lands.

---

## a) FULLY DONE

1. **Availability-model answer** (question phase): one runner in the whole fleet (`forgejo-runner-evo\x2dx2.service`, labels `[native]`, capacity 2, Restart=on-failure, 5-min ensure timer); four historic stop classes (ordering-cycle, crash-loop, manual/ensure, mount-stop propagation) cited from docs/services/forgejo.md:603-714 with live journal evidence: the runner was dark 23:38:29→23:41:48 (3m19s) inside the gen-1029 attic switch, restarted 21:51:43 by the gen-1028 switch — per-deploy restarts are the norm.
2. **Reliability wave coded** (modules/nixos/services/forgejo.nix, 3 edits):
   - `runner.shutdown_timeout = "60s"` (was `0s` — every switch stop force-cancelled in-flight CI tasks) + `TimeoutStopSec = "120s"` so the drain is never SIGKILLed mid-wait.
   - `Restart = lib.mkForce "always"` + `RestartSec = lib.mkForce "5s"` (mkForce REQUIRED: the v13 nixpkgs module sets on-failure/10 PLAIN at forgejo-runner.nix:511 — source-verified in the store copy) — closes clean-exit deaths in ~5s; systemd never auto-restarts manual/stop-propagated stops, so the ensure timer stays the recovery path for those.
   - Ensure timer 5min→**1min** (`OnBootSec=2min`, `OnUnitActiveSec=1min`, `AccuracySec=15s`) — worst-case dark after an unexpected stop drops from ~6 min to ~75s.
3. **Eval verification:** `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` **GREEN at 00:06** (drv `9hks5rxnryd8…`). `nix fmt` clean (0 changed).
4. **Docs:** runbook gained "Reliability posture (2026-11-24)" (docs/services/forgejo.md, convergence-not-redundancy table + by-design windows + MASK doctrine); CHANGELOG entry prepended.
5. **Harvest:** 2 new rows appended to docs/todo/services.md + mirrored TODO_LIST.md one-liners (deploy [blocked:deploy], verification [watch]) — self-harvest declaration in §h.
6. **Deploy attempt + overnight watcher:** first fire 00:04 refused by deploy.sh's entry PSI gate (real IO storm). Hand-rolled PSI watcher armed 00:03 (verdict log `~/.local/state/forgejo-rel-deploy-watcher.log` per the persistence convention), timed out at 02:03 after 120 polls, re-armed 02:03 with a 4h horizon — **still running** (poll 152 at 04:35, `calm_streak=0` the whole night). It did NOT force; zero overrides of the stability gate.

## b) PARTIALLY DONE

1. **The deploy itself** — everything is committed and eval-green but ZERO of it is live: `busctl` still reports `Restart=on-failure`; rendered timer still 5min/5min/1min; `connection-config.yaml` has no `shutdown_timeout` line; system still gen-1029. Three-blocker stack, all diagnosed:
   - **PSI storm** — avg10 32-54% continuously 00:03→04:40+ (worst single stretch: 20+ polls never below 32%); gate's own attribution: top stalled cgroups = `app-niri-ghostty-1381229.scope` (user-1000, owner's interactive terminal), nvme1n1 54.5% util bursty; NO build battery visible via pgrep (nix/cargo/go/duckdb all negative).
   - **library-policy stale vendorHash** (foreign wave, NOT mine) — the 01:35 foreign deploy died: `library-policy-e092b400-go-modules.drv` hash mismatch (specified `gYkU…` vs got `UCnK…`) cascading through man-paths → system-path. Already fully documented + queued by the supplements session (TODO_LIST [blocked:push] row; local library-policy HEAD a60fda4 carries the fix UNPUSHED, session 1225951 owns the push). I did not touch it (foreign-authored).
   - **Pre-deploy battery blockers** (03:15 foreign attempt): 5 `loaded failed` units at battery time; live-probed 04:38 — `audiblesync-backup`, `forgejo-github-sync`, `inboxclean-sync`, `service-health-check` still **failed**, `media-atlas-poll-embeddings` inactive/dead. Mapped to EXISTING rows (inboxclean OAuth re-consent [blocked:user]; forgejo-github-sync = the reinterval-mirrors permanent-offender exit-1 contract; service-health-check metastable-red by design listing the others) — no new rows; audiblesync-backup has no dedicated row (falls under the failed-unit census row).
2. **Eval reproducibility** — the 00:06 GREEN eval is the proof the tree compiles, but a re-probe at 04:40 hit the intermittent nix store race AGAIN ("store path …was hashed to avoid a full copy…, contents have changed", evaluating `systemd.services.signoz-provision.unitConfig`) — second occurrence tonight (00:05 first), both under full storm + concurrent foreign evals; the 03:15 foreign log shows the same eval degradation (`toplevel --dry-run eval failed — §1 flake check owns the eval error`). Tree-side eval health is therefore UNPROVEN at this minute — the 00:06 pass says the content is fine; the race is environmental, but it will also bite the next real deploy under load.

## c) NOT STARTED

1. **Deploy of the wave** — blocked per §b; watcher armed (fires `nix run .#deploy` after 3 consecutive calm polls <20% avg10+avg60).
2. **All post-deploy verification legs** (queued [watch]): Restart=always property; rendered `shutdown_timeout: "60s"` + journal drain line; timer 2min/1min/15s; same-PID across next switch; measured dark window vs the 3m19s baseline; Restart-vs-MASK live behavior on first deliberate mask.
3. **Owner answers from the attic session** (unchanged, queued): residue deletion [blocked:root], wildcard doctrine reconciliation [ready], smoke-red triage.
4. **True HA** (second runner on a second host) — not designed, not started; needs owner decision (§g3).

## d) TOTALLY FUCKED UP

**Nothing I authored broke.** Honest near-misses and defects, ranked:

1. **Deploy never landed** — the directive "Make it more reliable!" is still INERT on the box 4h40m later. Every blocking layer was external (storm gate, foreign vendorHash, foreign failed-units), but the outcome is: zero behavioral change live.
2. **Hand-rolled watcher reinvented the productized path** — `scripts/deploy-when-quiescent.sh --fire` already exists (rc-classified loop-back, §0.5 quiescence probe, disarm-list). My watcher gates ONLY on PSI, not on eval-relevant mtimes/tree dirt — if a foreign session had edited mid-storm, my fire would have run against a moving tree (deploy.sh's own §0.5 is WARN-only; the §11 tree-stamp void risk was live). It also fired nothing (no calm window), so the gap never materialized.
3. **Watcher launcher `$?` misattribution** — the launcher echoed `rc=42` (stale exit status from a prior command) making the launch LOOK failed; the detached loop was in fact alive. Cosmetic, but for ~30s I distrusted my own instrumentation instead of checking the log first.
4. **Two eval attempts (00:05, 04:40) died on the store race** — cost ~6 min; not controllable, but I burned the second one at 04:40 knowing the storm was still full-on; I could have skipped re-probing and cited the 00:06 pass + foreign §11 degradation instead.
5. **First eval raced mid-daemon-commit** — I started the eval seconds after the 23:59:25 sweep landed; sequencing evals off daemon-commit boundaries is luck, not method.

## e) WHAT WE SHOULD IMPROVE

1. **Use `deploy-when-quiescent.sh --fire` for overnight arming** — retire hand-rolled PSI watchers; the productized script carries the quiescence checks mine lacks.
2. **Night-storm attribution discipline** — a 4h+ PSI storm with no visible build process deserves the /proc forensics pass (per-cgroup io.pressure, /proc/<pid>/start-times) BEFORE re-arming watchers, not after; tonight's ghostty-scope attribution came only from the gate's own output.
3. **The eval race needs a name** — twice tonight, same signature (`…hashed to avoid a full copy…contents have changed`) under storm + concurrent evals; characterize (nix dedup vs concurrent evals vs daemon writes) or the next deploy window will burn time re-deriving it.
4. **Keep-alive doctrine comment is stale** — forgejo.nix:1584 still says "converges all three within one cadence"; there are four stop classes and the cadence is now 1min; runbook's older keep-alive section likewise — one consistency pass post-deploy.
5. **Sentinel-of-the-sentinel** — tonight `service-health-check` itself was failed while 4 units were failed: the notifier is blind exactly when it matters. A dead-man's-switch heartbeat (textfile timestamp + gatus "staleness" rule) closes the metastable blind spot.
6. **Verified-claims ledger for the wave** — exactly ONE claim is doc-derived not source-verified (act_runner v13.2.1 `shutdown_timeout` duration-string acceptance); keep that pattern explicit per change: what's proven, what's pending render-time proof (the §c watch row encodes it).

## f) UP TO 50 THINGS TO GET DONE NEXT

*Grouped; [H] = harvested to queue this session, [NH] = deliberately not harvested with reason.*

**Deploy unblock + wave verification**
1. [NH foreign-owned] library-policy 5-commit lineage push (session 1225951) → then `nix flake update library-policy` — THE deploy unblock; already queued [blocked:push].
2. [H] Deploy the forgejo-runner reliability wave (rides the same switch as supplements-weekly-print).
3. [H] Post-deploy verification legs ×6 (Restart property; shutdown_timeout render + journal; timer cadence render + tick; same-PID across switch; measured dark window; Restart-vs-MASK).
4. [NH: duplicate] Deploy supplements-weekly-print wave + first-fire watch Mon 2026-11-30 — already queued.
5. [NH: pre-existing] Boot-transaction leg of the ordering-cycle fix (docs/services/forgejo.md:666 "Boot-time verify still pending since gen-955") — next reboot must show zero cycle deletions + runner pulled via forgejo.service.wants.
6. [NH: post-deploy] Full post-deploy-check battery in a CALM window (the storm-degraded-baseline class, pipeline.md:651).
7. [NH: routine] Re-stamp README/FEATURES service + gatus counts at the next close-out (foreign modules added tonight; counts drift since my 156/319 stamp).

**Runner / CI reliability**
8. [NH: owner-gated] Second runner on a second host = true HA (§g3) — currently single-point-of-failure by design.
9. [NH: idea] CI-level retry for long host-mode jobs — shutdown_timeout=60s cannot save >60s nix builds across a switch stop; retry belongs in hub build.yml (retry/continue-on-error policy).
10. [NH: needs ORG] "Jobs stuck = runner wedged" Gatus check — route live but needs a real ORG token (forgejo.md:503); the runner-wedged signal still does not exist.
11. [NH: idea] Runner liveness canary — act_runner has no metrics endpoint (forgejo.md:485); a textfile `forgejo_runner_last_poll_seconds` heartbeat would make silent wedge visible to gatus/SigNoz.
12. [NH: pre-existing] Escaped-unit-name helper for runner probes (pipeline.md:1036 row, open since 2026-11-04).
13. [NH: decision] ubuntu-latest jobs queue forever by design (labels `[native]` only) — either document in workflow templates or add a label-lint to hub build.yml so authors stop discovering it at queue time.
14. [NH: micro-decision] Ensure-timer MASK noise: at 1-min cadence a deliberate MASK now logs a failed start per tick — accept documented noise or add a mask-state condition guard to the ensure script.
15. [NH: idea] Evaluate systemd `RestartSteps`/`RestartMaxRetries` (systemd 262) as a cleaner crash-loop shape than start-limit-hit + ensure reset-failed dance.
16. [NH: doc] Forgejo.md + forgejo.nix keep-alive consistency pass (cadence 1min, four stop classes) post-deploy.

**Deploy infrastructure / storm aftermath**
17. [NH: diagnose] Characterize the nix store eval race (`hashed to avoid a full copy…contents changed`, 2× tonight) — nix dedup vs concurrent evals vs daemon writes; write the gotcha into docs/agents/nix-flakes.md once named.
18. [NH: triage] `audiblesync-backup.service` failed — storm victim vs broken; fold into the failed-unit census row (services.md:959) or split a dedicated row after journal read.
19. [NH: process] Storm-wait policy: who may say `DEPLOY_FORCE_PRESSURE=1` and when (owner-only, explicit per wave — doctrine stays).
20. [NH: process] Retire ad-hoc overnight watchers in favor of deploy-when-quiescent.sh (e1).
21. [NH: watch] My 4h watcher (job 05A) expires ~06:03 — either extend/re-arm or hand the fire to the owner/next session; verdict log: `~/.local/state/forgejo-rel-deploy-watcher.log`.
22. [NH: process] Persist foreign-deploy-failure triage: tonight's 01:35/02:01/03:15 failures were discoverable only via `/var/log/systemnix-deploys/` — consider a gatus/SigNoz signal on `deploy exited code≠0` (deploy logs are currently unmonitored).

**Attic decommission carry-overs (earlier in this session, all queued)**
23. [NH: root] Residue deletion timing (empty `/mnt/pool/services/atticd` subvol + `/var/lib/atticd` sqlite) — [blocked:root] row.
24. [NH: queued] Wildcard doctrine reconciliation (deployed `*.home.lan` record vs DOMAIN_LANGUAGE.md) — [ready] row; also my §g2.
25. [NH: queued] Removed-unit-process-survives-switch trap pin — [ready] row (atticd orphan class).
26. [NH: owner] Smoke-red triage dispatch from the attic report §g.

**Live-unit health (existing rows, restated for the morning triage)**
27. [NH: queued] inboxclean-sync OAuth re-consent (invalid_grant) — [blocked:user].
28. [NH: queued] forgejo-reinterval-mirrors N-strike de-escalation (permanent offender keeps service-health-check red).
29. [NH: queued] Failed-unit census row (services.md:959) — absorb tonight's new names.
30. [NH: new-but-tiny] Dead-man's-switch heartbeat for service-health-check itself (e5).
31. [NH: verify] media-atlas-poll-embeddings inactive/dead — confirm benign (no P0) rather than a fourth casualty.
32. [NH: verify] forgejo-github-sync current failure offender — which repo is the 500 this time (row 415 pattern).

**Hygiene (small, session-adjacent)**
33. [NH: doc] AGENTS.md session-discipline: add "arm deploys via deploy-when-quiescent.sh, not hand-rolled watchers" once e1 ratified.
34. [NH: doc] Record tonight's storm window in the stability freeze ledger only if it turns out freeze-adjacent (PSI 50% for 4h without a freeze is itself notable data).
35. [NH: micro] Watcher log rotation — `~/.local/state/*-watcher.log` grows unbounded (152+ lines tonight; trivial).
36. [NH: micro] The `rc=42` launcher bug — if the watcher pattern gets reused, fix the `$?` capture (e3 adjacent).
37. [NH: idea] Timer `RandomizedDelaySec` on the ensure timer so a deploy storm doesn't align ensure ticks with switch instants.
38. [NH: idea] Per-repo Actions concurrency limit on the forgejo side so a push storm can't queue >capacity jobs that then all die at a switch.
39. [NH: verify] After the wave deploys, confirm `log.level=debug` does NOT add per-tick journal volume from the 1-min ensure (tick itself is silent; runner start lines only on actual convergence).
40. [NH: idea] Re-evaluate `shutdown_timeout` upward (e.g. 120s) ONLY if post-deploy data shows jobs dying in the 30-60s band — drains trade against switch latency.

*(40 items; 2 harvested this session, 38 deliberately not — each tagged with its gate: foreign-owned, owner-gated, queued-elsewhere, or idea-stage.)*

## g) THREE QUESTIONS I CANNOT ANSWER MYSELF

1. **The storm:** the deploy gate has refused for 4h40m with the stall inside YOUR ghostty terminal scope (`app-niri-ghostty-1381229.scope`) and no visible build process — do you know what's running there, and do you want me to (a) keep waiting (watcher armed to ~06:03), (b) re-arm indefinitely, or (c) you explicitly authorize `DEPLOY_FORCE_PRESSURE=1` for this wave?
2. **Wildcard DNS doctrine (still open from the attic report):** the DEPLOYED dnsblockd config carries a `*.home.lan → 192.168.1.150` wildcard while DOMAIN_LANGUAGE.md says wildcards are unsupported and a localSubdomains list is required — which is the intent, and does a correct wildcard make the 27-entry localSubdomains list redundant?
3. **HA appetite:** "at least 1 runner always available" can only be truly guaranteed with a second runner on a DIFFERENT failure domain — do you want one (on which host — the MacBook is 90% full and darwin-runner is untested), or is bounded convergence (worst-case ~75s dark after the wave deploys) the accepted posture?

## h) SELF-HARVEST DECLARATION

- Harvested this session: §f.2 → docs/todo/services.md + TODO_LIST.md ([blocked:deploy]); §f.3 → same files ([watch]).
- Deliberately NOT harvested: §f.1, 4, 23-26, 27-29 (already queued verbatim — cited rows); §f.5-7, 16, 19-22, 30-32, 33-40 (post-deploy legs ride §f.3's watch row, or process/idea-stage items awaiting the owner verdicts in §g); §f.8-15, 17-18 (owner-gated, needs-ORG, or diagnosis-first — queueing premises I cannot verify yet would violate the spot-verify rule).

---

*Machine: evo-x2 · Live system: gen-1029 `gwfgxm1vy9` · Wave commit: d38466003 · Watcher: armed, job 05A, expires ~06:03 · Authored 2026-11-25 04:40*
