# Nix-Native Modernization — Full-Wave Execution Status (closeout)

**Date:** 2026-11-08 12:56 CET · **Session:** 07:18 → 12:56
**Plan:** `docs/planning/2026-11-08_06-31_SUPERB-nix-native-modernization-pareto-plan.md` (§10 = execution record, tombstone EXECUTED)
**Commits:** `dc17077c0` (T1/T2 manifest) · `57cbd4654` + daemon-swept batch (T3–T7, T11, 12.1) · `66fb1e864` (T8/T9) · `aa496d770` (T4.3/T10/T13/T14) · `fe1b3aae2` (first status report)

---

## §a FULLY DONE (committed, verified, standing)

| Task | Deliverable | Verification |
|---|---|---|
| T1 manifest v1 | `lib/integration-manifest.nix` (union view; checkUrl parity; assertJsonSafe naming first offender) + `checks.integration-manifest-shape-selftest` | fixture green; evo-x2 manifest BUILT green (78 ports / 88 services, checkPhase jq) |
| T2 runtime exposure | `modules/nixos/services/integration-manifest.nix` → `system.build.integration-manifest` + `/etc/systemnix/integration-manifest.json` (0644); rpi3-dns imported (catalog-only subset) | both hosts eval green; rpi3 manifest drv evaluated |
| T3 battery conversion | 34 host-form port literals dead in `post-deploy-check.sh`; loader extracted to `scripts/lib/integration-manifest-loader.sh`; zero `localhost:[0-9]` remain (grep proof) | verdict parity ×3 full live battery runs — converted sections byte-identical, FAIL set unchanged & baseline-matched |
| T4 degrade/drift legs | absent manifest = WARN+SKIP never FAIL; unknown-port drift WARN; standing `integration-manifest-loader-selftest` | 8/8 fixture legs; degradation + drift batteries run live (logs in `~/.cache/nix-native-exec/`) |
| T5 script-port-audit | `modules/nixos/services/script-port-audit.nix` eval gate + `CASES=scriptport` legs; zero-padded-group scanner fix in `lib/default.nix` | legs 3/3; evo-x2 eval green; FIRST SWEEP caught verify-deployment.sh @ stale gatus 9110 (dead 12 days) + llama-rag-soak 18848 → both fixed |
| T6 vHost timeout | budget = max(client.timeout) from manifest, 20s floor | live-derived 20→30; pipeline.md row + TODO_LIST queue row ticked (both surfaces) |
| T7 doctrine docs | `docs/agents/integration-registry.md` §Manifest Bridge + AGENTS critical-rule amendment | — |
| T8 hermeticity | COLLAPSED to errata E1 (all 7 readFile embeds were already writeShellApplication+pinned deps); 8.7 intentional-tree-access comment; 8.8 scrubGuard grep = zero hits | plan §10 E1 |
| T9 registry matrix | 88-row generated table in the doc; `checks.registry-matrix-drift` + `packages.registry-matrix` regen path | green + RED leg proven live (corrupt→STALE→restore byte-clean) |
| T10 LAN-IP scripts | COLLAPSED to errata E2 (units already inject `networking.local`); provenance comments ×3 | plan §10 E2 |
| T11 port range guard | int/1-65535 enforced at import in `lib/ports.nix` (no mkPort call-site churn) | red (141100 throws naming `pocket-id`) + green (78 ports) |
| 12.1 tmux | ALL SIX dead `just` bindings rewired to flake apps (check/deploy/pre-deploy/post-deploy/pre-reboot) | — |
| T13 cache-names | 13.1 inventory refresh ONLY — D4 deliberately held for owner (see §e) | [decision] row refreshed in pipeline.md |
| T14 closure | plan §10 + EXECUTED tombstone; masterplan-v5 errata cross-link; CHANGELOG entry; T1–T4 rows ticked on BOTH surfaces | `nix flake check --no-build` rc=0 at `aa496d770` |

## §b PARTIALLY DONE

- **The deploy.** Two PSI-gate refusals (real write-back storm from a parallel session's tests + a forgejo git bulk op), then the crosscheck proved the residual storm is the DOCUMENTED ghostty io_uring phantom class (all devices ≤0.1% util, mem PSI 0.00, stalled cgroup = `app-niri-ghostty-*.scope` at 100% with zero io.stat — root-caused 2026-10-14, named in the gate's own comments). Fired `DEPLOY_FORCE_PRESSURE=1` (the gate's documented-sufficient path for phantom PSI, evidence captured in `~/.cache/nix-native-exec/`). The pre-deploy battery then REFUSED on **"evo-x2 evaluation failed"** cascades (§13/§14/§16/§19 legs) — cause: a PARALLEL SESSION was MID-EDIT on service modules (`crm.nix` +61 lines unstaged, flake.lock restaged; their phase-2 plan tombstone landed at `d7d4855d5`). I re-evaluated read-only minutes later: **tree green again (rc=0)** — their edit landed; the breakage was transient mid-edit state, not my wave (my last full `nix flake check` was rc=0). Deploy not yet re-fired.

## §c NOT STARTED (deliberately)

- Nothing from the plan. The only unexecuted cell is T13.2–13.5 (D4-gated by design).

## §d TOTALLY FUCKED UP (honest ledger)

1. **My own mid-edit race (twice- documented class, live again):** launched the degradation battery as a background run, then immediately edited the same script for T6 — bash read a half-written file and died `GGUF: command not found` at a comment line. Degradation WARNs had already fired pre-crash; re-ran clean. The AGENTS rule existed; I violated it by sequencing.
2. **Fired the forced deploy into a non-quiescent tree.** I checked drv-drift but NOT the tree-quiescence heat-check (the 2026-10-25 deploy-vs-executor doctrine: poll for eval-relevant files' mtimes quiet ≥4 polls). The battery caught it (its job), but the deploy attempt was wasted and the failure noise polluted the deploy log. Process error, self-caught, zero damage.
3. **jq hyphen-key trap ×2** (`pocket-id` → "id/0 is not defined") before I internalized bracket syntax.
4. **doc-counts caught me twice** (modules 148→149→150, packages 49→50) — correct behavior of the gate, my misses.
5. **Daemon races ×5** during commits — handled per policy (3 soft-reset splits, land-on-top, pathspec), zero content loss proven each time; one flagship message rode a 1-file commit with the batch described in its body.

## §e WHAT WE SHOULD IMPROVE (systemic, from this run)

1. **Ghostty phantom PSI makes the deploy gate near-permanently strict on this box** (any ghostty window books ~100% io PSI with zero IO). The gate handles it (crosscheck + `=1`), but the CALM-bar (<20) my retry loop used is unreachable while terminals are open — the gate could grow a documented "phantom-only + mem-calm + disks-idle → advisory instead of refusal" tier (owner call — it weakens a freeze guard).
2. **Deploy-vs-executor quiescence check should be a deploy.sh PRE-BATTERY step** (mtime heat-check on eval-relevant paths), not just doctrine in AGENTS — today's mid-edit refusal proves the battery is the only net.
3. **doc-counts should print the re-stamp COMMAND** in its error (it does) AND accept a `--restamp` auto-mode for mechanical +1 module/package counts (5 min saved × every session that adds a module).
4. **The tracked-files trap** (new part file invisible to eval until `git add`) cost a cycle — a devshell alias `nixadd <file>` or an eval-time hint when a `flake/parts/**` file exists untracked would close it.
5. **T8/T10's plan premises were stale** — the planning session verified them at PLAN time but a prior wave had already migrated the code. A `git log --since` freshness note per V-row in future plans would flag premises older than the last wave.

## §f NEXT (up to 50, ranked; queue-harvested rows marked Q)

1. **Re-fire the deploy** (tree green, drift real) → post-deploy: live `/etc/systemnix/integration-manifest.json` probe, full battery on the DEPLOYED gen (the true end-to-end proof — loader consuming the live file), anchor check (`readlink /run/current-system` vs newest `system-N-link` by NUMBER), then push. *(this session, gated on instructions/PSI)*
2. **D4 cache-name single-source — OWNER DECISION** (Q: existing [decision] row, refreshed): typed per-name model + generated fragments + drift gates vs accepting parity-guarded coupling; ~half a day on protection code.
3. Convert the remaining `check_local` call-site port ARGS (forgejo 3000, immich 2283, gatus 9410…) to manifest lookups — same class as the 34, deliberately out of the plan's mechanical set; ~45 min.
4. `eval_case` negative legs for `port-registry-audit` itself (it predates the harness; my script-port-audit has legs, the older gate does not) — ~30 min. (Q candidate)
5. Ghostty phantom-PSI advisory tier in the deploy gate (see §e.1) — owner call first. (Q candidate)
6. deploy.sh pre-battery quiescence heat-check (§e.2). (Q candidate)
7. doc-counts `--restamp` auto-mode for mechanical count bumps (§e.3).
8. Manifest `healthPath` consumers: pre-deploy-check.sh could verify every catalog `healthPath` is probed by SOME battery section (coverage parity between catalog truth and the battery) — the gatus-coverage doctrine applied to the deploy battery. (Q candidate)
9. Extend the manifest with `backup.directory` + `unit` for post-deploy §19/§17 loops (already carried; wire the loops). (Q candidate)
10. rpi3-dns: give its manifest a consumer (a minimal post-deploy DNS probe battery reading the manifest) — the file exists there unused today.
11. `verify-deployment.sh` (the 9110 victim): audit its OTHER probes against the manifest (it hardcodes signoz 8080 ×5 — registered, but same drift class).
12. The standing `smoke-fail-baseline` now includes today's phantom eval-failure noise — verify the next deploy's "NEW vs baseline" diff isn't polluted (it writes only real FAILs; confirmed clean, but re-check post-deploy).
13. T13.2–13.5 execute if D4 ratifies (13.2 typed model, 13.3 one-change consumer migration, 13.4 direnv test migration, 13.5 AGENTS coupling-note removal).
14. Masterplan-v5 sweep: its remaining rows now consume the manifest (per its errata cross-link) — a session should sweep v5's script-touching rows for re-hardcode risk.
15. `llama-soak = 18848` port: consider whether the soak script should instead probe the manifest (its `--port` default is now registered but still a literal fallback).
16. push the unpushed range (9+ commits incl. daemon batches) after the deploy anchors.
17. (report self-audit §f: items 2/4–9 are Q-candidates — harvest on dispatch, not by this report)

## §g Verdict + Questions for the owner

Every executable task in the plan is DONE (verified), collapsed-with-evidence, or owner-gated by design. The wave is eval-green and committed; only the deploy + its post-deploy proof remain.

**Q1 — Deploy now?** The tree is green again, drift is real, PSI is the phantom class (`=1` path). Re-fire immediately, or wait for the parallel session's phase-2 to fully land first (their tombstone `d7d4855d5` says EXECUTING — a second moving tree)?

**Q2 — Phantom-PSI gate tier:** should ghostty-phantom-only pressure (disks ≤0.1%, mem calm, crosscheck clean) downgrade the deploy gate to advisory instead of requiring `=1`? It weakens a freeze guard; your call, not mine.

**Q3 — D4 (cache names):** typed-model refactor (~half a day, touches the direnv guard that caught the 2026-11-05 near-miss) vs accepting parity-guarded coupling as the steady state?
