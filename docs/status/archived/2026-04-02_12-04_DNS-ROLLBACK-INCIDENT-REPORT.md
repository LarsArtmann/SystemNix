# DNS Rollback Incident Report - 2026-04-02

**Date:** 2026-04-02 12:04 CEST
**Severity:** P1 - Full DNS outage requiring system rollback
**Status:** Rollback applied (gen 178 -> gen 172), dnsblockd still crash-looping
**Root Cause:** sops-nix secret migration left `/run/secrets/` empty; cascading service failures

---

## Incident Timeline

| Time                | Event                                                                               |
| ------------------- | ----------------------------------------------------------------------------------- |
| Mar 31 18:43        | Generation 172 built and applied (WORKING)                                          |
| Mar 31 20:39        | Generation 173 built - nixpkgs bumped from `20260328.b63fe7f` to `20260330.15c6719` |
| Apr 1 00:09 - 03:16 | Generations 174-177 built - sops-nix cert migration commits                         |
| Apr 2 08:46         | Generation 178 built and applied (BROKE DNS)                                        |
| Apr 2 09:42         | Rolled back to generation 172 (DNS partially restored)                              |
| Apr 2 11:32         | Dynamic IP detection fix committed (gen 548b872)                                    |

---

## Root Cause Analysis

### The Trigger: sops-nix Cert Migration

Between gen 172 and gen 178, the following commits migrated dnsblockd certificates from Nix store paths to sops-nix managed secrets:

```
5deab04 feat(certs): add dnsblockd CA and server certs as plain files
7a4d32f feat(sops): declare dnsblockd cert secrets with proper ownership
0d82e8a refactor(dns-blocker): use sops-managed CA cert/key instead of nix store
7e4518d refactor(caddy): use sops-managed server cert/key for TLS
3e2d27d refactor(overlay): remove dnsblockd-cert from flake overlay
```

### What Changed

| Component         | Gen 172 (Working)                     | Gen 178 (Broken)                     |
| ----------------- | ------------------------------------- | ------------------------------------ |
| dnsblockd CA cert | `/nix/store/.../dnsblockd-ca.crt`     | `/run/secrets/dnsblockd_ca_cert`     |
| dnsblockd CA key  | `/nix/store/.../dnsblockd-ca.key`     | `/run/secrets/dnsblockd_ca_key`      |
| Caddy server cert | `/nix/store/.../dnsblockd-server.crt` | `/run/secrets/dnsblockd_server_cert` |
| Caddy server key  | `/nix/store/.../dnsblockd-server.key` | `/run/secrets/dnsblockd_server_key`  |
| dnsblockd blockIP | `192.168.1.163` (hardcoded)           | `192.168.1.150` (hardcoded, WRONG)   |

### Why It Broke

1. **`/run/secrets/` is EMPTY** - sops-nix never successfully decrypted the secrets. The secrets.yaml and dnsblockd-certs.yaml exist in the repo, but the sops age key mechanism failed to decrypt them at boot time.
2. **dnsblockd fails to start** - cannot read CA cert/key from `/run/secrets/`
3. **Caddy MAY have failed too** - same cert path issue (but Caddy is currently running on gen 172 with nix store certs)
4. **IP address mismatch** - blockIP configured as `192.168.1.150` but actual system IP is `192.168.1.161` (DHCP-assigned despite `useDHCP = false`)

### Why the Rollback "Fixed" It

Rolling back to gen 172 restored the **Nix store cert paths** which are always available (baked into the derivation). dnsblockd and Caddy could find their certs again. However, the IP mismatch issue persists.

---

## Current System State

### Running: Generation 172 (26.05.20260328.b63fe7f)

```
IP Addresses:  192.168.1.161 (eno1 DHCP), 172.17.0.1 (docker), 10.88.0.1 (podman), 169.254.202.106 (link-local)
Config says:   192.168.1.150 (static) - NOT APPLIED
Unbound:       RUNNING - DNS resolution works for external domains
Caddy:         RUNNING - listening on *:80 and *:443
dnsblockd:     CRASH-LOOPING - "listen tcp 192.168.1.163:80: bind: address already in use" (port conflict with Caddy)
SOPS secrets:  /run/secrets exists but is EMPTY
dhcpcd:        Enabled in systemd (despite networking.dhcpcd.enable = false)
```

### Active Services & Ports

| Port  | Service         | Status       | Notes                                      |
| ----- | --------------- | ------------ | ------------------------------------------ |
| :53   | Unbound         | Running      | DNS resolution works                       |
| :80   | Caddy           | Running      | Binds to `*:80` - conflicts with dnsblockd |
| :443  | Caddy           | Running      | HTTPS reverse proxy for .lan domains       |
| :22   | SSH             | Running      |                                            |
| :3000 | Gitea           | Running      |                                            |
| :2283 | Immich          | Running      |                                            |
| :3001 | Grafana         | Running      |                                            |
| :8082 | Homepage        | Running      |                                            |
| :8050 | Photomap        | Running      |                                            |
| :9090 | dnsblockd stats | Intermittent | Crashes every ~4 seconds                   |

### dnsblockd Crash Loop (restart counter at 1908+)

```
dnsblockd 0.1.0 listening on 192.168.1.163:80 (HTTP block page)
dnsblockd listening on 192.168.1.163:8443 (HTTPS block page, dynamic certs)
server error: listen tcp 192.168.1.163:80: bind: address already in use
```

**dnsblockd has been crash-looping since the system booted.** It works on gen 172 because certs exist, but port 80 is taken by Caddy.

---

## Known Issues Found During Investigation

### 1. Static IP Not Applied (CRITICAL)

`networking.nix` sets `useDHCP = false` and static IP `192.168.1.150`, but:

- System gets IP `192.168.1.161` via DHCP
- `dhcpcd.service` is enabled in `multi-user.target.wants`
- `dhcpcd` lease file exists at `/var/lib/dhcpcd/eno1.lease`
- `hardware-configuration.nix` has `networking.useDHCP = lib.mkDefault true` which may conflict

### 2. Port 80 Conflict: Caddy vs dnsblockd (CRITICAL)

- Caddy binds to `*:80` (all interfaces) for HTTP->HTTPS redirect
- dnsblockd also needs port 80 on the LAN IP for block pages
- These cannot coexist on the same port

### 3. SOPS Secrets Not Decrypted (CRITICAL)

- `/run/secrets/` exists but is empty
- sops-nix module IS configured (`modules/nixos/services/sops.nix`)
- `sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]`
- SSH host key exists at `/etc/ssh/ssh_host_ed25519_key`
- But secrets are not being decrypted at boot

### 4. DNS Local Domains Point to Wrong IP (MEDIUM)

Unbound `local-data` in dns-blocker-config.nix hardcodes `192.168.1.150`:

```
immich.lan -> 192.168.1.150 (actual IP is .161)
gitea.lan -> 192.168.1.150 (actual IP is .161)
grafana.lan -> 192.168.1.150 (actual IP is .161)
home.lan -> 192.168.1.150 (actual IP is .161)
photomap.lan -> 192.168.1.150 (actual IP is .161)
```

### 5. /etc/nixos Stale Config (LOW)

`/etc/nixos/configuration.nix` contains the stock NixOS template from initial installation (Dec 2025), not the flake config. This is cosmetic but confusing.

---

## Work Status

### a) FULLY DONE

1. **Root cause identification** - Traced DNS breakage to sops-nix cert migration leaving `/run/secrets/` empty
2. **Generation diff analysis** - Compared gen 172 vs 178 configs (unbound, dnsblockd, Caddy)
3. **Port conflict discovery** - Found Caddy and dnsblockd both trying to bind port 80
4. **Dynamic IP detection** - Added `detectIPScript` to dns-blocker.nix for runtime IP detection
5. **Build verification** - New config builds successfully with `nix flake check --no-build` and `nix build`
6. **Commit created** - Changes committed as `548b872`

### b) PARTIALLY DONE

1. **DNS fix** - Dynamic IP detection committed but NOT deployed (still on gen 172)
2. **dnsblockd service** - Still crash-looping on current system (port 80 conflict unresolved)
3. **SOPS secrets** - Migration code exists but secrets not decrypting (cause unknown)

### c) NOT STARTED

1. **SOPS secret decryption debugging** - Why `/run/secrets/` is empty despite correct config
2. **Static IP enforcement** - Fixing `useDHCP = false` to actually work
3. **Port 80 conflict resolution** - Caddy vs dnsblockd port sharing strategy
4. **DNS local-data dynamic IP** - .lan domains should use detected IP, not hardcoded
5. **Generation 178+ rebuild** - Applying fixes forward instead of staying on gen 172
6. **dhcpcd service removal** - Disable rogue dhcpcd despite `dhcpcd.enable = false`
7. **Stale /etc/nixos cleanup** - Remove or symlink initial install config

### d) TOTALLY FUCKED UP

1. **The sops-nix migration was deployed WITHOUT verifying secrets actually decrypt** - The commits `5deab04..3e2d27d` changed cert paths from `/nix/store/` (always available) to `/run/secrets/` (requires sops-nix to decrypt), but nobody verified the secrets were actually present before deploying. This is a textbook "test before deploy" failure.

2. **The static IP configuration is a lie** - `networking.useDHCP = false` is set, but dhcpcd runs anyway and assigns a DHCP address. The system has NEVER been at `192.168.1.150`. The entire dnsblockd config points to the wrong IP.

3. **dnsblockd has been crash-looping for potentially DAYS** - The restart counter is at 1908+ (at 3s intervals = ~1.5 hours of continuous crashing just this session, but likely much longer).

### e) WHAT WE SHOULD IMPROVE

1. **Add smoke tests for service dependencies** - Before `nixos-rebuild switch`, verify that all referenced paths (especially `/run/secrets/*`) will exist
2. **Add health checks** - dnsblockd should have a systemd `WatchdogSec` to detect and alert on crash loops
3. **Add sops-nix verification step** - After sops configuration changes, verify `sops --decrypt` works before building
4. **Never migrate from static paths to dynamic paths without a migration plan** - The cert path migration should have been: add sops paths -> verify secrets decrypt -> then remove old paths
5. **Use `systemd-analyze verify`** before deploying service changes
6. **Add monitoring/alerting** for persistent service failures (dnsblockd crash loop went unnoticed)

---

## f) Top 25 Things to Do Next

### Priority 1 - Fix DNS (Now)

1. **Fix sops-nix secret decryption** - Debug why `/run/secrets/` is empty, verify age key path and sops file encryption
2. **Resolve Caddy vs dnsblockd port 80 conflict** - dnsblockd should use a different port (e.g., 8080) and Caddy should reverse-proxy blocked domains to it
3. **Deploy the dynamic IP detection fix** - `nixos-rebuild switch` with the committed changes
4. **Fix static IP or embrace DHCP** - Either make `useDHCP = false` actually work, or switch to DHCP and make everything dynamic
5. **Fix .lan domain IP resolution** - Use detected IP for unbound local-data instead of hardcoded `192.168.1.150`

### Priority 2 - Stabilize

6. **Add systemd watchdog to dnsblockd** - Detect and alert on crash loops instead of silently restarting
7. **Add pre-deploy verification script** - Check all service dependencies before `nixos-rebuild switch`
8. **Add sops secret validation to CI/flake check** - Verify secrets decrypt during `nix flake check`
9. **Remove or document stale /etc/nixos/** - Clean up initial install config
10. **Add network interface assertion** - Fail build if configured interface doesn't exist or IP doesn't match

### Priority 3 - Harden

11. **Add monitoring for dnsblockd** - Alert on crash loops or DNS resolution failures
12. **Add integration test for DNS stack** - Test unbound + dnsblockd + Caddy together
13. **Add rollback automation** - Auto-rollback if critical services fail after deploy
14. **Document the sops-nix setup** - How to encrypt, what keys are used, how to rotate
15. **Add `.lan` domain health check** - Periodic curl to immich.lan, gitea.lan, etc.

### Priority 4 - Improve

16. **Consider moving dnsblockd to high port** - Eliminate port 80 conflict entirely
17. **Add Caddy integration for block pages** - Serve block pages through Caddy instead of separate service
18. **Make all IPs dynamic** - Remove all hardcoded IPs, detect everything at runtime
19. **Add networkd configuration** - Replace scripted networking with systemd-networkd for reliability
20. **Add DHCP reservation documentation** - If using DHCP, document router config for stable IP

### Priority 5 - Nice to Have

21. **Clean up generation proliferation** - 97 generations, many from rapid iteration
22. **Add nix garbage collection for old generations** - `nix.gc` is configured but manual cleanup needed
23. **Audit all sops secret references** - Ensure no other services reference missing secrets
24. **Add generation diff tool** - Quick way to see what changed between NixOS generations
25. **Document incident response process** - How to quickly diagnose and rollback DNS issues

---

## g) Top #1 Question I Cannot Answer

**Why are sops-nix secrets not being decrypted at boot?**

The configuration appears correct:

- `sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]` - key exists
- `sops.defaultSopsFile` points to valid `secrets.yaml`
- `dnsblockd-certs.yaml` exists with encrypted secrets
- `sops-nix.nixosModules.sops` is imported in the flake

But `/run/secrets.d/25/` is completely empty. This could be:

- The SSH host key doesn't match the age identity used to encrypt the secrets
- The sops files were encrypted with a different key
- sops-nix service ordering issue (secrets decrypted after services start)
- A silent failure in sops-nix decryption that doesn't show in logs

**This needs to be investigated on the machine with access to `sops --decrypt` and the age/SSH keys.** Without verifying the encryption key matches the decryption key, the sops-nix integration will never work.

---

## Files Modified This Session

| File                                      | Change                                          | Status              |
| ----------------------------------------- | ----------------------------------------------- | ------------------- |
| `platforms/nixos/modules/dns-blocker.nix` | Added `detectIPScript` for runtime IP detection | Committed (548b872) |

---

## Environment

- **Machine:** evo-x2 (GMKtec AMD Ryzen AI Max+ 395)
- **NixOS:** 26.05.20260328.b63fe7f (Yarara) - gen 172
- **Kernel:** 6.19.10
- **Git HEAD:** 548b872
- **Flake check:** PASSING
