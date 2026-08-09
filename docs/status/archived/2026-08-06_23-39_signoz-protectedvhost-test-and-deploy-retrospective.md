# Status Report: SigNoz protectedVHost — Test, Deploy & Retrospective

**Date:** 2026-08-06 23:39
**Session scope:** Re-run the Caddy auth VM test, fix failures, format, deploy, verify, then brutally self-review
**Previous report:** `docs/status/2026-08-06_22-54_signoz-protectedvhost-and-caddy-test.md`

---


## What This Session Actually Did

1. Re-ran the VM test after the `--adapter caddyfile` fix from the previous session
2. **Test FAILED** on assertion #4 — `curl http://localhost:8082/` returned empty body
3. **Root cause:** `localhost` resolves to `::1` (IPv6 loopback), which is NOT in `127.0.0.1/8`, so Caddy's `@external` matcher treated local requests as external → forward_auth kicked in → 401 redirect → empty body
4. **Fix:** Changed all test curls from `localhost` → `127.0.0.1`
5. **Test PASSED** — all 6 assertions green
6. Ran `nix fmt` — reformatted `mockBackend` lambda indentation (1 file changed)
7. Ran `nix flake check --no-build` — all checks passed
8. Re-ran VM test post-formatting — still passes (exit 0)
9. Deployed via `nix run .#deploy` — 31/31 smoke tests pass, 0 failures
10. Verified deployed Caddy config — confirmed `@external` matcher + conditional `forward_auth` + bare `handle` LAN bypass
11. Verified SigNoz reachable via LAN — returns SvelteKit SPA HTML

---

## a) FULLY DONE

| Item | Evidence |
|---|---|
| SigNoz switched to `protectedVHost` | Deployed Caddy config shows `@external` + conditional forward_auth + bare handle LAN bypass |
| Caddy auth VM test (`tests/test-caddy-auth.nix`) | 6/6 assertions pass, registered in `tests/default.nix` |
| `--adapter caddyfile` fix | Caddy starts cleanly, parses Caddyfile syntax |
| IPv6 loopback fix (`127.0.0.1` not `localhost`) | All test curls use explicit IPv4 |
| `nix fmt` | 1 file reformatted (mockBackend lambda) |
| `nix flake check --no-build` | All checks passed |
| Deploy | 31/31 smoke tests pass |
| SigNoz LAN access verified | `fetch` returns SvelteKit SPA HTML |
| Post-deploy smoke test | SigNoz impersonation mode active, 20 alert rules provisioned, all vHost checks pass |
| AGENTS.md updated | SSO table, gotchas, callouts all reflect Layer 2 protectedVHost |
| signoz.nix comments updated | Header + impersonation script comments describe Layer 2 |

## b) PARTIALLY DONE

| Item | Status | What remains |
|---|---|---|
| **Gatus health check for SigNoz post-deploy** | Gatus was passing BEFORE deploy (probes from 127.0.0.1 which hits LAN bypass). Post-deploy Gatus status was NOT explicitly checked. The smoke test checks SigNoz impersonation mode and alert rules, but does not query Gatus for the SigNoz endpoint health status. | Verify `journalctl -u gatus` or Gatus UI shows SigNoz as healthy |
| **External access verification** | The protectedVHost pattern means external clients should hit oauth2-proxy forward-auth. This was NOT tested — no way to test from inside the LAN without simulating an external IP. | Only verifiable from outside the LAN or with a crafted request that spoofs `X-Forwarded-For` (but Caddy uses `remote_ip` not XFF, so this is hard to test) |

## c) NOT STARTED

| Item | Why it matters |
|---|---|
| **External forward-auth path test** | The VM test verifies the LAN bypass works, but does NOT verify that external requests are correctly forwarded to oauth2-proxy and redirected on 401. The mock oauth2-proxy returns 401, but no test sends a request with a non-LAN source IP to verify the redirect. This is a gap in the test coverage. |
| **SigNoz SSE/streaming through protectedVHost** | SigNoz uses SSE for live log tailing. Caddy's reverse_proxy handles SSE by default, but `protectedVHost` adds `forward_auth` for external requests. SSE + forward_auth could have issues (auth check on long-lived connection). Not tested. LAN bypass means SSE works for LAN users regardless. |
| **Gatus config update for SigNoz** | The Gatus health check for SigNoz was NOT reviewed. If it was previously probing through the unconditional forward-auth path (which returned 500), it may have been configured with `[STATUS] < 400` or similar workaround. Post-protectedVHost, Gatus probes from localhost → LAN bypass → direct access → should work cleanly. But the Gatus config was not inspected to confirm. |
| **Commit message quality on empty commit** | Commit `ab6b346c` has an EMPTY message — it contains the caddy.nix + signoz.nix protectedVHost changes. The auto-git daemon committed it without a message. This is a git history quality issue. |

## d) TOTALLY FUCKED UP

| Item | What went wrong | Impact |
|---|---|---|
| **Empty commit message (`ab6b346c`)** | The auto-git daemon committed the caddy.nix protectedVHost change with an empty commit message. This is unprofessional and makes git history harder to navigate. | Low technical impact, high hygiene impact. Can't be fixed without history rewrite (which is banned by project rules — never `git reset`). |
| **Previous session's wrong approach (`edc653d4`)** | The previous session switched SigNoz to a completely open no-auth plain proxy. This left SigNoz (running in root-admin impersonation mode) with zero auth protection if port 443 was forwarded. This session corrected it to `protectedVHost`, but the bad commit is still in history and WAS deployed. | The window of exposure was real but short (hours). If port 443 is not forwarded to the internet (LAN-only), impact was zero. But the approach was wrong — should have been `protectedVHost` from the start. |
| **Two test iterations needed for basic issues** | The `--adapter caddyfile` flag and the `localhost` → `127.0.0.1` issue are both basic Caddy/networking fundamentals. A more careful initial test would have caught both on the first run. | Wasted build cycles. Each VM test build takes ~30-60s. Two unnecessary iterations. |

## e) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Test first-run quality** — The VM test had two basic issues that should have been caught during code review before the first build: (a) missing `--adapter caddyfile` is documented in Caddy's own docs, (b) IPv6 `localhost` resolution is a well-known testing gotcha. Take more time to review test code before building.

2. **External auth path is untested** — The VM test only verifies the LAN bypass. The WHOLE POINT of `protectedVHost` is that external requests get forward-auth. This path is not tested at all. We should add a test node with a non-LAN IP (e.g., `10.5.5.5`) that sends requests to the Caddy node and verifies the 401 redirect. This would require a two-node VM test.

3. **Gatus config not reviewed** — When changing a service's Caddy vHost pattern, the Gatus health check should be reviewed to ensure it still makes sense. This was not done for SigNoz.

4. **Empty commit messages** — The auto-git daemon produced an empty commit message. Consider adding a pre-commit hook or git config that rejects empty messages, or improve the daemon's commit message generation.

5. **Deploy verification is shallow** — The post-deploy smoke test checks SigNoz impersonation mode and alert rules, but does NOT explicitly check that the Caddy vHost pattern is correct in the deployed config. The manual `cat /run/current-system/etc/caddy/caddy_config` I did should be part of the automated smoke test.

### Technical Improvements

6. **SSE through forward_auth** — If external users use SigNoz's live log tailing (SSE), the forward_auth check happens on the initial request but the long-lived SSE connection stays open. If the oauth2-proxy session expires during an SSE connection, the stream is NOT interrupted. This is a known oauth2-proxy limitation. For LAN users (the primary use case), SSE goes through the bare `handle` block — no issue.

7. **The test should replicate `lanSubnet` from production** — The test hardcodes `192.168.1.0/24` as the LAN subnet, matching production. But if `networking.local.subnet` ever changes, the test won't catch it. Consider parameterizing.

8. **`protectedVHost` first argument (`_subdomain`) is unused** — The helper takes a subdomain argument but ignores it (prefixed with `_`). It's only there for documentation/readability. This is fine but worth noting — if someone tries to use it for logic, it won't work.

---

## f) Up to 50 Things We Should Get Done Next

### High Priority (SigNoz / Auth)

1. **Add a two-node VM test** for the external forward-auth path — second node with non-LAN IP verifies 401 redirect
2. **Review Gatus config for SigNoz** — ensure health check uses correct endpoint and expected status code post-protectedVHost
3. **Verify SigNoz SSE (live log tailing) works through the LAN bypass path** — connect from a LAN browser and start a live tail
4. **Add Caddy config assertion to post-deploy smoke test** — verify deployed vHost has `@external` matcher + conditional `forward_auth` (not unconditional)
5. **Test external access to SigNoz** — from outside the LAN (or simulate) verify oauth2-proxy redirect works

### Medium Priority (Test Infrastructure)

6. **Extract mock backend/oauth2-proxy helpers into `test-helpers.nix`** — the Python mock servers are reusable across tests
7. **Add a test for the `proxyTo` pattern** — currently only plain proxy access is tested, not header injection (`X-Real-IP`)
8. **Add a test for TLS config** — verify `tlsConfig` enforces TLS 1.2+ (currently untested)
9. **Add a test for `commonConfig` security headers** — verify HSTS, X-Content-Type-Options, etc. are present
10. **Run all VM tests in CI** — currently `nix flake check --no-build` skips VM tests (they need `--all-systems` or explicit build)

### Medium Priority (SigNoz)

11. **Review SigNoz OTLP endpoint configuration** — is `OTEL_EXPORTER_OTLP_ENDPOINT` set correctly for the query service?
12. **Check SigNoz retention settings** — data retention may need tuning for the 128GB RAM / NVMe storage
13. **Verify SigNoz alert rules are actually firing** — 20 rules provisioned, but are any triggering?
14. **Review SigNoz resource limits** — `MemoryMax` and `CPUQuota` may need adjustment for the workload
15. **Set up SigNoz backup** — add SigNoz data directory to `backup-coordination` module if not already

### Medium Priority (Monitoring)

16. **Add Gatus alert for Caddy config drift** — detect if deployed Caddy config doesn't match expected pattern
17. **Add Gatus alert for oauth2-proxy health from Caddy's perspective** — Caddy depends on oauth2-proxy for external auth
18. **Review all Gatus health check endpoints** — ensure they probe the right paths post-protectedVHost migration
19. **Add monitoring for SigNoz query latency** — slow queries could indicate ClickHouse issues
20. **Review EMEET PIXY monitoring** — the session-aware gate (`e6fd2213`) was added this session, verify it works

### Medium Priority (Caddy / Auth)

21. **Document the `protectedVHost` pattern in a service module template** — make it easy for future services to pick the right auth pattern
22. **Review all services using `protectedVHost`** — ensure they all actually need Layer 2 (some might support native OIDC)
23. **Add a lint check for unconditional `forward_auth`** — a static analysis that scans caddy.nix for `forward_auth` outside a `handle @external` block
24. **Review oauth2-proxy session timeout** — ensure it's reasonable for the services behind it
25. **Consider SSO logout flow** — currently partial; document what works and what doesn't

### Lower Priority (Code Quality)

26. **Clean up commit history** — the empty-message commit `ab6b346c` is ugly; consider a future squash (requires coordination)
27. **Review `tests/test-oauth2-proxy.nix`** — it's disabled; either fix it or remove it
28. **Add `statix` linting to CI** — catch Nix anti-patterns automatically
29. **Review all `_`-prefixed helper files in modules/** — ensure they're still needed
30. **Document the Caddy adapter format requirement** — add to AGENTS.md gotchas (Caddyfile needs `--adapter caddyfile` with `caddy run`)

### Lower Priority (Documentation)

31. **Update `docs/status/2026-08-06_22-54_signoz-protectedvhost-and-caddy-test.md`** — mark it as superseded by this report
32. **Update `docs/status/2026-08-06_22-34_signoz-no-auth-mode-brutal-self-review.md`** — mark the no-auth approach as corrected
33. **Add architecture decision record (ADR) for SigNoz auth pattern** — document why protectedVHost was chosen over no-auth and unconditional forward-auth
34. **Review and consolidate status reports** — there are 9 status reports for 2026-08-06 alone; some may be redundant
35. **Update FEATURES.md** — if it exists, ensure SigNoz auth pattern is documented

### Lower Priority (Security)

36. **Audit which services are exposed externally** — verify only intended services have port 443 access
37. **Review firewall rules** — confirm `eno1` trusted interface is correct and sufficient
38. **Check if port 443 is actually forwarded** — if not, external auth is moot (but still good defense-in-depth)
39. **Review SigNoz ClickHouse credentials** — are they rotated? Are they in sops?
40. **Audit all DynamicUser services** — ensure none are missing auth boundaries they need

### Backlog (Nice to Have)

41. **Add a Caddy config integration test** — load the ACTUAL SystemNix caddy.nix module (not a mock Caddyfile) and verify the generated config
42. **Test oauth2-proxy + Pocket ID end-to-end in a VM** — full OIDC flow, not just mock 401
43. **Add a test for the `@external` matcher with `X-Forwarded-For`** — verify Caddy uses `remote_ip` not XFF for the matcher
44. **Benchmark Caddy with forward_auth** — measure latency overhead of the auth check on external requests
45. **Review ClickHouse storage usage** — SigNoz can consume significant disk; ensure it's not filling up
46. **Add SigNoz to the backup coordination module** — if ClickHouse data is important, it needs backup
47. **Review SigNoz version upgrade path** — v0.127.1, check if newer versions have breaking changes
48. **Consider migrating SigNoz to native OIDC** — if CE ever adds OIDC support, switch from Layer 2 to Layer 1
49. **Review all Layer 2 services for SSE compatibility** — any service using SSE/websockets behind forward_auth may have session expiry issues
50. **Add a pre-deploy diff check** — show what Caddy vHost changes will be applied before deploying

---

## g) Questions I Cannot Answer Myself

### 1. Is port 443 actually forwarded from the router to evo-x2?

This determines whether the external forward-auth path is even reachable. If the router does NOT forward 443, then all services are LAN-only and the external auth boundary is defense-in-depth only. I cannot check router config from the server. This affects how much effort we should put into testing the external auth path.

### 2. Should the empty-message commit `ab6b346c` be fixed via interactive rebase, or left as-is?

Project rules say "NEVER `git reset`" and the auto-git daemon committed it. An interactive rebase to reword would technically modify history. The commit is already deployed and local-only (not pushed). What's the preferred action — leave it, or reword it before pushing?

### 3. Does anyone actually access SigNoz from outside the LAN?

If SigNoz is only ever used from inside the LAN, the external forward-auth path is unnecessary complexity. In that case, we might consider a plain proxy (like Forgejo/Gatus) with firewall-only protection, simplifying the setup. But this depends on usage patterns I can't observe.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md [Unreleased].**
> All forward-looking items in this report were completed in subsequent sessions.
