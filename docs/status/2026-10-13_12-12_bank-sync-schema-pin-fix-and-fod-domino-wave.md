# Status: bank-sync schema-pin fix + the FOD domino wave it uncovered

_2026-10-13 12:12 CEST — single-session report. Trigger: the user's `nh os switch`
failed with `internal/cqrs/upcasting.go: undefined: schema.Chain` (pasted build
log, 2026-10-12 20:18). Scope discipline: everything below is this session's run
plus what it directly observed; no unrelated research._

---

## 0. One-paragraph verdict

The pasted bank-sync failure is fixed at its root (bank-sync `eb7818c6`, pushed),
and the SystemNix evo-x2 toplevel now builds green (`rc=0`,
`nix flake check --no-build` `rc=0`). Getting there surfaced and cleared a
**pre-existing FOD domino wave** (6 more broken packages that the user's aborted
run never reached): 3 stale consumer-side shims dropped, 3 upstream vendorHashes
fixed+pushed+re-locked, 1 input re-locked past a real upstream compile break.
Deploy is unblocked; it has NOT been run (owner call).

---

## a) FULLY DONE

1. **Root cause, verified end-to-end before any edit**: bank-sync's flake pinned
   `go-cqrs-lite` at frozen rev `7142e43` (2026-09-30 fork point), whose schema
   module predates the `schema.Chain/Compile/Transform` API (`89454037d`, landed
   later on master). `mkPreparedSource` replaces every go-cqrs-lite sub-module
   with the INPUT tree — so Nix builds compile the old schema while local
   `go test` (proxy tags, schema v4.6.0) stayed green. The exact failed drv was
   dissected from the store (`_local_deps/go-cqrs-lite/schema/` has no
   `chain.go`/`ops.go`).
2. **bank-sync fix, committed `eb7818c6` and PUSHED to origin/master**:
   pin → `d15e0a48` (origin/master HEAD, postdates every required tag's fork
   point; newest fork `dcbbe0e45` 2026-10-10), input comment rewritten with the
   full rationale, go-directive ceiling re-verified (104/104 modules `go 1.27`).
3. **Both FOD vendorHashes re-danced** via the repo's own
   `nix run .#update-vendor-hash` (default `sha256-3/5qqagP…`,
   cqrs-lint `sha256-udnDYkwi…`), each with a real verification build.
4. **Schema-chain vendorWitness added** (`func Compile(ops ...Op) (*Chain,
   error)` under `github.com/larsartmann/go-cqrs-lite`) so a future pin
   regression to the pre-chain schema API fails loudly again.
5. **CI parity moved to the same rev** (`.github/workflows/ci.yml`): install
   `@d15e0a48…` + version assertion `d15e0a48d095`; stale "ruleset sits ABOVE
   tag v4.11.1" claim removed (a v4.15.0 batch-release tag now exists; parity
   is rev-matched, not tag-recency).
6. **bank-sync verification chain green**: `check-dep-alignment.sh` OK,
   `check-cqrs-lite-coherence.sh --strict` OK (single revision class),
   `checks.test` (full go suite against the NEW vendored trees) + `checks.lint`
   + both vendor-witness checks green, dashboard `nix run .#e2e` **PASSED**
   (live SSE event stream, zero console errors / CSP violations).
7. **bank-sync bookkeeping closed**: the blocked TODO_LIST row
   ("Re-pin go-cqrs-lite flake input") removed to CHANGELOG with a full entry;
   the "modernization wave HOLD" row updated (HOLD stands for tag-based
   re-pins; the red-build premise is gone).
8. **SystemNix lock updated**: `bank-sync` → `eb7818c6` and nested
   `bank-sync/go-cqrs-lite` → `d15e0a48`.
9. **The domino wave cleared** (all six were pre-existing — my lock diff touched
   only the bank-sync subtree; the failures were among the ~951 postponed drvs
   the user's aborted run never reached):
   - **cqrs-lint**: the ACTIVE shim (`7wijvzQm…` at `f12a849b`) was itself the
     only breaker — upstream `d15e0a48` bakes a green through-our-lock hash
     (first-hand probe, store `wzc06wa9…`). Shim DROPPED in
     `lib/lars-packages.nix` with a full drop record.
   - **cv + discordsync**: "upstream stale" was a MISDIAGNOSIS class — the
     stale hashes lived in **service-module shims** (`cv.nix`, `discordsync.nix`)
     while the input packages were green through-our-lock (probes
     `3w5hsmnp…`, `c1ffr7g8…`). Both shims DROPPED (their own drop conditions —
     "lock moves past an upstream-fixed rev" — had fired).
   - **projects-management-automation `47b405f7`**, **library-policy
     `9db1d50`**, **go-structure-linter `3f3c5467`**: genuinely stale upstream
     hashes — through-our-lock got-hashes measured, pasted upstream, pushed,
     re-locked, all three packages green from our locks.
   - **discordsync compile break**: locked rev `86defd1` shipped
     `errkit.WithContext` against a go-error-family that lacks it
     (green FOD ≠ compile green). Origin head `10c744ea` builds green →
     re-locked past the break. No upstream edit (repo mid-churn: 4 unpushed
     local commits, origin moved 19:20 same evening).
10. **Final gates**: `nix build
    .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going`
    → zero errors, `rc=0`, outPath `45bhlb968…`;
    `nix flake check --no-build` → `rc=0` (the aarch64-darwin warning is the
    documented-expected one).
11. **Lessons recorded**: `docs/agents/nix-flakes.md` — the two-surfaces shim
    corollary on the treadmill bullet (green probe + red toplevel = diff the
    declared hashes, grep the service module) and a new bullet: green FOD does
    not clear the package (compile layer next; probe origin head before
    declaring upstream forever-broken). `docs/todo/upstream.md` wave9 updates
    on the three affected rows (2026-10-01 wave, a7868a7 sweep, cqrs-lint row
    RESOLVED).

## b) PARTIALLY DONE

1. **SystemNix-side commit hygiene**: all content IS committed, but the
   auto-commit daemon swept it into heuristic commits (`c7aa7dfb`, `3798c940`,
   `ff093aea`, `9e7b43f5`) that now sit mid-stack under OTHER sessions' work
   (a secrets commit `04a71dae`, docs, a 131-line status report) in a **41-commit
   unpushed stack**. Rewriting mid-stack during live concurrency was rejected —
   correct call, but my SystemNix work has poor commit messages as a result.
2. **The cqrs-lint CI version assertion is copied, not proven**: CI is dark
   (billing), so `go install …@d15e0a48…` + `cqrs-lint version | grep
   d15e0a48d095` + the `go-finding: 1.13.0` assertion are unverified end-to-end.
   What IS verified: the rev is on origin and cmd/cqrs-lint compiles at it
   (SystemNix's own cqrs-lint package builds green at `d15e0a48`).
3. **Clean-HEAD equivalence for the bank-sync FOD measurements**: the hash
   dance, checks.test, and e2e all ran against a DIRTY tree. Sound because my
   diff never touched the FOD source fileset (go.mod/cmd/internal/pkg/sql) —
   and the post-push SystemNix toplevel built the committed rev green, which
   closes the loop — but the ordering (dirty first, clean proof last) is
   backwards vs the doctrine ("measure against CLEAN HEAD").
4. **Upstream todo library sweep rows**: updated with wave9 resolutions for the
   repos THIS session fixed; the remaining rows (row 97's still-failing list,
   row 115's ~14 remaining tools) were NOT re-probed this session — their
   current status is unknown, only that the toplevel is green (they may be
   fixed, unconsumed, or still latent).
5. **DiscordSync premises**: re-locked to `10c744ea` and the shim dropped, but
   the GCS signed-URL hot-loop row (`a0db1e1`, 640 lines/min journal spam) is
   untouched — whether `10c744ea` contains a fix is untested until post-deploy.

## c) NOT STARTED

1. **The deploy itself** (`nix run .#deploy` / the user's `nh os switch`) —
   deliberately not run: deploy activates prod services; owner call.
2. **Post-deploy smoke** (bank-sync daemon + canary + rev-drift service green,
   paperless/canary units, memory-watermark §17 sweep, §19 backup freshness) —
   blocked on the deploy.
3. **bank-sync full `nix flake check`** (VM tests:
   `tests/test-bank-sync-paperless.nix`, `test-integration.nix` etc.) — only
   the targeted checks battery was run.
4. **`nix run .#pre-deploy-check`** (the §11 deploy-FOD vendorHash preview would
   have been the RIGHT iteration tool for the domino wave; I used ad-hoc
   `--impure` probe exprs instead).
5. **A shared SystemNix-side got-hash helper** — the ad-hoc
   `nix build --impure --expr '…inputs.<i>.packages.*.goModules'` probe worked
   well but is tribal knowledge; not scripted anywhere.
6. **An ambient-environment repair for bank-sync's poisoned module cache**
   (`/mnt/buildcache/go-mod` wrong bytes for `modernc.org/sqlite@v1.60.1`,
   plus the corrupted toolchain extraction that made ambient `go build` in
   bank-sync fail on stdlib-internal packages) — still the owner-gated row it
   was before this session; I routed around it entirely via Nix builds.
7. **Pushing SystemNix** — the 41-commit stack contains other sessions' commits
   (incl. a secrets re-paste `04a71dae` and a newer "deployment outcome" doc
   `1375553f` I did NOT investigate per scope discipline). Not mine to push.

## d) TOTALLY FUCKED UP (honest list)

1. **Hand-pasted a truncated base64 hash.** For go-structure-linter I wrote
   `…NXU=` instead of the real got `…NXUg=` — the exact failure class the
   bank-sync tooling exists to prevent ("never paste hashes by hand"). Caught
   by re-reading my own write BEFORE any build consumed it (fixed in-place,
   then committed `3f3c5467`). Zero damage, but the miss-rate on manual hash
   transcription is now personally demonstrated.
2. **Violated the Project Discovery ordering**: I did ~20 tool calls of git
   archaeology (tag ancestry matrices, prepared-source dissection) BEFORE
   grepping bank-sync's `TODO_LIST.md`, which already contained the full
   diagnosis AND the prescribed fix (the 2026-10-11 blocked row). The
   exploration wasn't wasted (it independently confirmed the row's premise),
   but the row should have been the SECOND tool call, not the thirtieth.
3. **First commit attempt fought the machinery**: pre-commit (BuildFlow, 122s,
   exit 1 on a linter timeout + pre-existing debt) aborted my commit; the
   auto-commit daemon then committed my staged files as a heuristic commit
   mid-hook; I soft-reset two daemon commits and re-committed — correct per
   the daemon-race policy, but the sequence produced a detour
   (`e27e7b85`/`9d5440ca`/`33c22555` → amended into `eb7818c6`) that a
   pathspec-commit right after verification would have avoided.
4. **Almost co-published a live session's work**: I nearly chose "fix upstream +
   push" for DiscordSync before checking `git status` there — 4 unpushed
   commits from another active session sat on top. The check happened before
   any damage; it should have been reflexive (it WAS for the cqrs-lint case in
   the existing docs — I repeated the trap the docs warn about).
5. **Misdiagnosed cv + discordsync as "upstream green, mystery mismatch"** for
   one round-trip: my through-our-lock probes were green while the toplevel
   failed, and I briefly faced a contradiction instead of immediately diffing
   the two derivations' declared hashes (the drv paths themselves differed —
   the tell was visible in the first enumeration output). Cost: ~3 extra tool
   calls; the two-surfaces shim pattern is now documented so the next session
   skips this entirely.

Nothing was deployed, reverted, force-pushed, or lost. No secrets were exposed
(all evidence cites store paths and hashes, never values).

## e) WHAT WE SHOULD IMPROVE

1. **TODO_LIST first, always** — the discovery checklist exists because of
   exactly this session shape; make the `rg` of the target repo's TODO_LIST +
   `docs/todo/` the second command after locating the repo.
2. **A lock-free through-our-lock probe app** in SystemNix
   (`nix run .#probe-fod -- <input> [attr]`) wrapping the
   `builtins.getFlake` + `inputs.<i>.packages.<sys>.<attr>.goModules` pattern —
   it did the heavy lifting this session and is currently tribal knowledge.
3. **Two-surfaces shim detection in `pre-deploy-check`**: a WARN-grade sweep
   grepping `overrideAttrs` + `vendorHash` in `modules/nixos/services/*.nix`
   and diffing each against the current lock's upstream-baked hash — the wave
   diagnosis cost came from the shims hiding in the service layer while every
   doc pointed at `lars-packages.nix` (the 2026-10-12 pdd correction hit the
   SAME trap; twice is a pattern).
4. **Never transcribe hashes by hand — on ANY side of the fence.** bank-sync
   has `update-vendor-hash.sh`; SystemNix has nothing equivalent for the
   `flakePkg`/service-module surfaces. Either extend §11's preview to emit
   ready-to-paste `got:` lines or add a tiny script that runs the probe and
   rewrites the target file itself.
5. **Pathspec-commit immediately after each verified unit of work** — on this
   tree the daemon sweeps within minutes; verification → commit → docs, not
   verification → docs → commit.
6. **Concurrency check as a pre-flight, not a mid-flight save**: one
   `git status --short` + unpushed-count across every repo about to be touched
   (the DiscordSync save).
7. **The enumeration-first discipline worked and should stay**: the
   `--keep-going` pass after the first fix caught all five remaining dominoes
   in one shot — this is the AGENTS.md critical rule paying for itself; keep
   running it even when the first error "looks singular".

## f) NEXT THINGS (prioritized, ≤50)

**Deploy chain (blocking value):**
1. Owner: run `nix run .#deploy` (or your own `nh os switch`) — everything is
   verified green up to the toplevel.
2. Post-deploy: bank-sync daemon/canary/paperless units green;
   `check-rev-drift` (bank-sync-rev-drift.service) green.
3. Post-deploy: memory-watermark §17 sweep + §19 storage-history freshness
   (standing post-deploy gates).
4. Post-deploy: discordsync journal rate — is the GCS signed-URL hot loop
   (`a0db1e1` era) still present at `10c744ea`, or fixed upstream?
5. Owner: push the SystemNix stack (41 commits; contains other sessions' work —
   whole-stack push is an owner decision).
6. Owner: push bank-sync `cef4a68e` (BuildFlow's github-actions-pinning
   auto-fix: taiki-e v2.87.27→v2.87.28 + pre-commit-config symlink churn —
   mechanical, landed after my push).
7. Re-run `nix flake check` WITH builds (VM tests incl.
   `test-bank-sync-paperless`) once the deploy window exists.
8. Verify the bank-sync CI cqrs-lint legs when CI returns (pseudo-version
   assertion + go-finding 1.13.0 at `d15a48`).
9. Watch the three pushed hashes for the "own-lock-moved re-stale" class —
   PMA's dep-sweep daemon re-staled pdd the same day in a prior wave; re-probe
   all three at the next SystemNix lock touch.
10. Probe the STILL-listed row-97 repos (golangci-lint-auto-configure,
    health-hub, meta, visionreviewd) — unshimmed status unknown; the green
    toplevel means they're fixable-or-unconsumed, not necessarily fixed.

**Process/tooling (from §e):**
11. Build `nix run .#probe-fod -- <input> [attr]` (the probe script).
12. Extend `pre-deploy-check` §11 with a two-surfaces shim sweep (service
    modules + lars-packages).
13. Add a hash-transcription guard: a script that pastes got-hashes into a
    target file itself (no manual printf).
14. Update `docs/agents/nix-flakes.md` §11 section to name the probe pattern
    (the gotcha bullets exist; the §11 procedure doesn't reference it).
15. Queue the two-surfaces trap as a `[ready]` row in the SystemNix TODO
    dispatch queue if the owner wants it dispatched (it's currently documented,
    not queued).
16. Consider tagging the three upstream fix commits (PMA/library-policy/gsl)
    upstream so their next lock moves are tag-pinned per the pin policy.

**bank-sync follow-through:**
17. Re-run bank-sync `nix flake check` locally post-deploy for the full VM
    battery.
18. Close the e2e escape-hatch knowledge (the 2026-10-11 02-45 report recipe)
    as obsolete now that `nix run .#e2e` works — one line in the next bank-sync
    docs pass.
19. The ambient-poison rows (GOMODCACHE wrong bytes; corrupted toolchain
    extraction) — owner/environment decision unchanged.
20. bank-sync `docs/INTERIM-INPUT-PINS.md`-style note: not needed (no interim
    pins were added this wave) — verify that file's claim list stays true.
21. Watch schema v4.7.0 (65 commits behind master at probe time): when bank-sync
    next bumps schema, the pin + witness move together per the input comment.
22. The cqrs-lint "unstable-d15e0a48d095" version string — add to the
    rot-on-every-bump watchlist next to the templ-components witness note.

**SystemNix bookkeeping:**
23. The 41-commit stack: consider a `git log --stat` review pass before push so
    the push message/PR (if any) summarizes accurately.
24. `gatus-config.nix` formatting churn (my `nix fmt` caught another session's
    unformatted file) — already in-tree via daemon sweep; nothing to do unless
    the owner wants fmt-only commits labeled.
25. My SystemNix heuristic commits (`3798c940`, `ff093aea`, `9e7b43f5`) have
    poor messages — acceptable per repo convention (dozens exist); do NOT
    rewrite the mid-stack.
26. The wave9 updates in `docs/todo/upstream.md` + the nix-flakes bullets ride
    the same unpushed stack — confirm they survive the push review.
27. Next lock wave: run the two-surfaces grep BEFORE the first `nix build`, not
    after the first mismatch (this session's ordering cost ~3 round-trips).
28. When go-cqrs-lite master moves next: SystemNix's `go-cqrs-lite` input
    follows master — expect the cqrs-lint shim question to re-arm; the drop
    record names the re-evaluation protocol.

**Leftover/adjacent (observed, untouched — from the tree, not researched):**
29. DiscordSync: 4 unpushed local commits (another session, active 19:20
    2026-10-12) — coordinate before any DiscordSync work.
30. The "docs: deployment outcome" commit (`1375553f`) in the unpushed stack
    suggests a post-session deploy already happened — verify bank-sync's daemon
    is on `eb7818c6`-class binary at next contact.
31. Row 97/115 remaining repos (health-hub, meta, visionreviewd,
    vision-review-agent, go-health-dashboard, crm, file-and-image-renamer,
    project-dependency-graph, crush-daily doCheck leg) — re-probe at next wave.
32. The `annotate.go cmdCheckRows` defect (crush-config, foreign repo) —
    unchanged, still blocked on owner.
33. CI runs remain disabled (billing) — all CI-parity work stays
    unverifiable until then.

(Stopped at 33: the remaining ideas were variants of the above or outside this
session's observed scope.)

## g) QUESTIONS FOR THE OWNER (unanswerable from here)

1. **Deploy authority + timing**: shall I run `nix run .#deploy` now (it will
   activate bank-sync `eb7818c6` + the discordsync/PMA/library-policy/gsl
   re-locks on evo-x2), or do you want to run your own switch? If a deploy
   already happened (the unpushed `1375553f` "deployment outcome" commit
   suggests so), should I instead run the post-deploy smoke battery?
2. **Push policy for the 41-commit SystemNix stack**: it mixes my FOD/pin fixes
   with other sessions' commits (incl. a secrets re-paste and status reports).
   Push the whole stack as-is, or do you want to review/split first?
3. **DiscordSync concurrency**: is the 4-unpushed-commit local state in
   `~/projects/DiscordSync` (last activity 19:20 on 2026-10-12) a live session
   I should stay clear of, or abandoned work I may re-lock around / clean up?
   (The GCS hot-loop fix, if that's what those commits are, changes whether
   `10c744ea` needs a follow-up deploy.)

---

### Self-harvest record (docs-health rule)

Follow-ups from this report: items 2–5, 9–10, 16–19, 27–33 are either ALREADY
QUEUED in `docs/todo/upstream.md` (wave rows, updated this session) or
bank-sync `TODO_LIST.md` (ambient-poison, CI rows — unchanged), or owner-gated
actions that cannot be agent-queued (deploy, push, DiscordSync coordination) —
explicitly recorded as deliberately not harvested for that reason. Items 11–15
(tooling/process) are new; queued here pending owner interest, not planted in
the dispatch queue without a ratification signal.
