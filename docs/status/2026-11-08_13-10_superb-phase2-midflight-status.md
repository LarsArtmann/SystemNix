# SUPERB Phase-2 — Mid-Flight Status (delegation wave landing)

**Date:** 2026-11-08 13:10 · **Session:** SUPERB-executor (phase-2 plan: `docs/planning/2026-11-08_10-44_SUPERB-upstreaming-completion-phase2.md`, tombstoned EXECUTING, `d7d4855d5`) · **Window:** ~12:30–13:10 (plus the 03:59–08:33 phase-1 window reported in `2026-11-08_08-33_superb-upstreaming-execution-status.md`)

**Owner rulings in force:** Q1 = agent may push the LarsArtmann repos ✓ · Q2 = deploy NOW at quiescence ✓ · Q3 = FULL scope for crm/media-atlas/papdashboard ✓

## a) FULLY DONE (this window, verified)

1. **Phase-2 plan written + tombstoned** (`d7d4855d5`): pareto (1% = push+delegate trio; 4% = deploy; 20% = full-scope extractions; tail = docs/verdicts/close-out), 8 medium tasks, micro tables, mermaid graph, 8 guardrails.
2. **Four repos pushed** (owner-sanctioned): cvagent `f070ffa..e0d0e8b`, pdd `ab80974..c8dd750`, go-health `83be4b1..d15fcb6`, journal `0ab2856..34edc4a` (+ crm `d5f5cc5..f32f4c0` after its module landed).
3. **Trio re-locked in ONE float wave — proof GREEN**: cvagent `09ff6c1`, go-health `d15fcb6`, pdd `c8dd750` (`float-proof-20261108-125034.log`, rc=0, "no root signatures"), registry pair landed by the daemon.
4. **Three SystemNix delegation rewrites DONE on disk**: cvagent.nix (combined scan+mesh via upstream wrapper mode; sops.nix restartUnits renamed cvagent→cvagent-scan ×2; system-health row renamed), project-discovery-daemon.nix (import + shim/user/mount-gate/ioTier/bounds layer), health-dashboard.nix (import + port-registry addr + drift sweep + integration/catalog layer). evo-x2 eval GREEN through all three (`nix eval --raw …toplevel.drvPath` → `vg307r7r…`).
5. **crm upstream module written + pushed** (`nix/nixos-module.nix` + flake export, `f32f4c0`): product deployment contract (loopback, dual stores, API_TOKEN env, auth/secure-cookie flags, OIDC trio + issuer-host DNS gate, GOMEMLIMIT), repo `nix flake check --no-build` green.

## b) PARTIALLY DONE

6. **Delegation-wave commit IN FLIGHT**: the six-path commit (lock + registry + 3 modules + sops.nix) is mid pre-commit battery right now. Two real bugs were caught and fixed on the way: (i) my health-dashboard rewrite hoisted the catalog entry to module top level (illegal `services` attr — pre-commit eval leg caught it; restored into `imports = [{…}]`); (ii) see TFU §1 below — a latent pdd ExecStartPost string-vs-list bug that the battery is likely catching in the running attempt.
7. **cvagent VM test — round 7 failed** (detail unread at report time; rounds 1–6 were all assertion-mechanics, each fixed: eval-assert, show-time-format, python next(), `{path}` braces, `path=` prefix, YAML toJSON quoting). The module's runtime behavior (tolerance loop, chained mesh, spend gate) has not yet been observed green end-to-end.
8. **Parity renders**: baseline (8b84d6de6, tombstone parent) worktree up under `~/.cache/parity-baseline` (moved from /tmp — volatile); new-tree renders done for 4/5 units; pdd render exposed the string-vs-list bug (the render IS the parity harness working).

## c) NOT STARTED

9. D1 deploy (queued immediately after the wave commits + parity).
10. F1 crm SystemNix delegation + pin re-roll (upstream module ready; delegation rewrite not written).
11. F2 media-atlas, F3 papdashboard full-scope (read/inventory only).
12. Y-tail: upstream.md ticks (hermes premise correction, nsfw close, cvagent/pdd/go-health rows), runbook sweep, CHANGELOG, go-health lock dupe cleanup, D2 dnsblockd card, EXECUTED flips ×2, final report, SystemNix push.

## d) TOTALLY FUCKED UP (honest ledger, this window)

13. **The latent pdd string-vs-list bug is MINE to have caught by parity BEFORE the float proof claimed green**: the proof (12:50) snapshotted the tree BEFORE my delegated pdd.nix landed on disk (~12:52), so "proof green" covered the re-lock but NOT all three delegations — I then over-trusted it. The pre-commit battery and the parity render both caught it (the layers work!), but the sequencing error was assuming proof coverage I didn't have. Fix in flight: upstream `ExecStartPost = [ … ]` list form (+push+re-lock ride). Silver lining: the ORIGINAL SystemNix pdd module carries the same string form — it would break under the floated root nixpkgs anyway; the delegation fixes a latent break.
14. **Round-7 VM test still iterating** — 6 prior rounds on assertion mechanics; the persistent failure pattern says I should have replaced ALL fragile show-format assertions with render-greps in one pass instead of one per round.
15. **git index.lock collision** with the parallel session's commit — waited it out correctly (never deleted the lock), but it cost the first commit attempt's momentum.
16. **Stale-reading risk spotted in time**: `float-register`'s "daemon landed the pair" message vs the still-staged flake.lock — the pair had NOT fully landed; my six-path commit carries them (verified via staged diff before committing).

## e) IMPROVE (standing additions)

17. After ANY float proof, re-run the cheap `nix eval …drvPath` against the FINAL tree state if files changed during the proof window — proof coverage must name the tree it proved.
18. VM tests: convert ALL `systemctl show --value` assertions to `systemctl cat | grep` render assertions in ONE pass; quote-tolerant greps for anything YAML/JSON-rendered.
19. When a pre-commit battery aborts, capture the FULL hook log before retrying (I misattributed the first abort to the catalog bug alone; two bugs were hiding).

## f) NEXT (up to 50, ordered)

1. Read round-7 VM failure; fix (module vs test as evidence dictates); rerun.
2. Fix upstream pdd `ExecStartPost` → list form; commit+push pdd.
3. Re-float pdd lock past the fix (float-register); verify trio commit lands green after.
4. Commit the delegation wave (six paths) — in flight, likely needs the pdd fix first.
5. Parity: render new-tree pdd unit post-fix; diff old/new for cvagent↔cvagent-scan, pdd, health-dashboard, rediscover; harden-bounds readout (CPUQuota/MemoryHigh/ProtectHostname + 8G/400%/512M/256M/1G bounds).
6. Tick cvagent/pdd/go-health rows in docs/todo/upstream.md + runbook headers (docs/services/{cvagent,project-discovery-daemon,health-dashboard}.md) + CHANGELOG.
7. D1 deploy: quiescence polls ×4, green drvPath probe, `nix run .#deploy`, watch /var/log/systemnix-deploys/<ts>.log, anchor by system-N-link NUMBER, post-deploy battery, mr-sync smoke, cvagent-scan.timer enabled check, nsfw-stays-down check.
8. F1 crm delegation: rewrite crm.nix as import+layer (keep OIDC bridge, backups, alarms, catalog/integration, shim via layer env files); pin re-roll to f32f4c0+ (flake.nix `?rev=` + pin-audit allowlist comment update); float-register; parity (crm-server unit + crm-oidc-env + backups unchanged).
9. F2 media-atlas: read 908 lines fully; extract hub-core module upstream; forgejo push; float; delegate; parity on all 11 units (10 must be byte-identical).
10. F3 papdashboard: read 968; extract service unit per plan boundary; honest verdict if stop-gate fires; document either way.
11. go-health lock dupe-node inspection + cleanup (4 `_N` nodes).
12. Y-tail: hermes premise-corrected row; nsfw row CLOSE; journal pin-gated row note; EXECUTED flips (both plans); final status report; SystemNix git push (owner-sanctioned).
13. D2 dnsblockd decision card (unprivileged upstream user vs root + restore paths) for the owner.
14. Reconcile with the PARALLEL "nix-native full-wave closeout" session's report (docs/status/2026-11-08_12-56_*) — they PSI-gated a deploy twice and forced once mid-edit; coordinate D1 to avoid a third collision.

## g) QUESTIONS (cannot resolve from the tree)

**Q1:** The parallel session's closeout says a deploy was PSI-gated twice and "forced once into a parallel-session mid-edit tree the battery correctly refused" — and it left 3 owner questions (deploy timing, phantom-PSI gate tier, D4). Should MY D1 (which carries the upstreaming payload) wait for that session's deploy to land first, or is mine the deploy of record and theirs superseded?

**Q2:** The pdd fix changes the upstream module AFTER the trio lock (pdd `c8dd750` → fix rev): re-lock pdd again tonight (recommended, one more float wave), or leave `c8dd750` (the bug is latent — ExecStartPost would fail at BUILD, and the tree is currently protected by the battery) and ride the next organic float?

**Q3:** None — everything else is executable.

## Self-harvest note

Rows 1–14 above live in this report pending the owner's Q1/Q2 answers; the docs/todo/upstream.md tick wave (f.6) is the harvest vehicle and executes with the delegation commit regardless of the answers.
