# Status: vendorHash wave fix (discordsync/browser-history) — pressure-gated deploy, landed via parallel session

**2026-10-07 06:50 CEST · session scope: the 2026-10-06 23:54 `nix flake update browser-history bank-sync discordsync && nh os switch` failure and everything this session did about it.**

**Verdict up front:** the wave's build failures are FIXED and LIVE on evo-x2 (`/run/current-system` = `vyjjl6al…`; live units verified: `discordsync.service → s7w9p0m0…-discordsync-1ac31f8` (this session's re-pinned-shim build), `browser-history.service → 999dlpy9…-browser-history-server-3ebbfbf` (parallel session's newer, shim-free lock)). The final switch was landed by a PARALLEL session at ~06:40 when the I/O storm dipped — this session's own 13 deploy attempts all correctly aborted at the memory-pressure gate.

---

## a) FULLY DONE

1. **DiscordSync vendorHash fix (both surfaces, first-hand evidence)** — the 23:54 failure was the documented TEMPORARY shim (pinned 2026-10-05 at lock rev `1c20710`, got `YZTwoufR…`) going stale when the input moved to `1ac31f8`. Re-pinned BOTH sites — `modules/nixos/services/discordsync.nix` (direct input ref) and `overlays/linux.nix` (`pkgs.discordsync` surface) — to `sha256-/NYfLmDMxO+YDEJQqELmP4DXzxtKjgLXDiHLWjeL018=` with updated provenance comments. FOD built green (`s7w9p0m0…-discordsync-1ac31f8`); both pins verified present at HEAD (2+2 grep hits); the exact build now serves live traffic.
2. **Second masked root failure enumerated and fixed** — nh's stop-at-first-failure hid it at 23:54; the AGENTS-mandated `--keep-going` toplevel run exposed `browser-history-server-d834910-go-modules` (shim `hca9rn9t…` vs got `4Rrty+r2…`). Re-pinned `modules/nixos/services/browser-history.nix`, toplevel went green. (Hours later the parallel session's `f0442ea3` superseded this by DROPPING the shims — upstream `3ebbfbf` carries the fix; their drop satisfies the shim lifecycle's drop condition and the live unit proves it.)
3. **Transient `toFile` eval failure correctly diagnosed as NOT ours** — `nix flake check` failed twice with `path '5qx0vvw…-backup-drifted.nix' is not valid` (the `borg-restore-drill-fixture`'s `builtins.toFile` at flake.nix:1876). Discriminated in three probes: trivial `toFile` green, `nix path-info` confirmed the exact path invalid, exact-chain standalone reproduction SUCCEEDED and healed the store entry. Zero code changes; my two string edits cannot influence that content hash. Check green afterwards.
4. **Toplevel builds green ×3** — `fr9lk2mz…` (my pins), `qfgsqxzl…` (at the parallel session's post-drop HEAD), and the live `vyjjl6al…` closure carrying both fixes. `nix flake check --no-build` green at both HEADs ("all checks passed", aarch64-darwin omission expected).
5. **Pre-deploy gate green** — 76 passed / 0 failed; §11 vendorHash preview reported "all deploy go-modules FODs cached — vendorHash proven by prior builds", which closed the browser-history agent `l6ATO1jf…` question with store evidence (mooted same-session by the shim drop).
6. **Live-state verification, not output-trust** — per the "assert WHICH entity served it" rule: read ExecStart from `/run/current-system/etc/systemd/system/*.service` and matched both store paths to this session's builds before claiming success.
7. **Multi-agent conflict handled per doctrine** — discovered the parallel session had dropped my hours-younger browser-history re-pin (`f0442ea3`, bundled into a "freeze-22 addendum" daemon commit): did NOT revert; re-verified eval + build at their HEAD; killed my own retry loop the moment their switch landed to avoid firing a redundant second switch mid-verification.

## b) PARTIALLY DONE

1. **The deploy itself** — objective achieved, but NOT by this session: 13 attempts over ~1h45m (04:55–06:37) all rc=12 at the pressure gate (io PSI some avg10 97.9% → 26% across the window; tq-agent-pool wrote +97 GB per the freeze-22 addendum). The parallel session's switch slipped through a <20% dip at ~06:40. This session contributed the verified, buildable config — not the switch.
2. **§f self-harvest** — direct follow-ups landed at authoring (2 new rows in `docs/todo/pipeline.md`, 1 queue one-liner; the discordsync shim drop-check and the upstream sweep were ALREADY queued by the 01-25 report + row 111 — no duplication).
3. **Comment provenance for browser-history** — my restore-edit (agent `l6ATO1jf…` lineage) was itself superseded by the shim drop; no drift remains, but the work is moot.

## c) NOT STARTED (in-scope, deliberately untouched)

1. **DiscordSync upstream hash fix** (`buildflow -s nix-hash-fix --fix` + push + re-lock + drop both shims) — blocked on push permission; already tracked (row 111 + the 01-25 drop-check row naming `discordsync.nix:40`).
2. **bank-sync input** — updated in the user's command; never independently probed. Its FODs never appeared in any build list (= store-valid for this closure), but no direct evidence was gathered.
3. **The other ~19 repos of the a7868a7-wave sweep** (row 111) and the pre-existing eval-warning cleanup rows — untouched per the no-scope-creep instruction.

## d) TOTALLY FUCKED UP

1. **~2 hours of retry churn into a storm** — 13 attempts, each a full pre-deploy suite + eval, ALL gate-blocked. The gate was RIGHT every time and my loop added nix-daemon load to the exact box state (freeze-#22/#23 conditions live) the stability docs say not to load. The loop had no early-exit on "PSI trend not draining" and no cap on total wall time.
2. **The retry loop lacked a target-live guard** — after the parallel session's switch, attempt 14 would have deployed my (older) toplevel over their newer one. Caught only because I re-probed `/run/current-system` before the next poll; the loop itself was one sleep-cycle from a harmful redundant switch.
3. **First `nix flake check` ran without `set -o pipefail`** — `tail` swallowed the rc and I printed "RC=0" under a failing check. This is the EXACT trap `docs/agents/nix-flakes.md` line 72 documents ("always set -o pipefail when piping build output through a filter"). Repeated a known lesson once.
4. **First browser-history comment edit silently dropped the agent hash's provenance** — self-caught on re-read and restored, but the lossy version existed for one edit cycle.
5. **Diagnosis order** — on the toFile failure I theorized (GC race, daemon cache) before running the cheap discriminating test; cost one extra round-trip.

## e) WHAT WE SHOULD IMPROVE

1. **`deploy.sh --wait-for-pressure <minutes>`** — a first-class bounded wait (PSI-gated sleep + re-gate, with a target-already-live guard) instead of every session hand-rolling retry loops. Queued this session.
2. **Drop-check-first protocol for shim waves** — the 01-25 row's insight (upstream is often ALREADY correct at the locked rev; the 2026-10-07 browser-history case proves a stale shim can BREAK a deploy upstream already fixed) should be the DEFAULT first move on any hash mismatch, before re-pinning.
3. **Deploy idempotence guard in scripts** — `nh`/deploy wrappers could refuse to switch when the built toplevel is already the live system.
4. **toFile fixture resilience** — the drift-fixture failure mode (store entry invalid under GC/storm pressure) self-heals but costs a full flake-check red; a pre-realize or re-add retry inside the check would convert it to a warning.
5. **Session discipline** — pipefail rc capture must be reflexive, and every background loop needs: wall-clock cap, trend check, and a live-state re-read per iteration.

## f) NEXT (up to 50; scoped to this session + what it noticed; ★ = NEW this session, rest already tracked)

| # | Item | Status pointer |
|---|------|----------------|
| 1 | ★ `deploy.sh --wait-for-pressure <min>` with target-live guard | NEW → queued (pipeline.md + TODO_LIST) |
| 2 | ★ `[watch]` toFile fixture `path … is not valid` under GC/storm; self-heal protocol | NEW → queued (pipeline.md) |
| 3 | Drop-check the 4 module-surface shims (incl. my `discordsync.nix` one) — likely droppable NOW | queued: 01-25 report row |
| 4 | DiscordSync upstream hash fix + shim drop (both sites) | queued: row 111 |
| 5 | Post-deploy health pass for the wave (discordsync catch-up writer, Gatus, auth vHosts) — owner unclear, see §g3 | NEW (action, not queued) |
| 6 | Row 741/754 nested art-dupl FOD check — tonight's 25-drv build list showed NO art-dupl FODs; candidate for closure via re-dispatch protocol | queued: TODO_LIST 754 |
| 7 | Row 111's remaining ~19 repos of the a7868a7 sweep | queued: row 111 |
| 8 | bank-sync input probe (never directly verified this session) | NEW (small) |
| 9 | mr-sync cmdguard/v4 classification (blocked:push) | queued: upstream.md |
| 10 | branching-flow 0.6.4 version-sync push + shim drop | queued: upstream.md |
| 11 | browser-history empty-dashboard chain (cqrs-htmx push → deploy → verify) | queued: upstream.md |
| 12 | Domains repo push (CAA reconciliation) | queued: upstream.md |
| 13 | nixpkgs netbird `ManagementUrl` module fix (verify-before-filing first) | queued: upstream.md |
| 14 | monitor365 `/ds/` cache-policy follow-ups | queued: upstream.md |
| 15 | Catalog integration-subdomain warning (21 names) | queued: services.md/TODO_LIST |
| 16 | discordsync-db-backup stalled-dump failure catch-up (OnFailure retry) | queued: storage.md |
| 17 | discordsync-attachments-migrate stub-fixture test BEFORE its deploy trigger | queued: storage.md |
| 18 | Post-crash resumable-reader pause automation (freeze-6 rule (a)) | queued: stability.md |
| 19 | Freeze #8–#13 taxonomy entries for stability.md | queued: stability.md |
| 20 | tq-agent-pool +97 GB write attribution → dispatch gating (freeze-#23 conditions live) | queued: stability.md lineage |

(Remaining ~30 slots deliberately NOT filled with repo-wide items — this report's scope is this session; `docs-health` HARVEST can widen later.)

## g) QUESTIONS (cannot answer myself)

1. **Pressure-gate policy:** when a fix is build-verified and the storm is third-party (tq battery), do you want deploys to FORCE (`DEPLOY_FORCE_PRESSURE=1`), keep bounded-waiting, or is there an owner-only "pause the pool, deploy, resume" runbook? Two sessions burned ~4h of retries tonight; the policy needs a ruling.
2. **May I fix DiscordSync upstream** (`buildflow -s nix-hash-fix --fix` with `/NYfLmDMx…`, push, SystemNix re-lock, drop both shims)? It's a push to your repo — your call; row 111 + the drop-check row are pre-staged.
3. **The ~06:40 switch that landed the wave** — was that your terminal/the other agent's intended deploy, and who owns the wave-level post-deploy verification (I stopped my loop to avoid double-switching; `post-deploy-check.sh` has not been run by ME against `vyjjl6al…`)?

---

*Self-harvest at authoring: §f1 + §f2 landed in `docs/todo/pipeline.md` (+ §f1 one-liner in `TODO_LIST.md`); §f3–§f20 were already queued by prior sessions (verified present before writing — no duplication).*
