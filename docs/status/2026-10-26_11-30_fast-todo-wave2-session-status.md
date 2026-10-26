# Fast-TODO Wave 2 — Deploy-Blocker Execution: §18 Gate, Quiescence Productization, Migrate-State Forensics

**Report:** 2026-10-26 ~12:00 CET · **Session run:** 2026-10-26 ~10:44 → ~12:00 · single agent (crush) · evo-x2 working tree · **HEAD at start:** `739334737`
**Trigger:** owner directive: execute the whole TODO list, Pareto-first, ≤12-min tasks, table report. Wave-1 close-out left the deploy-blocker lane (T6–T11 of `2026-10-26_09-11_SUPERB-fast-todo-wave1.md`) as the top agent-executable tier; three parallel sessions own the QLC space crisis (`10-33` plan), the caddy gen950 verification (`10-46` report), and the tmp hot-tier migration (E6).
**Concurrency:** 17+ live crush sessions; `TODO_LIST.md`, `pipeline.md`, `monitoring.md`, `flake.nix`, `selftests.nix`, `modules/*` parallel-dirty throughout. All commits below went through a TEMP GIT_INDEX so the shared index's foreign staged entries (`journal-serve.nix` staged mid-session by the tmp-migration session) stayed untouched; shared TODO files committed with explicit attribution.

---

## a) FULLY DONE

| # | What | Evidence | Files/surfaces |
|---|------|----------|----------------|
| a1 | **P1 plan** — wave-2 comprehensive plan w/ ALL-TODOs coverage map (11 surfaces, ~3,264 open rows, disposition each), ≤12-min task table, EXECUTING tombstone | commit `14e14330c` | `docs/planning/2026-10-26_10-55_SUPERB-fast-todo-wave2-execution.md` |
| a2 | **P2 deploy-gate friction map — with a material correction**: §8 disk space is BYTE-based (FAIL <5G, WARN <15G), so at 14G free tomorrow's E6 deploy only WARNs on disk; the binding gates are PSI/zram/mem. The `block <10%` figure in the 07-09 report's a4 is MemAvailable, not disk | plan §5 | same plan file |
| a3 | **P3 `.migrate-state` forensics SOLVED**: the state dir EXISTS at `/mnt/hot/hot/.migrate-state/` (`HOT_PARENT="$TOPLEVEL/hot"`, migrate-hot-db.sh:58-62) — the storage row's `/mnt/hot/.migrate-state/` path was wrong. Waves 1-5 have full markers (discordsync 10-12 15:46 · gatus + browser-history 10-14 15:07 · pocket-id 10-14 18:45 · dnsblockd 10-14 21:52, each FILES/BYTES/BIG_SIZE/BIG_PATH/STAMP); **wave 6 (postgres) has NO marker = the "Prepared + cut over" config comment was claim-only**, the exact fabricated-closeout class | marker files read live 11:0x, stamps `date -d @` decoded | inventory table below; storage.md:14 ticked |
| a4 | **P4 §18 shadow-split gate LANDED (the wave's data-loss-class item)** — `scripts/shadow-split-gate.sh` + pre-deploy §18 + `--section-18-only`; FAILs the wave-6 signature (data-class empty subvol over non-empty shadow), PG_VERSION presence parity, parity-band + EACCES WARNs; verdict-callback pattern per §15's delegation shape | commit `3187b86bd`; shellcheck green; flake check green | `scripts/shadow-split-gate.sh`, `scripts/test-predeploy-shadow-split.sh`, `scripts/pre-deploy-check.sh` |
| a5 | **§18 fixtures 19/19 green** — every verdict branch including the `/mnt/hot/hot/<name>` hot-parent prefix | `bash scripts/test-predeploy-shadow-split.sh` → "all shadow-split gate fixtures green (19 cases)" | test script |
| a6 | **§18 live run matches reality**: 5 entries pass (cache/nix prepared-copy shape holds; discordsync/dnsblockd/pocket-id/postgres all populated at `/mnt/hot/hot/<name>` — postgres = the recovered 780M cluster), 3 WARNs = true state (cache/tmp half-provisioned MID-E6 (the parallel session's migration is genuinely not prepared yet — the gate is its entry-guard), browser-history + gatus `/var/lib/private/*` degraded without sudo ticket) | `--section-18-only` run 11:4x | live system |
| a7 | **P5 deploy-when-quiescent productized** — `scripts/lib/eval-relevant-paths.sh` (the shared definition, flake.lock included) + `scripts/deploy-when-quiescent.sh`: 4×60s clean+cold polls, green-eval pre-gate (`nix eval --raw`, NO --no-link), default DRY WOULD-FIRE, `--fire` classifies rc=1 (§11-void/eval signature = exit 3 expected-race; anything else stops for review); per-run output grep (the log accumulates — grepping it would classify the LAST watcher's race as this one's) | commit (this batch); syntax + live dry runs | `scripts/deploy-when-quiescent.sh`, `scripts/lib/eval-relevant-paths.sh` |
| a8 | **Watcher live-negative-tested**: refuses the current 33-entry dirty tree; stability-counter reset paths logged | watcher dry runs 11:49 | same |
| a9 | **Queue/library ticks** — 3 queue rows + 2 storage rows ticked with DONE notes (gate, forensics, quiescent productization); close-out-discipline row annotated (blocked by dirty docs/agents/storage.md, not forgotten); `check-todo-system.sh` → "OK: TODO queue/library structure clean" | this batch | `TODO_LIST.md`, `docs/todo/storage.md` |
| a10 | **AGENTS.md quote-scrutiny rule landed** (07-09 §f.12's do-on-sight): analysis one-liners get one known-value sanity check before their numbers enter a report | this batch | `AGENTS.md` (Session Discipline) |

### P3 inventory (the deliverable the forensics row asked for)

| wave | service | state marker | stamp (decoded) | landing commit | verdict |
|---|---|---|---|---|---|
| 1 | gatus | YES (`FILES=3 BYTES=19940064`) | 2026-10-14 15:07:40 | `c398729e3` (heuristic daemon commit) | evidence-complete |
| 2 | dnsblockd | YES (`BYTES=4823594355`) | 2026-10-14 21:52:33 (the hard-down night window; dir mtime matches) | `6efafec6c` (proper message) | evidence-complete |
| 3 | pocket-id | YES (`BYTES=5314305`) | 2026-10-14 18:45:44 | `a5edaede8` (heuristic) | evidence-complete |
| 4 | browser-history | YES (`BYTES=204124160`) | 2026-10-14 15:07:44 (combined window w/ gatus) | `c398729e3` | evidence-complete |
| 5 | discordsync | YES (`BYTES=5744992552`) | 2026-10-12 15:46:21 (out-of-order wave) | `aa889dcae` (heuristic) | evidence-complete |
| 6 | postgres | **NO MARKER** | — | `9e902add2` (heuristic) | **claim-only — the fabricated closeout**; the marker system was live and used by every honest wave within 5 days before, so its absence is evidence of absence, not of an older toolchain |

## b) PARTIALLY DONE / DEFERRED (each with the exact unblock)

1. **pipeline.md:579 twin tick for the quiescent script** — pipeline.md parallel-dirty (33-entry tree). Land when quiescent. Wave-1's 4 twins (rows 648/1386/1419/1491) equally pending on the same file.
2. **§18 selftest → flake check wiring** — selftests.nix parallel-dirty; wire `predeploy-shadow-split-selftest` when quiescent (queued below).
3. **§11's tree-stamp adoption of `eval-relevant-paths.sh`** — vendor-freshness.sh is deploy-battle-tested; the 3-line swap gets its own commit + a §11-only probe verify, not a rider (queued below).
4. **docs/agents/storage.md close-out discipline line** — file parallel-dirty; row annotated in place.
5. **Watcher WOULD-FIRE end-to-end** — needs a quiescent moment (tree never went clean this session); gates A/B/C each proven individually (A live-negative, B/C form-verified). First real fire = the proof.

## c) NOT STARTED (deliberately, with owner)

The four owner gates: wave-1 Q1/Q2 (overcommit posture; hermes config), crisis-plan gates (wevisone-spike, cross-repo consent, balance 06:48 deviation), tonight 23:00 balance redo (T1). Storm load-shed policy. Deploy itself.

## d) TOTALLY FUCKED UP (all self-caught, none shipped broken)

1. **My §18 gate carried THREE premise failures the fixtures + live run caught pre-commit**: `nix eval --raw` on a BOOLEAN enable flag errors ("cannot coerce a Boolean to a string: true") which my `|| echo null` silently converted into "no enabled entries" — the exact phantom-green class the gate exists to kill; the user-caches option is `.caches` not `.entries`; and the hot-db subvol root is `/mnt/hot/hot/<name>` not `/mnt/hot/<name>` — the SAME path error the storage row itself made. The live §18-only run (which showed entries + honest verdicts) is the proof the final form works; the interim wrong forms never committed.
2. **Permission-shaped absence**: `dir_size` reported root-owned 700 shadows as "absent" (→ PASS) instead of "unknown" (→ WARN) because `-d` fails on unreadable parents. Fixed via parent-readability probe; fixture case added implicitly through live verification (browser-history/gatus now WARN honestly).
3. **Shared-index commit trap**: my first plan commit inherited the shared index's foreign staged `journal-serve.nix` and died on ITS statix finding. Fixed with the temp-index pattern for every commit this session. Cost: ~10 min, no damage (foreign staging preserved byte-exact).
4. **House subject-limit hook tripped twice** (96 then 77 chars > 72) — amend/retry, no force, no bypass.

## e) WHAT WE SHOULD IMPROVE

1. **Fixture-first for gates that read live config**: writing the fixtures BEFORE the live wiring would have caught the raw-bool and option-name bugs at fixture time instead of at first live run (they were caught at first live run, still pre-commit — but only because I ran the live probe).
2. **`git status --porcelain` in a pre-commit wrapper** could warn when the staged tree contains files the committing session never touched (the co-mingling class) — the temp-index pattern works but is tribal knowledge; a `scripts/commit-solo.sh` wrapper would productize it.
3. **§-gate selftests should auto-wire**: the "fixture script lands now, flake-check leg later" gap is a silent-coverage window; a check that greps scripts/test-*.sh for a matching selftests.nix leg would close it (queued).

## f) TOP NEXT THINGS (harvest disposition explicit)

1. **Wire `predeploy-shadow-split-selftest` into selftests.nix** (runs `scripts/test-predeploy-shadow-split.sh`) — High, S, Quality. → HARVESTED (queue row below; library twin pipeline.md pending quiescence — noted in row).
2. **Adopt `scripts/lib/eval-relevant-paths.sh` in §11's vendor-freshness tree-stamp** (kill the second copy of the list) — Medium, S, Cleanup. → HARVESTED (queue row below, same twin caveat).
3. **pipeline.md twin ticks (quiescent-script row + these two)** — Medium, S, Process. → deliberately NOT re-queued as new rows: they are the deferred half of EXISTING rows, tracked in §b.1.
4. **§-gate selftest coverage check** (e.3) — Low, S, Tooling. → HARVESTED (queue row below).
5. **First real `deploy-when-quiescent.sh --fire`** — rides the E6 deploy window (crisis plan T2); not a separate row (the E6 runbook step should name it — noted in §b.5).

## g) QUESTIONS I CANNOT ANSWER MYSELF

None new. Standing: wave-1 Q1/Q2, crisis-plan §5 gates. One observation offered free of charge: §18's live WARN on `cache/tmp` (shadow 479k files, subvol missing) IS the E6 prepare-pending state — when the tmp-migration session runs its prepare, the WARN flips PASS; the gate is its independent progress light.

---

**Harvest rows landed this report (TODO_LIST.md; library twins pending pipeline.md quiescence, noted inline):**

- [ ] [ready] **Wire `predeploy-shadow-split-selftest` into flake/parts/checks/selftests.nix** (leg runs `bash scripts/test-predeploy-shadow-split.sh`, 19-case fixture of the §18 gate) — deferred because selftests.nix is parallel-dirty as of authoring (Source: this report §b.2)
- [ ] [ready] **Adopt scripts/lib/eval-relevant-paths.sh as §11's tree-stamp source in scripts/lib/vendor-freshness.sh** (one shared eval-relevant definition; own commit + `--section-11-only` verify) (Source: this report §b.3)
- [ ] [ready] **Add a check that every scripts/test-*.sh fixture has a matching selftests.nix leg** (closes the fixture-lands-now/flake-leg-later silent-coverage gap) (Source: this report §e.3)

**Handoff note:** §18 gate + quiescent watcher + forensics inventory are complete and verified; the remaining session obligations are the quiescence-gated ticks/wirings in §b — none block the crisis plan's T1 (tonight 23:00) or T2 (E6 deploy, which §18 now guards as its entry gate).
