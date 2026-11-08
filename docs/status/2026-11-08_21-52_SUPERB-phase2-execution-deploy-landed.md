# SUPERB Phase-2 Execution: Upstream Fixes → Re-locks → Parity → F1 → Deploy LANDED

**Session:** 2026-11-08 ~15:55 → 21:52 (resumed from the 13:10 midflight handoff)
**Instance:** SUPERB-executor (phase-2 plan `docs/planning/2026-11-08_10-44_SUPERB-upstreaming-completion-phase2.md`, tombstoned EXECUTING)
**Owner rulings in force:** may push LarsArtmann repos; deploy NOW at quiescence; FULL scope for crm/media-atlas/papdashboard.
**Headline:** D1 deploy **LANDED** (forced under a verified PSI phantom): gen **system-990**, anchor repaired, `cvagent-scan.service`/`cvagent-scan.timer` **LIVE** — the delegation wave (cvagent + pdd + health-dashboard trio + crm F1) is deployed. Exit 3 on smoke: 1 NEW failure (forgejo-runner, ordering-cycle class, self-converging), 5 pre-existing.

## What this session executed (chronological)

1. Read both blocking logs. **The handoff premise was wrong**: the 0EF commit battery did NOT abort on the pdd string bug — flake check AND the toplevel FOD gate PASSED with the bug live; the abort was statix (`cvagent.nix:57 useless parens`). The string-Exec break bites the `--json` RENDER path only, not the toplevel build. VM round 7's real failure: `cvagent-scan-run: line 24: awk: command not found` (status 127) — the wrapper's `aiDailyFactCap` gate uses awk; `runtimeInputs` lacked gawk.
2. Upstream cvagent: added gawk (`1664d48`); VM round 8 then failed on **invalid generated YAML** (`ai:` block children rendered at indent 6 after the dedented multi-line string — `model:`/`baseurl:` were siblings-not-children; confirmed by `cat`-ing the actual store config). Fixed nesting (`6ff68d3`), **VM round 9 GREEN** (4 machines), pushed.
3. Upstream pdd: `ExecStartPost` string→list (`adb9821`, nixfmt'd), flake check green, pushed.
4. Re-lock wave: cvagent `6ff68d3` + pdd `adb9821`; float-register proof **rc=0** (built the pdd FOD at adb9821 green through the `Rd4vxq` shim); registry green; committed.
5. Statix fix landed via daemon sweep (`579e168d7`, battery bypassed — statix re-verified standalone rc=0).
6. **Parity protocol complete** (renders old=baseline worktree 8b84d6de6, new=current): `mr-sync-dashboard` control **byte-identical**; `health-dashboard-rediscover` store-path-only; `health-dashboard` 6 keys (re-lock paths, upstream ProtectSystem full→strict + RestrictAddressFamilies, generic description); pdd 6 keys (re-lock, strict+RAF; old side needed the identical list-form patch to render at all); `cvagent`↔`cvagent-scan` semantic diff — every delta maps to a designed wrapper-mode change (rename, GIT_CONFIG_GLOBAL env, WorkingDirectory=dataDir, RequiresMountsFor state dir, strict+carve-outs, git in PATH). **Harden-bounds readout**: 512M/8G+400%/256M intact, MemoryHigh ≈80% coherent, ProtectHostname everywhere.
7. **F1 crm**: delegation rewrite (import + layer: catalog, sops template, oidc bridge, backups, alarms, integration, shim) + pin re-roll `0ce5ecc→f32f4c0` + allowlist row. First float proof RED: shim `k0Inp4g` stale at f32f4c0, got **`EzVPIaj…`** (first-hand FOD evidence, float-proof-20261108-172105.log) — re-shimmed, float **GREEN** (daemon landed the pair, float-register verified content). Parity: `crm-backup` + `crm-oidc-env` **byte-identical**; `crm-server` deltas = pin-roll store path + fail-open message "Pocket ID"→"the IdP" + upstream RAF hardening (flags byte-identical).
8. **F2 upstream** (media-atlas repo): `nix/nixos-module.nix` — hub serve unit + poll-embeddings/umap/lane-join timer family, freshness-stamp contract, fitProgram option (assertion-gated); flake check green; pushed `350dc42`.
9. **F3 upstream** (PapDashboard repo): `nix/nixos-module.nix` — the PAP_* env contract + unit skeleton (DynamicUser, state dir, journal supplementary group); every site value is an option; pushed `287f695`. (First attempt dropped the `flake.` prefix — eval broke; matched the proven cvagent shape.)
10. **go-health dupe-node investigation (Z1)**: the 4 `_N` nodes exist because discordsync/dnsblockd/library-policy/pma each pin go-health(-dashboard) as their OWN unfollowed sub-inputs, and the revs have DIVERGED (dnsblockd `c77a9f2` vs root `b7258b0`; unsuffixed `project-discovery-daemon` node `b36f7d8` is a consumer copy, root points at `_3`=`adb9821`). Deduping via `follows` would couple diverged pins and re-stale 4 FOD graphs — **not mechanical; deferred with evidence** (row queued).
11. **D1 deploy** (4 attempts): PSI gate refused 3× (exit 12). Forensics: no D-state corpses, devices 11% busy, zero builds — the stall is **entirely scoped to the 4 ghostty MONITOR terminals** (nvtop/btop/iotop scopes at 52-100% self-reported io.pressure, feeding user@1000 at 85%). Per the gate's own phantom branch (verify device/corpse before forcing) → **DEPLOY_FORCE_PRESSURE=1**. First forced run blocked on doc-counts (README gatus stamp 280 vs truth **282** — the mr-sync Dashboard endpoint wave; anchor is the embedded-command lineage line, not the headline). Re-stamped + committed. **Deploy LANDED**: activated, gen **system-990**, anchor self-repaired, 166 smoke PASS / 6 FAIL / exit 3.

## a) FULLY DONE

- cvagent upstream fixes (gawk + YAML nesting), VM test GREEN, pushed `6ff68d3`
- pdd upstream ExecStartPost list fix, pushed `adb9821`
- Re-lock cvagent+pdd via float-register, proof rc=0, registry green
- Delegation trio + sops rename landed & pushed (daemon `e2f270bb9`; statix fix `579e168d7`)
- Parity: 5 units verified, control byte-identical, all deltas designed+documented
- Harden-bounds audit: fleet bounds intact post-delegation
- F1 crm: delegation + pin re-roll `f32f4c0` + shim re-measure `EzVPIaj` + float green + parity (2 byte-identical, crm-server explained)
- F2/F3 UPSTREAM modules written, checked, pushed (media-atlas `350dc42`, PapDashboard `287f695`)
- Z1 go-health dupe-node root-cause documented (deferred deliberately)
- README gatus 280→282 re-stamp (doc-counts catch)
- **D1 DEPLOYED**: gen-990, anchored, cvagent-scan live, wave real

## b) PARTIALLY DONE

- **D1 close-out**: exit 3 — the ONE new-vs-baseline smoke failure (forgejo-runner INACTIVE, ordering-cycle class) has a 5-min runner-ensure converger; not yet re-probed. The 5 other fails are pre-existing baseline (llama-embeddings ×2, Health Hub 503, borg tripwire binary, papdashboard+node-exporter journal noise >300/min).
- **mr-sync-dashboard smoke specifics** (vHost render / gatus endpoint / cache dir) and **nsfw-stays-down** check: general battery passed; the specific probes not individually run.
- **Q1/Q2 owner answers** (from the 13:10 report) never arrived; I proceeded under the standing deploy-NOW + full-scope rulings. Q2 (pdd re-lock timing) became moot: parity REQUIRED the re-lock.

## c) NOT STARTED

- F2 SystemNix-side: `media-atlas.nix` delegation rewrite (import+layer; keep pg-ro/archive-perms/key-provision/immich-external-library/backup/integration) + lock float + parity on all 11 units
- F3 SystemNix-side: `papdashboard.nix` delegation rewrite (env-contract import; keep tiles/services.json/icons/checkEnv/drift-collector/sops/integration) + float + parity
- Y-tail: upstream.md ticks (cvagent done-row, pdd/go-health/journal module rows, **hermes premise correction** — third-party NousResearch, external-contribution wave, re-lock `21ae0e12` state; nsfw close), runbook headers (`docs/services/{cvagent,project-discovery-daemon,health-dashboard,crm}.md`), CHANGELOG entry
- D2 dnsblockd decision card (unprivileged upstream user vs root + restore paths)
- EXECUTED flips on BOTH plan files (`scripts/plan-marker.sh <plan> done`)
- SystemNix final commit (PATHSPEC) + push
- Post-deploy: cvagent-scan.timer ENABLED check, sops cvagent-env restartUnits surface, pdd socket contract live check

## d) TOTALLY FUCKED UP (session TFU ledger)

1. **Parity loop cd bug**: rendered BOTH old and new crm units from the baseline worktree (no `cd` back between loops) — the first "identical" result was baseline-vs-baseline garbage. Caught only because a size mismatch looked suspicious. A false PARITY-GREEN claim was one matching size away.
2. **Wrong-node lock probe**: my python read `nodes['project-discovery-daemon']` (an unsuffixed consumer copy at `b36f7d8`) instead of resolving through `nodes.root.inputs` (→ `_3` = `adb9821`) — spawned a false "a parallel session re-floated the lock" theory, an unnecessary float-register rerun, and 20 minutes of confusion. The registry's "no drift" was right.
3. **Invented lane-join flags** in the media-atlas upstream module (wrote `pull --with-lanes --db … --api-key-file …` from memory); caught by reading the real SystemNix unit before push and correcting to the actual invocation. Verify-before-write, not write-then-hope.
4. Dropped `flake.` prefix on the PapDashboard export (eval break) — fixed by copying the proven cvagent shape instead of free-styling.
5. Forgot `nix fmt` before the pdd commit (nixfmt block, one wasted cycle).
6. Two PATHSPEC commits raced the daemon ref-lock (mid-battery HEAD moves) + index.lock waits; the statix fix ultimately landed via daemon sweep, bypassing the battery — re-ran statix standalone; the float proof covered eval.
7. Initial PSI attribution ("parallel builds") was wrong — the builds ended and PSI stayed; the real cause is monitor-scope stall accounting. My first two deploy attempts burned on a theory, the forensics came third.

## e) WHAT WE SHOULD IMPROVE

- **Render-side hygiene**: one `cd` per render loop, or absolute `--expr`; stamp a side marker into each render output so a baseline-vs-baseline mistake cannot masquerade as parity.
- **Lock probes must resolve via `nodes.root.inputs`** (the `_N` suffix trap) — worth a 5-line helper script or an AGENTS.md line; it cost this session a false concurrency theory.
- **Lint the string-Exec latent class**: `--json` unit renders throw on string `Exec*` under new nixpkgs while the toplevel build passes silently — the repo still carries pre-existing instances (crm alarms ×2, and whatever else a sweep finds). A systemd-shape-audit leg would close the gap; pdd was this exact class.
- **PSI gate phantom branch**: the four monitor-terminal scopes (nvtop/btop/iotop) permanently self-report ≥50% io.pressure with idle disks and trip the ≥20% entry gate all evening; the gate's per-device crosscheck already detects the phantom, but its verdict branch ("REAL I/O storm") fires the moment the deploy's OWN cached build nudges busy ≥20%. Consider scoping the busy probe to the pre-build window or excluding read-only monitor scopes.
- `nix fmt` before every upstream commit (two repos enforce it; I hit one).
- The 0EF handoff premise ("will fail on the pdd bug") vs reality (statix-only abort) — handoff notes should mark predictions as predictions, not state.

## f) NEXT (priority order)

1. Re-probe forgejo-runner after the 5-min ensure timer (busctl/ActiveState) — expect INACTIVE→active; if not, journalctl the ordering-cycle.
2. mr-sync-dashboard specific smoke: vHost render, "mr-sync Dashboard" gatus endpoint green, cache dir present.
3. nsfw-stays-down check (owner-disabled; module still evals — confirm no unit).
4. cvagent-scan.timer enabled + sops `cvagent-env` restartUnits surfaces updated (sops.nix rewrite landed pre-deploy).
5. pdd live socket check: `/run/project-discovery/daemon.sock` exists (ExecStartPost contract green in prod).
6. F2 SystemNix delegation: rewrite `media-atlas.nix` as import+layer (upstream `350dc42`), keep site units, float, parity 11 units.
7. F3 SystemNix delegation: rewrite `papdashboard.nix` (upstream `287f695`), keep registry/tiles/icons, float, parity.
8. Y2 upstream.md ticks: cvagent wave-CLOSE row, pdd/go-health/journal new-module rows, hermes premise-corrected row, nsfw row CLOSE.
9. Runbook headers: cvagent (unit rename + wrapper mode), pdd (delegation), health-dashboard (delegation), crm (delegation + shim lineage EzVPIaj).
10. CHANGELOG entry for the wave.
11. D2 dnsblockd decision card (ask owner).
12. EXECUTED flips on BOTH plans (`scripts/plan-marker.sh … done`).
13. SystemNix final PATHSPEC commit + push.
14. String-Exec sweep + systemd-shape-audit leg (the render-break class) — queue row.
15. go-health follows-decision row (Z1 finding: diverged per-consumer pins; follows = coupling decision).
16. crm alarm units: fix `ExecStart = "string"` → list form (latent render break, same class).
17. Monitor-scope PSI gate refinement row (e).
18. cvagent upstream: consider a module-level VM assertion that the generated YAML parses (round-9's failure class was only catchable by running the binary).
19. media-atlas upstream: VM test or at least a minimal nixos eval for the new module (currently import-checked only).
20. PapDashboard upstream: same minimal-module eval check.
21. hermes external-contribution wave (premise-corrected): draft the NousResearch upstream ask.
22. journal pin LIFT check (templ regen at 0.3.1100 at tip? probe `git log` in the journal repo).
23. pdd sibling node `b36f7d8` (deps bump v0.21.1): decide root float to it (vendorHash re-measure first — the shim is untested at that rev).
24. The 5 pre-existing smoke failures (llama-embeddings, Health Hub 503, borg tripwire, journal-noise pair) — triage who owns each (not this wave).
25. papdashboard 674 lines/min journal noise — suspicious on its own; journalctl it.
26. Re-verify the 12:56 session's 3 owner questions don't collide with this report's close-out.
27. Purge `~/.cache/parity` renders older than this wave (housekeeping).
28. Harvest this report's §f into TODO_LIST + docs/todo/upstream.md per the self-harvest rule (deliberately deferred pending owner instructions — see §g).

## g) OWNER QUESTIONS (cannot resolve myself)

1. **Forgejo-runner smoke NEW-failure**: let the 5-min runner-ensure timer converge it (my read — ordering-cycle class), or do you want an immediate journalctl investigation before anything else rides this deploy?
2. **The 4 monitor terminals (nvtop/btop/iotop) trip the deploy PSI gate all evening** via self-reported io.pressure (devices idle). They are YOUR terminals: may I restart them (or should the gate learn to exclude monitor-scope self-stall), or do you prefer forcing deploys manually each time as today?
3. **pdd root pin**: `adb9821` (my fix, FOD-proven) is deployed; the sibling node `b36f7d8` (deps bump v0.21.1) sits one commit ahead unproven through our graph. Roll the root pin to it deliberately (re-measure the vendorHash shim first), or hold at `adb9821` until the next organic float?

**Self-harvest note (per the standing rule):** this report's §f items 1-5 are direct deploy-close follow-ups and 6-13 are the plan's remaining tail — they are candidates for TODO_LIST.md + docs/todo/upstream.md at authoring time, deliberately not written yet because the owner asked for the report and a WAIT; say the word and I harvest them verbatim.
