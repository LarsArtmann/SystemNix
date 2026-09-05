# Status Report: VRAM Carveout BIOS Fix + TTM pages_limit Code Verification

**Date:** 2026-09-05 13:57 · **Host:** evo-x2 (boot 13:16, kernel 7.2.2) · **Scope:** this session only

---

## Context

User noticed the GPU panel showing `VRAM 557/32768 MiB, GTT 1534/96058 MiB` after BIOS changes (UMA Frame Buffer → 1 GB → Auto; it had silently been 32 GB). Session evolved through four phases: (1) diagnose the Auto state, (2) verify the user's 1 GiB reboot, (3) defend or retract my "safety margin" claim against user challenge — resolved by reading the **running kernel's source**, (4) verification + memory updates.

---

## a) FULLY DONE

| # | What | Evidence |
|---|------|----------|
| 1 | **Diagnosed "Auto" = full 32 GiB carveout.** Verified live on boot 12:54: MemTotal 93.8 GiB, VRAM total 32768 MiB, `amdgpu.ttm.pages_limit=31457280` active in `/proc/cmdline`, zram 46.9 GiB. Told user: BIOS-only setting, must be explicit, never Auto. | `/proc/meminfo`, `who -b`, `/proc/cmdline` |
| 2 | **Verified the 1 GiB-carveout reboot (boot 13:16).** MemTotal 124.3 GiB (**+30.5 GiB recovered**), VRAM 1024 MiB total / 909 used (~89% — in use, not wasted), GTT 2.6 GiB / 122880 MiB, zram auto-scaled to 62.2 GiB (50%). Verdict delivered: no meaningful waste; no further BIOS trips needed. | sysfs `mem_info_*`, `/sys/block/zram0/disksize` |
| 3 | **Code-verified `ttm.pages_limit` mechanics against the RUNNING kernel 7.2.2** (not torvalds master): default = **totalram/2** (`ttm_device.c:96`); enforcement = **soft eviction loop** — forced `ttm_global_swapout` while over limit, then the allocation **proceeds anyway** when nothing is evictable (`ttm_tt.c:388-397`); amdgpu sets the **GTT domain size = pages_limit, clamped to physical RAM on APUs** (`amdgpu_ttm.c:2156-2173`). This explains both observed GTT totals: min(120G, 124.3G) = 122880 MiB now; min(120G, 93.8G) = 96058 MiB on the 32 GiB boot. | Source extracted from `/nix/store/bnh3b93d…-linux-7.2.2.tar.xz` → `/tmp/k7src/`, live `/sys/module/ttm/parameters/pages_limit` = 31457280 |
| 4 | **Retracted the "safety margin" framing with evidence.** Verdict: half-BS — the number is real (GTT accounting ceiling below physical RAM → clean driver-OOM for ROCm/KFD clients) but it is not a hard cap, reserves nothing, and the kernel's own default is the conservative RAM/2. Box's real protections: per-service MemoryMax, memory-emergency-guard, zram. `pages_limit` has never fired in any incident here. | Code citations above |
| 5 | **AGENTS.md updated (GPU section, line 917)** — three edits: (i) "Auto" = 32 GiB trap with boot-12:54 evidence; (ii) carveout is now 1 GiB (user-set); (iii) code-verified mechanics with file:line refs. Edits verified landed; tree already clean (auto-commit daemon). | `grep` verification, `git status` clean at 13:57 |
| 6 | **Verified `page_pool_size` live = 6291456 pages = exactly 24 GiB** — the AGENTS.md "MUST stay 24 GiB" invariant is now evidence-backed, not just doc narrative. | `/sys/module/ttm/parameters/page_pool_size` |

## b) PARTIALLY DONE

| # | Item | Done | Missing | Effort |
|---|------|------|---------|--------|
| 1 | Doc consistency after carveout change | Main GPU section updated to 1 GiB / 124.3 GiB | **AGENTS.md ZRAM section still says "512 MiB VRAM carveout … ~125 GiB"** — stale reference missed by the edit sweep | S |
| 2 | Session documentation in repo memory | AGENTS.md carries the full findings | No `CHANGELOG.md` entry for the 2026-09-05 GPU findings (repo convention) | S |
| 3 | VRAM usage understanding | Verified 909/1024 MiB is *in use* (not waste) | **What** fills it (scanout vs DRI buffers) unverified — needs root `amdgpu_gem_info` | S |

## c) NOT STARTED

| # | Item | Why not started | Priority |
|---|------|-----------------|----------|
| 1 | **Carveout-regression detector** — `system_memtotal_gib` metric + Gatus alert when MemTotal < ~120 GiB on evo-x2 (the silent BIOS-revert signature). The 2026-08-19 revert went unnoticed; Auto bit again today. | Not requested; surfaced by this session | **High** — the trap has now fired twice |
| 2 | ROCm client-view verification — `hipMemGetInfo` from a live client should now report the ~120 GiB ceiling (confirms KFD accounting sees what we think) | Not requested | Medium |
| 3 | `/tmp/k7src/` cleanup | Deliberately kept (useful for follow-ups until next kernel bump) | Low |

## d) TOTALLY FUCKED UP

Nothing broken — no data loss, no bad config shipped, live state fully verified. But three honest process failures, all mine:

1. **The "safety margin" claim was oversold BS until the user challenged it twice.** I wrote "pages_limit 120 GiB sits ~4.3 GiB below MemTotal | restored" in a verdict table and "inverting the TTM safety margin" into AGENTS.md **without having read a single line of TTM code** — I repeated the existing doc narrative. The conclusion happened to be directionally right (GTT ceiling < RAM matters), but the mechanism was unproven at write time and my framing implied kernel-enforced protection that does not exist (soft cap, proceeds anyway).
2. **First-turn overstatement: "the deployed config expects 512 MiB."** `boot.nix` never references the carveout; the only coupling is the implicit MemTotal assumption behind the 120 G pages_limit choice. Minor, but a claim stated as fact.
3. **Wrong source order:** I queried torvalds/linux **master** on sourcegraph for "what does our kernel do" — the user had to redirect me ("check the actual Kernel code we are running"). Version drift makes master evidence non-authoritative; the running kernel was reachable in ~5 minutes via `nix-store -q --outputs` → realize tarball → selective extract.

Root cause across all three: **narrative repetition over primary-source verification.** Mitigation already applied: mechanics now sit in AGENTS.md with file:line citations from the running kernel.

## e) WHAT WE SHOULD IMPROVE

1. **"What does OUR kernel do" questions → running kernel source FIRST.** This session proved the 5-minute workflow: `uname -r` → resolve `perf-linux-<ver>.drv` outputs → `nix-store -r` the source tarball (was GC'd; realized from cache) → `tar -xJf` only the needed files. Make it a script so the next session doesn't rediscover it.
2. **Claim discipline for mechanism statements.** Words like "margin", "protects", "cap" entering tables or AGENTS.md need a code citation or an explicit "unverified" tag. The user should not have to be the BS detector.
3. **Batch AGENTS.md edits.** Three sequential edits to the same paragraph across three turns; one consolidated edit would have been cleaner in a shared tree with an auto-commit daemon.
4. **Staleness sweep when a canonical value changes.** 512 MiB → 1 GiB updated the GPU section but not the zram section's reference. A `grep -rn "512 MiB"` sweep belongs at the end of any value-flip edit.

## f) Next tasks (ranked by impact)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Add carveout-regression guard: `system_memtotal_gib` textfile metric + Gatus check `MemTotal < ~120 GiB` on evo-x2 — catches the silent 32 GiB revert class within one scrape cycle | **High** | S/M | Feature |
| 2 | Fix stale ZRAM-section carveout reference in AGENTS.md (512 MiB → 1 GiB, ~124 GiB) | Medium | S | Documentation |
| 3 | Add CHANGELOG.md entry: 2026-09-05 carveout 1 GiB live, Auto=32 GiB trap, TTM mechanics code-verified | Medium | S | Documentation |
| 4 | Verify `hipMemGetInfo` from a live ROCm client reports ~120 GiB ceiling (KFD view matches sysfs) | Medium | S | Verification |
| 5 | `docs/gotchas-archive.md` entry: "UMA Auto = 32 GiB" BIOS trap (two occurrences: 2026-08-19 silent, 2026-09-05 Auto) | Medium | S | Documentation |
| 6 | Add the code-verified mechanics (3 file:line refs) as a comment block in `boot.nix` next to `ttmPagesLimit` | Medium | S | Documentation |
| 7 | Record live-verified values (pages_limit 31457280, page_pool_size 6291456 = 24 GiB, verified 2026-09-05) in boot.nix comments | Low | S | Documentation |
| 8 | Sweep repo for other stale "512 MiB carveout" / "~125 GiB visible" references (`grep -rn`) | Medium | S | Cleanup |
| 9 | Script the running-kernel-source extraction → `scripts/fetch-running-kernel-source.sh` (drv → outputs → realize → extract given paths) | Low | S | Tooling |
| 10 | Identify VRAM 909 MiB composition (root: `amdgpu_gem_info`); document expected scanout footprint per connected display | Low | S | Verification |
| 11 | Watch GTT usage under full AI load (llama-rag + ollama resident) — first real-world exercise of the 120 G ceiling | Low | M | Verification |
| 12 | On next kernel bump: re-diff `ttm_tt.c` / `amdgpu_ttm.c` clamping behavior (soft-cap semantics could change) | Low | S | Verification |
| 13 | HARVEST items 1-8 into TODO_LIST.md per docs-health (items 9-12 → ROADMAP) | Medium | S | Process |
| 14 | Decide fate of `/tmp/k7src` (keep until next kernel bump, then trash) | Low | S | Cleanup |

## g) Questions I cannot answer myself

1. **Is 1 GiB now the canonical carveout?** I documented it as fact (user-set). If you'd rather return to the 2026-09-02 target of 512 MiB, say so and I'll flip the docs back — both are functionally fine, but docs should have one owner decision.
2. **Has the BIOS setting reverted more often than we know?** The documented silent revert is 2026-08-19 (18 GiB → 32 GiB). You're the only one who sees boots/BIOS screens — did reverts correlate with BIOS updates, CMOS resets, or power cuts? This decides whether the regression detector (task 1) is High or can wait.
3. **Alert tier for the carveout-regression detector:** notify-only (one self-expiring notification, per your movie-night rule) or Discord-only via Gatus? Memory conditions must never overlay per your standing rule, but this is a hardware-config regression — your call.

---

*Report format: `.md` per explicit user request (skill canonical is HTML — override flagged).*
