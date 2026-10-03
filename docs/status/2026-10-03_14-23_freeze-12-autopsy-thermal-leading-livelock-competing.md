# Freeze #12 autopsy — THERMAL LEADING (99 °C live at load 20, no build running), IO-livelock competing; taxonomy had already reached #11

**Supersedes `2026-10-03_14-23_freeze-8-autopsy-io-livelock-deploy-train-storm.md`** (v1, swept by the auto-commit daemon as `0c0892eb` before its freeze numbering was found wrong — see §d.6). One incident, one report; v1's numbering and mechanism-prior are corrected here, evidence carried over.

**Session scope:** single-question session ("Why did we crash this time?") + this report. Diagnosis of the Sat 2026-10-03 14:14:05 hard cutoff of boot -1 (ran Oct 02 10:59 → Oct 03 14:14, 27 h). No tree changes, no deploys, no service actions — read-only forensics, then this report (plus the mandated TODO harvest).

**Verdict — freeze #12, TWO candidate mechanisms, thermal leading:**

- **Leading: THERMAL TRIP (the #8/#9/#11 lineage).** Freezes #8/#9 (Oct 01, Tctl 95–100 °C) and #11 (Oct 02 10:57, instant cut at 91 °C after riding 98.4–99.1 °C) are documented in `docs/status/2026-10-02_11-10_freeze-11-thermal-ceiling-instant-cut-forensics.md` — the taxonomy the series ACTUALLY ended at (stability.md itself still ends at #7; the entry-writing row is queued there). #11's discriminator — *sub-ms-healthy final journal lines = instant cut, NOT progressive collapse* — matches today's terminal pattern (final journal lines are ordinary service traffic, cut mid-message). Today's driver class is #11's exact driver: ~27 h of continuous heavy compile (clickhouse -j8 + a --cores 32 fallback, ~35 GB per attempt, three attempts).
- **Competing: IO-livelock (the #3/#4/#5/#6/#7 lineage).** Two-day Zone-6 I/O PSI storm (guard trips #1680→#1769, avg60 40–65 %), genuine memory cliff (zram at its full 62 GiB, MemAvailable 20 %, 10.8 M major faults, morning OOM cascade), death-rattle writeback stall >121 s (`db.test:2442531`, 14:13:25) — but house precedent says livelock terminals are PROGRESSIVE collapses, not instant cuts.
- **LIVE FINDING (harvest phase, 14:26):** `Tctl 99.1 °C` + `acpitz 98.0 °C` (two independent sensors agreeing) at load avg ~20, PPT 112.7 W, amdgpu edge 50 °C, **zero fan telemetry in `sensors`** — with NO build running. The cooling deficit is STANDING, not load-transient. This makes thermal the leading hypothesis for #12 and plausibly the single physical condition under #8/#9/#11 as well — and it means the box may be minutes from **freeze #13** the moment anything heavy launches.
- **Undiscriminated without:** pstore read (root), the boot -1 thermal series 10:00→14:14 (ClickHouse samples_v4 fingerprint-scan method from the #11 forensics), and the user's answer on manual-reset vs self-reboot.

**Build freeze recommendation:** NO attempt #5, no `nix flake check`, no heavy compile until the cooling question is physically answered (§g.2). Every prior "relaunch the deploy train" plan from the 12:01 report is now gated on this.

---

## a) FULLY DONE (this session, verified)

1. **Boot cutoff + discriminators established.** `--list-boots`: boot -1 ended 14:14:05, boot 0 began 14:15:36 (91 s gap). Final 80 journal lines are ordinary service traffic — zero shutdown/Stopping records → hard cutoff. Sub-ms-healthy-then-cut matches the #11 thermal discriminator (also consistent with livelock terminal; not by itself discriminating).
2. **Death timeline reconstructed from journal evidence.** Morning OOM cascade 10:44–10:49 (niri `oom-kill`, running clickhouse daemon, gcr-ssh-agent, a user-975 systemd — `CONSTRAINT_NONE` global kills; already queued by the 07-49 session as "Triage the 10-03 10:42 kernel-OOM cascade"). Hermes ledger: `mem_available_kib: 0`, zram swap 62 GiB used (full capacity). 14:07:24 memcg OOM killed an 8.3 GB `nix` inside `tq-agent-pool.service` (kernel dump: `pgmajfault 10828710`, pswpin/pswpout 10.7 M/13.5 M pages). 14:13:25 kernel writeback-stall warning (`db.test:2442531` >121 s; same signature Oct 02 11:25). 14:14:05 journal cut mid-message.
3. **Guard behavior for the whole siege documented.** Zone 6 tripped every ~10 min across two days, trips #1680→#1769; FLM sacrificed repeatedly, restore capped 3/day by midday (SEV1 "MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" every ~90 s at the end). Guard blindness generation 3: the sacrifice list cannot touch the actual drivers (nix builds, tq pool, gopls). NOTE: 38 guard trips also accompanied thermal freeze #11 — guard-trip count alone is NOT a livelock discriminator.
4. **Post-crash filesystem integrity verified.** BTRFS bdev error counters identical pre/post crash (boot -1 vs boot 0 mounts: corrupt 12 / 1 / 386583438 on the three btrfs devices, modulo the documented nvme0/nvme1 flip) → **zero new corrupt events from the hard cutoff**. (This was freeze-11 protocol row 15, never run for #11 — now done for #12.)
5. **Live boot-0 state checked.** Memory healthy (92 GiB available, swap 4 MiB). Zone 6 re-tripped post-crash (trip #1770, 14:18:04, avg60 57.74 %) — storm residual. Freeze-6 recovery readers clean (crush-hot-db-migrate: 3 projects relocated; discordsync-db-heal: integrity passed, both by 14:16:39).
6. **Current IO storm attributed.** `sdb` (USB SanDisk buildcache) at 100 % util; per-PID 6-second read deltas: two `gopls` (two Crush sessions, `~/projects/DiscordSync`) pulling a combined 280 MB/s via `GOMODCACHE=/mnt/buildcache/go-mod` (deliberate design, storage.md §Build Cache SSD). System iowait 40 %.
7. **Live THERMAL state probed (post-v1):** Tctl 99.1 °C / acpitz 98.0 °C at load ~20, PPT 112.7 W, amdgpu edge 50 °C, **no fan RPM telemetry exposed** (`sensors` shows no fan chips) — see Verdict.
8. **Deploy-train impact assessed.** Both toplevel builds died with the freeze; `/tmp/toplevel-*.log` gone (tmpfs). Boot 0 `init=r6fcay8x…` = gen 813 → the fixed `nix-build-cleanup` is NOT live; old killer-timer logic still owns the fire windows. Attempt #5 now double-gated (cooling + storm).
9. **Boot-mirror first-reboot verification (passive, closes half of a standing row).** This crash reboot was the mirror's first since activation (2026-09-30). `boot-mirror-sync: OK — 17 entries, 325M mirrored` at 14:16:05; bootctl updated the mirror ESP. Survived the freeze. (The `BootCurrent`/`LoaderDevicePartUUID` decode half of the storage row remains open.)
10. **Crash-autopsy capability gap identified:** freezes #3–#12 all paid the same manual forensics tax; no `crash-autopsy.sh` exists (§f.9).

## b) PARTIALLY DONE

1. **The autopsy (~85 %).** Missing: pstore (root); boot -1 thermal series (would likely SETTLE thermal-vs-livelock for #12); per-device disk saturation at death (guard logs give only "max disk busy 99–100 %" — which device(s) unverified; candidates: QLC root p6, Samsung /nix p2, clickhouse XFS p9, USB buildcache).
2. **`db.test` identity.** Pattern-matched to a Go `db`-package test binary (Go `<pkg>.test` naming; adjacent to the 14:07 tq nix build). PID→cmdline unrecoverable post-reboot. Hypothesis, not verified (§d.4).
3. **Post-crash fallout inventory (noticed, not diagnosed).** `gitea-runner-evo-x2.service` crash-looping since 14:17 (`forgejo-gen-runner-token` exit 1 every ~63 s → forgejo-side readiness/DB post-crash); `service-health-check.service` failed exactly once at 14:18:09, coincident with the runner loop start (same root, folds into the runner item). Queued §f.11.
4. **flm socket state.** Capped 3/3 since midday boot -1; the 07-49 session's "SEV1 triage … live or latched stale" queue row covers the check; not re-verified in boot 0 by me.

## c) NOT STARTED

1. **stability.md freeze entries #8–#12** — taxonomy ends at #7; the queued row covers #8–#11, extends to #12 (§f.4).
2. **Thermal-vs-livelock discrimination for #12** (pstore + thermal series) — §f.2/§f.3.
3. **Physical cooling inspection** — owner hands (§g.2); agent side (fan-telemetry gap → monitoring row §f.8) queued.
4. **`scripts/crash-autopsy.sh`** — §f.9.
5. **Build-IO gating** (Zone-6 blindness gen 3) — existing "IO admission for tq pool" row, annotated with #12 evidence (§f.10).
6. **Toplevel attempt #5** — now cooling-gated first, storm-gated second (§g.2).
7. **gitea-runner recovery** — §f.11.

## d) TOTALLY FUCKED UP (nothing hidden)

1. **Answered the freeze question WITHOUT reading the routing docs first.** Ran the whole v1 autopsy on journal spelunking alone; told the user "With `softlockup_panic=1` the kernel likely panicked itself" — stability.md:25 documents the opposite for the livelock family (panic machinery armed #3–#7, NEVER fired; livelocks end in manual resets). Mechanism speculation delivered unhedged.
2. **Recommended "move GOMODCACHE off the USB disk (spare sdc or Samsung hot tier)" without reading storage.md.** Buildcache placement is a deliberate documented design (2026-08-14, consumers, HM symlinks, recovery stack) and sdc is EARMARKED for the 2-device btrfs merge (2026-09-22 decision). Confident recommendation, wrong premise.
3. **Evidence-class overclaims in the verbal answer.** "every disk pinned ~100 %" (one max-disk-busy number, per-device state unverified); "the disk was saturated by … " framed as settled. The claim outran the surface actually probed — the AGENTS.md correction-rule sin in miniature.
4. **`db.test` identity stated as fact** — pattern inference only.
5. **Wasted round trips on sloppy commands:** `sudo` attempt (harness-blocked — should be known), then a journalctl regex with an unescaped paren. Zero impact on the verdict.
6. **Numbered the crash "#8" from a stale taxonomy — and the error flipped the mechanism prior.** stability.md ends at freeze #7, so I anchored there; the series had ACTUALLY reached #11 (2026-10-02 forensics report; the queue rows say so plainly). The last three freezes (#8/#9/#11) were THERMAL with an instant-cut discriminator that matches today's terminal pattern at least as well as livelock — and I read the stability doc but not the newest forensics report or the library rows until the HARVEST phase. Consequence: v1 led with "IO-livelock, the documented crash #3 class" when the most recent crash lineage pointed at thermal — and the 99 °C live finding that reframed everything only surfaced because the harvest made me re-read the queue.
7. **Never probed temperature during a crash autopsy whose most recent siblings were thermal.** One `sensors` call was always one tool away; it would have shown the standing cooling deficit BEFORE I delivered a livelock-rooted answer. It took the harvest phase to run it.
8. **Ended the diagnosis session with "worth queueing…" and queued nothing** — the self-harvest-at-authoring rule exists for exactly this (discharged with this report; overlaps with rows the 07-49/10-02 sessions already queued are annotated, not duplicated).

## e) WHAT WE SHOULD IMPROVE

1. **Incident-routing discipline, full depth:** for ANY freeze question, read stability.md AND the newest freeze-forensics status report AND the stability library's queue rows — the freeze SERIES, its numbering, and the latest discriminator set live across all three; any one alone is stale (stability.md's #7 ending cost me four numbers and the thermal prior).
2. **Thermal is now a first-class leg of EVERY crash autopsy** — one `sensors` call (Tctl, acpitz, PPT, fans) goes into the standard procedure, before any journal archaeology; the #8/#9/#11 lineage made it mandatory and I still skipped it.
3. **Codify the autopsy:** `scripts/crash-autopsy.sh <boot>` — boot gaps, journal-cut discriminator, guard trip tail + FREEZE-SERIES LOOKUP (reads the taxonomy so numbering is never stale), OOM/writeback scan, `sensors` snapshot, per-PID read deltas, btrfs counter delta, boot-0 health sweep; ends in a verdict line naming open discriminators. Freezes #3–#12 all paid this tax manually.
4. **Zone 6 blindness generation 3 — fix is build-side, not guard-side** (stopping nix mid-build IS the killer this repo just fixed): PSI-entry gating for build launches (deploy.sh's gate extended to detached attempts and tq dispatch), `IOAccounting`/`IOMax` on the pool, serialization on a busy box. The existing "IO admission" row owns this; annotated with #12.
5. **gopls cold-load duplication:** every Crush session spawns its own gopls against the same projects over the single USB link (280 MB/s from two observed). Cheapest: single LSP per project or post-boot `go mod download` pre-warm. Structural: the 2-device buildcache merge doubles throughput headroom.
6. **Claim hygiene:** "is" vs "looks like" — pattern identities and mechanism hypotheses must be labeled in the ANSWER, not only in the later report.
7. **Post-freeze settle window covers agent sessions:** boot 0 had recovery readers clean, but two sessions immediately cold-loaded gopls into the residual storm (Zone 6 re-tripped 3 min post-boot). After any freeze: no new heavy-IO sessions until Zone 6 quiet N minutes — AND no heavy CPU until `sensors` reads sane (new, from #12).

## f) Next (session-derived, ranked — actual: 14)

1. **[URGENT, owner] Physical cooling inspection — Tctl 99 °C at load ~20 with NO build running, zero fan telemetry in `sensors`.** Dust/fans/paste/vents. Until answered: no attempt #5, no flake check, no heavy compile (freeze #13 bait at the current ceiling).
2. **pstore read (root shell): `ls -la /sys/fs/pstore/`** — panic-vs-manual-reset discriminator for #12; folds into the existing "[blocked:user] Pstore post-#11 read + EFI retention" row (extend to #12; note a prior session made the same permission-swallowing mistake I did — the row already warns about it).
3. **Boot -1 thermal series 10:00→14:14** (ClickHouse samples_v4 fingerprint-scan method from the #11 forensics) — likely SETTLES thermal-vs-livelock for #12; also pulls load-average correlation.
4. **Extend the "Write the missing freeze #8–#11 entries into stability.md" row to #8–#12** — same ask, now five entries; #12's draft material is this report's Verdict + §a.
5. **k10temp Gatus check + fan-telemetry gap** (the #11 "thermal ceiling policy" decision row's option (b), now near-mandatory): Tctl ≥ 95 °C sustained pages; investigate why no fan RPM is exposed (hwmon config? EC?) — a box that keeps thermalling with silent fans cannot be agent-monitored for its #1 failure mode → `docs/todo/monitoring.md`.
6. **stability.md freeze-#12 section + discriminators note** (thermal-vs-livelock families BOTH documented with their discriminator sets — instant-cut vs progressive-collapse — so the next autopsy starts from the fork, not from zero) → `docs/todo/stability.md`.
7. **Relaunch toplevel attempt #5 — COOLING-GATED then storm-gated** (order inverted by the live finding); log to `/var/tmp`, never `/tmp` (tmpfs ate attempts #1–4's logs).
8. **Deploy the fixed nix-build-cleanup** (rides attempt #5) — killer logic old until then.
9. **`scripts/crash-autopsy.sh`** (§e.3 — includes the sensors leg and freeze-series lookup).
10. **Annotate the "IO admission for tq pool" row with #12** (done at harvest — third data point: 27 h clickhouse train + gopls storm through one USB link + QLC).
11. **gitea-runner-evo-x2 crash-loop** (`forgejo-gen-runner-token` exit 1 every ~63 s since 14:17; service-health-check 14:18 folds in) → `docs/todo/services.md`.
12. **hermes config.yaml duplicate key `provider`** (line 476/477, edge vs zai — YAML warning every cycle) → `docs/todo/services.md`.
13. **Zone-6 trip-RATE alert** (trips/hour sustained — #12 ran 90+ trips over 2 days with zero trend alert; also accompanied thermal #11, so rate-alert ≠ livelock-specific but still storm-signal) → `docs/todo/monitoring.md`.
14. **buildcache 2-device btrfs merge priority elevation** (queued in storage; #12's storm floor ran through the single USB link at 100 %) — annotated at harvest.

Not re-queued (already owned by earlier harvests, verified during this session's harvest): flm/SEV1 live-vs-latched triage (07-49 row), the 10-03 10:42 OOM-cascade triage (07-49 row), system_health.prom `\x2d` escaping + canary + blind-window (monitoring rows), deploy battery / FEATURES / CHANGELOG paperless legs (12:01 report §f, all deploy-gated).

## g) Questions I can NOT figure out myself (max 3)

1. **Did you hard-reset the box at ~14:14, or did it come back on its own?** A self-reboot would be a new terminal mechanism for the series; a manual reset is consistent with both the livelock and thermal families. (Complementary root-shell check: `ls -la /sys/fs/pstore/` — §f.2.)
2. **The box is at Tctl 99 °C right now at load ~20 with nothing building, and `sensors` exposes no fan RPM.** Has the cooling been physically checked recently (dust/fans/paste), and do you hear the fans actually spinning? Until this is answered I recommend a hard freeze on ALL heavy builds (attempt #5 included) — confirm or overrule.
3. **Fan telemetry is invisible to tooling on this box — is there a known reason (EC not exposed, needs `nct6775`/vendor module)?** If the fans are spinning but unreadable, monitoring can only watch Tctl; if they are NOT spinning, this is the root of freezes #8–#12 and a hardware fix closes the whole family.

---

*Report v2 written 2026-10-03 ~14:28 CEST, superseding v1 (daemon commit 0c0892eb — mis-numbered #8, livelock-only prior). Evidence: journalctl boots f4bacc7a…/f8808e36…, guard trips #1680–#1770, kernel OOM dump 14:07:24, writeback stall 14:13:25, per-PID /proc IO deltas, `sensors` live at 14:26 (k10temp 99.1 °C / acpitz 98.0 °C / PPT 112.7 W), stability.md + storage.md routing docs, `docs/status/2026-10-02_11-10_freeze-11-thermal-ceiling-instant-cut-forensics.md` (freeze numbering + thermal lineage + instant-cut discriminator + fingerprint-scan method), stability/monitoring/services library rows (harvest-phase reads).*
