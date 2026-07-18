# DNS Blocklist Whitelist Filter — Runtime Allowlist Implementation

**Date:** 2026-07-16 06:55
**Session scope:** Making the DNS blocklist whitelist effective at runtime (it was build-time only)
**Trigger:** User reported `discord.com`, `linkedin.com`, and `9gag.com` were blocked despite being in the whitelist

---

## a) FULLY DONE

### 1. Root Cause Analysis — COMPLETE

**Problem:** The `whitelist` in `platforms/common/dns-blocklists.nix` was only consumed by `dnsblockd process` (build-time) for `mapping.json` generation. The runtime DNS resolver loaded raw blocklist files via `dns_blocklists` config key with **zero whitelist filtering**. So `discord.com` was blocked at runtime despite being whitelisted.

**Root cause chain:**

1. `fetchedBlocklists` in `dns-blocker.nix` fetched raw blocklist files via `pkgs.fetchurl`
2. These raw files were passed to both `processedBlocklist` (build-time processor) AND `blocklistPaths` (runtime `dns_blocklists` config key)
3. The build-time processor DID respect the whitelist (line 164-167 of processor.go: `if inWhitelist { return }`)
4. But the runtime DNS engine's `Blocklist.Load()` in `internal/dns/server.go` loaded the raw files directly into an in-memory matcher — no whitelist check
5. dnsblockd has no runtime whitelist/allowlist config key (only a temp-allowlist via HTTP API with TTL)

**dnsblockd matcher behavior (verified):** `Blocklist.Match()` in `internal/dns/blocklist.go:96-128` walks up the dot hierarchy. Querying `foo.discord.com` checks `foo.discord.com`, then `discord.com`, then `com`. So even if `discord.com` is removed from the blocklist, a direct `foo.discord.com` entry would still match. This means the filter must strip both the parent AND all subdomains of whitelisted domains.

### 2. Build-Time Blocklist Filter — COMPLETE

**Files changed:**

- `modules/nixos/services/dns-blocker.nix` — Added a Python-based filter derivation factory

**Implementation:**

- `fetchedRawBlocklists` — fetches raw blocklist files (renamed from `fetchedBlocklists`)
- `whitelistFileForFilter` — writes the whitelist to a text file for the filter script
- `filterScript` — Python script (`pkgs.writeText`) that:
  - Parses all 3 blocklist formats: dnsmasq (`local=/domain/`), adblock (`||domain^`), hosts (`0.0.0.0 domain`)
  - Walks parent domains: `foo.bar.discord.com` is stripped when `discord.com` is whitelisted
  - Preserves comment lines and original formatting
  - Logs `kept=N skipped=M` to stderr
- `filterBlocklist` — `pkgs.runCommand` wrapper that runs the filter per blocklist
- `fetchedBlocklists` — applies the filter to every raw blocklist (23 derivations)

**Both the build-time processor AND the runtime DNS engine now consume the filtered files.**

### 3. Whitelist Domain Expansion — COMPLETE

**File:** `platforms/common/dns-blocklists.nix`

Added comprehensive domain coverage:

**Discord (22 domains):** All Discord Inc. brand TLDs — `discord.com`, `discord.gg`, `discordapp.com`, `discordapp.net`, `discordapp.io`, `discordcdn.com`, `discordactivities.com`, `discord-activities.com`, `discordmerch.com`, `discordpartygames.com`, `discordsays.com`, `discordstatus.com`, `gateway.discord.gg`, `discord.co`, `discord.design`, `discord.dev`, `discord.gift`, `discord.gifts`, `discord.media`, `discord.new`, `discord.store`, `discord.tools`

**LinkedIn (7 domains):** `linkedin.com`, `linkedin.at`, `linkedin.be`, `linkedin.cn`, `linkedin.nl`, `licdn.com`, `lnkd.in`

**9gag (2 domains):** `9gag.com`, `9cache.com`

### 4. Verification — COMPLETE

- `nix flake check --no-build` — passes (all modules eval)
- HaGeZi-social filter test: 14 entries removed (discord/linkedin/9gag), 887 kept
- Hosts-format filter test: 6/7 entries removed, 1 legitimate tracker kept
- All 23 filtered blocklist derivations built successfully in nix store
- Typosquat domains (`accountslinkedin.com`, `modificationviewpointdiscord.com`) correctly remain blocked
- dnsblockd binary builds: `/nix/store/1fqr0kajqk76gn8yaxnn7pqyvcavkbwy-dnsblockd-18ece4b`

### 5. Pre-existing Changes Found (Not Authored This Session)

The git diff shows two changes that were already present before this session:

- `modules/nixos/services/_signoz-alerts.nix` — Added `dnsblockd-crashes.json` alert rule
- `modules/nixos/services/gatus-config.nix` — Added `[BODY].jsonpath.dnsRunning == true` condition to DNS blocker health check

These appear to be from the prior session (DNS reliability work). Left untouched.

---

## b) PARTIALLY DONE

### 1. Expanded Whitelist Not Yet Rebuilt

The whitelist was expanded from 6 Discord domains to 22, but the filtered blocklist derivations in the nix store are from the FIRST build (before the expansion). The expanded whitelist (74 entries total per `nix eval`) has NOT been rebuilt and verified. The `nix flake check --no-build` passes but the actual filtered output with all 22 Discord domains hasn't been confirmed.

### 2. No Deploy Performed

The changes are uncommitted and undeployed. The running system (generation 519) still has the old blocklists without any runtime whitelist filtering.

### 3. rpi3-dns Not Considered

The rpi3-dns host also imports `dns-blocklists.nix`. The filter applies to it too (same module), but this hasn't been verified or deployed.

---

## c) NOT STARTED

### 1. AGENTS.md Update

The `dns-blocker.nix` module now has a significant new mechanism (build-time whitelist filter). AGENTS.md should document:

- The whitelist is now effective at runtime via build-time filtering
- The filter walks parent domains (suffix matching)
- Adding a domain to the whitelist strips it AND all subdomains from all 23 blocklists

### 2. Testing on Live System

No verification that `discord.com`, `linkedin.com`, or `9gag.com` actually resolve after deploy. The `post-deploy-check.sh` script doesn't test for DNS allowlist effectiveness.

### 3. Post-Deploy Smoke Test for Whitelist

The `post-deploy-check.sh` should be extended to verify that whitelisted domains resolve (not just that services are alive).

### 4. Commit

Changes are uncommitted.

---

## d) TOTALLY FUCKED UP

### 1. Python Script Duplication Debacle

**What happened:** The first `edit` call to insert the Python filter script into `dns-blocker.nix` produced a BROKEN result — the script was duplicated twice inside the `runCommand`, with the first copy having a malformed `"$out/${name}"` argument dangling after it. The `runCommand` shell had two Python invocations back-to-back.

**Why:** I wrote the Python script inline using Nix string interpolation inside a `''` multi-string, and the complexity of escaping + the `let` binding caused me to paste the script twice during editing.

**Impact:** Wasted ~5 minutes. The broken version was caught by viewing the file immediately after. Fixed by replacing the entire section with a clean version using `pkgs.writeText` for the script (outside the `runCommand`) and a simple `runCommand` wrapper.

**Lesson:** For complex inline scripts in Nix, always write the script to a separate `pkgs.writeText` derivation and reference it. Never inline multi-line Python inside a `runCommand` string body.

### 2. Toplevel Build Failure Misdiagnosis Sequence

**What happened:** The toplevel build failed. I initially tried to build sub-components to isolate the failure, but went down several wrong paths:

- Tried `nix build .#nixosConfigurations.evo-x2.config.services.dns-blocker.fetchedBlocklists` — failed because `fetchedBlocklists` is a `let` binding, not an option
- Tried `nix eval` with various attr paths — all failed for the same reason
- Tried `nix-instantiate --eval` to access module internals — failed because module `let` bindings aren't exposed

**Actual issue:** The toplevel build fails on `python3.14-cbor2-5.8.0` → `remarshal` → `gatus.yaml` — a **pre-existing nixpkgs Python 3.14 package issue**, completely unrelated to the DNS filter changes. The dnsblockd service unit and all filtered blocklist derivations build fine.

**Lesson:** When a build fails with a deep dependency chain error, look at the ROOT of the chain first (`cbor2`), not the leaves (`gatus`). And don't try to introspect NixOS module `let` bindings from outside — they're not exposed.

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **The whitelist filter is a SystemNix-side workaround.** The proper fix is adding a `dns_whitelist` config key to dnsblockd itself, so the runtime resolver checks it before the blocklist. This would eliminate 23 filter derivations and make the whitelist dynamic (hot-reloadable). The current approach requires a rebuild to change the whitelist.

2. **The filter creates 23 extra derivation builds.** Each blocklist gets its own `runCommand` with a Python invocation. While cached in the nix store, this adds ~23 derivations to every eval path. A single batch-filter derivation would be more efficient.

3. **No automated test for the filter.** The filter was tested manually with a standalone Python script, but there's no Nix-level test that verifies `discord.com` is absent from the filtered output. A `runCommand` test assertion would catch regressions.

4. **The `extract_domain` parser duplicates dnsblockd's logic.** The filter re-implements blocklist parsing (dnsmasq, adblock, hosts formats) in Python, while dnsblockd has this in Go (`internal/blocklist/parser.go`). If dnsblockd adds a new format, the filter won't know about it.

5. **The filter doesn't handle `@@` adblock exception rules.** dnsblockd's parser treats `@@||domain^` as a comment (line 75 of parser.go: `strings.HasPrefix(line, "@@")`). The filter also skips these, which is correct by accident, not by design.

### Operational

6. **No metric or log line confirms how many domains were filtered.** The Python script logs `kept=N skipped=M` to stderr, but this goes to the nix build log and is lost. Consider surfacing this in the dnsblockd stats API or a status file.

7. **The whitelist is a flat list with no grouping/comments.** 74 entries in a single list. Grouping by purpose (Discord, LinkedIn, streaming, infrastructure) with comments would improve maintainability. The Discord section IS commented now, but the rest isn't.

8. **No mechanism to discover what's blocked that shouldn't be.** The current workflow is: notice something broken → check if it's in the blocklist → add to whitelist. A periodic report of newly-blocked domains that were accessed via the temp-allowlist API would surface these proactively.

---

## f) Next 50 Things To Do

#### Immediate (Block deploy)

1. **Rebuild with expanded whitelist** — verify the 22 Discord domains are all stripped from the filtered HaGeZi-social blocklist
2. **Commit all changes** — dns-blocker.nix, dns-blocklists.nix, _signoz-alerts.nix, gatus-config.nix, flake.lock
3. **Deploy to evo-x2** — `nix run .#deploy`
4. **Verify DNS post-deploy** — `python3 -c "import socket; print(socket.gethostbyname('discord.com'))"` etc.
5. **Verify discordsync.service starts** — `systemctl status discordsync.service`
6. **Run post-deploy smoke test** — `nix run .#post-deploy-check`

#### DNS Blocklist Filter Improvements

7. **Add a Nix-level test** that asserts `discord.com` is absent from the filtered HaGeZi-social output
8. **Consolidate 23 filter derivations into one batch** — single `runCommand` that filters all blocklists
9. **Add `dns_whitelist` config key to dnsblockd upstream** — proper runtime whitelist support
10. **Add filter count metrics** — surface how many domains were stripped per blocklist
11. **Handle adblock `@@` exception rules explicitly** — document the behavior, don't rely on accident
12. **Add wildcard support to the whitelist** — `*.discord.com` syntax instead of listing every subdomain
13. **Add a `nix run .#dns-whitelist-report` command** — shows what's in the whitelist and what it filters

#### AGENTS.md / Documentation

14. **Update AGENTS.md** with the build-time whitelist filter mechanism
15. **Document that the whitelist now affects runtime** — this is a behavior change from the prior session
16. **Document the parent-domain walking behavior** — `discord.com` strips `*.discord.com`
17. **Add a "Adding a domain to the DNS whitelist" procedure** to AGENTS.md
18. **Update the dnsblockd whitelist gap documentation** — the gap is now closed for SystemNix
19. **Document the cbor2/remarshal/gatus pre-existing build failure** in AGENTS.md gotchas

#### DNS Architecture

20. **Fix `cache.nixos.org` DNS resolution** — currently fails (pre-existing, not caused by this change)
21. **Deploy rpi3-dns with DoT forwarders** — configured but not deployed
22. **Investigate oauth2-proxy startup race** — DNS timing issue during activation
23. **Consider adding a DNS whitelist sync mechanism** between evo-x2 and rpi3-dns
24. **Review all blocklist categories for over-blocking** — HaGeZi-social blocks entire platforms
25. **Consider replacing HaGeZi-social with a more targeted list** — blocks Mastodon, Bluesky, LinkedIn, Discord, Reddit

#### Monitoring & Alerting

26. **Add Gatus check for discord.com resolution** — verify DNS allowlist works post-deploy
27. **Add Gatus check for linkedin.com resolution**
28. **Extend post-deploy-check.sh** to test whitelisted domain resolution
29. **Add a Prometheus alert for dnsblockd crash count** (already done in _signoz-alerts.nix — verify it works)
30. **Add a periodic DNS resolution test** — cron/timer that resolves key domains and alerts on failure

#### Pre-existing Build Issues

31. **Fix `python3.14-cbor2-5.8.0` build failure** — blocks gatus.yaml generation, prevents toplevel build
32. **Investigate remarshal dependency chain** — remarshal depends on cbor2
33. **Consider pinning Python 3.13 for remarshal/cbor2** — overlay override
34. **Check if nixpkgs unstable has fixed cbor2** — may be a transient issue

#### Code Quality

35. **Extract the filter script to `scripts/dns-blocker-filter.py`** — currently inline in the Nix module
36. **Add type annotations to the Python filter script**
37. **Add unit tests for `extract_domain()` and `is_whitelisted()`** — test all blocklist formats
38. **Consider using `pkgs.python3.withPackages` for the filter** — currently bare python3
39. **Remove the duplicate `whitelistFile` / `whitelistFileForFilter`** — both write the same content
40. **Review whether `processorArgs` / `processedBlocklist` still needs the whitelist file** — the filtered files are already clean

#### Deployment & Operations

41. **Run `nix fmt`** to ensure treefmt/alejandra formatting passes
42. **Update flake.lock** if any inputs changed during this session
43. **Consider adding `dns-blocklists.nix` to `restartTriggers`** — ensure dnsblockd restarts when whitelist changes
44. **Review `blocklist-auto-update.service`** — does it re-fetch raw lists and bypass the filter?
45. **Add a rollback plan** — if the filter breaks DNS, how to quickly revert

#### Security Review

46. **Verify the filter doesn't weaken blocking** — ensure only whitelisted domains are stripped
47. **Audit the whitelist for over-permissive entries** — `akamaihd.net` is very broad
48. **Review whether `linkedin.cn` should be whitelisted** — Chinese LinkedIn may have different privacy implications
49. **Consider DNS leak prevention** — whitelisted domains resolve via DoT forwarders (Cloudflare/Quad9)
50. **Review the filter's handling of IDN/punycode domains** — `xn--` domains may bypass the filter

---

## g) Top 2 Questions

### Q1: Does `blocklist-auto-update.service` bypass the build-time filter?

The module has a `blocklist-auto-update.service` referenced in the systemd units. If this service re-fetches blocklist files at runtime (writing to `/var/lib/dnsblockd/`) and dnsblockd's `dns_reload_interval` picks them up, then the filter is bypassed — the runtime resolver would load unfiltered blocklists. I could not verify this because the service definition is inside the dnsblockd-internal module and I didn't read it. **This is critical to verify before deploying.**

### Q2: Should the whitelist filter live in dnsblockd upstream instead?

The current approach (build-time filtering in Nix) works but creates 23 derivations and requires a rebuild to change the whitelist. Adding a `dns_whitelist` config key to dnsblockd's runtime resolver would be cleaner — the handler already has an `allowlist` check at line 312-317 of `handler.go` (for temp-allowlist), so adding a permanent whitelist check is a small change. Should I implement this upstream and remove the Nix-side filter, or is the build-time approach preferred for its declarative nature?
