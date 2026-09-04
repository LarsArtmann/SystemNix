# Technitium DNS Evaluation & Implementation Plan

**Date:** 2026-01-13
**Author:** Crush AI Assistant
**Target Platforms:** NixOS Laptop (evo-x2), MacBook Air M2 (Darwin), NixOS Private Cloud

---

## Executive Summary

**Recommendation: Deploy Technitium DNS selectively across your infrastructure**

Technitium DNS is an excellent choice with **native NixOS support**, comprehensive features, and strong security hardening. However, given your past DNS issues and current simple setup, I recommend a **phased deployment**:

- **Phase 1:** Deploy on NixOS Private Cloud (centralized DNS for network)
- **Phase 2:** Deploy on NixOS Laptop (evo-x2) for local caching/blocking
- **Phase 3:** Evaluate for MacBook Air M2 (optional, likely not needed)

---

## 1. Technology Analysis: Technitium DNS

### Key Features

**Core DNS Capabilities:**

- Authoritative AND recursive DNS server
- DNS-over-TLS (DoT) - Port 853
- DNS-over-HTTPS (DoH) - Port 443
- DNS-over-QUIC (DoQ) - HTTP/3
- DNSSEC validation (RSA, ECDSA, EdDSA)
- QNAME minimization
- High performance (async IO, 100,000+ req/s)

**Privacy & Security:**

- Encrypted DNS protocols (DoT/DoH/DoQ)
- DNS rebinding attack protection
- Support for popular forwarders (Cloudflare, Google, Quad9, AdGuard)
- HTTP/HTTPS proxy support (Tor, Cloudflare hidden resolver)

**Content Filtering:**

- Block ads & malware at DNS level
- Automatic daily blocklist updates
- REGEX-based blocking
- Advanced blocking with different blocklists per client IP/subnet

**Network Management:**

- Built-in DHCP server
- Split Horizon DNS
- Geolocation-based responses
- DNS Apps for custom logic
- Clustering support (manage multiple instances from single console)

**Developer-Friendly:**

- HTTP API for automation
- Multi-user role-based access
- TOTP 2FA support
- Web console (Dark Mode, port 5380 HTTP / 53443 HTTPS)
- Open source (GPLv3)
- Cross-platform (Windows, Linux, macOS, Raspberry Pi)

### Comparison with Current Setup

| Feature                | Current (Quad9 via dhcpcd) | Technitium DNS                         |
| ---------------------- | -------------------------- | -------------------------------------- |
| **DNS Caching**        | Minimal (system-level)     | Advanced (persistent, stale, prefetch) |
| **Ad Blocking**        | None                       | Yes (automatic daily blocklists)       |
| **DNS Logging**        | None                       | Yes (detailed query logs)              |
| **DNS-over-HTTPS**     | No                         | Yes (native)                           |
| **DNS-over-TLS**       | No                         | Yes (native)                           |
| **Web Interface**      | No                         | Yes (port 5380/53443)                  |
| **Clustering**         | No                         | Yes                                    |
| **Custom DNS Zones**   | No                         | Yes (authoritative server)             |
| **DHCP Server**        | No                         | Yes (built-in)                         |
| **Network Complexity** | Very Low                   | Medium                                 |
| **Maintenance**        | Zero                       | Low (blocklists auto-update)           |

---

## 2. Current DNS Configuration Analysis

### NixOS Laptop (evo-x2)

**Current Setup:**

```nix
# platforms/nixos/system/networking.nix
networking.nameservers = ["9.9.9.10" "9.9.9.11"];  # Quad9 DNS
services.resolved.enable = false;  # Disabled to prevent conflicts
networking.dhcpcd.extraConfig = ''
  static domain_name_servers=9.9.9.10 9.9.9.11
  noipv6  # IPv6 disabled due to timeout issues
'';
```

**Recent DNS Issues Resolved:**

- ✅ IPv6 DNS timeouts (disabled IPv6)
- ✅ NetworkManager conflicts (switched to dhcpcd)
- ✅ Nix cache timeouts (increased connect-timeout to 120s)
- ✅ File descriptor limits (increased to 65536)

**Performance:**

- Works well for daily use
- No caching (relies on system-level resolver)
- No ad blocking
- Simple, predictable behavior

### MacBook Air M2 (Darwin)

**Current Setup:**

- Uses macOS default DNS resolution
- No custom DNS configuration
- Likely uses router DNS or ISP DNS
- **Not documented in current config files**

---

## 3. Cross-Platform Compatibility Analysis

### NixOS Support ✅ **EXCELLENT**

**Availability:** Native NixOS module in Nixpkgs
**Module Path:** `services.technitium-dns-server`
**Version:** Latest (v14.3+)
**Installation:** One-line enable in NixOS config

**Sample Configuration:**

```nix
services.technitium-dns-server = {
  enable = true;
  openFirewall = true;
  # Uses default ports: 53 (DNS), 5380 (HTTP), 53443 (HTTPS)
};
```

**Security Hardening (Built-in):**

- Dynamic user (no root)
- Private devices, mounts, tmp
- No new privileges
- System call filtering (seccomp)
- Capability bounding (only CAP_NET_BIND_SERVICE)

### Darwin (macOS) Support ⚠️ **POSSIBLE WITH DOCKER**

**Availability:** Not native to nix-darwin
**Alternative:** Docker container
**Docker Image:** `technitium/dns-server:latest`
**Installation:** Manual Docker setup or via Nix's `virtualisation.docker`

**Considerations:**

- Docker adds complexity
- Not integrated with nix-darwin system config
- Requires manual service management
- Port conflicts possible (macOS already uses 53 for system DNS)

**Recommendation:** **Do NOT deploy on MacBook Air** - use it as a client to the NixOS DNS servers instead.

---

## 4. Deployment Architecture Recommendation

### Recommended Architecture: **Centralized DNS with Local Caching**

```
┌─────────────────────────────────────────────────────────────┐
│                     NixOS Private Cloud                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           Technitium DNS Server (Primary)           │  │
│  │  - Authoritative for internal domains               │  │
│  │  - Recursive for external lookups                   │  │
│  │  - Ad blocking for entire network                   │  │
│  │  - DNS-over-HTTPS/TLS for privacy                  │  │
│  │  - Clustering master                                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ (DoH/DoT/DoQ)
                              ▼
┌─────────────────────┐                 ┌─────────────────────┐
│   NixOS Laptop      │                 │  MacBook Air M2     │
│    (evo-x2)         │                 │   (Darwin)          │
│  ┌───────────────┐ │                 │                     │
│  │   Local       │ │                 │  Configure to use    │
│  │   Technitium  │ │                 │  Private Cloud DNS  │
│  │   DNS Server  │ │                 │  via DoH/DoT        │
│  │   (Cache)     │ │                 │                     │
│  └───────────────┘ │                 │                     │
└─────────────────────┘                 └─────────────────────┘
```

### Deployment Phases

#### Phase 1: Private Cloud (NIXOS ONLY - HIGH PRIORITY)

**Why:**

- Centralized control for entire network
- Single point of management for ad blocking, logging
- Can serve other devices on network
- Minimal overhead (already running NixOS)

**Configuration:**

```nix
# platforms/nixos/private-cloud/dns.nix (NEW FILE)
services.technitium-dns-server = {
  enable = true;
  openFirewall = true;
  firewallUDPPorts = [ 53 ];  # Standard DNS
  firewallTCPPorts = [
    53
    5380     # Web console (HTTP)
    53443    # Web console (HTTPS)
    443      # DNS-over-HTTPS
    853      # DNS-over-TLS
  ];
};

# Alternative: Disable built-in DHCP if already using another DHCP server
# services.dhcpcd.enable = false;  # Depends on your setup
```

**Initial Setup via Web Console (http://private-cloud:5380):**

1. Set admin password
2. Configure forwarders (Quad9, Cloudflare, Google)
3. Enable DNS-over-HTTPS/TLS
4. Add ad blocking blocklists
5. Configure DNS caching (persistent cache to disk)
6. Set up logging
7. Test DNS resolution

**Benefits:**

- Network-wide ad blocking
- Centralized DNS logging for all devices
- Privacy via encrypted DNS
- Single source of truth for DNS policy

#### Phase 2: NixOS Laptop (evo-x2) (MEDIUM PRIORITY)

**Why:**

- Local caching reduces latency
- Device-specific ad blocking
- Works offline with cached entries
- Consistent with NixOS architecture

**Configuration:**

```nix
# platforms/nixos/system/dns.nix (NEW FILE - replace/extend networking.nix)
services.technitium-dns-server = {
  enable = true;
  openFirewall = false;  # Local only, no need to open to network
};

# Configure system to use local DNS
networking.nameservers = [ "127.0.0.1" ];  # Use local Technitium DNS

# In Technitium DNS web console (http://localhost:5380):
# 1. Configure forwarders (Private Cloud via DoH/DoT, or Quad9 directly)
# 2. Enable ad blocking blocklists
# 3. Enable persistent caching
# 4. Test DNS resolution
```

**Integration with Current Setup:**

- Replaces Quad9 direct resolution
- Adds caching and ad blocking
- Can forward to Private Cloud (Phase 3) or public DNS directly
- Maintains compatibility with current dhcpcd setup

**Benefits:**

- Faster DNS resolution (local cache)
- Works offline (cached entries)
- Device-specific control
- Reduces bandwidth (caching)

#### Phase 3: MacBook Air M2 (OPTIONAL - LOW PRIORITY)

**Why NOT Recommended:**

- No native nix-darwin support
- Docker adds unnecessary complexity
- macOS already manages DNS well
- Laptop is mobile, might connect to different networks
- Better to use it as a client

**Alternative: Use as Client**

```bash
# Configure macOS to use Private Cloud DNS (via DoH)
# System Settings > Network > Wi-Fi > DNS
# Add Private Cloud IP as DNS server

# Or via command line (requires elevated privileges)
sudo networksetup -setdnsservers Wi-Fi <private-cloud-ip>

# Verify
scutil --dns
```

**Benefits:**

- No local DNS server overhead
- Uses centralized policy
- Simple configuration
- Works across networks

---

## 5. Implementation Steps

### Phase 1: Deploy on NixOS Private Cloud

**Step 1.1: Create DNS Configuration Module**

```bash
# Create new module file
touch platforms/nixos/private-cloud/dns.nix
```

**Step 1.2: Add Technitium DNS Configuration**

```nix
# platforms/nixos/private-cloud/dns.nix
{
  services.technitium-dns-server = {
    enable = true;
    openFirewall = true;
    firewallUDPPorts = [ 53 ];
    firewallTCPPorts = [ 53 5380 53443 443 853 ];
  };

  # Optional: Replace existing DHCP server with Technitium's built-in DHCP
  # services.dhcpcd.enable = false;
  # services.dhcpd4.enable = false;  # If using dhcpd
}
```

**Step 1.3: Import DNS Module in Main Config**

```nix
# platforms/nixos/private-cloud/default.nix
imports = [
  ./dns.nix  # Add this line
  ./system.nix
  # ... other imports
];
```

**Step 1.4: Rebuild NixOS**

```bash
sudo nixos-rebuild switch --flake .#private-cloud-hostname
```

**Step 1.5: Access Web Console**

```bash
# Open browser to:
http://private-cloud-ip:5380
# Default credentials: admin / admin (CHANGE IMMEDIATELY!)
```

**Step 1.6: Configure Technitium DNS (via Web Console)**

1. **Security:** Change admin password
2. **Forwarders:** Add Quad9 (9.9.9.10, 9.9.9.11), Cloudflare (1.1.1.1, 1.0.0.1)
3. **Encrypted DNS:** Enable DoH/DoT for forwarders
4. **Blocklists:** Add popular blocklists (StevenBlack, AdGuard DNS)
5. **Caching:** Enable persistent cache to disk
6. **Logging:** Enable query logging
7. **Test:** Use "DNS Client" tab to test resolution

**Step 1.7: Configure Network Devices**

- Configure router DHCP to point DNS server to Private Cloud IP
- OR manually configure devices to use Private Cloud DNS

**Step 1.8: Verify**

```bash
# From another device (e.g., MacBook Air)
dig @private-cloud-ip google.com
# Should return IP address

# Test ad blocking
dig @private-cloud-ip doubleclick.net
# Should return 0.0.0.0 or NXDOMAIN
```

### Phase 2: Deploy on NixOS Laptop (evo-x2)

**Step 2.1: Create DNS Configuration Module**

```bash
touch platforms/nixos/system/dns.nix
```

**Step 2.2: Add Local Technitium DNS Configuration**

```nix
# platforms/nixos/system/dns.nix
{
  services.technitium-dns-server = {
    enable = true;
    openFirewall = false;  # Local only
  };

  # Update networking to use local DNS
  networking.nameservers = [ "127.0.0.1" ];
}
```

**Step 2.3: Update Main Configuration**

```nix
# platforms/nixos/system/configuration.nix
imports = [
  ./dns.nix  # Add this line
  ./networking.nix
  # ... other imports
];

# Remove Quad9 from networking.nix (optional, since we're overriding nameservers)
```

**Step 2.4: Rebuild NixOS**

```bash
sudo nixos-rebuild switch --flake .#evo-x2
```

**Step 2.5: Configure Technitium DNS (via Web Console)**

```bash
# Open browser to:
http://localhost:5380

# Configuration steps:
1. Change admin password
2. Configure forwarders:
   - Primary: Private Cloud (via DoH/DoT)
   - Fallback: Quad9 (9.9.9.10, 9.9.9.11)
3. Enable ad blocking blocklists
4. Enable persistent caching
5. Enable DNSSEC validation
6. Test resolution
```

**Step 2.6: Verify**

```bash
# Test DNS resolution
dig google.com

# Test ad blocking
dig doubleclick.net

# Check cache stats
# (via web console > Query Log)

# Test offline behavior
# Disconnect network, try resolving previously visited domains
```

### Phase 3: Configure MacBook Air M2 (Optional)

**Step 3.1: Configure macOS DNS Settings**

```bash
# Get Private Cloud IP
PRIVATE_CLOUD_IP="192.168.1.100"  # Replace with actual IP

# Set DNS server for Wi-Fi
sudo networksetup -setdnsservers Wi-Fi $PRIVATE_CLOUD_IP

# Verify
scutil --dns
```

**Step 3.2: Test**

```bash
# Test DNS resolution
dig google.com

# Test ad blocking
dig doubleclick.net

# Test encrypted DNS (if enabled on Private Cloud)
# This requires macOS 14+ and specific configuration
```

**Step 3.3: Create Alias (Optional)**

```bash
# Add to ~/.config/fish/config.fish
alias dns-status='scutil --dns'
alias dns-test='dig google.com && dig doubleclick.net'
```

---

## 6. Risk Assessment & Mitigation

### Risks

**1. Increased Complexity**

- **Risk:** Technitium DNS adds another service to manage
- **Mitigation:** Well-documented, stable, auto-updating blocklists
- **Impact:** Low

**2. Single Point of Failure**

- **Risk:** If Private Cloud DNS fails, all devices lose DNS
- **Mitigation:** Configure fallback forwarders (Quad9, Cloudflare)
- **Impact:** Medium

**3. Resource Usage**

- **Risk:** DNS server uses CPU/memory
- **Mitigation:** Minimal resources (async IO, efficient caching)
- **Impact:** Low

**4. Configuration Complexity**

- **Risk:** Web console has many options
- **Mitigation:** Start with defaults, incremental changes
- **Impact:** Low

**5. Network Latency**

- **Risk:** DNS queries to Private Cloud slower than local DNS
- **Mitigation:** Caching, local DNS on evo-x2
- **Impact:** Low

### Benefits vs. Risks

| Metric              | Current Setup     | Technitium DNS        |
| ------------------- | ----------------- | --------------------- |
| **DNS Speed**       | Fast (no caching) | Faster (with caching) |
| **Ad Blocking**     | None              | Yes                   |
| **Privacy**         | Medium (Quad9)    | High (DoH/DoT)        |
| **Complexity**      | Very Low          | Medium                |
| **Maintainability** | Excellent         | Good                  |
| **Reliability**     | Excellent         | Excellent             |
| **Visibility**      | None              | Full logging          |

**Net Benefit:** ✅ **POSITIVE** (Benefits significantly outweigh risks)

---

## 7. Alternative Approaches Considered

### Alternative 1: Use Unbound Instead

**Why Rejected:**

- Unbound is more complex to configure
- No built-in ad blocking (requires external blocklists)
- No web console (CLI only)
- Less actively developed

**When to Consider:**

- You prefer CLI-only management
- You want maximum performance (Unbound is slightly faster)
- You have existing Unbound expertise

### Alternative 2: Use dnscrypt-proxy + AdGuard Home

**Why Rejected:**

- Requires two services (dnscrypt-proxy + AdGuard Home)
- More complex architecture
- AdGuard Home is less feature-rich than Technitium DNS
- No native NixOS module for AdGuard Home

**When to Consider:**

- You specifically need dnscrypt protocol
- You prefer AdGuard's simpler interface

### Alternative 3: Keep Current Setup (Quad9)

**Why Rejected:**

- No ad blocking
- No caching
- No logging
- No web console
- Misses out on privacy features (DoH/DoT)

**When to Consider:**

- You want zero complexity
- You don't need ad blocking
- You don't care about DNS privacy

---

## 8. Performance Impact

### Resource Usage Estimates

**NixOS Private Cloud (assuming 4+ devices):**

- CPU: ~1-2% (idle), ~5-10% (peak)
- Memory: ~50-100MB
- Disk: ~100-500MB (for persistent cache)
- Network: Negligible (DNS is tiny)

**NixOS Laptop (evo-x2):**

- CPU: <1% (idle), ~3-5% (peak)
- Memory: ~30-50MB
- Disk: ~50-200MB (for persistent cache)
- Network: Negligible

**Comparison with Current Setup:**

- Current: Near-zero resources
- Technitium DNS: Minimal resources (unnoticeable in practice)

### DNS Resolution Speed

**Scenario 1: First Lookup (No Cache)**

- Current: ~50-100ms (Quad9 direct)
- Technitium DNS: ~60-120ms (via forwarder)
- **Impact:** Negligible (~10-20ms overhead)

**Scenario 2: Cached Lookup**

- Current: ~50-100ms (no caching)
- Technitium DNS: ~1-5ms (local cache)
- **Impact:** Significant improvement (10-100x faster)

**Scenario 3: Ad/Malware Domain**

- Current: Returns IP (ad loads)
- Technitium DNS: ~1-5ms (blocked)
- **Impact:** Significant improvement (privacy, speed)

---

## 9. Monitoring & Maintenance

### Monitoring

**Web Console Monitoring:**

- Query log (real-time)
- Request rate
- Cache hit rate
- Blocked queries
- Server uptime

**System Monitoring:**

```bash
# Check service status
systemctl status technitium-dns-server

# View logs
journalctl -u technitium-dns-server -f

# Check resource usage
htop  # Look for technitium-dns-server process
```

### Maintenance

**Automatic:**

- Blocklist updates (daily, automatic)
- Cache expiration (TTL-based)
- Log rotation (systemd-managed)

**Manual (Optional):**

- Review query logs (monthly)
- Update configuration (as needed)
- Review security updates (via `just update`)

### Backup & Recovery

**Configuration Backup:**

```bash
# Technitium DNS stores config in state directory
sudo tar -czf technitium-dns-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/technitium-dns-server/

# Restore
sudo tar -xzf technitium-dns-backup-YYYYMMDD.tar.gz -C /
sudo systemctl restart technitium-dns-server
```

**NixOS Rollback:**

```bash
# If DNS update causes issues, rollback NixOS
sudo nixos-rebuild switch --rollback
```

---

## 10. Migration Timeline

### Week 1: Planning (Current Week)

- ✅ Research completed
- ✅ Architecture determined
- ✅ Implementation plan created

### Week 2: Private Cloud Deployment

- Deploy Technitium DNS on Private Cloud
- Configure blocklists, forwarders
- Test with network devices
- Verify ad blocking, logging

### Week 3: Laptop Deployment

- Deploy Technitium DNS on evo-x2
- Configure forwarders to Private Cloud
- Test local caching, ad blocking
- Verify performance improvement

### Week 4: MacBook Air Configuration

- Configure macOS to use Private Cloud DNS
- Test resolution, ad blocking
- Verify encrypted DNS (DoH/DoT)
- **Optional:** Evaluate local DNS on MacBook Air

### Week 5: Optimization & Documentation

- Fine-tune blocklists
- Optimize caching settings
- Document configuration
- Create monitoring dashboard

---

## 11. Cost-Benefit Analysis

### Implementation Costs

- **Time:** 4-8 hours (spread over 4 weeks)
- **Learning Curve:** Low (intuitive web console)
- **Maintenance:** Low (automatic blocklist updates)

### Benefits

- **Ad Blocking:** Network-wide ad blocking (privacy, speed)
- **DNS Caching:** Faster resolution (10-100x for cached)
- **Privacy:** Encrypted DNS (DoH/DoT)
- **Visibility:** Full DNS query logging
- **Control:** Fine-grained control over DNS policy
- **Offline Capability:** Cached entries work offline

### ROI (Return on Investment)

- **Time to Break Even:** ~1 week (faster resolution saves time)
- **Long-term ROI:** Very High (ongoing benefits, minimal maintenance)

---

## 12. Final Recommendations

### ✅ RECOMMENDED: Deploy Technitium DNS

**Priority 1:** Deploy on NixOS Private Cloud (Week 2)
**Priority 2:** Deploy on NixOS Laptop (evo-x2) (Week 3)
**Priority 3:** Configure MacBook Air as client (Week 4)
**Priority 4:** Evaluate local DNS on MacBook Air (Optional)

### Key Success Factors

1. **Start Simple:** Use default configuration, incremental changes
2. **Test Thoroughly:** Verify DNS resolution, ad blocking, performance
3. **Monitor Actively:** Check logs, query rates, cache hit rates
4. **Document Changes:** Track configuration, lessons learned
5. **Rollback Plan:** Keep NixOS rollback available

### Decision Framework

| Platform                  | Deploy Technitium DNS? | Why?                                                         |
| ------------------------- | ---------------------- | ------------------------------------------------------------ |
| **NixOS Private Cloud**   | ✅ YES                 | Centralized control, network-wide benefits, minimal overhead |
| **NixOS Laptop (evo-x2)** | ✅ YES                 | Local caching, device-specific control, offline capability   |
| **MacBook Air M2**        | ⚠️ NO (as server)       | No native support, Docker complexity, mobile device          |
| **MacBook Air M2**        | ✅ YES (as client)     | Simple configuration, uses centralized policy                |

---

## 13. Next Steps

### Immediate Actions (This Week)

1. ✅ Review this evaluation document
2. ✅ Decide on deployment schedule
3. ✅ Prepare Private Cloud for deployment
4. ✅ Backup current DNS configuration

### Next Week (Week 2)

1. Deploy Technitium DNS on Private Cloud
2. Configure blocklists, forwarders
3. Test with network devices
4. Document any issues

### Questions?

- Do you want me to proceed with implementation?
- Which phase do you want to start with?
- Do you have any concerns or questions?

---

**Appendix: Resources**

- Technitium DNS Website: https://technitium.com/dns/
- GitHub Repository: https://github.com/TechnitiumSoftware/DnsServer
- NixOS Module: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/networking/technitium-dns-server.nix
- NixOS Package: https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/te/technitium-dns-server/package.nix
- Documentation: https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md

---

**End of Evaluation**
