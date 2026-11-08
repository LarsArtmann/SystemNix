# SUPERB Upstreaming Plan — Execution Status (mid-flight close-out)

**Date:** 2026-11-08 08:33 · **Session:** SUPERB-executor (tombstoned at d94d0ebb7, plan: `docs/planning/2026-11-08_03-30_SUPERB-own-project-module-upstreaming-completion.md`) · **Window:** 03:59–08:33 (~4.5h)

**Self-harvest note:** follow-ups below are deliberately NOT yet harvested into TODO_LIST.md/domain libraries — their shape depends on the three owner questions at the end (push authority, deploy timing, X-wave scope). Harvest lands with the answers.

## a) FULLY DONE (verified)

1. **Plan tombstone** — `**Created:**` anchor added (the plan lacked one; `plan-marker.sh` refuses without it), EXECUTING marker written + committed (`d94d0ebb7`). No prior execution markers existed.
2. **X0 — extraction recipe** parked in `docs/agents/integration-registry.md` (`0129f32df`): 9 steps incl. the two NEW stop-gates learned this session (step 0 premise-probe the input URL, step 1 portable-set threshold / philosophy-conflict stop).
3. **Wave H premise CORRECTED (the plan's biggest error):** `hermes-agent` input is **third-party `github:NousResearch/hermes-agent`** — no LarsArtmann fork exists (`gh` + `git ls-remote` both confirm). The plan's "owner/daemon pushes hermes-agent (HEAD 686193c0)" was impossible; the local checkout is an owner-patched clone whose `nix/nixosModules.nix` came from UPSTREAM commits (already on origin/main). The audit's "own-project" classification for hermes was wrong.
4. **H2 — hermes re-locked `0ea6ea9` → `21ae0e12`, proof GREEN.** Toplevel probe at `31d0a242` green first; the re-lock grabbed a NEWER tip (origin moved; my origin/main read was a stale local ref); recovered through the repo's own ceremony: `nix run .#float-register` regenerated `flake/expected-locks.nix`, ran the keep-going toplevel proof (rc=0, `~/.cache/lockfloat/float-proof-20261108-062809.log`), and the pair landed (`90669dda4` + `14713a5f0`). **H3 delegation honestly reframed:** the upstream module manages config.yaml/.env declaratively; SystemNix's deployment deliberately leaves the agent's state agent-owned (uid 975, linger, heal/verify units, workspace docs, credential helpers are site-operational). Importing upstream's module would activate config-rendering against a live agent-owned home — cvagent-class upstream-first work (external contribution to NousResearch), NOT a tonight delegation. Row update queued (Y2).
5. **Wave N COMPLETE (the cleanest loop of the session):**
   - N1a upstream fix: `nix/nixos-module.nix` `unitConfig.TimeoutStartSec` → `serviceConfig` (`a1e5d29a`, nsfw-classifier) — daemon pushed it within ~30 min.
   - N1b: input re-locked `a8ba146` → `64a29d8d` via float-register (proof GREEN, pair landed), SystemNix's `serviceConfig.TimeoutStartSec` duplicate AND the `unitConfig.TimeoutStartSec = mkForce null` neutralizer both dropped (`74e96d9f1`), `checks.x86_64-linux.nsfw-classifier` contract test GREEN.
6. **C2a — cvagent upstream module extended + committed** (Code-To-CV-Agent, daemon-swept): `scan.repositories` (curated per-repo tolerance loop), `scan.aiModel`/`aiBaseUrl` (rendered into the generated config; `ai.enabled: false` + `--ai` stays the single switch), `scan.aiDailyFactCap` (run-level AI spend gate via `facts --json` awk), `scan.timeoutStartSec`, `mesh.runWithScan` (combined scan+mesh unit; no mesh unit/timer). Two real bugs caught before/while testing: the searchPaths assertion excluded curated mode, and the combined scan sandbox needed `mesh.targetDir` in `ReadWritePaths` (ProtectSystem=strict would EROFS the chained export — caught by walking sandbox semantics, then pinned by the VM test design). Upstream `nix flake check --no-build` green.
7. **Three upstream modules banked** (written, repo eval green, committed — Wave X XRb for three repos):
   - `journal` `nix/nixos-module.nix` + flake export (`0ab2856`) — loopback dashboard, books-home contract. Delegation pin-gated (templ wave; lift condition NOT met — tip is still the un-regenerated 5604c6f lineage).
   - `project-discovery-daemon` (`3ae2d7f` + `c8dd750`) — socket-start contract, notify+watchdog, discovery env mapping.
   - `go-health-dashboard` (`d15fcb6`) — federation hub unit, remotes assert, loopback default.

## b) PARTIALLY DONE

8. **C2b VM test:** extended with a 4th machine (`curated`) pinning tolerance/combined-mesh/spend-gate/rendered-config. **5 rounds, 4 assertion-mechanics failures, module itself never failed at runtime yet** — failures were: eval-assert (fixed), systemd show time format (fixed), python `next()` on wrapper ExecStart (fixed), `{path}` braces (fixed), and finally `path=` prefix (**one line remains**: add `| cut -d= -f2` to the wrapper extraction, `nix/vm-test.nix:~188`). The behavioral tail (scan tolerance WARN, mesh artifact, cap gate) has not executed yet.
9. **Wave X delegations: 0 of 6 landed** — all serialized on daemon pushes (currently ahead: cvagent 4, pdd 2, go-health 1, journal 8) because a delegated SystemNix module imports `nixosModules` that don't exist at the locked rev (tree would break until re-lock — delegation + re-lock must land as one wave, via float-register).
10. **Wave X remaining writes: crm/media-atlas/papdashboard not written.** Inventoried: crm 543 lines (portable core = product deployment contract; OIDC provisioning/sops stay), media-atlas 908 (11 units; portable = hub core only), papdashboard 968 (service-unit-only per plan; bulk is SystemNix-internal tile machinery).

## c) NOT STARTED

11. **D1 deploy** — sudo verified WORKING this session (`sudo -n true` rc=0, yolo-class). Undeployed payload accumulating: mr-sync delegation (previous session), nsfw fix+delegation, hermes float, plus whatever lands next.
12. **Y1 runbook sweep** (docs/services/*.md owning-module lines for nsfw + future delegations).
13. **Y2 library ticks:** docs/todo/upstream.md rows need: hermes premise correction + re-lock state, nsfw row close (N done), cvagent row update (module written; delegation pending), NEW rows for journal/pdd/go-health modules (written, delegation push-gated), media-atlas/papdashboard scope verdicts.
14. **CHANGELOG** for this session's SystemNix changes (hermes float, nsfw neutralizer drop, X0 recipe).
15. **Z1** — parallel-session ledger this window: an all-health-alerts sweep (03:56), a cv-crm-mirror-repair + brutal-self-review session (07:15), a telephony-passkey builder, the nsfw io-surface session (whose 6 commits I rode/published via the daemon push — their work was committed-complete). No conflicts; their untracked reports left untouched.
16. **D2 dnsblockd owner ruling** — decision card not yet prepared.
17. **Plan EXECUTED flip** — plan still carries EXECUTING (correctly — waves incomplete).

## d) TOTALLY FUCKED UP (honest ledger)

18. **The 21ae0e12 unprobed-float window (~10 min, real blast radius):** I re-locked, started a probe, and the daemon committed the bare lock BEFORE the proof — an incomplete float that fails EVERY tree eval (lock-float audit). A parallel session's build was live in that window. Fixed by float-register, but the correct move was: **any `--update-input` must be immediately followed by `nix run .#float-register`** — that's literally what it's for (its header documents absorbing daemon-swept floats). I ran the manual probe ceremony instead because I hadn't read float-register.sh yet.
19. **5 VM-test rounds on one assertion chain:** guessed `systemctl show` output formats 4 times (`^1h 30min` time normalization, wrapper ExecStart tokens, `{path}` braces, `path=` prefix) instead of shipping the `echo WRAPPER=$wrapper` diagnostic in round 3. ~25 min + 4 FOD rebuilds (worse: rounds 3-5 rebuilt the package FOD every time because the tree was `-dirty` — I should have committed module+test before the first test run).
20. `rg -rn` — tripped the host's third-strike hook (documented trap; zero damage).
21. pdd commit landed as "1 file" because the daemon had swept the module file separately — verified after the fact; the git-log check should have been before (AGENTS.md daemon-race rule).
22. Serializing delegations on push latency without pre-banking the SystemNix-side rewrites — the delegated modules could have been written and held (uncommitted/staged) so each push→relock→delegate lands in minutes. Didn't; that's why Wave X shows 0 delegations despite 3 modules ready.

## e) IMPROVE (standing rules I'm taking away)

23. **float-register FIRST, probes second** — it owns the probe (keep-going toplevel), the registry, and the daemon-race absorption in one command. Manual `--override-input` probing is only for pre-commit investigation of a SPECIFIC rev (like 31d0a242), never the ceremony.
24. **VM-test assertions assert RENDERS, not `systemctl show` formats** (`systemctl cat | grep 'Key=value'` beats `show --value` format-guesses), and every non-trivial shell assertion ships with an echo of its intermediates from round 1.
25. **Commit before building checks** in upstream repos (kills `-dirty` FOD churn).
26. **Premise-probe the INPUT URL before planning any wave** (recipe step 0 — born from hermes).
27. Bank SystemNix delegation rewrites ahead of push-availability; land delegation+re-lock as one float-register wave.

## f) NEXT (ordered, gated)

1. VM test round 6: the one-liner (`cut -d= -f2`), expect the behavioral tail to finally run (tolerance WARN, mesh artifact, cap-gate). ~6 min.
2. Owner Q1 (pushes) resolves the queue: push cvagent/pdd/go-health/journal (or wait for daemon), then per repo: float-register re-lock → SystemNix delegation rewrite → parity diff (baseline = `git log -S "EXECUTING (instance SUPERB-executor"` minus one) → harden-bounds check → audits (io-tier on the new upstream units, class-9, timeout floors) → tick.
3. cvagent SystemNix delegation specifics already designed: imports upstream, user=lars/group=users/dataDir=~/.local/state/cvagent, serve.enable=false, curated list + AI opts + cap + 90min + calendar 05:53 + randomizedDelay 600, mesh.runWithScan target CV checkout; layer ioTier.background/onFailure/system-health→`cvagent-scan` rename/HOME/ProtectHome mkForce false/MemoryMax mkForce 512M/serviceOneshotDefaults; **sops.nix restartUnits "cvagent.service"→"cvagent-scan.service" (2 sites)**.
4. pdd delegation layer: package vendorHash shim (graph-stale class stays consumer-side), user=primaryUser, projects-mount gate, onFailure, ioTier, harden{8G/400%/read-only} (equal values to upstream — no priority fight), serviceDefaults.
5. go-health delegation layer: addr from ports.health-dashboard, rediscover sweep + timer stay SystemNix, integration/catalog entries stay, harden MemoryMax 256M.
6. journal delegation: PIN-GATED until templ regen at 0.3.1100 (tip still un-regenerated — verified this session). Row note only.
7. crm upstream module (product deployment contract: addr/db paths/api-token-env/auth flags/oidc opts) + pin re-roll per wave policy + delegation. media-atlas hub-core extraction. papdashboard stop-gate verdict (see Q3).
8. go-health-dashboard lock dupe-node cleanup (4 `go-health-dashboard_N` nodes — un-inspected this session).
9. D1 deploy (after the delegation waves or per owner Q2): quiescence polls, `nix run .#deploy`, anchor-by-NUMBER, post-deploy battery + mr-sync-dashboard smoke (vHost/gatus/cache dir), nsfw stays down.
10. Y1/Y2/Y3: runbook sweep, upstream.md row updates (hermes premise + state, nsfw close, cvagent progress, 3 new module rows, scope verdicts), CHANGELOG entry, WARN recount if any prune.
11. D2 decision card + owner ruling (dnsblockd unit identity).
12. Plan EXECUTED flip + final report + tombstone commit.

## g) QUESTIONS FOR THE OWNER (cannot be resolved from the tree)

**Q1 — Push authority for Wave X/C's tail.** cvagent (4), pdd (2), go-health (1), journal (8, incl. two parallel sessions' committed work) sit ahead of origin. The daemon pushes eventually (nsfw landed in ~30 min), but every SystemNix delegation is serialized behind it. May I push these four LarsArtmann repos directly, or keep waiting for the daemon?

**Q2 — Deploy timing.** sudo works in this session. mr-sync delegation (previous session), the nsfw fix + neutralizer drop, and the hermes float are all UNDEPLOYED. Deploy now at tree quiescence, after the pending delegations land, or leave D1 entirely to you?

**Q3 — media-atlas / papdashboard / crm scope ruling.** Reading them against the recipe's step-1 stop-gate: papdashboard's portable set looks tiny (the plan itself keeps the tile/icons layer SystemNix-internal; the service unit is host plumbing), media-atlas's is hub-core-only (10 of 11 units are site wiring), crm's is real but the smallest-delta path is product-contract-only. Full scope anyway, reduced scope as described, or defer all three as recipe-driven follow-ups?
