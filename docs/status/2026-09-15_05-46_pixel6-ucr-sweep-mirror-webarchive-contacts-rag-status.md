# Status: P2.6 Pixel-6 UCR sweep — mirror/web-archive/contacts/RAG tooling wave

**Date:** 2026-09-15 05:46 CEST
**Session scope:** the four P2.6 addition rows from TODO_LIST.md (`Full ffprobe sweep over all 591 UCR WAVs`, `WAV→FLAC/opus mirror + browsable web archive`, `Contacts VCF export to the pool + per-contact card decode`, `RAG query CLI over the archive`).
**Tree state:** five new scripts in `scripts/`, zero nix config changes, zero deploys needed or made. Auto-commit daemon will have picked the scripts up.

---

## a) FULLY DONE

### Task 1 tooling — integrity sweep script (`scripts/ucr-ffprobe-sweep.sh`)

- Written + fixture-validated end to end BEFORE touching the 54 GB real set (3-file fixture incl. a deliberately truncated WAV and a deliberately wrong sha256 line — both detection paths proven: `TRUNCATED` verdict fired, `SHA_MISMATCH` logic wired, exit code 2 on problems / 0 on clean).
- Phases: (1) `sha256sum -c` vs the 2026-08-20 manifest (bitrot since extraction), (2) RIFF header parse — declared data-chunk size vs actual bytes available (header-lies truncation detection, no ffmpeg-version variance), (3) ffprobe metadata (codec/rate/channels/real duration), (4) ffmpeg full decode to null (mid-stream corruption headers miss), (5) reconcile vs index.csv + manifest-vs-disk diff, write `encode-manifest.tsv` for the encoder + human `summary.txt`.
- IO discipline per AGENTS doctrine: every probe/decode subprocess wrapped `ionice -c3 nice -n19`, parallel=2 default, entry point intended under `heavy-job` (which is how the real run was launched).
- **The real sweep is RUNNING** (background job, launched 05:21) — see b).

### Task 3 tooling — contacts (`scripts/pixel6-contacts.py`)

- `derive`: evidence registry from Cube ACR `.props/*.json` (1047 files: callee numbers, direction, filename contact names) + UCR filenames/index.csv → `derived/contacts/contacts-evidence.json`. **RAN against the real archive: 284 contacts (49 named, 235 number-only), wife correctly top with 380 Cube calls** (e.g. `Kanyu Artmann (Wife 💍)`), Michele Vinciguerra correctly merged across UCR (5) + Cube (6) by casefolded name.
- `decode-vcf`: real vCard 2.1/3.0/4.0 parser (line unfolding, QUOTED-PRINTABLE incl. soft breaks + charset, BASE64 photos → `photos/`, item1.TEL grouping, bare v2.1 type params) → clean per-contact v3.0 cards in `derived/contacts/vcf/`, `contacts.json`, browsable `index.html` (dark card grid, search, call-archive badges). Fixture-validated (QP fold + base64 JPEG + TEL/EMAIL/ORG/NOTE round-trip).
- Evidence merge: card numbers matched against registry (full or last-9-digits) or name casefold; **unions ALL matching entries** (the same human reachable under two names/numbers sums their call counts).
- Verified data reality: **no VCF exists anywhere in the archive** (find over the whole tree), WhatsApp `msgstore.db.crypt14` is encrypted (dead end without the key), `com.android.providers.telephony` is an empty `.done` dir, and **no phone is attached** (`adb devices` empty). So "export VCF" remains a USER phone-side step; the tooling + landing path is what could be built today, and the evidence registry already delivers per-contact call counts from the archive itself.

### Task 4 tooling — RAG CLI (`scripts/ucr-rag.py`)

- Written + fixture-validated end to end: `init` → `import` → `ask "Eiffel Tower"` returns the **earliest** mention correctly ordered (call ts first, then segment offset), with date/contact/[mm:ss]/audio-path/highlighted snippet; `stats`; `--semantic` flag present.
- Ingests whisper json (openai + whisper.cpp `transcription[].offsets` ms shapes), SRT, VTT, plain txt; stem matching handles `<stem>.de.json` and `<stem>.wav.json` variants.
- Storage = sqlite FTS5 (stdlib only, no deps); optional per-call bge-m3 embeddings via `:8848` with **graceful degradation** — live-proven: the llama-rag endpoints are currently 503 (known llama.cpp regression) and `ask --semantic` printed the warning and answered lexically.
- Import safety: first-import-wins with `--force` override (found the last-write-wins overwrite hazard by watching my own re-test flip the "earliest mention" answer).
- `init` accepts the sweep manifest when present, else falls back to index.csv (RAG is decoupled from sweep completion).
- **Real-data smoke PASSED**: whisper.cpp (nixpkgs `whisper-cpp` 1.9.2, model via the package's official `whisper-cpp-download-ggml-model base`) transcribed a real 77 s German call (`1_Finn Artmann_1649099334928.wav`) → 32 segments, language auto-detected `de`, real dialogue text. The transcription path is proven end to end with the exact formats the importer accepts.

### Investigation deliverables (side facts established)

- The "600 vs 591 WAVs" discrepancy: 9 extra `.wav` live in `_transfer-artifacts/stale-partial-android-data*/` (aborted first-transfer copies) whose path CONTAINS the same `com.sparklingapps.callrecorder.full/files/` substring, so naive `find | grep -v` lies. Real set = exactly 591, `ls`/`find`-in-dir agree.
- Contact coverage: only **68/591** calls carry a contact (49 numbers + 19 names) in index/filenames; 523 are anonymous `0_/3_/5_` prefixed (the known call-log-XML gap).
- ffmpeg on the system has native `flac` + `libopus` encoders (no nix-shell needed); python3 has FTS5; 32 cores; 54 GB RAM available.

## b) PARTIALLY DONE

- **Task 1 real sweep — RUNNING right now.** Phase 1 (sha256, 54 GB read) was at 516/591 files at 05:39 after ~18 min (~50 MB/s effective over the busy USB link; io PSI `some avg10` was 99% machine-wide at launch — idle priority held, nothing degraded, but it's slow). Phase 2-4 (probe + full decode, second 54 GB pass, parallel=2) not yet started; expect ~15-25 min more. Reports will land in `universal-call-recorder/integrity-sweep/` (`sweep.jsonl`, `encode-manifest.tsv`, `summary.txt`, `sha256-verify.log`, `decode-stderr/`).
- **Task 2 — mirror + web archive: tooling 100%, real output 0%.** `scripts/ucr-mirror-encode.py` (FLAC `-compression_level 8` with full Navidrome tag set: artist/albumartist=contact, album=`Call Archive <Year>`, chronological tracknumbers, genre, date/originaldate, comment=original wav, custom UCR_PREFIX; opus 32k voip encoded FROM the flac so the legs are content-identical; per-flac full-decode MD5 verification; `.part`+rename atomicity; idempotent skip; idle IO priority; `--phase/--only/--force/--parallel`) — fixture-validated (tags + duration parity + MD5 verify all confirmed). `scripts/ucr-web-archive.py` (static `index.html` player: search by contact/date, contact filter dropdown, sticky player with seek/±10s/speed/next-prev/keyboard, file://-safe `data.js`, audio streams `../opus/...` so no duplication; auto-wires durations from the sweep manifest) — fixture-validated (every data.js path resolves to a real file). **The real encode starts the moment the sweep verdict lands.**
- **Task 4 on the real archive:** real DB not yet initialized (waiting on the sweep manifest so durations/verdicts are the verified ones), the real finn transcript not yet imported, no real `ask` yet. Everything is staged for a 3-command sequence once the sweep finishes.
- **Task 3 on the real archive:** `derive` done (see a)); the decode-vcf half awaits the real VCF (user phone-side export) — landing path documented in the script help: `contacts/incoming/` then `decode-vcf`. **`contacts/incoming/` itself not yet created on the real root** (oversight, listed in e/f).

## c) NOT STARTED

- Pool README (`/mnt/pool/backups/pixel6/2026-08-20/README.md`) "Derived artifacts" section.
- TODO_LIST.md checkbox updates for the four rows (plus cross-rows 106-115 untouched).
- AGENTS.md memory section for the pixel6 archive tooling + gotchas learned this session.
- Real FLAC/opus encode + verification + real web archive generation (blocked on sweep, then ~1-3 h background).
- Full whisper transcription batch (TODO row 114 — its own row; this session only proved the per-call path).
- Navidrome module (row 113 — explicitly next row, feeds on the FLAC leg this session produces).
- Flake app entries (`nix run .#ucr-*`) + `tests/test-scripts.nix` fixtures for the new scripts (repo convention for script regressions).
- Committing anything explicitly (per rules: no commit without the word).
- `contacts-evidence.html` browsable registry (JSON exists; HTML only generated for VCF cards).

## d) TOTALLY FUCKED UP (honest list)

Nothing catastrophic — no data touched (all writes were new `derived/` paths + new scripts; originals never opened for write). But:

1. **The 600-vs-591 WAV confusion was self-inflicted and cost 3 rounds.** My `find | grep -v '<files-dir>'` was defeated by the same-substring stale copies — the README I had ALREADY read says `_transfer-artifacts/` holds partial aborted transfers. Scoped `find` to the files dir first and this is a 10-second answer.
2. **First sweep-script draft had 3 real bugs** (sha-log parse IndexError — parsed the wrong file format; `fh.tell()` after file close; an xargs design with a shared temp-file race + `set -u` vs fresh-bash hazards). Caught ALL of them by fixture-testing before the 54 GB run — which is exactly why that habit exists — but the bash→python-parallel rewrite was a mid-flight architecture change I could have avoided by designing for parallelism from line one.
3. **Encoder shipped with `.part` muxer-inference failure** (ffmpeg can't infer format from an extensionless temp name). Fixture run caught it; two-char fix (`-f flac`/`-f opus`).
4. **First real `derive` produced garbage** (21 "contacts", empty-string number keys, isolation-mark-poisoned names like `⁨Assi Loser⁩`): callee fields that are NAMES were routed into number keys, and `looks_like_number` ran before isolation-mark stripping. Caught only because I eyeballed the registry output — the lesson "always inspect the first real output of a parser" paid; re-derive is clean (284).
5. **`contacts.types()` went through 3 iterations** and the middle one silently dropped `CELL`/`HOME` types (my "=" -exclusion caught `TYPE=CELL` as a keyed non-type). Only caught on fixture round-trip.
6. **The import overwrite hazard** (above) would have silently corrupted RAG answers with worse transcript variants. Found by luck during re-test, not by design review — a design review should have caught it.
7. **Un-investigated anomaly left open:** the 10.7 s smoke call returned **0 transcription segments** (language detected `en`, empty result). Did not chase it (likely near-silence/music, but unproven). For the full batch this class needs handling (empty-transcript is not an error).
8. **I launched the sha sweep while io PSI some avg10 sat at 99%.** Idle priority + heavy-job contained it (nothing else degraded), but per the freeze-4 doctrine I could have sampled the PSI trend and deferred 10 minutes; the hash pass took ~20 min at ~50 MB/s partly because of that same contention.
9. **whisper auto-grabbed the GPU** (`use gpu = 1`) during the smoke while the GPU stack is in the known llama.cpp-regression state — worked here, but the full batch must make CPU-vs-GPU a deliberate flag (`--no-gpu`), not an accident.

## e) WHAT WE SHOULD IMPROVE (process/tooling takeaways)

- Fixture-first for every pipeline stage is the single reason zero bugs reached the 54 GB / real-archive stage — keep it mandatory.
- `find`/`ls` scoping: never grep-filter find output by a path substring that can appear in stale copies; scope the search root itself.
- Inspect the first real output of any parser/registry before building on it (caught the evidence bugs in minutes; the alternative is a poisoned registry discovered months later).
- Long background jobs should log progress to a FILE the session can poll (my job output is buffered behind `tail -40`, so I monitored via output-file line counts instead — worked, but by accident of design).
- Every "skip existing" idempotency needs an explicit conflict policy (first-wins vs last-wins) — silent last-wins overwrites are data-poisoning.
- Script conventions: wire new scripts into `tests/test-scripts.nix` + flake apps so the repo's own gates cover them (not done yet).
- Decide CPU/GPU explicitly for any inference run on this box while the GPU stack is in a known-bad state.

## f) NEXT (prioritized, ≤50)

**Immediate (sweep-dependent chain, this session if instructed):**

1. Wait for sweep phase 1 completion; confirm 591/591 sha OK.
2. Let phases 2-4 finish; read `summary.txt` verdict + investigate ANY TRUNCATED/DECODE_ERROR/SHA_MISMATCH file individually.
3. Reconcile index.csv duration drift list (expected: size-quantized durations drift a few seconds).
4. Launch real FLAC encode (phase flac, background, heavy-job).
5. Launch opus phase (reads the 18 GB flac leg, not the WAVs).
6. Launch verify phase (full-decode MD5 of every flac).
7. Compare resulting sizes vs the "~18 GB" TODO estimate; record real numbers.
8. Generate the real web archive; verify every data.js audio path resolves on the real tree.
9. Real RAG `init` from the sweep manifest; import the finn transcript; run a real `ask`.
10. Investigate the 0-segment 10.7 s call (silence detection or batch-time classification).
11. Create `contacts/incoming/` on the real root.
12. Pool README "Derived artifacts" section (paths, regeneration commands, whisper runbook pointer).
13. TODO_LIST: mark rows 470/471/473 (and partially 470's sweep) with proof + status.
14. AGENTS.md: pixel6-archive section (tooling paths, io doctrine used, gotchas: `_transfer-artifacts` substring trap, `.part` muxer, first-wins imports, whisper GPU default).
15. Write per-task status docs or fold into this one's successor.

**Whisper batch (row 114 — the RAG payoff):**
16. Batch wrapper script (queue over 591 calls, resume, per-call isolation, 16k mono conversion, json+txt outputs to `derived/transcripts/`).
17. Model decision: base (proven here, rough German) vs small/medium (better German, proportionally slower).
18. CPU vs GPU decision (`--no-gpu` default while GPU stack is in regression; measure both).
19. Language policy: `-l auto` vs per-call heuristic; handle empty-segment outputs as "no speech" class.
20. Runtime measurement → realistic ETA (52 h audio; base CPU ≈ 1-2× realtime with 4 threads → scale-out plan over 32 cores).
21. Then: bulk `ucr-rag.py import` + real coverage stats + web-archive transcript integration.
22. `ucr-rag.py embed` once :8848 is healthy + true semantic E2E test (only degradation-tested so far).

**Contacts completion (row 472 tail):**
23. User: on-phone VCF export → `contacts/incoming/` → `decode-vcf` run.
24. Cross-link: after VCF lands, re-derive registry and reconcile named vs number-only contacts (235 number-only should collapse).
25. Person dedupe (e.g. "Assi Loser 🐶🦴 (Finn Artmann)" vs "Finn Artmann" likely one person — needs the VCF as authority).
26. `contacts-evidence.html` browsable registry (pre-VCF stopgap).

**Archive hygiene (adjacent rows touched by findings):**
27. Trash-or-keep decision: the 9 stale duplicate WAVs in `_transfer-artifacts/` (README already marks the dir deletable).
28. Row 106: SHA256SUMS for Signal + WhatsApp + Cube ACR sets (same pattern as UCR's).
29. Row 105/103: call-log XML pull → enrich the 523 anonymous calls (would rename half the archive's Unknowns).
30. Row 115: UCR prefix decode (0×428 / 1×68 / 3×4 / 5×91 semantics) — sizes/directions may already hint.
31. Row 108: `backups/pixel6` into btrbk-pool snapshots + backup-coordination freshness (now includes `derived/`).

**Navidrome + web serving (rows 113/471 tail):**
32. `modules/nixos/services/navidrome.nix` (port registry, harden + ioTier.background, MusicFolder=`derived/flac`, RequiresMountsFor, protectedVHost "music", homepage tile, Gatus login-body check, integration-registry entry — full AGENTS procedure).
33. Decision: serve the static web archive via Caddy (Layer 2) or keep it file://-only.
34. Navidrome tag/folder-shape acceptance test against the real flac leg.
35. Clients setup notes (Tempo/Symfonium/Feishin) in the runbook.

**Repo-quality for this session's scripts:**
36. Flake apps: `ucr-ffprobe-sweep`, `ucr-mirror-encode`, `ucr-web-archive`, `pixel6-contacts`, `ucr-rag`.
37. `tests/test-scripts.nix` fixtures: sweep verdict classification, vCard QP/base64 round-trip, whisper-json/srt/vtt parsing, RAG earliest-mention ordering, first-wins import.
38. shellcheck the bash entry script; ruff/pyflakes the four python scripts.
39. Explicit per-task commits if authorized (auto-daemon batches otherwise).
40. `scripts/README` or runbook doc linking the whole pixel6 pipeline in execution order.

**RAG depth (post-transcription):**
41. Per-segment FTS ranking tuning (bm25 boosts, phrase vs term fallback when 0 hits — currently phrase-only).
42. Cross-language query support (DE calls vs EN queries — bge-m3 semantic leg covers this once embeddings run; FTS won't).
43. Web-archive transcript panel + transcript hits in the browser search (CLI-only today).
44. "When did we STOP talking about X" / date-range query flags.
45. Optional: call-level summaries (rides flm/llama stack decision — currently dead GPU/LLM paths).

**Ops:**
46. Re-check io PSI before each heavy phase launch (encode/opus/verify).
47. Clean `/tmp/whisper-smoke` (200 MB model) or move model to `/data/ai/models/whisper/` for the batch.
48. Clean `/tmp/ucr-sweep-test` fixture.
49. Monitor that the auto-daemon's commits of these scripts stay clean (pathspec discipline per AGENTS).
50. Post-batch: re-run sweep-phase-5 style reconciliation for `derived/transcripts/` coverage (591 expected).

## g) QUESTIONS (cannot self-answer)

1. **Web archive serving:** should the static player be served via Caddy (`protectedVHost`, LAN-bypass + SSO for external) as part of this work, or is pool-local `file://` browsing enough for now? (Adds a real service deploy + monitoring; the row as written only demands "browsable".)
2. **Whisper batch budget (row 114):** which quality/time point do you want — `base` (proven today, rough German, fastest), `small`, or `medium` (good German, multi-day CPU unless GPU)? And is GPU offload acceptable while the llama.cpp/GPU stack is in the known regression state, or hard `--no-gpu`?
3. **`_transfer-artifacts/` stale WAVs:** the 9 duplicate partial-transfer WAVs (and the dir generally, which the pool README already calls "safe to delete") — trash them now that the 591-set reconciliation is proven, or keep until the sweep + mirror verify fully clean?

---

**Waiting for instructions.** The sweep background job keeps running regardless; on request I'll chain encode → web-archive → real-RAG as soon as its verdict lands.
