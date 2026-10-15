# Status: discordsync vendorHash shim drop + gitea-runner STATE_DIRECTORY list fix — LIVE

**Session window:** 2026-10-15 ~19:25–20:30 CEST · **Host:** evo-x2 · **Trigger:** user's `nix flake update discordsync` (bf7e459 → 0089b99) → vendorHash FOD mismatch → "fix"
**End state:** all green — discordsync live on 0089b99, gitea-runner live and registered, anchor verified (`/run/current-system` = `system-898-link` = `gl4djjgdw…`), both fixes committed by the daemon (6193f506 batch, 73a2be3a).

---

## Timeline (first-hand evidence throughout)

| Time | Event | Evidence |
| --- | --- | --- |
| ~19:25 | User paste: `discordsync-0089b99-go-modules` FOD hash mismatch — specified `UnFb4VRSMfx…`, got `3dje+f7TFwv13yGGCesJFhfiBpjWl2RPaQF1Dou1f50=` | user log, 19:21 nh run |
| 19:2x | Shim located: `modules/nixos/services/discordsync.nix:51-53` (re-added 2026-10-15 fleet wave at lock cac57aa). Single surface confirmed (overlays shim dropped 2026-10-11, `lib/lars-packages.nix` has none) | rg |
| 19:2x | **Drop-first protocol fired:** upstream `vendorHash.nix` at locked rev 0089b997 bakes EXACTLY the got hash `3dje+…`; upstream's lock nixpkgs node `55bfb4d` matches our `discordsync/nixpkgs` node (identical FOD environment) → shim DROPPED, direct input reference restored, provenance comment written | `gh api …/vendorHash.nix?ref=0089b997…`, `…/flake.lock` |
| ~19:30 | Toplevel build GREEN (`qx847n6p…`) after drop | `nix build … --keep-going` |
| 19:37 | Deploy attempt 1: pre-deploy pressure gate REFUSED (io PSI some avg10 58%, nvme0n1 101% — real storm from parallel ghostty sessions, NOT our build's residue) | `scripts/deploy.sh` gate output |
| 19:39–20:09 | Watcher round 1: **BROKEN — `bc` missing, calm-check never evaluated**; 30 min of polling with a dead condition (min io avg10 observed 29%) | job log |
| 20:00–20:20 | Watcher round 2 (shell integer compare, 2 consecutive <30): ran correctly, threshold never met | job log |
| 20:10 | **User deployed themselves** (nh): build GREEN 40/40 (shim drop proven), switch live, discordsync started on 0089b99 — BUT activation **exit 4**: `gitea-runner-evo\x2dx2.service` failed (`forgejo-register-runner` ExecStartPre → `mkdir: cannot create directory '/var/lib/gitea-runner:': Read-only file system` ×5 → start-limit-hit) | user paste |
| 20:11–20:20 | Runner root cause isolated: nixpkgs 7fd4004 → 55bfb4d changed the `gitea-actions-runner` module — `StateDirectory` is now a 2-element list `[ "gitea-runner" "gitea-runner/<name>" ]` + NEW `RuntimeDirectory=gitea-runner/<name>` (verified in upstream source at 55bfb4d). systemd therefore sets `STATE_DIRECTORY` as a colon-joined LIST; our register script's naive `"$STATE_DIRECTORY/${hostName}"` produced `/var/lib/gitea-runner:/evo-x2`; `mkdir -p` died creating the bogus `/var/lib/gitea-runner:` component (bare `/var/lib` is read-only in the sandboxed ExecStartPre). Empirical anchor: last clean start 03:14:30 ran under gen-894 whose unit had ONE StateDirectory line (silent mkdir on existing dir); the failing unit had TWO. Unit-vs-unit diff across 870–896 also proves the register script itself was unchanged since gen 870 — the MODULE changed under it | journal, per-generation unit greps, upstream source |
| 20:2x | Fix: `modules/nixos/services/_forgejo-scripts.nix:1489` → `INSTANCE_DIR="''${STATE_DIRECTORY%%:*}/${hostName}"` (first list entry; lands on `/var/lib/gitea-runner/evo-x2`, matching upstream's own `WorkingDirectory`). Rendered script verified (`3h31gbz…` line 16). Toplevel GREEN (`gl4djjgdw…`) | store inspection |
| 20:17 | (Context) another switch wave still carried the OLD script → same mkdir failures again, start-limit re-hit | journal 20:17:40–47 |
| 20:22:01 | Deploy landed (user/parallel session fired it): **runner Started → "declared successfully" → "[poller] launched"** — fix PROVEN LIVE | journal |
| 20:24 | Anchor discipline: `/run/current-system` == `system-898-link` == `gl4djjgdw…` (the fixed toplevel). discordsync serving `/healthz` 200, `/metrics` 200 | readlink, journal |

---

## a) FULLY DONE

1. **discordsync vendorHash fix — shim DROPPED, not re-pinned.** Upstream converged at the locked rev (drop-first protocol from `docs/agents/nix-flakes.md`); single-surface verified before editing. LIVE on 0089b99, health 200s.
2. **gitea-runner `STATE_DIRECTORY`-is-a-list fix** — root-caused to the nixpkgs 55bfb4d module change (2-element StateDirectory + RuntimeDirectory), fixed at the script (first-entry extraction), rendered-output verified, LIVE: runner registered + poller launched at 20:22:01.
3. **Deploy verified end-to-end** — exit-4 activation did NOT unanchor: `/run/current-system` == latest `system-898-link`; no exit-14 class.
4. **Both fixes committed** (daemon): discordsync.nix in the 13-file batch `6193f506`, `_forgejo-scripts.nix` solo in `73a2be3a`. Tree clean at report time.
5. **Stale watcher killed** (job 020) after the deploy landed — no rogue re-switch pending.

## b) PARTIALLY DONE

1. **Post-deploy battery breadth** — verified discordsync liveness + runner registration + anchor personally; did NOT run the full `scripts/post-deploy-check.sh` (§19, auth-gateway, memory-throttle sweep legs) — note this switch ALSO carried rocm 7.2.3→7.2.4, kernel 7.2.9→7.2.10, nix 2.34.8→2.34.9, forgejo-lts 15.0.9→15.0.10 from the wider lock wave (user's 20:10 paste diff), none soak-tested by me.
2. **Self-harvest** — direct follow-ups queued (see §h); the brainstorm-scale §f items deliberately NOT harvested (ROADMAP fuel per docs-health rigor).

## c) NOT STARTED

1. CHANGELOG row for today's second vendorHash wave (wave sessions self-document; today's drop + runner fix are unrecorded there).
2. `STATE_DIRECTORY` list-hardening sweep across the other naive users (paperless.nix:927/1028, pool-smart-metrics.nix:107) — same trap, currently single-StateDirectory units, re-breakable by any upstream module change like today's.
3. forgejo-lts 15.0.10 DB-migration review (Docker-removal doctrine: DB-backed apps get migration review on minor bumps).

## d) TOTALLY FUCKED UP

1. **Watcher round 1 was dead code for 30 minutes** — `bc` doesn't exist on this box, so the calm-check never evaluated; the loop "worked" while its decision logic silently never ran. Own bug, caught when reviewing the round-1 log. Lesson applied: shell integer compare in round 2.
2. **A failed diff briefly read as "units identical"** — my first 895-vs-896 unit diff failed silently on `\x2d` path escaping and empty output was nearly taken as "no diff". Only the later per-generation grep loop with a working glob surfaced the real unit delta (1 → 2 StateDirectory lines). Empty tool output ≠ verified equality.
3. **Deploy latency ~50 min was self-inflicted** — watcher patience where a user re-run (which happened at 20:10) would have surfaced the NEXT blocker (the runner bug) an hour earlier. The gate refusals were correct; my choice to wait rather than report-and-hand-back was the suboptimal part.

## e) WHAT WE SHOULD IMPROVE

1. **`STATE_DIRECTORY` must be treated as a colon-joined list everywhere** — one upstream module change re-broke a "working for months" script. Harden every consumer (`%%:*` first-entry) in one sweep, not after each breakage.
2. **The vendorHash drop-first protocol worked exactly as designed** — worth keeping as the documented default (upstream converged ~same-day again; re-pinning would have created tomorrow's stale shim).
3. **Watcher scripts must prove their decision logic** — a loop that only prints readings proves nothing about its branch. First iteration of any watcher: one forced trip of each branch.
4. **Parallel-session io storms are now the normal deploy-blocking condition** — three ghostty scopes at 77–90% stall for 60+ minutes. The gate is right to block; the fleet lacks any coordination (build semaphore, nice/ionice for agent builds, or a "who is building" oracle).
5. **Attribution gap on the final deploy** — I know WHAT deployed (gl4djjgdw, my build) but not WHO fired the 20:22 switch (user vs parallel agent session; my watcher was NOT calm yet). Acceptable here, but the multi-agent ledger relies on owner memory.

## f) NEXT — brainstorm list (up to 50; most are ROADMAP fuel, not commitments)

**This fix's tail:**
1. CHANGELOG row: 2026-10-15 wave2 (discordsync shim drop + runner STATE_DIRECTORY fix) — QUEUED this session.
2. STATE_DIRECTORY `%%:*` hardening sweep (paperless ×2, pool-smart-metrics ×1, audit for more) — QUEUED this session.
3. Sweep ALL repo scripts for `$STATE_DIRECTORY` naive interpolation beyond the four known sites.
4. Consider an eval-time/pre-commit lint leg: grep generated shell for `"$STATE_DIRECTORY/` (the exact drift class that re-broke today).
5. gatus coverage check: is `gitea-runner-evo\x2dx2` probed at all? A start-limit-hit unit sat failed for an hour before anyone looked (the nh exit-4 did flag it — but only because a deploy happened).
6. forgejo-lts 15.0.9→15.0.10 migration review (DB-backed doctrine) + forgejo service green sweep.
7. Runner start-limit tuning: ExecStartPre failures burned the 5-restart budget in 10 s; consider `StartLimitIntervalSec`/`RestartSec` so a transient forgejo-restart race self-heals instead of latching.
8. Re-verify `docs/todo/pipeline.md` art-dupl nested-consumer row against the NEW lock (discordsync input moved again today).
9. Consider upstreaming the `%%:*` fix pattern to any LarsArtmann repos with their own register-style scripts (fleet grep).
10. The 2026-10-15 wave2 hash data point does NOT resolve the open "DiscordSync goModules FOD hash invariance" TODO row (different hash era: yh2ttYTK-era vs UnFb4VRSMfx/3dje+); leave that row open — do NOT close on today's evidence.

**VendorHash / wave system:**
11. `buildflow -s nix-hash-fix` trial on a green tree (pipeline.md standing row) — today was another hand-drop (justified via drop-first, but the tool trial remains undone).
12. Auto-queue "re-probe upstream, drop shim if converged" on every shim re-pin (pipeline.md:435, still open).
13. Sweep remaining lars-packages.nix flakePkgShim entries for drop-window convergence (each lock move reopens/closes them silently).
14. day-2 check: does upstream DiscordSync stay green at 0089b99 through OUR graph (today's environment match was verified at eval; a follow-up toplevel build after the next root-nixpkgs move re-proves it).

**This switch's wider cargo (from the user's 20:10 diff — unverified by me):**
15. rocm 7.2.3→7.2.4: soak-check llama-rag/GPU services post-bump.
16. kernel 7.2.9→7.2.10: ttm.pages_limit/page_pool_size knobs unchanged? (GTT doctrine says re-verify after kernel moves).
17. nix 2.34.8→2.34.9: watch for trusted-settings re-prompts and nh/nix interaction regressions.
18. forgejo-lts bump: verify Actions runner executes a real job end-to-end (registered ≠ functional).
19. firefox 158 / chromium .79: user-facing; nothing to do unless breakage reported.
20. Daily nixpkgs-compat CI + nightly go-deps-audit results after today's double lock move.

**Pressure / storm discipline:**
21. Fleet build semaphore or ionice policy for agent-initiated nix builds (three sessions storming one QLC).
22. "Who is building right now" oracle (per-cgroup io.pressure aggregator) as a crushrc guard friend.
23. Re-test deploy_pressure_gate fixture coverage (stability.md row exists — still open).
24. Consider a deploy-gate "small-delta fast path" decision (owner policy call, not agent call).

**Hygiene observed in passing:**
25. Journal truncation warnings (`system@…journal~ is truncated, ignoring file`) appeared on every journalctl — audit hot-tier journal integrity (forensics capability at risk).
26. `post-deploy-check.sh` grew +44 lines from a PARALLEL session today (11f6ffa6) — co-verify before trusting it (shared-tree rule).
27. system-path python3.13/3.14 colliding-subpath warnings — plan the 3.13 exit when immich deps allow.
28. templ version-check warning (generator 0.3.1020 < go.mod 0.3.1070) in discordsync + browser-history builds — upstream CLI bump rows.
29. `fastflowlm.socket` newly started units — confirm intended (appeared in both of today's switches).
30. Gen 896→898 within 12 minutes across parallel sessions — deploy-rate discipline between agents (last-writer-wins today; fine, but unmanaged).

## g) Questions I cannot answer myself

1. **Who fired the ~20:22 deploy** — you manually, or a parallel agent session? (My watcher was still waiting on calm; the journal shows the switch but not the hand.) Matters for the multi-agent ledger and for whether gen-897 was an intentional intermediate.
2. **Gate policy call:** do you want a "small-delta fast path" (pre-built closure + tiny unit delta skips the io gate) or is strict blocking until <20% always the intent, even for fix-forward deploys?
3. **Watcher etiquette:** when the gate blocks, do you prefer I hand back immediately with the one-liner for you to fire, or keep arming calm-window watchers (round-2 style) in the background?

## h) Self-harvest ledger (AGENTS.md queue rule)

- Queued this session: (1) CHANGELOG wave2 row → `TODO_LIST.md` + `docs/todo/services.md`; (2) STATE_DIRECTORY list-hardening sweep (grep-verified sites) → `TODO_LIST.md` + `docs/todo/services.md`.
- Deliberately NOT harvested: §f items 3–30 (brainstorm/ROADMAP fuel or already-tracked rows — referenced here so the next HARVEST pass can route them with docs-health rigor).
