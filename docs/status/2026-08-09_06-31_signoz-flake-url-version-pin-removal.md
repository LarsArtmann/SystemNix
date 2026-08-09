# Status Report: SigNoz Flake URL Version Pin Removal

**Date:** 2026-08-09 06:31
**Session Scope:** Audit all flake.nix inputs for hardcoded version pins, convert to latest-default-branch tracking
**Verdict:** Mission accomplished — all 61 inputs now defer versioning to `flake.lock`

---

## What Was Done

### Audit Finding

Audited all **61 flake input URLs** in `flake.nix`. Found exactly **2 inputs** with hardcoded version tags:

| Input | Before | After |
|---|---|---|
| `signoz-src` | `github:SigNoz/signoz/v0.127.1` | `github:SigNoz/signoz` |
| `signoz-collector-src` | `github:SigNoz/signoz-otel-collector/v0.144.5` | `github:SigNoz/signoz-otel-collector` |

The remaining **59 inputs already correctly defer** to `flake.lock` (branch refs like `?ref=master`, `/stable`, `/nixos-unstable`, or default branch). No commit-hash pins, no `?ref=v*` tags anywhere else.

### Changes Made

| File | Lines | Change |
|---|---|---|
| `flake.nix` | 108-115 | Dropped `/v0.127.1` and `/v0.144.5` version tags from both SigNoz URLs |
| `_signoz-packages.nix` | 9-10 | Hardcoded semver → `inputs.signoz-src.shortRev or "latest"` / `inputs.signoz-collector-src.shortRev or "latest"` |
| `_signoz-packages.nix` | 19 | `collectorVendorHash` recomputed: `sha256-41K2izMlUTpYrIXW+1rpy4F/yosSMQvvbO/EpOwQJvE=` |
| `_signoz-packages.nix` | 52 | `vendorHash` (signoz) recomputed: `sha256-wl12FQS11YWdE6Gd0zjTlAuCGcuz5DqLnwHJ/pSMsqA=` |
| `flake.lock` | signoz-src node | Updated to commit `40aa322` (latest main, 2026-08-05) |
| `flake.lock` | signoz-collector-src node | Updated to commit `75a995d` (latest main, 2026-08-02) |

### Verification Performed

| Check | Result |
|---|---|
| `nix build .#signoz .#signoz-otel-collector .#signoz-schema-migrator` | EXIT=0 — all 3 binaries built (113 MB, 323 MB, 10 MB) |
| `nix flake check --no-build` | EXIT=0 — "all checks passed!" |
| Store path versioning | `signoz-40aa322`, `signoz-otel-collector-75a995d` — confirms `shortRev` derivation works on `flake = false` inputs |
| Binary sanity | All 3 binaries present in `/bin/` with expected names |

---

## a) FULLY DONE

1. **Flake URL audit** — All 61 inputs scanned, 2 version pins identified, 59 confirmed clean
2. **URL conversion** — Both SigNoz inputs now track default branch (no version tag in URL)
3. **Version derivation** — `shortRev or "latest"` replaces hardcoded semver in both `version` and `collectorVersion`
4. **Vendor hash recompute** — Both hashes (`vendorHash` + `collectorVendorHash`) recomputed against latest main
5. **flake.lock update** — Both SigNoz nodes updated to latest commits
6. **Package build verification** — All 3 packages (`signoz`, `signoz-otel-collector`, `signoz-schema-migrator`) built from source successfully
7. **Eval check** — `nix flake check --no-build` passes

## b) PARTIALLY DONE

1. **AGENTS.md update** — NOT done. The SigNoz section in AGENTS.md does not mention version pinning strategy. Should document that SigNoz now tracks latest main + the vendorHash recompute procedure
2. **Full system eval** — `nix flake check` passes (module-level), but `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` (full system config eval) was NOT run
3. **Alerting API compatibility** — `_signoz-alerts.nix` was written for SigNoz v0.127.1's "v5" alerting API. Newer `main` may have changed it again. NOT verified

## c) NOT STARTED

1. **Deploy** — No deploy was performed. Changes are in the working tree only
2. **ClickHouse backup** — No backup taken before migration. The schema migrator runs on startup
3. **Service startup test** — Binaries build but no test that services start and function with new code
4. **Post-deploy checks** — `scripts/post-deploy-check.sh` not run (no deploy happened)
5. **Pre-deploy checks** — `scripts/pre-deploy-check.sh` not run

## d) TOTALLY FUCKED UP

1. **Vendor hash transcription error** — Initially captured `sha256-...pSMmqA=` (wrong, `mqA`) but the real hash was `sha256-...pSMsqA=` (correct, `sqA`). This was a sloppy copy-paste from the build error output. Cost one extra full build cycle (~3 min). Process was correct (fakeHash → capture `got:` → paste), execution was sloppy
2. **Used deprecated `--update-input` flag** — `nix flake lock --update-input` is deprecated. Should use `nix flake update signoz-src signoz-collector-src`. Functioned correctly but emitted warnings

## e) WHAT WE SHOULD IMPROVE

1. **AGENTS.md needs updating** — Document the SigNoz version-tracking change and the vendorHash recompute procedure (set to `lib.fakeHash`, build, paste `got:` hash)
2. **Missing full-system eval verification** — `nix flake check --no-build` checks individual modules but doesn't guarantee the full `nixosConfigurations.evo-x2` evaluates. Should add `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel --no-build` as a verification step
3. **No CI guard for version-tagged inputs** — There is no automated check that prevents someone from re-adding `/v0.127.1` style tags to `flake.nix`. A grep-based pre-commit hook or flake check would enforce the "flake.lock is the sole version authority" policy
4. **Alerting API drift risk** — `_signoz-alerts.nix` hardcodes the v5 alerting schema that was specific to v0.127.1. Tracking unreleased `main` means this could silently break on any upstream API change. Needs a runtime alert-provisioning smoke test
5. **No SigNoz changelog review** — Upgrading from v0.127.1 to unreleased main is an unknown delta. Breaking changes (config schema, ClickHouse migrations, API endpoints) are possible. A changelog/release-notes review should precede deploy

## f) Next Steps (Up to 50)

### Immediate (Before Deploy)

1. Run `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` to verify full system eval
2. Take a ClickHouse backup: `clickhouse-client -q "BACKUP DATABASE signoz TO Disk('backups', 'pre-signoz-main-upgrade.zip')"`
3. Review SigNoz changelog between v0.127.1 and current main (`40aa322`) for breaking changes
4. Review SigNoz collector changelog between v0.144.5 and current main (`75a995d`)
5. Check if `_signoz-alerts.nix` v5 API format is still valid in latest main
6. Check if `signoz.yaml` / `collector.yaml` config schema changed
7. Run `scripts/pre-deploy-check.sh` before deploying
8. Deploy: `nix run .#deploy`
9. Watch schema migrator logs: `journalctl -u signoz-schema-migration -f`
10. Run `scripts/post-deploy-check.sh` after deploy
11. Verify SigNoz UI loads and shows data
12. Verify alert rules are still provisioned

### Documentation

13. Update AGENTS.md SigNoz section: note that version now tracks latest main via `shortRev`
14. Add vendorHash recompute procedure to AGENTS.md (fakeHash → build → paste `got:`)
15. Add note about ClickHouse backup before SigNoz upgrades
16. Update `_signoz-packages.nix` header comment to explain the `shortRev` version derivation
17. Consider adding a "flake input version policy" section to AGENTS.md

### CI / Automation

18. Add pre-commit grep guard: reject `github:.*/v[0-9]+\.[0-9]` patterns in `flake.nix` (enforces "no version tags in URLs")
19. Add CI check: `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel --no-build` on every PR
20. Add a SigNoz alert-provisioning smoke test to post-deploy-check.sh
21. Consider a `nix flake update signoz-src signoz-collector-src` scheduled job (monthly?) to stay on latest main

### Broader Flake Hygiene

22. Audit `follows` chains — verify all `follows` are still correct (no orphaned follows pointing to removed inputs)
23. Check for unused flake inputs (inputs declared but never consumed in any .nix file)
24. Consider consolidating the `flake = false` Go library tarballs (go-finding, go-output, etc.) into a single attrset
25. Review `art-dupl?ref=fork` — is the `fork` branch still maintained? Should it track `main` instead?
26. Review `go-humanize-linter?ref=main` — all other LarsArtmann repos use `ref=master`; is this intentional?
27. Consider adding `nix flake update --flake .` (update ALL inputs) on a schedule to avoid lockfile staleness
28. Review whether `nix-homebrew` and `homebrew-bundle`/`homebrew-cask` inputs are still needed on NixOS (darwin-only)

### SigNoz-Specific

29. Test the alert provisioner against latest main API
30. Verify dashboards still render correctly in the UI
31. Check if new SigNoz main has native OIDC support now (was Enterprise-only — maybe it's open now)
32. Check memory/CPU usage of new binaries vs old (regression check)
33. Verify OTel collector still exports metrics/traces/logs correctly
34. Check if the schema migrator introduces new ClickHouse tables or columns
35. Verify the `signoz` service starts within the systemd timeout (3 min default)
36. Test Gatus health check still passes after upgrade
37. Check if the SigNoz vHost Caddy config needs updates for new API paths

### General System Health

38. Run `nix flake check --no-build` one more time after AGENTS.md updates
39. Commit all changes with a clear message
40. Verify no other services are affected by the flake.lock changes
41. Check `nix flake metadata` for any inputs with stale lastModified dates
42. Review duplicate nixpkgs instances (should be zero with all the `follows`)
43. Consider adding `nix flake show` output to CI for diff visibility
44. Review the `herdr` input — is it still used?
45. Review the `hermes-agent` input — is it consumed?
46. Check if `otel-tui` is still needed (was it a one-time investigation tool?)
47. Audit `nix-amd-npu` — is the XDNA driver stable enough to track latest?
48. Consider whether `silent-sddm` should track a release branch instead of default
49. Review `nixos-hardware` — any stale profiles for removed hardware?
50. Run `nix flake archive` to verify all inputs are cacheable

## g) Questions (Cannot Figure Out Myself)

### Q1: Should I deploy this SigNoz main-tracking change now, or wait?

The packages build and eval passes, but the upgrade from v0.127.1 to unreleased main is an unknown delta. SigNoz runs ClickHouse schema migrations at startup (`signoz-schema-migration.service`). If a migration is irreversible or data-corrupting, rolling back requires restoring ClickHouse from backup. I cannot assess the migration risk without reviewing the SigNoz changelog, which I have not done. Should I:
- (a) Deploy now and watch closely, or
- (b) Review the changelog first, take a ClickHouse backup, then deploy?

### Q2: Should `_signoz-alerts.nix` be re-verified before deploy?

The alert rules were written for SigNoz v0.127.1's "v5" alerting API format (flat schema with `condition.compositeQuery`, `preferredChannels`, `ruleType: promql_rule`). If latest main changed the API again, the provisioner will fail loudly (the `|| true` swallowing was already fixed in a prior session). I cannot test the API format without deploying. Should I review the SigNoz source for API changes before deploying, or trust that the provisioner will fail loud enough to catch regressions?

### Q3: Is the `go-humanize-linter?ref=main` branch ref intentional?

All other LarsArtmann repos use `ref=master`. Only `go-humanize-linter` uses `ref=main`. This could be intentional (the repo's default branch is `main`) or an oversight. I cannot verify without checking the repo's branch settings on GitHub. Should it be normalized to `master` for consistency, or is `main` correct for this repo?

---

## Self-Assessment

**What went well:** Thorough audit before acting. Correct identification of the only 2 problem inputs. Clean conversion with build verification.

**What was sloppy:** The vendor hash transcription error (`mqA` vs `sqA`) was a careless copy-paste that cost a full rebuild cycle. Should have copied directly from the error output character-by-character.

**What was missed:** No full-system eval verification. No ClickHouse backup recommendation before the migration risk was accepted. No changelog review. The "convert and verify" choice was executed literally (packages build) but the production deployment risk (schema migrations on live data) was only mentioned, not mitigated.

**Quality bar:** The code change itself is clean and correct. The process gaps are in verification depth (module-level eval vs full-system eval) and production safety (migration risk assessment).
