# Status: Offline-Banner Extraction + Cutover Session (own-project directive) — with brutal self-review

**Date:** 2026-10-17 01:19 (session ran 2026-10-16 ~23:00 → 01:19)
**Scope:** this session only — the "own project" question, the standalone-repo build, and the SystemNix cutover. Live system untouched throughout (evo-x2 still runs v1, gen 904).
**Actor:** extraction/cutover session (this one). Two parallel sessions ran in the NEW repo (nix-skills-review 23:28, docs-health 23:58) — their work observed, not co-verified.

---

## 2-minute version

Owner asked whether the offline banner should be its own project. I argued **against** twice; owner overrode ("I want it in its own project", "SystemNix is too big"). I built `/home/lars/projects/offline-banner` (module port at v3, own flake + checks + docs + CI), queued the cutover `[blocked:push]`. Owner created the remote; I executed the cutover end-to-end: `offline-banner` flake input locked `fff0b61` (follows clean), thin wrapper in `modules/nixos/desktop/offline-banner.nix`, evo-x2 eval green, shipped-QML parity **proven by forcing the resolved restartTriggers derivation** (namespace `systemnix:offline-banner`, v3 click-dismiss + caption, probe, MemoryMax intact). All 6 SystemNix doc surfaces + the new repo's TODO/AGENTS updated. Deploy deliberately NOT done (single-switch doctrine + the smoke-test gate). One process failure that mattered: **I locked `fff0b61` without reviewing what the parallel sessions had put in it** — details in §d/§e.

---

## a) FULLY DONE

1. **Standalone repo built** — `github:LarsArtmann/offline-banner` (public, master, pushed by owner): `module.nix` (v3 port; +2 new options `package` [mkPackageOption] and `layerNamespace`), `flake.nix`, README, AGENTS, TODO_LIST, CHANGELOG, .gitignore, CI workflow (pinned action SHAs reused from SystemNix's proven workflow — no guessed hashes).
2. **Port fidelity proven** — sed-extracted QML block diffed against the SystemNix original: exactly 3 intended deltas (2 comment de-SystemNix-ifications + `${cfg.layerNamespace}` interpolation). Zero functional drift.
3. **Repo checks green (x86_64-linux + aarch64-linux)** — treefmt formatting + `module-contract` runCommand: unit present-when-enabled / absent-when-disabled, quickshell in ExecStart, `OFFLINE_BANNER_*` env contract in unit text, MemoryMax set, probe-overlap assertion fires on bad config AND stays silent on good config (**bad=1 / good=0, proven via derivation env inspection** — not just exit-0).
4. **Cutover executed** — `offline-banner` input (`?ref=refs/heads/master`, locked `fff0b61`), `nixpkgs`+`treefmt-nix` follows per infra-follows doctrine (lock-audit clean, eval would throw otherwise); wrapper module on the discordsync/inboxclean pattern; `configuration.nix` enable-line and auto-discovered filename unchanged.
5. **Parity verified on the SHIPPING artifact** — `nix eval --impure` forcing `restartTriggers` head + `readFile` of the built `shell.qml`: `WlrLayershell.namespace: "systemnix:offline-banner"`, v3 features, probe script, escapes all intact; unit `MemoryMax=256M`. This closes the "assert WHICH entity serves it" rule — not the source file, the resolved store path.
6. **evo-x2 toplevel eval green** with the input-backed module (pre-existing warnings only, unrelated).
7. **Docs updated, drift-free across all surfaces** — TODO_LIST queue (cutover `[x]` DONE, 5 debt rows `[x]` MOVED→upstream, v3 deploy row re-pointed "via input"), docs/todo/desktop.md library (same lifecycle + section header), docs/agents/desktop.md bullet, FEATURES.md row (`offline-banner.nix` → `offline-banner` input), CHANGELOG.md Changed row (dms-paste style), new-repo TODO_LIST + AGENTS Consumers.
8. **Premise-checks at queue time** — remote absence verified via `gh` BEFORE queueing `[blocked:push]`; wrapper convention grepped (5 existing examples); SystemNix's todo-system checker green after my edits.

## b) PARTIALLY DONE

1. **Cutover is code-complete but UNDEPLOYED** — deliberate (single-switch doctrine; bank-sync boot-rename rides the same switch). Live system still serves v1 (gen 904).
2. **Module debts migrated, not started** — observability, VM/negative test, IPv6 leg, demo mode, claim cleanups now live ONLY in the upstream repo's TODO_LIST (correct ownership; nothing began).
3. **`layerNamespace`→QML wiring is UNCHECKED** — my draft check for it was wrong (QML lives in the store-dir derivation, not unit text — IFD trap) and I dropped it rather than replacing it. The sibling session later added sandbox checks but NOT this. Gap stands: a rename/drift in the upstream interpolation changes the namespace silently; `niri msg layers` recipes break.
4. **CI workflow written but never observed green** — I did not check `gh run list` after the owner pushed; the upstream "Tag v0.1.0" row mentions "once master is green" — state unverified by me.
5. **New-repo TODO/AGENTS updated only at the cutover tail** — I discovered the sibling sessions' restructuring late (line numbers shifted, dprint.json, .gitignore buildflow block). My updates are consistent with the END state, but my mid-session mental model was stale for ~30 minutes of work.

## c) NOT STARTED (session scope)

1. **Hardened-unit live smoke test** — the sibling session's gate (`systemd-run --user` with the sandbox + standalone quickshell; render/probe/click-dismiss; RSS vs MemoryMax; benign Qt cache-write warnings). I re-pointed this gate at the SystemNix SWITCH (pre-deploy), not the cutover.
2. **The evo-x2 switch itself** — coordination question (pareto report §g Q1) + smoke test ordering.
3. **Upstream productization** — LICENSE, tag `v0.1.0` + GitHub Release, README CI badge, demo GIF (all queued upstream).
4. **Consumer-side contract pinning** — SystemNix currently has ZERO eval-time check that the input's unit still carries the `OFFLINE_BANNER_*` env contract (upstream CI owns it; a SystemNix relock could carry drift invisibly to local eval). Cheap assertion missing.

## d) TOTALLY FUCKED UP (process failures, honestly graded)

Nothing destroyed, no secrets, no data loss, live system untouched. But:

1. **THE BIG ONE — I locked `fff0b61` without reviewing its contents.** I built the repo at my authored state; before the owner's push, parallel sessions hardened the unit (module.nix:317-346), added `dprint.json`, restructured `.gitignore`, expanded the TODO. After "github:LarsArtmann/offline-banner now exists" I checked `git log` + `status` but never `git show --stat HEAD` / diffed my owned files. I inspected the sandbox directives only AFTER the lock and eval. It turned out sound — `NoNewPrivileges` deliberately withheld precisely because it would kill ping's `cap_net_raw` file-caps — but **that outcome was luck, not diligence**. Eval passing proves shape, not runtime (an `IPAddressDeny` or over-restrictive `RestrictAddressFamilies` would eval green and break the probe live). The smoke-test gate existed exactly for this class, and I jumped it (owner-directed) **without surfacing the gate before executing** — it appeared only in my wrap-up.
2. **Two phantom-green check iterations shipped before the good one.** v1: `badConfigAsserts >= 1` on a full nixosSystem eval — swamped by ~1,450 base assertions, green even if OUR assertion vanished (caught by inspecting derivation env = 1450). v2: namespace-via-unit-text (impossible without IFD). Both caught by my own verification instinct — but a check whose negative side is unproven should never land in the same shape as "done".
3. **tryEval misdiagnosis, twice.** I asserted "tryEval should catch attr-missing" from theory, was wrong (the throw escapes at derivation-env coercion), theorized again, was wrong again, and only then reached for the right tool (`lib.evalModules` isolation). Cost: 3 failed `flake check` cycles. A 10-second `nix eval --expr` hypothesis test would have settled it first.
4. **Edit-guard friction** — used grep output where the tool requires a View read (3 failed edit attempts across TODO_LIST/desktop.md). No damage; pure cycle waste in a racing tree.
5. **CHANGELOG versioning claim** — wrote `[0.1.0]` header while the same file says "versioning waits for the first tag". No tag exists. Should have been `[Unreleased]`.

## e) WHAT WE SHOULD IMPROVE (self-review answers)

- **Did I lie?** No fabricated claims; every "green" statement maps to a re-run command in-session. One self-correction made and disclosed immediately: "byte-identical port" turned out to have 3 intended diffs (proved by diff, disclosed same message). The `badProbeOverlapAsserts=1450` discovery forced an honest retraction of my own check's validity — good instinct, late arrival.
- **What did I forget?** (1) The owner's extraction CAMPAIGN — dms-paste extraction landed the SAME DAY and a `[decision]` PasteBot-extraction row sat in desktop.md while I argued "rule of three, currently at one". The strategic direction was already made; I analyzed the tree, not the forest. (2) The smoke-test gate's existence before executing the cutover. (3) `gh run list` for the new repo's CI.
- **Split brains?** Two live, both with mitigation paths: (1) the `OFFLINE_BANNER_*` env contract now lives in the upstream module, SystemNix's desktop.md recipes, and drop-in docs — nothing consumer-side pins it (fix: wrapper assertion, §f-2); (2) the iface-exclude list exists in upstream QML AND SystemNix's wifi-failover QML — cross-ref comment queued upstream (acceptable; same-domain duplication across repo boundaries is the price of extraction).
- **Ghost systems?** None created. Wrapper is imported, input consumed, auto-discovery intact, no dead code left (the module body was replaced wholesale, not orphaned). The `offline-banner` flake attr `nixosModules.offline-banner = offlineBannerModule;` aliases `default` — single source, no drift.
- **Tests?** Upstream: eval-contract checks incl. one proven-negative pair (good). No render test (needs a compositor — correctly out of CI scope), no VM probe test yet (queued upstream). Consumer: zero pinning (§f-2). Standard reached: better than the in-tree module ever had (it shipped with NO checks); still below the repo's sev1 8-scenario bar.
- **Scope creep?** One deliberate scope addition: the `package` + `layerNamespace` options (required by the extraction's own semantics — a standalone repo with a hardcoded `systemnix:` namespace would be a naming lie). Otherwise stayed inside the mandate.
- **How to be less stupid:** (1) after ANY gap where parallel sessions may have touched a repo I'm about to lock/consume: `git show --stat HEAD` + diff my owned files FIRST — "the remote exists" is not "the remote contains what I wrote"; (2) prove a check's negative side in the same iteration as the check; (3) when jumping a documented gate under owner direction, NAME the gate in the executing message, not the wrap-up; (4) test evaluator-behavior hypotheses with a one-liner before building on them.

## f) NEXT (deduplicated against existing rows — new items marked NEW)

**Do before the switch (SystemNix):**
1. [NEW] Reference the hardened-unit smoke-test gate ON the SystemNix v3 deploy row (currently the gate lives only in the upstream repo's TODO + AGENTS — a future dispatcher could switch cold). Tiny doc edit.
2. [NEW] Consumer-side pin: wrapper assertion that the resolved unit text carries `OFFLINE_BANNER_INTERVAL/_PROBE_HOST/_PROBE_TIMEOUT/_FAILURES` — closes the env-contract split brain at relock time.
3. Hardened-unit live smoke test (upstream row, re-gated by me to pre-switch) — then ONE combined switch carrying v3-via-input + bank-sync + the rest of the deploy-pending batch (single-switch doctrine, pareto §g Q1).
4. Post-switch verify: `niri msg layers` shows `systemnix:offline-banner`, unit restarted on the new store path, banner still armed (this unit is already live — no stc cold-start trap).

**Upstream repo (already queued there — listed for completeness, NOT re-harvested):**
5. State-transition observability (journal line + fail-closed `offline_banner_active` metric).
6. VM/negative test (`OFFLINE_BANNER_SYSROOT` + probe injection).
7. Demo mode `OFFLINE_BANNER_DEMO=1`.
8. IPv4-only probe blind spot (v6 leg or documented tradeoff).
9. Claim cleanup (DMS-plugins-layer-shell claim; iface-list cross-ref; gen-904 provenance; AGENTS pointers).
10. `sandboxInUnit` full-line assert (~15 sandbox lines, not 3 markers).
11. `failuresToShow` sanity bound; `restartTriggers` drift guard; docs-drift gate (README vs module).
12. Tag `v0.1.0` + Release + verify CI green + badge.
13. Demo GIF for README.
14. dprint.json fate + .gitignore buildflow-block provenance ([decision] rows).
15. `.config/metadata.yaml` fate.
16. [NEW] QML-reachability check: expose the shell as a passthru package and grep the BUILT qml for `namespace:` + probe markers in a runCommand — closes the §b-3 gap properly (no IFD at check-build time).
17. Unit-syntax gate (`systemd-analyze verify` on rendered unit.text).
18. Formatter/channel-intent/optionDoc [decision] rows.

**Owner-gated:**
19. LICENSE choice (question g-1).
20. Daemon-vs-hand commit hygiene for the now-public repo (question g-3).

**Harvested:** #1 (edit to the v3 deploy row), #2 (new SystemNix row → desktop.md), #16 (new upstream TODO row). Items 5-15, 17-18 deliberately NOT re-harvested — already tracked upstream. 19-20 deliberately not harvested — owner-gated questions below.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **LICENSE for `github:LarsArtmann/offline-banner`?** Public + unlicensed = all-rights-reserved for everyone else. Sibling `niri-session-manager` is GPLv3; your Go libs vary. GPL-3.0 / MIT / Apache-2.0 — pick one and I'll add the file + README badge.
2. **Switch ordering:** must the hardened-unit smoke test gate EVERY next evo-x2 switch (delaying the bank-sync batch if needed), or is a cold switch acceptable given eval-green + the sandbox analysis? I re-gated it pre-switch by default — override if you want speed over proof.
3. **Commit hygiene for the public repo:** the auto-commit daemon sweeps it with `chore: auto-commit N files (heuristic)` — is daemon coverage INTENDED for extracted public repos, or should they get real commits (and should I hand-commit there when told to commit)? This decides whether future sessions amend/land properly or ride the daemon.

---

**Verdict:** extraction + cutover landed clean and verified on the shipping artifact; the deploy-gate sequence is intact but its documentation was completed out of order, and the biggest lesson is about trusting repo contents across session boundaries without diffing them.
