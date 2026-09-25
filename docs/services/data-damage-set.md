# /data Damage-Set Inventory

Single source of truth for the /data corruption victims, the scrub evidence, and the snapshot-pinning
timeline. Created 2026-09-25 (task queue) to replace the scattered prose mentions that already lost
context once (the 2026-09-12 gemma GGUF needed a follow-up session because its state lived in three
unlinked surfaces).

Consumes (never duplicates):

- **Origin, repair plan, verification gates:** `docs/todo/storage.md` P0 row (T04–T08, blocked:user).
- **New victims:** `docs/services/jan.md` → "Single-victim /data repair recipe" (this doc is now one
  of that recipe's live doc-sweep surfaces).
- **Timeline:** `AGENTS.md` → BTRFS section → **"Snapshot-pinning doctrine"** (per-fs pin windows +
  live tree table). This doc CITES that table; edit the doctrine there, never here, so the two cannot
  drift.
- `docs/status/**` reports are point-in-time archives — history lives there, state lives here.

## Root cause & scrub evidence

| When        | Evidence                                                                                                                                                  |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-08-03  | Zero-page csum signature `0x8941f998` first documented (reads return zeros = wiped region, not random media rot)                                          |
| 2026-08-17  | Weekly scrub found **1,351,271 uncorrectable csum errors**; aborts `btrfs send` → `btrbk-data` dead since 2026-07 (re-confirmed 2026-09-05: EIO after 3h12m/258G) |
| 2026-09-06  | **Root cause CORRECTED: operator-inflicted unsafe partition shrink, NOT failing hardware** (user correction; supersedes the earlier hardware reading)      |
| 2026-09-11  | **Gate (a) SMART: PASS** — Lexar `QBC838R010854P220C`: `media_errors 0`, `percentage_used 15`, `available_spare 100`, `critical_warning 0`, `error_log_entries 0` |
| 2026-09-11  | **Bounded-static hypothesis remains formally UNPROVEN** — no completed scrub since the 2026-08-31 freeze-killed run; gate (b) (before/after scrub delta) pending, blocked on the scrub-mechanism-fix deploy + a root scrub run |

## Victim set

### Resolved

| Victim                                            | Disposition                                                                                                    |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| inode 1331118 (the journal "headline" for 5+ weeks) | **GONE** — evidence correction 2026-09-11: absent from the full live /data walk AND the newest snapshot; the recurring signal rode stale-era parent chains |
| `models/llm/gemma-4-31b-abliterated-Q8_0.gguf` (~30.4 GiB) | Header EIO (os error 5); **trashed 2026-09-12** to `/data/.Trash-1000` (same-fs rename). Do NOT re-import any re-download without the `dd bs=4k count=1` header validation (jan.md) |

### Live — 10 files, ~49G total (paths resolved 2026-09-11, T05)

All journal-derived bad inodes resolved via one `find /data -xdev \( -inum … \)` walk, each pair
re-verified by `stat -c %i`. **All are re-downloadable AI models / HF-cache blobs — zero unique user
data; NONE is the monitor365 DuckDB** (the T04 safety copy is unaffected). Paths relative to `/data`;
the journal carried ~12 bad (root,ino) pairs, of which 11 enumerated (1 gone above, 10 live here) —
the residual is journal-era noise; the live walk is authoritative. Deletion needs NO root
(`lars:users 644`), only the T06a user sign-off AFTER gate (b).

| root/ino            | Path                                                                                  | Size  |
| ------------------- | ------------------------------------------------------------------------------------- | ----- |
| 256/2114533         | `ai/models/image/perfectdeliberate_v90.safetensors`                                   | 6.9G  |
| 256/2608101         | `ai/models/image/illustrij_v21_diffusers/tokenizer/tokenizer.json`                    |       |
| 256/4020751         | `ai/models/image/sana-1.6b/tokenizer/tokenizer.model`                                 |       |
| 256/4995089         | `ai/models/image/ernie-image/pe/model.safetensors`                                    | 7.7G  |
| 256/1389858         | `ai/models/jan/llamacpp/models/qwen3.6-27b-aggressive/mmproj-f16.gguf`                | 0.9G  |
| 256/1389877         | `ai/models/jan/llamacpp/models/qwen3.6-27b-aggressive/Qwen3.6-27B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf` | 17.5G |
| 256/4971282         | `ai/models/jan/llamacpp/models/llmfan46/gemma-4-26B-A4B-it-ultra-uncensored-heretic-Q4_K_M/mmproj.gguf` | 1.2G |
| 256/2114473         | `ai/cache/huggingface/hub/models--Tongyi-MAI--Z-Image-Turbo/blobs/31349551…`          |       |
| 256/2114488         | `ai/cache/huggingface/hub/models--Tongyi-MAI--Z-Image-Turbo/blobs/95facd59…`          |       |
| 256/2114494         | `ai/cache/huggingface/hub/models--Tongyi-MAI--Z-Image-Turbo/blobs/aba4e37a…`          |       |

## Snapshot-pinning timeline

**Governing doctrine: `AGENTS.md` → BTRFS → "Snapshot-pinning doctrine" table** — /data pin window
≈ 4–5 weeks (14d 4w retention, min 7d); `trash` on /data is a same-toplevel rename that frees
NOTHING (the pin clock starts at trash-time / trash-empty). That table owns the windows; this
section owns only the damage-set's position ON them:

- **7 of the 10 live files** exist in ALL 35 `/data/.snapshots` (20260721T2330 → 20260905T2330);
  **the 3 Z-Image-Turbo blobs** appear from `20260906T2330` on.
- **Repair consequence (refines T06→T09, from the 2026-09-11 round):** delete the 10 live files →
  the 23:30 snapshot is clean → a full `btrbk-data` send of THAT snapshot succeeds and the pool seed
  establishes WITHOUT snapshot surgery (old snapshots keep rollback value; corrupt extents stay
  pinned by them until natural expiry). The two gates DECOUPLE: btrbk-data resumes ~1 day after
  deletion, scrub-clean (T08) greens ~4 weeks later.
- The **gemma trash copy's** extents are pinned by the same /data window — purging
  `/data/.Trash-1000` frees nothing earlier (trash-purge policy is a separate owner decision,
  `docs/todo/storage.md`).

## Change protocol

A new victim (or a state change to any row above) is NOT closed until: the jan.md single-victim
recipe's atomic doc sweep has run (`grep -rn "<filename>" --include='*.md'`) and THIS file's rows are
updated in the same commit. History/appends go to `docs/status/**` reports, never here as narrative.
