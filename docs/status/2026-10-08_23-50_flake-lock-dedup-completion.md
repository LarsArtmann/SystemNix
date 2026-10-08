# Flake.lock dedup completion session (owner rulings + W2/W3/selftest applied)

**Date:** 2026-10-08 23:20–23:50 (resumed session) · **Verdict:** ALL lock-level work COMPLETE AND PROVEN; the single remaining item is the deferred verification battery, handed off as a [ready] queue row (§f.22 sanctioned) because the box sat in a deepening sibling-build IO storm (io some avg10 25–51%, avg60 up to 46% = the Zone-6 band) for the entire session — the freeze doctrine (deploy/battery gate: avg10 ≥20% blocks) forbids running it into that.

Continues `docs/status/2026-10-08_23-19_flake-lock-dedup-collapse-review-session.md` (read its addendum: the owner answered the §g questions at resume).

## a) Owner rulings (§g of the 23-19 report) — all executed

1. **Q1 attribution collapse: DENIED — keep the heuristic commits.** No `git reset --soft`, no pathspec re-commits; attribution rides the 23-19 report. Future sessions must not re-attempt (addendum recorded). The daemon continued sweeping this session's work the same way (3 more heuristic commits, contents verified session-exclusive: 44fc011e flake.nix W2+Q3, 2a62215e flake.lock canonical, 99ff8824 flake.nix W3 migration + fixture).
2. **Q2 bank-sync: option (a) CONFIRMED — follow declared.**
3. **Q3 pin posture: FLOAT — both root pins flipped to `?ref=master`.** Upstream master HEADs verified == the previously locked revs at flip time (`git ls-remote`: git-hooks a0e4241b, flake-compat 5edf11c4), so the flip is a zero-rev-move posture change: a lock wave MAY now move them (5-repo pre-commit blast radius), the weekly bot will do so naturally.

## b) DONE this session (all verified at lock level)

1. **W2 + Q3 applied** — flake.nix: bank-sync follow line + honest comment in the group (lockstep-structural framing: its own node tracked root's rev through 3 waves green, ad423c8f content-identical); stale "deliberately NOT followed" block comment deleted; git-hooks/flake-compat URLs → `?ref=master` + float comment; NEVER-follow-Go-deps group comment amended (helper = the sanctioned LarsArtmann-tools exception, module tarballs stay banned). Lock canonicalized via the worktree pattern: Nix rewrote bank-sync's edge to array form, deleted the duplicate helper node (**444→443**), renumbered — adopted wholesale. Integrity proven by fingerprint diff (exactly ONE node-content copy lost, zero rev movement anywhere) + recursive reachability (no dangling, no orphans). Sync probe exit 0.
2. **W3 applied** — `/tmp/migrate-follows.py` re-run on the post-W2 tree (not the stale output): 125 lines moved, follows-set parity **169==169 EXACT** (168 + the new bank-sync line), zero block-form lines remain, comments migrated, structural scan clean (no empty wrappers/double blanks), `nix fmt` normalized 4 lines, **worktree `nix flake lock` re-derives a byte-identical lock** (the row's no-op proof). `nix fmt -- --ci` clean across all 2923 files. Final sync probe (§f.21): exit 0.
3. **Selftest 6th leg (§f.9)** — new fixture `tests/fixtures/lock-audit/evil-infra-dup.lock` (hook-tool owning a git-hooks dup + compat-tool owning a flake-compat dup) wired as `infraDup`; standalone verdicts verified: both dup edges FAIL with self-describing fix hints, clean fixture stays `[]` (no regression), **real-lock verdict `[]`** — which also closes §f.10 (all 3 `deliberate` entries still match live edges; bank-sync needs none).
4. **Doctrine refresh (§f.8)** — nix-flakes.md "Infra follows": regrowth datapoint (387→454→443), float posture + wave duty, nested-edge rule, worktree-canonicalize pattern, canonical-form notes, bank-sync exception reconciling the NEVER-follow rule with the NAR-hash MUST-rule, 6 legs.
5. **Row close-outs** — upstream.md:121 (bank-sync alias) RESOLVED with option-(a) evidence; TODO_LIST:483/484 (drifted twins of pipeline rows closed 2026-10-08) repaired; TODO_LIST:485 + pipeline 44 (2026-10-02 CHANGELOG entry — exists, verified); TODO_LIST:487 + pipeline 46 (migration — proven, own verification demand met); TODO_LIST:488 + pipeline 47 (selftest legs — standalone-proven); TODO_LIST:740 + upstream.md:13 (stale premises: todo-list-ai systems line long gone, zero dead-override warnings in a fresh metadata stderr sweep; regrowth priority evidence ADDED to the fleet-follows row — the 23-19 report's "noted on them" claim had NOT actually landed).
6. **23-19 report addendum** — owner rulings recorded, collapse cancelled.

## c) Battery (the ONE open item) — deferred per §f.22, queued as [ready]

Not run: `nix flake check --no-build --all-systems` + evo-x2 toplevel drvPath eval. The IO storm ran 25–51% avg10 all session (drivers attributed via cgroup io.pressure + ps: another session's nix builds (`nixbld1 cp` 106% CPU), go test suites (applyflow/integration, 117–135% CPU), discordsync-worker) and DEEPENED into the Zone-6 band (avg60≈46) at close. Holding ticks that claim it: **TODO_LIST:486 + pipeline.md:45 stay [ ]** and the [Unreleased] CHANGELOG entry for the collapse is NOT yet written (its Verified line would claim the battery). Handoff row queued on both surfaces: at the next calm window (avg10 <20 sustained), run the battery, tick 486/45, land the CHANGELOG entry. Risk assessment for the deferral: LOW — the lock is Nix-re-derived (twice, zero-diff), the flake parses (three lock runs + two metadata probes + the formatter eval all green), the audit verdict is `[]`, and neither promoted input is consumed by any output directly; the battery is confirmation, not exploration.

## d) Mistakes this session (owned)

1. The first `question` call was malformed (missing `type` field) — wasted a round trip.
2. Two multiedit calls shipped a second edit without `old_string` (tool rejected both; no partial writes, but sloppy).
3. First lock-integrity checker had two bugs (missing `.get('inputs')` on leaves; non-recursive path resolution producing 29 false "unresolvable" artifacts) — fixed before trusting the verdict; the recursion fix matters because follows arrays nest through other follows arrays.
4. Initially conflated nix-flakes.md's line numbering with lib/lock-audit.nix's (edit targeted the wrong file's text) — caught by the not-found error, re-located via grep.

## e) Self-harvest note

The battery handoff row (TODO_LIST + pipeline.md) is this report's §c made queue-actionable. Items 9/19 of the 23-19 §f remain queued unchanged (489 + its pipeline twin). No other new actionable items surfaced.
