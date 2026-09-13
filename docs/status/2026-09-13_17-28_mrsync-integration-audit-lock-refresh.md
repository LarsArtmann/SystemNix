# Status Report: mr-sync Integration Audit + Lock Refresh

**Session:** 2026-09-13, ~17:10–17:30
**Scope:** Single question — "How is our integration with ~/projects/mr-sync?" — executed as a full READ → RESEARCH → VERIFY → FIX loop on the SystemNix↔mr-sync integration surface only. No unrelated research per instruction.

---

## Executive Summary

The mr-sync integration was **functionally intact but rotting quietly**: SystemNix's flake.lock pinned a 102-commits-old rev whose sandbox test suite had already gone RED (2 failing tests). A user running `nix build .#mr-sync` today would have hit a build failure with no local signal anything was wrong — the classic "moving-ref input nobody probes" gap. The lock was refreshed to origin/master (`91bcb4c`, today), the package now builds green **with tests**, and the binary verifies. `flake check` is green.

One honest gap: I verified the old rev was broken and the new rev is green, but I did not bisect WHICH upstream commit fixed the two failing tests (unnecessary for the task — noted for honesty, not as pending work).

---

## a) FULLY DONE

| # | Work | Evidence |
|---|------|----------|
| 1 | **Integration-surface inventory** — mapped how SystemNix consumes mr-sync: flake input `github:LarsArtmann/mr-sync?ref=master` (flake.nix:361-366) → `lib/lars-packages.nix:28-30` (`flakePkg inputs.mr-sync`) → package `.#mr-sync`. No overlay, no service module, no sops, no Gatus — pure CLI tool, source-only flake input (FEATURES.md:437 confirms). | grep sweep, 100+ hits reviewed |
| 2 | **Three-way rev drift analysis** — local checkout `228a6d3` (1 unpushed auto-commit ahead), origin/master `91bcb4c`, SystemNix lock `793b8ad` (102 commits behind origin, ~v0.5.0-72 vs ~v0.5.0-102). | git rev-parse + flake.lock jq |
| 3 | **Proved the stale lock was BROKEN, not just old** — `nix build .#mr-sync` at `793b8ad` FAILED: `TestErrorTemplatesMatchDataContracts` (test reads `../../docs/DATA_CONTRACTS.md` via relative path — absent in the build sandbox) + `TestExecuteMigrationMovesSkipsConflict` (error-message expectation drift: test wanted `resolve it manually`, code emitted `resolve the conflict manually, then re-run migrate-paths`). | nix log of the failed drv |
| 4 | **Confirmed fixes exist upstream** — local `go test ./cmd/mr-sync/` at HEAD passes (5.8s, ok). Both failures were already fixed in the 30 commits between lock and origin (which are otherwise pure auto-commit churn + the v0.5.1 CHANGELOG cut). | go test run |
| 5 | **Lock refresh** — `nix flake lock --update-input mr-sync`: `793b8ad` → `91bcb4c` (narHash `Rr4Nsxq…`). Auto-committed by the daemon (`bd1712ab` batch). | flake.lock diff |
| 6 | **Hermetic build green at new rev** — full build incl. go-modules FOD and sandbox tests: `/nix/store/yy97yvm…-mr-sync-91bcb4c…`. | nix build output |
| 7 | **Binary verification** — `mr-sync version 91bcb4c73cff…, Commit: 91bcb4c, Go: go1.26.7-X:jsonv2` — runs and self-reports the correct rev (the version-embed ldflags path works). | binary --version |
| 8 | **Repo health gate** — `nix flake check --no-build`: all checks passed (aarch64-darwin omission expected per AGENTS.md). | flake check |

## b) PARTIALLY DONE

| # | Work | State |
|---|------|-------|
| 1 | **Lock-update commit attribution** — the daemon committed the lock refresh inside a `chore: auto-commit 3 changed file(s)` batch (`bd1712ab`). The change is IN, but not in a self-describing commit. Per AGENTS.md concurrent-session doctrine I did not pathspec-recommit (daemon owns the cadence); acceptable, but the audit trail for "why did the lock move" lives only in this report. | done, weakly attributed |
| 2 | **Root-cause of the stale drift** — I refreshed the lock but did NOT establish WHY it had drifted 102 commits/1 month (no TODO item, no CI guard, no staleness check exists for this input; earlier sessions' recurring pattern: notice drift → fix → forget). The systemic fix is open. | fixed symptom, cause unaddressed |
| 3 | **Local checkout hygiene** — mr-sync local master sits 1 unpushed auto-commit ahead of origin (`228a6d3`). Left alone (never push without explicit ask). Flagging here so it doesn't silently grow. | observed, not resolved |

## c) NOT STARTED (noticed, deliberately out of scope this session)

- No staleness detection for ANY `?ref=master` moving-ref inputs (mr-sync is one of ~15+; CI has no "lock older than upstream head" check).
- No bisect of which upstream commit fixed the 2 tests (curiosity-level; lock is past them).
- v0.5.1 CHANGELOG was cut upstream but **no `v0.5.1` tag exists** (`git describe` = `v0.5.0-102-g91bcb4c`) — release process incomplete upstream; not my repo state to fix without ask.
- SystemNix CHANGELOG.md:364 still says "mr-sync pinned to `3db4fb2`" — historical changelog line, left as-is (changelogs are append-only history), but a reader could mistake it for current state.

## d) TOTALLY FUCKED UP

Nothing in this session. Closest misses, for honesty:

1. **First grep was too broad** (100-result truncation across archived status docs) — recovered immediately by narrowing to flake.nix/lib/flake.lock.
2. **Brief misread of local-vs-origin state** — first `git log HEAD..origin/master` printed empty and the revs differed, which briefly looked like divergence; resolved in one follow-up call (origin is an ancestor; local is simply 1 ahead). No wrong action taken on the misread.

## e) WHAT WE SHOULD IMPROVE

1. **Lock-staleness guard** — a CI check (or `nix-check.yml` step) that, for each `?ref=master` input, compares the locked rev against the GitHub head and opens an issue/warns when drift exceeds N commits or N days. mr-sync drifted 102 commits for ~a month with the locked tests already red — invisible until someone built the package.
2. **Batch Go-package build probe** — the 2026-08-12 precedent (`nix build .#mr-sync …` in the batch list) exists but nothing runs it routinely. A weekly "build all mkLarsPackages" CI job would have caught this class for ALL 20+ LarsArtmann tools, not just mr-sync.
3. **Upstream test hygiene** — `TestErrorTemplatesMatchDataContracts` reads a repo doc via a relative `../../docs/` path: works locally, breaks in any sandbox/nix build at older revs. Should use `runtime.GOROOT`-independent embedding (`go:embed` or locate via `go.mod`). Fix belongs upstream in mr-sync (it may already be fixed — unverified which commit).
4. **Upstream release discipline** — CHANGELOG cut for v0.5.1 with no tag; consumers on `ref=master` can't pin semver. Cut the tag upstream.
5. **This session's report-before-instructions cadence** — fine; noting the earlier turn ended with "WAIT FOR INSTRUCTIONS" repeated, which cost one redundant user message.

## f) Up to 50 Things To Do Next (prioritized, mr-sync-adjacent first)

**P0 — direct fallout of this session**
1. Cut `v0.5.1` tag in mr-sync upstream (CHANGELOG already cut) so consumers can pin semver.
2. Add the lock-staleness CI check for `?ref=master` inputs (SystemNix `nix-check.yml`).
3. Add a weekly CI job building all `mkLarsPackages` outputs (the 2026-08-12 batch list, automated).
4. Verify which upstream mr-sync commit fixed `TestErrorTemplatesMatchDataContracts`; if the `../../docs/` relative-path pattern still exists anywhere, fix it with `go:embed` upstream.
5. Push or discard the 1 unpushed auto-commit on mr-sync local master (user decision — I cannot push unasked).
6. Deploy or leave the lock bump: decide whether `nix run .#deploy` should ride now or with the next change batch (the package is a PATH tool, not a service — no urgency).
7. Update SystemNix CHANGELOG with an entry documenting the lock refresh + the two now-unblocked upstream test fixes.

**P1 — same class, other inputs**
8. Run the same three-way drift audit (local / origin / lock) for the other `?ref=master` LarsArtmann inputs (crush-daily, md-go-validator, branching-flow, go-structure-linter, todo-list-ai, file-and-image-renamer, …) — expect at least one more stale-broken lock.
9. For each moving-ref input, decide: semver-pin vs keep-master, and record the decision (2026-08-12 self-review item 13 "pin instead of ref=master" was never executed).
10. Consider converting mr-sync input to a tag URL once v0.5.1 exists.
11. Sweep archived docs' superseded "pinned to X" claims into a single current-state table (FEATURES.md already has one — keep it authoritative).

**P2 — upstream mr-sync product work (from its own docs/TODO, not researched this session — verify before executing)**
12. Add the integration test for the FULL sync flow (open item from 2026-07-29 report, item 37 — status unknown, verify).
13. Confirm `proxyVendor = true` in mr-sync package.nix is still needed post-dep-bump (open item 38 from same report).
14. Run `deadnix` on mr-sync flake.nix (open item 19).
15. Add the CI check for mr-sync vendorHash drift (open item 17).
16. Update mr-sync's own AGENTS.md with the go-atomic-write flock-creates-file gotcha (open item 20).
17. Audit mr-sync for "Unknown Author"/`unknown@example` fallbacks (2026-08-06 item: grep across mr-sync was recommended, never confirmed done).
18. Check mr-sync's BuildFlow CI status (2026-08-05: 1 failing step — never confirmed fixed).

**P3 — SystemNix standing items I touched peripherally**
19. The `nixpkgs` tarball-registry / lock-hygiene family: confirm `fix-nixpkgs-lock.sh` still current.
20. `nix flake check` runtime cost: the batch-build CI idea (#3) must ride the `heavy-job` wrapper doctrine (workload-admission) — design before implementing.
21. Vendored `vendor/` dir exists in ~/projects/mr-sync checkout — confirm upstream intends vendor/ committed (AGENTS doctrine says vendor dirs are usually not; if committed, note the go mod vendor regeneration trap from 2026-07-29).
22. Document in SystemNix AGENTS.md (Consuming LarsArtmann Flakes section) that source-only flake inputs get NO CI signal — pointing at the new staleness check once it exists.
23. Post-deploy smoke does not cover `.#mr-sync` (CLI tool, no service) — decide if PATH tools need any deploy verification at all (probably not; document the decision).
24. mr-sync `--version` reports full 40-char rev — fine for a tool (AGENTS rule about short versions applies to store-path names; store name is also full rev here — consider `shortRev` for the derivation name per the versioning doctrine).
25. Ensure the lock-bump rides the next deploy's pre-deploy-check cleanly (§10 metric-presence unaffected — no metrics for this package; nothing to do, just noted).

*(25 concrete items; the remainder of the 50 would be generic SystemNix TODO_LIST items already tracked there — deliberately not duplicated per the "right file" doctrine.)*

## g) Questions Only You Can Answer

1. **Should `?ref=master` inputs stay moving, or do you want a semver-pin policy now that mr-sync has (almost) tags?** This decides whether the staleness CI check alerts or is unnecessary (tags make locks stable by construction).
2. **Is the mr-sync v0.5.1 release meant to be cut by me (push + tag upstream is a push — I need explicit permission), or will you cut it?**
3. **Do you want CLI tools like mr-sync deployed via the system PATH (they already are via mkLarsPackages → environment.systemPackages?) — i.e., should I run `nix run .#deploy` now to propagate the rebuilt binary to evo-x2, or batch it with the next deploy?** (I did not verify whether `mr-sync` is on the deployed system PATH; the local checkout's `./mr-sync` symlink suggests ad-hoc use.)

---

**Verification state at report time:** lock at `91bcb4c` (committed via daemon batch `bd1712ab`), `.#mr-sync` builds green with tests, binary self-verifies, `nix flake check --no-build` all-passed. No deploy performed. No other files touched by this session.
