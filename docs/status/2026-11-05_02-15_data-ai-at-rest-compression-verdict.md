# /data/ai At-Rest Compression Verdict (compsize-equivalent pass) — 2026-11-05

**Task queue:** storage batch item 2 (`Task-Queue-ID: 000001a1a7beb2a2a335067e979f00000000`), Source: docs/planning/2026-11-03_data-redesign-latency-first-design.md §5. **Instance:** tq-000001a1a7 re-dispatch (the plan header's EXECUTING marker covers this batch, §5 probes only, NO layout change).

## Verdict

**Model extents are NOT compressed at rest in any meaningful way.** Despite `compress=zstd:3` on /data, every /data/ai slice stores at ratio ≈ 1.000. The A1 compression-off leg (chattr +C / compression off on content dirs) is justified: ~zero space cost measured on the bytes that matter, and it removes the per-write zstd attempts.

## Numbers (btrfs filesystem du -s, unprivileged, 2026-11-05 01:5x)

| slice | files | logical | disk (Total) | ratio |
| --- | --- | --- | --- | --- |
| models/jan | 8,061 | 113.38 GiB (121,730,522,448 B) | 113.37 GiB | 1.000 |
| models/image | 456 | 264.05 GiB (283,502,339,353 B) | 264.03 GiB | 1.000 |
| models/fastflowlm | 10 | 22.62 GiB (24,292,111,297 B) | 22.62 GiB | 1.000 |
| models/gguf | 4 | 2.16 GiB (2,317,448,266 B) | 2.16 GiB | 1.000 |
| cache | 429 | 108.53 GiB (116,511,938,587 B) | 108.51 GiB | 1.000 |

~0 of 515 GiB saved. Exclusive = 0.00 B and Set shared 82–98% everywhere: btrbk /data snapshots pin essentially the whole tree (reclaim = snapshot expiry, Phase F context).

## Corroborating extent evidence (filefrag -v, top files per slice)

- Big weight files carry MIXED plain + `encoded` extents where encoded extents show physical span == logical span (encoded-path 1:1 = stored uncompressed): gemma-31B-Q6 121/311 encoded, Qwen35B 840/1269, image safetensors ~99% encoded, krea2_turbo-Q8_0.gguf 0/33 (plain), a 22.4G cache blob 84/793 (mostly plain).
- Only small JSON/tokenizer files realize real ratios (tokenizer.json/mmproj pair: 100% encoded) — negligible size.

## A/B controls (fresh writes, /data/ai)

- 20M repeated text written under calm memory (mem PSI ~1.7): compressed to 76 KiB = **270:1** — zstd:3 on /data WORKS when memory is calm.
- Same text written under memory PSI ~45 (swap active): stored `encoded` at 1:1 — the memory-pressure fallback signature explains encoded-without-gain extents.
- 50M urandom: plain extents (encoded=0) — the heuristic skip fires on truly random data, so model weights sit in the gray zone: zstd attempts, gains ~nothing, stores ~1:1.

## Method notes

- `compsize` is root-gated here: the agent sandbox sets no-new-privileges (sudo hard-fails from agent shells, typed or script-internal), and unprivileged compsize dies rc=1 silently on this host. This CORRECTS docs/todo/storage.md row 97's "root needed for FIEMAP" framing: `btrfs filesystem du -s` and `filefrag -v` both run unprivileged and produced these numbers (filefrag FIEMAP works fine as user; its final SEARCH_V2 ioctl EPERMs harmlessly).
- Raw outputs: ~/.cache/data-ai-compsize/SUMMARY.txt + per-dir .txt (volatile cache; the numbers above are the durable record).

## Side findings

- **Image safetensors are max-extent shredded**: ~131KB/extents (195,584 extents for a 25.6G file) vs jan GGUFs at 19–84MB/extents — some image-dir writer (download/merge flow suspected) fragments the biggest model slice badly; directly multiplies QLC cold-read seek cost. Harvested to TODO_LIST (fragmentation-writer attribution row).

## Surfaces updated (this batch)

- Design doc §5 probe 1 → ANSWERED with the numbers above; probe 3 (churn writer) enriched with the fragmentation evidence.
- docs/todo/storage.md row 221 → [x] ANSWERED (with method + row-97 correction); TODO_LIST.md row → [x] ANSWERED.
- docs/agents/storage.md "BTRFS (evo-x2)" → new "Measured at-rest compression on /data" paragraph with the re-run one-liner.

## Follow-up harvest

- Fragmentation-writer attribution → TODO_LIST new [ready] row (agent-executable). No other direct follow-ups from this item; deliberately not harvested: the fleet-wide compsize brainstorm (stays with its own audit thread).
