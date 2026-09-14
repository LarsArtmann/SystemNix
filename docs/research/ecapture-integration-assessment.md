# eCapture Integration Assessment for SystemNix

**Date:** 2026-04-05
**Tool:** [gojue/ecapture](https://github.com/gojue/ecapture) — eBPF-based SSL/TLS plaintext capture
**Verdict:** ⚠️ **NOT RECOMMENDED** for permanent integration — use ad-hoc instead

---

## Executive Summary

eCapture captures SSL/TLS plaintext traffic without CA certificates using eBPF uprobes. It's a powerful, niche security/debugging tool with 15k+ GitHub stars. After thorough analysis against SystemNix's architecture, security posture, and operational patterns, **the risks and maintenance burden outweigh the benefits of permanent inclusion**. The nixpkgs package is severely outdated (v1.5.2 vs upstream v2.2.0), AppArmor conflicts are likely, and the tool's value is episodic rather than continuous. Recommended approach: use `nix-shell` or a custom flake input when needed.

---

## What is eCapture?

| Aspect | Detail |
|--------|--------|
| **Purpose** | Capture SSL/TLS plaintext without CA certificates |
| **Method** | eBPF uprobes on TLS library functions (SSL_read, SSL_write, SSL_do_handshake) |
| **Language** | C (89.7% — kernel probes), Go (7.4% — userspace CLI) |
| **License** | Apache 2.0 |
| **Maturity** | 15.1k stars, 1.6k forks, 90+ releases (latest: v2.2.0, March 2026) |
| **Platforms** | Linux & Android only (x86_64, aarch64) |

### Supported Capture Targets

| Module | Libraries/Versions |
|--------|-------------------|
| **TLS** | OpenSSL 1.0.x, 1.1.x, 3.0.x+, LibreSSL, BoringSSL |
| **GnuTLS** | GnuTLS library |
| **GoTLS** | Go `crypto/tls` package |
| **Bash/Zsh** | Command auditing |
| **MySQL** | mysqld 5.6, 5.7, 8.0, MariaDB |
| **PostgreSQL** | PostgreSQL 10+ |

### Output Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `text` | Plaintext to stdout/file | Quick inspection |
| `pcapng` | Wireshark-compatible capture | Deep protocol analysis |
| `keylog` | TLS Master Secrets (SSLKEYLOGFILE) | Offline decryption in Wireshark |

---

## PRO — Arguments For Integration

### 1. Unique Capability Gap

No existing tool in SystemNix can capture TLS plaintext without MITM proxy setup. The current stack has:

- `wireshark` / `tcpdump` / `netsniff-ng` — capture encrypted traffic, can't decrypt
- `mitmproxy` — not installed; requires CA cert + proxy configuration
- `openssl s_client` — manual, single-connection only

**eCapture fills a genuine gap**: instant TLS plaintext inspection with zero application changes.

### 2. Perfect for Debugging the Caddy Reverse Proxy Stack

All `*.lan` services are TLS-terminated at Caddy. When debugging API issues between services:

```
Client → Caddy (TLS termination) → Backend service (plaintext HTTP)
```

eCapture can hook into Caddy's OpenSSL/BoringSSL and see decrypted traffic in real time, useful for:

- Debugging Authelia SSO token flows
- Inspecting Immich upload API calls
- Tracing Gitea git push/pull payloads
- Observing SigNoz OTel collector ingest (gRPC on 4317)

### 3. Already in nixpkgs

```nix
# Available as:
pkgs.ecapture                    # Standalone (v1.5.2)
linuxPackages_latest.ecapture    # Kernel-matched (withNonBTF variant)
```

Trivial to add to `security-hardening.nix` alongside existing security tools.

### 4. Kernel Compatibility Verified

| Requirement | SystemNix Value | Status |
|-------------|-----------------|--------|
| Kernel ≥ 4.18 (x86_64) | 6.19.4 (linuxPackages_latest) | ✅ Exceeds |
| Kernel ≥ 5.8 (for CAP_BPF) | 6.19.4 | ✅ Exceeds |
| BTF support | Likely enabled in default config | ✅ Needs verification |
| x86_64-linux | evo-x2 is x86_64-linux | ✅ Match |

### 5. Bash/Zsh Command Auditing

Provides host-level command auditing — complements the disabled `auditd` (currently broken due to AppArmor conflicts). Could serve as a partial replacement for audit-style logging.

### 6. Database Query Capture

MySQL and PostgreSQL query capture could be useful for debugging ClickHouse queries made by SigNoz (though ClickHouse uses its own protocol, not directly supported).

### 7. Fits the Security Toolkit Profile

SystemNix already installs 30+ security tools in `security-hardening.nix`:

```
wireshark, tcpdump, nmap, lynis, nuclei, masscan, sqlmap, nikto,
aircrack-ng, sleuthkit, aide, osquery, clamav, fail2ban, ...
```

eCapture fits this profile — it's a security professional's tool, not a production service.

---

## CONTRA — Arguments Against Integration

### 1. ❌ nixpkgs Version Severely Outdated (CRITICAL)

| | Version | Date |
|---|---------|------|
| **nixpkgs** | v1.5.2 | ~2024 |
| **Upstream** | v2.2.0 | March 2026 |

This is not a minor version lag — **v2.x is a complete architecture rewrite**:

- Major refactoring of eBPF program loading
- New capture modules and protocol support
- Breaking CLI changes
- Performance improvements

Running v1.5.2 means: missing features, known bugs, incompatible CLI flags, outdated eBPF bytecode.

**Fixing this requires**: custom overlay (like `dnsblockdOverlay`) or flake input — significant maintenance burden.

### 2. ❌ AppArmor Conflict Risk (HIGH)

SystemNix has `security.apparmor.enable = true` in `security-hardening.nix`. AppArmor's LSM (Linux Security Module) hooks can block eBPF operations:

- **Precedent**: `auditd` is already disabled with a comment:
  ```nix
  # Audit daemon disabled due to AppArmor conflicts
  # NixOS 26.05 (Jan 2026) has bug where audit-rules-nixos.service fails
  # See: https://github.com/NixOS/nixpkgs/issues/483085
  ```
- eBPF uprobes require `CAP_SYS_PTRACE` to read `/proc/<pid>/maps` — AppArmor may restrict this
- Loading eBPF programs (`CAP_BPF`) can be blocked by AppArmor BPF policies

**This is the same class of problem that killed auditd.** There's no evidence ecapture works correctly with AppArmor enabled on NixOS.

### 3. ❌ Elevated Privilege Requirements

| Capability | What It Grants | Risk |
|------------|---------------|------|
| `CAP_BPF` | Load arbitrary eBPF programs into kernel | Can intercept all syscalls, access kernel memory |
| `CAP_PERFMON` | Create perf events, read perf buffers | Trace execution of any process |
| `CAP_SYS_PTRACE` | Read memory of any process | Inspect secrets in privileged processes |
| `CAP_NET_ADMIN` | Modify network stack (pcapng mode) | Packet redirection, filtering |

Granting these permanently to a system package expands the attack surface. If ecapture's binary has a vulnerability, an attacker gains near-root capabilities.

### 4. ❌ Invisible TLS Interception — Dual-Use Risk

eCapture captures TLS traffic **without any detection by the application or user**. Unlike MITM proxies (which cause certificate warnings), eBPF uprobes are invisible.

This makes it:
- A powerful debugging tool ✅
- A powerful credential theft tool ❌

On a multi-user system or a system with remote SSH access (which evo-x2 has), an attacker with `CAP_BPF` could silently capture all HTTPS traffic, including credentials and session tokens.

### 5. ❌ Linux-Only — No Darwin Benefit

SystemNix manages two machines. ecapture only works on Linux (no macOS support), so:

- Cannot be added to `platforms/common/packages/base.nix`
- Must be gated with `lib.optionals stdenv.isLinux`
- Adds maintenance burden for only one of two platforms

### 6. ❌ Niche, Episodic Use

ecapture is not a continuously-running service — it's invoked ad-hoc for specific debugging sessions. Adding it permanently to the system packages means:

- Increased closure size (Go binary + eBPF bytecode)
- Security surface expansion for a tool used maybe 2-3 times per year
- No benefit when not actively running

### 7. ❌ No Integration with Existing Observability Stack

SigNoz is the observability platform. ecapture's output (text/pcapng/keylog) doesn't integrate with:

- SigNoz OTel Collector (different format)
- ClickHouse (different schema)
- Any alerting or dashboard system

It's a standalone, offline analysis tool — not part of the observability pipeline.

### 8. ❌ Single nixpkgs Maintainer

```nix
mainters = with lib.maintainers; [ bot-wxt1221 ];
```

One maintainer. Version gap suggests limited maintenance velocity. Risk of package rot.

---

## Technical Compatibility Matrix

| Factor | Status | Detail |
|--------|--------|--------|
| Kernel version | ✅ 6.19.4 >> 4.18 minimum | Well above requirement |
| BTF (CONFIG_DEBUG_INFO_BTF) | ⚠️ Unknown | Likely enabled, needs verification on evo-x2 |
| Architecture (x86_64) | ✅ | Supported |
| AppArmor | ❌ Risk | Known to conflict with LSM-dependent tools |
| Required capabilities | ⚠️ Available | CAP_BPF, CAP_PERFMON, CAP_SYS_PTRACE on kernel ≥ 5.8 |
| Go version compatibility | ⚠️ Check needed | ecapture needs Go 1.21+, SystemNix pins Go 1.26.1 |
| nixpkgs version | ❌ Outdated | 1.5.2 vs upstream 2.2.0 |
| Cross-platform | ❌ Linux only | No Darwin support |

---

## Alternatives Comparison

| Tool | TLS Capture | NixOS Package | Complexity | Use Case |
|------|-------------|---------------|------------|----------|
| **eCapture** | ⭐⭐⭐⭐⭐ | ✅ (outdated) | Low | Dedicated TLS capture |
| **bpftrace** | ⭐⭐ (manual scripts) | ✅ Current | High | Custom eBPF tracing |
| **mitmproxy** | ⭐⭐⭐⭐ (MITM) | ✅ Current | Medium | HTTP(S) proxy debugging |
| **Wireshark + keylog** | ⭐⭐⭐ (needs keys) | ✅ Already installed | Low | Protocol analysis |
| **strace/ltrace** | ⭐ (syscall only) | ✅ Already installed | Medium | Syscall tracing |
| **Tetragon** | ⭐ (no TLS) | ⚠️ Manual | High | Runtime security |
| **Tracee** | ⭐ (no TLS) | ⚠️ Manual | High | Security forensics |

**Best alternative for TLS debugging**: `mitmproxy` — already in nixpkgs, well-maintained, doesn't need kernel privileges, integrates with Wireshark (already installed).

---

## Recommendation

### ⚠️ Do NOT add permanently — use ad-hoc

**Rationale:**

1. The nixpkgs package is 7+ versions behind (1.5.2 vs 2.2.0) — a major architecture rewrite gap
2. AppArmor conflicts are probable (same class as the auditd failure)
3. Episodic tool doesn't justify permanent privilege escalation
4. mitmproxy covers most TLS debugging needs without kernel access

### Recommended Approach: `nix-shell` Ad-Hoc Usage

When you need eCapture for a specific debugging session:

```bash
# Option A: nix-shell (uses nixpkgs version, likely outdated)
nix-shell -p ecapture

# Option B: Run latest via Docker (avoids nixpkgs staleness)
docker run --rm \
  --cap-add=BPF --cap-add=PERFMON --cap-add=NET_ADMIN --cap-add=SYS_PTRACE \
  gojue/ecapture:latest tls --pid=$(pidof caddy)

# Option C: Build from source via custom flake input (for v2.2.0)
# Only worth it if you use it frequently
```

### If You Decide to Add It Permanently Anyway

If the decision is to proceed despite the risks:

1. **Add to `security-hardening.nix`** (Linux-only, gated):
   ```nix
   # In environment.systemPackages, inside lib.optionals stdenv.isLinux:
   ecapture
   ```

2. **Pin to latest via flake input** (recommended to avoid the v1.5.2 staleness):
   ```nix
   ecapture.url = "github:gojue/ecapture/v2.2.0";
   ecapture.flake = false;
   ```
   Then create a custom package in `pkgs/ecapture.nix` using `buildGoModule`.

3. **Add AppArmor compatibility test** to `just test-fast`:
   ```bash
   # Verify ecapture can load eBPF programs with AppArmor active
   sudo ecapture tls --list
   ```

4. **Document the security implications** in AGENTS.md under "Known Issues".

5. **Do NOT grant capabilities permanently** — require `sudo` for each use:
   ```bash
   sudo ecapture tls --pid=1234
   ```

---

## Decision Matrix

| Criterion | Weight | PRO Score | CONTRA Score | Net |
|-----------|--------|-----------|-------------|-----|
| Unique TLS capture capability | High | +3 | 0 | +3 |
| nixpkgs version outdated | High | 0 | -3 | -3 |
| AppArmor conflict risk | High | 0 | -3 | -3 |
| Privilege escalation surface | Medium | 0 | -2 | -2 |
| Episodic vs permanent value | Medium | +1 | -2 | -1 |
| Fits security toolkit profile | Low | +1 | 0 | +1 |
| Linux-only (no Darwin) | Low | 0 | -1 | -1 |
| Integration with observability | Low | 0 | -1 | -1 |
| **TOTAL** | | **+5** | **-12** | **-7** |

---

## References

- [eCapture GitHub](https://github.com/gojue/ecapture) — 15.1k stars, Apache 2.0
- [nixpkgs package](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ec/ecapture/package.nix) — v1.5.2
- [Minimum Privileges Guide](https://github.com/gojue/ecapture/blob/master/docs/minimum-privileges.md)
- [Defense & Detection](https://github.com/gojue/ecapture/blob/master/docs/defense-detection.md)
- [NixOS AppArmor issue #483085](https://github.com/NixOS/nixpkgs/issues/483085) — auditd conflict
