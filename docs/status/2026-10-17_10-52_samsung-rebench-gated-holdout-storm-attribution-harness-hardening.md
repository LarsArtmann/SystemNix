# Samsung re-bench: gated holdout under a 19-hour IO storm — harness hardened + committed

**Session:** 2026-10-16 16:15 → 2026-10-17 ~11:00 (overnight idle, resumed 10:40)
**Task:** "Run the benchmark!" — the quiet-window Samsung live-FS re-bench queued by the 2026-10-16 heatsink/boot-drive session (`[ready]` row, TODO_LIST:86 / docs/todo/storage.md:37).
**Headline:** The benchmark is BUILT, COMMITTED, VERIFIED, and ARMED with 24h gate patience — but has NOT RUN. A concurrent-session Go-build storm held io PSI above the quiet gate for the entire ~19h observation span (three gate windows expired clean; zero contaminated runs). Four mid-storm prefill datapoints (1.78–2.32 GB/s seq write vs 2.7 GB/s raw baseline) say the drive itself is healthy. This report ends with WAIT FOR INSTRUCTIONS.

---

## a) FULLY DONE

1. **Dispatch intake + live-state verification (rootless):** read the parked session state, the re-bench method row, and `scripts/bench-disk.sh` for the exact baseline workloads (6 fio tests: rr1/rw1/rr32/fs1/sr/sw, all `--direct=1 --ioengine=io_uring`). Verified live: `/tmp/bench-samsung-livefs*.sh` gone (died with the day's reboots/tmp lifecycle), fio store path alive at arm time, Samsung hwmon resolvable, scratch target `/home/lars/.cache/nix` confirmed ON the Samsung (`/dev/nvme1n1p2`, 553G free — writing 3G to the QLC root would have been dangerous; checked before building).
2. **Harness v3 built + debugged:** PSI gate (some<20 AND full<15, 3×5s consecutive), NOCOW `+C` scratch, seq-write prefill (hole-read lesson), identical workloads to baseline, 2s temp sampler, QLC io_ticks contamination proxy, rr1-lat post-hoc sanity check. One bug caught and fixed at first launch (hwmon resolver compared a symlink path to a canonical path).
3. **Storm attribution (live, /proc-based):** the blocker is a concurrent-session build storm — 14–35 `go` processes (two in D state), nix/link workers, 2 QEMU VMs (`vm-tests`), `flush-8:16` buildcache kworkers. Sustained 2026-10-16 ~16:00 → 22:15+ at some=35–84 / full=7–83, resumed overnight: 14–18 go procs STILL alive at 10:45 on 10-17 (day 2).
4. **Gate discipline held, three times:** armed windows of 55 min, 120 min, 180 min — each expired with a clean `ABORT ... refusing contaminated run` (exit 2), honoring the 2026-10-16 lesson that timed-out-and-ran-anyway data is worse than no data. Zero contaminated suites launched.
5. **Four mid-storm prefill datapoints captured** (each gate arm seq-writes the 3G scratch as prefill; these ARE seq-write benchmarks): **1775 / 2114 / 2213 / 2028 MiB/s** through btrfs+NOCOW, mid-storm, vs the 2.7 GB/s raw baseline — 66–82% of raw through the file path while the host was saturated. Drive-level health signal; recorded into the storage.md row.
6. **Prior session's flagged improvement EXECUTED (late — see §d):** harness committed as `scripts/bench-samsung-livefs.sh` with hardening beyond v3: fio resolution chain (env → both known store paths → PATH → flake-locked `nix build --impure` rebuild — the same proven pattern as `bench-nix-fs.sh`), default 24h gate patience, 60s heartbeat logging (`[heartbeat +Nmin] some= full= go_procs=`), per-test QLC io_ticks (replacing the misleading per-test PSI echo), method caveats printed with results, and a `COMPLETE-stamp` file any future session can poll. Syntax-checked (`bash -n`); shellcheck unavailable in the agent shell — CI lint will be the first shellcheck pass (daemon commit may skip the pre-commit leg, the known daemon-race caveat).
7. **fio fallback exercised LIVE and proven:** overnight GC ate BOTH known fio store paths (third occurrence of the storage.md:253 failure mode — first time it hit MY armed harness between sessions); the committed harness rebuilt fio from flake-locked nixpkgs cache-substituted in seconds at 10:45 arm.
8. **Harness ARMED autonomously** (10:45:47, 24h patience, heartbeat live in run.log) — it fires without any session watching and stamps results for the next reader.
9. **Row pair updated without drift:** TODO_LIST:86 + storage.md:37 now point at the committed harness, carry the prefill datapoints, the scratch-cleanup clause (`bench-v3/` + stale `samsung-bench.MthhVr/`), and the COMPLETE-stamp polling path. Two mid-edit mtime conflicts with concurrent sessions were resolved by fresh re-reads before re-applying.

## b) PARTIALLY DONE

1. **The benchmark itself:** armed + verified end-to-end through prefill, but the 6-workload suite has not executed — no quiet window materialized in ~19h. The armed gate covers the next 24h autonomously.
2. **Parity recording** (AGENTS.md ~163 numbers, CHANGELOG entry amendment, row close on both surfaces): fully specified, blocked on the run.
3. **Heatsink under-load thermal evidence:** sampler wired (idle observations 45.9–56.9 °C across the span; crit 84.85 °C), but no suite load temps yet.

## c) NOT STARTED

1. The quiet-window 6-workload suite and the parity verdict (incl. confirming the QD32-inversion was pure host queueing).
2. Post-run scratch cleanup (`~/.cache/nix/bench-v3/`, `samsung-bench.MthhVr/` v2 remnant — 6G total).
3. Post-run integrity echo: `btrfs device stats` delta on `tlc` (corruption_errs must stay static at 12 through the bench IO).

## d) TOTALLY FUCKED UP

1. **Re-offended the prior session's flagged mistake before correcting it:** §e.2 of the 2026-10-16 report said "commit the harness — /tmp copies die on reboot." I rebuilt the harness in `/tmp` AGAIN from scratch anyway, and only landed the committed copy mid-session because the storm gave me idle time. If this session had ended early, the third rebuild would have been needed. The fix exists now; the discipline failure is the finding.
2. **First-launch resolver bug:** wrote the hwmon↔nvme matching from memory (symlink path vs `readlink -f` canonical path) instead of verifying the path shape live before writing — guess-then-fix, cost one launch cycle. Trivial to have checked first.
3. **Left a self-referential telemetry line in v3:** per-test `some=$(psi_some)` echo is uninterpretable by construction — our own fio IO dominates PSI during the suite. I knew this at design time (it's why I added the QLC proxy) and left the echo in anyway. Removed in the committed copy.
4. **Reinvented monitoring ~15 times:** manual `sleep N; cat /proc/pressure/io` poll cycles instead of baking a heartbeat into the harness on day one. Cadence was vibes (5–30 min), not derived; tool-spam waste.
5. **Owner decision surfaced too late:** "wait for natural quiet vs coordinate the other session vs accept a directional contaminated run now" was MY call to silently make for 5.5h — I only surfaced it in the eventual status answer. (A parallel session independently reached the same class of ask overnight: TODO_LIST:157 stacks this re-bench into a five-verification calm-window battery.) Should have been question #1 at arm time.

## e) WHAT WE SHOULD IMPROVE

1. **Act on flagged improvements in the SAME session they're flagged in** — §d.1 is the exact anti-pattern; the backlog row existed while I recreated the failure.
2. **Verify path/shape assumptions live before writing resolvers** — 30 seconds of `readlink -f` beats a debug cycle.
3. **Bake operational telemetry (heartbeat, completion stamps) into long-running scripts at creation** — anything gated on an external condition must be self-observing; manual polling doesn't survive session boundaries.
4. **Surface autonomy decisions that consume hours at decision time** — the wait-vs-alternatives tradeoff was owner-relevant immediately.
5. **Method refinement still open:** 3G working set lets QD32 cycle DRAM/SLC-cached LBAs (inflates QD32 vs the full-disk raw run); an 8–16G scratch would be more representative — either amend the row or always print the caveat (committed copy prints it). Prefill BW should be parsed as a formal datapoint in every run, not scrounged from logs.
6. **GC-vs-store-path war:** third strike of hardcoded fio paths being GC'd. The flake-locked fallback is now proven twice over (bench-nix-fs.sh lineage + this harness); the trivial transplant into `bench-disk.sh` remains queued (storage.md:253 / TODO_LIST:1387).

## f) NEXT (ranked)

1. **Poll `~/.cache/nix/bench-v3/COMPLETE-stamp`** (any session; or read run.log tail) — on fire: verify rr1-lat sanity line, QLC busy %, temps.
2. **Record parity numbers** → AGENTS.md Samsung-role paragraph (~line 163), CHANGELOG 2026-10-16 entry amendment, close `[ready]` row pair (TODO_LIST:86 + storage.md:37) — surfaces: BOTH, per the correction-claim rule.
3. If rr1 sanity fails (>2.5× baseline) → investigate before recording anything; a contaminated fire is a non-result.
4. Trash scratch dirs after close (2 above done first): `bench-v3/` + `samsung-bench.MthhVr/`.
5. Fold the 4 prefill datapoints into the parity narrative (storm-sensitivity curve for seq write).
6. Post-run `btrfs device stats tlc` delta check (corruption_errs static at 12).
7. **Owner Q1 (below) SMART output** → parse percentage_used / media_errors / thermal-throttle counter → close the `[blocked:user]` row (TODO_LIST:88).
8. **Owner Q2 (below) reseat facts** → update the reversion-mystery `[watch]` row.
9. Coordinate TODO_LIST:157's calm-window battery (one 30-min window + 2 deliberate reboots closes five stacked verifications incl. this re-bench).
10. `bench-disk.sh` fio fallback transplant (row 1387 — pattern now copy-proven in `scripts/bench-samsung-livefs.sh`).
11. Deploy carries the done-but-undeployed nvme0n1 by-id hardening (row 87, DONE 2026-10-16, deploy pending).
12. If parity lands ambiguous on QD32 → amend scratch size to 8G and rerun rr32 only (SCRATCH_SIZE env exists).

Harvest accounting: items 1–6 are the existing re-bench row's own scope (row pair edited this session to carry harness pointer + datapoints + cleanup — HARVESTED by edit); 7 = existing TODO_LIST:88 row; 8 = existing [watch] row; 9 = existing TODO_LIST:157; 10 = existing 1387; 11 = existing 87. No NEW rows needed; nothing deliberately unharvested.

## g) QUESTIONS (cannot be resolved agent-side)

1. **The storm / the calm window:** the Go-build storm has run ~19h and 14–18 build processes are still live (day 2). Is that sanctioned concurrent-session work I must keep waiting out (the armed gate now has 24h patience and fires autonomously), and — merging with TODO_LIST:157's ask — can you grant ONE 30-minute io-calm window (plus 2 deliberate `systemctl reboot`s) to close all five stacked calm-window verifications including this re-bench? Alternatively: tell me to pause/renice the building session, or to accept a directional contaminated run now with the clean one later.
2. **SMART (definitive heatsink verdict, still open since 2026-10-16):** `sudo smartctl -a /dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0RA01856V` — paste the output; I need percentage_used, media_errors, and the thermal-throttle counter (agent shells cannot sudo).
3. **The reseat (feeds the reversion `[watch]` row):** did the Samsung stay in its M.2 slot during the heatsink install or move slots, and was the reseat aimed at the 2026-10-12 NVRAM reversion or purely thermal? (nvme0/nvme1 enumeration flips make this undeterminable from sysfs.)

---

**Session state at park:** harness ARMED (24h from 10:45), heartbeat logging, COMPLETE-stamp path published in the row pair. Awaiting owner instructions. Do not re-arm a second copy while one is live (two suites firing together would contaminate each other — check `pgrep -af bench-samsung-livefs` first).
