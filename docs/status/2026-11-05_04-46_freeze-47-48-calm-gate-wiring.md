# Status report — freeze #47 + #48 triage: the two unwired calm gates found and wired

**When:** 2026-11-05 03:07 → 04:46 CET
**Session:** ad-hoc incident response to the owner's "Why the fuck did we crash this time and why can't the fucking computer recover from it itself" (03:0x) and "FUCKING AGAIN" (03:2x — freeze #48 landed mid-diagnosis).
**Trigger:** WDT reset at 03:03:12 (freeze #47, boot `91b4a3a2`, 7 h 57 m), then its recovery boot `30b6b4cb` died at 03:13:47 — **eight minutes and three seconds after boot** (freeze #48, shortest family boot since #18's 26 m).

---

## Scope line — VERIFIED vs NOT

**Verified with fresh commands:**

| Claim | Evidence |
| --- | --- |
| #47/#48 mechanism = hardware watchdog (family C) | `x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired` in boots `30b6b4cb` and `5819f35d` kernel logs |
| Census #47 `91b4a3a2` (7h57m): 133 trips / 279 ENTERs / 0 OOM | `crash-triage.sh --boots 3` |
| Census #48 `30b6b4cb` (8m03s): 3 trips / 5 ENTERs / 0 OOM | same |
| #48 boot-storm measured at T+120 s: SIX GB-scale cold readers | guard's own forensic bundle `/var/tmp/io-psi-forensics-20261105T020742Z/` (trigger zone6-trip): flm-real 12.0 G, llama-server(vlm-cap) 9.7 G, monitor365 7.5 G, llama-embeddings 6.2 G, dnsblockd 5.4 G, nsfw 3.9 G; flm-real D-state 102 s, btrfs flush kworker 114 s |
| flm-real crash-loop pre-#47 | coredumpctl: SIGABRT 02:50:56 (core missing) + 02:55:10 (782.5 M present), fastflowlm-1.0.2, all threads in gomp barrier wait |
| llama-embeddings re-arm (the never-run #46 §c.5 check) | measured 6.2 G cumulative read at T+120 s of boot `30b6b4cb` — answered by measurement, on a different boot than asked |
| Live cvagent still carries the WRONG 20-min timeout | busctl `TimeoutStartUSec = 1200000000`; next fire 05:53 (Persistent catch-up ruled out — NextElapse is tomorrow's slot); the 90-min fix sits in tree undeployed |
| The two 2026-10-17 gate packages were store-only ghosts | `psi-wait-gate` (built for "socket-activated units (fastflowlm, llama-vlm backends)" per its own header) + `post-crash-calm-gate` (built for "post-crash resumable readers" per freeze-6 rule (a)): zero consumers in modules/platforms/systems, `post-crash-calm-gate` missing even from the overlay |
| The wiring (this session) evals green | toplevel drvPath eval OK; rendered asserts: llama-embeddings/nsfw-classifier `requires` carries the gate, gate `TimeoutStartSec=65min`, fastflowlm ExecStartPre = portGuard THEN psi-wait-gate, llama-vlm-cap ExecStartPre = psi-wait-gate, `TimeoutStartSec=25min` |
| Gate selftests green | `checks.x86_64-linux.post-crash-calm-gate-selftest` + `psi-wait-gate-selftest` built (runCommand = executed) OK |
| Evidence pulled before vacuum (0.2 G headroom) | `docs/status/tasks/2026-11-05_02-52_boot-{30b6b4cb,91b4a3a2}-evidence-pull.md` |
| Toplevel closure PREBUILT (rc=0) | background `nix build … --no-link` completed; the switch is cheap |

**NOT verified here:**

- **The deploy did not land at report time** — PSI some avg10 54–71 % all session; the pressure gate (correctly) blocks at ≥20 %. The prebuild + the queued deploy row carry it.
- Per-device (QLC/Samsung/pool) split of the #48 storm — the bundle's `diskstats.txt` was not read (the #46 residual row's own trap, repeated; queued there).
- flm-real SIGABRT root cause — coredump identified, not analyzed (upstream row queued).
- Third boot `5819f35d` survived 1 h 30 m+ under PSI some avg60 ~53 % — attribution of WHY it survived (monitor365 41.3 G nightly export landed 03:30 per the parallel media-atlas session's row; possibly the storm went bandwidth-bound instead of stall-bound) is the parallel session's autopsy row, not mine.

## a) FULLY DONE

1. Freeze #47 + #48 boundary, mechanism (WDT ×2), census, and ledger registration — rows + cluster table updated (Nov 2–5: 10 cuts in ~72 h, worst cluster on record extended).
2. Boot-storm attribution for #48 from the guard's own T+120 s bundle — the first RECOVERY-BOOT (not death-window) measured attribution: six simultaneous GB-scale cold readers.
3. **The ghost-system fix: both 2026-10-17 gate packages wired per their designed contracts** —
   - `post-crash-calm-gate`: NEW `modules/nixos/services/post-crash-calm-gate.nix` (barrier oneshot, wait ≤60 min, refuse at cap, RemainAfterExit, OnFailure toast, ioTier.background), overlay entry, `configuration.nix` enable; gates `llama-embeddings` + `nsfw-classifier` (and `llama-reranker` when enabled) via options-guarded `Requires+After` (single-module VM tests stay self-contained). Kill-switch property: `systemctl stop post-crash-calm-gate` drops the whole gated fleet.
   - `psi-wait-gate`: `ExecStartPre` on `fastflowlm` (port-guard FIRST, gate second) and every `llama-vlm-*` backend; `TimeoutStartSec` 3→25 min. Every restart re-arms the wait — the flm SIGABRT pile-driver class is spaced automatically.
4. Selftests wired: `post-crash-calm-gate-selftest` added beside `psi-wait-gate-selftest`; both green.
5. Evidence pulls for both dead boots (pre-vacuum discipline), todo harvest (2 rows, both surfaces), this report.

## b) PARTIALLY DONE

1. **Deploy** — closure prebuilt, gate-blocked at report time (PSI ≥20 %). Rides the first genuine lull; carries cvagent-90min + media-atlas-WatchdogSec (parallel session's tree fix) in the same switch. The queued row owns the battery.
2. dnsblockd (5.4 G) + monitor365-server (7.5 G) boot readers deliberately NOT gated — DNS is network-critical and monitor365 is the observability leg; both need profiling/staggering rows of their own (dnsblockd's exists from #46; monitor365's cold-boot read is now measured and needs a row).

## c) NOT STARTED (owner-gated / parallel-owned)

1. **Cooling floor (BIOS fans/PPT)** — 279 ENTERs in #47, 5 in #48's 8 minutes; still the longest-standing unexecuted mitigation on the books.
2. Quiescent-settle / power-off decision — the crash loop is boot-inherent; until the gated config deploys, every reboot re-rolls the same dice.
3. The triple-boot autopsy row (parallel media-atlas session owns it).
4. flm-real abort root cause (upstream).

## d) TOTALLY FUCKED UP (the honest list)

1. **The gates sat unwired for 19 days while the box died ~15 times.** `psi-wait-gate`'s header NAMED fastflowlm and llama-vlm as its target users on 2026-10-17; nothing consumed it. Freezes #40–#48 (~9 cuts) each re-armed exactly the class it was built to hold back. This session is the wiring, not the invention — the invention was already in the store.
2. First eval attempt tripped `io-tier-coverage-audit` (my new gate unit lacked an ioTier fragment) — a guard class I hadn't read before writing. One wasted eval cycle; fixed with `ioTier.background`.
3. Darwin verification incomplete: two wrong attr paths tried, never resolved (`darwinConfigurations.Lars-MacBook-Air` exists; the toplevel sub-attr path wasn't found in two tries). Risk assessed minimal (only the overlay changed for darwin; the same trivial writeShellApplication builds cross-platform) — but "assessed minimal" is not "verified".
4. The `rg -rn` trap hit me AGAIN (4th strike host-wide) within this session — hook caught it, zero damage, shame recorded.
5. First nsfw edit referenced `calmGateDeps` before defining it — caught on re-read, fixed before eval.

## e) WHAT WE SHOULD IMPROVE

| Pattern | Impact | Fix |
| --- | --- | --- |
| Store-only ghosts | ~15 crashes with the fix already built | "built" ≠ "wired": every new pkgs/ helper needs its consumer in the SAME change or an explicit queue row saying what's pending (the selftest proved the gate worked while the box died without it) |
| Recovery boots start everything at once | #48 died in 8 min | LANCHED: barrier + per-backend waits; next: dnsblockd/monitor365 staggering rows |
| Trip census greps are cheap, attribution bundles are gold | this triage took 3 min once the bundle was found | the guard's bundle capture already triggers on zone6 — nothing to change, just READ them first (this session did) |

## f) NEXT

1. Deploy the calm-gate wave at the first lull + full battery (✘ NEW row, TODO_LIST + stability.md — owns it)
2. Upstream flm SIGABRT (✘ NEW row, upstream.md)
3. monitor365-server 7.5 GB cold-boot read profiling row (deliberately not harvested here — the parallel autopsy row may absorb it; next session decides)
4. Owner: cooling floor; power-off/quiesce call tonight (§c)
5. dnsblockd burst profiling (✘ existing row from #46)

## g) QUESTIONS (owner)

1. **Tonight: power off, or ride it?** The box is surviving (1 h 30 m+) under a 50 %+ storm with the monitor365 export riding it. Power-off = guaranteed calm deploy window but another cold-boot roll with the OLD gen; riding = wait for avg10 <20 % and fire. My default: passive-watch + fire the prebuilt deploy at the first lull.
2. **Cooling floor scheduling** — 279 thermal ENTERs in #47's last boot alone. It is 2026-11-05; the row dates to early October.
