# Status: storage-collector FOD `sed: Permission denied` deploy blocker — root-caused, fixed upstream, shipped, live-verified

**Session window:** 2026-11-15 ~13:20 → 2026-11-16 07:41 (interleaved with heavy parallel activity; several verification points re-checked this morning)

---

## Scope line — what this report VERIFIED vs did NOT

**Verified first-hand this session** (command / artifact named per claim):

- FOD failure root cause: `nix derivation show` on the failing drv + `nix log` (builder text shows `cp -r` of 3 read-only store sources then `sed -i` with no `chmod`; source dir perms confirmed `dr-xr-xr-x` via `ls -ld`)
- Fix landed upstream: `git -C ~/projects/storage-collector show ad7df4d / 4a9360e` (diff read), `branch -vv` shows origin/master == `4a9360e`
- SystemNix lock floated: `python3 json` over `flake.lock` → `storage-collector` locked rev `4a9360e8` (== local upstream HEAD)
- Green proof chain: `nix eval` toplevel drvPath rc=0; `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` → 0 errors in captured log (`~/.cache/systemnix-fix/toplevel-proof.log`), toplevel out path realized; `nix build ~/projects/storage-collector#packages.x86_64-linux.default` rc=0
- Deploy gate: `nix flake check --no-build` rc=0, zero `^error` lines
- Deploy outcome (the parallel session's 13:52 run, log `2026-11-15_13-52-04.log`): exited code=3 at 15:15:52 after 5028s; activation parked ~55 min on post-crash-calm-gate; anchor equality `readlink /run/current-system` == `system-1013-link` (as of 15:1x); `storage-collector-0.2.0` (03zzbm55) present in `/run/current-system` closure; service active/running
- Smoke-failure triage (all 6 re-probed): crm HTTPS **200** (was 303), health-hub /readyz **200** (was 503), crm-server CPU delta **0%** (was >100%), forgejo-runner **active** (timer converged), bank-sync clean 15-min cycles (`published=20 failed=0` through 05:38; `bank_sync_sync_errors_total 1` = single early transient), papdashboard **176 lines/min** benign INFO access logs (was 371)
- Gate refusal state: journalctl shows REFUSE loop from 14:35 (memory-emergency-guard trip window), cap-hit FAIL at 15:07:07 with OnFailure triggered
- This morning (07:41): same boot (`7096665b`), gate still `inactive/dead`, **llama-embeddings still inactive** (gated fleet down ~16h), storage-collector **still active/running** on gen-1015 (`/run/current-system` == `system-1015-link`, anchored)

**NOT verified / out of scope:**

- The 18:02 / 23:34 / 00:34 overnight deploys (gen-1014/1015) — other sessions' work; I only confirmed current-system == newest link and storage-collector live
- The 5 PRE-EXISTING failed units from the paste's §6 (buildcache-gc, forgejo-github-sync, inboxclean-sync, service-health-check, tq-agent-pool) — parallel rows already own verify-or-reset (`docs/todo/services.md` tail)
- Why `nix build` on the zombie drv returned rc=0 once (see §d) — contradiction never fully explained, non-blocking
- Whether the gated fleet (llama-embeddings/reranker/nsfw) has ANY socket-activated consumer impact right now — no endpoint probe attempted

---

## a) FULLY DONE

1. **Root cause, first principles**: prepared-source FOD builder `cp -r`'s read-only store sources into `$out`; dirs land `555`; `sed -i` must create its temp file inside `$out/crates/ui/` → EACCES. The first sed (on `$out/Cargo.toml`) only worked because `$out/` itself was `mkdir`-created (755).
2. **Fix verified upstream**: `ad7df4d` adds `chmod -R u+w $out`; `4a9360e` strips `[workspace]` tables from embedded sibling manifests ("multiple workspace roots" trap). Both authored/pushed by the parallel session; SystemNix lock floated to `4a9360e`.
3. **Proof chain all green** (eval → keep-going toplevel build → package build → flake check gate): every step captured, rc=0, logs under `~/.cache/systemnix-fix/`.
4. **Fix is LIVE**: shipped by the parallel session's 13:52 deploy; `storage-collector-0.2.0` in the live closure and the service running; re-confirmed still running this morning on gen-1015.
5. **Deploy exit-3 smoke triage**: all 6 "new regressions" re-probed after settle — every one stale/benign/converged (details in scope line).
6. **Deploy-park diagnosis**: the 55-min "Activating configuration" hold was the designed freeze-prevention calm-gate refusing under the memory-guard trip window — not a hang; documented REFUSE mechanics read from `modules/nixos/services/post-crash-calm-gate.nix`.
7. **Session-discipline checks**: parallel-session markers pulled (docs/status + upstream repo status), deploy flock holders checked before any deploy consideration, no tree edits made (fix was upstream+floated; nothing to write).

## b) PARTIALLY DONE

1. **Status-report self-harvest**: the one actionable session-owned finding (calm-gate REFUSE → gated AI fleet down this boot, owner re-arm needed) is queued into `docs/todo/services.md` this session; the broader §f list below is deliberately NOT harvested (brainstorm/observations, per routing rules).
2. **Zombie output path mystery**: identified that the failed build left an unregistered store dir (`y7sbdq9g...`, `nix path-info` → invalid) that polluted `ls -t` ordering and once produced a phantom rc=0; diagnosed far enough to ignore, not to a complete mechanism.
3. **Overnight state continuity**: my 15:1x anchor verification (gen-1013) is superseded by gen-1015; current anchor re-verified but the intermediate deploys' own close-outs belong to their sessions (partially covered by existing queue rows).

## c) NOT STARTED

1. **Gated AI fleet re-arm** (llama-embeddings, llama-reranker, nsfw-classifier): still down this boot after the 15:07 REFUSE. Needs owner `systemctl start post-crash-calm-gate` (or next reboot) — agents cannot mutate systemd from this shell. Queued `[blocked:user]`.
2. **Eval warnings triage** (observed on every toplevel eval, pre-existing): `catalog` subdomains-without-catalog-entries warning (23 subdomains), `services.pipewire.jack.enable` deprecation, caddy ghost entries `nsfw`/`llama` (subdomains with no vHost and no registry entry). Untouched — not this session's scope.
3. **Smoke baseline policy**: exit-3 "NEW smoke failures" counted stale-settle noise as regressions; nothing decided yet (see §g Q3).
4. **`nix log` attempt-count visibility**: a FOD that failed N times shows only the last attempt's log; no work done.
5. **Deploy §11 quiescence/storm interplay**: the 13:06 deploy was force-run through a 44% IO storm (user's override), then the same class of storm re-appeared overnight (avg300=60.83% at 07:41); no improvement work started.

## d) TOTALLY FUCKED UP

**Nothing this session broke, and no un-triaged wreckage remains.** Honest near-misses and unexplained residue:

1. **Phantom `rc=0` on the zombie drv** — `nix build` of the known-failing old drv returned rc=0 once with a dangling `-o` symlink; `nix path-info` then proved the output unregistered. Never fully explained (suspect race with the deploy's failed-output cleanup). Non-blocking, but an unresolved observation I'm disclosing rather than hand-waving.
2. **Wasted cycles (mine)**: (a) `nix build <drv-path>` — symlinked the drv instead of building it; should have gone straight to `nix build .#attr`; (b) chased the zombie path for ~4 commands before recognizing failed-build leftovers; (c) `getent ahostsv4` returned `127.0.0.2` and I probed loopback (empty by Caddy bind design) instead of starting from `ss -tlnp`, the documented probe; (d) `${PIPESTATUS[0]}` is dead in mvdan/sh — every `RC=` echo printed empty until I stopped trusting it.
3. **Session-discipline order**: I checked `docs/status/` for parallel-session markers only AFTER extracting the builder. The 10-second grep should have been first — the 13:06 deploy log and same-day upstream auto-commits would have told me immediately that a session was mid-iteration on this exact family.

## e) WHAT WE SHOULD IMPROVE

1. **Probe-set muscle memory**: `ss -tlnp` for bind addresses, `nix path-info` as ground truth for store validity, flake-attr (not drv-path) for builds. Document the `nix build <drv-path>` symlink trap in `docs/agents/nix-flakes.md`.
2. **"Failed build leaves an unregistered store dir"** is a distinct trap from the stale-fetch-cache class: it pollutes `ls -t` sorting and can alias old drvs. Worth 5 lines in nix-flakes.md next to the GC-evicted-drv note.
3. **Prepared-source builders that `sed -i` without a preceding `chmod -R u+w`** are an eval-time-greppable class — same shape likely exists in the other family builders (monitor365, monitor365-ui-sdk, collector-utils). A lint (or upstream audit) prevents the next lock-float landing this in prod eval.
4. **Upstream CI for prepared-source builders**: storage-collector's flake has no CI leg that realizes its own prepared-source; the bug reached SystemNix's deploy gate through a live-floated lock. A 2-minute FOD build upstream would have caught it pre-push.
5. **Smoke exit-3 settle window**: re-probe "NEW smoke failures" after a settle delay (or quote just-restarted units as WARN) before declaring a regression signal — today all 6 were stale-settle.
6. **Calm-gate REFUSE visibility**: the gated fleet being down for hours is by design but invisible outside the journal — a textfile metric (`post_crash_calm_gate_refused 1` + fleet-down gauge) would surface it in SigNoz/Gatus.
7. **Park-during-activation transparency**: nh printed nothing for 55 min while stc waited on the gate; streaming stc's per-unit output into the deploy log would have saved the diagnosis.
8. **The huge pin-audit trace block** head of every deploy log could collapse to one summary line + file pointer — it pushed the actual gate output far down the paste.
9. **Self-harvest at authoring time**: this report was written only when asked; the discipline (and the skill) want it at session end.

## f) Things we should get done next (brainstorm — NOT harvested except where noted; ordered by impact)

**Session-direct, actionable:**
1. `[blocked:user]` Re-arm the post-crash calm gate (gated AI fleet down since 15:07 yesterday; same boot) — queued to `docs/todo/services.md` this session ✅ *(harvested)*
2. Decide the REFUSE policy: is "gate refused → fleet down until next boot" acceptable as a terminal state on a long-lived boot, or should a 24h-calm re-poll re-run the gate? → [decision] for owner (§g Q1)
3. storage-collector upstream: CI leg that realizes its own prepared-source FOD (catches sed-in-readonly + manifest shape pre-push)
4. Audit the monitor365 family builders (monitor365, monitor365-ui-sdk, collector-utils, wireguard-collector) for the cp-then-sed-without-chmod shape
5. Eval-time lint candidate: `sed -i` inside prepared-source builder text without a preceding `chmod` — fits the existing eval-audit family (`*-audit.nix`)
6. Deploy smoke: productize a settle-window re-probe for exit-3 failures (stale-settle classifier)
7. Document in `docs/agents/nix-flakes.md`: `nix build <drv-path>` symlink trap; unregistered-zombie-output diagnosis; FODs are build-time-only (drv closure, not runtime closure)
8. Document in the probe-set (AGENTS.md): `getent ahostsv4` can return `127.0.0.2` (nsncd) — bind-address discovery goes through `ss -tlnp`
9. bank-sync: identify which cycle produced `bank_sync_sync_errors_total 1` (one journal grep; confirm transient)
10. papdashboard: INFO access-log rate (176-371/min) flaps the smoke threshold — journald rate-limit or sampling knob
11. Confirm deploy.sh's nested process-tree behavior (two deploy PIDs observed mid-run: holder + queued invocation) — intent vs duplicate-run risk
12. Stream stc per-unit output into the deploy log during the activation phase (parked-activation visibility)
13. Collapse the flake-input-pin-audit trace block in deploy output to a summary line
14. `nix log`: expose attempt count for FOD failures (today: 2 attempts visible only via differing mktemp names)
15. Calm-gate textfile metric for REFUSE state + gated-fleet-down gauge (SigNoz rule + Gatus check)

**Observed-adjacent (route, don't act):**
16. The 5 pre-deploy failed units (buildcache-gc, forgejo-github-sync, inboxclean-sync, service-health-check, tq-agent-pool) — already covered by existing `docs/todo/services.md` rows; verify they haven't drifted
17. Overnight deploys gen-1014/1015 (18:02 / 23:34 / 00:34 logs) — confirm their sessions closed out under the current IO storm
18. Eval warnings trio (catalog coverage, pipewire jack deprecation, caddy ghost entries `nsfw`/`llama`) — ROADMAP cleanup sweep
19. Wire `scripts/deploy-when-quiescent.sh` as the default night path so deploys stop being force-fired through 40-60% IO storms
20. post-deploy anchor auto-verify inside deploy.sh (today I verified the anchor manually; the exit-14 class note says procedure exists but it's still manual)
21. Skip-class for smoke: a gate REFUSE / parked-activation outcome should be a known-good converged annotation, not a regression signal
22. The `qmd`/`paperless-gpt-src`/nixpkgs pin rows in the pin-audit trace each carry LIFT conditions — schedule a lift sweep (pre-existing rows, untouched here)
23. `deploy exited code=3` classification taxonomy: separate "activation artifacts" from "true regressions" in the log summary line
24. Add `~/.cache/systemnix-fix/`-style capture-once convention to the heavy-eval doctrine (already practiced; one-line doc)
25. Zombie-output GC: a `nix store verify`/`path-info` sweep that flags unregistered store dirs left by failed builds (store hygiene + `ls -t` pollution source)
26. Consider `Restart=no` + explicit journal marker for the calm-gate retry loop (15s REFUSE re-runs make journal storms of their own)
27. storage-collector upstream: pin the `sed` idiom as a tested helper (shared family lib) so sibling builders can't drift
28. Family prepared-source builder: hoist into collector-utils (one implementation, four consumers) — matches the collector-extraction doctrine
29. Smoke SKIP: 3 checks skipped in the 13:52 battery — enumerate and justify
30. SigNoz/Gatus: does anything alert on `post-crash-calm-gate.service` failed state today? (OnFailure= toasts once; alerting path unverified — flagged, not researched)
31. Lock-float drift probe at deploy §0.5: warn when a LarsArtmann input's lock rev is behind its remote tip (today the fix outran the paste's deploy)
32. journal clock sanity line in post-deploy checks (overnight timestamps initially read as a clock step; cheap assertion would have made it instant)
33. Add `storage-collector` service runbook note: which generation carries the 0.2.0 prepared-source chain (documents the repair lineage)
34. Cross-check whether the gate-refusal window (15:07) overlapped any failed smoke check to attribute vs noise (would sharpen the exit-3 story)
35. nix-flakes doc: "two sed attempts with different mktemp suffixes = builder ran N times" forensic hint (cost me a confusion loop today)

## g) Questions I can NOT figure out myself

1. **Calm-gate policy**: the gate REFUSED at 15:07 and the AI cold-reader fleet has been down ~16h on a calm box. Do you want (a) a manual re-arm now (`systemctl start post-crash-calm-gate`), (b) the gate to self re-poll after a long-calm window (design change in the module), or (c) leave it to the next natural reboot?
2. **Smoke baseline policy**: exit-3 counts stale-settle noise (just-restarted units) as NEW regressions. Should the battery auto-re-probe failures after a settle window, or do you prefer the current strictness (human triage every exit-3)?
3. **Force-deploy doctrine**: yesterday's 13:06 deploy was force-fired through a 44% IO storm (and the storm returned overnight). Should `DEPLOY_FORCE_PRESSURE=1` stay a per-invocation owner override, or do you want deploys to default to the quiescent-wait path with force requiring an explicit flag rename?

---

*Report ends. Waiting for instructions.*
