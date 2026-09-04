# Pixel 6 Recovery — Follow-Up Status (Day 2)

**Date:** 2026-08-21 05:19
**Prior report:** `2026-08-20_09-46_pixel6-full-phone-recovery-to-hdd-pool.md` (the full session ledger — this report updates it)
**Session type:** Follow-up after ~20h gap; since the last report only advisory exchanges happened (SMS B&R explainer, display-repair cost ranges, "interesting next steps" proposals). **No new extraction was executed in this window.**

---

## a) FULLY DONE ✅

1. **Everything from the prior report still stands** — ~62.7 GB / 17,511+ files verified on `/mnt/pool/backups/pixel6/2026-08-20/`:
   - 591/591 Universal Call Recorder WAVs (54 GB, triple-verified) + `index.csv` + `SHA256SUMS`
   - Signal backup byte-exact (9,156 files / 3,684,163,308 bytes)
   - Full shared-storage pull (58 GB / 8,355 files), Cube ACR 2094/2094, WhatsApp media 692 MB
   - UCR APK, metadata, pool README with restore paths
2. **Playback verified** (pipewire, `--target 49`) — user confirmed hearing a 2021 call
3. **Advisory answers delivered** (no tools touched the phone):
   - "SMS Backup & Restore" explainer (what/why/flow/caveats — incl. the call-log→contact-name enrichment for the 428 anonymous WAVs)
   - Pixel 6 display replacement cost ranges (~€60–190 by tier)
   - "What interesting next" menu: whisper transcription → RAG → web archive, FLAC conversion, Immich ingestion, call analytics

## b) PARTIALLY DONE ⚠️

1. **Signal passphrase handling — NEW DEVELOPMENT, mixed:** `SIGNAL_RECOVERY_KEY.txt` now sits in the backup root (user-created since last report; I did NOT write it). Good: the key is preserved. Bad: a **plaintext passphrase stored beside the encrypted backup** on the pool defeats the encryption if anyone but the owner ever reads that share. Flagged, not touched (user's file)
2. **Phone ↔ host adb access is BROKEN AGAIN (live finding from this report's checks):** `adb devices` → "no permissions (user lars is not in the plugdev group)". The phone was replugged overnight → new USB node number → yesterday's `setfacl` fix (node-specific) expired exactly as predicted in prior report e.1. Until re-fixed, NO further pulls are possible (WhatsApp refresh, SMS B&R pull, contact export all blocked on it)
3. **WhatsApp fresh backup** — still not triggered (user decision pending since yesterday)
4. **SMS/call-log/contacts export** — still waiting on the on-phone app install (user was walked through it; no confirmation of install yet)

## c) NOT STARTED ❌

1. SMS + call logs + contacts XML pull (blocked on b.2 + b.4)
2. Call-log enrichment of the 428 anonymous-number WAVs
3. SHA256SUMS for Signal / WhatsApp / Cube ACR sets (only UCR has a manifest)
4. WAV→FLAC conversion, whisper transcription, RAG, web archive, Immich ingestion, call analytics (all proposed, none built)
5. Durable udev rule for Google vendor 18d1 in the NixOS config (the permanent fix for b.2)
6. `scripts/` promotion of the working transfer scripts (still only in `/tmp` — **may already be lost to reboot**; unverified)
7. `btrbk-pool` snapshot coverage + backup-coordination freshness for `backups/pixel6/`
8. Full ffprobe sweep (591 files; only 5 spot-checked)

## d) TOTALLY FUCKED UP 💥

1. **Nothing new broke in this window** (no operations were run). Standing items from yesterday's ledger remain the honest record: silent whole-tree tar stalls (×2), unchecked `trash` failure → wasted skip-run, stdin-eating loop (1/130 dirs "complete"), config edit against removed `programs.adb` option
2. **Process failure worth naming:** yesterday I predicted the ACL-expiry failure mode (prior report e.1) but did NOT act on my own prediction — no udev rule was written while the session had momentum. Today the predicted failure is live and the fix path is colder (needs replug-time context). Lesson: when I identify a known-expiring workaround, the durable fix belongs in the same session

## e) WHAT WE SHOULD IMPROVE

1. **Ship the udev rule now** — `services.udev.extraRules`: Google devices (vendor `18d1`) get `MODE="0660", GROUP="users"` (or tag + ACL). One deploy permanently fixes headless adb. This is now the single blocker for every remaining phone-side task
2. **`SIGNAL_RECOVERY_KEY.txt` placement** — recommend moving the passphrase into a password manager (or sops) and removing the plaintext file from the pool share; at minimum note it in the README's threat model
3. **Scripts out of `/tmp`** — verify `/tmp/pixel6-*.sh` survived; if not, they're gone with the working logic and must be rewritten from the status reports
4. **Checksums beyond UCR** — Signal/WhatsApp/Cube sets have no integrity manifest; bitrot in them would be silent
5. Same as prior report: verification-first transfer discipline, pool ownership convention, btrbk coverage, UTC↔CEST labeling

## f) UP TO 50 NEXT TASKS

**Unblock the phone (do first)**

1. Write + deploy udev rule for vendor 18d1 (`boot.nix` extraRules or tiny module)
2. Verify `adb devices` shows `device` again after deploy + replug
3. Check `/tmp/pixel6-*.sh` survival; if lost, reconstruct into `scripts/` (with stall detection + count verification baked in)
4. Add `pkgs.android-tools` to system packages (kill the per-call `nix shell` overhead)

**Finish the recovery**
5. User: install "SMS Backup & Restore" → export SMS/call logs/contacts XML
6. Pull the XMLs → verify counts → parse call log
7. Enrich `index.csv`: join 428 anonymous WAVs (number+timestamp) → contact names
8. User: WhatsApp "Back up now" → re-pull `Android/media/com.whatsapp` → fresh msgstore
9. Contacts VCF → pool; optionally decode into per-contact cards
10. Re-run README contents table with day-2 additions (SIGNAL_RECOVERY_KEY note, XMLs)

**Integrity & durability**
11. SHA256SUMS for Signal backup tree
12. SHA256SUMS for WhatsApp media + Databases
13. SHA256SUMS for Cube ACR archive
14. Full ffprobe sweep over all 591 UCR WAVs (truncation detection)
15. Add `backups/pixel6` to `btrbk-pool` snapshot set
16. Register pool backup freshness in `backup-coordination` (Gatus alerting)
17. Kick a manual `btrfs scrub` on the pool (66 GB of new data since last scrub)
18. Move/passphrase-manage `SIGNAL_RECOVERY_KEY.txt`; document decision

**Make it valuable (the fun tier)**
19. WAV→FLAC mirror (54 GB → ~18 GB, lossless; keep originals)
20. whisper.cpp transcription batch on GPU (gfx1150 ROCm) — 591 calls
21. Merge transcripts into `index.csv` (text column)
22. RAG: embed transcripts via llama-rag (`:8848`) + reranker (`:8849`)
23. Query CLI/script: "when did we first talk about X"
24. Web archive app (browse by contact/date, inline player, full-text search)
25. Call analytics: per-contact frequency heatmap, timeline of the relationship
26. Decode UCR prefix semantics (0/1/3/5) definitively
27. Immich ingestion of DCIM + WhatsApp media
28. Human-friendly renamed mirror tree (hardlinks, no extra space)

**Ops hygiene**
29. Phone storage at 95% — user cleanup advisory (user-only; we never delete)
30. Keep phone ≥50% charge while it remains a primary copy
31. Pool dir ownership convention (`backups/<thing>` pre-owned lars:users)
32. Document phone-recovery runbook in repo docs (from these two reports)
33. TODO_LIST/docs-health pass to fold actionable items forward

## g) QUESTIONS I CANNOT ANSWER MYSELF (max 3)

1. **Did you put `SIGNAL_RECOVERY_KEY.txt` on the pool intentionally as the long-term home for the passphrase?** If yes, I'll document it (and its risk) in the README; if it was temporary, I'd recommend relocating it to your password manager — your call, I won't touch it either way
2. **Did anything happen on the phone overnight** (WhatsApp backup tapped, SMS B&R installed, or nothing yet)? Phone-side truth is currently unreadable to me (see b.2) and I don't want to guess
3. **Proceed with the udev-rule deploy now?** It's a one-line `extraRules` addition + `nix run .#deploy` — it unblocks every remaining phone task permanently, but it's a system change during a session whose mandate has been read-only-on-the-phone (host config change, phone untouched — want the green light)

---

**Bottom line:** the 62.7 GB archive is intact and verified; nothing regressed. The live frictions are (1) adb access expired on replug — durable fix identified, one deploy away, (2) passphrase file placement decision, (3) the last three data classes (SMS/call-log/contacts, fresh WhatsApp) still waiting on small on-phone actions.

_Report generated by Crush session 2026-08-21 05:19._
