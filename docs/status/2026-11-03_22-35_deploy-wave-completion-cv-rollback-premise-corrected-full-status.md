# Deploy Wave Completion + cv Rollback (Premise Corrected Same-Day) — Full Status

**Scope:** VERIFIED first-hand this session: the gen-974 anchor and its first-boot service states (busctl, 16:18–16:30), the cv panic-loop journals across three boots, the cv rev-pin rollback execution + float-register proof (rc=0, log `~/.cache/lockfloat/float-proof-20261103-164712.log`), gen-976's deployed cv unit (ExecStart store path read directly), the browser-history pin-lift closure surfaces, two boot-evidence pulls + the pre-vacuum gate flip (refused → pass), the gatus endpoint count eval (255) and the live `/api/doctor` 200, and the FOD direct-probe false-green trap (recorded in `docs/agents/nix-flakes.md`). NOT verified: the §10 phantom-metric mass-fail root mechanism (probe target read only partially — storm-shaped, unconfirmed), the tq-agent-pool brake outcome (a `sudo systemctl stop` was in flight at 22:22; the unit still ran at 22:26), and anything after 22:26. Heavy reliance on parallel-session work is EXPLICITLY attributed below (the 21:15 cv-attribution session and the freeze-45 stability session corrected and extended my conclusions; their reports are the authoritative versions of those threads).

## a) FULLY DONE

1. **The interrupted 2026-11-02 deploy run is completed and anchored.** gen-974 (dnc9swbbk) activated 16:0x on boot deed9c84 and, after two further silent stops, gen-975 → gen-976 followed via the evening sessions; current anchor **gen-976 (6nz9id10) == system-976-link** (readlink-verified 22:2x). The float set from the 21:03 lock (11 inputs incl. browser-history f941a1e, cv, dnsblockd, media-atlas, dms-shell 2.1-beta, papdashboard c0b29a36, golangci 072921f1) is live.
2. **cv rolled back to 16a656f4 and deployed** — the rev-pin (flake.nix `&rev=16a656f4…` + pin-audit allowlist row + vendorHash bPvMOBEz + expected-locks registry) proved rc=0 and gen-976 runs the `cv-16a656f` binary (store-path verified). NOTE: the rollback's ORIGINAL causal claim is retracted — see (d)1; the pin survives only as build-hash stability per the evening session's retraction.
3. **browser-history pin-lift closed end-to-end** — doctor series on origin, pin + allowlist row dropped (17:0x yesterday), re-locked (this wave), deployed, and `docs/todo/upstream.md:241` ticked with the landing evidence. Registry check `/api/doctor` answers 200 live; endpoint count still **255** (eval-verified — no README re-stamp needed).
4. **Two silent-stop boots pulled before vacuum** — `db565285` (2026-11-02 22:07) + `deed9c84` (2026-11-03 16:16) evidence files committed; pre-vacuum gate flipped **refused → pass**; stability triage row harvested (`docs/todo/stability.md`). The stability session subsequently registered **freeze #45** (commit 9ef607479: 7th consecutive WDT reset, Nov 2-3 cluster, storm driver = tq-agent-pool unindexed full-table sqlite LIKE scans against crush.db at 409 MB/s + k10temp 98 °C).
5. **papdashboard vendorHash re-stale landed** (20a329e → c0b29a36: spec mi1+rwiO, got unmyEeVV, first-hand keep-going ×2) — build green in gen-976.
6. **The FOD direct-probe false-green trap is mechanized** — `docs/agents/nix-flakes.md` now documents that `nix build <drv>.drv` can rc=0 against an already-registered CA realisation while the toplevel proof rejects the same drv; only the flake-attr toplevel proof is truth (2026-11-02 21:38 incident).
7. **gitea-runner convergence validated on the new boot** — stopped by the gen-974 switch 16:10:02, ensure-timer converged it 16:14:03 and again post-boot 16:23:03 (v13.2.0, poller launched); the battery's "cycle breaker" FAIL was a dead-window sample, third occurrence of the known tolerance class.

## b) PARTIALLY DONE

1. **Post-deploy battery for gen-976 never completed green.** My 16:11 run sampled the pre-boot window (6 FAILs), the 16:26 rerun died at 2 min (shell reaping), the 17:0x run was the deploy app's own and BLOCKED on 63 §-fails (≈60 phantom-metric absences during the SigNoz/clickhouse storm window + the PSI gate), and two further attempts died to flock/git-128 contention. Metrics were verified healthy at the exporter (`:9400`, all five sample metrics present) — the mass-fail coheres with a storm-dead REMOTE query path, but the §10 mechanism is unconfirmed. TODO_LIST:1844 (evening session) queues the single calm-window full pass — correct ownership; I deliberately did not duplicate it under PSI 85-91.
2. **The tq-agent-pool storm brake** — a `sudo systemctl stop tq-agent-pool.service` was observed in flight (22:22) but the unit still ran at 22:26 and PSI held 85-91. Owner decision row on the pool brake options was queued by the freeze-45 session; execution is pending.

## c) NOT STARTED

1. Upstream CV issue filing (nil-guard + chunked rehydration) — gated on verify-before-filing + owner; the full fix-shape row already exists (`docs/todo/upstream.md:245`, blocked:push).
2. quotaboard float (b2a34902 → c98d13ad) sits staged in the tree — another session's in-flight float procedure, deliberately untouched.

## d) TOTALLY FUCKED UP

1. **I rolled back cv on an under-verified premise and shipped a wrong causal claim into three surfaces.** The 16:4x rollback justified the 16a656f4 pin with "80c2c88 panic-loops; 16a656f4 proven green for 18 h on deed9c84". Both halves were wrong or lucky: (a) the panic is REV-INDEPENDENT — the evening session found the first SIGSEGV on 2026-11-02 14:06 on cv@aa878d2, restart counter already 17, 228 SIGSEGVs across deed9c84 itself (I had read the death-window tail, saw crm-sync WARNs and no panic lines, and concluded "green" — a tail is not a census); (b) root cause is `pipeline_events` outgrowing the 5 s `sqliteOperationTimeout` on full-scan `All()` — boot rehydration deterministically fails under (and beyond) the crush.db storm, the chatstore lazy service stays nil, and the samber/do healthcheck probe nil-derefs. My pin happened to be harmless (build-hash stability) but the rationale I wrote into flake.nix + pin-audit + cv.nix was false. The 21:15 session retracted all three surfaces properly, filed the real fix-shape upstream row, and left the pin standing with the corrected justification. Lesson I already owed from yesterday's report ("counts ≠ identities") one level deeper: **a clean journal tail is not a boot census — grep the whole boot for the failure signature before declaring a rev "proven green"**; and a rollback pin justified by a non-reproducible failure is a coin flip, not a fix.
2. **My background shells kept dying to tool-interruption reaps, killing three deploy attempts and one battery mid-flight** — including one death mid-activation (21:58 Nov 2-era window) that left the system running gen-973 units with a half-applied switch for 18 h until the next boot. The setsid detach fixed the reaping but then hit flock/git-128 contention instead. The deploys need a re-entrant, session-independent runner pattern; my ad-hoc setsid + per-attempt logs worked but cost five attempts for one landing.
3. **I nearly overwrote the sibling's better retraction** — my 22:3x flake.nix edit was prepared from a stale read (their 21:17 retraction had already landed); the edit tool's mtime guard caught it. The pre-edit content-pin discipline saved the correction; it should have been my FIRST step, not the tool's.

## e) WHAT WE SHOULD IMPROVE

1. **Deploy under my agent harness needs a survives-session-death runner** (systemd-run --user scope or a tq-dispatched deploy): flock-serialised, logs to /var/log/systemnix-deploys, immune to agent-shell reaping. The freeze-cluster makes mid-activation deaths non-theoretical — a half-applied switch on a box that WDT-resets within the hour is the unanchored-boot generator.
2. **The pre-deploy phantom-metric §10 should distinguish "exporter dark" from "remote query path dark"** — one exporter-scrape probe (all-or-nothing at :9400) before the per-metric check would have turned 60 fails into 1 actionable fail + 60 skips, and prevented tonight's misread.
3. **"Proven green for N hours" claims require a boot-wide census**, not a tail read: `journalctl -b … | rg -c 'SIGSEGV|panic'` belongs in the pin-ritual evidence template (the 21:15 session's 228-SIGSEGV census is the model).
4. **The lock-float registry can be committed UNPROVEN by the daemon sweep** (fb0f7fd0a carried browser-history + crush-daily floats mid-deploy): the float procedure's "commit lock+registry together AFTER the proof" is unenforceable against the auto-commit daemon. A pre-commit guard keyed on `expected-locks.nix` + a missing same-commit proof-log reference would close it (same shape as the TODO-gate legs).
5. **The cv events table (~300 MB read per crash cycle) needs compaction/chunked rehydration upstream** — the current design re-reads everything on every boot, so any IO storm converts into a restart loop.

## f) Top things to get done next

1. Owner: pick the tq-agent-pool brake (freeze-45 decision row) — the crash cluster is owner-input-gated, 7 WDT resets in 30 h.
2. Calm-window full post-deploy battery on gen-976 (queued: TODO_LIST:1844) — closes the §10 question and re-baselines the 7-fail set.
3. cv upstream: nil-guard + chunked rehydration fix (`upstream.md:245`, blocked:push) — then lift the 16a656f4 pin via the ritual.
4. Land the quotaboard float proof its session staged (in-flight, tree has lock+registry staged).
5. §10 probe-disambiguation improvement (e.2) as a pre-deploy-check leg.
6. Boot-census evidence template (e.3) folded into `boot-evidence-pull.sh` output.
7. Daemon-sweep guard for unproven lock+registry commits (e.4).
8. cv events-table compaction upstream (e.5, folds into #3's fix shape).
9. Watch `browser-history` @3ee89742 + `crush-daily` @07cf5ca4 (committed unproven by the sweep): both ran inside gen-975/976 builds — confirm their units' journals stay clean on gen-976, else pin per ritual.
10. The three unpulled-boot guard continues to pass — keep the pull-on-refusal reflex; journal vacuum clock read 7.7G/8G at 16:2x.

## g) Questions I can NOT figure out myself

1. **Was tonight's 21:42:58 WDT crash (#7 in the cluster) preceded by the tq brake landing?** The freeze-45 commit says the driver is the tq-agent harvest; I saw a stop command in flight at 22:22 but the unit still ran. If the pool respawns faster than it can be stopped, the brake decision (owner row) is the only lever — is the intended remedy "stop the pool" or "fix the harvest query"?
2. **Should the 16a656f4 pin be lifted immediately?** The evening session kept it for build-hash stability; floating it re-exposes the FOD re-stale churn (thirteen re-stales in two weeks) for zero behavioral gain while the crash-loop persists. I kept it — confirm.
3. **Is gen-976 the intended head?** gen-975 → gen-976 were deployed by evening sessions under storm with batteries incomplete; if the owner wants a clean calm-window deploy of the same tree with a full battery, say the word and I (or the next session) run it when PSI < 20.
