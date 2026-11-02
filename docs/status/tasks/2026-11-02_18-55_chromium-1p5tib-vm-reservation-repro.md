# chromium ~1.5 TiB total-vm reservation — mechanism pinned by live repro

Session: 2026-11-02, task-queue batch `000001a19d3b35657c72153f15d800000000` (item 2).
Repro: chromium-unwrapped **156.0.8078.73** (the same build as the Oct-28 victims),
`--headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage --remote-debugging-port=9333
--user-data-dir=~/.cache/chromium-repro/prof about:blank`, launched 2026-11-02 ~18:4x CET
as uid 1000; VmSize sampled from `/proc/<pid>/status` within seconds of launch, maps
categorized from `/proc/<pid>/maps`.

## Verdict

**The ~1.5 TiB total-vm is a STARTUP address-space reservation carried by every
`--type=renderer` process — NOT uptime growth, NOT committed memory, and NOT
browser-process-wide.** Chromium reserves (PROT_NONE, `---p`) huge address-space
regions in each renderer at launch: one dominant ~1296 GiB anonymous region near the
top of the address space (the V8 sandbox: 1 TiB sandbox + guard regions) plus
PartitionAlloc pool reservations (several 16 GiB pools, one 64 GiB, one 4 GiB). The
kernel's overcommit/OOM accounting sees the full reservation as total-vm while the
committed charge stays at KB–MB scale (prod victims: anon-rss ≤1 MB).

## Repro numbers

| pid | process | VmSize |
|-----|---------|--------|
| 274545 | browser (main) | 55.65 GiB |
| 280360 / 280655 / 280799 / 280845 / 286516 | `--type=renderer` (×5) | **1,518,601,000–1,520,574,764 kB (1.414–1.415 TiB)** |

Prod kill lines (boot `b0d70d73`, Oct 28 10:15): chromium 1,518,605,956 kB /
chrome-headless 1,518,498,916 kB — **the repro renderers match the prod victims to
within 0.01%**. Same reservation layout, present at t≈0, no run time needed.

## Renderer map composition (pid 280360, PROT_NONE `---p` totals)

| region | size |
|--------|------|
| `0x709c00034000-0x71e000000000` | **1296 GiB** (V8 sandbox + guards) |
| `0x708800000000-0x709800000000` | 64 GiB |
| `0x247c025c0000-…` / `0x2589659e000-…` / `0x36200024c000-…` / `0x362403454000-…` / `0x709801940000-…` | 5 × ~16 GiB (PartitionAlloc pools) |
| `0x10000-0x100100000` | 4 GiB |

Total anonymous reservation ≈ 1447.2 GiB = the full VmSize delta over the browser
process. Committed pages at sample time: VmRSS 10–60 MB per renderer.

## Consequences for the Oct-28 cascade reading

1. "Reservation grows over 9h uptime" is **falsified** — the reservation exists at
   process start; uptime is irrelevant. The earlier 55 GiB sample in the window
   closeout was the BROWSER process, not a renderer.
2. The 9 victims at 1.414 TiB (chromium ×2, chrome-headless ×2 across uid 975 + 1000)
   were killed on RESERVATION pressure: global OOM (CONSTRAINT_NONE, swap exhausted)
   ranks victims by badness, and the kernel's badness heuristic + overcommit handling
   weighs total-vm. The renderers were top-ranked despite ≤1 MB resident.
3. `MemoryMax` on the containing cgroup CANNOT prevent this class: cgroup memory
   limits bound the charge, not the address space. See the containment audit
   (item 3, `hermes-worker-cron` exec scope) for the live MemoryMax state.
4. chrome-headless instances (the §f.21 session-74 spawns) carry the SAME
   renderer-class reservation — any chromium renderer, headless or not.

## Repro hygiene

Repro browser torn down after sampling; scratch under `~/.cache/chromium-repro/` (not /tmp).
