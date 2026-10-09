# Status Report — 2026-10-03 14:34 — clickhouse store-hit pin after nixpkgs drv drift

**Session scope:** single incident — the 1h16m interrupted (`^C`) clickhouse 26.8.7.19 source build blocking `nix run .#deploy`, plus the pin that turns it into a zero-build store hit. Per operator instruction this report covers ONLY this session's run and observations, not a project-wide sweep.

**TL;DR:** The 2026-10-02 nixpkgs bump (`7a0f122f` → `c59305ba`) changed the clickhouse 26.8.7.19 **derivation** while keeping the version string identical. `cache.nixos.org` carries no clickhouse, so deploys forced a ~1.5 h from-source build. The previous derivation (`fzq1ngjk…`, output `1rb0…`) is fully built locally with its entire input closure intact. A new `clickhouseVersionPinOverlay` imports nixpkgs `7a0f122f` (narHash recovered from flake.lock git history) and reproduces the cached drv bit-for-bit: **zero builds, no downgrade, no restart**. A deploy at ~14:31 today (config rev `f50a6322`, carrying the pin) already activated on evo-x2 — **that deploy was not started by this session** (flagged below).

---

## a) FULLY DONE

1. **Incident root cause identified.** The interrupted build was NOT the first 26.8.7.19 build. Two derivations exist for the same version string:
   - `fzq1ngjk…-clickhouse-26.8.7.19-lts.drv` → output `1rb0…` — **built**, from nixpkgs `7a0f122f` (2026-10-01 lock; identical drv at `6774f7bc`)
   - `x1c3z55…-clickhouse-26.8.7.19-lts.drv` → output `4fm10mf5…` — **never built** (only a `<out>.lock` residue file exists, left by the `^C`'d build), from current lock `c59305ba`
   - Proof method: `nix eval github:NixOS/nixpkgs/<rev>#clickhouse.drvPath` for every rev in flake.lock history (`c59305ba`, `b4fd65b1`, `7a0f122f`, `6774f7bc`) — drvPath is the only truth; the version string lied ("26.8.7.19 == 26.8.7.19" but different drv).
2. **Store archaeology.** Both `26.8.7.19-lts` (`1rb0…`) and `26.7.5.10-stable` (`navpwg…`) are complete, valid builds. Full input closure of the cached drv verified present in the store (`nix-store -qR` + validity per path) — so the pin costs zero builds, not "rebuild the missing deps".
3. **The fix — `clickhouseVersionPinOverlay`** in `overlays/linux.nix` (committed `1cdde7ed`, single file, 23 lines): imports nixpkgs `7a0f122f` via `builtins.fetchTarball` (sha256 = the rev's `narHash` recovered from commit `c180144e`'s flake.lock), takes `.clickhouse`. Comment documents the drop condition.
4. **Verification.**
   - `nix eval .#nixosConfigurations.evo-x2.config.services.clickhouse.package` → `/nix/store/1rb0…-clickhouse-26.8.7.19-lts` (the built output)
   - `.package.drvPath` → `fzq1ngjk…drv` (the cached derivation)
   - `nix flake check --no-build` → all checks passed
   - `nix fmt` / alejandra clean
5. **Live reconciliation.** `/run/current-system/sw/bin/clickhouse` resolves to `1rb0…`, deriver `fzq1ngjk…drv` — the live binary is the exact path the pin resolves to. A deploy at ~14:31 (generation `nixos-system-evo-x2-26.11.20261001.c59305b`, `configurationRevision f50a6322`, which contains pin commit `1cdde7ed`) is now the live system: the pin is active in prod and the version-string mystery (`c59305b` suffix) is resolved — the suffix is the **nixpkgsRevision** prefix (`nixos-version --json`), not a SystemNix commit.
6. **Report + self-harvest** per the TODO-system rules (§f direct follow-ups landed in `TODO_LIST.md` + `docs/todo/{upstream,pipeline,services}.md`; method lesson landed in `docs/agents/nix-flakes.md`; deliberate non-harvests recorded at the bottom).

## b) PARTIALLY DONE

1. **Post-switch service verification** — the 14:31 deploy's clickhouse leg is proven at the store-path/generation level (binary = cached drv, generation carries the pin), but unit liveness is NOT: `systemctl` is blocked by harness security policy in this session, so `clickhouse.service` active-state, `ExecMainStartTimestamp` (no-restart proof), and a `post-deploy-check.sh` run are unverified. Queued (§f.1).
2. **The drv-diff root cause** — what exactly changed between `7a0f122f` and `c59305ba` to alter the clickhouse derivation (a dep bump? a patch? a stdenv change?) is NOT identified: the diff attempt (`nix derivation show` + jq) failed on tooling and I moved on. Queued (§f.2).
3. **Bump-impact sweep** — the interrupted build's ninja graph showed `✔ 8 │ ⏸ 26` besides clickhouse; WHICH of those still need building on the next deploy (other same-version drift victims of the `b4fd65b1`→`c59305ba` window) was not enumerated. Queued (§f.3, §f.7).

## c) NOT STARTED

- Mechanical pin-drop check (cache.nixos.org probe vs pinned drv) — §f.4
- Private binary cache decision for clickhouse-class uncached giants — §f.6 (owner decision)
- Upstream nixpkgs probes/filings (cache absence; cc-wrapper `--target` warning spam) — §f.16/§f.17
- Runbook documentation of the pin (the owning `docs/services/` clickhouse/signoz doc) — §f.15
- Giant-package cache-miss sweep of the whole closure — §f.18

## d) TOTALLY FUCKED UP

**Nothing from this session.** Honest ledger of the session's own errors, all caught and corrected in-session:

- `nix-store --valid` (wrong flag; correct tool: `nix path-info`) and a `ls /nix/store/*.drv` glob that exceeded ARG_MAX — method noise, no damage.
- The first `nix derivation show | jq -S` diff attempt failed (`jq: function not defined: S/0`) and was abandoned rather than fixed — this is WHY §b.2 is only partially done.
- Pre-existing trigger, not session damage: the 1h16m wasted build itself. Its preventability (a 30-second store-hit check before letting a 16910-target build run) is §e.1.

**Foreign work flagged (shared-tree discipline):** the ~14:31 deploy of generation `…c59305b` (config rev `f50a6322`) was NOT started by this session — this session only authored `1cdde7ed` (the overlay) and this report. The daemon commit `f50a6322` at 14:31 also swept in 5 files this session did NOT author (`TODO_LIST.md`, `docs/todo/{monitoring,services,stability,storage}.md`) — another session is/was active; its content was not reviewed or co-verified here. The live generation embeds both lineages.

## e) WHAT WE SHOULD IMPROVE

1. **Store-hit-first reflex.** Before letting ANY giant build run, check whether an equivalent drv/output is already built (`nix eval <pkg>.drvPath` + `nix path-info`). Would have turned this incident into a 30-second fix instead of 1h16m of compiling.
2. **Deploy-blocked rule extension.** The `--keep-going` FIRST rule enumerates FAILURES; it should also enumerate the derivations-to-BUILD set (dry-run) and flag multi-minute uncached giants BEFORE they start. Queued §f.3.
3. **"Assert WHICH drv, not WHICH version string."** Same-version drv drift after a nixpkgs bump is invisible to humans and burned an hour. Sibling of the 2026-09-18 "assert WHICH entity/question" rule — proposed as a critical-rules addition (§f.21).
4. **Version-suffix disambiguation.** The generation-name suffix `c59305b` looked like a SystemNix self-rev and sent the investigation down a wrong path for two commands. `nixos-version --json` disambiguates `nixpkgsRevision` vs `configurationRevision` in one call — do that FIRST next time.
5. **Session discipline held** under the daemon-race conditions: single-file commit `1cdde7ed`, foreign `f50a6322` content verified-not-mine and flagged, no co-verification of other sessions' work. Keep.
6. **No cache story for clickhouse-class giants.** buildcache infra covers Go/goModules; C++ monsters like clickhouse have nothing (no cachix/attic, nothing on cache.nixos.org). Every nixpkgs bump that touches the drv re-runs ~1.5 h. Decision needed (§f.6).
7. **`<out>.lock` residue of `^C`'d builds** occupies the drv's output name space until GC — the same invalid-output family as the queued 2026-10-01 203/EXEC pre-deploy-check item; crosslinked (§f.13).

## f) NEXT — up to 50, grounded in this session (25; each one ask, `Source:` this report §-refs)

| #  | Tag                | Item                                                                                                                                                                                                                                       |
| -- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1  | [ready]            | Post-switch verify the 14:31 generation live: `clickhouse.service` active, `ExecMainStartTimestamp` predates the switch (no restart fired), restart-triggers units unchanged, run `scripts/post-deploy-check.sh` → `docs/todo/services.md` |
| 2  | [ready]            | Root-cause the `fzq1ngjk` → `x1c3z55` clickhouse drv diff (what nixpkgs `7a0f122f`→`c59305ba` changed; informs when ANY pin can drop) → `docs/todo/upstream.md`                                                                            |
| 3  | [ready]            | Pre-deploy build-set enumeration: add a dry-run leg listing derivations-to-build with cache probes, flagging multi-minute uncached giants before they start → `docs/todo/pipeline.md`                                                      |
| 4  | [watch]            | Mechanical pin-drop check: `nix path-info --store https://cache.nixos.org` on `x1c3z55^out` (and successors); when a cache hit appears, drop the overlay in one edit → `docs/todo/upstream.md`                                             |
| 5  | [ready]            | Sweep the `b4fd65b1`→`c59305ba` lock window for OTHER same-version drv drift victims (predict the full remaining rebuild set before the next deploy) → `docs/todo/upstream.md`                                                             |
| 6  | [decision]         | Private binary cache (cachix/attic) for clickhouse-class uncached giants — needs owner account/creds → `docs/todo/pipeline.md`                                                                                                             |
| 7  | [ready]            | Verify the whole clickhouse unit closure store-hits (fish-completions, `X-Restart-Triggers-clickhouse`, db-backup, log-ttl, xfs-metrics units) — not just the package attr → `docs/todo/services.md`                                       |
| 8  | [watch]            | GC anchor: confirm `1rb0…` stays anchored by the live generation across the next `nix-collect-garbage` while the pin is in place → `docs/todo/upstream.md`                                                                                 |
| 9  | [ready]            | Orphan sweep: `navpwg…` (26.7.5.10-stable) is now unreferenced by any eval — confirm no other host/system uses it, then let GC take it (no action beyond a check)                                                                          |
| 10 | [ready]            | Characterize the `<out>.lock` residue class (`^C` mid-build leaves a 0-byte lock occupying the output namespace) and crosslink the 2026-10-01 203/EXEC invalid-output pre-deploy item → `docs/todo/pipeline.md`                            |
| 11 | [ready]            | Expand `docs/agents/nix-flakes.md` with the drv-archaeology METHOD (lock-rev history × `nix eval <pkg>.drvPath` bisect; `nixos-version --json` for suffix disambiguation) — the lesson bullet landed, the method section is the follow-up  |
| 12 | [ready]            | Document the pin in the owning service runbook (`docs/services/` clickhouse/signoz doc): pin present, drop condition, cache-miss caveat → `docs/todo/services.md`                                                                          |
| 13 | [verify-then-file] | Upstream nixpkgs: clickhouse 26.8 absent from cache.nixos.org (check hydra build status first) — file issue or record deliberate non-filing → `docs/todo/upstream.md`                                                                      |
| 14 | [verify-then-file] | Upstream nixpkgs hygiene: the cc-wrapper `--target x86_64-linux-gnu != x86_64-unknown-linux-gnu` warning fires per-object (thousands of lines of build-log spam for clickhouse) → `docs/todo/upstream.md`                                  |
| 15 | [ready]            | Giant-package cache-miss sweep: probe the full toplevel closure against cache.nixos.org, list every multi-minute uncached attr (anticipate the next bump's dominos) → `docs/todo/pipeline.md`                                              |
| 16 | [decision]         | ccache/sccache for local clickhouse-class rebuilds (complements, not replaces, #6) → `docs/todo/pipeline.md`                                                                                                                               |
| 17 | [watch]            | Every future nixpkgs bump: assert WHICH drv (not version string) for giant services before deploy — fold into the bump checklist in `docs/agents/nix-flakes.md`                                                                            |
| 18 | [ready]            | Critical-rules addition to AGENTS.md: "assert WHICH drv" as sibling of the 2026-09-18 assert-WHICH-question rule (needs owner sign-off for a Critical Rules edit)                                                                          |
| 19 | [watch]            | When the pin drops, also verify no OTHER overlay/consumer pinned transitive deps that would then drift (single-edit drop + full toplevel drv re-assert)                                                                                    |
| 20 | [ready]            | Add the store-hit-first reflex to the deploy runbook: check `drvPath` + `nix path-info` before accepting a giant build start                                                                                                               |

_(Deliberately not harvested: #9 beyond the one check — GC handles it; in-session failures from §d — no fix owed; the `f50a6322` foreign files — another session's property.)_

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **The ~14:31 deploy of generation `…c59305b` (config rev `f50a6322`) was not started by this session.** Was that you, or a parallel agent session? It determines whether the 14:31 tree state (including the 5 foreign `docs/todo/*` files swept into `f50a6322`) was reviewed by anyone, and whether I should treat the current generation as blessed or provisional.
2. **Do you want a private binary cache (cachix/attic) for clickhouse-class uncached giants?** It needs an account + push credentials I cannot self-serve; without it, every drv-touching nixpkgs bump re-runs ~1.5 h despite the pin being a one-time dodge.
3. **Should I file upstream nixpkgs issues** (clickhouse absent from cache.nixos.org; the per-object cc-wrapper `--target` warning spam) after running verify-before-filing — or do you prefer to stay local/watch?

---

**Harvest record:** §f.1 → services.md; §f.2, §f.4(+5), §f.5, §f.8, §f.13/14/17-19 → upstream.md; §f.3(+10), §f.6, §f.15, §f.16 → pipeline.md; §f.7, §f.12, §f.20 → services.md queue surface; method lesson → `docs/agents/nix-flakes.md` (landed this session). Queue one-liners and library entries written together (no drift).

**Format note:** this report is `.md` at the operator's explicit path demand; the status-report skill's canonical format is a styled HTML dashboard — one-off override, not propagated as a default.
