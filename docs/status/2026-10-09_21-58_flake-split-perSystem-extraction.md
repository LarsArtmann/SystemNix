# Flake Split Status — flake.nix 4023 → 1147 lines (flake/parts/ extraction)

**Date:** 2026-10-09 21:58
**Session:** split flake.nix perSystem monolith into flake-parts modules
**Baseline pinned:** `5d4bb3be` (clean tree at session start)
**Current:** refactor eval-verified equivalent; docs/commits/gate still open

---

## a) FULLY DONE

1. **Research & design (verified, not assumed):**
   - flake-parts source inspection (store checkout): `perSystem` modules get `inputs'`/`self'` only — raw `inputs`/`self` THROW (`modules/perSystem.nix:123-124`); the canonical pattern is binding `inputs` at the top-level module head and closing over it lexically — this kept all moved bodies byte-identical.
   - **Empirical:** `inputs = import ./flake/inputs.nix;` is REJECTED by Nix 2.34.8 ("expected a set but got a thunk" — same class the 2026-10-02 dedup session hit with `let`/`//`). **Inputs MUST stay a syntactic attrset in flake.nix.** Verified in a /tmp throwaway flake, never in this repo.
   - Prior planning checked (`docs/planning/2026-10-02_09-47_flake-lock-infra-dedup.md` — lock dedup, does not block a file split; its "inputs attrset in flake.nix" doctrine pointers stay valid because inputs don't move).
2. **The split (all files format-clean under nixfmt, eval green):**

   | File | Lines | Contents |
   | --- | --- | --- |
   | `flake.nix` | **1147** (was 4023) | description, nixConfig, inputs (927, untouchable — parser + trap docs), eval guards, shared let-bindings, mkFlake with `imports = [ parts… ] ++ discoveredModulePaths`, `_module.args` (mkLarsPackages, sharedOverlays, linuxOnlyOverlays, disableTests, theme, root), flake.lib + hosts |
   | `flake/parts/pkgs.nix` | 32 | perSystem `_module.args.pkgs` nixpkgs instantiation |
   | `flake/parts/formatter.nix` | 51 | treefmt wrapper |
   | `flake/parts/packages.nix` | 102 | mkLarsPackages + nixpkgs picks + Linux-only |
   | `flake/parts/devshells.nix` | 55 | default + quickshell shells |
   | `flake/parts/apps.nix` | 282 | mkApp + all 19 apps |
   | `flake/parts/checks/lint-static.nix` | 689 | statix/deadnix/module-shape/dead-guard/gatus×2/signoz/binary-coverage×2 (shared binaryCoverageScanner let)/gitleaks/lock-audit/chown-vs-bind |
   | `flake/parts/checks/fixtures-forgejo.nix` | 578 | forgejo-scripts + migrate-forgejo-subvol |
   | `flake/parts/checks/fixtures-storage.nix` | 549 | borg-restore-drill + root-prune + btrfs-scrub-staleness |
   | `flake/parts/checks/fixtures-migrations.nix` | 203 | browser-history-probe-purge + migrate-{hot-db,rust-cache,caddy-logs} |
   | `flake/parts/checks/selftests.nix` | 478 | disko-samsung-tlc + 11 pre/post-deploy + precommit selftests + exit-contracts + buildcache parity |
   | `flake/parts/checks/vm-tests.nix` | 25 | the original `// lib.optionalAttrs isLinux (import ./tests)` tail |

   All 37 flake.nix checks, 19 apps, packages, devShells, formatter accounted for (name-inventory asserted programmatically against the pristine baseline).
3. **Path rewrites:** ~85 root-relative path literals (`./scripts/…`, `${./.}`, `import ./…`, list-file args) rewritten to `root`-based forms (`root` = `./.` passed via `_module.args`; parts live one+ dirs deeper so `./` semantics changed). Each rewrite printed and reviewed; survivors found by eval failure were fixed (see d).
4. **Equivalence proof (drvPath fingerprints, same lock):** because the lock drifted mid-session (external re-lock), the baseline was re-captured in a throwaway git worktree at `5d4bb3be` + the CURRENT flake.lock — isolating the refactor as the only variable.
   - **packages.x86_64-linux: BYTE-IDENTICAL (41/41)**
   - **devShells: BYTE-IDENTICAL** · **darwinConfigurations: BYTE-IDENTICAL**
   - **nixosConfigurations: rpi3-dns + zfs-vm BYTE-IDENTICAL**
   - checks: 74/100 byte-identical; the 26 differing drvs all embed the flake SOURCE path (`cd ${root}` etc.) — the source tree content changed (that IS the refactor), so their source store hash differs **by design**; no check appeared/vanished.
   - apps: 17/19 identical; pre/post-deploy-check differ in the same source-embedding class (`cp ${root}/scripts/…`).
   - **evo-x2 toplevel: differs — PROVEN benign**: `etc`-derivation store-path-set diff shows ZERO name-set differences (no package added/removed anywhere); the only same-name-different-hash paths are the whole-tree `-source` copies (`…-source/modules/nixos/services/dashboards/*`) plus the mechanical rebuild cascade (etc → system-path/system-units/user-units/dbus-1/fish-completions/terminfo). The system's eval path never touches perSystem outputs, so content is equal; only tree-derived store paths rehash.
   - formatter: differs ONLY by the one intended error-message string ("rework the formatter override in flake/parts/formatter.nix") — upstream treefmt path identical, patched toml byte-identical.

## b) PARTIALLY DONE

- **Commit hygiene:** the daemon committed in-flight states (`071be0eb` 277-file sweep incl. a BROKEN apps.nix, `151912dc` titled "refactor(flake): split…", then `c0770141`/`edab9394`). The final corrected files are staged/committed on top, but the amend-forward analysis (`git show --stat` per daemon-race policy) and a clean pathspec commit of the final state have NOT been done.
- **Moved-text "flake.nix" mentions:** the formatter message was fixed; a sweep of the other moved comments/messages for now-stale "in flake.nix" pointers has not been run.
- **`nix flake check --no-build`:** NOT yet run on the final state (the strongest remaining gate; checks fingerprint evals passed, which covers most of it).

## c) NOT STARTED

- Docs: AGENTS.md architecture sketch (flake.nix line + flake/parts row), `docs/agents/nix-flakes.md` flake/parts structure+conventions section (incl. the empirically-verified "inputs must stay syntactic" rule), CHANGELOG entry.
- TODO_LIST self-harvest of this report's §f (repo rule: harvest at authoring time).
- Final verification battery: `nix flake check --no-build`, pre-commit hook run, standalone re-lint after any daemon-swept amend.
- Cleanup: `git worktree remove /tmp/sn-baseline`; trash nothing else (no `rm` per policy).
- evo-x2 toplevel background BUILD to warm the deploy cache (doctrine after structural evals).

## d) TOTALLY FUCKED UP (and recovered)

1. **Hand-typed line-number extraction (first attempt):** I transcribed ~40 check line-ranges by hand from an rg snapshot; `nix fmt` reformatted flake.nix between my mapping and the extraction, plus a concurrent session touched the file — mixed numberings produced an apps.nix missing its `let` and a stray `{` in lint-static (nixfmt caught both: "unexpected '='" / "unexpected '{'"). **Recovery:** full regeneration from the pristine `5d4bb3be` blob with programmatic anchor discovery (regex + comment-walk) and inventory assertions — zero hand-typed numbers. Lesson encoded in §e.
2. **Two silent no-op `str.replace`s:** the imports-list and `import nixpkgs`→`import inputs.nixpkgs` replacements matched nothing (anchors reformatted / dedented-line prefix assumption) and python's `str.replace` fails silently — symptoms surfaced only as `apps: []`/`checks: []` (parts not imported) and `undefined variable 'nixpkgs'`. **Recovery:** assert-anchored replaces. `apps:19 checks:100 packages:41` after.
3. **Path-rewrite regex coverage gap:** 9 value-position paths (`auditWith ./tests/fixtures/…`, module-list args `./platforms/nixos/system/backup.nix`) escaped the rules; first symptom: `Path 'flake/parts/checks/platforms/…' does not exist` (relative resolution against the PART FILE's dir — exactly the hazard `root` exists for). Fixed; the two `:23/./repo` SSH-URL fragments were correctly left alone.
4. **External breakage absorbed:** a concurrent session narrowed `tests/test-paperless-gpt.nix` head `{pkgs, inputs}` → `{inputs}` while its body still uses `pkgs.` exactly once — `tests/default.nix:41` still passes pkgs → every checks eval threw "unexpected argument 'pkgs'". I restored the `pkgs,` arg (minimal forward-fix, body still uses it). **Flagged to the user — not my edit to own.**

## e) WHAT TO IMPROVE

- **Never hand-transcribe line ranges for file surgery** — always re-derive anchors programmatically from the exact blob being carved, with inventory assertions (37/37 checks matched after the rewrite).
- **Every string replace must assert it fired** (`assert old in t`), and scaffold emission must assert expected structure keywords (`let`/`in`/`{`) — both classes cost debug cycles here.
- **Post-extraction invariant before ANY eval:** `grep -rn '[^-a-zA-Z]\./[a-z]' flake/parts/` must return zero path literals (the two-line check that would have caught item d.3 instantly).
- **Baseline the worktree BEFORE the first edit** in shared-tree sessions — the lock drift mid-session invalidated the original baseline and forced a worktree re-baseline.
- **`nix fmt` mutates the working tree between script phases** — extraction scripts must run against a frozen snapshot (the git blob), not the live file. (The regen script does; the first one didn't.)

## f) Next tasks (impact-sorted)

1. Run `nix flake check --no-build` on the final tree (the repo gate; expect green — all 100 checks eval).
2. Daemon-race close-out: `git show --stat` on `071be0eb`/`151912dc`/`c0770141`/`edab9394`; amend-forward IF contents are exclusively this refactor's files; re-run any pre-commit lint legs the daemon-swept commits skipped.
3. Sweep moved text for stale "flake.nix" pointers (comments/error messages in parts files).
4. AGENTS.md: update the architecture sketch (flake.nix row + `flake/parts/` row + module auto-discovery note now also mentions parts).
5. docs/agents/nix-flakes.md: new "flake/parts structure" section — conventions (head args via mkFlake specialArgs + `_module.args`, `root` instead of `./`, perSystem merging), and the empirical inputs-must-be-syntactic rule (with the /tmp repro).
6. CHANGELOG.md `Unreleased → Changed` entry for the split (evidence: fingerprint parity table above).
7. TODO_LIST.md harvest of this §f per the self-harvest rule (route to docs/todo/pipeline.md as the owning domain).
8. `git worktree remove /tmp/sn-baseline`.
9. evo-x2 toplevel background build (warms deploy cache; also converts the etc-cascade proof into a built artifact).
10. Grep repo docs for "4023" / "flake.nix checks" style claims now stale (docs/CONTRIBUTING.md module templates?).
11. Decide + document whether `flake/parts/checks/*` grouping names (lint-static/fixtures-*/selftests/vm-tests) become doctrine in nix-flakes.md so new checks have an obvious home.
12. The `warning: input 'go-structure-linter' has an override for a non-existent input 'treefmt-nix'` seen on eval — external (lock/follows interaction from the concurrent lock edit); route to docs/todo/pipeline.md if it persists after the next reconcile.
13. Tell the owning session (user) about the paperless-gpt head-narrowing fix (d.4) — if their intent was a full pkgs-removal, the remaining `pkgs.` usage in the body is theirs to finish.
14. Post-merge: verify CI green on push (nix-check.yml runs the same gate + VM tests).
15. Optional: consider a `treefmt` or statix/deadnix pass over flake/parts as a unit (already formatted; belt).
16. Update `docs/agents/README.md` provenance map if it references flake.nix sections that moved.

## g) Questions (cannot resolve myself)

1. **paperless-gpt test head:** the concurrent narrowing (`{pkgs, inputs}` → `{inputs}`) left one `pkgs.` usage dead — I restored `pkgs,` to unblock the shared eval gate. If the narrowing was mid-flight work, coordinate: either they remove the last `pkgs.` usage, or my restore stands. Which?
2. **Lock drift ownership:** branching-flow (+ others) re-locked externally mid-session; I treated the new lock as canonical (re-baselined against it). If another session is holding/rolling back that lock, my parity evidence is against the transient state — confirm the new lock is wanted.
3. **Push:** after the final pathspec commit + `nix flake check` green, should I `git push` (push-protection aware), or leave pushing to you?

---

**Bottom line:** flake.nix went 4023 → 1147 lines (927 of which are the parser-locked inputs registry — the maximum split Nix allows). All logic now lives in 11 focused flake/parts modules. Output equivalence is proven at the strongest feasible level given the tree itself changed: every non-source-embedding output is BYTE-IDENTICAL, and every differing derivation is mechanically explained by whole-tree source-path rehashing (name-set diff: zero). Remaining work is commits/docs/gate — §f 1–8.

---

## CLOSE-OUT (2026-10-10 follow-up session — §f resolution ledger)

**HARVESTED + EXECUTED same-session.** The tree was NOT quiescent between sessions (~15 daemon commits from parallel sessions landed on top of `151912dc`), which changed two close-out decisions:

- **§f.1 `nix flake check --no-build`: GREEN** ("all checks passed!", expected aarch64-darwin omission).
- **§f.2 daemon-race close-out: analyzed, amend-forward CORRECTLY DECLINED** — `c0770141` (flake.nix +10 imports + apps.nix + pkgs.nix) and `edab9394` (fixtures-storage, lint-static, paperless-gpt restore) contain exclusively this refactor's files, BUT parallel sessions' commits now sit on top of them; amending would rewrite others' unpushed history (forbidden). `151912dc` carries the proper title but swept in flake.lock + SECURITY.md (a foreign file) — already buried, documented here instead of rewritten.
- **§f.3 stale-pointer sweep → found ONE REAL BUG (fixed):** the pre-commit formatter memo's content key (`scripts/lib/precommit-eval-cache.sh`) hashed flake.nix/lock/overlays/lib but NOT `flake/parts/` — after the split, a parts-only edit produced a STALE cache HIT, falsifying the memo's "never an entry computed from other bytes" guarantee. Fixed: pathspec += `'flake/parts/*.nix'` (git pathspec globs cross directories, so the nested checks/ files are covered), header/comment updates in the lib + `.githooks/pre-commit` + `scripts/fmt-cached.sh`, and a new selftest sensitivity case — 13/13 green. All other "flake.nix" mentions in parts files are correct provenance notes or `flake.nixosModules` namespace refs. Also fixed: `docs/CONTRIBUTING.md` formatter-override pointer.
- **§f.4/§f.5/§f.6 docs: LANDED** — AGENTS.md architecture sketch (flake/parts tree + imports-not-auto-discovery note), nix-flakes.md "flake/parts structure" section (head-closure, `root`, perSystem merging, checks grouping doctrine, inputs-must-be-syntactic + the /tmp repro, drvPath-parity verification doctrine), CHANGELOG Unreleased→Changed entry. Line-count reconciliation: flake.nix is **1156** now, not 1147 (+10 imports completed in `c0770141`, −1 `go-structure-linter.inputs.treefmt-nix.follows` removed by a parallel session in `705c4e97`).
- **§f.7 harvest: §f.14 → [blocked:push] CI-green row, §f.9 → [watch] warm-build row (deliberately not run — freeze-#15 IO class, parallel sessions active), §f.13/§g.Q1 → [blocked:user] paperless-gpt ownership row; all in `docs/todo/pipeline.md`.** No new [ready] queue rows: every remaining §f item was executed this session, is owner-gated, or waits on push/deploy.
- **§f.8 worktree: removed.** **§f.10 stale claims: none** (SVG hits are coordinate noise; CONTRIBUTING template refs were already correct modulo the formatter pointer fixed above). **§f.11 grouping doctrine: encoded** in nix-flakes.md. **§f.12 treefmt-nix warning: RESOLVED EXTERNALLY** (the parallel session removed the dead follows line — verify absent on next eval). **§f.15: parts were already format-verified** in the authoring session; unchanged since. **§f.16 provenance map: no flake.nix refs existed.**
- **§f.9 (evo-x2 toplevel build): deliberately not executed** — freeze-#15 autopsy attributed the death-minute IO container to a session verification battery; with parallel sessions active at close-out, a giant background build is exactly that class. The deploy's IO-pressure gate arbitrates.
- **§g questions: STILL OPEN** (asked of the owner at session end): Q1 paperless-gpt restore vs coordinate, Q2 lock canonicality, Q3 push. **Q3 is the only blocker on §f.14.**
- **Final landing (git forensics, 2026-10-10 01:58):** refactor content rode `151912dc`/`c0770141`/`edab9394`; the close-out session's script+AGENTS edits rode `fe18c0e7` (batched with a foreign session's lib/lars-packages.nix + overlays/linux.nix — amend forbidden by mixed authorship) and the 5 doc files rode `5a960ebc` (exclusively mine, but a foreign `4a163174` landed on top — retitle would rewrite another session's commit; left heuristic per land-on-top policy). Post-sweep verification legs re-run STANDALONE (daemon commits bypass hooks): shellcheck --severity=warning + bash -n on all touched scripts, eval-cache selftest 13/13, `nix flake check --no-build` GREEN on the final tree (twice — re-run after external flake.lock moves in `a417201b`/`bcacc14b`), gitleaks `detect --log-opts="fe18c0e7~1..HEAD"` no leaks.
