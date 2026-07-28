# SearXNG Integration — Status Report

**Date:** 2026-07-28 19:51
**Session:** Single-session SearXNG integration into SystemNix
**Status:** Code complete, NOT deployed

---

## Executive Summary

SearXNG (privacy-focused metasearch engine) was integrated into SystemNix following the standard service-add pattern (port → module → Caddy → DNS → Gatus → Homepage → enable → smoke test). All evaluation passes (`nix flake check --no-build`, full system eval). The service is **not yet deployed**.

---

## a) FULLY DONE

| # | Task | File(s) | Verified |
|---|------|---------|----------|
| 1 | Port `searxng = 8888` registered | `lib/ports.nix` | `nix eval` confirms port in config |
| 2 | Service module created | `modules/nixos/services/searxng.nix` | `nix flake check` passes, auto-discovered as `nixosModules.searxng` |
| 3 | Caddy vHost `search.home.lan` | `modules/nixos/services/caddy.nix` | `nix eval` confirms vHost in `virtualHosts` |
| 4 | DNS subdomain `search` | `platforms/common/dns-local.nix` | Added to `localSubdomains` list |
| 5 | Gatus health check | `modules/nixos/services/gatus-config.nix` | `/healthz` endpoint, 60s interval, Discord alert |
| 6 | Homepage service tile | `modules/nixos/services/homepage.nix` | Productivity section, `searxng.png` icon (VERIFIED exists in `enableLocalIcons` pack) |
| 7 | Homepage bookmark | `modules/nixos/services/homepage.nix` | Search section, "SX" abbreviation |
| 8 | Homepage search provider | `modules/nixos/services/homepage.nix` | Replaced DuckDuckGo with SearXNG custom provider (`/search?q=`, `/autocompleter?q=`) |
| 9 | Enabled on evo-x2 | `platforms/nixos/system/configuration.nix` | `services.searx.enable = true` |
| 10 | Post-deploy smoke test | `scripts/post-deploy-check.sh` | `check_local "SearXNG" "8888" "/healthz" "200"` |
| 11 | Secret key auto-generation | `modules/nixos/services/searxng.nix` | Oneshot service generates `openssl rand -hex 32`, persists to `/var/lib/searxng/searxng.env` |
| 12 | Dedicated Redis instance | nixpkgs `redisCreateLocally = true` | Unix socket at `/run/redis-searx/redis.sock`, isolated from Immich's Redis |
| 13 | `/healthz` endpoint verified | SearXNG source `webapp.py:597` | Confirmed: `@app.route('/healthz')` returns `Response('OK', mimetype='text/plain')` |
| 14 | Formatting | `nix fmt` (alejandra) | Applied |

### Configuration details

- **Auth:** Layer 2 SSO (`protectedVHost` → oauth2-proxy → Pocket ID). SearXNG has no native OIDC.
- **Binding:** `127.0.0.1:8888` (Caddy is sole public entry)
- **Hardening:** nixpkgs module's strict hardening (ProtectSystem=strict, DynamicUser, MemoryDenyWriteExecute) + SystemNix `harden { MemoryMax = 512M; }` (mkDefault — upstream values take precedence)
- **Rate limiter:** `server.limiter = true` with dedicated Redis (bot protection)
- **Search method:** POST (privacy — queries not in URL/logs)
- **Image proxy:** Enabled (images proxied through SearXNG)
- **Autocomplete:** Google suggestions backend

---

## b) PARTIALLY DONE

| # | Item | Status | Gap |
|---|------|--------|-----|
| 1 | statix lint clean | WARNING | `systemd.services` key repeated 3 times (secret-key, searx, searx-init blocks). statix suggests consolidating into one `systemd = { ... }` block. Cosmetic, not a correctness issue. |
| 2 | AGENTS.md documentation | NOT STARTED | No SearXNG section added to the gotcha table or service procedures. Every other service has detailed documentation. |
| 3 | Favicons settings | NOT CONFIGURED | SearXNG has a `faviconsSettings` option (favicon caching DB). Not configured — favicons will still work but without persistent caching. |
| 4 | Limiter settings | DEFAULTS | `limiterSettings` not explicitly set. Uses SearXNG defaults (botdetection with standard thresholds). Adequate for single-user homelab. |

---

## c) NOT STARTED

| # | Item | Why It Matters |
|---|------|----------------|
| 1 | **Deploy** (`nix run .#deploy`) | Nothing is live. All changes are evaluated but not activated. |
| 2 | Browser-policies integration | Could set SearXNG as the default search engine in Helium/Chromium via `browser-policies` |
| 3 | Engine customization | All ~70+ default search engines enabled. May want to disable some (e.g., ones that consistently fail or rate-limit) |
| 4 | Functional post-deploy verification | `post-deploy-check.sh` only checks `/healthz` returns 200. Doesn't verify search actually returns results. |
| 5 | SearXNG API integration | SearXNG has a JSON API (`/search?format=json`). Could be used by Crush, Hermes, or other AI tools as a search backend. |
| 6 | Sops secret for secret_key | Currently auto-generated on first boot and stored plaintext at `/var/lib/searxng/searxng.env`. Could use sops for consistency with other services, though this is a randomly-generated machine-local secret (not a shared credential). |

---

## d) TOTALLY FUCKED UP

**Nothing is fucked up.** No data loss, no broken services, no incorrect wiring.

However, one design decision deserves scrutiny:

- **`searxng-secret-key` runs as root without hardening.** The oneshot service creates `/var/lib/searxng/` and writes the env file as root. This works and is safe (the file is 0600, systemd reads it as PID 1), but it doesn't follow the SystemNix `harden {}` pattern. The nixpkgs searx module uses DynamicUser, so the searx user doesn't exist at secret-generation time — making hardening tricky. This is an acceptable tradeoff documented in the module comments.

---

## e) WHAT WE SHOULD IMPROVE

### Immediate (before deploy)

1. **Fix the statix warning** — consolidate the three `systemd.services.X` blocks into a single `systemd = { services = { ... }; }` attrset. Cleaner, matches statix guidance, and is the pattern other modules use when they touch multiple services.

2. **Update AGENTS.md** — add a SearXNG section covering:
   - Module name (`services.searx` from nixpkgs, not `services.searxng-config`)
   - Secret key auto-generation pattern
   - Redis isolation (unix socket, separate from Immich)
   - Layer 2 SSO (no native OIDC)
   - Homepage search provider integration

3. **Add a functional post-deploy check** — beyond `/healthz`, verify a search query returns results. Something like: `curl -s "http://localhost:8888/search?q=test&format=json" | grep -q '"results"'`. This catches the "healthy but broken search" failure mode.

### Short-term (after deploy)

4. **Configure `faviconsSettings`** — enable persistent favicon caching to reduce outgoing requests and speed up the UI.

5. **Verify rate limiter doesn't block legitimate searches** — the limiter + bot protection can be aggressive. Monitor Gatus for false-positive health check failures after deploy.

6. **Test the Homepage custom search provider** — verify `https://search.home.lan/search?q=` and `/autocompleter?q=` work correctly through the Caddy reverse proxy + oauth2-proxy forward-auth chain. The autocomplete endpoint may behave differently when behind forward-auth.

### Long-term

7. **SearXNG as AI search backend** — wire SearXNG's JSON API into Crush or Hermes as a web search tool. This is the highest-value integration: AI agents get private, untracked web search.

8. **Browser default search engine** — set `search.home.lan` as the default search engine in Helium via `browser-policies`.

---

## f) Up to 50 Things We Should Get Done Next

### Must-do before deploy
1. Fix statix warning (consolidate `systemd.services` blocks)
2. Update AGENTS.md with SearXNG section
3. Run `nix run .#deploy`
4. Verify `https://search.home.lan/` loads (behind Pocket ID login)
5. Verify `/healthz` returns 200 on localhost
6. Run `nix run .#post-deploy-check` and confirm SearXNG passes
7. Verify Gatus health check turns green for SearXNG

### Functional verification (post-deploy)
8. Perform a search query and verify results return
9. Verify autocomplete suggestions appear in the search bar
10. Verify image search works with image_proxy enabled
11. Verify the rate limiter doesn't block normal single-user usage
12. Check Redis socket connectivity (`redis-cli -s /run/redis-searx/redis.sock ping`)
13. Verify Homepage search bar uses SearXNG (not DuckDuckGo)
14. Verify Homepage SearXNG tile shows green status dot
15. Verify Homepage bookmark link works
16. Check `journalctl -u searx -n 50` for any errors/warnings
17. Check `journalctl -u searxng-secret-key` for successful key generation
18. Check `journalctl -u redis-searx` for Redis startup

### Hardening & polish
19. Add `faviconsSettings` for persistent favicon cache
20. Consider `limiterSettings` tuning for single-user homelab
21. Add functional post-deploy check (search query returns JSON results)
22. Consider adding SearXNG to the `system-health.nix` Prometheus textfile collector
23. Review if `MemoryMax = 512M` is sufficient under load (SearXNG is Python + uWSGI)
24. Add `restartTriggers` for the searx service (package + settings changes)
25. Consider whether `ProtectHome = true` (from nixpkgs) causes any issues

### Integration & features
26. Set SearXNG as default search engine in `browser-policies`
27. Wire SearXNG JSON API into Crush as an MCP tool or search backend
28. Wire SearXNG JSON API into Hermes for AI web search
29. Consider adding custom engines (e.g., NixOS package search, local Forgejo)
30. Explore SearXNG's `/metrics` endpoint (Prometheus-compatible, password-protected)
31. Add SearXNG metrics to SigNoz if `/metrics` is enabled
32. Consider enabling `open_metrics` for Prometheus scraping

### Engine tuning
33. Disable engines that consistently timeout or fail (check `/stats` page after deploy)
34. Tune `outgoing.request_timeout` if searches are slow
35. Consider enabling `outgoing.proxies` if search engines rate-limit the homelab IP
36. Evaluate `enable_http2` — some engines behave differently with HTTP/2
37. Set `default_lang` to a specific language if "auto" misbehaves

### Documentation & memory
38. Document the secret-key auto-generation pattern in AGENTS.md gotcha table
39. Document the Redis isolation pattern (unix socket, not TCP)
40. Document the Homepage search provider integration
41. Add SearXNG to the SSO architecture table (Layer 2, no native OIDC)
42. Note the `services.searx` (not `services.searxng`) naming convention

### Monitoring improvements
43. Add a Gatus check for actual search functionality (not just /healthz)
44. Add response-time threshold tuning after observing real performance
45. Consider a Gatus check for the Redis socket (TCP check on the socket path)
46. Add SearXNG to the deploy.sh pre-deploy-check if applicable

### Future features
47. Consider SearXNG's built-in Tor support for anonymous searches
48. Explore SearXNG's plugin system (e.g., self-hosted translation, currency conversion)
49. Consider running a second SearXNG instance for public access (different config)
50. Evaluate SearXNG vs. Whoogle for specific use cases

---

## g) Questions I Cannot Answer Myself

### 1. Should SearXNG replace DuckDuckGo as the browser default search engine?

I've already replaced it in the Homepage dashboard search widget, but the browser default (`browser-policies`) is a user preference. SearXNG behind Pocket ID SSO means every new tab search goes through auth — which could be friction for quick lookups if the oauth2-proxy session expires. Alternatively, LAN access bypasses auth (protectedVHost allows LAN IPs through without forward-auth), so it would be seamless on evo-x2 itself.

### 2. Should specific search engines be disabled?

SearXNG enables ~70+ engines by default. Some (Google, Bing) may rate-limit or block a homelab IP. Others may consistently timeout. I don't know which engines you value — the answer requires post-deploy observation of the `/stats` page to see which engines have high error rates.

### 3. Should the secret key use sops instead of auto-generation?

Currently the key is auto-generated on first boot via `openssl rand -hex 32` and stored at `/var/lib/searxng/searxng.env` (plaintext, root:root, 0600). This is consistent with how SearXNG's Docker image handles it. Alternatively, it could be stored in sops like other SystemNix secrets — but it's a machine-local random secret, not a shared credential, so sops adds complexity without clear benefit. Your call on which pattern to standardize on.
