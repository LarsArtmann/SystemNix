# Nix Binary Cache CI — Session Report

_2026-08-02 00:50_

---

## Goal

Set up a proper Nix binary cache CI pipeline for Monitor365, leveraging the existing Forgejo Actions runner on the SystemNix NixOS host (evo-x2).

## Solution Chosen: Attic (self-hosted binary cache)

Attic deployed on evo-x2, with Forgejo Actions CI building Monitor365 on the `native:host` runner and pushing results to Attic. LAN machines pull from the cache as Nix substituters.

---

## A) FULLY DONE

### SystemNix changes (7 files, +373 lines — staged)

| File | Change | Status |
| --- | --- | --- |
| `modules/nixos/services/attic.nix` | **NEW** — Attic server NixOS module (SQLite backend, local storage, 12h GC, 30-day retention, hardened systemd) | **DONE** — evaluates clean, verified |
| `lib/ports.nix` | Added `attic = 8200` | **DONE** — port collision check passes |
| `platforms/common/dns-local.nix` | Added `"cache"` subdomain | **DONE** — dnsblockd will resolve `cache.home.lan` |
| `modules/nixos/services/caddy.nix` | Added `cache.${domain}` reverse proxy (plain proxy, no forward-auth) | **DONE** — vhost verified in eval |
| `modules/nixos/services/sops.nix` | Added Attic JWT secret + env template | **DONE** — template renders to `/run/secrets/rendered/attic-env` |
| `platforms/nixos/system/configuration.nix` | Enabled `attic-config.enable = true` | **DONE** |
| `docs/setup/nix-binary-cache-setup.md` | **NEW** — 9-step setup walkthrough | **DONE** |

### Monitor365 changes (2 files — committed in `ae55ce08e`, workflow re-fixed)

| File | Change | Status |
| --- | --- | --- |
| `.forgejo/workflows/nix-cache.yml` | **NEW** — CI workflow: build + push to Attic | **DONE** (after bugfixes — see section D) |
| `flake.nix` | Added `nixConfig.extra-substituters` | **DONE** — placeholder public key (intentional) |

### Verification performed

- `nix eval .#nixosConfigurations.evo-x2.config.services.attic-config.enable` → `true`
- `nix eval .#nixosConfigurations.evo-x2.config.services.atticd.settings.listen` → `"[::]:8200"`
- `nix eval .#nixosConfigurations.evo-x2.config.services.atticd.settings.storage` → local at `/var/lib/atticd/storage`
- `nix eval .#nixosConfigurations.evo-x2.config.services.atticd.serviceConfig.Restart` → `"always"`
- `nix eval .#nixosConfigurations.evo-x2.config.services.atticd.serviceConfig.MemoryMax` → `"2G"`
- `nix eval .#nixosConfigurations.evo-x2.config.sops.templates.\"attic-env\".content` → renders correctly (placeholder secret)
- `nix eval .#nixosConfigurations.evo-x2.config.services.caddy.virtualHosts` → includes `cache.home.lan`
- Caddy vhost, DNS entry, port allocation, sops template, system packages — all verified via `nix eval`
- `nix flake check --no-build` on Monitor365 → passes

---

## B) PARTIALLY DONE

### Secret file not created
The sops-encrypted secret file `platforms/nixos/secrets/attic.yaml` does NOT exist yet. The sops template evaluates with `PLACEHOLDER` — deploying now would crash-loop `atticd` (JWT secret literally = "PLACEHOLDER"). The setup guide documents the manual `openssl rand -base64 32` + `sops -e` step but it hasn't been executed.

### Public key not filled in
Both `nix-settings.nix` (`cachePublicKey = ""`) and `flake.nix` (`extra-trusted-public-keys = []`) have empty/placeholder values. These can't be filled until the Attic cache is actually created and its key extracted. This is an inherent chicken-and-egg — documented in the setup guide.

### No actual deployment test
Nothing has been deployed to evo-x2. `nix eval` confirms the config is valid, but `nh os switch` has not been run. No runtime verification that `atticd` starts, that Caddy proxies correctly, or that the `attic` CLI can authenticate.

---

## C) NOT STARTED

1. **Secret generation** — `openssl rand -base64 32` → `sops -e` → `platforms/nixos/secrets/attic.yaml`
2. **SystemNix deployment** — `nh os switch .`
3. **Attic cache creation** — `attic cache create monitor365 --public`
4. **Public key extraction** — `attic cache info monitor365` → fill into config
5. **Forgejo repo secrets** — `ATTIC_ENDPOINT` + `ATTIC_TOKEN` in Forgejo UI
6. **First CI run** — triggering the workflow manually or via push
7. **Runner memory increase** — Forgejo runner has `MemoryMax = 4G` which may OOM on Rust builds
8. **Caddy→atticd dependency** — Caddy's `after` list doesn't include `atticd.service` (not critical — reverse_proxy handles upstream restarts gracefully)

---

## D) BUGS FOUND AND FIXED (self-review)

### Bug 1: `serviceDefaults` used as value instead of called as function

**Status: FIXED**

`serviceDefaults` in SystemNix's lib is a function `{ Restart ? "always", ... }: { ... }`, not an attribute set. My original attic.nix had:

```nix
serviceConfig = lib.mkMerge [
  (harden { ... })
  serviceDefaults        # ← WRONG: passing a function where an attrset is expected
];
```

The correct form (matching caddy.nix pattern):

```nix
serviceConfig = lib.mkMerge [
  (harden { ... })
  (serviceDefaults { })  # ← FIXED: call the function
];
```

This would have caused a NixOS build failure on deployment. Caught during verification via `nix eval`.

### Bug 2: `pkgs.attic` doesn't exist — correct name is `pkgs.attic-client`

**Status: FIXED**

My original attic.nix had `environment.systemPackages = [ pkgs.attic ]`. The nixpkgs attribute is `pkgs.attic-client` (defined at `pkgs/by-name/at/attic-client/package.nix`). The error suggestion said "Did you mean acpic, arti, atac, atril or attr?" — none of which are attic. Fixed to `pkgs.attic-client`. Caught during verification.

### Bug 3: Workflow referenced non-existent `.#monitor365-cli` flake output

**Status: FIXED**

The workflow originally built `.#monitor365-cli`, but the actual flake output is `.#monitor365` (the CLI agent package). Available flake packages: `default`, `monitor365`, `monitor365-cli-fast`, `monitor365-server`, `monitor365-server-fast`, `monitor365-ui`, `monitor365-ui-fast`. There is no `monitor365-cli` (only `monitor365-cli-fast`). Fixed to `.#monitor365`.

### Bug 4: Workflow referenced `.#monitor365-cli.passthru.cargoArtifacts` which doesn't exist

**Status: FIXED**

The `monitor365` package has `passthru = {}` (empty) — crane's `buildPackage` in this flake does not expose `cargoArtifacts` via passthru. The workflow step "Build dependency cache (crane buildDepsOnly)" would have failed. Fixed by removing the step entirely and instead using `nix-store -qR` to push the full closure (which includes all intermediate build dependencies, including the crane `buildDepsOnly` output).

### Bug 5: Auto-commit swept unrelated clippy changes into the Monitor365 commit

**Observation (not fixable by me)**

Commit `ae55ce08e` ("chore(session): commit all uncommitted changes from clippy lint cleanup session") was created by the auto-commit mechanism. It included my `.forgejo/workflows/nix-cache.yml` and `flake.nix` changes alongside unrelated clippy fixes to `crates/collectors/linux/src/*.rs` and `crates/server/src/*.rs`. This is messy but not harmful — the commit message mentions the CI files.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture issues

1. **No CI test job** — The workflow only builds and caches. It doesn't run `cargo check`, `cargo clippy`, `cargo test`, or `cargo fmt`. A full CI pipeline should have separate jobs for quality gates that gate merges, with the cache job being additive. Currently the GitHub Actions CI handles this, but if the intent is to migrate fully to Forgejo Actions, a proper `ci.yml` in `.forgejo/workflows/` is needed.

2. **No `--accept-flake-config` in workflow** — The workflow's `nix build` commands don't use `--accept-flake-config`, so the flake-level substituter config won't be used during CI builds. This means the CI builder itself won't pull from the cache on subsequent runs. For incremental builds (source-only changes), this means full recompilation every time. Fix: either add `--accept-flake-config` to nix commands, or configure the substituter globally in `nix-settings.nix`.

3. **Closure push strategy may be slow** — `nix-store -qR` on the monitor365-server output will enumerate thousands of store paths (including all of nixpkgs gcc, glibc, etc.). `attic push` handles dedup but the initial scan is O(N) in closure size. A smarter approach: push only the monitor365-specific outputs and let attic's substituter resolution handle the rest. Or use `nix build --json` to get exact output paths and push just those + their immediate build-only dependencies.

4. **SQLite backend may not scale** — Attic with SQLite is fine for a single-user/family cache. If the cache grows large (>100K paths) or if multiple CI jobs push concurrently, SQLite's single-writer lock could become a bottleneck. PostgreSQL is the recommended backend for production Attic deployments. The immich module already enables PostgreSQL on evo-x2 — Attic could share that instance.

5. **No cache for other projects** — The workflow only caches Monitor365. SystemNix itself (the NixOS configuration), dnsblockd, and other LarsArtmann projects would benefit from the same Attic instance. Each project just needs its own `attic cache create <name>` and its own workflow.

6. **No monitoring/alerting** — If Attic goes down or the cache GC deletes everything, CI builds silently slow down. Should add a Gatus health check for `cache.home.lan`.

7. **Runner concurrency = 2, but cache builds are heavy** — A full Monitor365 build uses significant CPU/RAM. If another CI job runs simultaneously, both compete for resources. The 4G MemoryMax may be too low for Rust builds (the devShell itself recommends 4 jobs × 8 cores to stay within memory).

### Process issues

8. **I should have run `nix eval` on EVERY module attribute before declaring done** — I caught 2 bugs (serviceDefaults, pkgs.attic) only because I ran targeted eval checks. A systematic `nix eval --json .#nixosConfigurations.evo-x2.config.systemd.services.atticd` would have caught both at once.

9. **I should have checked flake output names before writing the workflow** — The `.#monitor365-cli` bug was avoidable by running `nix eval .#packages.x86_64-linux --apply 'builtins.attrNames'` first.

10. **I didn't verify the nixpkgs atticd module API** — I assumed the `services.atticd` options (settings, environmentFile, etc.) based on memory/documentation without checking the actual nixpkgs module source. The eval confirmed they exist, but the `allow-duplicate-paths` setting might not be valid (no error yet, but untested at runtime).

---

## F) Up to 50 Things to Do Next

### Critical path (bring cache online)
1. Generate JWT secret: `openssl rand -base64 32`
2. Create `platforms/nixos/secrets/attic.yaml` with sops
3. Deploy SystemNix: `nh os switch .`
4. Verify atticd starts: `systemctl status atticd`
5. Verify Caddy proxy: `curl -sk https://cache.home.lan/api/v1/server-info`
6. Create cache: `attic cache create monitor365 --public`
7. Get public key: `attic cache info monitor365`
8. Fill public key into `nix-settings.nix` (`cachePublicKey`)
9. Fill public key into `flake.nix` (`extra-trusted-public-keys`)
10. Redeploy SystemNix with public key
11. Generate push token: `attic token ...`
12. Add `ATTIC_ENDPOINT` secret to Forgejo Monitor365 repo
13. Add `ATTIC_TOKEN` secret to Forgejo Monitor365 repo
14. Trigger workflow manually (workflow_dispatch)
15. Monitor first build: `journalctl -u gitea-runner-evo-x2 -f`
16. Verify cache populated: `attic cache info monitor365`
17. Test substituter from evo-x2: `nix build .#monitor365 --substituters ... -v`

### Hardening
18. Add Gatus health check for `cache.home.lan`
19. Add Caddy `after = [ "atticd.service" ]` dependency
20. Increase runner MemoryMax from 4G to 8-16G for Rust builds
21. Add `--accept-flake-config` to workflow nix commands (so CI pulls from cache too)
22. Configure Attic disk usage monitoring (check `/var/lib/atticd/storage/` growth)
23. Set up Attic log rotation if not automatic
24. Add firewall rule to restrict atticd port 8200 to localhost only (Caddy handles external)

### CI expansion
25. Write proper `.forgejo/workflows/ci.yml` with check/clippy/test/fmt jobs
26. Add `nix flake check --no-build` to CI
27. Add NixOS VM tests to CI (`nix build .#checks.x86_64-linux.server-vm-test`)
28. Add BDD tests to CI (`cargo test -p monitor365-bdd-tests --test bdd -- -c 1`)
29. Mirror GitHub Actions CI matrix in Forgejo workflows
30. Add cache warming for `monitor365-cli-fast` and `monitor365-server-fast`
31. Add cache for the devShell (`nix develop` profile)

### Multi-project caching
32. Create cache for SystemNix itself: `attic cache create systemnix`
33. Create cache for dnsblockd
34. Create cache for other LarsArtmann Rust/Go projects
35. Document the "new project" cache setup pattern
36. Consider a shared "nixpkgs-overrides" cache for custom overlays

### Attic optimization
37. Evaluate PostgreSQL backend (share immich's PG instance)
38. Tune chunking parameters based on real-world NAR sizes
39. Set up cache retention policy per-project (Monitor365: 30d, SystemNix: 7d)
40. Add periodic cache compaction/cleanup
41. Evaluate attic watch store mode (auto-push anything built locally)

### Monitoring
42. Add Attic metrics to SigNoz/Gatus
43. Alert on cache miss rate spikes
44. Track cache size growth over time
45. Monitor GC effectiveness

### Documentation
46. Add Attic to SystemNix README service table
47. Document the cache in Monitor365 AGENTS.md
48. Add architecture diagram for the CI → cache → deploy flow
49. Document recovery procedure if Attic storage corrupts
50. Create a "cache warm-up" runbook for after nixpkgs bumps

---

## G) Questions I Cannot Answer Myself

### 1. Should this replace GitHub Actions CI, or complement it?

The Monitor365 GitHub Actions CI runs 16 jobs across 8 parallel runners. The Forgejo runner on evo-x2 has capacity=2. If the intent is to eventually migrate fully to self-hosted Forgejo Actions, we need a plan for either (a) adding more runners, or (b) accepting slower CI. If it's complementary (GitHub for PRs, Forgejo for cache building), the current setup is sufficient. What's the end goal?

### 2. Should Attic use PostgreSQL (shared with immich) or stay on SQLite?

You have PostgreSQL running for immich. Attic supports PG as a backend. For a single developer's cache, SQLite is fine. But if you plan to cache multiple projects or if concurrent pushes become common, PG would be more robust. Should I wire Attic to the existing PG instance, or keep SQLite for simplicity?

### 3. What's the desired cache retention and disk budget?

I defaulted to 30 days and local storage at `/var/lib/atticd/`. The evo-x2 has a 98GB `/rust-cache` partition and BTRFS root. Where should Attic store its data? Is 30 days appropriate, or do you want shorter/longer retention? And what's the disk budget — the full Monitor365 closure could be 5-10GB per build.
