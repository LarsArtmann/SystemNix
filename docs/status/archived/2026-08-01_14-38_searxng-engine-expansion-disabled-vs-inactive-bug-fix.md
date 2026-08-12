# SearXNG Engine Expansion & Privacy/Performance Session

**Date:** 2026-08-01 14:38 CEST
**Session:** SearXNG engine additions, privacy/performance tuning, `disabled` vs `inactive` bug discovery and fix
**File modified:** `modules/nixos/services/searxng.nix`
**Deployed:** NO — all changes are in the working tree, `nix flake check --no-build` passes

---


## What This Session Did

The user asked to expand SearXNG with more search engines (Yandex, Baidu, Quark, video engines, developer-reference engines) and improve privacy/performance. The session uncovered a critical SearXNG configuration bug affecting **53 of 71 engines**.

---

## A) FULLY DONE

### 1. Engine expansion — 71 engines explicitly enabled (WAS: ~8)

Added explicit `disabled = false; inactive = false;` declarations for:

| Category | Count | Engines |
|---|---|---|
| General search | 7 | google, google images, bing, yandex, yandex images, baidu images, quark images |
| Package registries | 15 | alpine, cachy, crates.io, docker hub, hex, hoogle, lib.rs, metacpan, pnpm, packagist, pkg.go.dev, pub.dev, pypi, rubygems, voidlinux |
| Q&A forums | 6 | askubuntu, caddy.community, discuss.python, pi-hole.community, stackoverflow, superuser |
| Code repos | 10 | bitbucket, codeberg, gitea.com, github, gitlab, huggingface (3), ollama, sourcehut |
| Video search | 33 | google videos, bing videos, brave.videos, qwant videos, ddg videos, youtube, dailymotion, vimeo, rumble, peertube, sepiasearch, odysee, bilibili, media.ccc.de, wikicommons.videos, pixabay, bitchute, google play movies, mediathekviewweb, naver, acfun, iqiyi, sogou, 360search, adobe stock, dogpile, findfiles, fireball, niconico, privacywall, tusksearch, vuhuv, ina |

### 2. Redis cache bounded

```nix
services.redis.servers.searx.settings = {
  maxmemory = "128mb";
  maxmemory-policy = "allkeys-lru";
};
```

Prevents unbounded Redis memory growth. Redis is pure cache for SearXNG (rate limiter / bot protection state) — data loss is harmless.

### 3. Outgoing timeouts increased

```nix
request_timeout = 8.0;   # was 3.0
max_request_timeout = 20.0;  # was 10.0
```

Image/video engines (Google Images, Yandex Images, Baidu, Quark) are slower than text. The old `3.0s` timeout dropped them from results before they could respond.

### 4. Autocomplete changed to Yandex

```nix
autocomplete = "yandex";  # was "duckduckgo"
```

### 5. Helium default search engine confirmed

Already configured at `configuration.nix:146-154` via `programs.chromium.extraOpts`. Helium is Chromium-based so enterprise policy applies. No changes needed.

---

## B) PARTIALLY DONE

### 1. SearXNG `disabled` vs `inactive` bug — FIXED, but not deployed

**Root cause:** SearXNG has two independent engine off-switches:
- `disabled: true` — engine module never loads at all
- `inactive: true` — engine loads but is excluded from default category searches

The original config used `inactive = false` to "enable" engines. This does NOT override `disabled: true` in the default settings. **53 of 71 engines we thought we enabled were silently still off.** Only engines that defaulted to `inactive: true` (Google, YouTube) actually worked.

**Fix:** Every engine now has both `disabled = false; inactive = false;`

**Status:** Fixed in working tree, `nix flake check --no-build` passes. NOT deployed — needs `nix run .#deploy`.

### 2. Tor proxy — added then reverted (user said "too slow")

Tor SOCKS5 proxy was added (`services.tor.enable = true`, `outgoing.proxies`, `using_tor_proxy = true`), then fully reverted when user said Tor latency is unacceptable. No traces remain. The VPS proxy alternative was discussed but not implemented (user hasn't decided).

### 3. Engine verification — eval only, no runtime test

All changes verified via `nix eval --json` (71 engines, both `disabled` and `inactive` are `false`). But NO runtime verification — we don't know which engines actually return results vs hit CAPTCHAs/rate limits.

---

## C) NOT STARTED

1. **Deploy** — `nix run .#deploy` has not been run
2. **AGENTS.md update** — the `disabled` vs `inactive` gotcha is NOT documented yet
3. **Post-deploy smoke test** — no functional test of search results per engine
4. **Gatus check enhancement** — current SearXNG Gatus check only hits `/healthz`, doesn't verify engines are actually returning results
5. **Favicon resolver consistency** — `autocomplete = "yandex"` but `favicon_resolver = "duckduckgo"` (cosmetic inconsistency)
6. **VPS proxy** — discussed but user hasn't committed
7. **Engine weight tuning** — all engines have default weight 1.0; no tuning for quality vs speed

---

## D) TOTALLY FUCKED UP

### 1. The `inactive = false` bug — THE BIG ONE

**Severity: CRITICAL — 53 engines silently disabled**

I wrote `inactive = false` on every engine without understanding SearXNG's dual off-switch system. The result: we "added" 60+ engines over multiple turns, and almost NONE of them were actually enabled. Only Google and YouTube worked (because they default to `inactive: true`, not `disabled: true`).

**Why this happened:**
- I copied the pattern from the existing Google config (`inactive = false`), which worked for Google only because Google's default is `inactive: true`
- I never checked SearXNG's default `settings.yml` to see what the actual default state of each engine was
- When the user said "Why can't I add yandex?", I initially blamed Yandex's CAPTCHA blocking — a plausible but WRONG diagnosis. The real reason was that the engine was simply never loaded.
- It took the user asking AGAIN and mentioning the video UI was broken before I actually read the SearXNG source `settings.yml` and discovered the `disabled: true` default

**Lesson:** When configuring a new tool's options, ALWAYS read the tool's default config file first. Do NOT assume attribute semantics from one item apply to all items.

### 2. Duplicate `google videos` entry

Added `google videos` in both the general section AND the video section. Caught via eval output showing a duplicate. Fixed by removing it from the general section.

### 3. Premature Tor implementation

User said "enable all for it" (referring to the 5 privacy/perf recommendations). I immediately implemented Tor proxy + `services.tor` + systemd dependencies — a large, invasive change — without confirming the user actually wanted Tor's latency tradeoff. User rejected it next turn. Should have flagged Tor as the one item with a major tradeoff and confirmed separately.

### 4. Misdiagnosed the video UI issue

When user said "Video Search results UI so bad", I blamed the number of engines (sparse results) and `image_proxy`. While the engine count was A factor, the REAL root cause was the same `disabled` bug — ALL video engines except `google videos` were still off. The UI isn't a grid either (it's `float: left` rows), which I only discovered after reading the template CSS.

---

## E) WHAT WE SHOULD IMPROVE

### Code quality

1. **DRY the engine list** — 71 lines of `{ name = "X"; disabled = false; inactive = false; }` is repetitive. A helper function `enableEngine = name: { inherit name; disabled = false; inactive = false; };` would cut it to `map enableEngine [ "google" "bing" ... ]`
2. **The module comment at line 1-6** says "aggregating results from Google, Bing, DuckDuckGo, Brave" — needs updating to reflect 71 engines across 5 categories
3. **The `favicon_resolver`** is still `"duckduckgo"` while autocomplete is `"yandex"` — pick one provider for consistency, or document why they differ
4. **Engine validation** — SearXNG silently ignores engine names that don't exist in its module tree. A typo like `{ name = "yandes"; }` would be invisible. No eval-time check exists.

### Privacy

5. **Outgoing proxy (VPS)** — the user expressed interest. A cheap VPS with SOCKS5/Dante would hide evo-x2's IP from all engines without Tor's latency. Not implemented.
6. **`default_lang = "auto"`** — this lets SearXNG pick based on browser headers, which may leak the user's locale. Consider pinning to `"en"` or `"all"`.
7. **Engine query leakage** — each enabled engine receives every search query. 71 engines = 71 upstream services seeing every search. Consider whether all are needed or if some should be `!bang`-only (inactive but not disabled).

### Performance

8. **71 engines per query is a LOT** — each search fans out to 71 upstream HTTP requests (or more, if paginated). With `request_timeout = 8.0s`, a single search can hold 71 concurrent connections for up to 8 seconds. Consider raising `MemoryMax` above 512M or reducing the active engine count.
9. **Redis `maxmemory = 128mb`** may be too small for 71 engines' bot-protection state. Monitor eviction rate (`redis-cli -s /run/redis-searx/redis.sock info stats | grep evicted_keys`).
10. **No connection pooling config** — SearXNG's `outgoing` section supports `pool_connections` and `pool_maxsize`. Not set (uses defaults).

### Monitoring

11. **Gatus only checks `/healthz`** — doesn't verify any engines are actually returning results. A functional check (search for a known term, assert >0 results) would catch the `disabled` bug class.
12. **No per-engine health visibility** — SearXNG exposes `/stats` and `/config` endpoints with engine reliability metrics. Not monitored.
13. **Post-deploy-check** has no SearXNG-specific functional assertion (unlike crush-daily which asserts `session_count > 0`).

### Documentation

14. **AGENTS.md** needs the `disabled` vs `inactive` gotcha documented — this is a non-obvious trap that will recur
15. **AGENTS.md** SearXNG section doesn't mention the 71-engine configuration or the categories
16. **The existing `2026-08-01_03-40_searxng-improvement-session-comprehensive-status.md`** is now stale (pre-dates this session's fixes)

---

## F) NEXT TASKS (up to 50)

### Immediate (before deploy)

1. **Deploy the changes** — `nix run .#deploy`
2. **Run post-deploy smoke test** — `nix run .#post-deploy-check`
3. **Verify Yandex actually returns results** at runtime (may hit CAPTCHAs)
4. **Verify video search shows thumbnails** (not just text links)
5. **Verify Baidu/Quark image search works** (CJK engines, different blocking patterns)
6. **Check Redis memory usage** after deploy — `redis-cli -s /run/redis-searx/redis.sock info memory`
7. **Check SearXNG MemoryMax** — 71 engines may push past 512M under load
8. **Monitor SearXNG logs** for CAPTCHA errors — `journalctl -u searx -f`

### Short-term (this session or next)

9. **Update AGENTS.md** with the `disabled` vs `inactive` gotcha
10. **Update AGENTS.md** SearXNG section to reflect 71 engines, Redis cache config, timeout changes
11. **DRY the engine list** — extract a helper function
12. **Add a functional Gatus check** — search for a test term, assert results returned
13. **Add SearXNG to post-deploy-check** — functional search assertion
14. **Archive the stale status report** `2026-08-01_03-40_searxng-improvement-session-comprehensive-status.md`
15. **Pin `favicon_resolver`** — either change to `"yandex"` or document the mix
16. **Check if `autocomplete = "yandex"` actually works** — Yandex autocomplete API may be blocked like its search

### Engine tuning

17. **Review which engines actually return results** vs error/ban — trim dead weight
18. **Set `weight` on high-quality engines** — Google/Bing/DuckDuckGo should score higher
19. **Consider making some engines `!bang`-only** (inactive=true) to reduce fan-out on every search
20. **Test CJK engine coverage** — Baidu, Quark, Sogou, 360search, AcFun, iQiyi, Niconico
21. **Test video thumbnail rendering** — verify `image_proxy` proxifies thumbnails correctly
22. **Review `ban_time_on_fail = 5`** — too short for 71 engines; a single rate-limit ban cycles fast
23. **Check `max_ban_time_on_fail = 120`** — may need increasing for Yandex/Google rate limiting

### Privacy improvements

24. **VPS proxy implementation** — if user decides to proceed
25. **Evaluate `default_lang`** — pin to `"en"` or keep `"auto"`?
26. **Review `safe_search = 0`** — off by default; consider per-user preferences instead
27. **Consider `user_agent` customization** in outgoing settings
28. **Review whether `image_proxy = true`** fully anonymizes image fetches (no Referer leak?)

### Performance

29. **Monitor search latency** with 71 engines — measure P50/P99
30. **Set `pool_connections` and `pool_maxsize`** in outgoing config
31. **Consider raising MemoryMax** from 512M if engines push memory
32. **Profile Redis eviction rate** — adjust maxmemory if thrashing
33. **Consider `threads` setting** — SearXNG can use thread pool for engine requests
34. **Review `enable_http2 = true`** — some engines/proxies don't support HTTP/2

### Monitoring & observability

35. **Add Gatus check for search functionality** — not just `/healthz`
36. **Monitor per-engine reliability** via SearXNG `/stats` endpoint
37. **Add Gatus response time check** — `[RESPONSE_TIME] < 3000` (3s for 71 engines)
38. **Add Prometheus metrics** for SearXNG if available (searxng_exporter?)
39. **Alert on engine ban storms** — if >10 engines are banned simultaneously, something's wrong
40. **Log analysis** — set up structured logging for engine errors

### UI/UX

41. **Research custom CSS for video grid layout** — SearXNG Simple theme uses float, not grid
42. **Consider alternative SearXNG theme** that supports video grid (e.g., `beetroot`)
43. **Test infinite scroll** with 71 engines — may be slow to fill
44. **Review `results_on_new_tab = true`** — is this the desired behavior?
45. **Check mobile responsiveness** of the Simple theme with this engine count

### Long-term

46. **SearXNG API for programmatic search** — currently `formats = [ "html" ]` blocks JSON; consider a trusted-only JSON endpoint
47. **SearXNG as qmd data source** — feed SearXNG results into qmd's vector search
48. **Per-user SearXNG preferences** — persist engine selection via cookies (already supported)
49. **SearXNG federation** — query other SearXNG instances for distributed search
50. **Evaluate SearXNG alternatives** — Whoogle, Searx-space federation, etc. (if SearXNG can't meet needs)

---

## G) QUESTIONS I CANNOT ANSWER MYSELF

### 1. Do you want to deploy now, or make more changes first?

The working tree has 71 engines (all with `disabled = false; inactive = false;`), Redis cache limits, increased timeouts, and Yandex autocomplete. `nix flake check --no-build` passes. I don't know if you want to deploy immediately, do more tuning, or review the config first.

### 2. Should I implement the VPS proxy?

You expressed interest in a SOCKS5 proxy on a VPS to hide evo-x2's IP. I need: (a) whether you have a VPS already, (b) its IP/hostname, (c) whether you want WireGuard tunneling or plain SOCKS5. Without this I can't implement it.

### 3. Which engines do you actually want active on every search vs `!bang`-only?

71 engines on every search is aggressive — each query fans out to 71 upstream services. Some (e.g., `adobe stock video`, `findfiles videos`, `fireball videos`, `vuhuv videos`) may be low-value for daily use but useful as `!bang` lookups. I can't decide your threat model / quality bar for which engines stay in the default result set vs become opt-in via `!bang`.

---

## File-level summary

| File | Changes | Lines changed |
|---|---|---|
| `modules/nixos/services/searxng.nix` | Engine list (8→71), timeouts (3s→8s), Redis cache, autocomplete, `disabled` fix | ~100 lines |

No other files were modified. No AGENTS.md, no Gatus config, no post-deploy-check — all identified as next steps above.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
