# SearXNG Runtime Verification — Self-Review & Status

**Date:** 2026-07-29 16:55
**Session scope:** Verify SearXNG deployment: (1) Gatus health, (2) browser search policy, (3) favicon cache, (4) engine errors
**Host:** evo-x2 (NixOS)
**Outcome:** 3 of 4 items verified clean. 1 item (engine errors) revealed a **DNS boot-race bug** — misdiagnosed in the original TODO as "wikidata 403 / Brave 429 (transient)". Bug fixed but **not yet deployed**.

---

## a) FULLY DONE

### 1. Gatus Health Check — VERIFIED GREEN

- Queried via `journalctl -u gatus.service` (Gatus API at `localhost:9110` returns 401 — OIDC-protected, no way to query without a browser session token)
- Every 60s: `endpoint=SearXNG; success=true; errors=0; duration=~4ms`
- Conditions checked: `[STATUS] == 200` + `[RESPONSE_TIME] < 1000`
- Discord alert configured: `"SearXNG metasearch engine down — privacy search unavailable"`
- **Verdict:** Gatus is correctly monitoring SearXNG. No gaps.

### 2. Browser Default Search-Engine Policy — VERIFIED LIVE

- `/etc/chromium/policies/managed/extra.json` (Nix store symlink) contains:
  - `DefaultSearchProviderEnabled: true`
  - `DefaultSearchProviderName: "SearXNG"`
  - `DefaultSearchProviderKeyword: "sx"`
  - `DefaultSearchProviderSearchURL: "https://search.home.lan/search?q={searchTerms}"`
  - `DefaultSearchProviderSuggestURL: "https://search.home.lan/autocompleter?q={searchTerms}"`
- Policy is active in the current generation (not stale)
- **Verdict:** Browser policy is correct and deployed. No gaps.

### 3. Favicon Cache — VERIFIED WORKING

- `/favicon_proxy?authority=nixos.org&h=...` returns binary image data (PNG favicon)
- Search results page HTML shows `<img loading="lazy" src="/favicon_proxy?authority=..."/>` for every result
- Cache configured at `/var/cache/searx/faviconcache.db` with `MAINTENANCE_MODE = "auto"`, `HOLD_TIME = 5184000` (60 days)
- **ResourceWarning: unclosed database** appears in logs (2 occurrences in 3h) — this is an **upstream SearXNG Python bug**, not a config issue. Documented in AGENTS.md.
- **Verdict:** Favicon cache is functional. The ResourceWarning is cosmetic/upstream.

### 4. Search Functionality — VERIFIED FUNCTIONAL

- Live search for "nixos linux" returns 25+ results from duckduckgo, google cse, startpage, wikipedia
- Autocomplete/suggest endpoint `/autocompleter?q=nixos` returns valid JSON suggestions
- Response time: 1.2 seconds (within the `max_request_timeout = 10.0` config)
- Pagination works (10 pages available)
- Image thumbnails proxied via `/image_proxy`

### 5. DNS Boot-Race Bug — FIXED (code, not deployed)

- **Root cause:** `searx.service` had `After=network.target` but NO dependency on `dnsblockd.service`. SearXNG engines that call network during `init()` (wikidata, radio browser, ClearURLs) fail with `[Errno -2] Name or service not known` and stay **permanently disabled** for the process lifetime — SearXNG never retries `init()`.
- **Fix applied:** `modules/nixos/services/searxng.nix`:
  - `searx.service`: `after = [ "dnsblockd.service" ]` + `wants = [ "dnsblockd.service" ]` + `ExecStartPre = searxng-wait-dns` (probes `getent hosts wikidata.org`, 60 retries × 2s, exits 0 on timeout)
  - `searx-init.service`: same `after`/`wants dnsblockd.service`
- **Verified:** `nix flake check --no-build` passes. Full system eval confirms correct wiring.
- **PENDING DEPLOY** — the fix is in the Nix config but NOT running on the system yet.

### 6. Documentation Updated

- `TODO_LIST.md`: item marked `[x]` with full verification details
- `AGENTS.md`: gotcha corrected from "wikidata 403 / Brave 429 (transient)" to accurate DNS-race diagnosis

---

## b) PARTIALLY DONE

### DNS Fix — Code Complete, NOT Deployed

The fix exists in the Nix configuration but has not been deployed via `nix run .#deploy`. Until deployed:
- The current running `searx.service` still has the OLD unit file (no DNS gate)
- Wikidata + radio browser engines remain disabled on this running instance
- A reboot or `systemctl restart searx` would re-trigger the race (though DNS is likely ready now since the system has been up for hours)

### Gatus API — Verified via Logs, NOT via Direct API Query

I could not query the Gatus API directly (`http://localhost:9110/api/v1/endpoints/status` returns 401 — OIDC Layer 1 SSO). I worked around this by reading `journalctl -u gatus.service` which shows every check result with `success=true/false`. This is sufficient evidence but not a direct API call.

---

## c) NOT STARTED

### Post-Deploy Verification

After deploying the DNS fix, the following should be verified:
1. `journalctl -u searx.service` should show NO "engine INIT failed" errors for wikidata/radio browser
2. `/stats` endpoint should show wikidata and radio browser as active engines (currently absent)
3. ClearURLs tracker patterns should load (currently failing with DNS error)
4. The `searxng-wait-dns` ExecStartPre should log "DNS resolution ready" at boot

### Post-Deploy-Check Enhancement

The post-deploy-check (`scripts/post-deploy-check.sh` line 137) only checks SearXNG `/healthz` returns 200. It does NOT verify:
- Search actually returns results
- Autocomplete endpoint works
- Engines are initialized (not DNS-failed)
- Favicon proxy serves data

Other services (Crush Daily, DiscordSync, SigNoz, Monitor365) all have **functional** post-deploy checks that verify real data, not just liveness. SearXNG has only a liveness check. This is a gap.

---

## d) TOTALLY FUCKED UP

Nothing destroyed, nothing broken. But:

### Misdiagnosis in Original TODO

The original TODO item said "wikidata 403 / Brave 429 engine errors (assumed transient, not tested)". The AGENTS.md gotcha also said "Wikidata API returns 403 (likely IP/WAF blocking on residential IPs)". **Both were wrong about wikidata.** Wikidata never reached the remote API — it failed DNS resolution at boot (`[Errno -2] Name or service not known`). The 403 was never observed. This misdiagnosis existed since SearXNG was deployed and was never caught because nobody looked at the actual boot logs.

**Lesson:** "assumed transient, not tested" is a red flag. The actual logs told a completely different story. Always read the boot-time logs, not just steady-state.

### Brave 429 — Correctly Diagnosed but Understated Impact

Brave returns "Too many request (suspended_time=180)" — SearXNG suspends it for **180 seconds** (3 minutes), not the `ban_time_on_fail = 5` from config (that's a different code path). The engine is effectively unusable for searches with any regularity. Brave's `/stats` entry shows 0 results and "Powered by" placeholder. This is a **persistent** issue, not truly transient — Brave rate-limits residential IPs aggressively. The fix is either removing Brave from the engine list or accepting it as permanently degraded.

---

## e) WHAT WE SHOULD IMPROVE

### SearXNG-Specific

1. **Add functional post-deploy check for SearXNG** — verify search returns results, not just `/healthz` is 200. Same pattern as Crush Daily's `session_count > 0` assertion. A search for a known term should return >0 results.

2. **Add engine-init-failure monitoring** — after deploy, check `journalctl -u searx.service` for "engine INIT failed" as part of post-deploy-check. Silent engine loss is the same class of bug as silent-zero-data.

3. **Consider removing Brave engine** — it persistently 429s from residential IPs. `search.brave.com` rate-limits aggressively. Either remove it or accept it's permanently non-functional. Currently it adds noise to every search (WARNING + ERROR logs) and shows "0 results" in stats.

4. **The `waitDnsReady` script exits 0 on timeout** — this means if DNS truly never comes up, SearXNG starts anyway with degraded engines. This is intentional (degradation > hard failure) but means the fix doesn't *guarantee* wikidata works — it makes it much more likely. An alternative would be to fail hard, but that would prevent SearXNG from starting at all if DNS is briefly slow.

5. **ClearURLs tracker patterns** — these also failed DNS init. The `waitDnsReady` gate should fix them too, but this wasn't explicitly tested. ClearURLs provides URL-stripping (removes tracking parameters from result URLs). Its absence is a privacy regression, not a functional one.

6. **Favicon ResourceWarning** — upstream SearXNG doesn't properly close the SQLite favicon cache connection in all code paths. Not actionable from SystemNix, but worth monitoring if it worsens.

7. **Autocomplete via Google** — `autocomplete = "google"` sends autocomplete queries to Google (through SearXNG, but Google sees the query terms). This is a minor privacy tradeoff. Consider `autocomplete = "duckduckgo"` or `"wikipedia"` for stricter privacy.

### General Patterns

8. **DNS-gate pattern should be systematic** — every service that makes outbound network calls at init should have the `after dnsblockd.service` + `ExecStartPre waitDnsReady` gate. Currently only discordsync and (now) SearXNG have it. Other candidates: any service that fetches remote data at startup.

9. **AGENTS.md gotchas should cite evidence** — the "wikidata 403" claim was stated as fact with no log evidence. Gotchas should include the actual error message from logs, not assumptions.

10. **"assumed transient" is never acceptable** — the original TODO explicitly said "assumed transient, not tested". This is a documentation smell. If it's not tested, it's not known.

---

## f) Up to 50 Things We Should Get Done Next

### Immediate (Deploy + Verify)

1. **Deploy the SearXNG DNS-gate fix** — `nix run .#deploy`
2. **Verify post-deploy: no engine INIT failures in searx logs**
3. **Verify post-deploy: wikidata appears in `/stats`**
4. **Verify post-deploy: radio browser appears in `/stats`**
5. **Verify post-deploy: ClearURLs tracker patterns loaded (no WARNING in logs)**
6. **Verify `searxng-wait-dns` ExecStartPre logged "DNS resolution ready"**
7. **Run `nix run .#post-deploy-check` after deploy**

### SearXNG Improvements

8. **Add functional search check to post-deploy-check** — POST to `/search?q=test`, verify HTML contains result articles
9. **Add engine-init-failure check to post-deploy-check** — grep searx journal for "engine INIT failed" after restart
10. **Remove or disable Brave engine** — persistently 429 from residential IP, adds log noise
11. **Consider removing radio browser engine** — low value (niche), adds init-time DNS dependency
12. **Switch autocomplete from "google" to "duckduckgo"** — privacy improvement
13. **Add Gatus check for search quality** — not just `/healthz`, but actual search endpoint returns results
14. **Monitor favicon cache DB size** — add to system-health metrics if it grows unexpectedly
15. **Test SearXNG behind Caddy from LAN** — verify `search.home.lan` resolves and forward-auth works
16. **Test SearXNG from external network** — verify oauth2-proxy forward-auth gate blocks unauthenticated access
17. **Verify SearXNG `method = "POST"` privacy** — queries should NOT appear in Caddy access logs
18. **Add SearXNG to post-deploy-check functional section** — alongside Crush Daily, DiscordSync, etc.

### DNS-Gate Pattern Systematization

19. **Audit ALL services for DNS boot-race vulnerability** — any service with outbound network at init
20. **Create a reusable `dnsGate` helper in `lib/default.nix`** — standardize the `after dnsblockd.service` + `ExecStartPre waitDnsReady` pattern
21. **Add DNS-gate to `searx-init` ExecStartPre** — currently only has ordering, not active probe (may not need it since searx-init just generates config)
22. **Document the DNS-gate pattern in AGENTS.md** — as a canonical procedure, not just per-service gotchas

### Monitoring Gaps (from this session's observations)

23. **Gatus API is OIDC-protected** — no way to query programmatically without a token. Consider adding a read-only API key or localhost bypass for monitoring scripts.
24. **Post-deploy-check doesn't verify Gatus endpoint health** — it checks individual services but not whether Gatus itself is reporting them correctly
25. **Monitor365 checks are ALL failing** (observed in Gatus logs: server, bootstrap, UI, agent-connected, backup-health, cloud-sync all `success=false`) — this is a separate issue but was visible during this session
26. **SigNoz alert rules not provisioned** (TODO item, still open) — monitoring gap

### Documentation

27. **Update AGENTS.md SearXNG section** with the DNS-gate pattern (once deployed and verified)
28. **Add ClearURLs tracker-pattern dependency to the gotcha** — it's not just wikidata/radio browser
29. **Document that `pkgs.getent` (not `pkgs.glibc.bin`) provides `getent`** — non-obvious nixpkgs output split
30. **Add the Brave 429 `suspended_time=180` detail** to the gotcha — it's 3 min, not 5s

### Broader SystemNix

31. **Deploy the DNS fix and all other pending changes** (monitor365 buffer purge, Helium extensions fix, etc.)
32. **Run full post-deploy-check after deploy** — catch all regressions
33. **Twenty CRM PG role fix** — still crash-looping
34. **SigNoz 19 alert rules** — still not provisioned
35. **Monitor365 buffer backlog** — 597M events blocked by daily limit (fix is in config, pending deploy)

---

## g) Questions I CANNOT Answer Myself

### Q1: Should I deploy now?

The DNS-gate fix is ready (`nix flake check` passes, full eval confirms correct wiring). There are also other pending changes in the working tree (homepage.nix, TODO_LIST.md, status docs). Deploying would apply ALL changes. Should I:
- (a) Deploy immediately with just the SearXNG fix?
- (b) Wait for you to review the changes first?
- (c) You'll deploy yourself?

I cannot answer this because deploying is a system-level action with blast radius beyond this task, and there may be other uncommitted changes I'm not aware of.

### Q2: Should Brave engine be removed entirely?

Brave persistently returns 429 from this residential IP with `suspended_time=180` (3-minute ban per failure). It shows 0 results in `/stats`. The config has `ban_time_on_fail = 5` but Brave's own rate-limiting overrides this. Options:
- (a) Remove Brave from engines (cleaner logs, no false "too many requests" noise)
- (b) Keep it (occasionally works, provides results when not rate-limited)
- (c) Increase `max_ban_time_on_fail` to reduce retry frequency

I cannot answer this because it's a UX preference: do you want occasionally-working Brave results with log noise, or cleaner logs without Brave?

### Q3: Is the Gatus OIDC protection intentional for localhost?

Gatus API at `localhost:9110` returns 401 for unauthenticated requests. This means no script or monitoring tool can query Gatus programmatically without going through the OIDC flow. The post-deploy-check reads Gatus results via journald instead. Options:
- (a) Keep OIDC on (security: even localhost requires auth)
- (b) Add localhost bypass (operational: scripts can query the API)
- (c) Add a read-only API key for monitoring

I cannot answer this because it's a security-vs-operability tradeoff that depends on your threat model for localhost access.
