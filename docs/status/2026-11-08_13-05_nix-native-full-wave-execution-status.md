# Nix-Native Modernization — Full-Wave Execution Status

**Date:** 2026-11-08 (session start ~07:18, execution ~07:20–13:0x)
**Plan:** `docs/planning/2026-11-08_06-31_SUPERB-nix-native-modernization-pareto-plan.md` (§10 = execution record)
**Trigger:** owner GO ("The WHOLE TODO LIST! DO NOT STOP UNTIL THE ENTIRE LIST IS FINISHED and VERIFIED")

## §a Done (task → landing)

| Task | Outcome | Evidence |
|---|---|---|
| T1 manifest v1 | DONE | `lib/integration-manifest.nix` (union view, checkUrl parity, assertJsonSafe); evo-x2 manifest BUILT green (78 ports / 88 services, checkPhase jq) |
| T2 runtime exposure | DONE | `modules/nixos/services/integration-manifest.nix` → `/etc/systemnix/integration-manifest.json` (0644); rpi3-dns imported (catalog-only subset verified eval) |
| T3 battery conversion | DONE | 34 host-form literals dead; loader `scripts/lib/integration-manifest-loader.sh`; grep proof zero `localhost:[0-9]`; verdict parity byte-identical live (three battery runs: pre-baseline 167/5/4/14 → post-conversion 168/5/3/14 → post-extraction identical, FAIL set unchanged & baseline-matched) |
| T4 degrade/drift | DONE | absent-manifest WARN+SKIP live-proven (battery-degraded run); drift WARN live-proven (empty-ports stub run); standing `integration-manifest-loader-selftest` 8/8 |
| T5 script-port-audit | DONE | eval gate live (evo-x2 eval green, offenders empty); `CASES=scriptport` 3/3; FIRST SWEEP caught verify-deployment.sh @ stale 9110 (dead 12 days) + llama-rag-soak unregistered 18848 → fixed/registered |
| T6 vHost timeout | DONE | max(client.timeout) derivation live-verified (floor 20 → 30); pipeline.md:407 + TODO_LIST row ticked (both surfaces) |
| T7 doctrine | DONE | integration-registry.md §Manifest Bridge + adding-a-service step 3 amended; AGENTS critical rule extended |
| T8 hermeticity | COLLAPSED→errata E1 | all 7 readFile embeds were ALREADY writeShellApplication+pinned deps; 8.7 comment + 8.8 clean grep delivered |
| T9 registry matrix | DONE | 88-row generated table in the doc; `checks.registry-matrix-drift` red/green proven (corrupt→STALE, restore clean); `packages.registry-matrix` regen path |
| T10 LAN-IP | COLLAPSED→errata E2 | deployed units already inject `networking.local`; provenance comments ×3 |
| T11 port range guard | DONE | int/1-65535 at import; red (141100 throws naming pocket-id) + green (78 ports eval) |
| 12.1 tmux | DONE+ | all SIX dead `just` bindings rewired to flake apps |
| T13 cache-names | 13.1 only; D4 HELD for owner | [decision] row refreshed with verified inventory + ~half-day cost on protection code |
| T14 closure | DONE | plan §10 + EXECUTED tombstone; masterplan-v5 errata cross-link; CHANGELOG entry; T1-T4 rows ticked both surfaces |

## §b Verification summary

- `nix flake check --no-build` rc=0 (whole eval-guard army, post-everything).
- Negative legs: scriptport 3/3; registry-matrix red/green; ports-range red/green.
- Battery parity: three full live runs, converted sections byte-identical verdicts; only delta = time-varying PSI WARN text.
- shellcheck rc=0 on every touched script; statix clean on new nix files.
- Commits: `dc17077c0` (T1/T2), `57cbd4654` + daemon-swept batch (T3–T7, T11, 12.1), `66fb1e864` (T8/T9), `aa496d770` (T4.3/T10/T13/T14). Daemon interleaved mid-batch (3 soft-reset splits per CONTRIBUTING policy; content verified complete, zero loss: `git diff` clean vs work at every step).

## §c Process notes (the honest ledger)

1. **My own mid-edit background-job race (the 2026-11-05 class, live again):** launched the degradation battery run, then immediately applied the T6 edit to the SAME script — bash read a half-written file and died `GGUF: command not found` at a comment line. Degradation WARNs had already fired pre-crash; re-ran clean after edits were final. The AGENTS rule existed; I violated it by sequencing, not by ignorance.
2. **jq hyphen-key trap hit twice** (`pocket-id` parsed as subtraction → "id/0 is not defined"): bracket-form `.ports["pocket-id"]` everywhere now.
3. **doc-counts caught me twice** (module count 148→149→150, packages 49→50) — the gate earned its keep against the very session adding modules.
4. **The tracked-files trap** on new part files (eval fails until `git add`) — known, still cost one cycle.
5. Daemon-race: 3 soft-reset splits + 1 land-on-top; the flagship T3-T7 message rode a 1-file commit with the batch described in its body (heuristic diffs carry the rest — standing practice).

## §d Deploy

Deferred at time of writing: a PARALLEL session's `nix build .#checks.x86_64-linux.island-js` held IO PSI at avg60 55→67% (deploy-gate storm threshold); deploying into that contention violates the IO-storm hygiene. The deploy runs as soon as PSI drains (§e row 1); post-deploy legs: live `/etc/systemnix/integration-manifest.json` probe (jq stdin form), full battery on the DEPLOYED generation (the real parity proof — loader consuming the live file, not SYSTEMNIX_MANIFEST), deploy anchor check (`readlink /run/current-system` vs newest `system-N-link` by NUMBER).

## §e Open / follow-ups

1. **[this session, pre-close] Land the deploy + post-deploy battery** — the wave is eval-green and committed but the manifest is not live until the switch; §d.
2. **D4 cache-name single-source (OWNER DECISION)** — `docs/todo/pipeline.md` [decision] row refreshed 2026-11-08 with the verified 3-surface inventory + costs; deliberately NOT executed (protection code, no plan recommendation). Harvested: stays as the existing [decision] row.
3. **Not harvested (deliberately):** none — every §f item below maps to an existing row or this report.

## §f Direct follow-ups (self-harvested at authoring time)

1. ~~Land the deploy~~ — tracked in §d/§e row 1, deliberately a this-session obligation, not a queue row.
2. D4 → the existing refreshed [decision] row (pipeline.md, single-source cache names) — no new row needed.

## §g Verdict

Every executable task in the plan is DONE, collapsed-with-evidence, or owner-gated by design. The two premise collapses (T8/T10) were verified findings, not skipped work — the plan's own verification-first doctrine working as intended on itself.
