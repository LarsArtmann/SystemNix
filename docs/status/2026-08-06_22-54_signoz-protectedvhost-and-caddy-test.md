# Status Report: SigNoz Auth Fix — protectedVHost + Caddy Auth VM Test

**Date:** 2026-08-06 22:54
**Session Start:** ~22:38
**Branch:** master
**Commits This Session:** none yet (all changes uncommitted)

---

## What Was Done

### Problem
SigNoz at `signoz.home.lan` was returning oauth2-proxy 500 errors. The original
config used **unconditional** Caddy `forward_auth` (no LAN bypass) — every
request, including LAN, went through oauth2-proxy. When oauth2-proxy hiccuped,
the entire service was inaccessible.

### Investigation Findings

1. **The no-auth change was already deployed.** The deployed Caddy config
   (`/run/current-system`) already had a plain `reverse_proxy localhost:8080`
   for SigNoz with NO forward_auth. The previous session's claim "NOT deployed"
   was wrong — the system generation name (`26.11.20260805.b7c2ada`) reflects
   the nixpkgs input date, not the build date.

2. **SigNoz was already working.** Gatus reported `endpoint=SigNoz; success=true;
   duration=1ms`. Fetch returned the SvelteKit SPA HTML. Query service was
   actively processing PromQL alert rules.

3. **oauth2-proxy was healthy.** `/ping` returning 200, OIDC discovery
   successful, no errors in logs. The original 500 was likely transient.

4. **Port 443 IS in `allowedTCPPorts`** (`networking.nix:34`) on ALL non-trusted
   interfaces. `eno1` (LAN) is a `trustedInterface` (bypasses firewall). Whether
   443 is reachable from the internet depends on router port-forwarding —
   unverifiable from NixOS config. The `home.lan` domain is LAN-only DNS.

5. **No 500 errors in SigNoz access log.** The original `a157faec-*` request ID
   was not found in any journal.

### Decision: protectedVHost (Layer 2)

Switched SigNoz from the ungated plain proxy to `protectedVHost`:
- **LAN access:** direct proxy, NO auth gate (fixes the 500 — oauth2-proxy
  never touched for LAN requests)
- **External access:** oauth2-proxy forward-auth (defense-in-depth for port 443)

This is strictly better than both:
- Old approach (unconditional forward-auth = 500 for ALL when oauth2-proxy fails)
- Previous fix (ungated plain proxy = potential security risk if 443 forwarded)

### Changes Made (uncommitted)

| File | Change |
|------|--------|
| `modules/nixos/services/caddy.nix` | SigNoz vHost: inline ungated → `protectedVHost "signoz"` |
| `modules/nixos/services/signoz.nix` | Header comment + impersonation script comment → Layer 2 |
| `AGENTS.md` | SSO table: SigNoz back in Layer 2 row; gotcha updated; callout rewritten |
| `tests/test-caddy-auth.nix` | NEW — VM test for Caddy auth patterns (plain + protectedVHost) |

### Test Added

**`tests/test-caddy-auth.nix`** — standalone VM test verifying:
1. Plain proxy gives direct access (Layer 1 pattern)
2. protectedVHost LAN bypass: `127.0.0.1` reaches backend directly (the KEY
   assertion — LAN traffic never touches oauth2-proxy)
3. Mock oauth2-proxy returns 401 on auth check (proving the auth gate works)
4. Caddyfile structure: `forward_auth` inside `handle @external`, NOT
   unconditional (guards against the old SigNoz bug)

**NOT yet registered** in `tests/default.nix` — needs registration + test run.

---

## What Remains

1. **Register test** in `tests/default.nix`
2. **Run the VM test** to verify it passes
3. **Run `nix flake check --no-build`** for eval validation
4. **Run `nix fmt`** for formatting
5. **Deploy** — `nix run .#deploy`
6. **Post-deploy verify** — confirm SigNoz loads from LAN, confirm Gatus still
   passes
7. **Update Gatus** — verify the SigNoz health check endpoint still works with
   protectedVHost (Gatus probes from localhost, which hits the LAN bypass)

---

## Risks & Notes

- **Gatus health check:** Gatus probes from `127.0.0.1`, which matches the LAN
  bypass in `protectedVHost`. The health check should continue to work
  unchanged. Verify post-deploy.
- **Websocket support:** SigNoz uses SSE for live log tailing, not websockets.
  Caddy's `reverse_proxy` handles SSE by default. No `flush_interval` change
  needed.
- **Other Layer 2 services NOT broken:** oauth2-proxy is healthy, so all Layer 2
  services (Homepage, Twenty, Dozzle, SearXNG, etc.) are working normally.
- **Previous no-auth commit (`edc653d4`):** This change SUPERSEDES that commit.
  The no-auth approach was too permissive; `protectedVHost` is the correct fix.
