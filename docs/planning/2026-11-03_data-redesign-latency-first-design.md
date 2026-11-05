# /data Redesign — Latency-First Scoping Design

**2026-11-03 · directive: owner (storage Q&A + 19-02 audit §g-directives) · authored by: storage task-queue session (Task-Queue-ID 000001a1a3299dad1b9b14d9a57a00000000)**
**Status: SCOPING — nothing here is executed. The owner ratifies candidate(s) before ANY change.**
**EXECUTING (instance tq-000001a1a7 batch, §5 probes only — compsize + cold-load harness; NO layout change, 2026-11-04, HEAD `e9b353742`):** executing (see AGENTS.md plan-execution tombstone)
**Constraint ranking (owner, 2026-11-03): model-load LATENCY first. AI models stay on QLC (confirmed).**

---

## 1. Current state (measured 2026-11-03, live probes + AGENTS.md composition line)

| Fact | Value | Source |
|---|---|---|
| Partition | `/data` = `/dev/nvme1n1p8`, **BTRFS subvolid=5 toplevel** (whole partition, no subvol split) | `findmnt /data` |
| Mount options | `rw,noatime,compress=zstd:3,ssd,space_cache=v2,commit=300` | `findmnt /data` |
| Device | Lexar QLC (nvme1 — enumeration flips across boots; resolve via `/dev/disk/by-id`) | AGENTS.md |
| Content | ai 543G (dominant grower; models stay per owner) · SteamLibrary 107G · gcs-staging 24G (reclaim pending) · docker dormant ~10-15G (owner reclaim pending) | AGENTS.md 2026-11-03 probe |
| Pool backup | `btrbk-data` `/data → /mnt/pool` send **structurally DEAD since 2026-07** (EIO csum corruption; repair gate active, T04→T09 chain queued) | `platforms/nixos/system/snapshots.nix:252-284` |
| Excludes | `/data/ai` + SteamLibrary + gcs-staging must NEVER go to the pool (owner directive 2026-11-03: re-downloadable models are never backed up) — queued, not implemented | storage.md row "btrbk-data excludes" |
| Local snapshots | /data has its own rollback tier (never missed a window) | snapshots.nix |
| Code blast radius | **292 references** to `/data` outside docs (units, scripts, collectors, gates) | `rg -c '/data'` 2026-11-03 |
| Alerts | /data 85%/90% usage alerts exist (the ONLY QLC consumer with alerting — ironically the one this audit found healthy) | 19-02 audit §b |

## 2. The latency question — what the ranking constraint actually buys

**Tension to resolve honestly:** the 2026-08-31 Samsung-role design concluded AI models are **bandwidth-bound, not latency-bound** (that is WHY 589G of models stayed on QLC). The owner's 2026-11-03 ranking says latency first. Both are true on different workloads:

- **Pure sequential model load** (llama-server loading a GGUF): bandwidth-bound — QLC sequential reads are fine, FS choice barely matters.
- **The QLC latency cliff is interference-shaped**: SLC-cache exhaustion (write churn → 253 ms writes, fsync ~200 ms, reads stall behind them), btrfs checksum verification on every read extent, snapshot/scrub contention, and CoW metadata churn on mixed workloads. Model loads that coincide with telemetry writes (monitor365 125G on the root, game patching, staging churn) eat the stalls.
- **Consequence:** latency-first is best served by **removing interference and per-read overhead**, not by raw-FS swap. That reorders the candidates below.

## 3. Candidates

### Axis A — filesystem

| # | Candidate | Latency effect | Cost / risk | Verdict |
|---|---|---|---|---|
| A1 | **Stay btrfs, tune per-dir**: `chattr +C` (nodatacow) on model + Steam content dirs (kills per-read csum verification + CoW write penalty on huge files); disable compression where compsize proves incompressible | Direct: no csum verify on reads, no CoW on model writes | Cheap (chattr on dirs, new files inherit; EXISTING files need rewrite to pick it up — the `.rescue` zz-test chattr-cycle lesson applies) · loses csum protection on re-downloadable data = acceptable (owner: NEVER back up models) | **RECOMMENDED first leg** |
| A2 | **Split-FS: models+games move to XFS partition** on the same QLC (best raw sequential latency, no CoW/csum/snapshot overhead) | Highest ceiling | Partition re-provision (btrfs shrinks, XFS does not — order matters); severs pool sends for those dirs **permanently** — NOTE the send is already dead since 2026-07, so this cost is smaller than it reads; 543G copy cycle needs the post-Phase-F headroom (~137G freed) + staging | Only if A1+benchmarks prove a measured gap |
| A3 | ext4/zfs variants | — | ext4: same as XFS minus parallel-read tuning; ZFS: REJECTED already (5 s txg-sync stalls, AGENTS.md) | Rejected |

### Axis B — layout

| # | Candidate | Value | Migration cost |
|---|---|---|---|
| B1 | **Per-domain subvols on the existing FS**: `@data/ai`, `@data/steam`, `@data/scratch`, `@data/staging` | Per-subvol snapshot policies + nodatacow/compression per subvol + **per-subvol btrbk excludes** (aligns exactly with the queued excludes row — subvol-level exclusion is cleaner than path excludes) | Large dirs copy per subvol creation (mv across subvols = copy); sequence inside the post-Phase-F free window |
| B2 | Bind-mount ergonomics aliases (`/models → /data/ai/models`, `/games → /data/SteamLibrary`) | Naming clarity WITHOUT touching the 292-reference blast radius | Near-zero (bind mounts + one unit); reversible |

### Axis C — mount name

- Renaming `/data` itself = touching 292 code references (units, collectors, pre-deploy gates, scripts, alerts) + every machine path habit. Cost is real and one-shot-fragile.
- **Recommendation:** keep `/data` canonical; get the clarity via B2 aliases. A true rename only bundles with A2's re-provision (when paths change anyway), never standalone.

## 4. Sequencing (dependency-ordered)

1. **Phase F shadow reclaim** (queued [watch], auto-go ~2026-11-04/05) — frees ~137G: the headroom every later leg needs.
2. **btrbk excludes** (queued [ready]) — shrink the eventual re-send scope; subvol layout (B1) should be designed to land WITH or BEFORE this, so excludes are per-subvol.
3. **T04→T09 EIO repair chain** (queued, root-gated, next calm window) — the pool pipeline stays dead until this lands; do NOT let any /data re-provision (A2) jump the queue.
4. **A1 tuning leg** (chattr +C + compression off on content dirs) — small, reversible, benchmarkable.
5. **Benchmark protocol** (before AND after each leg): timed llama-server cold load of a representative GGUF + `compsize` pass on `/data/ai` (are model extents even compressed today? open probe) + `bench-disk.sh`. A2 is only justified if A1's after-numbers still miss a target the owner names.
6. **A2 / true rename** — only on owner ratification backed by step-5 data.

## 5. Open probes (agent-executable follow-ups, queued separately)

- **ANSWERED 2026-11-05 (compsize-equivalent pass, §4 benchmark protocol input):** model extents are NOT compressed at rest in any meaningful way — `btrfs filesystem du -s` disk vs logical on every slice of /data/ai: models/jan 113.37/113.38 GiB, models/image 264.03/264.05 GiB, models/fastflowlm 22.62/22.62 GiB, models/gguf 2.16/2.16 GiB, cache 108.51/108.53 GiB, all ratio ≈ 1.000 (515G total, ~0 saved). filefrag -v corroborates: big weight files carry mixed plain + `encoded` extents whose physical spans equal logical spans (encoded-path 1:1 = stored uncompressed), while small JSON/tokenizer files show real gains at negligible size. Controls: 20M repeated text written to /data/ai under calm memory compressed 270:1 (zstd:3 works), the same text under memory PSI ~45 stored encoded-1:1 (pressure-fallback signature), 50M urandom stored plain (heuristic skip). VERDICT for A1: turning compression off on content dirs costs ~zero space (measured on the bytes that matter) and saves the per-write zstd attempts, i.e. the compression-off leg is justified. Method note: `compsize` itself is root-gated here (agent sandbox NoNewPrivileges; unprivileged compsize dies rc=1 silently), but `btrfs filesystem du -s` + `filefrag -v` are both unprivileged and produced these numbers — see docs/agents/storage.md "Compression" for the re-runnable one-liners.
- Cold-load benchmark harness for one representative GGUF (repeatable, PSI-gated)
- What writes churn /data today besides Steam (telemetry lands on the ROOT; verify nothing writes models dirs) — fragmenting-writer evidence added 2026-11-05: the image safetensors sit at ~131KB/extents (195,584 extents for a 25.6G file = max-extent shredding, vs jan GGUFs at 19-84MB/extents), so SOME writer chunks/rewrites the image dir in small pieces (download/merge flow suspected)
- gcs-staging + docker reclaims (owner-gated rows, prerequisites for a clean re-provision if A2 ever fires)

## 6. Decision asks (owner)

1. Ratify A1 (tuning leg) as the first executed step after Phase F?
2. Ratify B1 subvol split as the excludes-row implementation shape?
3. B2 alias names (`/models`, `/games`) — wanted, and which spellings?
4. What cold-load time target would justify escalating to A2 (XFS split)? (Without a target, A2 stays dead.)

## 7. Non-goals

- No data moves before Phase F frees headroom.
- No FS change that severs the (post-repair) pool pipeline for the dirs the owner still wants sent.
- AI models do NOT move to the Samsung (owner: stay on QLC).
- This doc does not implement anything; the excludes row and repair chain own their own work.

---
_Arte in Aeternum_
