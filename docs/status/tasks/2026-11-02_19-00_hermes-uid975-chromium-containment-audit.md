# hermes (uid 975) chromium memory containment audit — worker-cron exec scope

Session: 2026-11-02, task-queue batch `000001a19d3b35657c72153f15d800000000` (item 3).
Evidence: live probes 2026-11-02 ~18:5x CET (a fresh hermes chromium was RUNNING —
pid 279199 browser + 4 helpers under
`hermes-worker-cron-f59d5d8cfb7b-exec-7967df990dee4670a4a62bb8333d33c7.scope`),
hermes source (`hermes-python-source` tools/process_registry.py), Oct-28 kill lines
(docs/status/tasks/2026-10-30_23-29_boot-b0d70d73-evidence-pull.md).

## Verdict

**Containment EXISTS — the "reservation-scale victims suggest zero" hypothesis is
falsified.** The worker-cron exec scope carries a real MemoryMax, and the Oct-28
victim died fully inside its limit. But the containment is a CHARGE limit and the
victims died on RESERVATION pressure, so the containment never engaged — that is
the gap, and it is structural (see the companion repro report).

## Live scope state (pid 279199 tree, cgroup v2)

| property | value |
|----------|-------|
| memory.max | **4 GiB** (4294967296) |
| memory.high | max (unbounded soft throttle) |
| memory.swap.max | max |
| pids.max | 152680 |
| oom_score_adj | browser 0, zygote 0, gpu/utility 200 (chromium's own per-role adjustments) |

Provenance: hermes spawns every worker via
`systemd-run --user --scope --collect --property=MemoryAccounting=yes
--property=MemoryMax=<N>` (tools/process_registry.py `_systemd_scope_argv`); N =
`_worker_memory_max_bytes()` = min(gateway cgroup memory.max, min(4 GiB, half of
RAM), optional tightening override) — the 4 GiB cap is hermes' own
`_WORKER_MEMORY_MAX_CAP_BYTES`.

## Oct-28 victim re-read (chromium 44547, uid 975, exec scope f59d5d8cfb7b)

- Killed by GLOBAL OOM (CONSTRAINT_NONE, swap 0/62 GiB) at 10:15:23, adj 300,
  total-vm 1.414 TiB, anon-rss 924 kB.
- systemd's own accounting AFTER the kill: `Consumed 1min 26s CPU … 1.1G memory
  peak, 248M swap peak` — the 4 GiB-class MemoryMax held for the whole 9.5 h
  lifetime. The scope was NOT uncontained.
- adj 300 = chromium's own renderer-role adjustment, UPGRADED FROM INFERENCE
  TO CITATION (chromium source, main, fetched raw 2026-11-02):
  *(2026-11-07 pin: the fetched rev is `9a988a2a086fabe2a948cdbeb557bccbcf395ff6`
  (chromium/chromium main@{#1733436}, committed 2026-11-02T23:59:47Z — resolved
  via the GitHub mirror commit API for that date, per the verify-before-filing
  rule); re-verified at that SHA, `content/public/common/content_constants.cc`
  carries exactly `kLowestRendererOomScore = 300`, `kHighestRendererOomScore =
  1000`, `kOomScoreBump = 100`, `kMiscOomScore = kLowestRendererOomScore -
  kOomScoreBump`, zygote 0, in the IS_LINUX||IS_CHROMEOS block — the citation
  holds verbatim at the pin.)*
  `content/browser/child_process_launcher_helper_linux.cc`
  (`LaunchProcessOnLauncherThread`) sets `oom_score = content::kLowestRendererOomScore`
  for every `--type=renderer` and `content::kMiscOomScore` for the other zygote
  children, applied via `ZygoteHostImpl::AdjustRendererOOMScore`
  (`content/browser/zygote_host/zygote_host_impl_linux.cc`). The constants live in
  `content/public/common/content_constants.cc` (IS_LINUX||IS_CHROMEOS block):
  `kLowestRendererOomScore = 300`, `kHighestRendererOomScore = 1000`,
  `kOomScoreBump = 100`, `kMiscOomScore = kLowestRendererOomScore - kOomScoreBump`
  = 200, browser/zygote = 0. The batch hypothesis named `oom_intervention` as the
  setter — FALSIFIED: the adjustment is unconditional in the browser's child-process
  launcher at every renderer launch, not a component intervention that fires under
  memory pressure. The observed live ladder (browser 0, gpu/utility 200,
  renderer 300) is exactly this compile-time table; it made the renderers
  preferential global-OOM victims on top of the 1.4 TiB total-vm weighting.

## The actual gap

Per the repro report (2026-11-02_18-55): each chromium renderer reserves ~1.4 TiB of
PROT_NONE address space at STARTUP. `MemoryMax` bounds the cgroup charge (RSS),
never the reservation; the kernel's global-OOM badness ranking weighs total-vm. A
fully-contained hermes chromium (1.1 GiB peak under a 4 GiB cap) is still top-ranked
kill bait in a system-wide memory exhaustion event, and its self-raised adj 300
pushes it ahead of the owner's own session processes. Remediation levers if this
class keeps eating hermes workers: `OOMScoreAdjust=` lowering on the exec scope
(hermes-side change), `vm.overcommit_memory` policy (system-wide, risky), or
accepting the kill behavior since anon-rss was negligible (the kills cost little
real memory — they cost the WORK, e.g. a 9.5 h cron run).
