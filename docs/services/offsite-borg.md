# Offsite Borg (Hetzner StorageBox)

Third copy for 3-2-1: btrbk snapshots are same-disk, the HDD pool is
same-chassis — the StorageBox (BX11, 1 TB) is the offsite leg. Borg over SSH
port 23 (Hetzner's first-class Borg port), `repokey-blake2` encryption so the
provider sees only ciphertext. Decision rationale + protocol research:
`docs/research/hetzner-storagebox-borgbackup.md`.

**Status: implemented, DORMANT** (`services.offsite-borg.enable = false`).
Go-live is owner-gated — the StorageBox hostname/username do not exist in any
secret yet (tracked as "Offsite Borg go-live inputs" in `docs/todo/storage.md`).

## What exists (2026-09-22)

| Piece | Where |
| ----- | ----- |
| Module | `platforms/nixos/system/backup.nix` (`services.offsite-borg`) |
| Secrets | `platforms/nixos/secrets/borg.yaml`: `borg_password` (REAL random value, generated at implementation), `borg_ssh_key` (dedicated ed25519), `borg_known_hosts` (PLACEHOLDER), `borg_repo` (PLACEHOLDER) |
| Job | `services.borgbackup.jobs.hetzner` → `borgbackup-job-hetzner.service` + timer (06:30 daily, `Persistent`) |
| Cache | `/mnt/hot/borg/{cache,config}` (Samsung hot tier — multi-GB caches on `@` would be pinned pool-side by btrbk snapshots forever) |
| Monitoring | `backup_healthy{backup="offsite-borg"}` marker in `/var/lib/borg-offsite/.last_success` → backup-coordination + the aggregate "All Backups Healthy" Gatus check; the shared loop also emits `backup_ever_succeeded{backup="offsite-borg"}` (MTIME≠0 gate — never-worked vs stale); job unit rides `ioTier.background` (BE/6 — nixpkgs' `idle` IO class starves on this box); enable-gated smoke: pre-deploy §13 + post-deploy §16; OnFailure → `notify-failure@` (DESKTOP leg) + registry `monitored` entry → `system_service_state_failed` metric → Gatus "Offsite Borg Job Service" → Discord (the Discord leg — corrected 2026-09-24: notify-failure@ alone never pages Discord) |
| Excludes | Rebuildable trees per the blueprint sizing list — `/data/{ai/models,ai/cache,ai/venv-anime-comic,models,SteamLibrary,cache,docker,tmp-*}`, `~/{projects,forks,worktrees,go,.cache,immich-temp}`, pool btrfs receive mirrors (`backups/{root,data}`), the restic repo, forgejo-subvol, paperless `export/index/llm_index/trash/consume`, immich `thumbs/encoded-video` |

The passphrase in `borg.yaml` is a real random value. Copy a recovery copy of
it to whatever medium the owner picks (password manager / printed / split) —
**without the passphrase the offsite repo is unrecoverable once this host is
gone.** Read it with the Sops + Age one-liner (AGENTS.md); the
recovery-copy policy is still an open owner decision (`docs/todo/storage.md`).

## Go-live checklist (owner)

1. **Recovery copy**: read `borg_password` from sops and store it outside the
   host (the first dead disk is the wrong moment to learn it was only in
   sops-on-that-disk).
2. **StorageBox**: enable SSH support (port 23) in the Hetzner console (Rex
   Robotics → Storage Box → "SSH-Support aktivieren" is usually already on).
3. **SSH key**: paste this public key into the Hetzner console
   (`storagebox.your-storagebox.de` → SSH Keys — port 23 reads standard
   OpenSSH format):

   ```
   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILfwy1LqNIcqy9kpBOuZ2/VrB4qinXkTPUyiJwjZ3OX+ borg-offsite evo-x2 (Hetzner StorageBox port 23)
   ```

4. **Fill the sops placeholders** (`sops platforms/nixos/secrets/borg.yaml`,
   as your user with the Sops + Age one-liner from AGENTS.md):
   - `borg_repo`: `uXXXXX@uXXXXX.your-storagebox.de:backups/evo-x2`
   - `borg_known_hosts`: output of `ssh-keyscan -p 23 uXXXXX.your-storagebox.de`
     (pinning the host key = MITM fails loudly, github knownHosts doctrine).
5. **Enable + deploy**: flip `services.offsite-borg.enable = true`
   (`platforms/nixos/system/configuration.nix`) and `nix run .#deploy`. The
   go-live tripwire (`borg-offsite-golive-check` ExecStartPre) fails the run
   with instructions if any placeholder survived.
6. **First run**: `systemctl start borgbackup-job-hetzner` (or wait for the
   06:30 timer). `doInit` creates the repo on first connect; the first
   archive seeds the whole irreplaceable set over WAN — hours, `TimeoutStartSec`
   is 2d. Watch `journalctl -u borgbackup-job-hetzner -f`.
7. **Verify**: `borg list <repo>` shows `evo-x2-<timestamp>`;
   `/var/lib/borg-offsite/.last_success` exists; `backup_healthy{backup="offsite-borg"} 1`
   and `backup_ever_succeeded{backup="offsite-borg"} 1` in node_exporter
   textfiles; "All Backups Healthy" stays green; post-deploy §16 passes.
8. **Sizing**: borg prints "This archive: <size>" per run in the journal —
   that (plus `borg info`) is the irreplaceable-set measurement. If it
   approaches ~800 G, upgrade BX11 → BX21 (instant, same credentials) —
   tracked in `docs/todo/storage.md`.
9. **Restore drill**: run the timed restore drill against the real repo —
   `sudo bash scripts/borg-restore-drill.sh` — and record the timings in
   `docs/services/offsite-borg-restore.md` (full restore runbook).

## Operations

```bash
# Manual run
sudo systemctl start borgbackup-job-hetzner

# Ad-hoc borg against the repo (env comes from the rendered template)
set -x
export BORG_REPO=$(sudo cat /run/secrets/rendered/borg-env | grep -oP '(?<=BORG_REPO=).*')
export BORG_PASSCOMMAND="cat /run/secrets/borg_password"
export BORG_RSH="ssh -p 23 -i /run/secrets/borg_ssh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/run/secrets/borg_known_hosts"
sudo -E borg list
sudo -E borg info

# Failure-alert delivery proof (executable only once the leg is enabled —
# the units do not exist while dormant). Two legs:
#   1. Desktop leg: the OnFailure template instance fires its critical
#      notify-send (or journal logger headless).
#   2. Discord leg: the job unit's state metric + the "Offsite Borg Job
#      Service" / "All Backups Healthy" Gatus checks.
systemctl cat borgbackup-job-hetzner | grep -i onFailure
#   → OnFailure=notify-failure@borgbackup-job-hetzner.service
sudo systemctl start notify-failure@borgbackup-job-hetzner.service
sudo journalctl -u notify-failure@borgbackup-job-hetzner -n 5   # desktop leg delivered
grep -H 'backup_healthy{backup="offsite-borg"}' /var/lib/node_exporter/textfile_collector/*.prom
grep -c 'Offsite Borg Job Service' /etc/gatus-config.yaml 2>/dev/null || \
  journalctl -u gatus -n 200 | grep -m1 'Offsite Borg Job Service'   # Discord leg wired

# Stale repo lock after a WAN drop / killed run (full recipe:
# docs/services/offsite-borg-restore.md "Stale lock"):
pgrep -af borg    # MUST be empty (or only unrelated borg) before break-lock
sudo -E borg break-lock   # with the env block above sourced

# Single-file restore (full restore runbook: docs/services/offsite-borg-restore.md)
sudo -E borg extract ::evo-x2-<timestamp> home/lars/path/to/file
```

(Root-only paths: the sops secrets render 0400 root because the job runs as
root; run ad-hoc borg under `sudo -E` with the env above.)

## Notes / gotchas

- **Why the placeholder repo lives in the unit, not sops only**: the nixpkgs
  job needs a static `repo`; the rendered `BORG_REPO` from the
  `borg-env` EnvironmentFile overrides it at runtime (systemd semantics).
  The placeholder is remote-shaped so the unit gets remote handling (no
  local-path mount wiring).
- **`StrictHostKeyChecking=yes` + placeholder known_hosts** = fail-closed:
  the job cannot connect anywhere until the host key is pinned. That is
  deliberate (no TOFU on a backup channel).
- **Do not point `BORG_CACHE_DIR` back at `~/.cache/borg`** (nixpkgs
  default): the cache is multi-GB and `@` snapshots pin deleted bytes
  pool-side forever (emergency-reserve pinning doctrine).
- **Retention** (`daily=7, weekly=4, monthly=6`) is the blueprint default;
  the final policy is still an owner decision (`docs/todo/storage.md`).
- **Immich path is included but currently empty** (`/mnt/pool/services/immich`
  exists with no library yet); when photos land, they ride this job with zero
  config churn — but re-check the sizing trigger at that point.
