# Ransomware Protection Strategy

## 1. Backups (Most Critical)

- **3-2-1 rule**: 3 copies, 2 different media, 1 offsite
- **Immutable backups**: Use BTRFS snapshots with `timeshift` — ensure snapshots are **read-only** and cannot be deleted by user processes
- **Offsite/cloud**: Encrypt backups before uploading (e.g., `restic` + S3/B2) — even if compromised, ransomware can't reach them
- **Test restores regularly** — untested backups aren't backups

## 2. NixOS-Specific Advantages

- **Declarative system**: `nixos-rebuild` rebuilds your entire OS from `flake.nix` — ransomware can't persist through a rebuild unless it compromises `/data` or `/home`
- **Read-only system store**: `/nix/store` is immutable by default — most ransomware can't touch it
- **Keep `flake.lock` + `flake.nix` in git** — full system recoverable from repo alone

## 3. Network Hardening (Existing Foundations)

- **DNS blocking** (dnsblockd) — blocks malware C2 domains
- **Firewall** — keep unused ports closed
- **sops-nix** — secrets are age-encrypted at rest, not plaintext on disk
- **Authelia forward auth** — services aren't exposed without authentication

## 4. Recommended Additions

| Priority | Action | Why |
|----------|--------|-----|
| **High** | Restic/Borg backup to offsite (e.g., Hetzner, B2, S3) | Local snapshots die with the disk |
| **High** | BTRFS read-only snapshots for `/data` and `/home` | Immutable recovery points |
| **High** | Email attachment hygiene — don't open unknown attachments | #1 ransomware vector |
| **Medium** | Separate backup credentials from daily-use credentials | Ransomware runs as your user |
| **Medium** | Keep sops age keys offline (YubiKey or offline USB) | If keys are on disk, ransomware can decrypt secrets |
| **Medium** | Restrict SSH access (key-only, no password auth) | Prevent lateral movement |
| **Low** | AppArmor/firejail for browser isolation | Browser is the main attack surface |

## 5. Quick Wins

```bash
# 1. Create read-only BTRFS snapshot (cron it)
btrfs subvolume snapshot -r /data /data/.snapshots/$(date +%Y-%m-%d)

# 2. Restic init (one-time, encrypted repo)
restic init --repo /mnt/backup-drive/restic

# 3. Verify your sops age key isn't on the compromised machine
# Move to YubiKey or air-gapped USB if possible
```

## 6. If Hit By Ransomware

1. **Disconnect from network immediately** — stops spread + C2
2. **Do NOT pay** — funds further attacks, no guarantee of decryption
3. **Rebuild from `flake.nix`** — your system is declarative
4. **Restore `/data` and `/home` from offsite backup**
5. **Rotate all credentials** (API keys, tokens, passwords)
