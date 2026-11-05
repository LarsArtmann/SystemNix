# Go-build slowness storm diagnosis — session status report

**Scope.** This report covers ONLY this session's work (2026-11-05, ~19:44–19:50 CET): diagnosing the owner's "why are all my Go builds so hardcore slow" complaint, plus this report itself. VERIFIED live in this session: load average 1248→1292 (19:48→19:50, `uptime`), io PSI some avg10 98.99→99.00 (`/proc/pressure/io`), `/mnt/buildcache` mounted ext4 (`rw,noatime,lazytime,commit=120,data=writeback`, 151G/220G = 73%, 58G free, `findmnt`/`df`), session env `GOCACHE=/mnt/buildcache/go-build` + `GOMODCACHE=/mnt/buildcache/go-mod` + `GOTOOLCHAIN=auto` (`go env`), **8 concurrent `golangci-lint run` processes across 5 repos** and **5 concurrent go linkers** (`pgrep -c -f`, ages 48m/44m/41m/7m/2m for the lint runs; linkers under BOTH `go-1.27.2` and `go-1.27.3` store paths), 6+ `golangci-lint-langserver` instances in the first sweep (eyeballed from `pgrep -af` output — exact count NEVER numerically established, see §d). NOT VERIFIED: any timed build measurement (deliberately skipped — adding a build to a PSI-99 storm feeds the fire), per-cgroup/per-scope IO attribution by my own hand (I inherited the 19:42 report's forensics instead), whether the 5 lint runs are progressing or starved-hung, the state of the 19:42 session's wait-for-calm deploy poller (another session's work — not touched), whether a downloaded toolchain exists in GOMODCACHE (fork inferred from env + `docs/todo/pipeline.md:217`, not probed). NO repo files were edited by this session; the modified files in `git status` (CHANGELOG, TODO_LIST, docs/todo/*, crush-events.nix, home.nix, pre-deploy-check.sh, the 19:42 report) are OTHER sessions' work, flagged per shared-tree discipline and left untouched.

---

## §a FULLY DONE

1. **The diagnosis itself** — the complaint is answered with live evidence: builds are slow because the box is saturated (load ~1250–1292 on 32 cores, io PSI some avg10 ~99%, disk ~101% busy), driven by the agent fleet's own tooling: 8 parallel `golangci-lint` runs across 5 repos (ChastityAPI, index, go-auto-upgrade, go-bilanz, Zlota44) + 5 go linkers, with single lint runs starving for **48+ minutes**. Zero system.slice involvement (inherited from the 19:42 report's per-scope forensics; my process-level evidence corroborates).
2. **Structural multipliers enumerated** (documented repo history + live env): (a) ALL Go caches funnel into ONE USB-bridge SanDisk SSD (`/mnt/buildcache`, ext4 `data=writeback`, no TRIM, autofs layer) — every concurrent session contends on that single disk queue; (b) TWO toolchains live simultaneously (`go-1.27.2` root pin + `go-1.27.3` via the 2026-10-25 `nixpkgs-unstable` follow, both seen linking) — separate cache keys, cross-version builds recompile cold; `GOTOOLCHAIN=auto` can silently fork more; (c) `-race` test builds (one seen live) and per-repo `GOEXPERIMENT` split cache keys (2026-08-15 class: 15,415 duplicate entries/day); (d) gopls defeats Go's 5-day LRU trim — the unbounded go-build cache is only bounded by the 05:00 daily GC (`docs/agents/storage.md:123`).
3. **Cache-redirect health check** — the 2026-11-04 "redirect ALL Go caches to /mnt/buildcache" row is confirmed working in agent shells: `GOCACHE`/`GOMODCACHE` resolve to the mount via both session env and `go env`.
4. **Cross-session context loaded without stepping on it** — the 19:42 deploy-blocker report (§e storm section) was found, read, and used as the corroborating forensics source; its pending storm-gated deploy was explicitly left to its owner; the parallel session's unauthored `home.nix` zed rename was flagged, not touched.
5. **Three recommendations delivered** in-chat: stagger agent sessions; revisit `GOTOOLCHAIN=local`; gate heavy work on io PSI avg10 < 20 (the same gate the 19:42 deploy poller uses).

## §b PARTIALLY DONE

1. **Attribution depth** — repos are named (5), but the owning SESSIONS are not: no `/proc/<pid>/stat` start-time forensics, no per-cgroup `io.pressure` split, no `.crush` DB join (the documented S-0035 probe set, `docs/agents/stability.md`). I stopped at "which repos" instead of "which sessions, since when, whose share".
2. **Storm state** — quantified point-in-time (19:48 and 19:50 probes, worsening: load 1248→1292) but with no drain forecast and no per-cgroup split of "my share vs theirs". The 19:50 re-probe is the report-time state: storm PERSISTS.
3. **Measurement leg** — the diagnosis is inference from saturation evidence (PSI, process counts, documented IO profiles), not a timed build. Deliberate (a probe build in a PSI-99 storm is self-harm), but it means "how slow exactly" and "IO-bound vs CPU-bound" remain unquantified.

## §c NOT STARTED

1. PSI-aware dispatch gate for agent tooling (the open offer that ended the first answer — user pivoted to this report instead of answering).
2. `GOTOOLCHAIN=local` reversal decision/implementation (the `docs/todo/pipeline.md:217` `[watch]` row stays as-is).
3. Any fix implementation — this session was read-only by design.
4. Self-harvest of this report's §f rows into `TODO_LIST.md` + domain libraries — **deliberately not harvested in-session because the owner instructed "DO NOT RESEARCH OTHER STUFF … just report … THEN WAIT FOR INSTRUCTIONS"**; harvest is queued behind the owner's next instruction (per the status-report skill's HARVEST rule, §f remains the input).
5. Buildflow-coverage confirmation: the builtin skill at `crush://skills/buildflow/SKILL.md` failed to load ("Builtin file not found") — unverified whether SystemNix is BuildFlow-covered; moot this session (no lint/format/build commands were run by me), but the load failure is itself a defect worth one retry (§f.7).

## §d TOTALLY FUCKED UP

Nothing this session *broke* — it was read-only. But brutally honest findings:

1. **The system-level "fucked up": the box is one heavy build away from freeze #49.** Freeze ledger #46–48 are <48 h old; load hit 1292 at 19:50 with io PSI pinned at 99%; the fix for this exact class ("stagger resume, PSI-aware dispatch gating") was recommended in the 2026-09-29 report — **five weeks ago — and is still not mechanized**. The direnv/fish cache guards exist (ghost-system-adjacent: real, wired, working — I verified the env), but NOTHING gates lint/build concurrency across agent sessions. The fleet self-DDoS's the one buildcache disk.
2. **My own probe error, recurring class:** the langserver count probe failed (`pgrep -c golangci-lint-langserver` → zero matches: process-name >15 chars needs `-f`) — the documented trap, hit anyway on first use. No false count SHIPPED (I cited only the `pgrep -c -f`-derived 8 lint runs + 5 linkers; the "6+ langservers" figure was explicitly left out), but the first-attempt failure is exactly the quote-scrutiny class AGENTS.md warns about (2026-10-26).
3. **Inherited claim not re-verified:** the "three parallel agent sessions are the driver" attribution is the 19:42 report's forensics. My process-level evidence corroborates it but I did NOT re-run their per-scope probes. Per brutal-self-review Q12: a verdict is a claim, not a fact — corroboration ≠ verification.
4. **Pre-read method was luck-shaped:** I found the 19:42 report via a content grep, not via the prescribed `ls -t docs/status/ | head` live-executor check. Right answer, wrong discipline — a different signature could have missed it.
5. **The builtin buildflow skill failed to load** (`crush://skills/buildflow/SKILL.md` → "Builtin file not found") and I moved on without a retry or a defect note. Recorded here instead.

## §e WHAT WE SHOULD IMPROVE

1. **Mechanize storm-aware dispatch** for agent tooling — a session-start/heavy-command gate on io PSI some avg10 (the deploy poller pattern, extended to lint/build), so staggering is enforced instead of remembered.
2. **Decide the toolchain story once:** `GOTOOLCHAIN=local` (no forks, manual floor bumps) vs `auto` (forks, silent) — the fleet pays the fork cost on every cross-version build while the decision sits in a `[watch]` row.
3. **Converge on ONE nixpkgs go** (drop the 1.27.2/1.27.3 skew when the root pin lifts) — the deliberate 2026-10-25 follow-input pattern has a per-build tax nobody is counting.
4. **Measure, don't infer:** a standing one-command timed-build probe (warm + cold cache, PSI-gated) would turn "feels slow" into numbers.
5. **Bound the lint fleet:** concurrent-run cap and/or shared lint-cache verification across repos (48-minute single lint runs are the user-visible symptom).
6. **Make the pre-read a habit, not luck:** `ls -t docs/status/ | head` + a PSI probe BEFORE any build-adjacent diagnosis (both cost seconds; both were afterthoughts this session).

## §f Up to 50 things we should get done next

Grouped; items 1–8 are this session's direct follow-ups, 9–16 storm containment, 17–26 cache/toolchain hygiene, 27–32 process/docs, 33–50 pointers to already-tracked adjacent rows noticed during this session (pointers only — no re-research done).

**Direct follow-ups of THIS session**

1. Attribute the lint/build waves to owning sessions: S-0035 probe set (`/proc/<pid>/stat` field-22 start times, cwd, per-cgroup `io.pressure`, `.crush` DB join) — turns "5 repos" into "whose sessions".
2. Decide + draft the PSI-aware dispatch gate (tq pool vs BuildFlow vs crush session env — owner question §g.1) and implement where directed.
3. Decide `GOTOOLCHAIN=local` vs `auto` (closes `docs/todo/pipeline.md:217`), implement the winner.
4. Build the PSI-gated timed-build probe (warm + cold) and baseline one small repo when calm — quantify "slow".
5. Establish the exact langserver instance count with `pgrep -f` (close the unverified number).
6. Probe GOMODCACHE for a downloaded toolchain (`golang.org/toolchain…` dirs) — confirm or kill the fork hypothesis with evidence.
7. Retry the buildflow builtin skill load (`crush://skills/buildflow/SKILL.md` failed: "Builtin file not found"); file the defect if it persists.
8. Self-harvest this report's actionable §f rows into `TODO_LIST.md` + `docs/todo/{stability,pipeline,storage}.md` once the owner answers §g (report-only instruction deferred it).

**Storm containment**

9. Verify the 19:42 session's wait-for-calm deploy poller is alive (other session's work — check, don't duplicate; the deploy it gates still carries crush-events chmod, §16 self-heal, flm disable).
10. Owner decision: stagger-by-policy vs enforced gate for agent sessions at PSI > 80 (§g.3).
11. Bound user-session IO: iocost/ioTier-style scoping (or `systemd-run --scope -p IO*=`) for agent-launched builds — system.slice is hardened, user tooling is not (19:42 §e: "the storm is 100% user-session tooling").
12. Cap concurrent `golangci-lint` runs fleet-wide (e.g., max 2; flock or PSI gate wrapper).
13. Verify all 5 storm repos actually hit the shared `GOLANGCI_LINT_CACHE` (per-repo config drift check — cold lint cache would explain 48-minute runs).
14. Restrict `-race` test builds to CI or gated windows (cache-key split + runtime cost, one seen live).
15. Fleet `GOEXPERIMENT` audit — per-repo flag drift forks cache keys 2x (2026-08-15 class, `CHANGELOG.md:1526`).
16. Surface freeze risk NOW: ledger #46–48 <48 h old + load 1292 — the heavy-builds-at-load doctrine says this is how freeze #49 happens (done in-chat; stands as a report row until the storm drains).

**Cache / toolchain hygiene**

17. Drop go-1.27.2 consumers when the root nixpkgs pin lifts to ≥1.27.3 — kill the dual-toolchain cache-key tax.
18. Audit go.mod floors across the 5 storm repos — floors above the pinned toolchain are what force forks.
19. Model buildcache refill vs the 05:00 daily GC: 73% now (58G free); the ec-hub 54G refill row (`docs/todo/storage.md:178`) is still open.
20. Compliance-check the 2026-11-04 agent-cache convention (direnv `_bf_agent_cache_guard`): did all 5 storm repos inherit buildcache env, or did any fall back to `/tmp`/`~/.cache`?
21. Verify no `~/.cache/go-build` regrowth (the 10-02 + 11-03 triage rows, `docs/todo/storage.md:88`/`:219`).
22. After the storm: re-probe the `direnv-smart-lib` dead-mount guard for D-state misfires at PSI 99 (`docs/todo/stability.md:297` `[watch]` row) — a false "dead mount" redirect silently lands builds on cold `/tmp` caches.
23. Count gopls instances per repo; consider LSP consolidation (gopls defeats Go's LRU trim, `docs/agents/storage.md:123`).
24. Evaluate `go clean -cache` policy vs GC-timer tuning for the gopls-unbounded cache.
25. Verify the 5 storm linkers used the `go-build-memlimit`/ioTier wrapper pattern (or confirm user-session linkers are unwired — candidate for §11's gate).
26. Codify a "build storm runbook" in `docs/agents/stability.md`: symptom → probe set → containment (S-0035 exists; a runbook wrapper does not).

**Process / docs**

27. Make `ls -t docs/status/ | head` the MANDATORY first step of any pasted-error/symptom session (this session got the right report by grep luck).
28. Apply the quote-scrutiny rule to process counts: `pgrep -c -f`, never eyeballed `-af` output (2026-10-26 rule; §d.2 is the live example).
29. Merge the 19:42 §e storm attribution + this session's process-level evidence into ONE incident note (two partial diagnosis docs = split-brain risk).
30. CHANGELOG entry when (and only when) a fix lands from this diagnosis — nothing yet.
31. Add the `pgrep >15-char name needs -f` one-liner to the AGENTS.md live-probe set if not already present (it is adjacent to, but distinct from, the redact-argv note).
32. Get owner answers to §g (below) — three decisions block the top follow-ups.

**Pointers to already-tracked adjacent rows (noticed this session, not re-researched)**

33. `docs/todo/pipeline.md:217` — GOTOOLCHAIN fork watch (decision pending; see §f.3).
34. `docs/todo/stability.md:297` — buildcache "dead mount" misfire under storm (re-probe when calm; §f.22).
35. `docs/todo/storage.md:178` — ec-hub 54G refill source (buildcache capacity).
36. `docs/todo/storage.md:219` — `~/.cache` regrowth triage (purge wave 1 done; wave 2 pending decision).
37. `docs/todo/services.md:285` — /tmp cleaner vs foreign-owned go-build chunks (ENOSPC class).
38. `docs/todo/upstream.md:95` — why BuildFlow minted `gobuild`/`gocache`/`gomod` fallback names.
39. 19:42 §e — the deferred deploy + its poller (other session's pending work; leave).
40. 19:42 §c — GitHub Actions billing block (owner action, already tracked at TODO_LIST 495).
41. Timed per-repo `golangci-lint` baseline when calm — separate "inherently slow repo" from "storm-starved".
42. Investigate whether the lint-langserver fleet duplicates the lint runs' work (double compile pay).
43. Consider a fleet "build window" convention (no builds during deploy batteries — the 2026-10-25 deploy-vs-executor class).
44. Wrap ad-hoc agent go builds in the existing `go-build-memlimit`/ioTier transient-scope pattern (exists for services; user-session ad-hoc runs are unwired).
45. Verify the direnv guard actually fired in the 5 storm repos (did they inherit session env, or launch env-less?).
46. Post-storm: the 19:42 deploy's post-switch battery (§f.2 of that report) re-run when calm.
47. Freeze-counter probe for this boot (trip counts so far — context for the §f.16 risk claim).
48. Capacity policy for `/mnt/buildcache/agent-caches` (sub-question of the 11-04 redirect row).
49. Consider `GOMAXPROCS` pacing for lint under load (CPU starvation at load 1292 makes lint thrash, not just wait).
50. Re-verify every number in this report post-storm — all figures are point-in-time 19:48–19:50 snapshots.

## §g Questions I can NOT figure out myself

1. **Do you want the PSI-aware dispatch gate built — and where?** tq pool entry gate, BuildFlow step gating, or the crush session env (refuse heavy commands above a PSI threshold)? I can design/implement any of the three; which one owns the policy is a product decision only you can make.
2. **`GOTOOLCHAIN`: back to `local`, or stay `auto`?** Local stops the silent cache-fork tax but re-imposes manual floor bumps on every go.mod raise (the 2026-09-29 pin removal was deliberate — what problem were you solving that I'd be re-introducing?).
3. **Are the 5 storm repos' lint waves sanctioned, and may I intervene?** ChastityAPI, index, go-auto-upgrade, go-bilanz, Zlota44 all have live lint runs (up to 48 min old) from parallel agent sessions. Staggering them means touching OTHER sessions' work — per shared-tree discipline that's your call, not mine: pause them, let them drain, or leave the fleet alone and accept the storm?

---

## Evidence appendix (point-in-time)

| Time | Probe | Result |
| --- | --- | --- |
| 19:48 | `uptime` | load 1248.12, up 16:31, 36 users |
| 19:48 | `/proc/pressure/io` | some avg10=98.99 avg60=98.91; full avg10=69.37 |
| 19:48 | `findmnt /mnt/buildcache` | systemd-1 autofs → `/dev/sdb1` ext4 `rw,noatime,lazytime,commit=120,data=writeback` |
| 19:48 | `df -h /mnt/buildcache` | 220G total, 151G used, 58G avail (73%) |
| 19:48 | `go env` | GOCACHE=/mnt/buildcache/go-build; GOMODCACHE=/mnt/buildcache/go-mod; GOTOOLCHAIN=auto |
| 19:48 | `pgrep -c -f 'golangci-lint run'` | 8 |
| 19:48 | `pgrep -c -f 'go/pkg/tool.*link'` | 5 (store paths: go-1.27.2 AND go-1.27.3) |
| 19:48 | lint run ages (`ps etimes`) | ChastityAPI 48m, index 44m, go-auto-upgrade 41m, go-bilanz 7m, Zlota44 2m |
| 19:48 | `pgrep -c golangci-lint-langserver` | FAILED (name >15 chars; needs `-f`) — exact count unestablished |
| 19:50 | `uptime` + PSI | load 1291.96; io PSI some avg10=99.00 — storm persists/worsening |

**Sources:** live probes as tabled; `docs/status/2026-11-05_19-42_deploy-blocker-fixes-storm-gated-deploy-status.md` §e (inherited forensics, flagged as such); `docs/agents/go-ecosystem.md` (routing pre-read); `docs/agents/storage.md:111-125` (buildcache doctrine); `docs/todo/pipeline.md:217` (GOTOOLCHAIN watch); `docs/agents/stability.md` (freeze ledger, S-0035 probe set); `CHANGELOG.md:1526-1560` (cache-key fork + wrapper history). Prior series context: `docs/status/2026-09-29_23-14_autofs-recovery-deployed-journal-hot-gap-io-storm.md` (the 5-week-old stagger/PSI-gating recommendation, §f.56/§23).
