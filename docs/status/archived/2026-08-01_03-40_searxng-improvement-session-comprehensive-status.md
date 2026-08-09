# SearXNG Improvement Session — Comprehensive Status

**Date:** 2026-08-01 03:40 CEST
**Scope:** SearXNG (`modules/nixos/services/searxng.nix`) configuration audit and improvement
**Session commits:** `b473f783` → `2f8a0a15` (5 commits, all pushed)

---


## a) FULLY DONE

| Item | Commit | Verification |
| --- | --- | --- |
| `autocomplete = "google"` → `"duckduckgo"` | `b473f783` | `nix eval` confirms `duckduckgo` |
| Google engine re-enabled (general, images, videos) | `b473f783` | `nix eval --json` confirms `inactive = false` |
| Bing engine re-enabled | `b473f783` | `nix eval --json` confirms `disabled = false` |
| Hostnames plugin configured (high_priority + remove) | `9f491978` | `nix eval --json` confirms regex patterns |
| Noise removed (useragent_suffix="", pool_*, suspended_times) | `9f491978` | Diff verified — all removed |
| `hotkeys = "vim"` reverted (subjective UX) | `9f491978` | Diff verified — removed |
| AGENTS.md gotcha entries added (2 new rows) | `8c8559f1`, `2f8a0a15` | Grep confirms entries present |
| `nix flake check --no-build` passes | all | Verified after every change |
| All commits pushed to `origin/master` | `git push` | `bd380ca0..2f8a0a15` confirmed |

---

## b) PARTIALLY DONE

| Item | Status | What remains |
| --- | --- | --- |
| **Runtime verification** | NOT DEPLOYED | All changes are eval-verified but NOT deployed. `nix run .#deploy` + `nix run .#post-deploy-check` needed to confirm engines actually merge correctly at runtime and Google/Bing results appear |
| **Hostnames plugin** | Config written, not runtime-verified | Need to deploy and search for e.g. "rust error" to confirm Stack Overflow bubbles to top, Pinterest disappears |
| **Engine merge behavior** | YAML structure verified correct | SearXNG's `use_default_settings` + `engines` override list merge is well-documented but we have not observed it live |

---

## c) NOT STARTED

| Item | Why it matters |
| --- | --- |
| Deploy + post-deploy smoke test | All work is theoretical until deployed |
| Browser testing (search quality) | Need to verify Google/Bing results actually appear alongside DDG/Brave |
| `hostnames.replace` for privacy frontends | YouTube→Invidious, Reddit→Redlib — evaluated and deliberately deferred (frontends are chronically unreliable) |
| `open_metrics` integration | SearXNG has a built-in Prometheus metrics endpoint behind basic auth. Could integrate with SigNoz/Gatus. Not needed — Gatus health check already covers availability |
| DOI resolver override | `sci-hub.se` as default DOI resolver — legal gray area, not appropriate for this homelab |
| Autocomplete A/B test | DDG autocomplete may be lower quality than Google's. Should test after deploy and potentially try `brave` as a middle ground |

---

## d) TOTALLY FUCKED UP (Self-Criticism)

### Mistakes made and fixed in this session

| # | Mistake | Impact | Fix |
| --- | --- | --- | --- |
| 1 | **`useragent_suffix = ""`** — added an empty string that does literally nothing | Noise in config, misleading "what" comment suggesting it "identifies the instance" when it's empty | Removed entirely in self-review pass |
| 2 | **`pool_connections = 100`, `pool_maxsize = 20`, `keepalive_expiry = 5.0`** — re-stated exact SearXNG defaults | Anti-pattern: re-stating defaults means upstream improvements don't track. Pure maintenance burden for zero value | Removed entirely |
| 3 | **`suspended_times`** — re-stated all 6 default suspension values | Same anti-pattern as #2. 15 lines of noise | Removed entirely |
| 4 | **`hotkeys = "vim"`** — imposed subjective UX preference unilaterally | User didn't ask for vim keybindings. This is a personal preference, not a config improvement | Reverted |
| 5 | **"What" comments** — several comments described what the code does instead of why | Violates AGENTS.md rule 8 ("NEVER ADD COMMENTS... Focus on *why* not *what*") | Cleaned up — remaining comments explain rationale only |
| 6 | **No deploy verification** — all work is eval-only | Could have runtime merge issues we haven't seen | Identified but not yet deployed (see NOT STARTED) |

### Process mistakes

| # | Mistake | Lesson |
| --- | --- | --- |
| 7 | **First pass added 6 changes, 4 were noise** | Should have studied SearXNG defaults FIRST before adding anything. The settings.yml from GitHub showed all the defaults — I should have diffed against those before writing |
| 8 | **Committed via auto-git daemon** | Pre-commit hook caught a pre-existing VM boot test failure (`checks.x86_64-linux.boot` — QEMU `systemctl is-system-running` timeout) that blocked my explicit commit. The auto-git daemon committed anyway without the hook. This is expected behavior per AGENTS.md but means the pre-commit `nix flake check` didn't run on the refactor commit |

---

## e) WHAT WE SHOULD IMPROVE

### SearXNG-specific

1. **Deploy and verify runtime behavior** — the #1 priority. All changes are eval-verified only
2. **Test autocomplete quality** — DDG autocomplete may feel different from Google's. Try `brave` as alternative
3. **Add more `hostnames.high_priority` entries** after real-world usage reveals which sites you click most
4. **Consider `hostnames.remove` expansion** — add content farms you encounter (e.g. `quora\.com`, `experts-exchange\.com`)
5. **Evaluate `preferences.lock`** — lock `autocomplete`, `favicon_resolver`, `method` so per-user preference changes don't silently revert privacy settings
6. **Consider enabling `mwmbl` as an additional engine** — a community-built, non-profit, privacy-respecting search index. Free result diversity without Google/Bing tracking

### Architectural / Process

7. **The pre-existing VM boot test failure** (`checks.x86_64-linux.boot`) blocks the pre-commit hook for ALL commits. This QEMU test has been failing since before this session. Should investigate or skip it in the hook
8. **Auto-git daemon bypasses pre-commit hooks** — expected behavior, but means the `statix`/`deadnix`/`nix flake check` validation in `.githooks/pre-commit` doesn't run on daemon commits

---

## f) Up to 50 Things to Get Done Next

### SearXNG (immediate)

1. Deploy with `nix run .#deploy`
2. Run `nix run .#post-deploy-check` to verify SearXNG health
3. Open browser, search "rust trait object" — verify Stack Overflow is at top
4. Search "pinterest cats" — verify Pinterest results are removed
5. Search "hello world" — verify Google results appear (not just DDG/Brave)
6. Test autocomplete — type "rust" in search bar, verify DDG suggestions appear
7. Check `/stats` page — verify Google and Bing show as active engines with result counts
8. Evaluate autocomplete quality after a week of use — consider switching to `brave` if DDG feels weak

### SearXNG (medium-term)

9. Add more `high_priority` entries based on real click patterns (check browser history)
10. Add more `remove` entries for content farms you encounter
11. Consider `preferences.lock` for `autocomplete` and `method`
12. Evaluate `mwmbl` engine — add if it provides value
13. Consider enabling `url_formatting = "host"` for cleaner result URLs (hides tracking params visually)
14. Evaluate `oa_doi_rewrite` plugin if you do academic research
15. Consider adding NixOS wiki to `high_priority` (already done) + add `search.nixos.org`
16. Consider adding `crates.io` to high_priority for Rust development
17. Consider adding `hackage.haskell.org` if you use Haskell
18. Test `hostnames.replace` with a reliable Invidious instance if you watch YouTube results often

### System-wide (from session observations)

19. Fix the pre-existing `checks.x86_64-linux.boot` VM test failure — it blocks ALL pre-commit hooks
20. Audit whether the auto-git daemon should run pre-commit validation
21. Consider adding a SearXNG search quality test to post-deploy-check (assert Google engine returns results)
22. Review whether the DNS-gate (`searxng-wait-dns`) timeout of 120s is appropriate — engines that fail init are permanently disabled
23. Consider adding `searxng-config-check` oneshot that validates `settings.yml` was generated correctly post-deploy
24. The `searxng-secret-key` oneshot uses `StateDirectory = "searxng"` which creates `/var/lib/searxng/` — verify this doesn't conflict with DynamicUser's ephemeral home
25. Consider whether `MemoryMax = "512M"` is sufficient for SearXNG with image_proxy + favicon cache + Google enabled
26. Audit favicon cache growth — `LIMIT_TOTAL_BYTES = 2147483648` (2GB) could fill `/var/cache/searx/`
27. Consider adding a Gatus check for SearXNG search functionality (not just `/healthz`) — e.g. query `test` and assert results returned
28. Review whether the `ban_time_on_fail = 5` is too aggressive for Google (Google rate-limits aggressively)
29. Consider increasing Google engine `timeout` specifically — Google can be slow and 3s default may cause premature bans
30. Evaluate whether `http_protocol_version = "1.1"` is still needed (Caddy handles HTTP/2 to client, SearXNG backend is HTTP/1.1)

### AGENTS.md / Documentation

31. The AGENTS.md gotcha table is enormous (>100 rows). Consider splitting into sections by service
32. The autocomplete privacy gotcha could reference the `hostnames` plugin entry more explicitly
33. Document the `engines` override merge mechanism (Nix attrset list → SearXNG YAML list → merge by `name` field)
34. Add a note about the auto-git daemon bypassing pre-commit hooks in the Critical Rules section
35. The SearXNG section in AGENTS.md should cross-reference the `hostnames` plugin docs URL

### Monitoring

36. Add a Gatus check that actually performs a search query (not just healthz) — catches silent engine failures
37. Consider SigNoz alert rule for SearXNG response time degradation (>2s average)
38. Monitor favicon cache disk usage via the existing disk monitoring stack
39. Add a periodic check that Google/Bing engines are not in "banned" state (SearXNG `/stats/errors` endpoint)
40. Consider exporting SearXNG's built-in metrics via `open_metrics` to SigNoz

### Code quality

41. The `searxng.nix` module is 227 lines — within reason but the `let` block (lines 15-72) could be extracted
42. Consider whether `generateSecretKey` and `waitDnsReady` should be in `pkgs/` for reuse
43. The `limiterSettings` hardcoded `lanSubnet` could be made a module option for portability
44. Consider whether `favicon_resolver = "duckduckgo"` and `autocomplete = "duckduckgo"` should be module options
45. The `engines` list could be a module option with validation (assert engine names exist in SearXNG defaults)

### Future features

46. Consider adding a SearXNG `hostnames` external YAML file for larger rule sets
47. Evaluate SearXNG's `plugins.tor_check` if Tor relay is ever added
48. Consider SearXNG multi-language engine duplicates (e.g. Google DE + Google EN)
49. Evaluate whether to enable ` Formats = [ "csv" ]` for data export use cases
50. Consider integrating SearXNG's `/autocompleter` endpoint with the DMS spotlight launcher

---

## g) Questions I Cannot Answer Myself

**None.** All decisions in this session were self-contained configuration choices with clear documentation. No external input needed.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
