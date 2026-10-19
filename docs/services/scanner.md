# Brother ADS-1800W → Paperless-ngx Intake Runbook

USB-attached ADF scanner feeding the existing Paperless-ngx consume directory. Proven end-to-end 2026-10-19 (scan → convert → consume → OCR → doc ID in ~16 s/doc).

| Piece       | What / Where                                                                                          |
| ----------- | ------------------------------------------------------------------------------------------------------ |
| Device      | Brother ADS-1800W, USB to evo-x2 (`/sys/bus/usb/devices/6-1`, vendor 04f9), SANE name `brother5:bus6;dev1` |
| Driver      | `hardware.sane.brscan5.enable = true` (`platforms/nixos/system/networking.nix`) — sane-backends has NO ADS-1800W support; no IPP-USB/eSCL-over-USB either |
| Wrapper     | `scripts/scan-to-paperless.sh` (repo, shellchecked)                                                    |
| Consume dir | `/mnt/pool/services/paperless/consume` — `PAPERLESS_CONSUMER_RECURSIVE=true`, PATCH-T split, Code-39 ASN, `OCR_LANGUAGE=deu+eng`, `DELETE_DUPLICATES=true` |
| Consumers   | 2 celery workers; OCR_DESKEW + OCR_ROTATE_PAGES on (handles 180° inserts automatically)                 |

## The PNM trap (2026-10-19, live)

`scanimage --batch=whatever.png` writes **PNM data regardless of the filename extension**. ImageMagick reads by content so previews work; Paperless rejects the real mime (`image/x-portable-pixmap` → `ConsumerError: Unsupported mime type`). **Never drop raw scanimage output into consume** — always go through the wrapper (stages raw PNM under `~/.cache/scan-to-paperless/raw/`, converts to real PNG/PDF, then delivers).

## Wrapper usage

```bash
scripts/scan-to-paperless.sh watch            # NON-STOP: duplex, 2-page PDF/sheet,
                                              # auto-delivered whenever the ADF has paper
scripts/scan-to-paperless.sh receipts         # simplex, one PNG per sheet
scripts/scan-to-paperless.sh invoices         # duplex, one 2-page PDF per sheet (front+back paired)
scripts/scan-to-paperless.sh receipts --dry-run  # stage + convert only, nothing consumed
scripts/scan-to-paperless.sh status           # consume depth, scanner, stop-flag, duplicates
```

**Watch mode (campaign default):** runs forever, polls the ADF every ~4 s, grabs paper the moment it is seated. Detach it so it survives the shell/session:

```bash
setsid nohup scripts/scan-to-paperless.sh watch >> ~/.cache/scan-to-paperless/watch.log 2>&1 &
tail -f ~/.cache/scan-to-paperless/watch.log   # live progress + blank-suspect stats
```

Stop gracefully: `touch ~/.cache/scan-to-paperless/STOP` (ends after the current batch). `rc=4` (`sane_start: Invalid argument`) is the feeder-sensor state — paper sits at the feeder but the pick rollers have not engaged; the watch loop treats it as a soft retry (3 s, then backoff capped at 15 s), never a death; physically push the sheet in until the rollers catch. Small receipts: same — the retry cycle grabs them as soon as they are seated far enough; sub-min docs (below 50.8×70 mm) need the Carrier Sheet. `timeout -k 20 300` bounds each batch, but a device that drops off the USB bus can still block the loop for tens of minutes (see durability below).

- Profiles: 300 dpi `24bit Color[Fast]`, `--AutoDocumentSize=yes --AutoDeskew=yes` (driver-level crop/deskew).
- `MultifeedDetection` and `SkipBlankPage` are `[inactive]` in this mode combo — SETTING them fails the scan (parse `scanimage -A` output before adding options). Corollary: stuck sheets can multifeed — a scanned page count larger than the sheets you fed means one sheet passed un-imaged; re-feed it (hash dedup makes an accidental true double harmless, live-proven 2026-10-19).
- `scanimage` exit 7 = ADF drained (expected end of batch; the wrapper treats it as success when frames exist).
- Blank-page guard: per-FRAME brightness stats (both duplex faces included) with `BLANK-SUSPECT` flags for thermal roll leaders, missed prints and folded letter-backs. Warn-only; `--drop-blank` is simplex-only (dropping duplex frames would break front/back pairing).

## Watch durability & staging lifecycle (2026-10-19 10:01 incident)

The scanner dropped off the USB bus mid-scan; `scanimage` stayed blocked in the kernel for 29 min, `timeout` finally returned rc=124 with a header-only truncated PNM, conversion produced nothing, the copy into consume failed — and `die` on that copy failure **exited the whole watch process**. Paper fed for the next 50 min went nowhere and the operator saw an idle machine. Nothing on the batch path may exit the process now:

- `fail()` logs and returns 0; every failure site returns its own status. Only pre-flight errors (missing dependency, missing consume dir, bad args) still `die`.
- `verify_frames()` trims the frame list at the first unusable frame (bad magic or ≤ 1024 bytes — a real smallest-doc 300 dpi frame is ~1.5 MB) and treats everything after it as suspect; the valid prefix still converts and delivers.
- `verify_product()` runs before anything reaches consume: non-empty, not raw PNM, and for PDFs the `/Count` marker must match the expected pages (2 per duplex sheet, 1 for the odd-frame fallback). `gs` is absent, so `/Count` is read with `grep -a` (all 47 live products read `/Count 2`).
- rc=124 has its own branch: it names the timeout, probes `scanimage -L`, and tells the operator to replug the cable (or clear the jam); the batch is dropped and polling continues after 10 s.
- Staging lifecycle: each batch dir is removed the moment it is done with (the empty idle-poll dirs were the real bloat — 1015 dirs / 2.0 GB), delivered products leave `out/`, and startup sweeps anything older than 60 min. First run reclaimed 2.0 GB + 467 MB.
- Restart recipe: `touch …/STOP` → wait for the process to leave (`pgrep -af "scan-to-paperless.sh watch"`) → delete the STOP flag → `setsid nohup … &`; verify with two `idle: ADF empty` lines ≈60 s apart.

**Unbounded failure mode to respect:** a device that drops off the bus blocks the loop for as long as the kernel needs to release the URB (29 min observed). Nothing in-process bounds that — the recovery is physical (replug). This is another argument for the queued systemd-unit conversion (`Restart=always`, journal, boot start).

## Orientation doctrine (receipts)

Printed-side **UP**, head-first. Duplex frame 1 = printed face (watermark backs are fiscal pre-print, zero thermal content). A 180° insert is self-healing: `OCR_ROTATE_PAGES` rotates text pages; receipts read fine either way.

## Consume-dir write path (two layers)

1. **Durable (deployed, `paperless.nix` consumer unit):** root `ExecStartPre` sets dir `2775`; `lars` is in the `paperless` group (`configuration.nix` extraGroups).
2. **ACL bridge (live):** `sudo setfacl -m u:lars:rwx …/consume` — covers sessions with a stale group list.
3. **Readable per file:** the consumer runs as another user, so a delivered file it cannot read is skipped **silently and forever**. A mode-600 phone photo sat in consume from 08:38 to 10:59 (2 h 21 min) with nothing in the journal; only `chmod 0644` unblocked it (consumed as doc 1000493 within 10 s). The wrapper now `chmod 0644`s every delivery — any other producer (manual copy, phone-photo drop) must land `0644` or the file is dead weight nobody reports.

**Hardening lesson (2026-10-19 regression):** a sandboxed `preStart` chmod as the service user EPERMs and start-limit-kills the consumer (dead 04:41–06:14). Before adding any script line to a hardened unit, determine as-which-user/namespace it executes — use the `+`-prefixed root `ExecStartPre`, existence-guarded, and verify via journal, not file modes.

## Campaign playbook (~2000 mixed docs)

1. Sort-after-scan: NEVER pre-sort. Feed receipts (simplex) and invoices (duplex) as encountered; tag ~50–100 docs manually first, then train the classifier (Documents → AUTO → Train Classifier) before bulk-tagging.
2. Duplicates: `DELETE_DUPLICATES=true` stays ON — ADF jam re-feeds are silently dropped by hash; a genuinely double-scanned doc is invisible noise, a missing one is recoverable from the stack. Owner-confirmed default for the campaign (flip in `paperless.nix` if policy changes).
3. Throughput (measured 2026-10-19): ~7 s/sheet scan, ~16 s/doc OCR pipeline (2 workers → pipeline hides behind feeding). ADF = 20 sheets/load ⇒ ~2.5–3 min/load ⇒ 2000 receipts ≈ 4–5 h of pure feeding.
4. Sub-min docs (below 50.8×70 mm): Carrier Sheet required (ADS-1800W spec).
