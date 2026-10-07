# Status: Deploy-Lock Holder Diagnostics Session

**Timestamp:** 2026-10-07 04:55 CEST
**Trigger:** User's `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` was refused by the concurrent-deploy lock guard (`holder PID: 397358`), with the ask: "Could this also check if the PID still exists and some more info e.g. name?"
**Scope:** `scripts/deploy.sh` lock-guard abort path + CHANGELOG + verification. No Nix modules touched, nothing to deploy (the script ships from the working tree on the next `nix run .#deploy`; the improved diagnostics take effect immediately).
**Format note:** status-report skill is HTML-canonical; user explicitly demanded `.md` at this path — override honored and flagged here per the skill's own rule.

---

## a) FULLY DONE

| # | Item | Evidence | Scope |
|---|------|----------|-------|
| a1 | **Lock-guard abort diagnostics rewrite** — the exit-13 path now (1) walks `/proc/*/fd` for whoever ACTUALLY holds the lock file open (the flock holder or any child that inherited fd 9, e.g. `nh`/`nix` during a long build) and prints ppid, process name, elapsed time, full command line per holder; (2) reports the recorded holder PID as corroboration: `ALIVE: <same detail>` or `DEAD (its flock was released with it)`; (3) skips non-numeric garbage lines in the append-opened record one-by-one; (4) prints a dedicated line when the record is empty; (5) honestly reports "fd table unreadable (other-user holder?)" instead of guessing. Guard contract unchanged: same `/tmp` path, same append-open (no O_TRUNC wipe), same exit 13, flock still kernel-released on holder death. | commit `ddcce8cd` (exclusively `scripts/deploy.sh`, 51+/3−, verified via `git show --stat` before any amend consideration) | `scripts/deploy.sh` guard block + its comment |
| a2 | **Lint verification at BOTH severities** — `bash -n` clean; `shellcheck --severity=warning` clean (pre-commit parity, run twice on the final state); `scripts/shellcheck.sh scripts/deploy.sh` (builder severity = style, what the writeShellApplication checkPhase actually enforces) exit 0. The style-level run was added after harvesting `docs/todo/pipeline.md:31`'s recorded trap (mkApp scripts lint at style, not the warning bar I initially ran) — closing the "next deploy breaks in the builder" risk. | exit 0 on all three; final run after last edit | `scripts/deploy.sh` |
| a3 | **Behavioral verification: 4-scenario live harness, 11/11** — A: live holder + live recorded PID (fd scan finds the flock→fish→sleep chain with details; recorded ALIVE; exit 13). B: THE key scenario — recorded PID dead, lock held by an orphaned child via inherited fd (scan names the orphan by PID; recorded DEAD). C: multi-line stale record (append-open artifact) → DEAD + ALIVE lines. D: no holder → clean acquire, exit 0, record overwritten by acquirer. | harness asserted output substrings AND exit codes; clean full-batch re-run green; independently corroborated by an instrumented single-scenario run and a flock-behavior probe (util-linux 2.42.3, parent holds the fd for the whole `-c` lifetime) | `/tmp` harness (now cleaned up — see c1 for the landing gap) |
| a4 | **Real-lock diagnosis (read-only)** — at check time the user's lock was FREE: recorded PID `892095` gone, zero fd holders. The original `397358` from the user's transcript had already been replaced by a later deploy attempt's record. | `cat` + per-PID `ps` + fd scan, no mutations | live system state |
| a5 | **Docs-surface drift check** — no script or doc parses or quotes the old `holder PID:` abort message (grep across repo excluding historical status reports); the `flock` mentions in `docs/agents/stability.md`/`systemd.md` are workload-admission and wedged-stc topics, not this guard. Only surfaces updated: the guard's own comment block (extended with the new diagnostics rationale) + CHANGELOG. | grep evidence in session log | repo docs |
| a6 | **CHANGELOG entry** — new `### Changed` section under `[Unreleased]` describing the diagnostics, the fd-inheritance case, and the verification. | landed in daemon sweep `bdfbd06d` (see d4) | `CHANGELOG.md` |
| a7 | **Daemon-race discipline held** — content-pin before post-edit steps; verified `ddcce8cd` contained exclusively my file before planning the policy-mandated amend; REFUSED the amend once a parallel session moved HEAD (`d78f2e8c`); REFUSED to split the mixed sweep `bdfbd06d` while the foreign session was actively committing; my PATHSPEC commit attempt lost the race to the daemon ("nothing to commit") — verified the content landed intact instead. | git log/show evidence throughout | repo history hygiene |

## b) PARTIALLY DONE

| # | Item | Works now | Open | Blocker | Effort |
|---|------|-----------|------|---------|--------|
| b1 | Verification of the final PACKAGED artifact | Standalone shellcheck at warning AND style severity on the source | The real `writeShellApplication` checkPhase (sandbox `nix build` of `apps...deploy`) never ran | Shared-tree discipline: a foreign session's in-flight `tests/test-root-prune-guard.nix` makes flake-surface evals unreliable mid-flight; standing quiescent-moment rule | S |
| b2 | Docs annotation | Script comment + CHANGELOG updated | `docs/agents/systemd.md` (T13 concurrent-deploy guard text) and the FEATURES.md deploy row not yet annotated with the new abort shape | None — queued (f5) | S |
| b3 | The user's actual deploy | Lock gate verified free | PSI memory gate, IO-PSI gate, guard-trip-recency gate, concurrent-stc gate all UNCHECKED — so "you can just re-run" is proven for the lock ONLY. The original attempt carried `DEPLOY_FORCE_PRESSURE=1`, which strongly suggests other gates were red. | Owner decides retry vs wait once gate state is known (see g1) | S |
| b4 | The behavioral harness | Proven 11/11 manually, twice (plus instrumented isolation runs) | NOT landed in-repo — dies with `/tmp` cleanup; the guard has zero standing regression protection (see c1) | None — pure authoring work | S |

## c) NOT STARTED

| # | Item | Why not started | Priority |
|---|------|-----------------|----------|
| c1 | **Permanent in-repo selftest for the guard block** (pattern-anchored extraction of the LIVE `deploy.sh` code — like `check-cv-oidc-gate.sh` / `test-gotoolchain-guard.sh`, never a copied snapshot that rots — driving the four scenarios with a substituted lock path + pre-commit leg on staged `deploy.sh` edits) | Session scope was the fix + verification; the harness existed only as a session-local tool. This is the single biggest follow-up. | High |
| c2 | Lock-record enrichment: write epoch timestamp + owning session scope (from `/proc/self/cgroup`) alongside `$$`; abort prints "recorded N min ago, held by session-N" — turns future aborts self-describing in this multi-agent house | Design not drafted | Medium |
| c3 | `nix run .#deploy-status` read-only app: lock state + all gate states in one command (would have made b3 a 5-second check instead of a judgment call) | Not designed | Medium |
| c4 | Opt-in `DEPLOY_KILL_STALE_LOCK=1` cleanup for the dead-record + orphan-child case (human-gated, `DEPLOY_KILL_WEDGED_STC` analog) | Deliberately deferred — killing live-looking processes stays a human decision per house doctrine | Low |
| c5 | `/mnt/rust-cache` recovery (SanDisk SSD reports dead on every shell; cargo/sccache redirect to `/tmp/bc-fallback` on tmpfs) | Owner operation (physical/media); I only observed the warnings repeatedly this session | High (operation) |
| c6 | Push of the 15+ unpushed commits (includes `ddcce8cd` + the CHANGELOG) | Harness rule: never push unless explicitly asked → `[blocked:push]` | Medium |

## d) TOTALLY FUCKED UP

1. **My close-out over-claimed deploy-readiness.** "Re-running `nix run .#deploy` will proceed" was true for the LOCK gate and unproven for every other gate (PSI mem/IO, guard-trip recency, concurrent-stc) — and the `DEPLOY_FORCE_PRESSURE=1` in your original command is standing evidence those gates were red. This is the "a verification close-out must answer the question the item ASKED, not a sub-proof" rule, violated one level up: I answered the asked question (lock) but let the phrasing leak into an all-clear. **Mitigation:** b3/f2 — gate-state summary in abort output, and gate check before any retry.
2. **~3 debug rounds burned on a self-inflicted harness bug, then an unexplained transient.** Round 1: the scenario ran through the tool shell — fish semantics turned `$!` into a job spec (`g1`) written as a "PID", and `&` bound to the whole `&&` chain, racing `rm` mid-flight (inode swap). The code LOOKED broken; the harness was. Round 2: a full batch run where EVERY holder reported DEAD and every scan came back empty — never fully root-caused (transient; coincided with heavy mount churn from the dead rust-cache), resolved by instrumented re-runs proving all paths green. Honest status: the FAILING run's mechanism is a documented unknown; the PASSING state is reproduced 2×.
3. **`/mnt/rust-cache` is DEAD (repo-side, noticed not caused).** Every tool shell prints `CARGO_HOME=/mnt/rust-cache/cargo is unwritable or unreachable (dead mount?)` and silently redirects cargo+sccache to `/tmp/bc-fallback` — RAM-backed tmpfs accumulating build caches during a session-heavy day. Combines a real degradation with an environment-flakiness source (suspect #1 for the d2 transient). Needs owner recovery (c5).
4. **Mixed daemon commit `bdfbd06d`** — my CHANGELOG entry swept together with the parallel session's `tests/test-root-prune-guard.nix` in one heuristic-message commit, left unsplit (splitting while that session was mid-flight risked swallowing its in-flight work — the lesser evil per the daemon-race policy). History hygiene only; content intact.

## e) WHAT WE SHOULD IMPROVE

1. **Write scenario tests as bash FILES from attempt #1.** Trusting the tool shell for `$!`/backgrounding/grouping cost ~15 min of false alarms. Rule: anything with background processes + PIDs goes into a `#!/usr/bin/env bash` file immediately.
2. **Close-outs must scope their claim to the verified surface.** "Lock free" ≠ "deploy will pass" — enumerate gates or name the single surface proven. (Same family as the 2026-09-18 count-claim rule.)
3. **Content-pin BEFORE the first edit**, not only before later ones — I edited `deploy.sh` after grep+view but without `git rev-parse` + `status --short`; got lucky that the daemon wasn't mid-sweep.
4. **Check the repo's own tooling docs BEFORE verifying:** `pipeline.md:31` already recorded the `scripts/shellcheck.sh` wrapper, the PATH-availability trap, and the style-vs-warning builder severity. I re-derived it from the queue AFTER the fact — the row exists so the lookup happens first.
5. **Standing selftests for guard blocks with abort-path behavior** — throwaway `/tmp` harnesses prove a moment, not the future; the extraction-fixture + pre-commit-leg pattern (cv-oidc gate) is the house answer (→ c1).
6. **Environment noise carries signal:** the CARGO/SCCACHE "dead mount" warnings looked like boilerplate until they became the prime suspect for test flakiness. Treat repeated warnings from the environment as findings, not furniture.

## f) NEXT TASKS (ranked; harvest accounting inline per the TODO-system rule)

**HARVESTED at authoring time** (landed in `TODO_LIST.md` + `docs/todo/pipeline.md` — both surfaces, no drift):

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| f1 | Land the four-scenario lock-guard selftest: pattern-anchored extraction of the LIVE `deploy.sh` guard block (sed by markers, not line numbers), substituted lock path, assert output substrings + exit codes per scenario (incl. the orphan-inherited-fd and multi-line-record cases and a `(deleted)`-inode negative), plus a pre-commit leg on staged `deploy.sh` edits. Modeled on `scripts/check-cv-oidc-gate.sh` + its selftest. | Critical | S | Quality |
| f2 | Add a gate-state summary line to the lock-guard abort output (PSI mem/io avg10, guard-trip recency, stc lock presence) so "blocked by lock" is never readable as "deploy otherwise ready"; share the gate-reading code with the queued `--when-calm` row to avoid a third copy of gate logic. | High | S | Feature |
| f3 | Annotate `docs/agents/systemd.md` (T13 guard section) + the FEATURES.md deploy row with the new abort-output shape and its fd-inheritance rationale. | Medium | S | Documentation |

**Deliberately NOT harvested, with reasons:**

- f4 Retry the deploy once gate state is checked — owner operation + g1 decision; nothing to queue until then.
- f5 `/mnt/rust-cache` recovery + `/tmp/bc-fallback` purge — owner physical operation; `docs/todo/storage.md` already owns the rust-cache surface (parity-guard, first-scrape-race rows); a dead-mount triage row would fragment that ownership.
- f6 Build-verify the deploy app's sandbox checkPhase — folded into the standing quiet-window batch (same deferral as the `cv-oidc-gate` flake-check wiring); a separate row would duplicate that mechanism.
- f7 Lock-record enrichment (timestamp + session scope) — needs a small design pass first; ROADMAP fuel, not a bounded task yet.
- f8 `deploy-status` read-only app — ROADMAP fuel (depends on f2's gate-reading helper landing first).
- f9 `DEPLOY_KILL_STALE_LOCK=1` opt-in kill — doctrine-sensitive (human decision on live-looking processes); parked until a real incident demands it.
- f10 PID-reuse guard on the recorded-ALIVE branch (verify `/proc/<pid>/cmdline` mentions deploy/nh before claiming ALIVE) — brainstorm; low frequency.
- f11 Push the 15+ unpushed commits — `[blocked:push]` harness rule; owner says when.
- f12 Re-run the scenario harness against a REAL production abort (actual `nh` child holding the lock) after the next occurrence — observation task, not queueable.
- f13 Generalize the holder-diagnostics pattern to other scripts with recorded-PID aborts (grep-driven sweep) — brainstorm; no known second site yet.
- f14 The foreign session's `tests/test-root-prune-guard.nix` — not this session's work; its owning session lands it. Watched, not touched.
- f15 `fuser`/psmisc alternative for holder lookup — considered and REJECTED: extra runtime dependency vs. a dependency-free `/proc` scan that is proven; recorded so it isn't re-proposed.
- f16 `--when-calm` deploy mode + activation lock-wait — ALREADY QUEUED (`pipeline.md` rows); f2's shared gate-reader is the only new synergy, captured in f2 itself.

(Headroom to 50 deliberately unused: the remaining ideas — cron-ish re-checks, message-format versioning, per-holder fd counts — failed the "specific and actionable" bar of the section-quality guide and would be HARVEST-rejected; padding the list would bury the real items.)

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Deploy intent + authorization:** your failed run carried `DEPLOY_FORCE_PRESSURE=1` — what was it meant to ship, and if the PSI/trip-recency gates are still red now that the lock is free: do you want me to check the gates and report (wait-default), or is a forced retry authorized? I cannot know your intent and will not self-authorize pressure overrides.
2. **`/mnt/rust-cache` (SanDisk SSD):** every shell reports it dead and cargo/sccache are silently falling back to tmpfs. Do you know its physical state (unplugged/failed?), and do you want recovery (replug/rescan/re-mount) or a permanent relocation of those caches? Journals can show WHEN it died, not whether you did it on purpose.
3. **Mixed daemon-commit policy:** my CHANGELOG entry landed swept together with the parallel session's test file (`bdfbd06d`). For future sweeps that mix my files with an ACTIVE foreign session's: leave them mixed (current, zero-risk), or soft-reset-split once the tree quiesces (clean history, small race window)? The 2026-09-30 split precedent doesn't cover the active-parallel-session case.

---

*Point-in-time snapshot; §f items f1-f3 are the HARVEST obligation and were landed at authoring time per the TODO-system rule. Everything else is recorded here with its not-harvested reason.*
