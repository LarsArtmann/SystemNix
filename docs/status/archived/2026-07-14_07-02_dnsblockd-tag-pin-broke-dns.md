# Status Report: 2026-07-14 07:02 — dnsblockd Tag Pin Broke DNS

## Summary

Gen 516 deploy (`nh os switch`) removed unbound and relied on dnsblockd's "embedded DNS resolver" — but the dnsblockd flake input was pinned to `refs/tags/v0.2.0`, which **predates** the embedded resolver. dnsblockd v0.2.0 only serves HTTP block pages; it silently ignores all `dns_*` config keys. The system lost all DNS resolution on :53, cascading into oauth2-proxy and discordsync failures. User rolled back to gen 515 (with unbound) to restore DNS. The fix changes the flake input from a tag pin to `refs/heads/master`.

---

## a) FULLY DONE

1. **Root cause identified:** dnsblockd flake input was `refs/tags/v0.2.0` (commit `ad14663`). The embedded sdns recursive resolver was added in commits _after_ v0.2.0 tag — it only exists on master. The Nix module (`076dc778` "migrate from unbound to dnsblockd") was written for a feature that doesn't exist in the pinned binary.

2. **Flake input fixed:** Changed `flake.nix` line 137 from `refs/tags/v0.2.0` → `refs/heads/master`. This was the **only** LarsArtmann repo still pinned to a tag — all others already track master.

3. **flake.lock updated:** `nix flake lock --update-input dnsblockd` pulled commit `4fa21f8` (master HEAD, 2026-07-13). Lock diff shows `ad14663` → `4fa21f8` plus new transitive input `git-hooks-nix` (dnsblockd added it on master).

4. **dnsblockd package built from master:** `nix build .#nixosConfigurations.evo-x2.pkgs.dnsblockd` succeeded. Binary includes `internal/dns`, `internal/server` packages with sdns embedded resolver (`github.com/semihalev/sdns`).

5. **Binary verified:** `strings` on the new binary confirms sdns package inclusion (`sdnsCfg`, `IncludesDNS`, `sdns/middleware`, `sdns/server`). Old v0.2.0 binary had none of these.

6. **Flake syntax validated:** `nix flake check --no-build` passes — all NixOS modules eval correctly.

7. **All gen 516 failures diagnosed:**
   - **dnsblockd** (primary): Started fine but only served HTTP block pages — nothing on :53. Logs from 06:21:10 show "HTTP block page server starting" and "stats API server starting" but **zero** DNS resolver log lines (no "DNS server initialized").
   - **oauth2-proxy** (cascade): Exit code 1. Depends on `dnsblockd.service` via `after`/`wants`. Could not resolve `auth.home.lan` (Pocket ID OIDC issuer URL) → OIDC discovery fails → immediate exit.
   - **discordsync** (cascade): Exit code 69. Depends on `dnsblockd.service`. Could not resolve Discord API endpoints or Turso cloud sync host → connection failure → exit.
   - **go-auto-upgrade** (separate build failure, first attempt only): `cmd/go-auto-upgrade/processor.go:286:30: cannot use res (variable of type *migrator.Result) as ...` — compilation error in upstream repo. Fixed itself when `nix flake update` pulled the latest master commit `e21aecd` (the broken commit was `43c01cc`).

8. **Gen 515 confirmed working:** User rolled back via `nixos-rebuild switch --flake .#evo-x2 --sudo --rollback`. `getent hosts google.com` and `getent hosts forgejo.home.lan` both resolve. `/etc/resolv.conf` shows `nameserver 127.0.0.1` + `search home.lan`.

---

## b) PARTIALLY DONE

1. **Deploy not yet attempted with fix.** The flake input change + lock update are staged in the working tree but not deployed. System is on gen 515 (unbound) and will remain so until `nix run .#deploy` is run. The deploy will need to rebuild dnsblockd from master (826 derivations in dry-run, mostly Rust monitor365 deps already cached).

2. **flake.lock has uncommitted changes.** Both `flake.nix` (input URL change) and `flake.lock` (dnsblockd rev update + new transitive input) are modified but not committed. `git status` shows `M flake.lock` (pre-existing from session start) plus our changes.

3. **AGENTS.md not yet updated** with the lesson learned (tag pin → master tracking for LarsArtmann tools).

---

## c) NOT STARTED

1. **Full system deploy** with the fixed dnsblockd input.
2. **Post-deploy verification** that dnsblockd's embedded resolver actually serves DNS on :53 (check logs for "DNS server initialized" line).
3. **Smoke test** that oauth2-proxy and discordsync start successfully with working DNS.
4. **Gatus health check** update — the DNS check may need updating if the endpoint or behavior changed.
5. **Commit** of the flake input fix + lock update.

---

## d) TOTALLY FUCKED UP

1. **Original migration commit `076dc778` shipped without verification.** The commit "feat(dns): migrate from unbound to dnsblockd as sole DNS resolver" removed unbound and configured dnsblockd as the sole resolver — but the binary being pulled (v0.2.0) didn't have the resolver. This is a **test failure**: no one verified that `dnsblockd serve` actually starts a DNS listener before shipping the migration. The Nix module generates the right config YAML with `dns_enabled: true`, but dnsblockd v0.2.0 silently ignores unknown config keys.

2. **dnsblockd's overlay/package on v0.2.0 should have failed loudly.** The v0.2.0 `ServeConfig` struct doesn't have `DNSConfig` embedded — the `dns_*` YAML keys are silently dropped by koanf. There's no validation that says "you set `dns_enabled: true` but this binary doesn't support DNS." This is an upstream issue.

3. **Tag pin was stale by 20+ commits.** v0.2.0 was tagged on `ad14663` (2026-07-02). Master HEAD is `4fa21f8` (2026-07-13). Eleven days of development including the entire embedded resolver feature shipped without the flake picking it up.

---

## e) WHAT WE SHOULD IMPROVE

1. **No LarsArtmann tool repos should be pinned to tags.** They're all private/internal tools under active development. Pinning to a tag means the flake silently uses a stale version. All should use `refs/heads/master` (which is what every other LarsArtmann input already does — dnsblockd was the sole exception).

2. **Post-build binary capability assertion.** The Nix module assumes the binary supports features based on config keys. We should add a post-build check (or integration test) that verifies the binary actually starts the DNS resolver when `dns_enabled = true`. For example: run `dnsblockd serve` with a test config in a Nix build checkPhase and grep for "DNS server initialized" in stdout.

3. **Deploy should DNS smoke-test before declaring success.** The `pre-deploy-check` script checks for boot hazards but doesn't test functional DNS. A post-deploy smoke test that runs `getent hosts google.com` and `getent hosts auth.home.lan` would have caught this immediately.

4. **The `nix flake update` that fixed go-auto-upgrade was accidental.** The user ran `nix flake update -v && nh os switch` as a retry, which pulled latest master for go-auto-upgrade (fixing the compile error). But this also pulled updates for buildflow, cmdguard, homebrew-cask, and nur — unrelated changes mixed into the fix. The lock file now has changes from multiple concerns.

5. **AGENTS.md should document this lesson.** Add to the gotchas table: "dnsblockd flake input must track master, not tags — the embedded resolver was never tagged."

---

## f) Up to 50 Things We Should Get Done Next

### Immediate (blocks deploy)

1. Commit the flake input fix (`refs/tags/v0.2.0` → `refs/heads/master`) + lock update
2. Deploy gen 517 with `nix run .#deploy`
3. Verify dnsblockd logs show "DNS server initialized (embedded recursive resolver)" after deploy
4. Verify `getent hosts google.com` resolves via dnsblockd (not unbound)
5. Verify `getent hosts auth.home.lan` resolves to server IP
6. Verify oauth2-proxy starts successfully (exit code 0)
7. Verify discordsync starts successfully (exit code 0)
8. Run `nix run .#post-deploy-check` to verify all services functional
9. Check Gatus dashboard for DNS-related health checks passing

### Short-term (hardening)

10. Add DNS smoke test to `post-deploy-check` script: `getent hosts google.com && getent hosts auth.home.lan`
11. Update AGENTS.md gotchas table with dnsblockd tag pin lesson
12. Add `dnsblockd` to AGENTS.md GOPRIVATE/overlay section noting it must track master
13. Audit all flake inputs for any remaining tag pins on actively-developed repos (SigNoz tags OK — upstream versioned releases)
14. Clean up the stale `result` symlink in project root (points to old drv)
15. Update `docs/status/2026-07-13_21-48_dnsblockd-dns-migration-status.md` with a "post-mortem" note about the v0.2.0 tag pin issue
16. Verify rpi3-dns still works (it also uses dnsblockd — does it have the same pin?)
17. Check if the `dns_local_records` wildcard `"*.home.lan."` is handled correctly by sdns (different from Unbound's local-zone)

### Medium-term (prevention)

18. Add a NixOS test that boots with dnsblockd enabled and verifies :53 responds to queries
19. Add upstream validation to dnsblockd: if `dns_enabled: true` but the binary doesn't have sdns compiled in, fail with a clear error (not silent ignore)
20. Add `nix flake check` that asserts no LarsArtmann private repos are pinned to tags
21. Consider adding a pre-commit hook that warns when a flake input URL contains `refs/tags/`
22. Review whether `dns-failover.nix` keepalived health check (`chk_dns`) works correctly with dnsblockd's embedded resolver
23. Review whether dnsblockd's `::` dual-stack default listen address conflicts with anything
24. Monitor dnsblockd memory usage under load — sdns recursive resolver is heavier than the old HTTP-only mode
25. Verify DNSSEC validation works end-to-end (dig +dnssec for a signed domain)

### Cluster / rpi3

26. Verify rpi3-dns dnsblockd input also tracks master (not tags)
27. Test VRRP failover between evo-x2 and rpi3-dns with dnsblockd embedded resolver
28. Update rpi3-dns config if it has different dnsblockd config requirements

### Monitoring

29. Add Gatus check for dnsblockd stats API (`127.0.0.1:9090`) health
30. Add Prometheus alert for dnsblockd DNS query rate dropping to zero
31. Verify sdns cache metrics (`dns_cache_hits`, `dns_cache_misses`) are scraped
32. Update Homepage dashboard DNS widget to show resolver stats (not just block stats)
33. Add Gatus DNS check: query `auth.home.lan` via `dig @127.0.0.1` and assert response

### Documentation

34. Update AGENTS.md with dnsblockd embedded resolver architecture notes
35. Document the sdns config keys that dnsblockd supports (reference upstream dnsblockd docs)
36. Update `platforms/common/dns-resolver.nix` comments to reflect embedded resolver
37. Add `docs/services/dnsblockd.md` with config reference and troubleshooting
38. Update TODO_LIST.md with completed/pending DNS migration items

### Cleanup

39. Remove the old `unbound.conf` references from any remaining test files
40. Clean up the `tests/default.nix` that had unbound-specific test cases removed in `076dc778`
41. Verify no orphaned sops secrets for unbound remain
42. Check if `dnsblockd-cert-trust.nix` needs updates for the new binary version
43. Review if the `process` subcommand deprecation in dnsblockd master affects the build-time `mapping.json` generation
44. Verify the `art-dupl` fork pin (`ref=fork`) is still necessary or if upstream has merged the changes
45. Review whether `hermes-agent` tag pin (`v2026.6.5`) is appropriate (upstream versioned release vs internal tool)

### Operational

46. Document the recovery procedure: `nixos-rebuild switch --flake .#evo-x2 --sudo --rollback` for gen rollback
47. Add a note about `switch-to-configuration test` exit code 4 → run `systemctl reset-failed` (already in AGENTS.md but reinforce)
48. Consider adding a DNS failover to a public resolver (e.g. 9.9.9.9) as a secondary in `/etc/resolv.conf` for resilience
49. Review the `nh os switch` vs `nix run .#deploy` workflow — the `deploy.sh` script has pre-deploy checks that plain `nh` skips
50. Schedule a review of all flake input URLs for tag vs branch consistency

---

## g) Top 2 Questions

### Q1: Should we deploy right now (gen 517), or investigate further first?

The fix is minimal (1-line input URL change + lock update), the package builds, and `nix flake check --no-build` passes. But the original migration commit `076dc778` shipped without testing, and we're now trusting that master HEAD `4fa21f8` has a working embedded resolver based on source code inspection (`internal/dns/` package exists) and binary `strings` output (sdns symbols present). **We have NOT actually tested that the resolver binds :53 and answers queries.** Should we:

- (a) Deploy and verify via logs + `getent`, rolling back if it fails, OR
- (b) Build a local test first (run dnsblockd with the generated config in a tmpdir and query it)?

### Q2: The `nix flake update` pulled unrelated changes (buildflow `abf5cdf`, cmdguard `1e1deed`, homebrew-cask, nur) into flake.lock alongside the dnsblockd fix. Should we isolate?

The user ran `nix flake update -v` as part of their retry, which updated ALL inputs. The lock file now contains changes from multiple concerns mixed together. Options:

- (a) Commit as-is (the unrelated updates are benign — buildflow/cmdguard are master HEAD updates that already built successfully on gen 516's second attempt)
- (b) Try to isolate only the dnsblockd change (would require manually reverting the other lock entries — messy and low-value)

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
