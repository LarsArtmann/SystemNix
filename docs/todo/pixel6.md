# TODO — Pixel6

Pixel 6 recovery → media-archive project (extraction DONE; remaining: XML pulls, FLAC/Navidrome, whisper transcription, Immich ingestion, call analytics).

Domain LIBRARY of the [TODO system](../../TODO_LIST.md) — every open item for this domain, any lifecycle. The dispatch QUEUE of agent-actionable (`[ready]`) items is `TODO_LIST.md`; the tq pool harvests only the queue.

House rules (enforced by convention, see AGENTS.md → "TODO System"): file an item under the domain that owns the FIX, not the symptom it mentions; one item = one ask + `**Source:**` pointer — verification narratives go to the status report, never the item; `[x]` rows are pruned to `CHANGELOG.md` at every pass; NO system-state narratives here (AGENTS.md and `docs/services/*` runbooks own state).

Tag legend: `[ready]` agent-actionable · `[blocked:user]` needs sudo/browser/external console/owner hands · `[blocked:push]` needs an upstream push/tag (agents implement, never push) · `[blocked:deploy]` waits on a deploy · `[watch]` time-gated verification · `[decision]` owner question.

## Prioritized

- [ ] [ready] **Udev rule for Google USB vendor 18d1 (adb access)** — durable fix for the expiring per-node ACLs; single blocker for every phone-side pull. Also add `pkgs.android-tools` to system packages
- [ ] [blocked:user] **User: install "SMS Backup & Restore" → export SMS/call logs/contacts XML** (resolves the 428 anonymous-number WAVs)
- [ ] [blocked:user] **User: WhatsApp "Back up now" → re-pull fresh msgstore**
- [ ] [ready] **Enrich `universal-call-recorder/index.csv` with call-log contact names** (depends on the XML pull)
- [ ] [ready] **SHA256SUMS for Signal + WhatsApp + Cube ACR sets** (only UCR WAVs have a manifest)
- [ ] [ready] **Full ffprobe sweep over all 591 UCR WAVs** (5 spot-checked)
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

- [ ] [ready] **Full ffprobe sweep over all 591 UCR WAVs** (5 spot-checked only) — feeds the WAV→FLAC mirror integrity
- [ ] [ready] **WAV→FLAC/opus mirror + browsable web archive (player/search) over the UCR call archive** — Navidrome feeds on the FLAC leg
- [ ] [ready] **Contacts VCF export to the pool + per-contact card decode** (the index.csv enrichment row covers call-log names, not VCF)
- [ ] [ready] **RAG query CLI over the archive** ("when did we first talk about X") — rides the whisper-transcription row's output
