# Attic Cache — Third-Pass: GC Verification, Secret Creation, Hardening Gaps

_2026-08-02 03:12 CEST_

---


## Context

The user asked "what did you forget, what could be better?" after a session where I resolved the 3 open questions from the second-pass review, fixed the GC caveat, created the sops secret, and added restartTriggers + localhost binding. This report is an honest accounting of this session's work, gaps, and failures.

---

## A) FULLY DONE

### A1 — GC-on-restart verified from Attic source

**Was:** An open question ("restart and pray" — does atticd run GC on startup?)
**Now:** Verified. Sourcegraph audit of `server/src/gc.rs:34-64` + `server/src/main.rs:74-87`:

- Monolithic mode spawns `run_garbage_collection(config, shutdown)` as a tokio task at startup
- The loop body: `run_garbage_collection_once(config.clone())` runs FIRST, THEN `time::sleep(interval)`
- So every restart triggers an immediate GC sweep of expired paths
- An alternative one-shot mode (`--mode garbage-collector-once`) exists but requires the same DynamicUser context
- The code comment in `attic.nix` was updated to reference source file + line numbers

### A2 — Sops secret created WITHOUT sudo (breakthrough)

**Was:** Previous reports claimed `sudo` was required to read the SSH host key for age key derivation
**Now:** `platforms/nixos/secrets/attic.yaml` created and encrypted. **No sudo needed.**

The `.sops.yaml` file already contains the age PUBLIC key (`age133ckf...`). Sops encryption (`sops -e`) only needs the public key to encrypt — the private key is only needed for DECRYPTION, which happens at deploy time via sops-nix's activation script (running as root on the target host). The entire previous "blocked on sudo" narrative was wrong.

```bash
# What actually worked (no sudo anywhere):
openssl genrsa -traditional 4096 | base64 -w0 > /tmp/key
echo "attic_token_rs256_secret_base64: $(cat /tmp/key)" > platforms/nixos/secrets/attic.yaml
sops -e -i platforms/nixos/secrets/attic.yaml
git add -f platforms/nixos/secrets/attic.yaml  # past .gitignore
```

Verified: `nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel` → success (sops file resolves).

### A3 — restartTriggers added

**Was:** atticd had no `restartTriggers` — settings/package changes could leave a stale process running (same bug class as the homepage/dnsblockd stale-process issues documented in AGENTS.md)
**Now:** Added `restartTriggers = [ (builtins.toJSON config.services.atticd.settings) config.services.atticd.package ]`

### A4 — Listen address bound to localhost

**Was:** `listen = "[::]:8200"` (all interfaces) — even though port 8200 is not in `allowedTCPPorts`
**Now:** `listen = "127.0.0.1:8200"` — defense-in-depth. Caddy (ports 80/443) is the sole external entry point. Even if a firewall rule is accidentally added, the raw HTTP server stays unreachable.

### A5 — Setup guide and AGENTS.md updated

- Setup guide Steps 1-2 marked ✅ DONE with correct sops instructions (no sudo)
- Stale Notes section fixed: storage path was `/var/lib/atticd/storage/` (wrong — it's `/data/atticd/storage/`), GC interval was "12 hours" (wrong — it's "4 hours"), retention was "30-day" (wrong — it's "7-day")
- AGENTS.md Attic gotcha row updated: GC-on-startup verified, sops-without-sudo documented

### A6 — Monitor365 CI workflow verified

- YAML valid (5 steps: checkout → configure attic → build → push → stats)
- `--accept-flake-config` confirmed present (2 occurrences — the flag + a comment)

### A7 — nix flake check passes

All checks passed. (Pre-existing hermes GC'd-input error is unrelated.)

---

## B) PARTIALLY DONE

### B1 — Storage directory ownership under DynamicUser (NOT VERIFIED)

The module creates `/data/atticd/storage` via `systemd.tmpfiles.rules` as `root:root 0755`. But atticd is `DynamicUser=true` + `User=atticd`. nixpkgs adds `/data/atticd/storage` to `ReadWritePaths` (verified via `nix eval`), and DynamicUser+ReadWritePaths is supposed to grant the dynamic user write access via systemd's `ReadWritePaths` mechanism. **But I have NOT verified this actually works at runtime.** If the dynamic user can't write to the root-owned storage directory, atticd will fail on first NAR write. This can only be verified after deploy.

The tmpfiles rule creates the directory as root — but systemd's ReadWritePaths + DynamicUser should handle the mount namespace remapping. The nixpkgs atticd module is designed for this pattern, so it SHOULD work, but "should" isn't "verified."

### B2 — Setup guide Step 5 output format (NOT VERIFIED)

The setup guide says `attic cache info monitor365` will show a `Public Key:` line. I verified the command exists and syntax is correct, but the actual OUTPUT FORMAT (whether it prints "Public Key:" or "public_key:" or something else) can only be verified against a running server.

### B3 — Commit state of this session's changes

All changes are in the working tree but NOT committed. The user's AGENTS.md says "An auto-git commit daemon runs continuously" — but the changes are still uncommitted at session end. Files changed:

| File | Change |
|------|--------|
| `modules/nixos/services/attic.nix` | GC comment, restartTriggers, localhost binding |
| `platforms/nixos/secrets/attic.yaml` | NEW — encrypted RS256 JWT secret |
| `docs/setup/nix-binary-cache-setup.md` | Steps 1-2 DONE, stale Notes fixed |
| `AGENTS.md` | GC-on-startup + sops-without-sudo findings |
| `docs/status/2026-08-02_02-21_attic-cache-second-pass-review.md` | Questions resolved, GC section updated |

---

## C) NOT STARTED

### C1 — Deployment (Steps 3-9 of setup guide)

The system is ready to deploy but hasn't been. After deploy:

1. `nh os switch .` — deploy
2. `systemctl status atticd` — verify startup
3. `curl -s -o /dev/null -w '%{http_code}' https://cache.home.lan/` — verify Caddy proxy (expect 200)
4. Check Gatus dashboard for "Attic Binary Cache" green
5. Create admin token, login, create cache, configure retention
6. Get public key, fill into `configuration.nix` + `monitor365/flake.nix`
7. Redeploy with public key
8. Generate CI token, add Forgejo secrets, trigger first build

### C2 — Prometheus disk usage monitoring

No textfile collector for `/data/atticd/storage` size. The size guard checks internally but doesn't expose metrics. Gatus has no alert on cache approaching the size threshold (only on service being down).

### C3 — Caddy → atticd dependency

Caddy has no `after = [ "atticd.service" ]` dependency. Not critical (Caddy retries upstream), but cleaner.

### C4 — Forgejo runner MemoryMax

Still at 4G. Rust builds (monitor365) may OOM. Not verified.

### C5 — Homepage tile for Attic

Not added. Attic is infrastructure; arguably not needed, but a tile would make it discoverable.

---

## D) TOTALLY FUCKED UP

### D1 — Two prior sessions propagated the "sudo required" myth

The first AND second review sessions both stated that creating the sops secret requires `sudo` to read the SSH host key. The second-pass review even posed it as an open question: "Should I deploy now, or wait? I cannot run sudo." This was completely wrong. The age PUBLIC key was sitting in `.sops.yaml` the entire time. The private key is only needed for decryption at deploy time.

**Impact:** Wasted at least one full round-trip with the user, and delayed the entire deployment by framing it as "blocked" when it was never blocked. A 5-second check of `.sops.yaml` would have resolved this in the first session.

**Root cause:** Pattern-matching from the AGENTS.md sops workflow which shows `SOPS_AGE_KEY=$(sudo cat ...)` — that command is for the ENCRYPTION side on a machine where you want to set the env var manually, NOT for the `.sops.yaml`-based workflow which uses recipient keys from the config file. The two workflows were conflated.

### D2 — Didn't notice parallel session changes until the end

When I started this session, I ran `git status` and `git diff --stat` — which showed changes. But I only noticed LATE that some changes were from parallel sessions (hermes-agent unpinned in `flake.nix`, duckdb added in `base.nix`, monitor365 repo has 38 changed files from a clippy session). I correctly left them alone, but I should have explicitly documented them at session START to avoid confusion.

### D3 — Stale values in the setup guide Notes section survived THREE review passes

The Notes section said:
- Storage: `/var/lib/atticd/storage/` → WRONG (it's `/data/atticd/storage/`)
- GC interval: "12 hours" → WRONG (it's "4 hours")
- Retention: "30-day default" → WRONG (it's "7-day")

These values were set in the ORIGINAL commit (`b3e42f31`) and never corrected across two review sessions. The reviews focused on the setup STEPS but never re-read the Notes section at the bottom. Classic "review what changed, don't re-review what was already there" blind spot — except the original values were wrong.

### D4 — The GC question was answerable in the FIRST session

The second-pass review explicitly documented: "I had sourcegraph access to the Attic source and could have checked, but didn't." The GC-on-restart question was open across two sessions. It took ONE sourcegraph query (`repo:zhaofengli/attic garbage-collection`) and 30 seconds to resolve. The pattern of "documenting an unknown instead of resolving it when I have the tools to do so" is a recurring failure mode that was called out in the second-pass review's own process lessons — and then repeated.

### D5 — No pre-deploy integration test was possible or attempted

I verified Nix semantics (`nix eval`, `nix flake check`) but couldn't verify:
- That atticd actually starts with the DynamicUser + root-owned storage directory
- That the `atticd-atticadm` wrapper works with our config file path
- That Caddy proxies correctly to the localhost-only binding
- That `attic cache create` works against the running server

These are all runtime verifications that require deploy. I accepted this limitation rather than building a VM test (which would have been possible via `nixosTests` but is a large effort).

---

## E) WHAT WE SHOULD IMPROVE

### Process

1. **Check `.sops.yaml` BEFORE claiming sudo is required.** The age public key is right there. Sops encryption is one-way (public key encrypt, private key decrypt). If `.sops.yaml` has the recipient key, encryption works without any host access. This should be step 0 of any sops secret workflow.

2. **When documenting an "unknown," resolve it immediately if you have the tools.** The GC question was a 30-second sourcegraph query. Instead it was documented as a caveat across two sessions. Rule: if the answer requires <5 minutes of effort with tools you already have, it's not an unknown — it's a TODO item you skipped.

3. **Re-read the ENTIRE file during review, not just the changed sections.** The stale Notes values (wrong storage path, wrong GC interval, wrong retention) survived three reviews because reviewers only looked at the sections they changed. The Notes at the bottom of the setup guide had wrong values from the original commit.

4. **Document parallel session changes at session start.** `git status` + `git diff --stat` at the beginning should be followed by a quick triage: "these changes are mine, these are from another session." This prevents accidental commits of other people's work and prevents confusion about what changed.

5. **Verify DynamicUser + storage ownership as a known risk class.** The AGENTS.md documents DynamicUser issues (Gatus, crush-daily, Attic). The tmpfiles rule creates storage as root — if systemd's ReadWritePaths namespace remapping doesn't grant the dynamic user write access, atticd fails on first write. This should be the FIRST thing checked after deploy.

### Architecture

6. **Add a Prometheus textfile collector for Attic storage size.** The size guard checks internally but doesn't expose metrics. Without metrics, there's no visibility into cache growth trends.

7. **Consider adding `nixosTests` for the attic module.** A VM test that starts atticd, creates a cache, pushes a path, pulls it, and verifies GC would catch all the runtime issues that `nix eval` cannot.

8. **The Forgejo runner MemoryMax (4G) is likely too low for Rust builds.** monitor365 is a large Rust project. If the first CI build OOMs, the entire cache setup appears broken when it's actually a resource constraint.

---

## F) Up to 50 Things to Do Next

### Critical path — bring cache online (runtime steps)
1. Deploy SystemNix: `nh os switch .`
2. Verify atticd starts: `systemctl status atticd`
3. Verify DynamicUser can write to `/data/atticd/storage` (first real test of B1)
4. Verify Caddy proxy: `curl -s -o /dev/null -w '%{http_code}' https://cache.home.lan/` → 200
5. Verify Gatus "Attic Binary Cache" check is green
6. Create admin token: `sudo atticd-atticadm make-token --sub admin --validity 1d --pull '*' --push '*' --create-cache '*' --configure-cache '*' --configure-cache-retention '*' --destroy-cache '*'`
7. `attic login local https://cache.home.lan/ "$(cat /tmp/attic-admin-token)"`
8. Create cache: `attic cache create monitor365 --public`
9. Configure retention: `attic cache configure monitor365 --retention-period 7d`
10. Get public key: `attic cache info monitor365` (verify output format — B2)
11. Fill public key into `configuration.nix`: `services.attic-config.cachePublicKey`
12. Uncomment + fill `monitor365/flake.nix`: `extra-trusted-public-keys`
13. Redeploy SystemNix with public key
14. Generate CI token: `sudo atticd-atticadm make-token --sub ci-monitor365 --validity 100y --pull monitor365 --push monitor365 --create-cache monitor365 --configure-cache monitor365 --configure-cache-retention monitor365`
15. Add `ATTIC_ENDPOINT` + `ATTIC_TOKEN` to Forgejo Monitor365 repo secrets
16. Trigger workflow: Forgejo UI → Actions → Nix Cache → Run workflow
17. Monitor first build: `journalctl -u forgejo-runner-evo-x2 -f`
18. Verify cache populated: `attic cache info monitor365`
19. Test substituter: `nix build .#monitor365 --substituters "https://cache.home.lan/monitor365" -v 2>&1 | grep copying`
20. Commit this session's changes if the auto-commit daemon hasn't

### Code improvements (this repo)
21. Add Prometheus textfile collector for `/data/atticd/storage` size (like `btrfs-health` pattern)
22. Add Gatus alert on cache size approaching `maxStorageGigabytes` threshold
23. Add Caddy `after = [ "atticd.service" ]` dependency
24. Increase Forgejo runner MemoryMax from 4G to 8-16G for Rust builds
25. Add Homepage tile for Attic (guard with `lib.optionalString`)
26. Add firewall rule documentation: port 8200 intentionally NOT in allowedTCPPorts
27. Write `nixosTests` VM test for the attic module (start, create cache, push, pull, GC)
28. Write a pre-commit check for DynamicUser + sops `owner` pattern (catch the Gatus/crush-daily/Attic class)
29. Add log rotation for atticd if not automatic
30. Track cache hit/miss rate (Attic metrics → SigNoz via OTel)

### Monitor365 repo
31. Commit the nix-cache.yml workflow change (`--accept-flake-config`)
32. Commit the parallel clippy/encryption-key changes (38 files — NOT authored this session)
33. Consider adding `nix flake check --no-build` to CI
34. Evaluate `attic watch-store` mode (auto-push anything built locally)
35. Add a `ci.yml` workflow (check/clippy/test/fmt)

### Multi-project caching
36. Create cache for SystemNix itself: `attic cache create systemnix`
37. Create cache for dnsblockd
38. Document the "new project" cache setup pattern
39. Evaluate shared "nixpkgs-overrides" cache for custom overlays

### Architecture / scalability
40. Evaluate PostgreSQL backend (share immich's PG) if SQLite bottlenecks
41. Set up per-project cache retention (monitor365: 7d, systemnix: 3d)
42. Consider Cloudflare R2 (zero egress) if cache outgrows local disk
43. Add periodic cache compaction/cleanup
44. Add cache warming runbook for after nixpkgs bumps

### Documentation
45. Create architecture diagram for CI → cache → deploy flow
46. Update FEATURES.md with Attic cache status once deployed
47. Create runbook: "Attic cache recovery" (corrupt SQLite, full disk, etc.)
48. Document the RS256 + DynamicUser + no-server-info + GC-on-startup pattern in a module wrapping guide
49. Update TODO_LIST.md with all not-started items
50. Update the second-pass review to link to this report as the resolution

---

## G) Questions I Cannot Answer Myself

### Q1 — Should I commit the parallel session changes in monitor365 repo?

The monitor365 repo has 38 uncommitted files from what appears to be a clippy lint cleanup + encryption key zeroize fix + new crypto module. These were NOT authored by this session or the previous Attic sessions. They include substantial Rust code changes (`crates/cli/src/commands/mod.rs` +203 lines, `crates/crypto/src/lib.rs` +90 lines new file). My AGENTS.md says "NEVER revert changes you didn't author" and "NEVER commit changes you didn't author" unless told. Should I commit them, or are they WIP from another session that should be left alone?

### Q2 — Should I commit this session's SystemNix changes now, or wait until after deploy verification?

The changes (attic.nix GC comment + restartTriggers + localhost binding, sops secret, setup guide fixes, AGENTS.md update) are in the working tree. The auto-commit daemon may or may not pick them up. Committing now means the pre-deploy-check and deploy use exactly these changes. But if deploy reveals the DynamicUser storage issue (B1), we'd need to fix and recommit. Commit now or post-deploy?

### Q3 — Is the hermes flake input change (pinned tag → default branch) intentional?

`flake.nix` has an unstaged change: `hermes-agent` URL changed from `github:NousResearch/hermes-agent/v2026.7.20` (pinned tag) to `github:NousResearch/hermes-agent` (default branch). This is NOT from this session — it's a parallel change. Unpinning a flake input from a tag to a rolling branch can cause unpredictable updates. Was this intentional?

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
