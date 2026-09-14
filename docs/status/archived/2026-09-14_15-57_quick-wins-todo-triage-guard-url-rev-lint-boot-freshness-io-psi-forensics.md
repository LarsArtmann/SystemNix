# Quick-Wins Session Status Report — 2026-09-14

**Session scope:** TODO_LIST "easy things" triage → 7 items closed (4 shipped by this session, 3 verified already-done), 2 new hardening layers landed (eval guard + forensics capture). All verification green. Nothing deployed yet.

---

## a) FULLY DONE (this session)

| # | Item | What shipped | Verification |
|---|------|--------------|--------------|
| 1 | **`chown-vs-bind-audit` WARN → FAIL** (TODO P2 line 106) | flake.nix check now `exit 1` on findings + FAIL message names the fix pattern; comment updated (WARN era ended) | `nix build .#checks...chown-vs-bind-audit` green, zero current violations; already in CI trap-lint build list |
| 2 | **Boot-generation-freshness check** (TODO P1 line 49) | New `system_booted_is_newest_profile` gauge in system-health.nix (`readlink -f /run/booted-system` vs `/nix/var/nix/profiles/system`, fail-closed 0) + Gatus "Boot Generation Freshness" check (Monitoring group, 5m interval, anchored `pat()` conditions, Discord alert naming the 2026-09-07 stuck-boot class + pre-reboot-check runbook) | evo-x2 eval green; deployed-collector script in the (externally built) toplevel closure `bash -n` OK + metric lines present; gatus-pattern-lint build green |
| 3 | **`?rev=` input-URL eval-time guard** (TODO P1.5 line 69 item 3) | `inputUrlRevGuard` in flake.nix: rejects `?rev=` on any remote-scheme input URL (overrides flake.lock, re-pins backward); `git+file:` interim pins exempt (sanctioned dirtyRev defense). Chained into the existing `builtins.seq nixpkgsTarballGuard` idiom as `allEvalGuards` | Fixture-tested both directions via synthetic lockFiles: evil `github:…?rev=` → offender named; `git+file:…?rev=` → clean. evo-x2 eval + full `nix flake check --no-build` rc=0 |
| 4 | **`scripts/io-psi-forensics.sh`** (TODO P1 line 28 / hot-DB plan T1) | Trap-time attribution capture: per-cgroup `io.stat` totals (rbytes+wbytes, root cgroup excluded), top-20 procs by cumulative bytes, D-state tasks + stacks (root-only best-effort), PSI, diskstats, bounded journal tail → timestamped bundle under `/var/tmp/io-psi-forensics-*`. Every section timeout-bounded best-effort. Wired into guard trip action via `systemd-run --collect` (transient unit — guard's own cgroup reaps backgrounded children) + flake app `nix run .#io-psi-forensics` for manual runs; guard module reuses the same script via `builtins.readFile` (single source of truth) | shellcheck `--severity=error` clean; LIVE run verified with real attribution data (top offenders: project-discovery 21G, crush 11G+4G, system.slice 68G); guard VM test (memory-emergency-guard) GREEN |

**Verified already-done by other sessions (stale TODO rows closed with evidence):**

| # | Item | Evidence |
|---|------|----------|
| 5 | btrbk-data marker-gate fast-fail (TODO P0 line 15) | `snapshots.nix:112+` — `btrbk-data-repair-gate` ExecStartPre (local snapshot + retention prune, then deliberate fast-fail while `/data/.repair-done` absent) |
| 6 | CI executes trap-lint derivations (TODO P1.5 line 65) | nix-check.yml "Build trap-lint checks" step builds gatus-pattern-lint, signoz-query-lint, module-shape-lint, chown-vs-bind-audit, binary-coverage-lint + selftest |
| 7 | shellcheck for scripts + binary-coverage lint (TODO P1.5 line 66) | nix-check.yml dedicated shellcheck job (`--severity=error scripts/*.sh .githooks/*`) + binary-coverage checks in CI |

TODO_LIST.md rows updated for all 7 (with annotations; header "Updated:" line NOT touched — see §e).

## b) PARTIALLY DONE

- **`scripts/io-psi-forensics.sh` wiring breadth**: capture fires on guard TRIP action only. The deploy pressure gate (deploy.sh exit-12 branch) and the deploy.sh IO-PSI phantom-vs-real branch do NOT invoke it yet — the TODO's "the moment the guard/gate fires" is half-covered. Deliberate: I didn't want to touch deploy.sh's pressure-gate path in the same pass (it was mid-flight with a parallel session's changes).
- **Boot-generation-freshness**: Gatus check landed; the TODO also mentioned a sev1-side emitter — not wired (notify-tier only via Gatus→Discord; no sev1 bridge entry).
- **Metric presence at deploy**: `system_booted_is_newest_profile` is a NEW metric — the pre-deploy §10 auto-loan should cover it (auto-derived from rendered gatus settings diff), but I did NOT dry-run pre-deploy-check.sh to prove the loan fires. Unverified assumption.

## c) NOT STARTED (from this session's own Pareto list)

- **Paperless scheduled-task failure monitoring + encrypted-tag consistency alert** (TODO P0 line 18) — researched, then deferred: the collector needs Paperless API auth (or PG access as postgres user via a dedicated User= collector unit); table/API surface names could NOT be verified without sudo (the `email_states` fixture-trap doctrine applies — I refused to write a collector against unverified schema names).
- **Textfile-collector fixed-`.tmp` audit sweep** (TODO P0 line 19) — repo-wide enforcement (`audit-textfile-tmp.sh`, pre-commit + CI) already exists per AGENTS; the row's residual is the live check whether the btrfs-compression collector's timer is healthy (needs runtime journal access) — not started.
- **llama.cpp 20260905-era pin-back** (TODO line 54) — RAG still dark; not touched this session (deliberately deprioritized: pin-back needs the ai-stack overlay + a build, heavier than "easy").
- **TODO_LIST "Updated:" header line** — stale (still says 2026-09-13 04:00); I updated rows but not the header.

## d) TOTALLY FUCKED UP (and fixed live)

1. **`?rev=` guard, three attempts to parse**: (a) nested-`builtins.seq` parens — bracket mismatch, syntax error at file tail; fixed by restructuring to a single `allEvalGuards` let-binding. (b) **`input.original` infinite recursion** — reading the resolved-flake `.original` attr inside the flake outputs function recurses (eval died with `infinite recursion encountered`); root-caused to resolved inputs vs lock metadata, switched to pure lock-file JSON introspection (`lockFile.nodes.<key>.original.url`). (c) **Nix `let` binding missing `;`** — `let url = if … else ""` followed by `in` is a syntax error (bindings are semicolon-terminated); confirmed with a minimal `nix-instantiate --eval -E` repro before fixing. Lesson: I wrote Nix from memory without fixture-testing the snippet first — the standalone-repro loop I used AFTER would have caught all three in seconds.
2. **io-psi-forensics: two silent attribution bugs caught ONLY by the live run** — (a) cgroup `io.stat` fields are `key=value` pairs; `t += $i` awk-coerces `rbytes=123` to **0** — every total was zero. (b) `/proc/PID/io` keys carry colons (`read_bytes:`), so `$1 == "read_bytes"` never matched. Both invisible in shellcheck/syntax checks; the non-root live run showed all-zeros and I nearly shipped it. Fixed (split on `=`; match `/^read_bytes:$/`), re-verified with real nonzero data. This is exactly the class the repo's "verify externally / fixture ≠ prod truth" doctrine warns about — the live run IS the fixture test.
3. **Gatus alert wiring typo**: first edit used `alerts = "…"` instead of `alerts = discordAlert "…"` — caught on self-review one edit later, before any eval.
4. **My own grep pipeline lied to me twice**: `nix flake check | grep -c error` returned 2 — the matches were the package NAME `hierarchical-errors`. Verified rc=0 directly afterward. (Repo's own pipeline-masking gotcha, committed by me in the same session that read about it.)

## e) WHAT WE SHOULD IMPROVE (observations from this run)

1. **Nix snippets deserve the same fixture-first discipline as shell scripts.** `nix-instantiate --eval -E '<expr>'` takes seconds; both the paren bug and the `let ;` bug were reproducible standalone on the first try. Rule of thumb: any non-trivial Nix expression I haven't run before → minimal repro BEFORE pasting it into a 1500-line flake.nix.
2. **New metrics need a pre-deploy §10 dry-run**, not the assumption that auto-loan works. The mechanism was built for exactly this (2026-09-14 correction), and I didn't exercise it. Next new-metric change should run `scripts/pre-deploy-check.sh` §10 path explicitly before the real deploy.
3. **Stale-TODO verification BEFORE proposing quick wins**: 4 of 7 "quick wins" I proposed were already done (marker-gate, CI trap-lints, shellcheck + one more). My initial Pareto list burned proposal slots on already-shipped work. A 30-second grep per candidate (which I only did after starting) should precede any "get this done" list.
4. **`readlink -f /nix/var/nix/profiles/system` vs `system-*-link` glob**: my freshness metric compares against the `system` symlink (newest). If the profile symlink is ever the dead-Calamares class again (2026-09-09 forensics), both reads fail → metric 0 → alert — fail-closed by construction, which is the right polarity, but worth knowing the failure mode is "alert", not "silently green".
5. **Foreign-change protocol worked**: formatter reflows in scripts/ (shfmt) and the Z6DEBUG cleanup in tests/ were left untouched and flagged; auto-commit daemon absorbed intermediate states as designed. No action needed — keep doing this.
6. **The 2026-09-14 IO storm is LIVE right now** (capture run: loadavg 70, io PSI some avg10 41.7%/avg60 29.8%): first forensics bundle is already evidence grade — the crush-session-DB P1 item has a real measurement instrument now. Use it BEFORE the hot-DB migration to baseline "before".

## f) NEXT: up to 50 things (ordered, session-relevant first)

**Immediate follow-ups to THIS session's work:**
1. Deploy the accumulated changes (`nix run .#deploy`) — gatus check + metric + guard wiring + audit flip are all deploy-pending; watch §10 auto-loan for `system_booted_is_newest_profile`
2. Verify post-deploy: Gatus "Boot Generation Freshness" green, `system_booted_is_newest_profile 1` in /metrics, `memory_emergency_guard_io_psi_*` present
3. Wire `io-psi-forensics` into deploy.sh's IO-pressure-gate block (the "gate fires" half of the TODO)
4. Add a sev1-bridge emitter for booted≠newest (currently Gatus→Discord only)
5. Baseline forensics BEFORE the crush-DB wave (run `nix run .#io-psi-forensics` 2-3× across a quiet/storm window) — evidence for the hot-DB P1

**The remaining "easy" TODO items I proposed but didn't do:**
6. ~~Paperless failed-tasks collector (needs schema verification path: read deployed paperless PG table names via a root-run query at deploy time, or `User=postgres` collector unit)~~ done (already tracked — TODO_LIST Paperless failed-tasks collector row)
7. btrfs-compression collector timer health check (live journal)
8. llama.cpp pin-back to 20260905-era build (RAG dark; every deploy re-breaks it — pair with item 1's deploy)
9. ~~TODO_LIST header "Updated:" line refresh (2026-09-13 04:00 → stale)~~ done (done — TODO_LIST header refreshed 2026-09-14 18:30 (docs-health pass))
10. Mystery snapshot `data.20260905T2330` root-cause (sudo forensics, P0 line 20)

**From TODO_LIST the session touched peripherally:**
11. io-psi-forensics bundle GC (bundles accumulate in /var/tmp — add tmpfiles age rule or tmp-cleanup exclusion+prune; do NOT let the tmp cleaner eat mid-storm captures)
12. system-health worst-case section sum (P1.5 line 64 — collector structurally can't finish under storm; now measurable with forensics evidence)
13. Known-outage classification in post-deploy-check (P1.5)
14. `backup_ever_succeeded` metric (P1.5)
15. btrbk receive-freshness gauges (P1.5)
16. journald SystemMaxUse cap + journalctl bounds audit (P1.5)
17. Service-completeness manifest audit (P1.5 line 78)
18. `?rev=` guard: consider also linting lock `original.url` in CONSUMERS (subtree nodes at follows-unreachable depth) — guard currently checks ROOT inputs only
19. Add `io-psi-forensics` smoke to post-deploy-check (§13-style: run app, assert bundle lands + nonzero top offender)
20. Guard VM test: add an assertion that the transient forensics unit spawned on trip (I only proved the trip state machine still passes)

**Bigger threads already tracked (unchanged):**
21. Crush session DBs off QLC root (P1) — use new forensics for before/after
22. `services.hot-db` module (Samsung Phase 2)
23. /data corruption repair T04-T08 (P0)
24. Mail Relay go-live (Resend domain verification — USER)
25. CI NIX_GITHUB_RO_TOKEN (USER)
26. Interim-pins cleanup after upstream pushes (USER pushes)
27. InboxClean main re-consent (USER)
28. Miniflux SSO link flow (USER)
29. Offsite Borg leg implementation
30. Hermes PAT go-live (USER)

(30 items — the TODO_LIST itself carries the full backlog; nothing else this session surfaced.)

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Deploy now or batch?** The working tree also carries a parallel session's Z6DEBUG cleanup + shfmt reflows; my changes (gatus check, metric, guard wiring, audit flip, `?rev=` guard) are deploy-pending. Deploy immediately, or wait for the parallel session / a specific window? (The box is in a live IO storm — loadavg 70 at capture time; the deploy pressure gate may block or need `DEPLOY_FORCE_PRESSURE=1`.)
2. **Should the forensics bundles live in /var/tmp?** They survive reboots there (evidence retention) but accumulate (~35KB each — trivial; the concern is unbounded count if the guard trips repeatedly). Prefer /var/tmp + a retention rule, /var/lib/memory-emergency-guard/forensics/ with tmpfiles, or somewhere else (e.g. pool once DAS-stable)?
3. **RAG pin-back urgency:** llama-rag is dark and every deploy restarts it into a 94% CPU spin for ~28 min until re-stopped (2026-09-14 note). Do you want the 20260905-era pin-back attempted in the SAME deploy as item 1, or kept separate so a llama.cpp build failure can't block the monitoring fixes?
