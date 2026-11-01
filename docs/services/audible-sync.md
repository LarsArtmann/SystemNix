# Audible Sync (Audible library → HDD pool archive) — Agent Notes

> Module: `modules/nixos/services/audible-sync.nix`. Created 2026-11-01 (owner ask: "download ALL books I ever bought and or listened to to the HDD, fully automated, at least once a week check").

## STATUS: DORMANT — NOT deployed. `services.audible-sync.enable = false`; no units exist on evo-x2. Go-live is a USER sequence (ONE interactive Amazon login + a sops paste), see the checklist below. Do not trust this file as describing a live service until the flip lands.

**Module:** `modules/nixos/services/audible-sync.nix` (`services.audible-sync`) — weekly oneshot (Sunday 05:00, `schedule` option) that syncs the ENTIRE Audible account library to `/mnt/pool/services/audible/`:

1. `audible library export -f json` → `library/library.json` + dated snapshot `library-YYYY-MM-DD.json` (13 kept; the audit trail of "every book in the account")
2. `audible download --all --aaxc --chapter --cover --pdf` → `downloads/` (skip-if-exists by default → weekly runs are incremental after the first seed; `--ignore-errors` keeps one bad book from blocking the rest, but the command STILL exits non-zero if any job failed)
3. `audible decrypt -r -t` per file (vendored plugin + ffmpeg) → `books/*.m4b` DRM-free with rebuilt chapters — per-file loop because the plugin has NO error handling (one corrupt file would starve every book after it in a plain `--all` pass)

Freshness: `last_success` marker in `/var/lib/audible-sync/` (touched only when download AND every decrypt passed) → `services.backup-coordination.backups.audible-sync` row (maxAge 240h = 10 days at weekly cadence) → the global `backup_all_healthy` Gatus check alerts on staleness; `onFailure` routes run failures to Discord. Dashboard tile "Audible Sync" (Sync & Backup group, `openaudible.png` — the dashboard-icons pack has NO Audible glyph, checked upstream 2026-11-01).

## Why audible-cli and NOT OpenAudible

OpenAudible (installed, v4.7.4 AppImage) has **no headless mode** — its own docs describe a GUI app; the Docker image is a browser GUI; the closest thing to remote control is a human-driven `/admin` web page. audible-cli (`mkb79/audible-cli`, nixpkgs 0.3.3) is fully scriptable and its CI-proven auth shape is just TWO STABLE device credentials (`adp_token` + `device_private_key`) — no refresh-token rotation, so the sops-rendered auth file is read-only forever. `~/OpenAudible/books` (existing GUI downloads) is untouched; this service builds its own canonical archive on the pool.

## Go-live checklist (owner, ~10 minutes)

1. **One-time interactive Amazon login** on any machine (2FA/CAPTCHA handled by the quickstart flow):
   ```
   nix shell nixpkgs#audible-cli -c audible-quickstart
   ```
2. **Extract the two stable credentials** (from the quickstart's auth file):
   ```
   jq -r '.adp_token, .device_private_key' < ~/.audible/auth.json
   ```
3. **Paste them into the sops scaffold via the EDITOR** (never a command line — fish_history is plaintext forever):
   ```
   SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) \
     sops platforms/nixos/secrets/audible-sync.yaml
   ```
   Replace the PLACEHOLDER JSON, keeping the shape: `{"adp_token": "...", "device_private_key": "..."}`
4. **Flip + deploy**: `audible-sync.enable = true;` in `platforms/nixos/system/configuration.nix`, then `nix run .#deploy`.
5. **Verify the seed**: `systemctl status` NOT needed — check the journal for the three phase lines (`exporting full library listing` / `downloading full library` / `decrypting to DRM-free M4B`), then `ls /mnt/pool/services/audible/books/`. The FIRST run downloads the whole library (hours to days for a large account; `TimeoutStartSec = 48h`); later runs converge in minutes.

The unit's `audible-sync-config-check` ExecStartPre fails LOUDLY with this exact checklist while the sops value still contains PLACEHOLDER (fail-closed tripwire; nothing can half-deploy against fake credentials).

## Design notes & traps

- **Auth JSON shape (minimal is REQUIRED for read-only safety)** — only `adp_token` + `device_private_key`, mirroring the upstream `mkb79/setup-audible-cli` CI action. A FULL quickstart auth.json (with refresh/access tokens) also works for READING, but the audible library can attempt token write-backs; the minimal shape provably never needs to write (read-only CI runs full library exports with it). audible-cli has NO env-var auth fallback (verified in config.py source) — a real `config.toml` + profile + auth.json in ONE dir is mandatory, hence the ExecStartPre symlink assembly (`AUDIBLE_CONFIG_DIR=/var/lib/audible-sync/config`, `config.toml` from Nix text + `auth.json` sops-rendered symlink).
- **`audible decrypt` is NOT in the PyPI/nixpkgs package** — `plugin_cmds/cmd_decrypt.py` lives outside `src/` upstream, so the module vendors it from a PINNED upstream rev (274539e, hash-pinned fetchurl) into `AUDIBLE_PLUGIN_DIR`. Verified API-compatible with nixpkgs audible-cli 0.3.3 (`pass_session` + `AudibleCliException` exist there; the loader globs `cmd_*.py` from the plugin dir). The plugin needs ffmpeg ≥ 4.4 on PATH (runtimeInputs) and reads the voucher sidecar NEXT to each `.aaxc`.
- **Podcast layout** — parent podcasts/series expand into per-episode downloads inside a SUBDIRECTORY named after the podcast; `*.aaxc` counts can legitimately exceed library item counts (episodes). Do NOT "fix" the count-diff by adding strict item-level comparison — the authoritative failure signal is `audible download`'s own exit code (its `raise_for_errors` fires even WITH `--ignore-errors`).
- **First seed sizing** — `TimeoutStartSec = 48h` (option `timeout`), `MemoryMax = 1G`, `ioTier.background`, `-j 3` (option `jobs`). A full library is GB-to-LOW-TB scale on the HDD pool (12T free at 2026-11); quality = Audible "best".
- **Decrypt failure semantics** — the unit FAILS if any file fails to decrypt (shortfall must be visible, the owner asked for "ALL books"); the raw `.aaxc` + `.voucher` stay in `downloads/` either way. Recovery: delete the corrupt `.aaxc` + `.voucher` so next week re-downloads them. NEVER convert failures into a silent success — that is the phantom-green class.
- **What "ALL books" covers** — everything the Audible library endpoint returns with `status=Active`: all past purchases still in the account + Plus-catalog titles present in the library. Books RETURNED (credit refunded) or removed from the account are NOT downloadable (gone server-side); the weekly `library.json` snapshots make such drift diffable.
- **Mount gating** — pool dirs are created by the mount-gated `audible-sync-dirs` oneshot (google-sync-dirs pattern: systemd sets up ReadWritePaths namespacing BEFORE ExecStartPre; a missing dir aborts with status=226/NAMESPACE) and listed in `scripts/deploy.sh`'s provisioner restart loop (converger oneshot, RemainAfterExit).
- **Credential rotation** — adp_token/device_private_key only invalidate if the Audible device is DEREGISTERED (account device management). If the weekly run starts failing auth, re-run quickstart and re-paste both values.
- **Country/marketplace** — `countryCode` option (default `de`) feeds both `config.toml` (profile country_code) and the `api.audible.<tld>` DNS-gate host. Direct-TLD markets (de/fr/it/es/com) work verbatim; co.uk/com.au markets need a manual host adjustment.
