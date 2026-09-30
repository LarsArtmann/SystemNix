# Pipeline Hardening Batch — Status Report

**Session:** 2026-09-30, ~05:50 → 06:25 (single agent session, evo-x2, IO-storm conditions: PSI some avg10 58.99% at start, peaked 82.14% mid-session)
**Scope:** worked `docs/todo/pipeline.md` — hooks/pre-commit/CI hardening + docs/convention codification batch. 21 library rows closed. **Question asked of this report: what did I forget, what could be better, what is still open.**
**Surfaces touched (for the surface-rule):** `.githooks/pre-commit`, `flake.nix` (3 new checks), `scripts/` (5 new/1 edited), `AGENTS.md`, `docs/CONTRIBUTING.md`, `docs/services/jan.md`, `docs/troubleshooting/STORAGE-OPTIMIZATION-PLAN.md`, `docs/todo/pipeline.md` (21 pruned, 3 added), `CHANGELOG.md`, `platforms/nixos/rpi3/default.nix`, `~/projects/crush-config/references/lessons.md` (foreign repo). Every closure is recorded in ONE CHANGELOG entry (`[Unreleased]/Added`, "Pipeline hardening batch") + the pipeline.md prune — both surfaces landed together.

---

## a) FULLY DONE (verified)

| # | Item | Verification (what was actually run) |
|---|------|--------------------------------------|
| 1 | `scripts/shellcheck.sh` — shellcheck availability wrapper (locked-nixpkgs via `--inputs-from`, default `--severity=warning`, explicit `--severity=` disables the default) | `bash -n`; shellcheck-clean (via itself); dogfooded on all 3 hooks + 5 scripts, rc=0 |
| 2 | Pre-commit **nix-parse leg** (`nix-instantiate --parse` per staged `.nix`, NUL-delimited, deletions excluded, fail-closed exit 1) | Hook `bash -n` + shellcheck-clean; selftest P1-P3 + D1-D3 green locally; **`checks.x86_64-linux.precommit-nix-parse-selftest` BUILT GREEN in the flake sandbox** (`7w94cjv8…`) — proves `nix-instantiate --parse` works inside a build sandbox; parse dogfood on flake.nix |
| 3 | Shellcheck leg now covers **`.githooks/*`** (extensionless hook scripts were permanently unlinted on the staged-path surface; CI's shellcheck job already had them — verified, no CI change needed) | `test-precommit-shellcheck.sh` updated (S1/S2 asserts re-synced, new D4 extensionless-violation case) — green with pinned shellcheck-0.11.0-bin; all three hooks shellcheck-clean at warning level |
| 4 | `scripts/test-commit-msg-hook.sh` + `checks.commit-msg-hook-selftest` — standing fixture for the 72-char subject hook: 72/73 boundary via `head -c`, comment scaffold, MERGE_HEAD + `Merge`-prefix exemptions, multibyte `${#}` byte-counting pinned under LC_ALL=C (both directions), all-comment pass-through; mutation negative (limit → 999) must trip C2 | 12/12 green locally; flake check **BUILT GREEN** (`3pcvsdfz…`) |
| 5 | `scripts/test-precommit-docs-skip.sh` + `checks.precommit-docs-skip-selftest` — persists the 2026-09-28 docs-only skip guard's throwaway verification: classification (all-docs skips; .nix-mixed / deleted-.nix / extension-less force the leg) + mutation negative | 7/7 green locally; flake check **BUILT GREEN** (`kqdmsrpb…`) — after the §d.1 sed fix |
| 6 | `scripts/flake-lock-node.sh` — lock node printer honoring the string-root quirk (`nodes[<root-key>.inputs.X]`, never bare `nodes[X]`) | Prints nixpkgs node (locked rev `7a0f122f…`); missing input exits 1 with a message; shellcheck-clean |
| 7 | rpi3: value-identical `nix.gc.options` mkForce DROPPED (import of `platforms/common/nix-settings.nix` confirmed at rpi3/default.nix:25; common file already carries `7d`) | `nix eval .#nixosConfigurations.rpi3-dns.config.nix.gc.options` → `"--delete-older-than 7d"`, no conflict |
| 8 | CONTRIBUTING hooks table RECONCILED against the actual hook source (old table claimed python-predecessor framing + `alejandra` + `flake-lock-validate` + `check-merge-conflicts` + `protect-home-audit` — none exist; replaced with the 21 real legs + commit-msg, both selftest lists) | Table content derived line-by-line from `.githooks/pre-commit` + `.githooks/commit-msg` read this session |
| 9 | CONTRIBUTING convention blocks: **Daemon-race commit policy** (land-on-top preferred; `git show --stat` exclusivity after every multi-file landing; mid-hook sweep variant; jan.md carries the carve-out), **Agent-safe verification verbs** (4 probes), **DONE-note era-annotation**, **Producer inventory before enforcement** | Landed (daemon `7267df22`); jan.md recipe step reworded + carve-out added (daemon `01fcfd1d`) |
| 10 | AGENTS.md: surface-rule Critical Rule (a correction claim names the corrected surfaces); spot-verify-at-queueing + dispatch-protocol-pointer sentences (TODO System rules); daemon-amend-bypass bullet (Multi-agent write discipline) | Landed (daemon `01fcfd1d`) |
| 11 | pipeline.md: **21 rows pruned to CHANGELOG** (one consolidated entry under `[Unreleased]/Added`); `check-todo-system.sh` green after both edits | Python prune with prefix-uniqueness assertion (21/21 matched exactly once); todo-system gate OK |
| 12 | Sweep closures (verification-only): `stdenv.isDarwin/isLinux` — **zero hits** in repo `*.nix` (warning spam originates in input flakes, out of repo scope); legacy `nix --json` flag — **zero hits** in scripts/docs/hooks (all `--json` uses are modern per-command forms or non-nix tools) | `rg` sweeps, output inspected line-by-line |
| 13 | §11 input-hygiene ghost probe: closed verification-only — **no `monitor365` reference exists anywhere in `.github/workflows/`**; the goModules probe list the row feared no longer exists, nothing to clean | `rg monitor365 .github/workflows/` → no matches |
| 14 | STORAGE-OPTIMIZATION-PLAN.md: the four `--delete-older-than 3d` commands annotated as EMERGENCY-ONLY (standing schedule 7d since `de0feb7e`) | 1 block + 3 inline annotations landed (daemon `6e7650af`) |
| 15 | crush-config `references/lessons.md`: status-report filename-hygiene micro-rule appended (measured-timestamp + collision-check, SOURCE-LEVEL delivery note) | File appended; **NOT yet committed there** — see §b.1 |
| 16 | §d.1 incident FIXED: all four hook selftests **build green, rc=0** (`7w94cjv8…`, `kqdmsrpb…`, `3pcvsdfz…`, `66rmf23f…`) | `nix build` of all four, exit 0, four store paths realized |

## b) PARTIALLY DONE

1. **crush-config lessons.md mirror — source-landed, not delivered.** Foreign-repo delivery = committed THERE (footer-bearing); the edit sits uncommitted in `~/projects/crush-config`. Harvested as a row at authoring time (pipeline.md Backlog, "Commit the crush-config … lessons.md mirror THERE").
2. **Batch commit mapping.** The auto-daemon swept this session's files into ≥5 heuristic commits, two of them MIXED with a parallel session's files (`caddy.nix`, `oauth2-proxy.nix`, `tests/test-caddy-mint.nix` in `01fcfd1d` + `7267df22`). I verified commit→file mapping for the tracked files (table in session log) but did NOT run the per-commit exclusivity/completeness `git show --stat` sweep over all five — harvested as a row (correctly NOT amended: an amend would absorb the foreign files).
3. **Full `nix flake check --no-build` — not run this session.** IO storm (avg10 58→82%) made the full-repo eval a freeze-risk per the pressure-aware policy; verification was done via targeted evals (rpi3 config, per-check builds ×4) + gates (todo-system, shellcheck, bash -n). The full check is owed in a quiet window — NOTE the pre-commit hook runs exactly this leg on every non-docs commit, so the next daemon sweep of a `.nix` file effectively runs it for me.

## c) NOT STARTED (planned this session, dropped — with reasons)

- **E2E-fire the docs-only skip through a real git commit** (pipeline row 171) and the equivalent for the new nix-parse leg (needs a real commit — see §g.3).
- **Extract the pre-mount-unit test scaffolding pattern** (row 197) — doc work; dropped for scope.
- **Eval coalescing convention** (row 198) — dropped for scope.
- **Duplicate-row lint in check-todo-system.sh** (row 182) — needs checker + selftest extension; dropped for scope.
- **TODO-citation rot detection** (row 175) — bigger checker; dropped for scope.
- **Gate-leg fixture/shellcheck coverage survey** (row 181) — partially advanced by the hooks-table reconcile (inventory done), fixture-plan part untouched.
- **Daemon-vs-precommit incident filing** (row 139), **parallel-session unformatted-files investigation** (row 138) — untouched.
- All large prioritized rows (batch-build output, known-outage classification, URL-aware §10, service-completeness manifest, vendorHash dry-runs, …) — untouched, still open in the library.

## d) TOTALLY FUCKED UP

1. **I shipped the docs-skip selftest's mutation negative as a NO-OP — the check was RED in the tree for ~15 minutes.** What happened: I wired the flake-check mutation as `sed "s/'\\.(md|html|txt)\\$'/'\\.(md)\\$'/"` and NEVER ran that sed against the real hook before wiring it — the mutation leg only ever executed inside the first sandbox build, which FAILED (`FAIL: mutated hook … passed the fixture` — the harness's negative-test did exactly its job and caught my broken negative-test). Local repro after the failure: the sed output still contained `'\.(md|html|txt)$'`, 0 substitutions — the `$`-laden escaped pattern never matched. **Root cause: I verified the positive fixture locally but not the mutation leg; and I chose a mutation needle with regex metachars + shell/nix double-escaping instead of a minimal unique substring.** Fix: `sed "s/(md|html|txt)/(md)/"` (metachar-free, verified to bite locally: 0 occurrences of the old pattern in the mutated output), then all four selftests rebuilt rc=0. **Lesson (now §e.1): mutation legs get local-first verification against the REAL target file, same as positive legs.**
2. **My batch interleaved with a parallel session in shared heuristic commits** (`01fcfd1d`, `7267df22` carry my AGENTS.md/jan.md/CONTRIBUTING/rpi3/flake-lock-node edits NEXT TO the other session's caddy/oauth2/test-caddy-mint work). Correct call was made (no amend — absorbing foreign files is the documented anti-pattern), but the practical effect is my "commits" are unattributable batch blobs and the CHANGELOG's tidy one-entry story is spread across 5+ heuristic commits with no footers. This is the daemon-race class I codified in CONTRIBUTING **this very session** — my own session became its freshest evidence (12→14+ live races).
3. Small self-inflicted wounds (all caught ≤1 step later): first multiedit on `test-precommit-nix-parse.sh` dropped a closing quote (bash -n caught it); first `nix build nixpkgs#shellcheck` + `tail -1` resolved the MAN output instead of `.bin`; two edit-tool must-read-before-edit refusals (I edited AGENTS.md/CONTRIBUTING/jan.md from context-memory before viewing current state — the guard worked, no damage).
4. **What I FORGOT until reminded by my own checks:** the tracked-files trap ordering (git add new scripts BEFORE any flake eval — done, but only because planned); running `check-todo-system.sh` after the pipeline prune (done); the §f self-harvest convention for THIS report (3 new rows added at authoring time below).

## e) WHAT WE SHOULD IMPROVE

1. **Negative legs get local-first verification** — every mutation/neuter fixture runs against the real target file BEFORE wiring into flake.nix. (This session's only RED was exactly this gap.)
2. **Mutation needles: metachar-free unique substrings only** — `s/(md|html|txt)/(md)/` beats `s/'\\.(md|html|txt)\\$'/…` on every axis (matching, escaping through nix→bash→sed, reviewability).
3. **Multi-derivation builds: assert rc + per-check store paths, never `tail -N`** — the combined 4-check build masked which check failed until the log was grepped.
4. **Land bookkeeping with a PATHSPEC commit immediately after the gate passes** (my own new CONTRIBUTING policy) — pipeline.md/CHANGELOG.md sat unstaged through two daemon sweeps; they landed, but as footer-less heuristic blobs I then had to map.
5. **Storm discipline worked but cost completeness** — targeted eval/build verification under PSI 60-80% was the right call; the owed full `nix flake check` should be queued, not skipped silently (it is, in §b.3).

## f) NEXT — up to 50, ranked (✱ = NEW this session, harvested into pipeline.md; everything else cites its existing row)

**Immediate (this session's loose ends):**
1. ✱ Run the exclusivity/completeness `git show --stat` sweep over the batch's five daemon commits (`68b3bdb9`, `fba6d2bd`, `d80b2a2a`, `01fcfd1d`, `7267df22`) — new row, HARVESTED.
2. ✱ Commit the crush-config `references/lessons.md` mirror THERE (footer-bearing) — new row, HARVESTED.
3. ✱ E2E-fire the nix-parse leg through a real git commit — new row, HARVESTED.
4. E2E-fire the docs-only skip through a real git commit (row 171).
5. Full `nix flake check --no-build` in a quiet window (see §b.3; next non-docs daemon commit runs it implicitly).

**Guard/test hardening (the library's own prioritized+backlog, closest first):**
6. Standing fixture coverage survey for `.githooks/pre-commit` legs → leg→tested-by matrix + minimal fixture plan (row 181; the inventory half is DONE via the hooks-table reconcile).
7. Duplicate-row lint in `check-todo-system.sh` + selftest (row 182).
8. TODO-citation rot detection (`<file>:<N>` refs vs anchor text; WARN on shift, FAIL on gone) (row 175).
9. E2E-fire + persist regression for the nix-parse and shellcheck legs' CI counterparts — CI shellcheck job is hand-run only; verify it on the next push (new observation, no row — fold into 6).
10. `Formatter-exclusion regression guard` (row 145).
11. `Exposition-syntax validator` flake check (row 143).
12. `FOWNER-chmod eval lint` (row 142).
13. `Smoke-baseline staleness stamps` (row 141).
14. Eval-time assertion: smoke-grep target paths exist in the deployed closure (row 71).
15. Extend `audit-textfile-tmp.sh` class B to `scripts/*.sh` + `docs/**/*.md` (row 153).
16. deploy.sh wrapper: refuse early in agent sandboxes (row 140).
17. deploy.sh pressure-gate rebound race — move final PSI read next to `nh os switch` (row 150).
18. Eval-time assertion: `btrfs send` units declare MemoryHigh (row 124).
19. Pre-deploy §10 WARN on active `churn_units_stopped` (row 125).
20. Buildcache reap-list pinning assertion + single-source the two reap loops (rows 126/127).
21. Extend `deploy-restart-audit.nix`: provisioner-loop members need non-empty wantedBy or exemption (row 117).
22. Extend `mount-gating-audit.nix`: reject ReadWritePaths whose own script mkdirs a descendant (row 118).
23. Wire find-based symlink sweep into post-deploy-check (row 119).
24. `Pre-deploy batch build` fast output (`.#quick-go`) (row 13).
25. Known-outage classification in post-deploy-check (row 14).
26. Structural §10 fix: URL-aware phantom-metric extraction (row 17).
27. §11 vendorHash freshness: real FOD dry-run checks (row 18).
28. Service-completeness manifest audit (row 19).
29. Surprise bulk `nix flake update` validation gate (row 16).
30. `systemd-analyze verify` sweep over ALL unit files (row 102).
31. User-env single-source enforcement checks (row 148) + `golines → base.nix` (row 151).
32. PMA upstream: cap heuristic commit subject at 72 chars (row 178).
33. Surface re-fire counts in tq verify output (row 174, upstream go-taskqueue).
34. Daemon-vs-precommit incident filing + pre-commit re-checks `git status` after its steps (row 139).
35. Investigate how parallel-session files landed unformatted; gate it (row 138).
36. Prune stale `flake: false` `go-health-dashboard` lock node after the next deliberate update (row 137).
37. Extract the pre-mount-unit test scaffolding pattern; align test-cv/test-hot-db variants (row 197).
38. Eval coalescing convention + `fmt-cached.sh` as documented default (row 198).
39. `Boot-scoped vs window-scoped journal assertions` CONTRIBUTING note (row 136).
40. Input-graph diet audit, 420 lock nodes (row 193).
41. CONTRIBUTING: Eval-Time Guards doctrine note (which negative-probe pattern a guard supports) (row 156).
42. `mkGatusEndpoint` helper + the 2026-05 abstraction survivors (row 146).
43. Codify "verification-only close" evidence-class convention in CONTRIBUTING (row 128).
44. AGENTS prevention-table sweep (every gotcha names its guard or UNGUARDED) (row 105).

**Owner-gated (blocked/decision — listed because they gate items above):**
45. `NIX_GITHUB_RO_TOKEN` PAT + repo secret — un-darks ALL nix CI incl. these new selftests (row 199, `[blocked:user]`).
46. Next deploy: carries rpi3 drop + flake checks (zero-runtime-delta); pressure-gate + IO-storm willing (standing queue rows).
47. Lix migration research (row 194, `[decision]`).
48. Enforcement-vs-norm for the self-harvest grep gate (row 185, `[decision]`).

**§f self-harvest status:** items 1-3 harvested into pipeline.md at authoring time (HARVESTED). Items 4-44 cite existing library rows (NOT HARVESTED-because-already-tracked — no new information beyond the row text). Items 45-48 are pre-existing blocked/decision rows. Item 9 is a new observation folded into item 6's row scope.

## g) Questions I cannot figure out myself (3)

1. **Gate ergonomics for the new nix-parse leg:** it currently FAILS FAST (exit 1 on the first unparsable file). The house linter style (deadnix/statix) collects ALL findings and reports at the end. Keep fail-fast (faster, broken syntax usually means the tree is broken) or collect-all (one pass shows every broken file)? Owner preference; trivial to flip.
2. **crush-config lessons.md:** commit it THERE now as its own footer-bearing commit, or leave it uncommitted for you to bundle with the next cross-project lesson batch? (That repo has no auto-commit daemon — the edit just sits until someone commits it.)
3. **Real-git E2E authorization:** both new hook legs (nix-parse, docs-only skip) are proven via verbatim-leg selftests in scratch repos; the remaining "real repo, real commit" path needs one deliberate commit each — a docs-only commit (exercises the skip log line) and a scratch-worktree broken-.nix commit (exercises the parse rejection). I don't commit without your say-so — authorize these two, or accept the selftest-level evidence?

---

*Report written per the status-report skill with the user-specified `.md` format (skill default is HTML — user instruction wins). No commits made by this session (harness rule); the auto-commit daemon swept the working files into heuristic commits mapped above. Verification convention: every green claim above names the command/store path that proved it (3-step probe: step 2 executed this session; step 3 n/a — nothing here is runtime-config until the next deploy, which carries zero-runtime-delta changes only).*

---

## §h CLOSE-OUT ADDENDUM (2026-09-30, follow-up session — the three §g questions + remaining follow-ups)

**§g.1 Gate ergonomics — DECIDED: fail-fast stays.** Rationale: standard pre-commit semantics; the selftest already pins the broken-parse contract; collect-all would change the leg's exit contract and force re-deriving the selftest's mutation cases for zero recurring benefit (agents iterate per-file anyway). Recorded in the CHANGELOG close-out entry. (Not implemented — no code change.)

**§g.2 crush-config lessons.md — DELIVERED (moot, the daemon resolved it):** crush-config ALSO runs a heuristic daemon — it had already swept the lessons.md write into `aa61439` (06:07). Per the daemon-race doctrine (verify contents → amend unpushed HEAD), amended into `docs(lessons): status-report filenames are measured, never guessed` (`163b76e`, 1 file +15, unpushed). Installation rides crush-config's next SystemNix input bump + home-manager rebuild (SOURCE-LEVEL delivery doctrine).

**§g.3 E2E — DONE without any master commits:** both legs fired through the REAL `.githooks/pre-commit` in a throwaway `git worktree` at `/tmp/sn-hook-e2e` (removed after). Broken `.nix` staged → `Nix parse failed in staged file: broken.nix` + rc=1; docs-only staged → `Docs-only staged diff (.md/.html/.txt) — skipping Nix flake check` + rc=0; `core.hooksPath=.githooks` verified. This satisfies the E2E-harvest row and needs no history writes.

**Follow-up rows executed (all pruned to CHANGELOG):** exclusivity sweep over 13 daemon commits (all session files landed, mixed commits match §d's mapping); TODO footer sweep (2 `[x]` rows verified — InboxClean `/health` fix commits `1540a56`+`d23c48a` live in ~/projects/InboxClean, row annotated); avatar-dms BuildFlow exclusion (NOT needed — BuildFlow source-verified: file-size check scans `**/*.go` only, image-scanning provider unwired; rationale comment at flake.nix `BUILDFLOW_EXCLUDE_PATTERNS`); **oci-containers `config.assertions` abort ROOT-CAUSED** — the incident report's "healed by ~05:00" premise was FALSE: upstream nixpkgs bug (`oci-containers.nix` rootless assertion MESSAGE interpolates `${podman.user}` while `podman` defaults null and docker backend requires null; any deep-force of `config.assertions` dies, toplevel/deploy evals never did — reproduced at `f8d04a8b` AND live at HEAD). Fix filed upstream (docs/todo/upstream.md); VM-checks sweep row stays queued (IO-gated).

**Deferred (IO-gated):** the full `nix flake check --no-build --all-systems` was NOT run this session — PSI io some avg60 climbed 30%→47% during it (parallel session's builds; the freeze-#4/5 parallel-eval class). Session's only eval-surface delta (flake.nix comment) is `nix-instantiate --parse`-verified; all other edits are docs/TODO (eval-inert). Owed by the next quiet-window commit or the pre-deploy gate, not by this session.
