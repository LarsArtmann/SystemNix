# Status report — llama-embeddings 645G write attribution (the 465G class, pinned one layer deeper)

**Window:** 2026-11-14 ~06:30-07:30 CET, session task 000001a1d5d871644a2dac5d586a00000000 (item 5).
**Method:** live systemd unit IO counters + journal forensics of the implicated window +
/proc/diskstats device reconciliation (current boot started 2026-11-07 01:06, so it SPANS the
645 GB window and every device counter is still accumulating).

## What is pinned

1. **The class is chronic and unit-attributed.** The last llama-embeddings invocation
   (2026-11-08 02:44→08:14, 5h32m, SIGKILLed on stop-timeout) measured **645.2 GB written /
   8.5 GB read** (`systemctl show llama-embeddings -p IOWriteBytes`; systemd cgroup io accounting
   over the invocation) — the same class as the 465.4 GB pre-switch instance of 2026-11-03/04,
   BIGGER. The journal shows continuous backlog re-embed tasks through the window (journald
   rate-limited most slot lines; the surviving ~240 lines show ~500-800-token tasks every few
   seconds, and journald suppression messages are ABSENT, so the process was not log-flooding).
2. **Not the model filesystem.** /data (nvme1n1p8, GGUF home) wrote **0 GB** since the 2026-11-07
   boot — the model file never took writes.
3. **Device reconciliation points at the HDD pool.** Since the 11-07 boot: pool mirror sda+sdd each
   wrote ~708 GB; the CURRENTLY-LIVE cgroups only explain ~126 GB of that (clickhouse 73 GB,
   paperless slice ~45 GB, restic ~6 GB, misc ~2 GB). The missing ~580 GB/device belongs to dead
   cgroups of the implicated window — and the only unit-scale counter in that magnitude is
   llama-embeddings' 645 GB. (Mirror note: a byte written to the pool hits both devices, so raw
   unit wbytes and per-device counters do not sum 1:1; the magnitude match, not exact equality,
   is the evidence.)
4. **The module has NO declared write surface** — ExecStart takes no output flags, no
   StateDirectory, harden{} gives ReadWritePaths=[] + ProtectHome=true + PrivateTmp (tmpfs, no
   device IO), zram has no writeback backing device, and HOME-cache writes are blocked by
   ProtectHome. Whatever dirtied 645 GB in the unit's cgroup did it through an IMPLICIT surface.
   The 65:1 write:read ratio "has no canonical llama-server mechanism" — that sentence survives
   this session: the layer above (consumer demand, item-4 report) and the device below (pool
   mirror) are pinned; the inner mechanism is not.

## NEW findings (queued same session)

1. **Samsung nvme0n1p2 wrote 16.6 TiB since the 2026-11-07 boot** (~2.4 TiB/day sustained) — an
   SSD-wear-relevant rate on the 1 TB Samsung hot-tier disk with an unattributed writer set.
   Queued to storage.md + TODO_LIST.md.
2. The paperless slice itself writes only ~45 GB per pool device — the pool bulk is NOT paperless'
   own index churn, which weakens the "consumer writes the index" half of the re-embed story and
   strengthens "the writes are inside the embeddings unit's cgroup".

## Direct follow-ups (self-harvested at authoring time)

- Per-device io.stat instrumentation of the embeddings cgroup during its NEXT serving window (the
  per-device split dies with the cgroup when the unit stops) → docs/todo/ai-stack.md +
  TODO_LIST.md. LANDED same session.
- Samsung 16.6 TiB writer attribution → docs/todo/storage.md + TODO_LIST.md. LANDED same session.
