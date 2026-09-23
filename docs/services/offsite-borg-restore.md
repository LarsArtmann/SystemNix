# Offsite Borg restore (Hetzner StorageBox)

Restore-side runbook for the offsite Borg leg (`platforms/nixos/system/backup.nix`).
The backup-side runbook + go-live checklist live in
[offsite-borg.md](offsite-borg.md); the blueprint/decision rationale in
`docs/research/hetzner-storagebox-borgbackup.md`.

**Status:** restore path implemented + drill-proven 2026-09-23 (first timed
drill ran against a local stand-in repo — table below). The leg itself is
still DORMANT until the owner go-live; re-run the drill against the real repo
as go-live checklist step 9 and extend the table.

## Recovery artifacts (what you must have when this host is gone)

The repo is `repokey-blake2`: **the passphrase alone decrypts the data, but
nothing else substitutes for it.** With no recovery copy, host loss + sops
loss = permanent data loss — that is the go-live blocker tracked in
`docs/todo/storage.md`.

| Artifact | Lives on evo-x2 | Dead-host source |
| -------- | --------------- | ---------------- |
| Borg passphrase | sops `borg.yaml` → `/run/secrets/borg_password` (0400 root) | **Owner recovery copy only** (password manager / printed — go-live checklist step 1). Nothing on the StorageBox can recover it. |
| SSH key | sops `borg_ssh_key` (ed25519; public key printed in the go-live checklist) | Not required: paste a NEW public key in the Hetzner console (StorageBox authorized_keys is box-side config, independent of the repo data). |
| Host-key pin | sops `borg_known_hosts` | Re-pin from a trusted network: `ssh-keyscan -p 23 <host>.your-storagebox.de` (TOFU caveat — verify out-of-band against Hetzner's published fingerprints when possible). |

## StorageBox Borg-access notes

- **Port 23, not 22** — port 22 is SCP/SFTP only; Borg runs on 23. Port 23
  reads standard OpenSSH key format (port 22 wants RFC4716 — never mix).
- **Repo address shape**: `uXXXXX@uXXXXX.your-storagebox.de:backups/evo-x2`
  (the path is relative to the box root; borg creates it at `borg init`).
- **The box is ZFS** — you cannot `btrfs receive` onto it, and the archive
  is only readable through borg itself (client-side encryption: the box
  stores opaque ciphertext chunks).
- **Hetzner's own box snapshots** (`<home>/.zfs/snapshot/`, plan-dependent
  retention) copy the RAW repo files — the only recovery for accidentally
  deleted/overwritten repo chunks within the snapshot window. Not borg-aware:
  they restore ciphertext files, which only decrypt with the passphrase.
- **Quota**: BX11 is 1 TB. Watch `borg info` size vs quota (upgrade path
  BX21 in the backup-side runbook).

Accessing the repo from any machine (restore client):

```bash
nix run nixpkgs#borgbackup -- --version   # or install borgbackup your way
export BORG_REPO='uXXXXX@uXXXXX.your-storagebox.de:backups/evo-x2'
export BORG_PASSPHRASE='<recovery-copy passphrase>'        # OR BORG_PASSCOMMAND
export BORG_RSH='ssh -p 23 -i ./restore-key -o IdentitiesOnly=yes'
borg list
```

(The scp-form `u@host:path` repo string carries NO port — it lands on 22
unless the port comes from BORG_RSH/ssh config. StorageBox serves Borg on
23 ONLY; port 22 is SCP/SFTP. The `-p 23` in the env blocks is therefore
load-bearing, and the `ssh-keyscan -p 23` known_hosts pin is
`[host]:23`-shaped so a default-port connect refuses on the host-key lookup.)

## Single-file restore (same host)

```bash
sudo bash -c '
  set -a; source /run/secrets/rendered/borg-env; set +a
  export BORG_PASSCOMMAND="cat /run/secrets/borg_password"
  export BORG_RSH="ssh -p 23 -i /run/secrets/borg_ssh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/run/secrets/borg_known_hosts"
  export BORG_CACHE_DIR=/mnt/hot/borg/cache BORG_CONFIG_DIR=/mnt/hot/borg/config
  borg list                                   # pick the archive
  mkdir /tmp/restore && cd /tmp/restore
  borg extract ::evo-x2-<timestamp> home/lars/path/to/file
'
```

Archive paths are stored WITHOUT the leading slash (`/etc` → `etc/`,
`/home/lars` → `home/lars/`, `/mnt/pool/...` → `mnt/pool/...`). **Never
extract with absolute intent from `/`: borg extract overwrites existing files
without asking** — always extract into a scratch dir and move what you need.

Browse without extracting (FUSE; needs `allow_other`-capable environment for
non-root readers):

```bash
borg mount ::evo-x2-<timestamp> /mnt/restore-browse   # Ctrl-C / fusermount -u to unmount
```

## Full restore (dead host / bare metal)

What the archive holds: `/etc`, `/home/lars` (minus the exclude list),
`/data` (minus rebuildable model/Steam/cache trees), and the pool's
`backups/` + immich/paperless service dirs. What it deliberately does NOT
hold: `/nix` (rebuild from the flake), the ESP/bootloader, and anything on
the exclude list — that is the sizing doctrine, not an accident.

1. **Reinstall NixOS from the flake** on the replacement host: boot any
   NixOS installer, clone `github:LarsArtmann/SystemNix`, adapt
   `hardware-configuration.nix` to the new disks, `nixos-install`. /etc,
   home, and service state come back in step 3 — do not hand-recreate them.
2. **Restore the sops identity first**: `/etc/ssh/ssh_host_ed25519_key` from
   the archive IS the sops age key source (ssh-to-age). Extract it into the
   new host's `/etc/ssh/` (permissions 0600) so `/run/secrets` decrypts
   again after the first rebuild. The borg secrets (`borg_password`,
   `borg_ssh_key`, `borg_known_hosts`) do NOT ride in the archive — they are
   sops values rendered to tmpfs `/run/secrets`, never on disk. They come
   back from the sops chain instead: the git-tracked
   `platforms/nixos/secrets/borg.yaml` (cloned in step 1) + the restored
   host key. NOTE: the declarations are gated behind
   `services.offsite-borg.enable = true`, so a first rebuild renders
   NOTHING until the leg is re-enabled — run the go-live checklist on the
   new host (StorageBox hostname/username + a fresh `ssh-keyscan` host-key
   pin re-supplied into `borg.yaml`) and rebuild again; the sops-rendered
   secrets then come back for the steady state (the `borgbackup-job-hetzner`
   unit and the `/run/secrets`-based drill block). Step 3 below does NOT
   depend on them — it rides out-of-band credentials instead: the owner's
   recovery-copy passphrase and a manually provided SSH key.
3. **Extract the data trees** (target needs free space ≈ the irreplaceable
   set — check `borg info` first):

   ```bash
   export BORG_REPO='uXXXXX@uXXXXX.your-storagebox.de:backups/evo-x2'
   export BORG_PASSPHRASE='<recovery-copy passphrase>'
   export BORG_RSH='ssh -p 23 -i ./restore-key -o IdentitiesOnly=yes'
   borg extract ::evo-x2-<timestamp> home data mnt   # into a staging dir
   # then rsync into the mounted filesystems, /etc cherry-picks LAST
   ```

4. **`/etc` is cherry-pick territory**: NixOS regenerates most of `/etc` on
   every switch, so do NOT blanket-copy it over the fresh system. Restore the
   mutable residuals only: `etc/ssh/ssh_host_*` (sops identity + host
   identity), anything hand-configured that shows up in `git diff` between
   the archive's `etc/nixos` and the flake, and service state dirs the
   modules expect to find (most live under `/var/lib`, which the archive
   covers only via the included service-data paths — check the exclude list).

## Timed restore drill

`scripts/borg-restore-drill.sh` — small-subset timed drill (an untested
restore is Schrödinger's backup). It connects, resolves the newest archive,
extracts a tiny deterministic subset (`etc/hostname` + `etc/machine-id`),
verifies the extracted bytes (existence, non-empty, `cmp` against the live
files in real mode), and times each phase. Per-run records land in
`${XDG_STATE_HOME:-~/.local/state}/borg-restore-drill/`.

```bash
sudo bash scripts/borg-restore-drill.sh                # real repo (needs root: secrets are 0400 root)
bash scripts/borg-restore-drill.sh --local /path/repo  # stand-in drill, no root
bash scripts/borg-restore-drill.sh --selftest          # throwaway repo, proves the path unprivileged
```

Pass criteria: resolve → extract → verify all succeed; any missing/empty
extracted file fails the drill. A `warn` (not failure) is printed when an
extracted file differs from its live counterpart — that is backup drift, not
a broken restore path.

### First timed drill — 2026-09-23 (local stand-in, borg 1.4.5)

Proven via `--selftest` (throwaway `repokey-blake2` repo, same compression
`auto,zstd,9` as the job):

| Phase            | Run 1  | Run 2  |
| ---------------- | ------ | ------ |
| connect+resolve  | 281 ms | 295 ms |
| extract          | 326 ms | 283 ms |
| verify           | 8 ms   | 7 ms   |
| **TOTAL**        | 615 ms | 585 ms |

Result: PASS (both runs; extracted files byte-verified via sha256). Reproduced
2026-09-23 across the verification re-dispatches — 5 full PASS records total
(469-739 ms) under `~/.local/state/borg-restore-drill/`. The local stand-in
cannot measure the StorageBox SSH/WAN leg — after go-live, run
`sudo bash scripts/borg-restore-drill.sh` and add the real-repo row to this
table (expect connect+resolve to dominate: TLS-less SSH handshake to the
StorageBox + key decryption + repo index read over WAN).

## Gotchas

- **borg extract overwrites silently** — scratch dir, always (the drill
  does exactly this; the 2026-09-23 bring-up polluted the repo worktree
  once before the CWD rule landed).
- **Root-only secrets**: `/run/secrets/borg_*` render 0400 root — ad-hoc
  borg needs `sudo` with the env block above. The drill enforces this in
  real mode and fails with instructions otherwise.
- **StrictHostKeyChecking=yes is fail-closed** — a host-key change (or an
  unpinned placeholder) refuses to connect. That is the no-TOFU doctrine on
  a backup channel; re-pin deliberately, never blanket-accept.
- **Cache on /mnt/hot** (`BORG_CACHE_DIR=/mnt/hot/borg/cache`): the drill
  reuses the job's warm cache for realistic timings. If the Samsung tier is
  detached, an unmounted `/mnt/hot` does NOT stop borg: it happily `mkdir`s
  its cache under the mountpoint, landing every cache byte on the ROOT fs
  (the shadow-dir class this repo documents elsewhere). The borgbackup job
  unit is mount-gated (`RequiresMountsFor`); the manual drill is not — until
  the drill grows a `mountpoint -q /mnt/hot` gate (queued in
  `docs/todo/storage.md`), check the mount before a real-mode drill and note
  the cache location in the drill record.
- **Borg 1.x extract has `--dry-run` (`-n`)** — it resolves paths, reads
  and checks every chunk, and writes nothing; use it (or
  `borg list ::archive <path>`) to preview a subset before extracting.
