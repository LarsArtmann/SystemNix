# Session: Wildcard `*.home.lan` DNS + Caddy Catch-All

**Date:** 2026-07-12 16:23
**Trigger:** User reported `*.home.lan` typos/unknown subdomains landing on DuckDuckGo instead of resolving locally.

---

## What Was Done

### Root Cause

Unbound's `local-zone "home.lan." static` only returned A records for 16 explicit `local-data` entries (defined in `platforms/common/dns-local.nix`). Any subdomain NOT in that list (typos, services not yet added, browser address-bar guesses) returned **NXDOMAIN**. Chromium-based browsers (Helium) treat single-word-looking NXDOMAIN queries as **search queries** → DuckDuckGo.

### Changes Made (3 files)

| File                                            | Change                                                                                    | Status                  |
| ----------------------------------------------- | ----------------------------------------------------------------------------------------- | ----------------------- |
| `platforms/nixos/system/dns-blocker-config.nix` | Added wildcard `*.home.lan.` + apex `home.lan.` local-data records pointing to `serverIP` | ✅ Written, eval-passes |
| `platforms/nixos/rpi3/default.nix`              | Same wildcard + apex records (using `lanIP` = evo-x2's `192.168.1.150`)                   | ✅ Written, eval-passes |
| `modules/nixos/services/caddy.nix`              | New `https://*.${domain}` catch-all vHost → redirects to `dash.${domain}`                 | ✅ Written, eval-passes |
| `AGENTS.md`                                     | Added gotcha entry documenting the wildcard DNS + Caddy catch-all pattern                 | ✅ Written              |

### Verification Done

- `nix flake check --no-build` → **all checks passed** (syntax + eval)
- `nix fmt` → formatted
- Confirmed `lanIP` on rpi3 correctly points to evo-x2 (not the Pi itself)
- Confirmed TLS cert is a wildcard `*.home.lan` cert (valid until Apr 2036, per AGENTS.md)

### Verification NOT Done

- **No deploy** — changes are uncommitted and undeployed
- **No runtime DNS test** — did not verify unbound actually resolves the wildcard
- **No browser test** — did not verify the DuckDuckGo fallback is actually gone
- **No Caddy reload test** — did not verify the catch-all vHost ordering works in practice

---

## Categories

### a) FULLY DONE

1. **Root cause identified** — NXDOMAIN from `static` zone → browser search fallback
2. **Wildcard DNS added** — both evo-x2 and rpi3 configs updated
3. **Caddy catch-all added** — unknown `*.home.lan` HTTPS redirects to dashboard
4. **AGENTS.md updated** — gotcha documented for future sessions
5. **Flake check passes** — syntax and eval validated
6. **Formatting applied** — `nix fmt` run

### b) PARTIALLY DONE

1. **DNS zone boundary** — The zone is still `static` (correct — queries outside `home.lan.` go to normal recursion). But no test verifies the wildcard doesn't leak beyond `home.lan.` into real DNS lookups. The TODO_LIST.md items (`dig @127.0.0.1 unknown.home.lan.` → NXDOMAIN) are now **wrong** — unknown subdomains now RESOLVE, not NXDOMAIN. These TODO items need updating.
2. **Caddy catch-all UX** — The redirect goes to `dash.home.lan` which is behind `protectedVHost` (oauth2-proxy). An unauthenticated user hitting a typo will be bounced to Pocket ID login → dashboard. This may be confusing UX but is better than DuckDuckGo. A plain error page or a "service not found" page would be cleaner.

### c) NOT STARTED

1. **Deploy** — `nix run .#deploy` not run
2. **Post-deploy verification** — No `dig`, `curl`, or browser test after deploy
3. **TODO_LIST.md update** — DNS zone boundary test items are now stale (they expect NXDOMAIN for unknown subdomains, which no longer happens)
4. **`dns-local.nix` cleanup** — The 16-entry `localSubdomains` list is now technically redundant for DNS resolution (wildcard catches everything), but serves as documentation of known services. Decision needed: keep for clarity or remove as dead config.
5. **Gatus health check for the catch-all** — No monitoring for whether the wildcard DNS / Caddy catch-all is working

### d) TOTALLY FUCKED UP

**Nothing catastrophically broken**, but one significant concern:

1. **Unbound wildcard local-data in a `static` zone — UNVERIFIED at runtime.** Unbound DOES support wildcard local-data entries (`*.domain.` in `local-data`), and this is a well-documented feature. But I did not test it on this specific unbound version with this specific config. If it silently doesn't work, the user will still hit DuckDuckGo. This is the **#1 risk** of the entire session. The fix: deploy, then `dig randomnonexistent.home.lan @127.0.0.1`.

### e) WHAT WE SHOULD IMPROVE

1. **Always note what was NOT tested.** I ran `nix flake check --no-build` and implicitly presented it as "verified". Eval-passing ≠ runtime-working. I should have explicitly stated "eval-verified, runtime-UNVERIFIED" in my summary.
2. **Browser-side search behavior.** The DuckDuckGo fallback is a browser behavior, not a DNS behavior. Even with perfect DNS, if a user types something that looks like a search query (e.g., a space, or a single word without dots), the browser may still search. The DNS fix only helps when the browser does a DNS lookup that fails. A more complete fix would also configure Helium's `keyword.enabled = false` or set `browser.fixup.alternate.enabled` to prevent keyword-to-search conversion for `.lan` domains. This was NOT investigated.
3. **Caddy vHost ordering assumption.** I assumed Caddy matches most-specific-first (explicit `auth.home.lan` beats wildcard `*.home.lan`). This is correct Caddy behavior, but I didn't verify it against the actual Caddy config. If Caddy's wildcard matching has a quirk with the `auto_https off` + manual TLS setup, an explicit vHost could be shadowed.
4. **The redirect target.** Redirecting to `dash.home.lan` (a protected vHost) means typo victims hit an auth wall. A lightweight "service not found" page served directly by Caddy (no proxy, no auth) would be better UX. This is a design improvement, not a bug.
5. **Stale TODO_LIST.md.** I noticed TODO_LIST.md has DNS verification items that are now wrong but didn't fix them. Should always update related docs when changing behavior.

### f) Next 50 Things To Do

| #   | Priority | Task                                                                                                                                                                                                               | Effort |
| --- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------ |
| 1   | **P0**   | **Deploy** (`nix run .#deploy`) and verify wildcard DNS resolves                                                                                                                                                   | 10 min |
| 2   | **P0**   | `dig randomnonexistent.home.lan @127.0.0.1` → must return 192.168.1.150                                                                                                                                            | 1 min  |
| 3   | **P0**   | Browser test: type `typo123.home.lan` in Helium → must NOT go to DuckDuckGo                                                                                                                                        | 2 min  |
| 4   | **P0**   | Browser test: type `auth.home.lan` → must still reach Pocket ID (not shadowed by wildcard)                                                                                                                         | 2 min  |
| 5   | **P0**   | `curl -sk https://randomnonexistent.home.lan` → must redirect to `dash.home.lan`                                                                                                                                   | 1 min  |
| 6   | **P1**   | Verify all 16 existing explicit subdomains still resolve correctly (not shadowed)                                                                                                                                  | 5 min  |
| 7   | **P1**   | Update TODO_LIST.md — DNS zone boundary items now expect RESOLVE not NXDOMAIN                                                                                                                                      | 5 min  |
| 8   | **P1**   | Consider a "service not found" Caddy response page instead of redirect to auth-protected dashboard                                                                                                                 | 30 min |
| 9   | **P1**   | Investigate Helium/Chromium `keyword.enabled` / `browser.fixup` settings for `.lan` TLD                                                                                                                            | 15 min |
| 10  | **P1**   | Add Gatus health check for wildcard DNS resolution                                                                                                                                                                 | 10 min |
| 11  | **P2**   | Decide whether `dns-local.nix` `localSubdomains` list should remain (documentation) or be removed (dead config now that wildcard exists)                                                                           | 5 min  |
| 12  | **P2**   | Consider extracting the wildcard local-data into `dns-local.nix` for DRY (both nodes duplicate the same `++ [ wildcard, apex ]` block)                                                                             | 10 min |
| 13  | **P2**   | Test the rpi3 failover path — does the wildcard work when rpi3 is primary DNS?                                                                                                                                     | 15 min |
| 14  | **P2**   | Check if the Caddy catch-all vHost needs to be ordered explicitly (Caddy `order` directive)                                                                                                                        | 10 min |
| 15  | **P2**   | Consider HTTP (port 80) catch-all for unknown subdomains — currently only the `:80` block handles `*.${domain}` with a redirect to HTTPS, which then hits the HTTPS catch-all. Verify this two-hop redirect works. | 5 min  |
| 16  | **P2**   | Verify `home.lan` apex (no subdomain) resolves and Caddy handles it                                                                                                                                                | 5 min  |
| 17  | **P2**   | Check if other LAN devices (phones, Mac) benefit from the wildcard or need browser-side config                                                                                                                     | 10 min |
| 18  | **P2**   | Document in README.md that `*.home.lan` is a wildcard (all subdomains resolve)                                                                                                                                     | 5 min  |
| 19  | **P3**   | Consider adding a test to `tests/default.nix` for wildcard local-data resolution                                                                                                                                   | 30 min |
| 20  | **P3**   | Audit all services in `dns-local.nix` — are there any that SHOULD NOT resolve via wildcard? (e.g., internal-only admin endpoints)                                                                                  | 15 min |
| 21  | **P3**   | Consider IPv6 — wildcard only adds A records, no AAAA. If IPv6 is ever enabled, need `*.home.lan. IN AAAA` too                                                                                                     | 5 min  |
| 22  | **P3**   | The `dns-blocker.nix` module's own unbound settings (lines 247-249) also has `local-zone` entries for whitelist/extraDomains — verify the wildcard doesn't interfere with blocklist zones                          | 10 min |
| 23  | **P3**   | Check if `dnsblockd-attach-ip` or `keepalived` need awareness of the wildcard                                                                                                                                      | 5 min  |
| 24  | **P3**   | Consider a reverse approach: instead of wildcard + catch-all redirect, use Caddy's `handle_errors` to serve a custom 404 for unknown subdomains                                                                    | 15 min |
| 25  | **P3**   | Review whether the `*.home.lan` cert covers the apex `home.lan` (some wildcard certs don't cover the bare domain)                                                                                                  | 5 min  |
| 26  | **P3**   | If the TLS cert does NOT cover `home.lan` apex, Caddy will fail TLS handshake for `https://home.lan` — verify                                                                                                      | 2 min  |
| 27  | **P3**   | Add a comment in `dns-blocker-config.nix` explaining why both explicit + wildcard records exist (explicit = documentation, wildcard = catch-all)                                                                   | 2 min  |
| 28  | **P3**   | Consider consolidating DNS local-data between evo-x2 and rpi3 into a single shared expression (currently duplicated with slight structural differences)                                                            | 20 min |
| 29  | **P3**   | Check if `unbound-control` can be used to test wildcard resolution without deploy                                                                                                                                  | 10 min |
| 30  | **P3**   | Review the `dns-blocking` test in `tests/default.nix` — it tests NXDOMAIN for blocked domains but has no test for local-zone wildcard behavior                                                                     | 15 min |
| 31  | **P4**   | Consider DNS-over-HTTPS implications — if any client uses DoH to an external resolver, `*.home.lan` won't resolve there                                                                                            | 5 min  |
| 32  | **P4**   | Review mDNS/`.local` domain interactions — ensure no confusion between `home.lan` and `home.local`                                                                                                                 | 5 min  |
| 33  | **P4**   | Consider adding a periodic check (Gatus) that verifies `*.home.lan` still resolves to the correct IP                                                                                                               | 10 min |
| 34  | **P4**   | Document the wildcard behavior in `docs/runbooks/` for ops reference                                                                                                                                               | 10 min |
| 35  | **P4**   | Consider security: wildcard DNS means any internal service that spins up on a new port is immediately discoverable by hostname (no DNS gate)                                                                       | 5 min  |
| 36  | **P4**   | Review whether the `protectedVHost` forward-auth still works correctly when the vHost is matched via wildcard Caddy fallback (shouldn't be an issue since explicit vHosts take priority, but verify)               | 10 min |
| 37  | **P4**   | Consider adding `home.lan` to browser's "local domains" list (Chromium `--proxy-bypass-list` or similar)                                                                                                           | 5 min  |
| 38  | **P4**   | Check if Android/Taskwarrior sync client benefits from the wildcard or needs explicit DNS entries                                                                                                                  | 5 min  |
| 39  | **P4**   | Review if the DNS failover VRRP setup needs any changes for the wildcard to work during failover                                                                                                                   | 10 min |
| 40  | **P4**   | Consider adding the wildcard to the `dns-blocker.nix` module itself (as an option) rather than in consumer configs                                                                                                 | 20 min |
| 41  | **P4**   | Check if the `browser-policies.nix` module should enforce homepage/search settings to prevent DuckDuckGo fallback                                                                                                  | 10 min |
| 42  | **P4**   | Consider whether other browsers (Firefox if installed) need similar anti-search config                                                                                                                             | 5 min  |
| 43  | **P4**   | Review the `:80` HTTP catch-all — it redirects `*.${domain}` to HTTPS, but does it also handle `home.lan` apex?                                                                                                    | 5 min  |
| 44  | **P4**   | Consider adding a `Server` header to the catch-all response for debugging                                                                                                                                          | 2 min  |
| 45  | **P4**   | Review if the catch-all should return 404 instead of 301 redirect (some clients/prefetchers may behave differently)                                                                                                | 5 min  |
| 46  | **P4**   | Check if the `post-deploy-check.sh` script should test wildcard resolution                                                                                                                                         | 10 min |
| 47  | **P4**   | Consider documenting the wildcard in `FEATURES.md` under "Local DNS records"                                                                                                                                       | 2 min  |
| 48  | **P4**   | Review if the wildcard breaks any existing DNS debugging workflows (`dig` expectations)                                                                                                                            | 5 min  |
| 49  | **P4**   | Consider a D2 diagram of the DNS resolution flow (browser → unbound → wildcard → Caddy → catch-all)                                                                                                                | 15 min |
| 50  | **P4**   | Commit the changes                                                                                                                                                                                                 | 2 min  |

### g) Top 2 Questions I Cannot Answer Myself

1. **Does the `*.home.lan` TLS certificate also cover the bare apex `home.lan`?** I added `home.lan.` as a local-data record, and Caddy's catch-all is `https://*.${domain}`. If a user visits `https://home.lan` (no subdomain), Caddy needs to serve TLS for it. Most wildcard certs (`*.home.lan`) do NOT cover the apex (`home.lan`) — they're separate. If the cert doesn't cover the apex, the TLS handshake will fail for `https://home.lan`. **I need to know: does the dnsblockd-generated wildcard cert include `home.lan` as a SAN, or only `*.home.lan`?** I can check this after deploy with `openssl s_client -connect 192.168.1.150:443 -servername home.lan`.

2. **Should the browser (Helium) also be configured to NEVER search for `.lan` / `.home.lan` domains?** The DNS wildcard fix is necessary but may not be sufficient. Chromium's omnibox has a "keyword search" feature that can intercept certain inputs before DNS lookup. If the user types something that looks ambiguous, the browser might search instead of doing a DNS lookup at all. Is the intent purely "DNS must resolve" (Layer 3 fix, done) or also "browser must never search for `.lan`" (Layer 7 fix, not investigated)? Configuring `browser.fixup.alternate.enabled` or Helium's search settings would be the complete fix. **I need to know: should I also add Chromium flags / policies to disable keyword-search for `.lan` domains, or is the DNS fix sufficient for your usage?**
