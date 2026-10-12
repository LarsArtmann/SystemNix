# What Can and Should We Improve, For Real — Pareto Plan

**2026-10-12 ~18:0x · evo-x2 · session following the 13:40 boot dispatch + 15:49 self-review**

Question on the table: after the boot-time dispatch and its brutal self-review,
what are the REAL improvements — not the 300-row queue noise, the things that
actually move the box?

Format note: `.md` per the owner's standing dispatch convention (same as the
15-49 report), not the skill-default HTML.

---

## The one-paragraph honest answer

**Boot time was a symptom. The disease is the crash cadence, and the second
disease is that the observability layer goes dark exactly when it is needed.**
15 crash-class boots in 12 days, zero clean reboots since Oct 1, 28 freezes —
every one of them forces a watchdog reset → cold boot → 62.7s firmware (AMI
memory retraining) → recovery IO storm → 8-13min userspace. The four boot-path
fixes (deployed, system-876) treat the storm's WAKE; the freeze cluster is what
keeps scheduling storms. Meanwhile system_health.prom has been whole-file
REJECTED since at least the freeze-28 boot — every `system_*` metric blind
mid-incident — and four thermal freezes happened with zero thermal alerting.
This session fixed the blindness (5 changes, eval-green, deploy-gated) and this
plan ranks everything else.

## The 1% that delivers 51%

**Make incidents visible again + stop feeding the freeze loop.**

1. **Monitoring de-blind (EXECUTED this session, deploy-gated):**
   census newline glue fix (system_health.prom whole-file rejection — 3rd
   quoting incident from this collector), storage-collector 0644 lock bump
   (completes the parallel session's perms fix), thermal alert leg
   (`system_thermal_alert`, freezes #8/#9/#11/#12 had none), boot-metrics
   collector (every reboot = free verification boot + automatic watchdog-reset
   classification), 5 Gatus checks (system-health canary, CPU thermal, boot
   metrics canary, userspace regression, watchdog reset).
2. **Freeze-loop breakers (top queued rows, ranked):**
   - IO-admission enforcement legs (stability.md): the `heavy-job` wrapper
     EXISTS (workload-admission.nix) but nothing makes the killers use it —
     agent verification batteries, migration scripts, midnight GC all still
     enter a storming box freely. The gate designs are written; the
     enforcement legs are the whole ask.
   - llama-chat 41.7G total-vm at the freeze-28 OOM cascade — the single
     named memory-side killer. (llama-chat.nix was dirty in-tree from a
     parallel session; verify ownership before touching.)
   - Owner BIOS: Fast Boot + MRC (cold 62.7s → ~7-15s) — already
     [blocked:user] with the NVRAM re-decode verify attached.

## The 4% that delivers 64%

3. **ClickHouse off the QLC disk** — the storm's eye (10m52s of every storm
   boot; SigNoz is the observability backbone, so its recovery IO competes
   with the very diagnostics that watch it). PREMISE CORRECTED this session:
   state is on a dedicated 100G XFS partition on the QLC (nvme0n1p9), not the
   root subvol — migration shape is partition→Samsung, and the owner risk
   call (relocate during an active freeze cluster?) is §g.3 of the 15-49
   report, still open.
4. **PSI avg60 collector gap + drain-gate semantics** (rows: `node_psi_io_some_avg60`
   never existed; deploy drain gates must require avg10 AND avg60 — the
   self-review's own #4). Small, unblocks calmer deploys.
5. **Queue economics**: the /data watch burned 17 paid fires, tmp-reclaim 8,
   oct3-triage 6 — the harness re-proves sudo-refusal at full session price.
   Highest-leverage LOCAL piece: land the 85% /data alarm (row) then RETIRE
   the manual watch row; the rest is go-taskqueue-side (upstream rows).

## The 20% that delivers 80%

6. **Durability proofs**: restic has never run check/restore; offsite Borg is
   engineered but go-live-gated on owner decisions (passphrase recovery copy,
   append-only posture, dump third-copy); ClickHouse restore drill authored
   but unrun. Each is a bounded window, each closes a data-loss class.
7. **/data csum repair** (129,533 errors, T04-T08 owner window) — every week
   of delay extends the read-error surface the scrubs keep re-finding.
8. **Docs/queue debt**: 63 queue↔library drifts, 101 unharvested reports,
   duplicate-row lint. Real but mechanical; batch behind the above.

## Explicitly NOT "for real" (declined, with reasons)

- **Loader timeout 2→1, initrd outliers, loader variance** — micro-wins
  behind the disease (self-review #13/#23, ROADMAP-fuel).
- **Rewriting the dispatch system now** — the waste is real (~30 paid no-op
  fires) but bounded; the freeze loop generates more cost per week than the
  queue inefficiency. Fix crashes first; the queue follows.
- **BIOS update hunting for MRC** — only after the owner confirms 1.11 lacks
  it (§g.2 of 15-49).
- **More boot micro-tuning before the reboot verdict** — the four deployed
  fixes are unmeasured on a calm boot; adding more changes before the verdict
  muddies attribution.

## Execution log (this session)

| Change | File(s) | State |
| --- | --- | --- |
| Census newline glue fix (whole-file rejection) | `modules/nixos/services/system-health.nix` | eval-green, **deploy-gated** |
| Thermal alert leg + option (95°C default) | `modules/nixos/services/system-health.nix` | eval-green, **deploy-gated** |
| Boot-duration collector + reset-reason classification | `modules/nixos/services/boot-metrics.nix` (new) + `configuration.nix` enable | eval-green, parser functionally verified vs boot-0's exact numbers, **deploy-gated** |
| 5 Gatus checks (canary/thermal/boot×3) | `modules/nixos/services/gatus-config.nix` | eval-green, **deploy-gated** |
| storage-collector explicit-0644 lock bump | `flake.lock` (c0a3389c → 0ba7b4fe, 2026-10-12) | closes the parallel session's deploy coupling, **deploy-gated** |
| ClickHouse relocation row premise correction | `docs/todo/storage.md` + 13-40 report annotation | landed |
| `nix flake check --no-build` | — | **all checks passed** |

Mechanism note for the census fix (the reusable lesson): `$(printf …)` command
substitution strips ALL trailing newlines — a `\n` inside the format string
never survives `VAR+="$(…)"`. The newline must be appended OUTSIDE the
substitution (`VAR+="$(printf …)"$'\n'`). Verified by simulation before edit
and against the live node_exporter error (line 686:
`44361195520system_cgroup_mem_anon_bytes{…}`).

## The verdict loop that closes this session's work

The deploy (PSI-gated at session time: io some avg10 47%, full 35%) makes all
five changes live; the NEXT reboot then self-verifies via the new
boot-metrics.prom instead of waiting for a human — which is itself the
template for the whole plan: **every recurring question becomes a metric,
every metric becomes a check, every check pages the owner instead of spawning
a dispatch.**
