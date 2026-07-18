# SystemNix — Comprehensive Status Report

**Date:** 2026-05-04 17:10
**Session:** 23 — Build Fix Sprint
**Branch:** master
**Build Status:** PASSING (nh os build .)

---

## Session Summary

Fixed all build failures in `nh os build .` — three independent categories of issues resolved.

---

## A) FULLY DONE

### 1. Hermes-TUI npmDepsHash Override (Root Cause: Upstream Stale Hash)

**Problem:** `github:NousResearch/hermes-agent` at commit `54e78cad` has a stale `npmDepsHash` in `nix/tui.nix`. The `package-lock.json` in `ui-tui/` changed (nanostores dependency diff + peer flag), but the hash `sha256-a/HGI9OgVcTnZrMXA7xFMGnFoVxyHe95fulVz+WNYB0=` was never updated.

**Solution:** Instead of patching the upstream flake (which we can't — it's a third-party repo), we use the hermes-agent's overlay with a `callPackage` interception pattern in `modules/nixos/services/hermes.nix`:

- Apply the upstream overlay via `pkgs.extend`
- Extract `hermesTui` from `passthru` and override its `npmDeps` with the correct hash (`sha256-tmKv51gGIHzfT6HqB3zR3mrRIfkmngrW1ad3Gg6n2aE=`)
- Intercept `callPackage` inside `hermes-agent.nix` so that `callPackage ./tui.nix` returns the fixed tui instead of the broken one
- The intercepted agent rebuilds using the fixed tui while everything else (web, python venv, etc.) uses the normal overlay path

**Correct hash obtained via:** `nix run nixpkgs#prefetch-npm-deps -- /nix/store/.../ui-tui/package-lock.json`

**Key learning:** `overrideAttrs` on a derivation does NOT remove it from the build closure if the original derivation was already evaluated as a build-time dependency. The `callPackage` interception pattern is the correct approach for overriding sub-dependencies in a flake's overlay.

**Files changed:** `modules/nixos/services/hermes.nix`

### 2. DNS Blocklist Hash Updates (10 Blocklists)

HaGeZi DNS blocklists update their content frequently (they're live blocklists from `hagezi/dns-blocklists` GitHub repo). 10 of 25 blocklists had stale hashes:

| Blocklist               | Status  |
| ----------------------- | ------- |
| HaGeZi-ultimate         | Updated |
| HaGeZi-tif              | Updated |
| HaGeZi-doh              | Updated |
| HaGeZi-bypass-full      | Updated |
| HaGeZi-native-winoffice | Updated |
| HaGeZi-gambling         | Updated |
| HaGeZi-nsfw             | Updated |
| HaGeZi-anti-piracy      | Updated |
| HaGeZi-dyndns           | Updated |
| HaGeZi-urlshortener     | Updated |
| HaGeZi-dga7             | Updated |

**Files changed:** `platforms/shared/dns-blocklists.nix`

### 3. golangci-lint-auto-configure vendorHash Update

The `golangci-lint-auto-configure` package source (`golangci-lint-auto-configure-src` flake input) was updated upstream, causing the Go module vendor hash to change.

**Files changed:** `pkgs/golangci-lint-auto-configure.nix`

### 4. Flake Lock Updates

Automatic lock file updates for: dnsblockd (a0b1879 → f587a72), homebrew-cask, NUR, silent-sddm.

**Files changed:** `flake.lock`

---

## B) PARTIALLY DONE

None — all identified build failures were fully resolved.

---

## C) NOT STARTED

### From MASTER_TODO_PLAN.md (65% → ~66% after this session)

**P5 — DEPLOYMENT & VERIFICATION (0/13, 0%)** — All require evo-x2 hardware access:

- `just switch` on evo-x2
- Verify all services after deploy
- Pi 3 build and DNS failover cluster setup

**P1 — SECURITY (3/7, 43%)** — Remaining:

- Move Taskwarrior encryption to sops (BLOCKED on evo-x2)
- Pin Docker digests for Voice Agents, PhotoMap (BLOCKED on evo-x2)
- Secure VRRP auth_pass with sops (BLOCKED on evo-x2)

**P9 — FUTURE (2/12, 17%)** — Research tasks:

- Automated blocklist hash updates (THIS SESSION would have benefited from this!)
- NixOS tests for service modules
- Home Manager Darwin migration
- Secrets rotation automation

---

## D) TOTALLY FUCKED UP

### Nothing catastrophic — but close calls:

1. **Hermes override approach iteration:** Went through 6+ failed approaches before finding the `callPackage` interception pattern. Failed approaches included:
   - `overrideAttrs` on the default package (doesn't remove old tui from closure)
   - `overrideAttrs` with `builtins.replaceStrings` on installPhase (old tui still a dep)
   - `override { callPackage = newScope { hermesTui = ...; } }` (callPackage doesn't resolve scope names for file-based calls)
   - `inputs.hermes-agent.source` (flake inputs don't have `.source` attribute)
   - Direct `pkgs.callPackage` on hermes-agent.nix (couldn't access source path)

2. **GitHub API rate limiting:** Could not update the hermes-agent flake input initially due to IP-based rate limiting. Workaround: used `gh auth token` via `--option access-tokens`. The cached version had the same commit anyway (upstream hasn't fixed the hash yet).

3. **DNS blocklist hashes are a recurring problem:** 10 of 25 blocklists were stale. These are live URLs that change content regularly. This will keep breaking builds until automated.

---

## E) WHAT WE SHOULD IMPROVE

### Critical Process Gaps

1. **No automated hash freshness checks for blocklists** — DNS blocklists change daily. We should have CI or a pre-commit hook that verifies blocklist hashes.

2. **No CI pipeline** — Build failures like this are caught only when someone runs `nh os build .` manually. A CI pipeline running `nix flake check` would catch these immediately.

3. **Hermes-agent is an external dependency with no hash pinning safety net** — The upstream flake can break our build at any time. Consider vendoring or forking.

4. **No `nix flake check` in pre-commit** — Would catch hash mismatches, eval errors, and lint issues before committing.

### Architecture Improvements

5. **Blocklist hashes should use `fetchurl` with `sha256` auto-update script** — A `just` recipe that re-fetches all blocklist hashes would prevent this class of failures.

6. **Hermes-agent should be consumed via overlay by default** — The current approach (`inputs.hermes-agent.packages.${system}.default`) doesn't allow local overrides. The overlay approach is more flexible.

7. **`inputs.hermes-agent.source` access** — Flake-parts doesn't expose source paths easily. Having a convention for accessing source paths of inputs would simplify overrides.

---

## F) Top 25 Things We Should Get Done Next

### Immediate (Next Session)

1. **`just switch` on evo-x2** — Deploy the build we just fixed
2. **Verify hermes service starts** — Check `systemctl status hermes` after deploy
3. **Verify DNS blocker works** — `just dns-diagnostics` after deploy
4. **Automated blocklist hash update script** — `just update-blocklists` recipe that re-fetches all 25 hashes
5. **Create blocklist hash CI check** — Pre-commit or justfile recipe

### High Priority

6. **Pin Docker digests** — Voice Agents and PhotoMap containers should use `sha256:` digests
7. **Move Taskwarrior encryption to sops** — Replace hardcoded hash with sops secret
8. **Secure VRRP auth_pass with sops** — dns-failover.nix plaintext → sops
9. **Hermes health check endpoint** — Add ExecStartPost health check to hermes service
10. **SigNoz metric verification** — Check that all exporters are actually reporting

### Medium Priority

11. **Nix flake check CI** — GitHub Actions or Gitea Actions pipeline
12. **Pi 3 DNS failover cluster** — Build and deploy the rpi3-dns configuration
13. **Authelia SMTP notifications** — Configure email alerts for auth events
14. **Immich backup restore test** — Verify the backup recipe actually works
15. **Twenty CRM status check** — Service is enabled but needs verification
16. **Automated flake input updates** — Weekly `nix flake update` with auto-commit
17. **NixOS tests for critical services** — caddy, unbound, hermes at minimum
18. **Home Manager Darwin sync** — Ensure macOS config matches NixOS shared config
19. **Secrets rotation automation** — sops secrets should have rotation schedules
20. **ComfyUI dedicated user** — Currently runs as `lars` for GPU access; should use service user

### Lower Priority / Future

21. **DNS blocklist deduplication analysis** — 25 blocklists likely have significant overlap
22. **Niri session restore integration tests** — Verify crash recovery works end-to-end
23. **Gatus uptime monitoring deployment** — Module draft exists, needs deploy
24. **Flake schema validation** — Ensure all module options have proper types and descriptions
25. **Documentation freshness audit** — AGENTS.md, README.md, and module docs may be stale

---

## G) Top #1 Question I Cannot Figure Out Myself

**Why does the patched overlay approach still create (but not build) the original tui derivation?**

The `patchedOverlay` evaluates `base = baseOverlay final prev` which creates the full hermes-agent package including the old (broken) tui. Even though we then override with `base.hermes-agent.override { callPackage = interceptCallPackage; }`, the old tui derivation still exists in the Nix evaluation store. It doesn't get built (nothing references it in the final closure), but it pollutes the evaluation. Is there a way to completely avoid creating the old tui derivation during evaluation, without restructuring the upstream flake? This is a fundamental Nix evaluation model question — is lazy evaluation truly lazy enough to skip unreferenced derivations in an overlay chain?

---

## Build Output (Final)

```
>>> /nix/store/m9hilx4vy6hxfcnwa8r4rmpqg2b0z1p9-nixos-system-evo-x2-26.05.20260423.01fbdee

SIZE: 41.7 GiB -> 41.8 GiB
DIFF: 59.2 MiB

ADDED:
  dnsblockd-f587a72, fonts-dummy, jscpd-4.0.9, otel-tui-v0.7.2

REMOVED:
  dnsblockd-a0b1879, otel-tui-v0.7.1
```

---

## Files Changed This Session

| File                                    | Change                                             | Lines   |
| --------------------------------------- | -------------------------------------------------- | ------- |
| `modules/nixos/services/hermes.nix`     | callPackage interception for tui npmDeps fix       | +21/-1  |
| `platforms/shared/dns-blocklists.nix`   | 10 HaGeZi blocklist hash updates                   | +11/-11 |
| `pkgs/golangci-lint-auto-configure.nix` | vendorHash update                                  | +1/-1   |
| `flake.lock`                            | dnsblockd, homebrew-cask, NUR, silent-sddm updates | +13/-13 |

---

_Master TODO: 65% complete (62/95 tasks)_
