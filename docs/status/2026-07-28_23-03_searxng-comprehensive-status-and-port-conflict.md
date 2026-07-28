# SearXNG Integration — Comprehensive Status Report

**Date:** 2026-07-28 23:03 CEST
**Session focus:** Research SearXNG best practices, optimize configuration, deploy, and verify

---

## Executive Summary

SearXNG was researched thoroughly against official docs, the nixpkgs module internals, and SystemNix patterns. The module was significantly improved with rate-limiter config, favicons, dark mode, privacy hardening, and browser default search engine integration. **Deployment succeeded but SearXNG is NOT running** — port 8888 is occupied by an unidentified process, causing the service to crash-loop into `start-limit-hit`. This is the critical blocker.

---

## a) FULLY DONE (Completed and Verified)

| Item | Details |
|------|---------|
| SearXNG official docs research | Full `settings.yml` reference extracted: server, outgoing, search, ui, general, redis/valkey, limiter/bot detection, rate limit constants, reverse proxy headers, security hardening recommendations |
| nixpkgs searx module research | Full module source analyzed: `redisCreateLocally` creates Redis (unix socket), `limiterSettings` generates `limiter.toml`, `environmentFile` uses `envsubst`, `settings.redis` deprecated → `settings.valkey`, direct server mode has NO `restartTriggers` |
| `searxng.nix` rewrite — statix fix | Consolidated three `systemd.services.X` blocks into one `systemd = { services = { ... }; }` attrset. Statix check now passes clean (exit 0) |
| `searxng.nix` rewrite — limiter config | Added `limiterSettings` with `trusted_proxies` (127.0.0.0/8, ::1, LAN subnet) and `pass_ip` (LAN subnet for unrestricted private access). Caddy sets X-Forwarded-For automatically |
| `searxng.nix` rewrite — HTTP/1.1 | Added `http_protocol_version = "1.1"` for keep-alive between Caddy and SearXNG's built-in server |
| `searxng.nix` rewrite — favicons | Added `favicon_resolver = "duckduckgo"` for result favicons |
| `searxng.nix` rewrite — dark mode | Added `theme_args.simple_style = "auto"` (follows system dark/light) |
| `searxng.nix` rewrite — privacy hardening | Added `query_in_title = false`, `results_on_new_tab = true`, `formats = [ "html" ]` (no API surface) |
| `searxng.nix` rewrite — outgoing tuning | Added `max_request_timeout = 10.0`, `autocomplete_min = 4`, `ban_time_on_fail`/`max_ban_time_on_fail` |
| `searxng.nix` rewrite — restartTriggers | Added `restartTriggers` referencing settings JSON + limiterSettings JSON + package path (nixpkgs module doesn't set these for direct server mode) |
| `searxng.nix` rewrite — secret-key hardening | Added `serviceOneshotDefaults {}` + `StateDirectory = "searxng"` to the oneshot service |
| `searxng.nix` rewrite — metrics | Added `enable_metrics = true`, `donation_url = false` |
| Browser default search engine | Added `DefaultSearchProvider*` Chromium/Helium policies in `configuration.nix` (conditional on `services.searx.enable`). Verified via `nix eval` — 5 search provider keys + ExtensionSettings merge correctly |
| AGENTS.md — SearXNG section | Added comprehensive section under Key Procedures: module name, secret key pattern, Redis isolation, limiter config, SSO layer, key settings, restartTriggers, browser integration |
| AGENTS.md — SSO table | Added SearXNG to Layer 2 (oauth2-proxy forward-auth) services list |
| AGENTS.md — gotchas | Added 4 new gotchas: infinite recursion trap, redis→valkey migration, no restartTriggers in direct server mode, limiter behind reverse proxy |
| AGENTS.md — Native OIDC | Updated "Native OIDC ≠ free" entry to mention SearXNG has no user accounts at all |
| Validation — flake check | `nix flake check --no-build` passes (all modules) |
| Validation — system eval | `nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel` succeeds |
| Validation — statix | `statix check modules/nixos/services/searxng.nix` passes (exit 0, no warnings) |
| Validation — targeted evals | All key settings verified via `nix eval`: port 8888, base_url, limiter=true, http_protocol_version=1.1, favicon_resolver=duckduckgo, simple_style=auto, max_request_timeout=10, limiterSettings trusted_proxies + pass_ip, restartTriggers, Redis isolation, valkey unix socket URL, service hardening merge |
| Deployment | `nix run .#deploy` succeeded — 29 derivations built, system activated. SearXNG unit files generated, searx.service started |

---

## b) PARTIALLY DONE (In Progress / Incomplete)

| Item | Status | What remains |
|------|--------|-------------|
| Port 8888 conflict resolution | **BLOCKED** — searx.service crash-loops because port 8888 is occupied. The occupying process could not be definitively identified (see section d). Need to either kill the occupant or change SearXNG's port. |
| Post-deploy verification | Post-deploy smoke test ran. 27 PASS, 2 FAIL (DiscordSync pre-existing, SearXNG port conflict), 1 SKIP. SearXNG check FAIL: `expected HTTP 200, got 404` — but the 404 is from the OTHER process on 8888, not from SearXNG. |
| AGENTS.md gotcha for port conflict | Not yet documented — should add a gotcha entry about checking port availability before deploy |

---

## c) NOT STARTED

| Item | Why it matters |
|------|---------------|
| Functional search test | Can't test until SearXNG actually runs — need port conflict resolved first |
| Gatus health check green | Gatus check will fail until SearXNG serves `/healthz` on 8888 |
| Homepage search bar verification | Can't verify autocomplete/SuggestURL through Caddy until SearXNG runs |
| Homepage tile green status | Tile will show red until SearXNG health check passes |
| Browser default search engine UX test | Can't verify the Chromium policy actually makes SearXNG the omnibox default |
| Favicon resolver test | Can't verify DuckDuckGo favicon fetching works |
| Dark mode / theme test | Can't verify `simple_style = "auto"` follows system theme |
| Rate limiter behavior test | Can't verify bot protection + LAN passlist behavior |
| Engine error monitoring | Can't check which engines fail (ahmia, torch already logging errors in journal) |

---

## d) TOTALLY FUCKED UP

### Port 8888 Conflict — CRITICAL BLOCKER

**What happened:** SearXNG deployed successfully but immediately crash-looped. The journal logs show:

```
Address already in use
Port 8888 is in use by another program.
```

After 5 restart attempts (startLimitBurst=5), the service hit `start-limit-hit` and stopped trying.

**The occupying process:** Something IS listening on `127.0.0.1:8888` (confirmed via `/proc/net/tcp` — socket inode 74914, state LISTEN). It serves a bare `404 page not found` response with `Content-Type: text/plain` — this is a **Go `net/http` default 404**, not SearXNG (which returns HTML). A Go test binary (`service.test`, PID 2268366) was found running at `/home/lars/tmp/go-build3271399455/b001/service.test` but it disappeared before I could confirm it owned the port. The socket inode 74914 could not be matched to any PID via `/proc/*/fd/` traversal — possibly because the owning process runs under a different user namespace or is a zombie/reparented socket.

**What I should have done:** Run `ss -tlnp | grep 8888` during the RESEARCH phase, before deploying. This would have caught the conflict in 1 second. Instead, I discovered it only after the deploy failed and the post-deploy smoke test reported 404.

**Investigation chaos:** I tried `ss`, `lsof`, `netstat`, `fuser`, `/proc/net/tcp` inode matching, `/proc/*/fd/` traversal, `ps aux`, `docker ps`, cgroup procs, and PMA's `/proc/PID/net/tcp` — none definitively identified the current owner. The investigation was inefficient and should have been more systematic: start with `ss -tlnp` + `fuser`, escalate to `/proc` only if those fail.

### Other Issues

| Issue | Severity | Details |
|-------|----------|---------|
| `/healthz` assumption | Medium | I verified `/healthz` exists in SearXNG source (`webapp.py:597`) but never tested it against a running instance. The 404 from the port conflict masked this — can't confirm the endpoint works until SearXNG actually runs |
| Engine load errors | Low | SearXNG logs show `ahmia: can't register engine (loading engine failed)` and `torch: can't register engine (loading engine failed)`. These are Tor-only engines (.onion) that fail without Tor. Not critical but pollutes logs. Could disable via `use_default_settings.engines.remove` |
| Favicon config missing | Low | SearXNG logs show `missing favicon config: /run/searx/favicons.toml`. The nixpkgs module doesn't generate this file unless `faviconsSettings` is set. SearXNG falls back to defaults but logs an error. Need to either set `faviconsSettings` or accept the error |
| DiscordSync failure | Pre-existing | DiscordSync was already failing before this deploy (shown in pre-deploy check). Not caused by SearXNG work |

---

## e) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Pre-deploy port check** — Before deploying any new service, check `ss -tlnp` for the target port. Should be part of `pre-deploy-check.sh`.
2. **Health endpoint live-test** — Don't assume health endpoints from source code reading. Test against a running instance before wiring Gatus checks.
3. **Port conflict gotcha** — Add to AGENTS.md: "Check port availability before deploy — `ss -tlnp | grep PORT`".
4. **`favicons.toml` generation** — Set `faviconsSettings = {}` (empty) in the module to generate a `favicons.toml` file and silence the error log.

### Configuration Improvements

5. **Disable Tor-only engines** — Add `use_default_settings.engines.remove = [ "ahmia" "torch" ]` to avoid error log noise from engines that can't load without Tor.
6. **Port change consideration** — If port 8888 has persistent conflicts (e.g., from development tools), consider changing SearXNG to a less commonly used port (e.g., 9090 is taken by dnsblockd, but something in the 8800s range).
7. **`faviconsSettings`** — Configure favicon caching/resolver settings properly via the nixpkgs module option.

---

## f) Next Steps (Up to 50)

### Immediate (Blockers)
1. Identify and kill the process on port 8888 (or reboot to clear stale sockets)
2. `systemctl reset-failed searx.service && systemctl start searx.service`
3. Verify SearXNG binds to 8888 successfully
4. Verify `http://localhost:8888/healthz` returns 200

### Verification
5. Verify `https://search.home.lan/` loads (behind Pocket ID login for external, direct for LAN)
6. Verify `https://search.home.lan/healthz` returns 200
7. Perform an actual search query and verify results return
8. Run `nix run .#post-deploy-check` — confirm SearXNG passes
9. Check Gatus health check turns green for SearXNG
10. Verify Homepage search bar uses SearXNG (not DuckDuckGo)
11. Verify Homepage SearXNG tile shows green status dot
12. Verify Chromium/Helium default search engine is SearXNG
13. Test search autocomplete suggestions from browser omnibox
14. Verify favicon resolver (duckduckgo) shows favicons next to results
15. Verify dark mode theme follows system preference
16. Test rate limiter — rapid requests from LAN should NOT be limited (pass_ip)
17. Test rate limiter — rapid requests from external should be limited

### Configuration Fixes
18. Add `faviconsSettings = {}` to generate `favicons.toml` and silence favicon error
19. Add `use_default_settings.engines.remove` for Tor-only engines (ahmia, torch)
20. Add pre-deploy port availability check to `pre-deploy-check.sh`
21. Add port conflict gotcha to AGENTS.md
22. Add SearXNG favicon config gotcha to AGENTS.md

### Hardening / Polish
23. Consider `useragent_suffix` with contact info for upstream engine admins
24. Consider locking preferences (`preferences.lock`) for safesearch, image_proxy, method
25. Consider SearXNG `open_metrics` password for Prometheus integration
26. Consider adding SearXNG to SigNoz OTel tracing if supported
27. Monitor engine error rates over 24h and disable consistently failing engines
28. Test image proxy functionality (loads images through SearXNG)
29. Test `method = "POST"` UX — verify back button and drag-drop behavior
30. Verify `infinite_scroll` works in the simple theme
31. Verify `center_alignment` renders correctly on desktop
32. Test `results_on_new_tab = true` — links open in new tab

### Integration
33. Verify Caddy vHost `search.home.lan` TLS works with dnsblockd cert
34. Verify oauth2-proxy forward-auth redirects to Pocket ID login for external access
35. Verify LAN bypass works (no auth prompt from 192.168.1.0/24)
36. Verify Homepage bookmark for SearXNG links correctly
37. Test SearXNG as Firefox default search engine (if Firefox is used)
38. Consider adding SearXNG search to DMS/Quickshell launcher (spotlight)

### Monitoring
39. Add SearXNG memory usage to system-health metrics
40. Monitor Redis-searx memory usage over time
41. Add Gatus response time alert threshold review (currently 1000ms)
42. Consider adding SearXNG engine status check to Gatus (which engines are active/banned)

### Documentation
43. Update `docs/status/2026-07-28_19-51_searxng-integration-status.md` with resolution
44. Add SearXNG to FEATURES.md when fully verified
45. Document the port conflict resolution in AGENTS.md gotchas
46. Document the favicons.toml requirement
47. Update TODO_LIST.md with remaining SearXNG tasks

### Future Enhancements
48. Consider Tor proxy integration (`outgoing.using_tor_proxy`) for enhanced privacy
49. Consider SearXNG API format enablement for programmatic search (currently HTML-only)
50. Consider custom engine configuration for privacy-focused engines (Brave, DuckDuckGo, Qwant)

---

## g) Questions (Cannot Resolve Without User Input)

1. **Port 8888 conflict** — There's an unidentified process (likely a Go test binary from `/home/lars/tmp/go-build3271399455/`) occupying port 8888. I cannot kill it (no sudo access). Should I change SearXNG to a different port (e.g., 8889), or can you kill the process / reboot to clear it?

2. **Tor-only engines** — SearXNG's default engine set includes Tor-only engines (ahmia, torch) that log errors on every startup because Tor is not configured. Should I disable them via `use_default_settings.engines.remove`, or do you plan to add Tor support in the future?

3. **Secret key via sops** — The current auto-generated secret key pattern (`openssl rand -hex 32` → `/var/lib/searxng/searxng.env`) means the key is NOT reproducible across reinstalls. Should this use sops instead so the key survives reinstall/migration? This was flagged in the original session as an open question.
