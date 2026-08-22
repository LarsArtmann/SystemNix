# XFS Migration Follow-Up Round: Phantom-Gate Fix, Restamp, Profile-Anchor Tripwire (2026-08-22 06:05)

Session ~05:35–06:05 CEST. Continuation of
`2026-08-22_05-30_clickhouse-xfs-migration-resume-live-state-found.md`: this round
executed every actionable item from that report's (e)/(f) lists. Concurrent sessions +
auto-commit daemon active throughout (three more daemon-swept commits; all verified).

---

## Executive summary

- All P0/P2 code items from the previous report are **done, verified, pushed**:
  phantom-green gate fixed and live-fired, `restamp` subcommand added, profile-anchor
  tripwire (metric + Gatus + allowlist) added, AGENTS.md lessons recorded.
- **The machine is STILL un-deployed and now manually-switched a THIRD time**
  (`6wjiga6` → `8y6vdvvd`, still no numbered profile — observed live mid-session).
  The new tripwire will fire `system_current_system_profiled 0` the moment it
  deploys — correct behavior, loud signal.
- Nothing in this round touched data, the running stack, or the migration state.
- **The single remaining blocker for the whole migration is unchanged: one
  `nix run .#deploy`.**

---

## a) FULLY DONE (this round)

| # | Item | Evidence | Commit |
|---|------|----------|--------|
| 1 | **Phantom-green XFS gate fixed** — post-deploy-check.sh now gates on the deployed fstab entry (`awk '$1 !~ /^#/ && $2 == "/var/lib/clickhouse"'`) instead of `/etc/systemd/system/var-lib-clickhouse.mount` (never populated for fstab-generated units) | live-fired against the real machine: `gate ARMED, fstype=xfs -> PASS branch fires`; positive/negative/comment cases unit-tested in shell | `4c792ca6` |
| 2 | **`restamp` subcommand** — re-creates `.systemnix-migration-state` on the live XFS mount (gated: must be mounted xfs, mountpoint, non-EIO; refuses zero-part stamps). Sound because finalize's tripwire is a ≥50% floor and merges only consolidate downward | `bash -n` + usage dispatch test (exit 64, shows `{prepare\|restamp\|finalize}`) | `4c792ca6` |
| 3 | **Profile-anchor tripwire** — `system_current_system_profiled` metric in system-health (computed by `readlink -f /run/current-system` vs `system-*-link` globs), Gatus "System Profile Anchor" endpoint (anchored-form pats — HELP embeds the 1-value), Discord runbook text, `KNOWN_NEW_METRICS` registration | live simulation: correctly reports **0** (machine IS manually activated) + negative control (fake path never matches); endpoint evaluates into evo-x2 gatus config | `a7c82bbc` |
| 4 | **Same-class audit** — swept both deploy-check scripts + all of `scripts/` for other `.mount`-unit existence gates: none exist; every other check targets `.service` units (module-generated, correctly static-path) | grep sweep output | — |
| 5 | **AGENTS.md** — fstab-mount unit-namespace exception appended to the enable-gate bullet + cross-reference to the new detector | commit diff | `a7c82bbc` |
| 6 | **Verification battery** — `bash -n` ×3 scripts; `nix flake check --no-build` (all checks passed); evo-x2 toplevel eval OK (note: attribute needs quoting — `.#nixosConfigurations."evo-x2"`); gatus endpoint eval shows both "System Profile Anchor" and "ClickHouse Data Mount" | command transcripts | — |
| 7 | **Pushed + verified landed** — daemon split my staging into two accurately-described commits (`4c792ca6`, `a7c82bbc`); content verified via `git show` before push | `git status -sb` clean, local == origin after fetch | — |

## b) PARTIALLY DONE

| Item | State | Remaining |
|------|-------|-----------|
| Migration completion | All code + gates ready | **User deploy, verify, `restamp` (optional), `finalize`** — unchanged since last report |
| Load-average investigation (P2 item 18) | Root-caused to: llama-server (17.6%), clickhouse (17.2%, post-migration merge backlog), crush (15.6%), nsncd (15.1%), kcompactd0 (14.3%) | None — no kernel-freeze signature (no D-state pileup, no IO PSI check performed); CH healthy. Reclassify as observation |

## c) NOT STARTED (all user-action or post-deploy gated)

1. `nix run .#deploy` — persist XFS config + activate the new tripwire + armed smoke checks.
2. Post-deploy verification pass (now actually armed: XFS + ping checks fire on fstab gate).
3. `sudo bash scripts/migrate-clickhouse-xfs.sh restamp` → `finalize`.
4. Soak-period `clickhouse-predelete-*` snapshot cleanup.
5. Root-space reclaim monitoring as 3d+1w snapshots expire.
6. ClickHouse backup coverage decision (TODO_LIST P3).
7. Retirement of `system_current_system_profiled` from `KNOWN_NEW_METRICS` after first deploy proves it live (one deploy cycle later).
8. Gatus endpoint-green confirmation (still OIDC-gated from this context; sqlite path known but not exercised).

## d) TOTALLY FUCKED UP

Nothing new this round — two near-misses, both caught by process:

1. **Eval-path fumble**: first `nix eval .#nixosConfigurations.evo-x2...` failed on the unquoted hyphenated hostname; I briefly suspected a concurrent flake restructure before testing the quoted form (which worked). Cost: one wasted eval. Lesson: quote hostnames with hyphens in flake attrpaths.
2. **Stale remote-tracking alarm**: `git status` showed `[ahead 3]` AFTER a verified-successful push — a concurrent session's fetch race had left the tracking ref stale. Re-fetch resolved it (origin at `a7c82bbc`). Lesson: verify push state with a fresh `git fetch` before declaring desync; push-success outputlines are the truth, tracking refs are advisory.
3. (Carried, unchanged from last report — still the top risk) **the machine runs an un-profiled, hand-switched system**; a reboot reverts it to pre-XFS system-716. Now also *tripwired* (the detector ships in the next deploy), but the exposure window is open until that deploy happens.

## e) WHAT WE SHOULD IMPROVE

1. **Quote hyphenated flake attrpaths** (`.#nixosConfigurations."evo-x2"`) — unquoted works for eval of `evo-x2` only sometimes; failure mode looks like a missing attribute (misdiagnosable as concurrent-session breakage).
2. **Push verification protocol**: after daemon-raced commits, confirm sync with `git fetch && git status -sb`, not `git status` alone — tracking refs can lie under concurrent fetches.
3. **Gate-style checks deserve unit tests at write time** — the fstab awk gate was validated with 3 synthetic cases before commit; this is cheap and caught the comment edge case pre-deploy. Consider a tiny `tests/` harness for smoke-check predicates if more accumulate.
4. **The daemon's commit-splitting is now good enough to trust with attribution** — it split my staged set into two semantically-clean commits with accurate messages. Keep verifying content, but stop pre-writing commit messages for batches it will likely sweep.

## f) NEXT (up to 50; this session's scope — 12 concrete, then context)

**P0 — single blocking action:**
1. `nix run .#deploy` (user) — persists XFS, activates tripwire + armed checks, closes the reboot-revert window.
2. Immediately after: confirm Gatus "System Profile Anchor" goes green (it MUST — deploy creates the numbered profile) and "ClickHouse Data Mount/Usage" green.
3. `nix run .#post-deploy-check` — first run where the XFS block actually executes (was dead code until `4c792ca6`).
4. Watch one `clickhouse-xfs-metrics` cycle (5 min) + one system-health cycle for the new metric emission.

**P1 — finish migration:**
5. `sudo bash scripts/migrate-clickhouse-xfs.sh restamp` (arms finalize tripwire).
6. `sudo bash scripts/migrate-clickhouse-xfs.sh finalize` (snapshot @ → delete shadowed originals).
7. Verify root `@` usage starts trending down as 3d+1w snapshots expire; sanity-check btrbk root sends after.
8. Delete `clickhouse-predelete-*` after 1–2 week soak.
9. ClickHouse backup coverage decision (TODO_LIST P3).

**P2 — follow-ups from this round:**
10. Retire `system_current_system_profiled` from `KNOWN_NEW_METRICS` once verified live (next session).
11. Re-check CH merge backlog drains (CH CPU should fall from ~17% over the next hours; if not, inspect `system.merges`).
12. Consider documenting the quoted-attrpath + fetch-verify protocol in AGENTS.md if it recurs.

## g) QUESTIONS (cannot self-answer)

1. **Who/what is doing the repeated manual switches** (`6wjiga6` → `8y6vdvvd`, both un-profiled, ~1h apart)? If it's your hand or a concurrent session's `switch-to-configuration`, that's the banned pattern — the machine needs one real `nix run .#deploy` to close the reboot-revert window. Is anything blocking you from running it right now?
2. **Deploy scope confirmation**: master also carries concurrent-session work since `312ae0f2` (dozzle unification `1d475d06`, gatus pattern repairs `e5bb375c`, dnsblockd/templ-components bumps in `054ce8f6`, plus the untracked gomemlimit status doc) — deploying deploys ALL of it. Confirm that's intended.
3. **Finalize timing after deploy**: immediate finalize, or soak the XFS copy for N days first? (`restamp` before finalize either way, if you want the tripwire enforcing.)

---

## Appendix: verification evidence (this round)

- Gate live-fire: `awk ... /etc/fstab` → armed; `findmnt -no FSTYPE` → xfs → PASS branch
- Gate unit tests: real-line arm, comment-only no-arm, `/dev/null` no-arm
- restamp: `bash -n` OK; bare invocation → `usage: ... {prepare|restamp|finalize}`, exit 64
- Profile-anchor simulation: `SYSTEM_PROFILED=0` on live (correct — un-profiled); fake store path → no match
- `nix flake check --no-build` → `all checks passed!` (aarch64-darwin omission expected)
- `nix eval '.#nixosConfigurations."evo-x2".config.system.build.toplevel.drvPath'` → drv path, exit 0
- Gatus eval: `[{"name":"System Profile Anchor"},{"name":"ClickHouse Data Mount"}]`
- `git fetch origin` → `312ae0f2..a7c82bbc master -> origin/master`; `git status -sb` → in sync
- `ps aux --sort=-%cpu`: llama-cpp 17.6%, clickhouse 17.2%, crush 15.6%, nsncd 15.1%, kcompactd0 14.3% (load 24.85/35.28/31.81)

**Commits this round (all pushed; local == origin at `a7c82bbc`):**
- `4c792ca6` fix(scripts): phantom-green XFS gate + restamp subcommand (daemon-swept, verified)
- `a7c82bbc` feat(monitoring): system profile anchor detector (daemon-swept, verified)
- Prior round's report landed in daemon batch `1d475d06` (verified via `git log -- <file>`)
