# Go-cache advisory + mid-session boot reset observation — session status report

> **[2026-11-06 merge note]** canonical incident narrative: [2026-11-05_go-build-storm-freeze-49-incident-note.md](./2026-11-05_go-build-storm-freeze-49-incident-note.md) — this report remains the advisory + boot-reset detail record.

**Scope.** Third report of this session's arc (2026-11-05, ~19:44–21:43 CET; predecessors: `2026-11-05_19-50_go-build-slowness-storm-diagnosis-status.md`, the in-chat storm diagnosis). Covers: the storm diagnosis, the owner's "how can we improve the go cache speed" advisory, and this report. VERIFIED live: the box **REBOOTED mid-session** — previous boot `5819f35ddbd34e58b5c9697df1313f04` ran 03:16:27→20:36:40 and ended with **no shutdown sequence** (journal tail at 20:36:40 is ordinary crm-server request logs, zero "Stopping…" markers), new boot `7c876ae078…` began 20:39:20 (2m40s gap — the abrupt-cut + gap signature, `journalctl --list-boots` + `-b -1 -n 8`); at 21:43: load 47, io PSI avg10 60.27 (avg60 74.32 — the NEW boot is already busy), `GOLANGCI_LINT_CACHE=/mnt/buildcache/golangci-lint` confirmed live, `/mnt/buildcache/go-build` = **96G** (`du -sh` — corrects my tmpfs-dismissal figure, see §d). Earlier windows verified: 20:09 storm-drain probes (load 22.64, PSI avg10 42.29 — from 1292/99% at 19:50). Also verified by file reads with line cites: home.nix cache machinery (L400-485: expand/probe/redirect chain, HM out-of-store symlinks incl. `.cache/go-build` → buildcache, gopls deliberately NVMe-local L456, /tmp tmpfs fallback L424-436), buildcache.nix GC (L595-650: daily 05:00, 45-min TimeoutStartSec, "metadata-bound on a DRAM-less USB SSD"), storage.md:66/92-93 (the owner-gated hot-tier `[decision]` rows + HM-symlink gating `[ready]` row). NOT VERIFIED: WHY the boot died (freeze-triage attribution is the stability protocol's job — I recorded the boot id, not an autopsy); whether the 20:36 death is a ledger freeze (owner reset vs unattended crash unknowable to me — §g.3); the benchmark I offered (never run); the HM-symlink hot-tier claim (design analysis, not a tested eval — §d); lint-fleet end-state at boot death (didn't re-pgrep before it died); the 03:05→03:13 8-minute boot cycle earlier today (noticed in `--list-boots` output, not investigated). NO repo files edited by this session — still zero-edit; all modified tree files remain other sessions' work.

---

## §a FULLY DONE

1. **Storm diagnosis closed with live evidence** (19:48–19:50): load 1248→1292, io PSI ~99%, 8 concurrent `golangci-lint` runs across 5 repos + 5 linkers under two toolchains, 48-min starved lint runs; structural multipliers enumerated (single DRAM-less USB-SSD cache, dual-toolchain cache-key fork, `GOTOOLCHAIN=auto`, `GOEXPERIMENT`/`-race` splits, gopls trim-defeat).
2. **The cache-speed advisory delivered** (second user question): ranked levers — (1) relocate GOCACHE/GOMODCACHE/GOLANGCI_LINT_CACHE to Samsung hot tier `/mnt/hot` (NVMe QD1 randwrite 79k IOPS/12.2µs vs the module's own "DRAM-less USB SSD" admission; keeps the off-QLC doctrine intact via doctrine-C subvols; kills the autofs corpse-pile misfire class as a side effect), (2) kill cache-key forks (single toolchain, GOTOOLCHAIN decision, GOEXPERIMENT unification, `-race` windows), (3) cap fleet concurrency; dismissed-by-category: QLC return, tmpfs GOCACHE, gopls-on-USB, Nix-FOD caching.
3. **Grounding reads, exact-cited**: home.nix L400-485 (the redirect/symlink/fallback machinery — all three Go caches confirmed buildcache-bound), buildcache.nix L595-650 (GC cadence + the DRAM-less quote), storage.md:66/92-93 (the relocation idea is ALREADY a `[decision]` row with the known blocker documented — the advisory converged on the repo's own pending decision rather than inventing a new one).
4. **Skill compliance**: how-to-golang loaded per mandate before the performance question — content turned out to be code/library policy (cache choice, validation, bans), NOT box-level build-cache infra; no governing material missed. Mismatch noted for §e.
5. **Storm-drain verified** (20:09): load 1292→22.6, PSI 99→42% — proving the contention diagnosis (same cache, ~60x load swing).
6. **Two status reports written** (19:50 + this), zero tree edits, shared-tree discipline held throughout.

## §b PARTIALLY DONE

1. **The reboot observation** — classified to the signature level (abrupt end, no shutdown markers, 2m40s gap, full 32-hex boot id captured for `-b`) but NOT attributed: no trip-counter continuity check, no boot-evidence pull, no ledger cross-reference. The stability protocol (S-0035 + `scripts/boot-evidence-pull.sh`, full-id `-b` per the 2026-10-18 trap note) owns the rest; deliberately not started (report-only instruction).
2. **Hot-tier migration feasibility** — analysis done (autofs-in-autofs trap argued NOT to apply to a fstab-mounted tier), but the claim is untested: no `extendModules` throwaway eval (the sanctioned safe-verification pattern) was run to prove an HM out-of-store symlink into `/mnt/hot` doesn't reproduce the 2026-09-20 mount-unit-naming failure.
3. **Tenant sizing** — go-build measured (96G) this window; the other 55G of mount tenants (pnpm/playwright/agent-caches/rust/go-mod…) un-sized.
4. **Lint-fleet hygiene** — `GOLANGCI_LINT_CACHE` location verified live; the concurrency cap / fast-only lint / shared-cache-hit verification not started.
5. **The benchmark offer** — PSI-gated rationale held at 19:50 (99%), but by 20:09 (42%) and 21:43 (60% on the new boot) it was runnable and wasn't. Offer ≠ execution.

## §c NOT STARTED

1. Everything gated on §g: hot-tier ratification, GOTOOLCHAIN decision, PSI-gate product decision, reboot intent (§g.3).
2. The full §f list of the 19:50 report — carried open (see §f tier 2), plus its self-harvest (still deliberately deferred: owner's standing report-only instruction; both reports' §f remain HARVEST input).
3. Freeze-ledger entry/triage for boot `5819f35d` (stability domain, other protocol's ownership).
4. Any repo edit — the session remains read-only by design.

## §d TOTALLY FUCKED UP

1. **The 19:50 warning appears to have been bait taken.** I wrote: freeze ledger #46–48 <48h old + load 1292 = "the freeze-#49 recipe". The boot died at 20:36:40 — 46 minutes later, under the predicted conditions (though causation is unattributed: the lint fleet may have drained before death; the 20:09 probes showed it draining). If triage confirms a freeze, that is at minimum freeze-#13/#33-family recurrence with my warning on record 46 minutes prior. The system-level fuck-up is unchanged: the 5-week-old stagger/PSI-gating recommendation is STILL not mechanized.
2. **My tmpfs dismissal cited the wrong number.** I wrote "151G doesn't fit sustainably in 128G RAM" — 151G is the WHOLE mount (all tenants); the relevant figure was go-build's own size, then unmeasured. Now measured: **96G** — the conclusion (tmpfs GOCACHE non-viable on this box) survives, but the shipped number was mount-total, not go-build-total. That is precisely the 2026-10-26 quote-scrutiny class ("the number must survive one known-value check before it enters a report"). Caught and corrected here.
3. **The hot-tier autofs claim is shipped as analysis, not proof.** If the HM out-of-store-symlink-into-fstab-mount shape does reproduce the 2026-09-20 six-unit activation-batch failure, ratifying on my say-so would burn a deploy cycle. The `extendModules` throwaway eval exists precisely for this and wasn't run.
4. **Two §f lists now exist across two reports in one session** — duplicate-row risk for docs-health HARVEST unless tier-2 items are recognized as carried, not new. Flagged here explicitly.
5. **Still uncorrected from the 19:50 report:** exact golangci-lint-langserver count (pgrep >15-char trap) — carried open, §f tier 2.

## §e WHAT WE SHOULD IMPROVE

1. **Mechanize the PSI gate** — the storm drained at 20:09 and the boot still died at 20:36; drain windows are not safety. Enforced gating (§g.1) beats waiting.
2. **Verify-before-recommending**: a design claim that gates an owner decision (hot-tier move) gets the `extendModules` eval BEFORE the ask, not after ratification.
3. **Number hygiene**: measure the specific tenant (96G go-build), cite the specific tenant — one `du` would have saved §d.2.
4. **Execute cheap probes when they become runnable** (the benchmark was runnable at 20:09 and offered instead of run).
5. **Skill trigger descriptions**: how-to-golang's description ("Go performance") pulled it for a box-level build-cache question it doesn't own — a one-line description scoping note for the skill-creator backlog would prevent future false-positive loads.
6. **Session-spanning reboot awareness**: the session outlived the boot; every earlier probe number was pre-reboot state. Point-in-time means point-in-BOOT — new boot, re-probe before building on old numbers.

## §f Up to 50 things we should get done next

**Tier 1 — new this window (cache advisory + reboot)**

1. Route boot `5819f35ddbd34e58b5c9697df1313f04` (ended 20:36:40, no shutdown markers, 2m40s gap) into the freeze-triage protocol: full-id `-b` evidence pull, trip-counter continuity, ledger decision (freeze #49 candidate vs owner reset).
2. Also notice boot `-2` (`30b6b4cb…`, 03:05:44→03:13:47 — an 8-minute boot) followed 3 minutes later by boot `-1`: two resets before 03:16 today, unexamined.
3. Owner ruling on the reboot (§g.3): deliberate hard reset vs unattended crash — determines ledger entry and whether containment work is URGENT or deferred.
4. `extendModules` throwaway eval: HM out-of-store symlink `~/.cache/go-build` → `/mnt/hot/go-build` (fstab-mounted parent) — prove the 2026-09-20 mount-unit-naming failure does NOT recur, before asking for ratification.
5. PSI-gated benchmark: `/mnt/buildcache` (ext4 USB) vs `/mnt/hot` file (BTRFS NVMe) using the `bench-disk.sh` methodology + `vmtouch -e` cold-cache probes — numbers for the §g.1 decision.
6. Size the remaining buildcache tenants (`du` per child: go-mod, golangci-lint, pnpm-store, playwright, agent-caches, rust) — migration planning + the GC model.
7. Draft the hot-tier migration plan on the caddy-logs-hot pattern: `+C` subvols on the Samsung toplevel, PSI-gated rsync BEFORE the deploy carrying the mounts, HM symlink flip + env repoint in home.nix, buildcache-gc coverage split decision (storage.md:66's own sub-question).
8. Design the HM-symlink mount-state gating (storage.md:93 `[ready]` row) — needed for ANY relocation, not just the hot tier.
9. golangci-lint fast-only mode for agent/IDE contexts (full lint stays in CI); measure the delta on one storm repo.
10. Verify all repos share-hit `GOLANGCI_LINT_CACHE` (per-repo config drift check) — cold lint cache would explain 48-minute runs.

**Tier 2 — carried open from the 19:50 report (HARVEST: recognize as carried, not new)**

11. S-0035 session attribution of lint/build waves (`/proc` forensics + `.crush` DB join) — pre-reboot fleet, partially moot (processes died with the boot), but the method run belongs in the triage of §f.1.
12. PSI-aware dispatch gate: decide + implement (tq pool vs BuildFlow vs crush session env).
13. GOTOOLCHAIN `local` vs `auto` decision (pipeline.md:217).
14. PSI-gated timed-build probe (warm + cold) — quantify "slow" on the NEW boot.
15. Exact golangci-lint-langserver count via `pgrep -f`.
16. GOMODCACHE toolchain-download probe (fork evidence).
17. ~~Retry the buildflow builtin skill load (crush:// "Builtin file not found"); file the defect.~~ **NOT-DO — buildflow is a USER skill at ~/.agents/skills/buildflow (loads fine); crush:// is the BUILTIN namespace and correctly 404s a non-builtin; no config carries the wrong path (rg-verified 2026-11-06) — wrong-namespace assumption from the 19-50 report, not a Crush defect.**
18. Self-harvest BOTH reports' §f into TODO_LIST + domain libraries once the owner lifts the report-only instruction.
19. Verify the 19:42 session's deploy poller survived the reboot — the deferred deploy it gated (crush-events chmod, §16 self-heal, flm disable) is presumably STILL pending on the new boot.
20. Re-check whether the §16 icons realize + other in-tree fixes rode ANY deploy before the reset (tree was never deployed as of 19:42; the reboot changed nothing about that).
21. Stagger-by-policy vs enforced gate ruling for agent sessions at PSI > 80.
22. User-session IO bounding (iocost/ioTier-style scopes for agent builds) — system.slice is hardened, user tooling is not (19:42 §e).
23. Cap concurrent `golangci-lint` runs fleet-wide.
24. Restrict `-race` builds to CI/gated windows.
25. Fleet `GOEXPERIMENT` audit (2x cache-key fork class).
26. Surface freeze risk standing row until containment exists (§d.1).
27. Drop go-1.27.2 consumers when the root pin lifts (dual-toolchain tax).
28. go.mod floor audit across the fleet's storm repos.
29. Model buildcache refill vs daily GC (73% pre-reboot; re-check post-reboot; ec-hub 54G row open).
30. Post-reboot compliance check of the agent-cache convention (direnv guard) in the 5 storm repos.
31. Verify no `~/.cache/go-build` regrowth (storage.md:88/:219 rows).
32. Post-storm/post-reboot re-probe of the dead-mount guard's D-state misfire behavior (stability.md:297).
33. gopls instance count + LSP consolidation study.
34. `go clean -cache` policy vs GC-timer tuning for the gopls-unbounded cache.
35. Verify linker wrapper usage (go-build-memlimit/ioTier) for user-session linkers.
36. Codify the build-storm runbook in stability.md (symptom → probes → containment).
37. Make `ls -t docs/status/ | head` + PSI probe the mandatory pre-read for build-adjacent sessions.
38. `pgrep -c -f` discipline (quote-scrutiny rule application note).
39. Merge the 19:42 §e storm attribution + the 19:50 diagnosis + this report's reboot observation into ONE incident note (three partial docs = split-brain risk).
40. CHANGELOG entries when fixes land (none yet).
41. AGENTS.md live-probe set: add the `pgrep >15-char name needs -f` one-liner if absent.
42. Owner answers to §g (three decisions block the top of this list).

**Tier 3 — pointers to already-tracked rows (noticed, not re-researched)**

43. pipeline.md:217 — GOTOOLCHAIN fork watch.
44. stability.md:297 — buildcache "dead mount" misfire under storm.
45. storage.md:66 — SSD-2 tenant decision (the hot-tier `[decision]`, §g.1).
46. storage.md:92-93 — hot-user-caches relocation + HM-symlink gating design rows.
47. storage.md:178 — ec-hub 54G refill source.
48. storage.md:219 — `~/.cache` regrowth triage.
49. services.md:285 — /tmp cleaner vs foreign-owned go-build chunks.
50. upstream.md:95 — BuildFlow's gobuild/gocache/gomod fallback-name root cause.

## §g Questions I can NOT figure out myself

1. **Ratify the Samsung hot-tier relocation (storage.md:66)?** If yes, do you want the §f.4 `extendModules` proof + §f.5 benchmark FIRST, or do you ratify on the analysis and accept the design risk?
2. **`GOTOOLCHAIN`: back to `local` or stay `auto`?** (Carried from the 19:50 report; still the fork-tax decision.)
3. **Was the 20:36 reset yours?** Deliberate hard reset (freeze-#33 pattern) or unattended crash — I cannot know if a human was at the console, and it decides whether boot `5819f35d` enters the freeze ledger and how urgent containment (§f.1/§f.12) is.

---

## Evidence appendix (point-in-time)

| Time | Probe | Result |
| --- | --- | --- |
| 19:48–19:50 | (pre-reboot) uptime/PSI/pgrep | load 1248→1292; io PSI some avg10 98.99→99.00; 8 lint runs / 5 repos / 5 linkers; details in the 19:50 report appendix |
| 20:09 | uptime, PSI | load 22.64 (1min avg), PSI some avg10 42.29 — storm drained |
| 20:09 | file reads | home.nix:400-485; buildcache.nix:560-650 |
| 21:43 | `date` | 21:43:47 CET |
| 21:43 | uptime | **up 1:04 — REBOOTED**; load 47.43, PSI some avg10 60.27 avg60 74.32 (new boot busy) |
| 21:43 | `journalctl --list-boots` | `-2` 30b6b4cb… 03:05:44→03:13:47 (8 min); `-1` 5819f35d… 03:16:27→**20:36:40**; `0` 7c876ae0… 20:39:20→ |
| 21:43 | `journalctl -b -1 -n 8` | tail = ordinary crm-server INFO logs at 20:36:40, NO shutdown markers |
| 21:43 | `echo $GOLANGCI_LINT_CACHE` | `/mnt/buildcache/golangci-lint` |
| 21:43 | `du -sh /mnt/buildcache/go-build` | **96G** (corrects the 151G mount-total figure used in the tmpfs dismissal) |

**Sources:** live probes as tabled; `docs/status/2026-11-05_19-50_go-build-slowness-storm-diagnosis-status.md` (predecessor report, §f tier-2 carrier); `docs/status/2026-11-05_19-42_deploy-blocker-fixes-storm-gated-deploy-status.md` §e (inherited forensics); `platforms/nixos/users/home.nix:400-485`; `modules/nixos/services/buildcache.nix:595-650`; `docs/agents/storage.md:66,92-93,111-125`; `docs/todo/pipeline.md:217`; `docs/agents/stability.md` (freeze ledger, S-0035, boot-evidence discipline incl. the full-id `-b` trap).

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** DONE f.1-4 f.7 f.26 f.37 f.39 f.40 · already-tracked f.6 f.8 f.12 f.13 f.19 f.20 f.23 f.29-32 f.43-50 · OBSOLETE f.17 f.18 f.42 · NEW rowed: 16 rows (merged f.5+22-27 §f.12+01-08 §f.18, f.9+47, f.10+48, f.11+21, f.14+46, f.15+44, f.16+45, f.24+19, f.25+16+18, f.27+17, f.28+15, f.33+34+14, f.36+22, f.38+41) → pipeline 8, stability 4, storage 1, upstream 2, desktop 1
