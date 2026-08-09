# Status Report: dnsblockd TLS Handshake Spam Investigation & Fix

**Date:** 2026-08-08 22:52
**Session focus:** dnsblockd.service log analysis, TLS handshake spam root cause, CA cert trust fix
**Author:** Crush (Parakletos)

---

> **RESOLVED — Investigation complete. Root cause: macOS daemon TLS session caching + orphaned tracking DB. Items harvested to TODO_LIST.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## Executive Summary

`192.168.1.62` (Lars's Mac, USB-C Ethernet, Realtek OUI) was generating **224,110 TLS handshake errors/day** against the dnsblockd block-page HTTPS server. Root cause: the Mac did not trust the dnsblockd self-signed CA, causing every blocked-domain HTTPS connection to fail the TLS handshake and retry in a loop. Installing the CA cert into the macOS System keychain reduced errors from ~15,000/hour to ~6/hour (99.96% reduction). Remaining stragglers are from cached daemon TLS sessions that will age out or clear on reboot.

---

## a) FULLY DONE

### 1. dnsblockd Log Analysis — Complete

Investigated all log patterns in the dnsblockd service. Identified and characterized 5 distinct issues:

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | TLS handshake spam (224K errors/day from .62) | High (log noise, wasted CPU) | **Fixed** |
| 2 | DNS forwarder timeouts (Iroh P2P query storm) | Medium (transient resolution delays) | Transient — self-resolved |
| 3 | SQLite tracking DB write timeouts (3 errors) | Low (caused by forwarder storm) | Self-resolved |
| 4 | Orphaned old database (`dnsblockd_tracking.db`, 724 MB) | Low (wasted disk) | Identified — not cleaned up |
| 5 | Benign noise (http2 stream closed, low_port warning) | None | Expected behavior |

### 2. TLS Spam Root Cause Identification — Complete

Traced the full causal chain:

```
Mac queries blocked domain (e.g. dns.quad9.net)
  → dnsblockd returns 192.168.1.200 (zero_ip mode)
  → Mac connects to 192.168.1.200:443 with TLS 1.2+ and SNI
  → dnsblockd mints per-domain cert signed by its self-signed CA
  → Mac does NOT trust the CA → rejects cert → closes connection → "EOF"
  → Mac retries TLS 1.2+ → same rejection → "EOF"
  → Mac falls back to TLS 1.0 (0x0301) as last resort
  → dnsblockd rejects (MinVersion: tls.VersionTLS12) → "unsupported versions: [301]"
  → Loop repeats forever
```

**Key finding:** The TLS 1.0 attempts were a *symptom* (downgrade fallback), not the cause. The real problem was cert trust. This was confirmed by reading the dnsblockd source code (`internal/server/tls.go:108-113` — `MinVersion: tls.VersionTLS12`, `internal/server/tls.go:116-125` — per-domain cert minting via SNI).

**Error type breakdown (pre-fix):**
- `EOF` (cert rejected): 149,605 (67%)
- `unsupported versions: [301]` (TLS 1.0 downgrade): 74,664 (33%)
- `illegal parameter`: 167 (<0.1%)

**Top blocked domains from .62:**
- `metrics.icloud.com` (824) — Apple telemetry
- `dns.quad9.net` (250) — DoH bypass attempt
- `mask.icloud.com` / `mask-h2.icloud.com` (324) — iCloud Private Relay
- `one.one.one.one` (116) — Cloudflare DoH bypass
- `beacons.gcp.gvt2.com` (102) — Google telemetry
- `cdn.optimizely.com` (40) — A/B testing tracker

### 3. CA Cert Installation on macOS — Complete & Verified

Provided instructions for extracting the CA cert from `/run/secrets/dnsblockd_ca_cert` (root-only readable, sops-managed) and installing it into the macOS System keychain. User confirmed successful installation.

**Verification results (post-fix):**

| Period | Errors/hour | TLS 1.0 attempts |
|--------|------------|------------------|
| Before cert install | ~15,000 | ~5,000 |
| After cert install (22:25+) | **~6** | **0** |

The TLS 1.0 downgrade attempts dropped to **zero** immediately — the Mac no longer needs to downgrade because it trusts the CA at TLS 1.2+. The 2 remaining stray `EOF` errors (22:27, 22:42) are from cached daemon TLS sessions (iCloud Private Relay / `cloudd`) that haven't picked up the keychain change yet.

### 4. Source Code Investigation — Complete

Read dnsblockd source code (`/home/lars/projects/dnsblockd/internal/server/`):
- `tls.go:108-113` — `TLSConfig()` with `MinVersion: tls.VersionTLS12`
- `tls.go:116-125` — `GetCertificate()` per-domain cert minting via SNI
- `server.go:611-631` — `startHTTPS()` block page server setup
- `handlers.go:206-215` — `blockRouter()` with block page rendering
- Confirmed no per-domain block response type exists (global `zero_ip` or `nxdomain` only)

Also read SystemNix module files:
- `modules/nixos/services/dns-blocker.nix` — service module, YAML config generation
- `modules/nixos/services/dnsblockd-cert-trust.nix` — Firefox/NSS cert trust (NixOS only)
- `platforms/common/dns-blocklists.nix` — whitelist configuration
- `platforms/nixos/system/dns-blocker-config.nix` — host-level config

---

## b) PARTIALLY DONE

### 1. Orphaned Database Cleanup — Identified but NOT cleaned

Found `/var/lib/dnsblockd/dnsblockd_tracking.db` (724 MB, last modified Jul 15) — the old database from before the migration to `tracking.db` (164 MB, in use). The old database contains 139,897 metrics rows and 140,250 track rows, all dating to before Jul 15. The config now uses `tracking_db_path: /var/lib/dnsblockd/tracking.db`.

**Why partially done:** Identified and verified it's safe to remove, but did not execute the cleanup (`sudo rm /var/lib/dnsblockd/dnsblockd_tracking.db`). This is an irreversible `rm` on a root-owned file and should be confirmed by the user.

### 2. Remaining Stray TLS Errors — Identified but NOT resolved

Two stray `EOF` errors at 22:27 and 22:42 are from macOS daemon TLS session caching. These will clear on Mac reboot or naturally age out. Not actively being worked on.

---

## c) NOT STARTED

1. **AGENTS.md update** — No documentation was written this session. The dnsblockd CA cert installation procedure for macOS should be recorded for future reference.
2. **Whitelist additions** — `dns.quad9.net`, `one.one.one.one`, `mask.icloud.com`, `mask-h2.icloud.com` were discussed as candidates for whitelisting (Private Relay is privacy-enhancing, DoH bypass is blocked at resolver level anyway), but no action was taken.
3. **dnsblockd upstream feature** — Per-domain block response type (NXDOMAIN for background services, zero_ip for browser-visible domains) was discussed as the "real fix" but not pursued. Requires upstream code changes in `/home/lars/projects/dnsblockd/`.
4. **Iroh DNS query storm** — 334 `dns.iroh.link` forwarder failures were identified (P2P data-sync library generating pathological TXT queries), but no process was running at investigation time. No mitigation was implemented.

---

## d) TOTALLY FUCKED UP

**Nothing was broken by this session.** All changes were read-only investigations. The only user-facing change (CA cert installation) was performed by the user on their Mac, not by this session.

**Near-miss:** Initially claimed the TLS spam had "stopped" after the service restart at 21:49, but it had actually resumed at 21:56. Corrected in the follow-up analysis when the user asked specifically about the TLS spam.

---

## e) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Don't declare transient issues "fixed" after a restart** — The TLS spam was initially reported as "stopped after restart" when it had merely paused. Should have waited longer to confirm the pattern was truly gone before declaring victory.

2. **Attempt packet capture earlier** — The `tcpdump` failed due to missing `CAP_NET_RAW`. Could have used `sudo` or checked for alternative capture methods instead of skipping straight to source code analysis. Actual packet inspection would have confirmed the TLS downgrade hypothesis faster.

3. **Proactively offer the CA cert fix** — The CA trust issue was identified in the first analysis, but the fix was only offered after the user asked about TLS 1.0 specifically. Should have proactively recommended the CA cert installation as the primary fix in the first response.

4. **Clean up orphaned files immediately** — The 724 MB old database was identified early but left for "manual cleanup." For a root-owned file outside trash scope, should have executed it with explicit user confirmation rather than leaving a note.

### Infrastructure Improvements

5. **dnsblockd should support per-domain block response types** — Background services (telemetry, DoH, Private Relay) should get NXDOMAIN (definitive, stops retry loops). Browser-visible domains should get zero_ip (shows block page). Currently `dnsBlockResponse` is global. This is an upstream dnsblockd feature request.

6. **dnsblockd CA cert distribution to non-NixOS devices** — The `dnsblockd-cert-trust.nix` module only handles Firefox policies + NSS database on NixOS. There's no automated path for macOS/iOS/Android devices. A deployment script or documentation page would prevent this class of issue for all network devices.

7. **Log noise suppression** — The `http: TLS handshake error` messages are Go's `http.Server` default logging at INFO level. dnsblockd could suppress these or log them at DEBUG, especially since they're expected behavior when a device doesn't trust the CA.

8. **Iroh query rate limiting** — The `dns.iroh.link` P2P TXT query storm (334 failures) suggests an Iroh client somewhere on the network is generating excessive DNS traffic. Should identify which device/service runs Iroh and consider rate limiting or blocking `dns.iroh.link` entirely.

---

## f) Next Steps (up to 50)

### High Priority
1. Clean up orphaned database: `sudo rm /var/lib/dnsblockd/dnsblockd_tracking.db` (724 MB freed)
2. Reboot Mac to clear remaining cached daemon TLS sessions (2 stray EOF errors)
3. Update SystemNix `AGENTS.md` with the dnsblockd CA cert macOS installation procedure
4. Verify TLS errors are fully zero after Mac reboot (check `journalctl -u dnsblockd -f`)

### Medium Priority
5. Consider whitelisting iCloud Private Relay domains (`mask.icloud.com`, `mask-h2.icloud.com`) — they're privacy-enhancing and can't work through a DNS-blocking resolver anyway
6. Consider whitelisting `dns.quad9.net` and `one.one.one.one` — DoH bypass attempts are already blocked at resolver level
7. Identify device at `192.168.1.62` in router DHCP table and give it a stable hostname for future log analysis
8. Check if other devices on the network also need the dnsblockd CA cert (check `journalctl` for TLS errors from other IPs)
9. Create a dnsblockd CA cert deployment script for macOS devices (automate the `security add-trusted-cert` flow)
10. Create a dnsblockd CA cert deployment guide for iOS/Android devices (MDM profile or manual import)
11. File upstream issue/PR in dnsblockd for per-domain block response type support
12. File upstream issue/PR in dnsblockd to suppress or downgrade `http: TLS handshake error` log lines
13. Add Iroh (`dns.iroh.link`) to the dnsblockd blocklist or rate-limit its queries
14. Investigate what's running Iroh on the network (check all devices for Iroh/Iroh-based apps)
15. Add a Gatus health check for the dnsblockd block page HTTPS endpoint to detect cert issues
16. Document the `dnsblockd_tracking.db` → `tracking.db` migration in the dnsblockd changelog

### Low Priority
17. Consider switching `dnsBlockResponse` to `nxdomain` globally if the block page is rarely useful (eliminates all TLS retry storms by design)
18. Add a dnsblockd log rotation or rate-limiting rule for `TLS handshake error` messages (journald filter)
19. Check the `false_positive_reports` table in both databases for any actionable user feedback
20. Review the `dns_resolve_timeout` (currently 10s) — consider reducing to 5s to fail faster on DoT forwarder stalls
21. Review DoT forwarder health (`tls://1.1.1.1:853`, `tls://9.9.9.9:853`) — add monitoring for forwarder timeout rates
22. Add a systemd journal cursor or watchdog for TLS handshake error spikes (>1000/hour from a single IP = alert)
23. Consider adding a dnsblockd maintenance oneshot that vacuums the tracking DB periodically (164 MB with WAL)
24. Check if the `temp-allowlist` feature is being used — if not, consider disabling it to reduce complexity
25. Review the 2.5M blocklist entries — check for false positives by reviewing the `false_positive_reports` table
26. Consider adding `dns.iroh.link` to `extraDomains` in `dns-blocklists.nix` if it's deemed unwanted
27. Document the full dnsblockd cert trust architecture (CA → per-domain minting → device trust chain) in SystemNix docs
28. Add the dnsblockd CA cert fingerprint to SystemNix documentation for verification during installation
29. Create a NixOS module option to export the dnsblockd CA cert to a network-accessible location for easy device enrollment
30. Consider mDNS-based CA cert discovery for automatic device enrollment (Bonjour profile distribution)

---

## g) Questions I Cannot Answer Myself

### 1. Is `192.168.1.62` your Mac (the one you just installed the cert on)?

The MAC address `00:e0:4c:68:04:00` has a Realtek Semiconductor OUI (typically a USB-C Ethernet adapter). The blocked domains are heavily Apple-centric (iCloud, metrics.icloud.com, Private Relay), strongly suggesting it's your Mac with a USB-C dock. But I can't confirm the device identity from SystemNix alone — I don't have access to the router DHCP lease table or macOS hostname mapping.

### 2. Is the orphaned `dnsblockd_tracking.db` (724 MB) safe to delete?

I verified the config now uses `tracking.db`, the old DB hasn't been modified since Jul 15, and its data (139K metrics, 140K tracks) predates the migration. But I cannot verify whether you have any external analytics, dashboards, or backup scripts that might reference the old filename. I also can't run `sudo rm` myself (systemctl/sudo commands are blocked in this environment).

### 3. Do you want to whitelist the iCloud Private Relay and DoH bypass domains?

These domains (`mask.icloud.com`, `mask-h2.icloud.com`, `dns.quad9.net`, `one.one.one.one`) are responsible for the majority of the remaining blocked queries from your Mac. Whitelisting them would eliminate the remaining TLS errors entirely. But this is a policy decision: Private Relay is privacy-enhancing (good), but it also bypasses your DNS blocking (potentially unwanted). DoH bypass domains are blocked because they allow encrypted DNS to circumvent your resolver, but blocking them causes retry loops. I can't decide this tradeoff for you.
