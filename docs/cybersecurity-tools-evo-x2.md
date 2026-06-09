# Cybersecurity Tools for evo-x2

Best open-source security tools for the NixOS (evo-x2) machine, organized by impact tier.

**Updated:** 2026-05-05

---

## Current Security Posture

### What's Already Installed

| Tool | Type | Status | Location |
|------|------|--------|----------|
| fail2ban | IPS (SSH brute-force) | ✅ Active | `security-hardening.nix:73` |
| ClamAV | Antivirus | ✅ Active | `security-hardening.nix:96` |
| nmap | Network scanning | ⚠️ Installed, no automation | `security-hardening.nix:155` |
| masscan | Fast port scanning | ⚠️ Installed, no automation | `security-hardening.nix:144` |
| nuclei | Vulnerability scanner | ⚠️ Installed, no automation | `security-hardening.nix:147` |
| nikto | Web server scanner | ⚠️ Installed, no automation | `security-hardening.nix:146` |
| sqlmap | SQL injection testing | ⚠️ Installed, no automation | `security-hardening.nix:145` |
| lynis | Security auditing | ⚠️ Installed, no automation | `security-hardening.nix:156` |
| aide | File integrity monitoring | ⚠️ Installed, no automation | `security-hardening.nix:125` |
| osquery | OS monitoring & analytics | ⚠️ Installed, no automation | `security-hardening.nix:126` |
| wireshark-cli | Packet analysis | ✅ Available | `security-hardening.nix:154` |
| wireshark | Packet analysis (GUI) | ✅ Available | `security-hardening.nix:120` |
| tcpdump | Packet capture | ✅ Available | `security-hardening.nix:151` |
| netsniff-ng | Network packet capture | ✅ Available | `security-hardening.nix:119` |
| ecapture | SSL/TLS capture via eBPF | ✅ Available | `base.nix:247` |
| aircrack-ng | WiFi security testing | ✅ Available | `security-hardening.nix:121` |
| sleuthkit | Forensic toolkit | ✅ Available | `security-hardening.nix:150` |
| gitleaks | Secret scanning | ✅ Available | `base.nix:94` |
| Firewall (nftables) | Default-deny, ports 22/53/80/443 | ✅ Active | `networking.nix:11` |

### What's Disabled or Missing

| Tool | Issue | Location |
|------|-------|----------|
| auditd | Disabled — NixOS 26.05 bug #483085 | `security-hardening.nix:26` |
| AppArmor | Disabled | `security-hardening.nix:55` |
| CrowdSec | Not installed | — |
| rkhunter / chkrootkit | Not installed | — |
| Trivy | Not installed | — |
| Suricata / Zeek (IDS/IPS) | Not installed | — |
| USBGuard | Not installed | — |

### Known Issues

1. **fail2ban configured twice** — `configuration.nix:259-284` duplicates `security-hardening.nix:73-93`. Remove the `configuration.nix` version.
2. **No automated scanning** — Security tools (nmap, lynis, nuclei, aide) are installed as packages but have no systemd timers for scheduled execution.
3. **No rootkit detection** — Zero coverage for rootkits, backdoors, or local exploits.
4. **No container vulnerability scanning** — Docker services (Immich, Gitea, Homepage, etc.) are not scanned for CVEs.
5. **No network IDS/IPS** — No traffic inspection beyond firewall port filtering.
6. **No USB device authorization** — No protection against BadUSB/evil maid attacks.

---

## Recommended Tools

### Tier 1 — Highest Impact, Add Now

| Tool | Package | Type | Why |
|------|---------|------|-----|
| **CrowdSec** | `crowdsec` | Collaborative IPS | Replaces fail2ban with behavior-based detection + global threat intelligence. nftables bouncer, multi-service parsing (SSH, Caddy, etc.). Much smarter than fail2ban's regex-only approach. |
| **Trivy** | `trivy` | Vulnerability scanner | Scans containers (Docker), filesystems, and git repos. Detects CVEs, misconfigurations, secrets. Essential with Docker services running. |
| **kernel-hardening-checker** | `kernel-hardening-checker` | Kernel audit | Validates all kernel hardening options from `boot.nix` (sysrq, panic params, gpu recovery). Catches missing protections. |
| **rkhunter** | `rkhunter` | Rootkit detection | Checks for known rootkits, backdoors, local exploits, suspicious files, and hidden processes. Currently zero rootkit coverage. |

### Tier 2 — Significant Defense-in-Depth

| Tool | Package | Type | Why |
|------|---------|------|-----|
| **Suricata** | `suricata` | Network IDS/IPS | Sits behind firewall inspecting all traffic. Detects malware C2, exploits, scanning, protocol anomalies. Rules from Emerging Threats. |
| **USBGuard** | `usbguard` | USB device authorization | Prevents BadUSB/evil maid attacks. Critical for desktop/server hybrid. ⚠️ **High risk of locking out input devices — see caveats below.** |

#### USBGuard Caveats

USBGuard can **permanently block your keyboard and mouse at boot** if the allowlist doesn't include them before the default policy takes effect. This is not theoretical — it happens.

**Risks on evo-x2:**
- Default policy `block` rejects all USB devices not in the allowlist — including input devices at SDDM login
- EMEET PIXY webcam (USB vendor `328f:00c0`) would be rejected on hotplug
- Boot race: USB enumeration happens before USBGuard daemon starts, so initial policy application can block already-connected devices
- No recovery path if keyboard is blocked (can't type to authorize it)

**If ever enabled, require:**
1. `ImplicitPolicy = "allow"` in daemon config (allow everything until rules loaded)
2. Pre-generate allowlist with `usbguard generate-policy` while all devices are connected
3. Test with `allow` default policy first, then switch to `block` only after verifying the allowlist covers all input devices
4. Keep a spare PS/2 keyboard or SSH access as recovery path

**Verdict:** Low threat model for a physically-accessed desktop. Consider only if evo-x2 is ever moved to a shared/semi-public location.
| **certspotter** | `services.certspotter` | Certificate transparency | Monitors CT logs for `*.home.lan` domains. Alerts on rogue cert issuance. Native NixOS module. |
| **dockle** | `dockle` | Container linter | Checks Docker images against CIS benchmarks. Complements Trivy. |

### Tier 3 — SIEM / Full Vulnerability Management

| Tool | Package | Type | Why |
|------|---------|------|-----|
| **Greenbone/OpenVAS** | `openvas-scanner` | Vulnerability management | Full framework with scheduled network scans against all services. Heavy but comprehensive. |
| **Wazuh** | `wazuh-manager` | SIEM + XDR | Log analysis, file integrity, vulnerability detection, compliance checking. Complements SigNoz (observability) with security analytics. |

---

## Quick Wins (No New Dependencies)

| Fix | What to do |
|-----|------------|
| Duplicate fail2ban config | Remove `configuration.nix:259-284` — keep only the version in `security-hardening.nix` |
| Add security scan timers | `systemd.timers` for: weekly `lynis audit system`, weekly `nuclei -u https://*.home.lan`, weekly `trivy fs /` |
| Retry auditd | Check if NixOS 26.05 bug #483085 is resolved; re-enable commented config |
| Re-enable AppArmor | Profile NixOS services with complain-mode first, then enforcing |
| Automate ClamAV scanning | Add systemd timer for `clamscan /data` beyond the on-access daemon |

---

## Proposed Security Scan Schedule

| Scan | Tool | Schedule | Scope |
|------|------|----------|-------|
| System audit | lynis | Weekly (Sun 03:00) | Full system |
| Vulnerability scan | trivy | Weekly (Sun 04:00) | Filesystem + Docker images |
| Network scan | nmap | Weekly (Sun 05:00) | `192.168.1.0/24` |
| Web scan | nuclei | Weekly (Sun 06:00) | All `*.home.lan` services |
| Rootkit check | rkhunter | Daily (03:00) | Full system |
| File integrity | aide | Daily (04:00) | `/etc`, `/var/lib`, `/data` |
| Kernel hardening | kernel-hardening-checker | Monthly | Kconfig + cmdline + sysctl |
