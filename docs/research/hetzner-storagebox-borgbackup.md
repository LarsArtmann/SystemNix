# Offsite Backup: Hetzner Storage Box + BorgBackup

**Date:** 2026-05-30
**Status:** Research — not yet implemented

---

## Context

evo-x2 has local BTRFS snapshots via `btrbk` (`platforms/nixos/system/snapshots.nix`) for fast rollback. These are same-disk only — disk failure = total loss. An offsite backup strategy is needed.

**Existing hardware:** Hetzner Storage Box BX11 (1 TB), already purchased.

---

## Why NOT Native BTRFS Send to Storage Box

Hetzner Storage Box is **ZFS-based** (snapshots live in `/.zfs/snapshot/`). It exposes file-level protocols (SFTP/SSH/rsync/BorgBackup) — not block-level access. You cannot run `btrfs receive` on it.

**Workaround:** `btrfs send | age > stream.btrfs.age` + `rsync` to Storage Box. Possible but:
- Manual incremental chain management
- Large stream files with no remote dedup
- Cannot restore directly on Storage Box (need a BTRFS system)

**Verdict:** Not worth the complexity. Use BorgBackup instead.

---

## Recommended: BorgBackup over SSH

### How Borg Deduplication Works

Borg is **always incremental, forever:**

1. Scans files for changes (ctime/mtime heuristics)
2. Chunks **only changed files** into 2 MiB blocks
3. Deduplicates each chunk against the **global chunk index** (across all snapshots)
4. Uploads only **new, never-before-seen chunks**
5. Creates a new snapshot pointing to the deduplicated chunk tree

**Practical example:**
- Day 1 full: ~50 GB uploaded
- Day 2 after `just switch`: ~200 MB (changed Nix store paths)
- Day 3: ~50 MB
- A week of daily backups: ~52 GB total (not 50×7 = 350 GB)

`prune` removes old snapshot *metadata* — shared chunks stay until no snapshot references them.

### Encryption

Borg encrypts **before** upload. The chunk ID (used for dedup) is based on the **plaintext hash** — identical chunks always deduplicate regardless of encryption.

| Mode | Key location | Trade-off |
|------|-------------|-----------|
| `repokey-blake2` | In repo (encrypted with passphrase) | Only need passphrase to restore; BLAKE2b faster than SHA-256 |
| `repokey` | Same, uses SHA-256 | Standard |
| `keyfile` | Local file only (not in repo) | Most secure — attacker needs keyfile + repo. Must back up keyfile separately |
| `none` | — | Don't use |

**Recommended:** `repokey-blake2` — passphrase stored in sops-nix (already encrypted by SSH host key via age).

**What gets encrypted:**
- All file content (AES-256-CTR)
- All metadata (filenames, paths, timestamps, permissions, symlinks)
- Chunk manifest

Someone with Storage Box access sees only opaque encrypted blobs — no filenames, no structure.

**Encryption is NOT based on SSH keys.** Borg uses its own AES-256 key + passphrase. The two layers are separate:

| Layer | Purpose | Mechanism |
|-------|---------|-----------|
| SSH key | Authenticates to Storage Box | `~/.ssh/` |
| Borg passphrase | Encrypts backup content | sops-nix → `/run/secrets/borg-password` |

The chain: `SSH host key → decrypts sops secret → reveals Borg passphrase → decrypts backup data`

This separation is better than using SSH keys directly — you can rotate either independently.

### Borg vs Restic

| | **BorgBackup** | **Restic** |
|---|---|---|
| Hetzner support | Explicitly listed in docs, port 23 | Works over SFTP (standard) |
| NixOS module | `services.borgbackup.jobs` | `services.restic.backups` |
| Deduplication | Fixed 2 MiB chunks | Variable ~1 MiB chunks |
| Compression | zstd (excellent), lz4, zlib | None (relies on backend) |
| Encryption | AES-256-CTR + HMAC-SHA256 | AES-256-GCM + scrypt KDF |
| Memory use | Higher (~1GB+ for large repos) | Lower (~300-500 MB) |
| Pruning | Slower (rewrites segments) | Fast (cheap snapshot deletion) |
| Remote mount | No native mount | `restic mount` — browse live via FUSE |
| Restore | `borg extract` (files or full) | `restic restore` or `restic mount` |

**Why Borg for this setup:**
- Compression matters over 1 Gbit/s link (BTRFS data is already zstd, but snapshot churn has redundancy)
- Hetzner lists it as a first-class supported protocol
- evo-x2 has 128 GB RAM — memory is irrelevant
- Battle-tested, mature codebase

**When to prefer Restic:** If you need `restic mount` to browse backups without extracting (e.g., "did that file change 3 weeks ago?").

---

## Hetzner Storage Box: Key Facts

- **Backend:** ZFS (NOT Btrfs) — snapshots in `/.zfs/snapshot/`
- **Protocols:** SSH (22: SCP/SFTP only), SSH (23: interactive/rsync/BorgBackup), FTP/FTPS, SMB/CIFS, WebDAV
- **Domain:** `<username>.your-storagebox.de` (IPs can change — always use domain)
- **SSH key format:** Port 22 = RFC4716, Port 23 = OpenSSH format (both support ED25519)
- **Snapshots:** 10 manual + 10 automatic (BX11), 20/20 (BX21) — NOT full backups, just ZFS change tracking
- **Limits:** 10 simultaneous connections, unlimited traffic

---

## Proposed Implementation

### NixOS Module: `platforms/nixos/system/backup.nix`

```nix
{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (import ../../../lib/default.nix lib) harden onFailure;
in {
  services.borgbackup.jobs.hetzner-root = {
    paths = ["/mnt/btrfs-root/.snapshots"];
    repo = "uXXXXX@uXXXXX.your-storagebox.de:backups/borg-root";
    encryption.mode = "repokey-blake2";
    encryption.passCommand = "cat /run/secrets/borg-password";
    compression = "zstd,9";
    startAt = "daily";
    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 6;
    };
  };
}
```

### Secrets (sops)

Add `borg_password` to existing sops secrets file:

```bash
# One-time: generate and store Borg passphrase
BORG_PASS=$(openssl rand -base64 32)
sudo env SOPS_AGE_KEY_FILE=/tmp/age.key \
  sops --set '["borg_password"] "'"$BORG_PASS"'"' \
  platforms/nixos/secrets/pocket-id.yaml
```

Wire in sops-nix config:

```nix
sops.secrets.borg-password = {
  owner = config.users.primaryUser;
  group = "users";
};
```

### SSH Key Setup

```bash
# Port 23 uses OpenSSH format (already have this)
ssh-copy-id -i ~/.ssh/id_ed25519.pub -p 23 uXXXXX@uXXXXX.your-storagebox.de

# Or manually — port 23 reads standard OpenSSH format from ~/.ssh/authorized_keys
```

### Restore Procedure

```bash
# List backups
borg list uXXXXX@uXXXXX.your-storagebox.de:backups/borg-root

# Extract specific files
borg extract uXXXXX@uXXXXX.your-storagebox.de:backups/borg-root::snapshot-name path/to/file

# Full restore
borg extract uXXXXX@uXXXXX.your-storagebox.de:backups/borg-root::snapshot-name
```

---

## Architecture

```
┌──────────────────────────────────────────────┐
│ evo-x2 (local)                               │
│                                               │
│  btrbk ──daily──> /mnt/btrfs-root/.snapshots │
│                        │                      │
│  borgbackup ──daily──>│ (source = snapshots) │
│                        │                      │
│                 encrypt + compress            │
│                 deduplicate + incremental     │
│                        │                      │
│                 SFTP over SSH (port 23)       │
└────────────────────────┼──────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────┐
│ Hetzner Storage Box (ZFS)                    │
│                                               │
│  backups/borg-root/  (encrypted blobs)       │
│  Hetzner sees: opaque ciphertext only        │
└──────────────────────────────────────────────┘
```

**btrbk** = fast local rollback (seconds, same disk)
**borgbackup** = offsite disaster recovery (disk failure, site loss, ransomware)

---

## Checklist Before Implementation

- [ ] Enable SSH Support (port 23) in Hetzner Console
- [ ] Add SSH public key (OpenSSH format) to Storage Box
- [ ] Generate Borg passphrase and store in sops
- [ ] Create `platforms/nixos/system/backup.nix` module
- [ ] Add import in `configuration.nix`
- [ ] Initial `borg init` + first backup
- [ ] Verify timer is running (`systemctl list-timers`)
- [ ] Test restore of a single file
- [ ] Add to AGENTS.md gotchas / FEATURES.md
