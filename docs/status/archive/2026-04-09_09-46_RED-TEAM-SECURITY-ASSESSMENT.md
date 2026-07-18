# Red Team Security Assessment — Full Comprehensive Status Report

**Date:** 2026-04-09 09:46
**Assessor:** Crush AI (defensive security audit)
**Scope:** NixOS (`evo-x2`) + macOS (`Lars-MacBook-Air`)
**Session Type:** Read-only security audit — no configuration changes made

---

## a) FULLY DONE

### Assessment Coverage (100% Complete)

All 40+ configuration files were read, analyzed, and cross-referenced across both platforms:

| Category        | Files Analyzed                                                              | Status |
| --------------- | --------------------------------------------------------------------------- | ------ |
| Networking      | `networking.nix`, `dns-blocker-config.nix`, `darwin/networking/default.nix` | Done   |
| Firewall        | NixOS firewall rules, macOS ALF, fail2ban                                   | Done   |
| Authentication  | Authelia, SSH, sudo, PAM, TouchID, sops-nix                                 | Done   |
| Services        | Docker, Gitea, Immich, SigNoz, Caddy, Homepage, Photomap                    | Done   |
| Secrets         | `sops.nix`, `secrets.yaml`, `authelia-secrets.yaml`, `dnsblockd-certs.yaml` | Done   |
| Desktop         | SDDM, swaylock, swayidle, Niri, Waybar, security-hardening                  | Done   |
| Boot            | systemd-boot, kernel params, IOMMU, ZRAM, sysctl                            | Done   |
| Hardware        | AMD GPU, NPU, Bluetooth, hardware-configuration                             | Done   |
| Packages        | `base.nix`, overlays, flake inputs, custom packages                         | Done   |
| User Config     | `home.nix` (both platforms), `home-base.nix`, git, fish, keepassxc          | Done   |
| Supply Chain    | `flake.nix` (all 20+ inputs), nix-settings, substituters                    | Done   |
| macOS-specific  | Darwin default.nix, PAM, Keychain, LaunchAgents, Chrome policies            | Done   |
| Chrome/Chromium | Extension policies, HTTPS-only, password manager (both platforms)           | Done   |
| Monitoring      | ClamAV, smartd, fail2ban jails, service health checks                       | Done   |

### Findings Identified

- **4 CRITICAL** severity findings
- **5 HIGH** severity findings
- **8 MEDIUM** severity findings
- **6 LOW** severity findings
- **11 Positive security findings** documented

### Secret Exposure Verification

Verified that `secrets.yaml`, `authelia-secrets.yaml`, and `dnsblockd-certs.yaml` are sops-encrypted (AES256_GCM). Verified that `dnsblockd-ca.crt` and `dnsblockd-server.crt` are plaintext but are public certificates (acceptable). Confirmed all secret files are tracked in git (sops-encrypted content is safe to commit).

---

## b) PARTIALLY DONE

Nothing was partially completed. The assessment was either fully done (analysis) or not started (remediation).

---

## c) NOT STARTED

All remediation work. Zero configuration changes were made. The following actions were identified but **not implemented**:

1. Moving Authelia user password hash to sops-nix
2. Moving Authelia OIDC client secret to sops-nix
3. Enabling sudo passwords
4. Re-enabling IOMMU
5. Removing SigNoz/ClickHouse firewall port openings
6. Fixing Gitea token file permissions (644 → 600)
7. Switching Git credential helper from `store` to `libsecret`/`cache`
8. Migrating from Docker to rootless Docker/Podman
9. Closing Steam game transfer firewall ports
10. Reducing swayidle lock timeout (300s → 120s)
11. Setting `accept-flake-config = ask`
12. Fixing Gitea runner `network = "host"` to bridge mode
13. Implementing LUKS disk encryption
14. Setting UEFI firmware password
15. Fixing Gitea mirror script `/tmp` predictable paths
16. Setting `REQUIRE_SIGNIN_VIEW = true` on Gitea
17. Enabling macOS stealth mode
18. Enabling AppArmor
19. Re-enabling auditd (blocked by nixpkgs#483085)
20. Moving coderabbit machineId out of git config
21. Increasing Authelia password policy minimum length (8 → 15)

---

## d) TOTALLY FUCKED UP

**Nothing.** This was a read-only assessment. No files were modified. No configurations were broken. The working tree remains clean.

The only "fucked up" things found were pre-existing issues in the config itself:

| Finding                                        | Why It's Bad                          |
| ---------------------------------------------- | ------------------------------------- |
| Authelia password hash in plaintext nix config | Anyone with repo access gets the hash |
| `wheelNeedsPassword = false`                   | Trivial privilege escalation          |
| `amd_iommu=off`                                | DMA attack surface wide open          |
| ClickHouse ports open to LAN with no auth      | Database accessible from network      |

---

## e) WHAT WE SHOULD IMPROVE

### Security Architecture Improvements

1. **Defense-in-Depth for Secrets:** All secrets should go through sops-nix. Currently Authelia user password and OIDC client secrets are hardcoded in Nix expressions. This creates an inconsistency where some secrets are properly encrypted while others are plaintext in the repo.

2. **Principle of Least Privilege:** The `lars` user has passwordless sudo AND docker group membership. This is two paths to root with zero authentication. At minimum one of these should require a password.

3. **Network Segmentation:** SigNoz, ClickHouse, and OTel Collector ports are opened directly in the firewall, bypassing the Authelia+Caddy reverse proxy. All services should be accessible only through the authenticated reverse proxy.

4. **Disk Encryption:** No LUKS encryption on any filesystem. Physical access = full data access including runtime-decrypted sops secrets.

5. **Boot Security:** No UEFI password, no Secure Boot. Physical access can modify boot parameters for root shell.

6. **Mandatory Access Control:** AppArmor is disabled. Auditd is disabled (upstream bug). The system has no MAC and no audit trail.

7. **Credential Storage:** Git uses plaintext `credential.helper = store`. Should use OS keychain integration.

8. **Container Isolation:** Docker (not rootless) with host networking for CI runners. CI jobs can access all host services.

### Code Quality Improvements

9. **Gitea Token Permissions:** Token file is world-readable (644). Should be 600.

10. **Temporary File Handling:** Mirror scripts use predictable `/tmp` paths instead of `mktemp`.

11. **Config Consistency:** Grafana fail2ban jail references `/var/log/grafana/grafana.log` but Grafana is not deployed. Dead config.

### Process Improvements

12. **Security Scanning:** No automated security scanning in CI/CD (gitleaks is installed but not in a pre-commit hook for this repo).

13. **Regular Audits:** No scheduled security audit process documented.

14. **Incident Response Plan:** Security tools are installed (sleuthkit, tcpdump, etc.) but no documented IR procedures.

---

## f) Top #25 Things We Should Get Done Next

### Priority 1: Critical Fixes (Do Immediately)

| #   | Task                                                          | Effort | Impact                                      | Risk if Skipped                    |
| --- | ------------------------------------------------------------- | ------ | ------------------------------------------- | ---------------------------------- |
| 1   | Move Authelia user password hash to sops-nix encrypted secret | 30 min | Closes plaintext credential exposure in git | Offline bruteforce of password     |
| 2   | Move Authelia OIDC client secret hash to sops-nix             | 30 min | Closes OAuth client impersonation risk      | Token theft, service impersonation |
| 3   | Enable sudo passwords (`wheelNeedsPassword = true`)           | 5 min  | Eliminates trivial privilege escalation     | Any process can get root           |
| 4   | Re-enable IOMMU (remove `amd_iommu=off`)                      | 5 min  | Restores DMA protection                     | Thunderbolt/USB DMA attacks        |

### Priority 2: High Fixes (Do This Week)

| #   | Task                                                                        | Effort  | Impact                                        | Risk if Skipped                     |
| --- | --------------------------------------------------------------------------- | ------- | --------------------------------------------- | ----------------------------------- |
| 5   | Remove SigNoz/ClickHouse firewall port openings                             | 15 min  | Closes unauthenticated database access on LAN | Data exfiltration, DB manipulation  |
| 6   | Fix Gitea token file permissions (644 → 600)                                | 5 min   | Prevents token theft by local users           | Full Gitea admin access             |
| 7   | Switch Git credential helper to `libsecret` (Linux) / `osxkeychain` (macOS) | 20 min  | Prevents plaintext credential storage on disk | GitHub token theft                  |
| 8   | Close Steam `localNetworkGameTransfers.openFirewall`                        | 5 min   | Reduces attack surface                        | Unnecessary open ports              |
| 9   | Evaluate Docker → rootless Docker or Podman migration                       | 2-4 hrs | Removes docker-equivalent-to-root risk        | Privilege escalation via containers |

### Priority 3: Medium Fixes (Do This Month)

| #   | Task                                                                 | Effort  | Impact                                         | Risk if Skipped               |
| --- | -------------------------------------------------------------------- | ------- | ---------------------------------------------- | ----------------------------- |
| 10  | Reduce swayidle lock timeout (300s → 120s) and suspend (600s → 300s) | 5 min   | Reduces physical access window                 | Unauthorized desktop access   |
| 11  | Set `accept-flake-config = ask` in nix-settings                      | 5 min   | Prevents arbitrary flake config injection      | Supply chain compromise       |
| 12  | Change Gitea runner to bridge networking                             | 30 min  | Isolates CI jobs from host network             | CI job accessing all services |
| 13  | Implement LUKS2 disk encryption for `/` and `/data`                  | 2-3 hrs | Protects data at rest                          | Physical theft data exposure  |
| 14  | Set UEFI firmware password for boot protection                       | 10 min  | Prevents boot parameter manipulation           | Root shell via init=/bin/bash |
| 15  | Fix Gitea mirror scripts to use `mktemp`                             | 15 min  | Prevents symlink attacks in /tmp               | Local privilege escalation    |
| 16  | Set `REQUIRE_SIGNIN_VIEW = true` on Gitea                            | 5 min   | Hides repo metadata from unauthenticated users | Information leakage           |
| 17  | Enable macOS stealth mode (`enableStealthMode = true`)               | 5 min   | Hides MacBook from port scans                  | Network reconnaissance        |

### Priority 4: Low / Hardening (Do Eventually)

| #   | Task                                                                      | Effort  | Impact                                 | Risk if Skipped              |
| --- | ------------------------------------------------------------------------- | ------- | -------------------------------------- | ---------------------------- |
| 18  | Enable AppArmor with profiles for critical services                       | 4-8 hrs | Mandatory access control               | Unrestricted process access  |
| 19  | Re-enable auditd once nixpkgs#483085 is fixed                             | 30 min  | Security audit trail                   | No forensic evidence         |
| 20  | Move coderabbit `machineId` to environment variable                       | 10 min  | Reduces information disclosure         | User identification          |
| 21  | Increase Authelia password min length (8 → 15)                            | 5 min   | Stronger authentication                | Weak password bruteforce     |
| 22  | Remove dead Grafana fail2ban jail configuration                           | 5 min   | Config cleanup / accuracy              | Confusion during incident    |
| 23  | Add gitleaks pre-commit hook to this repository                           | 15 min  | Automated secret scanning              | Future secret leaks          |
| 24  | Document incident response procedures                                     | 2-4 hrs | Faster incident response               | Delayed response to breaches |
| 25  | Set up automated security scanning (nix flake check, vulnerability scans) | 2-4 hrs | Continuous security posture monitoring | Unknown vulnerabilities      |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Is this repository public or private?**

This is the single most important unknown that changes the severity of several findings:

- **C1 (Authelia password hash)** and **C2 (OIDC client secret)**: If the repo is **public**, these are internet-exposed and the severity is maximum. If **private** (trusted collaborators only), the risk is limited to repo collaborators.
- **All hardcoded IPs** (Hetzner servers at `37.27.x.x`, local `192.168.1.x`): If public, this leaks infrastructure topology. If private, it's informational only.
- **The `coderabbit` machineId**: If public, it's a tracking vector. If private, it's a non-issue.

I can see the repo is `github:LarsArtmann/SystemNix` but I cannot determine its visibility without asking. **This directly determines whether C1/C2 are "fix today" or "fix this week" priority.**

---

## Findings Summary Table

| ID  | Severity | Component  | Finding                                     | Platform |
| --- | -------- | ---------- | ------------------------------------------- | -------- |
| C1  | CRITICAL | Authelia   | Password hash in git-tracked nix config     | NixOS    |
| C2  | CRITICAL | Authelia   | OIDC client secret hash in nix config       | NixOS    |
| C3  | CRITICAL | sudo       | Passwordless sudo for wheel group           | NixOS    |
| C4  | CRITICAL | Kernel     | IOMMU disabled (`amd_iommu=off`)            | NixOS    |
| H1  | HIGH     | SigNoz     | ClickHouse/Collector ports open on firewall | NixOS    |
| H2  | HIGH     | Gitea      | Token file world-readable (644)             | NixOS    |
| H3  | HIGH     | Git        | Plaintext credential helper (`store`)       | Both     |
| H4  | HIGH     | Docker     | Docker group = root equivalent              | NixOS    |
| H5  | HIGH     | Steam      | Unnecessary firewall openings               | NixOS    |
| M1  | MEDIUM   | swayidle   | Lock timeout too long (5 min)               | NixOS    |
| M2  | MEDIUM   | Nix        | `accept-flake-config = true`                | Both     |
| M3  | MEDIUM   | Gitea      | CI runner uses host networking              | NixOS    |
| M4  | MEDIUM   | Filesystem | No disk encryption (LUKS)                   | NixOS    |
| M5  | MEDIUM   | Boot       | No UEFI/Secure Boot password                | NixOS    |
| M6  | MEDIUM   | Gitea      | Predictable temp file paths                 | NixOS    |
| M7  | MEDIUM   | Gitea      | Public repo visibility without auth         | NixOS    |
| M8  | MEDIUM   | Firewall   | macOS stealth mode disabled                 | macOS    |
| L1  | LOW      | AppArmor   | MAC disabled                                | NixOS    |
| L2  | LOW      | auditd     | Audit disabled (upstream bug)               | NixOS    |
| L3  | LOW      | Git        | coderabbit machineId in config              | Both     |
| L4  | LOW      | Authelia   | Weak password policy (8 chars)              | NixOS    |
| L5  | LOW      | Homepage   | Service topology exposed (behind auth)      | NixOS    |
| L6  | LOW      | NixOS      | Git commit hash in system version           | NixOS    |

---

## Positive Security Findings

| Area               | What's Done Right                                                               |
| ------------------ | ------------------------------------------------------------------------------- |
| SSO/2FA            | Authelia with TOTP + WebAuthn, forward-auth for ALL services                    |
| Secrets Management | sops-nix with age encryption, SSH host key derivation, separate secret files    |
| DNS Security       | Unbound + 25 blocklists (2.5M+ domains), DNSSEC, DoH bypass prevention          |
| SSH Hardening      | Key-only auth, no root login, fail2ban aggressive mode, allowUsers restriction  |
| Network Firewall   | Deny-by-default, static IP, HTTPS-only via Caddy reverse proxy                  |
| TLS                | Custom CA for local services, sops-managed certificates                         |
| Supply Chain       | Flake input pinning, hash-verified blocklists, Nix sandbox enabled              |
| Browser Security   | Forced HTTPS-only, disabled password manager, safe browsing, extension control  |
| macOS              | TouchID for sudo, keychain auto-lock (5 min), application firewall enabled      |
| Git Security       | GPG signing enforced for all commits/tags, SSH for GitHub                       |
| Screen Lock        | swaylock + swayidle with automatic suspend                                      |
| Monitoring         | ClamAV, smartd, service health checks, BTRFS scrub                              |
| Identity Provider  | Authelia password policy, regulation (brute force protection), session timeouts |
