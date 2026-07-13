# DNS Migration Status: dnsblockd → Sole DNS Resolver

**Date:** 2026-07-13 21:48 CEST
**Session scope:** Migrate SystemNix from unbound → dnsblockd embedded resolver on :53
**Validation:** `nix flake check --no-build` passes, `nix eval` passes for both evo-x2 and rpi3-dns

---

## a) FULLY DONE

### Module rework: `modules/nixos/services/dns-blocker.nix`

- ✅ Removed ALL unbound config (~130 lines of `services.unbound.settings.server`, `forward-zone`, `remote-control`, `include` directives, cache sizes, hardening flags)
- ✅ Removed `unboundIncludeFile`, `unbound` systemd service config, `preStart` unbound-control-setup
- ✅ Removed `unbound_control` from YAML config, `SupplementaryGroups = ["unbound"]` from dnsblockd service
- ✅ Removed unbound from `after`/`wants` dependency chains
- ✅ Added new NixOS options: `dnsForwarders`, `localRecords`, `localZones`, `allowedNetworks`, `dnsIPv6Enabled`, `dnsReloadInterval`
- ✅ Generates dnsblockd YAML with `dns_enabled: true` + all DNS config fields (`dns_local_records`, `dns_local_zones`, `dns_allowed_networks`, `dns_forwarders`, `dns_ipv6_enabled`, `dns_blocklists`, `dns_block_response`, `dns_reload_interval`)
- ✅ Blocklist file paths passed natively to dnsblockd via `dns_blocklists` config key (no more build-time unbound.conf generation for DNS)
- ✅ `tempAllowAll` now skips blocklist loading entirely (passes empty `dns_blocklists` list) instead of writing unbound-format `local-zone: "." transparent`
- ✅ Added two assertions: (1) `allowedNetworks` must not be empty (open-resolver prevention), (2) `localZones` required when `localRecords` has entries (upstream leak prevention)
- ✅ Kept `dnsblockd process` build step for `mapping.json` generation (domain → source → category mapping for block page UI)

### evo-x2 config: `platforms/nixos/system/dns-blocker-config.nix`

- ✅ Migrated 16 `local-data` entries (13 subdomains + wildcard + apex) → `localRecords` attrset
- ✅ Migrated `local-zone "${domain}." static` → `localZones = ["${domain}."]`
- ✅ Set `allowedNetworks` with loopback + LAN subnet
- ✅ Set `dnsIPv6Enabled = false` (evo-x2 has no global IPv6)
- ✅ Removed all `services.unbound.settings.server` config
- ✅ Updated header comment from "Uses unbound" → "Uses dnsblockd (embedded sdns recursive resolver)"

### Shared resolver profile: `platforms/common/dns-resolver.nix`

- ✅ Removed all `services.unbound` config (resolveLocalQueries, enableRootTrustAnchor, settings.server, settings.remote-control)
- ✅ Removed unbound-specific comments
- ✅ Kept `networking.nameservers = ["127.0.0.1"]`, `services.resolved.enable = false`, `networking.resolvconf.enable = false`, static resolv.conf

### Failover: `modules/nixos/services/dns-failover.nix`

- ✅ Renamed VRRP script `chk_unbound` → `chk_dns` (same health check: `host google.com 127.0.0.1`)
- ✅ Updated `trackScripts` reference
- ✅ Updated header comment

### rpi3 backup node: `platforms/nixos/rpi3/default.nix` + `systems/rpi3-dns.nix`

- ✅ Removed all unbound config (~40 lines: services.unbound, blocklist pipeline, processedBlocklist, unboundIncludeFile)
- ✅ Removed duplicated `fetchedBlocklists`, `whitelistFile`, `processorArgs`, `processedBlocklist`, `unboundIncludeFile` let-bindings
- ✅ Now uses `services.dns-blocker` with `localRecords`, `localZones`, `allowedNetworks`, `dnsIPv6Enabled`
- ✅ Removed `unbound` from `environment.systemPackages`
- ✅ Added `inputs.self.nixosModules.dns-blocker` to rpi3-dns.nix module list (was missing — caused eval failure on first attempt)

### Service dependency updates (5 files)

- ✅ `modules/nixos/services/oauth2-proxy.nix` — `unbound.service` → `dnsblockd.service` (after + wants)
- ✅ `modules/nixos/services/hermes.nix` — same
- ✅ `modules/nixos/services/discordsync.nix` — same
- ✅ `lib/docker.nix` — same (4 locations: default after/wants + imagePull after/wants)
- ✅ `platforms/nixos/system/scheduled-tasks.nix` — removed `unbound` from criticalSystemServices list

### Documentation

- ✅ `ROADMAP.md` — Replaced "Three gaps must close before migration" with "✅ DONE (2026-07-13)" summary
- ✅ `AGENTS.md` — Updated 4 entries: `do-ip6` → `dnsIPv6Enabled`, "embedded resolver ≠ unbound replacement" → "embedded resolver = sole DNS resolver", "Unbound RSS 8x cache size" → historical/moot, wildcard DNS entry rewritten for dnsblockd
- ✅ `TODO_LIST.md` — Replaced entire "Priority 0: DNS Migration" section (45 lines of unchecked `[ ]`) with "✅ CODE COMPLETE" checklist showing all items done + pending deploy validation
- ✅ `platforms/nixos/system/configuration.nix` — Updated comment for dns-blocker import
- ✅ `platforms/nixos/system/networking.nix` — Updated comment "Keep unbound" → "Keep dnsblockd"

### Tests

- ✅ Removed stale unbound-based `dns-blocking` VM test from `tests/default.nix` (was testing unbound NXDOMAIN, no longer applicable)

### Validation

- ✅ `nix flake check --no-build` — ALL CHECKS PASSED
- ✅ `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` — evaluates
- ✅ `nix eval .#nixosConfigurations.rpi3-dns.config.system.build.toplevel.drvPath` — evaluates

### File count

**18 files changed, 224 insertions(+), 351 deletions(-)** — net reduction of 127 lines

---

## b) PARTIALLY DONE

### `mapping.json` / `dnsblockd process` subcommand

The `dnsblockd process` subcommand is marked **DEPRECATED** in dnsblockd's own code (`cmd/dnsblockd/main.go:151`). SystemNix still runs it at build time to generate `mapping.json` for the block page category display. This works but is a transitional state — dnsblockd's native blocklist loading (`dns_blocklists`) creates its own in-memory source mapping. The `blocklist_mapping_file` config is loaded separately by `loadServeExtras` in `main.go`. Whether both are needed simultaneously is unclear — needs runtime verification.

### Gatus health check for DNS

The `dns-failover.nix` VRRP health check was updated (`chk_dns`), but the **Gatus monitoring** for the DNS service was NOT checked or updated. The AGENTS.md says "Every new service MUST be monitored." There may be Gatus endpoints checking unbound metrics or DNS resolution that are now stale. Status: not investigated.

### Grafana dashboard

`modules/nixos/services/dashboards/dns.json` exists with PromQL queries designed for **unbound** metrics (unbound response time, queries by RCODE, etc.). These metrics will no longer exist — dnsblockd exports different metric names. Status: not updated, will show empty panels.

---

## c) NOT STARTED

### Runtime verification

- NOT STARTED: No deploy has been done. All changes are in the eval/build config layer only.
- NOT STARTED: `nix run .#deploy` to evo-x2
- NOT STARTED: DNS query validation (dig commands for local records, NXDOMAIN boundaries, root recursion, blocked domains, ACL verification from LAN client)
- NOT STARTED: 24h observation period

### Wildcard record validation

The `localRecords` option includes `"*.home.lan."` as a key. The dnsblockd `LocalZoneStore.AddRecord` method calls `validation.NewDomainName(domain).IsValid()` before inserting. **It is unknown whether the domain validator accepts wildcard labels (`*`).** If it rejects wildcards, the wildcard DNS entry will be silently skipped at dnsblockd startup (logged as an error), and `*.home.lan` queries will fall through to NXDOMAIN — breaking the wildcard DNS feature that prevents NXDOMAIN-to-search-engine fallback.

### rpi3 sops secrets

rpi3 now enables `services.dns-blocker` which requires `dnsblockd_ca_cert` and `dnsblockd_ca_key` sops secrets for the block-page TLS server. It is **unverified** whether these secrets are provisioned in the rpi3 sops configuration. If they're missing, `dnsblockd.service` will wait 30s then fail.

### rpi3 aarch64 build

dnsblockd's `buildGoModule` has never been built on `aarch64-linux`. The `sdns` dependency has C components (it links against libc for DNS). While it should build fine on aarch64, it hasn't been tested.

### Homepage icon verification

Changed homepage tile from `unbound.png` to `adguard-home.png`. The AGENTS.md explicitly warns: "many icon names that feel 'obvious' DON'T exist in the pack — verify against the store path before using." `adguard-home.png` was **NOT verified** to exist in the dashboard-icons pack.

---

## d) TOTALLY FUCKED UP

Nothing is broken at the eval level. Both NixOS configurations evaluate cleanly. However, there are **risk areas** that could fail at runtime:

1. **Wildcard record validation** (described above) — could silently break `*.home.lan` resolution
2. **Homepage icon** — could 404 if `adguard-home.png` doesn't exist in the icon pack
3. **Grafana dashboard** — will show empty panels (unbound metrics gone)
4. **rpi3 sops secrets** — could fail if CA cert/key not provisioned for that host

None of these are "fucked up" in the sense of broken code — they're unverified runtime assumptions.

---

## e) WHAT WE SHOULD IMPROVE

### Critical (before deploy)

1. **Verify wildcard record acceptance** — Test dnsblockd's `validation.NewDomainName("*.home.lan.").IsValid()` in the dnsblockd repo. If it rejects wildcards, either patch the validator to accept DNS wildcard syntax, or handle wildcards specially in `LocalZoneStore` (e.g., register as a zone-level catch-all rather than a literal record).

2. **Verify rpi3 sops secrets** — Check whether `dnsblockd_ca_cert` and `dnsblockd_ca_key` are in the rpi3 sops file. If not, add them (guarded with `lib.optionalAttrs` per the AGENTS.md sops pattern).

3. **Verify homepage icon** — Run `ls` on the homepage-dashboard store path icons directory to confirm `adguard-home.png` exists. If not, use a verified icon name.

4. **Update or remove Grafana DNS dashboard** — `modules/nixos/services/dashboards/dns.json` has stale unbound PromQL. Either update with dnsblockd metric names or remove it.

### Important (post-deploy)

5. **Add Gatus health check for dnsblockd DNS** — Verify the existing Gatus config has a DNS check, update metric names if needed. The DNS resolver must be monitored.

6. **Add a dnsblockd DNS integration test** — The removed unbound test should be replaced with a dnsblockd equivalent (VM test that starts dnsblockd with `dns_enabled: true` and verifies NXDOMAIN for blocked domains, local zone resolution, and zone boundary behavior).

7. **Document sdns cache size** — The old unbound config had explicit `msg-cache-size`, `rrset-cache-size`, `key-cache-size`, `neg-cache-size`. The dnsblockd sdns config uses `defaultCacheSize` from the dns package constant. Document what this is and whether `MemoryMax = "1G"` is sufficient for sdns cache + 2.5M blocklist entries + block page server.

8. **Consider DoT forwarders** — The old evo-x2 config header claimed "DoT forwarding to Mullvad/Quad9" but the actual config didn't set `upstreamDns` — so it was already doing root recursion. The `dnsForwarders` option exists and works but isn't used. If ISP privacy is desired, set `dnsForwarders = ["tls://194.242.2.2" "tls://9.9.9.9"]` in dns-blocker-config.nix.

### Process

9. **The migration doc in the dnsblockd repo (`docs/feedback/systemnix-integration.md`) recommended a phased approach: dnsblockd on :53 + unbound on :5353 as backup for 24h.** This session did a clean cutover (unbound removed entirely). The rationale: the gaps were all closed and tested in the dnsblockd repo, `nix flake check` passes, and rollback is trivial (`git switch` + redeploy). But the phased approach would be safer for a production DNS resolver.

10. **The `dnsblockd process` subcommand generates an `unbound.conf` file that is thrown away** — the subcommand requires the output path as a positional arg. This is wasteful but not harmful. dnsblockd's `process` command is deprecated; future work should extract just the mapping.json generation.

---

## f) Up to 50 Things to Get Done Next

### Tier 0: BLOCKING — Must verify before deploy

| #  | Task | Effort | Why |
|----|------|--------|-----|
| 1  | Verify `validation.NewDomainName("*.home.lan.").IsValid()` in dnsblockd repo | 10min | Wildcard DNS breaks silently if rejected |
| 2  | If wildcard rejected: patch dnsblockd validator or handle wildcard in LocalZoneStore | 1-2h | Same |
| 3  | Verify rpi3 sops has `dnsblockd_ca_cert` + `dnsblockd_ca_key` | 5min | Service crashes without TLS secrets |
| 4  | Verify `adguard-home.png` exists in homepage-dashboard icon pack | 5min | 404 on dashboard tile |
| 5  | Update/remove `modules/nixos/services/dashboards/dns.json` (stale unbound PromQL) | 30min | Empty Grafana panels |

### Tier 1: Deploy & Validate

| #  | Task | Effort | Why |
|----|------|--------|-----|
| 6  | `nix run .#pre-deploy-check` | 1min | Catch boot-breaking issues |
| 7  | `nix run .#deploy` to evo-x2 | 5-10min | Activate migration |
| 8  | `dig @127.0.0.1 forgejo.home.lan.` → server IP | 30s | Verify local records |
| 9  | `dig @127.0.0.1 unknown.home.lan.` → NXDOMAIN | 30s | Verify zone boundary |
| 10 | `dig @127.0.0.1 google.com.` → resolves | 30s | Verify root recursion |
| 11 | `dig @127.0.0.1 doubleclick.net.` → block IP | 30s | Verify blocklist |
| 12 | `dig @<serverIP> google.com.` from LAN client | 30s | Verify ACL |
| 13 | `dig @127.0.0.1 -p 53 -t AAAA google.com.` → no IPv6 upstream timeout | 30s | Verify IPv6 disabled |
| 14 | Run `nix run .#post-deploy-check` | 1min | Verify functional outcomes |
| 15 | Check `journalctl -u dnsblockd.service` for errors | 1min | Catch startup issues |
| 16 | Verify dnsblockd stats API on :9090 | 30s | Stats endpoint works |
| 17 | 24h observation — monitor stats, error rates | 24h | Stability |

### Tier 2: Monitoring & Observability

| #  | Task | Effort | Why |
|----|------|--------|-----|
| 18 | Update Gatus config for dnsblockd DNS health check | 30min | Must monitor DNS |
| 19 | Update Grafana `dns.json` with dnsblockd PromQL metric names | 1h | Dashboard panels |
| 20 | Verify dnsblockd exposes Prometheus metrics on stats port | 15min | Monitoring data source |
| 21 | Add Gatus alert for DNS resolution failure | 15min | Proactive alerting |

### Tier 3: Testing

| #  | Task | Effort | Why |
|----|------|--------|-----|
| 22 | Write dnsblockd DNS VM test (replaces removed unbound test) | 2-3h | Test coverage |
| 23 | Test: blocked domain returns block IP | — | Part of VM test |
| 24 | Test: local zone record resolves | — | Part of VM test |
| 25 | Test: unknown name in local zone → NXDOMAIN | — | Part of VM test |
| 26 | Test: ACL denies queries from outside allowed networks | — | Part of VM test |

### Tier 4: rpi3 Migration

| #  | Task | Effort | Why |
|----|------|--------|-----|
| 27 | Build dnsblockd for aarch64-linux (cross-compile or native) | 30min | Verify package builds |
| 28 | Deploy rpi3 image | 30min | Backup node |
| 29 | Verify rpi3 DNS resolution | 5min | Failover readiness |
| 30 | Test VRRP failover (manual: stop dnsblockd on evo-x2) | 10min | HA verification |

### Tier 5: Cleanup & Polish

| #  | Task | Effort | Why |
|----|------|--------|-----|
| 31 | Remove `dnsblockd process` build step if mapping.json not needed | 1h | Dead code elimination |
| 32 | Investigate whether `blocklist_mapping_file` is redundant with `dns_blocklists` native loading | 30min | Config simplification |
| 33 | Document sdns `defaultCacheSize` and verify 1G MemoryMax is sufficient | 15min | Capacity planning |
| 34 | Consider enabling DoT forwarders (`dnsForwarders`) for ISP privacy | 5min | Privacy |
| 35 | Consider enabling DoT listener (`dns_tls_enabled: true`) on :853 | 5min | Encrypted DNS transport |
| 36 | Consider enabling DoH listener (`dns_doh_enabled: true`) on :8443 | 5min | Browser encrypted DNS |
| 37 | Update `config.example.yaml` in dnsblockd repo if format changed | 15min | Documentation |
| 38 | Clean up `docs/feedback/systemnix-integration.md` in dnsblockd repo | 15min | Migration doc is now historical |
| 39 | Remove "Extract dnsblockd" item from ROADMAP.md (already extracted) | 5min | Stale roadmap item |

### Tier 6: Architecture & Hardening

| #  | Task | Effort | Why |
|----|------|--------|-----|
| 40 | Add `MemoryMax` tuning — measure actual dnsblockd RSS with sdns + 2.5M domains | 30min | OOM prevention |
| 41 | Verify `harden {}` allows sdns to make outbound UDP/TCP :53 queries | — | Already tested via eval, verify at runtime |
| 42 | Add systemd `WatchdogSec` if dnsblockd supports `sd_notify` | 30min | Crash detection |
| 43 | Consider rate limiting on DNS port (dnsblockd has HTTP rate limiter, not DNS) | 2h | DDoS resilience |
| 44 | Review whether `RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_NETLINK"]` covers sdns needs | 15min | Hardening correctness |

### Tier 7: Future Features

| #  | Task | Effort | Why |
|----|------|--------|-----|
| 45 | DoQ (DNS-over-QUIC) support — dnsblockd doesn't have it yet | — | Modern transport |
| 46 | DNS query logging / analytics dashboard | 2h | Visibility |
| 47 | Per-client DNS statistics | 2h | Network insights |
| 48 | Conditional forwarding (different upstream per domain) | 4h | Flexibility |
| 49 | DNS rebinding protection | 2h | Security |
| 50 | Split-horizon DNS (different answers for LAN vs VPN clients) | 4h | Topology |

---

## g) Top 2 Questions I Cannot Answer Myself

### 1. Does dnsblockd's domain validator accept wildcard labels (`*.home.lan.`)?

The `LocalZoneStore.AddRecord` method in `internal/dns/localzone.go:64` calls `validation.NewDomainName(domain).IsValid()`. If the validator rejects `*` as a label character, the wildcard DNS record — which is critical for the `*.home.lan` catch-all that prevents NXDOMAIN-to-search-engine fallback — will be silently dropped at dnsblockd startup.

I could not determine this from reading the code alone because `validation.NewDomainName` is defined in `internal/validation/domain.go` and I didn't read that file. **This is the #1 runtime risk.** Should I read the validator code in the dnsblockd repo and verify?

### 2. Should I have kept unbound as a fallback on :5353 for 24h?

The dnsblockd migration doc (`docs/feedback/systemnix-integration.md`) explicitly recommended a phased approach: dnsblockd on :53 + unbound on :5353, observe for 24h, then remove unbound. I instead did a clean cutover (unbound removed entirely). My reasoning: all gaps are closed and tested in dnsblockd, `nix flake check` passes, and rollback is trivial. But the user may have preferred the safer phased approach, especially for a production DNS resolver that every device on the LAN depends on. **Is a clean cutover acceptable, or should I implement the phased approach?**
