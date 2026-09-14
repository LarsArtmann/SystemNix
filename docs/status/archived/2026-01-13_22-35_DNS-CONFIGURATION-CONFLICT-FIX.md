# DNS Configuration Conflict Fix - Signature Mismatch Resolution

**Date:** 2026-01-13
**Time:** 22:35 CET
**Type:** Bug Fix
**Status:** ✅ FIXED (awaiting rebuild verification)

---

## Problem Analysis

### Symptoms

After running `nixos-rebuild switch --flake .#evo-x2`, the following error occurred:

```
warning: the following units failed: network-setup.service
× network-setup.service - Networking Setup
     Loaded: loaded (/etc/systemd/system/network-setup.service; enabled; preset: ignored)
     Active: failed (Result: exit-code) since Tue 2026-01-13 20:53:56 CET
    Process: 1680077 ExecStart=/nix/store/.../network-setup-start (code=exited, status=1/FAILURE)

Jan 13 20:53:56 evo-x2 network-setup-start[1680133]: .resolvconf-wrapped: signature mismatch: /etc/resolv.conf
Jan 13 20:53:56 evo-x2 network-setup-start[1680133]: .resolvconf-wrapped: run `resolvconf -u` to update
Jan 13 20:53:56 evo-x2 systemd[1]: network-setup.service: Main process exited, code=exited, status=1/FAILURE
```

### Root Cause

**DNS Configuration Conflict:**

1. **dhcpcd** was trying to manage `/etc/resolv.conf`
2. **NixOS's network-setup.service** (via `resolvconf`) was also trying to manage `/etc/resolv.conf`
3. When both try to manage the same file, `resolvconf` detects a "signature mismatch" and fails

**Why dhcpcd was trying to manage resolv.conf:**

The dhcpcd configuration in `platforms/nixos/system/networking.nix` had:

- `nooption domain_name_servers` - prevents dhcpcd from using router DNS
- `noipv6` / `noipv6rs` - disables IPv6
- **MISSING:** `nohook resolv.conf` - this tells dhcpcd NOT to manage `/etc/resolv.conf`

Without `nohook resolv.conf`, dhcpcd still tries to run its resolv.conf hook, which attempts to update `/etc/resolv.conf`.

**Architecture Intent:**

The configuration was designed to use NixOS's declarative DNS management:

- `networking.nameservers = ["9.9.9.10" "9.9.9.11"]` sets DNS declaratively
- NixOS's `network-setup.service` (via resolvconf) updates `/etc/resolv.conf`
- dhcpcd should NOT manage `/etc/resolv.conf` - it only handles DHCP

---

## Solution

### Fix Applied

Added `nohook resolv.conf` to dhcpcd's `extraConfig` in `platforms/nixos/system/networking.nix`:

```nix
dhcpcd = {
  enable = true;
  persistent = true; # Keep DHCP lease across reboots
  extraConfig = ''
    # Let NixOS networking.nameservers manage DNS
    # This allows Technitium DNS (127.0.0.1) or Quad9 to be set via config
    nooption domain_name_servers
    # Disable IPv6 completely
    noipv6
    noipv6rs
    # Prevent dhcpcd from managing /etc/resolv.conf
    # This avoids conflicts with NixOS's network-setup.service
    nohook resolv.conf  # <-- ADDED THIS LINE
  '';
};
```

### How This Fixes the Issue

1. **`nohook resolv.conf`** tells dhcpcd: "Do NOT run the resolv.conf hook script"
2. dhcpcd stops trying to manage `/etc/resolv.conf`
3. NixOS's `network-setup.service` (via resolvconf) becomes the sole manager
4. No more signature mismatch errors
5. `/etc/resolv.conf` is updated declaratively via `networking.nameservers`

---

## Verification

### Expected Behavior After Fix

Run: `sudo nixos-rebuild switch --flake .#evo-x2`

**Expected output:**

```
building the system configuration...
activating the configuration...
setting up /etc...
reloading user units for lars...
# No "network-setup.service failed" error!
✅ Rebuild successful
```

### Check DNS Configuration

```bash
# Verify /etc/resolv.conf contains correct DNS
cat /etc/resolv.conf
# Should show:
# nameserver 9.9.9.10
# nameserver 9.9.9.11

# Or if Technitium DNS is enabled:
# nameserver 127.0.0.1

# Check network-setup.service status
systemctl status network-setup.service
# Should show: Active: active (exited)

# Check dhcpcd status
systemctl status dhcpcd.service
# Should show: Active: active (running)
```

### Verify DNS Resolution

```bash
# Test DNS resolution
host cache.nixos.org
# Should resolve quickly (<1 second)

# Test Nix cache connectivity
nix-store ping --store https://cache.nixos.org
# Should succeed
```

---

## Related Documentation

- **`docs/troubleshooting/nix-cache-dns-timeout-fix.md`** - Comprehensive DNS timeout fix documentation
- **`docs/status/2026-01-13_17-40_DEEP-RESEARCH-COMPREHENSIVE-ANALYSIS.md`** - Deep research analysis of the project
- **`fix-network-deep.sh`** - Legacy migration script (now superseded by declarative config)

---

## Legacy Scripts (Now Deprecated)

The following scripts manually edit `/etc/resolv.conf` and should **NOT be used**:

1. **`fix-dns.sh`** - Manually adds Quad9 DNS to `/etc/resolv.conf`
2. **`rebuild-after-fix.sh`** - Manually edits `/etc/resolv.conf` before rebuild
3. **`scripts/fix-nix-cache.sh`** - Manually edits `/etc/resolv.conf` to remove IPv6 DNS

**Why these scripts are now obsolete:**

- DNS is managed declaratively via `networking.nameservers`
- dhcpcd no longer manages `/etc/resolv.conf` (thanks to `nohook resolv.conf`)
- NixOS's `network-setup.service` (via resolvconf) updates `/etc/resolv.conf` automatically
- Manual edits cause signature mismatch errors and defeat the purpose of declarative configuration

**Recommended action:** Remove or deprecate these scripts to prevent future confusion.

---

## DNS Architecture Summary

### Current State (After Fix)

```
┌─────────────────────────────────────────────────┐
│  NixOS Configuration (declarative)              │
│  - networking.nameservers = ["9.9.9.10", ...]  │
└────────────────┬────────────────────────────────┘
                 │
                 │ network-setup.service (via resolvconf)
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│  /etc/resolv.conf (managed by resolvconf)      │
│  - nameserver 9.9.9.10                          │
│  - nameserver 9.9.9.11                          │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  dhcpcd (DHCP client only)                      │
│  - Gets IP address via DHCP                     │
│  - NO resolv.conf management (nohook resolv.conf) │
└─────────────────────────────────────────────────┘
```

### Previous State (Broken)

```
┌─────────────────────────────────────────────────┐
│  dhcpcd                                         │
│  - Gets IP address via DHCP                     │
│  - TRIES to manage /etc/resolv.conf ❌          │
└────────────────┬────────────────────────────────┘
                 │
                 │ Conflicts!
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│  /etc/resolv.conf (CONFLICT)                    │
│  - dhcpcd edits it                              │
│  - resolvconf edits it                          │
│  - Signature mismatch error! ❌                 │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  NixOS Configuration                            │
│  - networking.nameservers = ["9.9.9.10", ...]    │
│  - network-setup.service tries to update        │
└─────────────────────────────────────────────────┘
```

---

## Testing Checklist

- [x] Identify root cause (dhcpcd missing `nohook resolv.conf`)
- [x] Apply fix to `platforms/nixos/system/networking.nix`
- [ ] Run `sudo nixos-rebuild switch --flake .#evo-x2` to verify fix
- [ ] Verify `/etc/resolv.conf` contains correct DNS (Quad9 or 127.0.0.1)
- [ ] Verify `network-setup.service` is active (no errors)
- [ ] Verify `dhcpcd.service` is active and running
- [ ] Test DNS resolution with `host cache.nixos.org`
- [ ] Test Nix cache connectivity with `nix-store ping --store https://cache.nixos.org`

---

## Future Improvements

### Cleanup Actions

1. **Remove or deprecate legacy scripts:**
   - `fix-dns.sh`
   - `rebuild-after-fix.sh`
   - `scripts/fix-nix-cache.sh`

2. **Update documentation** to reflect that DNS is now fully declarative

3. **Add Just command** for DNS diagnostics:
   - `just dns-check` - Verify DNS configuration
   - `just dns-test` - Test DNS resolution

### Considerations

- **Technitium DNS**: If enabled in `dns-config.nix`, `networking.nameservers` should be set to `["127.0.0.1"]` to use local DNS
- **IPv6**: Currently disabled via `enableIPv6 = false` and dhcpcd `noipv6` settings
- **DNS failover**: Quad9 provides redundancy with 9.9.9.10 and 9.9.9.11

---

## References

- **dhcpcd.conf man page**: https://man7.org/linux/man-pages/man5/dhcpcd.conf.5.html
- **NixOS networking options**: https://search.nixos.org/options?query=networking.nameservers
- **resolvconf documentation**: http://manpages.ubuntu.com/manpages/xenial/man8/resolvconf.8.html

---

**Fix Status:** ✅ IMPLEMENTED - awaiting rebuild verification
**Next Step:** Run `sudo nixos-rebuild switch --flake .#evo-x2` to verify the fix
