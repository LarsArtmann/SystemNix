# home.lan vs .internal — Migration Analysis

> Status: DECISION — **Do not migrate now.** Cost far exceeds benefit.
> Date: 2026-06-09

---

## Context

- `home.lan` is currently the base domain for all internal services on SystemNix.
- ICANN officially reserved `.internal` for private-use applications on **July 29, 2024** (RFC-equivalent status).
- `.internal` will never be delegated in the global DNS root zone.

## What a Migration Would Require

| Step | Files / Systems Affected |
|------|-------------------------|
| Regenerate CA + server certs | New `dnsblockd` CA cert/key, re-issue all service certs, update `dnsblockd-certs.yaml` sops secrets |
| DNS records | Unbound `local-data` on evo-x2 (`dns-blocker-config.nix`) + rpi3-dns (`platforms/nixos/rpi3/default.nix`) |
| Caddy vhosts | `caddy.nix` uses `config.networking.domain` — one line (`networking.nix`), but all vhosts reload |
| OAuth stack | Pocket ID client registrations, oauth2-proxy config, Immich/Forgejo OIDC callbacks |
| Service configs | Gatus endpoints, Homepage links, Taskwarrior sync URL, Monitor365, Twenty CRM, Crush Daily, etc. |
| Client devices | Browser bookmarks/cookies, Taskwarrior clients, mobile apps, saved passwords, SSH `known_hosts` |
| CA trust | Re-import internal CA on every browser/OS that accesses services (`security.pki.certificates`) |
| Documentation | README, AGENTS.md, runbooks, status reports (~100+ references across `docs/`) |

## Why It's Not Worth It Yet

1. **`home.lan` works.** Zero operational issues have been caused by the `.lan` TLD.
2. **`.internal` is too new** (July 2024). Some IoT devices, older Android, and network gear may not resolve it correctly yet.
3. **Private-CA already in use.** No dependency on public ACME/Let's Encrypt for internal domains, so the "can't get certs for internal TLDs" problem does not apply.
4. **`.lan` collision risk is theoretical.** Mali's ccTLD does not wildcard-resolve, and there is no indication ICANN will delegate `.lan` in a way that breaks `home.lan`.

## When to Reconsider

- A future device or software **actually fails** to resolve `home.lan`
- Rebuilding the auth/DNS stack from scratch anyway (natural migration window)
- `.internal` has **2+ years** of mature resolver support in consumer devices

## Alternative: Register a Real Domain

If future-proofing is desired with minimal pain, register a real domain and use a **private subdomain**:

```
*.internal.yourdomain.com
```

This provides:
- Public DNS fallback
- No TLD delegation risk
- Works with any resolver
- Can still be resolved internally via Unbound `local-data` overrides

## Conclusion

**Stay on `home.lan`.** The migration surface is large (~15+ config files, sops secrets, client reconfiguration, CA re-trust), the benefit is speculative, and `.internal` ecosystem support is still immature. Revisit in 2027+ if operational friction emerges.
