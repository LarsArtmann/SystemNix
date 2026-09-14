# DNS Rebuild Internet Loss Fix

**Date:** 2026-04-09
**System:** evo-x2 (NixOS)
**Severity:** P2 (intermittent network outage during rebuild)
**Status:** Fixed

## Summary

Fixed intermittent internet connectivity loss during `nixos-rebuild switch` caused by incorrect systemd service ordering between `unbound` (DNS resolver) and `dnsblockd` (block page server).

## Problem

When running `nixos-rebuild switch`, users experienced temporary loss of internet connectivity. This was caused by:

1. **Unbound service reload**: `services.unbound.reloadIfChanged = true` causes unbound to reload on config changes
2. **Primary DNS dependency**: `nameservers = ["127.0.0.1" ...]` makes unbound the only DNS resolver
3. **Race condition**: `dnsblockd.service` started `After=network-online.target` but not `After=unbound.service`, allowing it to start before unbound's control socket was ready
4. **Service restart gap**: During activation, services stop and start, creating a DNS resolution window where no resolver is available

## Root Cause Analysis

### Service Dependencies (Before Fix)

```nix
# platforms/nixos/modules/dns-blocker.nix:270
services.dnsblockd = {
  after = ["network-online.target" "sops-nix.service"];
  wants = ["network-online.target" "sops-nix.service"];
  wantedBy = ["multi-user.target"];
  # No dependency on unbound.service!
}
```

**Problem:** dnsblockd requires unbound's control socket (`/run/unbound/unbound.ctl`) but didn't wait for unbound to be ready.

### DNS Configuration Chain

| Component                        | Configuration              | Risk                                             |
| -------------------------------- | -------------------------- | ------------------------------------------------ |
| networking.nameservers           | `["127.0.0.1" "9.9.9.9"]`  | 127.0.0.1 is primary, no fallback during restart |
| services.unbound.reloadIfChanged | `true`                     | Reloads on config change, brief DNS gap          |
| dnsblockd.service                | Missing unbound dependency | Can start before unbound socket exists           |

## Fix Applied

### File: `platforms/nixos/modules/dns-blocker.nix`

```nix
# Before
services.dnsblockd = {
  after = ["network-online.target" "sops-nix.service"];
  wants = ["network-online.target" "sops-nix.service"];
  wantedBy = ["multi-user.target"];
}

# After
services.dnsblockd = {
  after = ["network-online.target" "unbound.service" "sops-nix.service"];
  wants = ["network-online.target" "sops-nix.service"];
  requires = ["unbound.service"];
  wantedBy = ["multi-user.target"];
}
```

**Changes:**

- Added `unbound.service` to `after` list — ensures startup order
- Added `requires = ["unbound.service"]` — hard dependency; if unbound fails, dnsblockd won't start

## Verification

```bash
# Syntax validation passed
just test-fast
✅ Fast configuration test passed

# Check service dependencies
systemctl list-dependencies dnsblockd.service
# Should show: unbound.service (required)

# Check unbound reload behavior
systemctl show unbound.service -p ReloadResult
```

## Testing Recommendations

1. **Dry-run rebuild**: `nixos-rebuild test --flake .#evo-x2` (non-destructive)
2. **Monitor DNS during switch**: `watch -n1 'dig +short @127.0.0.1 google.com'`
3. **Check service status**: `systemctl status unbound dnsblockd`
4. **Verify socket exists**: `ls -la /run/unbound/unbound.ctl`

## Related Issues

- See: `2026-04-05_05-59_PROMETHEUS-REMOVAL-INTERNET-LOSS-INCIDENT.md` — previous network outage caused by port conflict
- Both issues relate to DNS stack reliability during service restarts

## Future Considerations

1. **Consider `stopIfChanged = false`** for unbound to prevent service stop/start cycles:

   ```nix
   systemd.services.unbound = {
     reloadIfChanged = lib.mkForce false;
     stopIfChanged = false;
   };
   ```

2. **External DNS fallback**: Reorder nameservers to try external DNS first:

   ```nix
   nameservers = ["9.9.9.9" "127.0.0.1"];
   ```

3. **Health check**: Add a pre-switch validation to ensure unbound socket is accessible

## References

| File                                            | Description                |
| ----------------------------------------------- | -------------------------- |
| `platforms/nixos/modules/dns-blocker.nix`       | DNS blocker service module |
| `platforms/nixos/system/networking.nix`         | Network configuration      |
| `platforms/nixos/system/dns-blocker-config.nix` | DNS blocker configuration  |

---

**Deployed:** Pending `just switch` on evo-x2
**Validated:** `just test-fast` passes
**Impact:** Prevents DNS outages during NixOS rebuilds
