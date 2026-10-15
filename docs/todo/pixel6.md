# TODO — Pixel6

Pixel 6 recovery → media-archive project (extraction DONE; remaining: XML pulls, FLAC/Navidrome, whisper transcription, Immich ingestion, call analytics). **DEVICE DECOMMISSIONED 2026-10-01 (owner: phone broke, no longer used)** — all remaining items work on the EXTRACTED archive and stay valid; nothing new can ever be pulled from the device.

Domain LIBRARY of the [TODO system](../../TODO_LIST.md) — every open item for this domain, any lifecycle. The dispatch QUEUE of agent-actionable (`[ready]`) items is `TODO_LIST.md`; the tq pool harvests only the queue.

House rules (enforced by convention, see AGENTS.md → "TODO System"): file an item under the domain that owns the FIX, not the symptom it mentions; one item = one ask + `**Source:**` pointer — verification narratives go to the status report, never the item; `[x]` rows are pruned to `CHANGELOG.md` at every pass; NO system-state narratives here (AGENTS.md and `docs/services/*` runbooks own state).

Tag legend: `[ready]` agent-actionable · `[blocked:user]` needs sudo/browser/external console/owner hands · `[blocked:push]` needs an upstream push/tag (agents implement, never push) · `[blocked:deploy]` waits on a deploy · `[watch]` time-gated verification · `[decision]` owner question.

## Prioritized

- [ ] [ready] **Udev rule for Google USB vendor 18d1 (adb access)** — durable fix for the expiring per-node ACLs; single blocker for every phone-side pull. Also add `pkgs.android-tools` to system packages
- [ ] [blocked:user] **User: install "SMS Backup & Restore" → export SMS/call logs/contacts XML** (resolves the 428 anonymous-number WAVs)
- [ ] [blocked:user] **User: WhatsApp "Back up now" → re-pull fresh msgstore**
- [ ] [ready] **Enrich `universal-call-recorder/index.csv` with call-log contact names** (depends on the XML pull)
- [ ] [ready] **SHA256SUMS for Signal + WhatsApp + Cube ACR sets** (only UCR WAVs have a manifest)
- [ ] [ready] **Full ffprobe sweep over all 591 UCR WAVs** (5 spot-checked only) — feeds the WAV→FLAC mirror integrity
- [ ] [ready] **Add `backups/pixel6` to btrbk-pool snapshot set + backup-coordination freshness**
- [ ] [blocked:user] **Manual `btrfs scrub` on the pool** (~66 GB of new data since last scrub)
- [ ] [decision] **`SIGNAL_RECOVERY_KEY.txt` placement decision (USER)** — plaintext beside the encrypted backup; password manager + delete recommended
- [ ] [ready] **Recover `/tmp/pixel6-*.sh` transfer scripts into `scripts/`** (or reconstruct from the status reports)
- [ ] [ready] **WAV→FLAC mirror of UCR archive** (54 GB → ~18 GB; tag during conversion)
- [ ] [ready] **Navidrome audio-archive server (DECIDED over Jellyfin)** — plan: FLAC conversion + tags (mandatory, Navidrome is tags-only) → `modules/nixos/services/navidrome.nix` (port registry, harden + ioTier.background, pool MusicFolder + RequiresMountsFor, `protectedVHost "music"`, homepage tile, Gatus login-body check) → clients (Tempo/Symfonium, Feishin). Later: whisper transcripts → custom tags → search over what was said
- [ ] [ready] **Whisper transcription batch (GPU) over the 591 calls** — feeds RAG (`:8848`/`:8849` already run) + full-text search
- [ ] [ready] **Call analytics + prefix decode** (0/1/3/5 = direction?)
- [ ] [ready] **Immich ingestion of DCIM + WhatsApp media**
- [ ] [ready] **Human-friendly renamed mirror tree** (hardlink mirror, no extra space)
- [ ] [watch] **Phone care while primary** (95% full, ≥50% charge)
- [ ] [ready] **Pool README day-2 update** (signal key, pending XMLs, Navidrome/FLAC plans)

## Backlog (untriaged harvest)

- [x] [ready] ~~**WAV→FLAC/opus mirror + browsable web archive (player/search) over the UCR call archive**~~ **SHIPPED 2026-09-15 as the Python scripts** (`docs/status/2026-09-15_05-46_pixel6-ucr-sweep-mirror-webarchive-contacts-rag-status.md`); **REHOMED 2026-10-15** to `ucr-archive` v0.1.0 (`ucr encode` + `ucr web`) — SystemNix originals deleted
- [x] [ready] ~~**Contacts VCF export to the pool + per-contact card decode**~~ **SHIPPED 2026-09-15 as the Python scripts**; **REHOMED 2026-10-15** to `ucr-archive` v0.1.0 (`ucr contacts derive` / `decode-vcf`) — SystemNix originals deleted (the index.csv enrichment row covers call-log names, not VCF)
- [x] [ready] ~~**RAG query CLI over the archive**~~ **SHIPPED 2026-09-15 as the Python scripts**; **REHOMED 2026-10-15** to `ucr-archive` v0.1.0 (`ucr rag init/import/embed/ask/stats`) — SystemNix originals deleted ("when did we first talk about X") — rides the whisper-transcription row's output
- [x] [ready] ~~**Extract the UCR pipeline to sibling repo `ucr-archive` (Go rewrite, parity-verified) then delete the Python originals from SystemNix**~~ **DONE 2026-10-15:** `github:LarsArtmann/ucr-archive` v0.1.0 — single `ucr` binary (4 command families), parity-verified per its `README-VERIFICATION.md` (FLAC bit-identity, contacts/web/rag golden diffs on a /tmp sandbox, live root untouched); SystemNix originals (4 .py, 1,475 LOC + ucr-ffprobe-sweep.sh) deleted same day (Source: docs/planning/2026-10-14_22-08_systemnix-zero-python-pareto-plan.md)
