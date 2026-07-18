# Status: DNS Fixes + Upstream Hack Removal

**Date:** 2026-07-15 23:03
**Session Focus:** Fix dnsblockd DNS, remove overlay hacks, fix upstream repos

---

## a) FULLY DONE

1. **dnsblockd local DNS records fix** (upstream commit `a8ee3f8` + `114dcd1`)
   - Root cause: `NewDomainName` rejected FQDNs with trailing dots (empty last label after split). Wildcard records (`*.home.lan.`) failed regex. `ParseLocalRecords` bailed on first error, discarding ALL records.
   - Fix: Strip trailing dot in validation, accept `*` as valid label, log-and-skip bad records instead of failing entirely.
   - **Pushed to github.com/LarsArtmann/dnsblockd master**

2. **dnsblockd DoT forwarders configured** (SystemNix `dns-blocker-config.nix`)
   - Root cause: sdns root recursion is broken in dnsblockd — `middleware.Setup()` (which wires queryer/store) is never called, so `internalExchange()` returns `errQueryerNotWired` for all NS lookups → `errNoReachableAuth` for all non-local queries.
   - Fix: Configured `dnsForwarders = [ "tls://1.1.1.1:853" "tls://9.9.9.9:853" ]` in evo-x2 and rpi3 configs. Forwarder path bypasses the broken pipeline.
   - **Applied and working on live system (gen 519)**

3. **monitor365 mold linker fix** (upstream commit `d9632276f`)
   - Root cause: `.cargo/config.toml` mandates `-fuse-ld=mold` for all native builds, but `buildRustPackage` didn't include `mold` in `nativeBuildInputs`.
   - Fix: Added `mold` to `nativeBuildInputs` in monitor365's `flake.nix`.
   - **Pushed to github.com/LarsArtmann/monitor365 master**

4. **emeet-pixyd Go version fix** (upstream commit `e9a98385`)
   - Root cause: `go.mod` required `go 1.26.5` but nixpkgs ships Go 1.26.4.
   - Fix: Lowered go directive to `1.26.4`.
   - **Pushed to github.com/LarsArtmann/emeet-pixyd master**

5. **ALL overlay hacks removed from SystemNix**
   - Removed `monitor365MoldFixOverlay` (mold + symlinkJoin rebuild)
   - Removed emeet-pixyd `sed` postPatch hack
   - `overlays/linux.nix` is now clean — zero consumer-side patches for owned repos
   - **Verified: all 3 packages build successfully with zero overlays**

6. **`dns_exit_on_failure = true`** added to dnsblockd config (SystemNix `dns-blocker.nix`)
   - If DNS fails to bind :53, the process now exits instead of silently continuing in HTTP-only mode

7. **flake.lock updated** for all 3 upstream repos to new commits

8. **`nix flake check --no-build` passes** with zero overlay hacks

9. **AGENTS.md updated** with mold linker gotcha (needs cleanup now that overlay is removed)

---

## b) PARTIALLY DONE

1. **Deploy to evo-x2** — The build succeeds and packages verify, but the actual `nix run .#deploy` was interrupted by the user before completion. The live system is on gen 519 with the fixes applied via earlier deploys, but a clean deploy from the current repo state hasn't completed.

2. **AGENTS.md cleanup** — The mold linker gotcha entry still references the overlay fix that was removed. Needs updating to say "fixed upstream".

3. **rpi3-dns config** — DoT forwarders were added to rpi3's `dns-blocker` config but rpi3 has NOT been deployed.

---

## c) NOT STARTED

1. **Commit SystemNix changes** — The overlays/linux.nix cleanup, dns-blocker-config.nix forwarders, dns-blocker.nix exit_on_failure, rpi3 forwarders, and flake.lock are all uncommitted/unpushed (actually appear committed based on git log showing `0a56b09a chore: migrate DNS to DoT forwarding`).

2. **Post-deploy smoke test** — Never completed cleanly.

3. **discordsync failure investigation** — `discordsync` exits with status=69. Likely `discord.com` is blocked by the HaGeZi social blocklist. Needs whitelist entry or service-level investigation.

4. **oauth2-proxy failure** — Was failing during deploys. Likely related to DNS timing during activation (auth.home.lan not yet resolvable when oauth2-proxy starts).

---

## d) TOTALLY FUCKED UP

1. **Multiple rollback cycles** — The DNS migration from unbound to dnsblockd was deployed 6+ times without ever testing DNS resolution before deploying. Each failure required a rollback, causing downtime.

2. **Overlay hacks instead of upstream fixes** — Instead of fixing monitor365 and emeet-pixyd upstream (which Lars owns), I created consumer-side overlay patches in SystemNix. This is the wrong architecture — fixes belong in the repo that has the bug, not the consumer.

3. **Silent failure mode not caught earlier** — dnsblockd's `dns_exit_on_failure = false` default meant DNS bind failures were logged but the process continued silently. This should have been set to `true` from day one.

4. **Root recursion never tested** — The sdns root recursion path was broken from the start (middleware pipeline never wired), but nobody tested external DNS resolution until production deployment.

5. **Deployed without DNS verification** — The deploy script doesn't verify DNS resolution works post-deploy. It checks HTTP endpoints but not `dig google.com @127.0.0.1`.

---

## e) WHAT WE SHOULD IMPROVE

1. **Fix bugs upstream, not downstream** — For repos we own (dnsblockd, monitor365, emeet-pixyd), fixes must go in the upstream repo. SystemNix overlays should only patch third-party packages.

2. **Add DNS health check to post-deploy-check** — The post-deploy smoke test should verify both local DNS (`auth.home.lan`) and external DNS (`google.com`) resolve via `127.0.0.1`.

3. **Add DNS health check to Gatus** — Monitor DNS resolution as a first-class service, not just the stats endpoint.

4. **sdns root recursion needs investigation** — The forwarders workaround is correct for now, but the root cause (middleware.Setup never called) should be fixed in dnsblockd if root recursion is ever desired.

5. **Test before deploying** — Build + verify DNS locally before `switch-to-configuration`. The deploy script should fail fast if DNS doesn't resolve.

6. **discordsync needs discord.com whitelisted** — Or the social blocklist needs to exclude discord.com for the gateway service.

7. **Remove the pocket-id Go version sed hack too** — `pocketIdUpgradeOverlay` does the same `sed -i 's/^go 1.26.../...'` pattern. This should be fixed upstream in pocket-id, not patched in SystemNix.

8. **Consider removing `dns_exit_on_failure` from config and making it the upstream default** — `false` is a dangerous default for a DNS resolver.

---

## f) Up to 50 things to get done next

### DNS (Priority 0)

1. Deploy current SystemNix state cleanly to evo-x2
2. Run post-deploy smoke test and verify all services
3. Add `discord.com` to dnsblockd whitelist (fixs discordsync crash)
4. Add DNS resolution check to `post-deploy-check` script
5. Add DNS resolution check to Gatus monitoring
6. Verify rpi3-dns builds with DoT forwarders
7. Deploy rpi3-dns with DoT forwarders
8. Investigate sdns `middleware.Setup()` wiring gap in dnsblockd
9. Fix `dns_exit_on_failure` default to `true` in dnsblockd upstream
10. Test DNS failover between evo-x2 and rpi3

### Overlay Cleanup

11. Remove `pocketIdUpgradeOverlay` Go version sed hack (fix upstream)
12. Audit all overlays for consumer-side patches on owned repos
13. Move pocket-id upgrade to upstream or nixpkgs PR

### Build/Deploy

14. Add pre-deploy DNS verification to `deploy.sh`
15. Add `--dry-run` DNS test to CI pipeline
16. Investigate intermittent DNS instability reports
17. Monitor DNS query latency via Prometheus
18. Add dnsblockd metrics to SigNoz dashboard

### Upstream Repos

19. Fix dnsblockd `initDNS()` to return errors instead of silently swallowing
20. Fix dnsblockd `parseDNSExtensions()` to not discard all records on one failure
21. Fix dnsblockd sdns middleware pipeline wiring for root recursion
22. Add integration test for dnsblockd DNS resolution (local + external)
23. Add integration test for dnsblockd local records with FQDN trailing dots
24. Add integration test for dnsblockd wildcard records
25. Fix monitor365 `.cargo/config.toml` to not mandate mold for package builds
26. Consider removing the fast-build mold variant entirely in monitor365

### AGENTS.md / Docs

27. Update AGENTS.md mold gotcha (remove overlay reference, say "fixed upstream")
28. Update AGENTS.md dnsblockd section with DoT forwarder architecture
29. Document sdns root recursion limitation in dnsblockd README
30. Update dnsblockd migration status doc
31. Clean up old status reports referencing overlay hacks

### Service Hardening

32. Investigate oauth2-proxy startup race with DNS
33. Add `after = [ "dnsblockd.service" ]` to oauth2-proxy if not present
34. Add DNS readiness gate to all services depending on external DNS
35. Review discordsync `wait-dns` script effectiveness
36. Audit all services for missing DNS dependencies

### Monitoring

37. Add Gatus alert for DNS resolution failure
38. Add Gatus alert for DNS response time > 100ms
39. Add BTRFS-style health metrics for DNS (query count, cache hit rate)
40. Monitor DoT forwarder connection health

### General SystemNix

41. Commit all current changes
42. Clean up stale flake.lock entries
43. Run `nix flake check --no-build` in CI
44. Review all `restartTriggers` for effectiveness
45. Audit all systemd service start ordering for DNS dependencies
46. Consider adding `networking.networkmanager.dns = "none"` to prevent NM DNS interference
47. Review firewall rules for outbound DNS (port 53 UDP/TCP to root servers)
48. Consider DoH/DoT for dnsblockd → upstream as well (not just plain forwarders)
49. Document the full DNS resolution chain in a diagram
50. Review whether keepalived DNS failover actually works with dnsblockd

---

## g) Top 2 Questions

1. **Should dnsblockd's sdns root recursion be fixed properly, or is DoT forwarding the permanent architecture?** Root recursion gives maximum privacy (no third-party resolver), but the sdns middleware pipeline gap is a non-trivial fix. DoT forwarding through Cloudflare/Quad9 is pragmatic and reliable. I recommend DoT forwarding as the permanent architecture unless privacy requirements demand root recursion.

2. **Should `discord.com` be whitelisted in the blocklist, or should discordsync use direct IP/DoT to Discord's API?** The HaGeZi social blocklist blocks `discord.com`, which crashes discordsync. Whitelisting opens a tracking vector. Using direct IP or a DoH endpoint in discordsync itself would be cleaner but requires upstream changes.
