# Window Closeout — Five-Task Queue Window (2026-09-24 → 2026-09-25)

**Date:** 2026-09-25 11:30 CEST
**Scope:** The five dispatched tasks below, verified against commits/tree — not re-derived. Repo-wide state is owned by the standing harvest chain and domain libraries.
**Window tasks:**

| Task | Item | Verdict |
|---|---|---|
| `000001a0d1898b…` | Document nixpkgs override-shape change (`content` not `value`) + plain-`enable=false` probe-conflict class | DONE (`16719c10`) |
| `000001a0d1a502…` | Prove shellcheck covers `scripts/*.sh` in pre-commit | DONE (`e55c4d7d` work; dispatch raced completion, verify-only run `f4c996ff` report) |
| `000001a0d6d444…` | Fix the pre-existing `checks.disko-layout` eval failure (pre-commit flake-check gate dead for ALL agents) | DONE — environmental, not structural; fix chain `af87ce31`/`d827f478` in-tree; no-op verify run `289e879c` |
| `000001a0d79dae…` | Build the /data damage-set inventory (single source of truth) | DONE (`f6380065`) |
| `000001a0d7affe…` | Cross-link the flm AGENTS bullet to the snapshot-pinning doctrine table | DONE (`87cf9c6d`) |

---

## a) FULLY DONE (verified)

1. **Override-shape gotcha landed in AGENTS.md** (task 1). `16719c10`: AGENTS.md Non-Obvious Gotchas → Nix & Nixpkgs now carries both traps — the module-system override wrapper's inner field is `content` (`{…value = true;}` dies `attribute 'content' missing` at `lib/modules.nix:1458`) and plain values carry priority 100, so a plain `enable = false` in configuration.nix forces probe overrides to ≤50 (`<50` to beat an existing `mkForce`). Both error shapes were reproduced live against the locked nixpkgs **before** writing (throwaway `extendModules` evals, tree untouched). Queue closed on both surfaces (TODO_LIST:38, `docs/todo/pipeline.md:154`).
2. **Pre-commit shellcheck leg proven + real gap closed** (task 2). Work commit `e55c4d7d` (10 files, +206/−6): leg predates the borg drill that raised the question; 18 latent warning-level SC2034 findings in 5 scripts fixed (CI's error-level job could never see them, but each would hard-fail the next commit touching the file); persisted proof `scripts/test-precommit-shellcheck.sh` (S1–S5 static + D1–D3 dynamic) + `checks.x86_64-linux.precommit-shellcheck-leg-selftest` flake check wired into CI's trap-lint job. The duplicate dispatch (same ID re-fired after completion) independently re-verified everything: proof script 8/8 green, hook-exact warning-bar sweep over ALL `scripts/*.sh` incl. `scripts/lib/` rc=0, selftest builds green, CI wiring present.
3. **The "dead pre-commit flake-check gate" was ENVIRONMENTAL, and the durable fix is in-tree** (task 3). Root cause chain (established by the window's earlier sessions, closed by the no-op verify run): the `hot-user-caches-nix-bootstrap` ↔ `systemd-tmpfiles-setup` boot-ordering cycle deleted boot tmpfiles → `/run/binfmt` missing → EVERY sandboxed build died `getting attributes of path "/run/binfmt"` → `checks.disko-layout` / `treefmt.drv is not valid`. Fixes in-tree: `af87ce31` (bootstrap re-anchored to the `.mount`, tmpfiles-applied boot tripwire `tests/test-hot-user-caches.nix`), `d827f478` (`binfmt-sandbox-dir` belt), plus the flake.nix formatter override whose eval no longer coerces the treefmt package output. Gate verified GREEN 6× on 2026-09-25 (05:33, 06:34, ~07:14, ~07:17 pre-commit-verified, 06:55, and the 09:52 report commit's own hook) at rev `4435ddb8+`. TODO_LIST:43 closed `[x]` with the RESIDUAL note.
4. **/data damage-set inventory exists as the single source of truth** (task 4). `f6380065` created `docs/services/data-damage-set.md`: root cause + scrub-evidence table (2026-08-03 signature → 2026-09-11 gate-a PASS, gate-b formally pending), full victim set (1 gone + 10 live, ~49G, all re-downloadable) with root/ino/path/size, the T06→T09 decoupled repair-gate consequence (btrbk resume ~1d vs scrub-clean ~4w), snapshot-pinning timeline that CONSUMES the AGENTS.md doctrine table (cites, never duplicates), and a change protocol registering the inventory in jan.md's atomic doc sweep. jan.md cross-linked in 2 places; both queue surfaces closed.
5. **flm ↔ doctrine-table cross-link landed** (task 5). `87cf9c6d`: the flm Package bullet's re-pull sentence now carries the in-place-overwrite pin caveat and points at the BTRFS "Snapshot-pinning doctrine" table — closing the one-line asymmetry with jan.md (which already pointed at the table twice). Queue closed in TODO_LIST + `docs/todo/storage.md` (strikethrough + DONE note).
6. **In passing, same window:** the doctrine table's `/data/docker` row was refreshed via live `docker system df` (`6f7899a3`, report `050ec1ee`) — 15.5G total, ~9.9G/64% reclaimable, sizing rides the 4-5w /data pin window.

All five queue IDs closed `[x]` in TODO_LIST.md with DONE notes; `scripts/check-todo-system.sh` green at each landing; every work commit passed the full pre-commit suite (gitleaks, fmt, eval-only flake check).

## b) PARTIALLY DONE

1. **The disko-gate RESIDUAL is explicitly open, owner-gated:** the durable fixes (`af87ce31`/`d827f478`) are **UNDEPLOYED** — the host still boots gen 797 with the old automount-anchored wiring, so a reboot BEFORE the owner deploy re-manifests the `/run/binfmt` breakage. Tracked `[blocked:deploy]` (TODO_LIST:112 + the row-43 residual note). Post-reboot proof (`ls /run/binfmt && nix flake check --no-build`) pending.
2. **Damage-set victim rows are doc-derived, not live-re-probed** (inventory report §b1): the 10 live victims are transcribed from the 2026-09-11 T05 round; no fresh `stat -c %i` sweep this window. Gate (b) is still "formally pending" as of 2026-09-11 evidence.
3. **Shellcheck coverage is layered-partial:** `scripts/lib/*.sh` (the deploy-gate lib at the center of the 2026-09-24 §13/§16 incident) is only ever checked when staged, at the warning bar — CI's error-level job uses the top-level `scripts/*.sh` glob. Currently clean, structurally blind (07-31 report §b1, item N1 below).
4. **flm cross-link covers one of two discovery surfaces:** the "Known crash" bullet repeats the re-pull discipline without the doctrine pointer (10-41 report §b1) — judged out of scope for a one-line task, logged as follow-up.
5. **CONTRIBUTING.md does not yet teach the override recipe** the AGENTS.md gotcha encodes (mkOverride-50 template, throwaway-eval command, priority ladder) — queued work, deliberately not folded into task 1.

## c) NOT STARTED (window skips — all routed in (f) / TODO_LIST)

- The **deploy** that lands the boot-cycle fix chain (owner-gated, every storage/stability task since 2026-09-21 waits behind the deploy-authority decision, TODO row 71).
- The **offsite-borg go-live stack** (owner inputs), **Phase-2 hot-DB waves**, **restic proof chain**, **paperless DR drill**, **llama-rag root-cause bisect** — all already queued, untouched this window.
- No-op accounting: neither verify-only dispatch produced a derivable queue record beyond its report commit (no sanctioned no-op ack exists — systemic, see (d)/(e)).

## d) TOTALLY FUCKED UP

1. **A queue row actively taught a verification-gate BYPASS on a false premise** (caught 06-03, closed by task 3): `docs/todo/pipeline.md:155` claimed `nix flake check --no-build` fails on `checks.disko-layout` and therefore "every commit needs `--no-verify`" — meaning gitleaks/format/eval skipped fleet-wide for nothing. The 06-03 run's own commit empirically passed that exact check. This is the worst class of queue damage: false doctrine that erodes the security gate. Closed by task 3's environmental root-cause; the row no longer carries the instruction.
2. **Duplicate dispatch burned two whole agent runs this window.** Task 2 (shellcheck) and task 3 (disko) were both dispatched AFTER a prior run had closed them `[x]` the same day. The queue's harvest lags completion and dispatches without a row-state preflight. Accounting is also blind: verify-only runs leave no footer-bearing work commit, so the queue cannot derive their outcome. (Prior window logged the same pattern: 4 closed IDs re-fired 7 times on 09-24.)
3. **A machine-wide environmental breakage masqueraded as repo breakage for ~2 days** — the `/run/binfmt` cycle looked like a `checks.disko-layout` code failure and cost multiple agent sessions (one shipped `--no-verify` doctrine, see #1). The meta-lesson (fleet incident, not per-task noise) is not yet codified anywhere (item 10 below).
4. **Nothing shipped by this window is broken.** All five commits verified clean; the two partially-blind follow-ups (lib shellcheck, second flm bullet) are logged, not damage.

## e) WHAT WE SHOULD IMPROVE

1. **Queue dedup preflight at dispatch time** — re-check the TODO_LIST row state (`[ ]` vs `[x]`) before running; would have saved both wasted runs this window. (Adjacent queued rows 167/173 cover the reporting-policy side; the dispatch-side check itself is still unowned.)
2. **Sanctioned no-op/ack close-out** for already-done dispatches, so verify-only runs are derivable (report commit carries the footer today — an accident of convention, not a contract).
3. **Time-sensitive queue rows need re-verify commands.** The disko row asserted "live <date>" gate-death with no one-line re-check; it survived ~a day of contradicting evidence. Convention + backfill.
4. **`[x]`-with-RESIDUAL is an improvised third state** (row 43). Codify it in `check-todo-system.sh` so harvests neither re-open nor mis-skip such rows.
5. **Probe-before-run protocol** (git log + TODO grep first — resolved the disko no-op in <30s) should be a documented first step for every queue run.
6. **Machine-readable IO-storm skip rule**: "skip full flake check when PSI avg60 high" lives in prose; a `/proc/pressure/io` one-liner preamble would make it uniform. Same for the docs-only-delta argument ("gate safety unchanged because delta is .md-only").
7. **Proof-doctrine symmetry**: the shellcheck leg now has the repo's strongest closure (persisted proof + flake check + negative mutation + CI); the other pre-commit legs (ruff, formatter, templ, nullglob) have no equivalent.
8. **Asymmetry sweeps should grep the whole section** (the second unlinked flm mention was one `grep` away) — generalize into the one-sweep AGENTS pointer audit (item 4 below).
9. **`docs/status/README.md` does not exist** — the archive convention it is supposed to define is folklore (571 files in `archived/`). One page would fix it.
10. **"A gate dying for ALL agents = fleet incident"** should be a CONTRIBUTING rule with the /run/binfmt saga as the case study.

## f) NEXT THINGS (harvested to TODO_LIST; dedup-checked against all 271 open rows)

1. **Extend CI's shellcheck job to `scripts/lib/*.sh`** (find -print0 | xargs -0, keep `--severity=error`) — closes the error-bar blind spot on the deploy-gate lib; while there, add `.githooks/*` to the hook's own shellcheck leg.
2. **mktemp (+trap rm) the hook's per-leg logs** (`/tmp/shellcheck.log`, `/tmp/ruff.log`) — fixed paths race under concurrent commits in a multi-agent repo.
3. **One-sweep AGENTS.md pointer audit**: grep every service bullet mentioning in-place overwrite/delete of /data-resident artifacts for a missing snapshot-pinning doctrine pointer; fix all in one commit (subsumes the second flm "Known crash" bullet).
4. **Inventory hardening**: add inline re-verification one-liners (`stat -c %i` per victim) + a freshness tripwire to `docs/services/data-damage-set.md`.
5. **Reconcile the "~12 journal pairs vs 11 enumerated" residual** in the /data P0 row or downgrade the "~12" wording.
6. **Add the extendModules override recipe to CONTRIBUTING.md's Eval-Time Guards** (mkOverride-50 template, throwaway-eval command, priority ladder) — pairs with queued row 184's guard-pattern note.
7. **CI early warning: scheduled clean-HEAD `nix flake check --no-build`** — the /run/binfmt gate death would have been caught in hours, not days.
8. **Shared queue-agent pre-run preamble**: PSI-threshold probe + docs-only-delta check as a small script.
9. **Promote `boot.binfmt.preferStaticEmulators = true`** to a queued item after the deploy proves the ordering fix — removes `/run/binfmt` from extra-sandbox-paths, killing the whole class.
10. **Codify the fleet-incident rule** in CONTRIBUTING: a gate failing for ALL agents is an environment incident (/run/binfmt saga as case study), triage before touching the task.

Not re-added (already queued, verified present): offsite-borg go-live stack, deploy authority, restic proof chain, hot-DB waves, tq dedup/no-op reporting policy (rows 167/173/184/186), gate-triage runbook (row 54), heal-attribution breadcrumbs (row 55), formatter-exclusion guard (row 168), repair-recipe cross-link (row 93).

## g) QUESTIONS FOR THE OWNER (→ TODO_LIST as BLOCKED items)

1. **`services.offsite-borg.enable = false` → `lib.mkDefault false`?** Kills the whole plain-100 probe-conflict class (probes with plain `true` win; no `mkOverride 50` needed forever) vs keeping the go-live flip a conscious edit. Framed since 2026-09-23, unanswered by 2 closeouts.
2. **Hook shellcheck source:** keep `nix shell nixpkgs#shellcheck` (always-current, per-commit nixpkgs eval + network on the commit path) or pin from this flake (hermetic, faster, drifts only on flake bumps)?
3. **Placement doctrine:** is `docs/services/data-damage-set.md` acceptable as the permanent home for a STATE doc inside the services runbook dir, or does the repo grow a `docs/ops/` home once a second state doc appears?

## h) BAND DRIFT (ADR-0015 accountability)

**None recorded.** `tq facts --type task.reprioritized` returns 0 facts and the journal (6,794 facts, scanned 2026-09-25 11:17) contains no `task.reprioritized` events in the window. The only queue-level priority signal observed was mechanical, not a band move: task `000001a0d13bb98a…` (go-taskqueue repo) was repeatedly `task.requeued` 10:49–10:55 on the preflight "repo has uncommitted changes" guard — a pacing effect, not a reprioritization.

---

**Point-in-time snapshot at 2026-09-25 11:30 CEST.** Section (f) items were appended to TODO_LIST.md (dedup-checked); questions (g) appended as BLOCKED rows. This report is the harvest input; later sessions must not re-harvest its EXISTING-tagged queue rows.
