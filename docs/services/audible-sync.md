# Audible Sync (Audible library → HDD pool archive) — Agent Notes

> Module: **upstream** — `github:LarsArtmann/audiblesync` `nixosModules.default` (`nix/module.nix`, the `services.audible-sync` namespace; extraction wave 2026-11-15 — the SystemNix file `modules/nixos/services/audible-sync.nix` was retired; the wrapper `modules/nixos/services/audiblesync.nix` layers the fleet facts: sops authFile, DNS gate, onFailure, harden/ioTier ceilings, backup-coordination row). Created 2026-11-01 (owner ask: "download ALL books I ever bought and or listened to to the HDD, fully automated, at least once a week check").

## STATUS: GO-LIVE 2026-11-10 (enable = true; deploy-gated at authoring time). Owner completed the ONE interactive Amazon login (`audible-quickstart`); the two device credentials were ingested into `platforms/nixos/secrets/audible-sync.yaml` agent-side via runtime-variable expansion (minimal `{"adp_token", "device_private_key"}` shape — sops --set value must be a JSON literal; a bare JSON object gets stored as a nested YAML map, the ingest trap of record). The eval gates caught the module's two unit-level gaps at the flip (main unit lacked `RequiresMountsFor`, dirs unit lacked an ioTier — it had never been eval-exercised at enable=true); both fixed 2026-11-10. The unit's `audible-sync-config-check` ExecStartPre keeps failing loudly if the credential shape regresses.

**Module:** upstream `nix/module.nix` (`services.audible-sync`; SystemNix layer in `modules/nixos/services/audiblesync.nix`) — weekly oneshot (Sunday 05:00, `schedule` option) that syncs the ENTIRE Audible account library to `/mnt/pool/services/audible/`:

1. `audible library export -f json` → `library/library.json` + dated snapshot `library-YYYY-MM-DD.json` (13 kept; the audit trail of "every book in the account")
2. `audible download --all --aax --chapter --cover --pdf` → `downloads/` (skip-if-exists by default → weekly runs are incremental after the first seed; `--ignore-errors` keeps one bad book from blocking the rest — which is why the module adds an explicit zero-download guard: with every audio refused the command STILL exits 0 and only the summary line tells the truth, 2026-11-11 live)
3. per-file `ffmpeg -activation_bytes ... -c copy` remux (AAX pivot 2026-11-11: AAXC vouchers are refused for this customer under every auth shape; plain AAX decrypts via ffmpeg with the sops-rendered activation bytes) → `books/*.m4b` DRM-free — per-file loop so one corrupt file cannot starve the rest; the raw AAX is deleted on success, kept for retry on failure

Freshness: `last_success` marker in `/var/lib/audible-sync/` (touched only when download AND every decrypt passed) → `services.backup-coordination.backups.audible-sync` row (maxAge 240h = 10 days at weekly cadence) → the global `backup_all_healthy` Gatus check alerts on staleness; `onFailure` routes run failures to Discord. NO dedicated tile since the 2026-11-15 extraction: the archive rides the ONE "AudibleSync" Media tile (the former "Audible Sync" Sync & Backup tile merged away — see docs/services/audiblesync.md).

## Why audible-cli and NOT OpenAudible

Moved into the repo 2026-11-17: [`docs/nixos-module.md`](https://github.com/LarsArtmann/audiblesync/blob/master/docs/nixos-module.md) owns the module rationale, the auth shape (including the CORRECTED full-JSON finding — the old "two stable credentials suffice" premise was falsified for downloads), the AAX pipeline and the config-directory trap. This runbook keeps only fleet wiring, state and probes.

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

## Design notes & traps (fleet side only)

- **Auth shape** — the sops secret carries the FULL quickstart auth JSON (12 keys: adp_token, device_private_key, access_token, refresh_token, activation_bytes, WebPlayer cookies, …). The earlier "minimal two-key shape REQUIRED for read-only safety" premise is falsified: read-only auth cannot download audio, and the license server refused AAXC regardless of shape. Update via the pim-sync-proven recipe: `VAL=$(jq -c . ~/.audible/audible.json); STR=$(printf '%s' "$VAL" | env -u DIRENV_DIFF jq -Rs .); ARG=$(printf '["audible_sync_auth_json"] %s' "$STR")` then `sudo -n env SOPS_AGE_KEY="$(sudo -n cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key)" sops --set "$ARG" platforms/nixos/secrets/audible-sync.yaml` (sops 3.13 dropped ssh-key support in its age backend — convert the host key with ssh-to-age; the jq needs `env -u DIRENV_DIFF`, the 2026-10-17 trap).
- **Fleet ceilings** — the wrapper layers `MemoryMax = 1G` + `ioTier.background` + `serviceOneshotDefaults`; the first full seed legitimately runs hours-to-days (`timeout` option, default 48h). Do not shorten it after a "stuck" report without reading the journal phase lines first.
- **Mount gating** — pool dirs are created by the mount-gated `audible-sync-dirs` oneshot (google-sync-dirs pattern: systemd sets up ReadWritePaths namespacing BEFORE ExecStartPre; a missing dir aborts with status=226/NAMESPACE) and listed in `scripts/deploy.sh`'s provisioner restart loop (converger oneshot, RemainAfterExit). **TRAP (live 2026-11-10, fixed `3d92a2ac4`):** the DIRS unit's own `ReadWritePaths` must point at the EXISTING parent (`/mnt/pool/services`), never at the leaf it creates — pointing it at the leaf 226s the unit in a chicken-and-egg on every start (8 failures across 4 deploys on go-live day). Sibling provisioners already follow the parent form (`google-sync-dirs` → `/mnt/pool/backups`, `opencloud`/`tq-agent-pool` → `/mnt/pool/services`); the leaf gate stays on `audible-sync.service`, which starts only after dirs succeeds.

Everything else that used to live here is repo-owned as of 2026-11-17 — AAX vs AAXC pivot, activation bytes, the zero-download guard, decrypt-failure semantics, podcast counting, country/marketplace, credential rotation, what "ALL books" covers, and the `auth_file` absolute-path trap: [`docs/nixos-module.md`](https://github.com/LarsArtmann/audiblesync/blob/master/docs/nixos-module.md).
