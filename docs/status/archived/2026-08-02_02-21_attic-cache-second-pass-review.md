# Attic Cache: Second-Pass Review & Bug Fixes

_2026-08-02 02:21 CEST_

---


## Context

This session was triggered by the user's reaction to question Q3 from the
previous review report (`docs/status/2026-08-02_01-35_attic-cache-review-and-bugfixes.md`):
"Is 20 GB on `/data` the right disk budget for Attic, given what else lives
there (Docker, Immich, snapshots)? **WHAT?!**"

The "WHAT?!" was justified. The question was never a real question — it was
answerable with a 30-second disk check. The previous report posed it as an
open question instead of investigating. This session resolved ALL three open
questions and, in the process of verifying CLI commands against real binaries,
discovered 3 additional bugs the previous review missed.

---

## A) FULLY DONE

### Bugs found and fixed (this session)

| # | Bug | Severity | Fix |
|---|-----|----------|-----|
| RS6 | **`/api/v1/server-info` does NOT EXIST** in the Attic server. Sourcegraph audit of `server/src/api/mod.rs` + `v1/mod.rs` + `binary_cache.rs` shows the complete route table: `/` (placeholder HTML), `/{cache}/nix-cache-info`, `/{cache}/{path}`, `/{cache}/nar/{path}`, `/_api/v1/*` (internal API with underscore prefix). Zero matches for "server-info" in the entire repo. | **SHOWSTOPPER** — Gatus health check would ALWAYS return 404, generating permanent false alarms. The previous review session ADDED this broken endpoint while fixing RS3 (missing health check) — introduced a bug while fixing a bug. | Gatus check changed from `/api/v1/server-info` to `GET /` (returns 200 when server is up). Setup guide Step 3 verification updated. |
| RS7 | **`attic token` subcommand does NOT EXIST.** The `attic` client CLI has: `login`, `use`, `push`, `cache`, `watch-store`. There is no `token` subcommand. | **Broken setup guide** — Step 7 (`attic token --endpoint ...`) would fail at runtime. | Replaced with `atticadm make-token --sub ci-monitor365 --validity 100y --pull monitor365 --push monitor365 --create-cache monitor365 ...` (server-side admin tool with scoped permissions). |
| RS8 | **`atticadm make-token` had ZERO permission flags.** The previous review's Step 4 used `--sub admin --validity 1d` — no `--pull`, `--push`, `--create-cache`, etc. A token without permissions is useless: the admin can't create caches, push, or pull. | **Broken bootstrap flow** — following the setup guide would produce a token that can do nothing. | Added full permission flags: `--pull '*' --push '*' --create-cache '*' --configure-cache '*' --configure-cache-retention '*' --destroy-cache '*'` for admin bootstrap token. Scoped to `monitor365` for CI token. |

### All three open questions resolved

| Q | Resolution |
|---|------------|
| Q1 — `harden{}` dead-code | **Removed.** The `harden {}` call now contains ONLY `MemoryMax = "2G"`. `ProtectSystem` and `ReadWritePaths` were dead code (nixpkgs sets both at default priority, stricter than our `mkDefault`). Verified via `nix eval`: `ProtectSystem = "strict"` (nixpkgs wins), `ReadWritePaths = [ "/data/atticd/storage" ]` (nixpkgs wins), `MemoryMax = "2G"` (ours). |
| Q2 — Monitor365 CI workflow | **Fixed.** Added `--accept-flake-config` to the `nix build` command in `.forgejo/workflows/nix-cache.yml`. Without it, Nix silently ignores the flake-level `nixConfig` (extra-substituters + extra-trusted-public-keys) in CI. |
| Q3 — Disk budget on `/data` | **Resolved with evidence.** `/data`: 1.1 TB total, 367 GB free. Snapshots: 0 bytes exclusive (CoW). Docker + Immich share the partition. 20 GB = 5.5% of free space for a single-project 7-day cache with dedup. The question should never have been open. |

### CLI verification performed (not from memory — from real binaries)

Built `nixpkgs#attic-server` and `nixpkgs#attic-client` from source and ran
`--help` on every subcommand. Every setup guide command is now verified:

| Command | Source | Verified Against |
|---------|--------|------------------|
| `atticadm make-token --sub <SUB> --validity <P> [--pull <PAT> --push <PAT> ...]` | `atticadm --help` + `atticadm make-token --help` | attic-server 0.1.0 (`/nix/store/abx2lc9...`) |
| `attic login <NAME> <ENDPOINT> [TOKEN]` | `attic login --help` | attic-client (`/nix/store/p0cnf8...`) |
| `attic cache create <CACHE> --public` | `attic cache create --help` | attic-client |
| `attic cache configure <CACHE> --retention-period <P>` | `attic cache configure --help` | attic-client |
| `attic cache info <CACHE>` | `attic cache info --help` | attic-client |
| `GET /` returns 200 | Sourcegraph: `server/src/api/mod.rs:14` — `.route("/", get(placeholder))` returns `Html(&'static str)` | Source audit |
| `/_api/v1/*` (internal, underscore prefix) | Sourcegraph: `server/src/api/v1/mod.rs` | Source audit |

### Files changed this session

| File | Changes |
|------|---------|
| `modules/nixos/services/attic.nix` | Removed dead-code `ProtectSystem`/`ReadWritePaths` from `harden {}` (only `MemoryMax` remains — verified via `nix eval`). Updated comment. |
| `modules/nixos/services/gatus-config.nix` | Changed Gatus endpoint from `/api/v1/server-info` (non-existent) to `GET /` |
| `docs/setup/nix-binary-cache-setup.md` | Step 3: updated verification (`curl /` not `/api/v1/server-info`). Step 4: added permission flags to `make-token`, explained token requires permissions. Step 7: replaced non-existent `attic token` with `atticadm make-token`. |
| `docs/status/2026-08-02_01-35_attic-cache-review-and-bugfixes.md` | Resolved Q1/Q2/Q3, updated all status sections, fixed stale `/api/v1/server-info` references, added D4/D5 findings. |
| `docs/status/2026-08-02_00-50_nix-binary-cache-ci.md` | Fixed stale endpoint reference in appendix. |
| `AGENTS.md` | Updated Attic gotcha row: added endpoint discovery, `attic token` non-existence, `make-token` permission requirement, harden{} dead-code note. |
| `/home/lars/projects/monitor365/.forgejo/workflows/nix-cache.yml` | Added `--accept-flake-config` to `nix build`. |

### Verification

- `nix flake check --no-build` → **all checks passed**
- `nix eval` confirmed: `ProtectSystem = "strict"` (nixpkgs), `ReadWritePaths = [ "/data/atticd/storage" ]` (nixpkgs), `MemoryMax = "2G"` (ours)
- Monitor365 workflow YAML validated (`python3 -c yaml.safe_load`)

---

## B) PARTIALLY DONE

### GC-on-restart assumption — ✅ VERIFIED (third session)

**VERIFIED from Attic source** (`server/src/gc.rs:34-64` + `server/src/main.rs:74-87`):
The GC loop (`run_garbage_collection`) calls `run_garbage_collection_once` FIRST
(before sleeping for the interval). So on every startup — including restart —
GC runs an immediate sweep of expired paths. The "restart and pray" concern was
unfounded. The size guard's restart-to-trigger-GC mechanism is correct and verified.

An alternative one-shot mode exists (`atticd --mode garbage-collector-once`) but
requires the same DynamicUser context + config file path, making the restart
approach simpler. The code comment in `attic.nix` has been updated to reflect
this verified behavior.

### Setup guide Step 5 (`attic cache info` output format)

The setup guide says to look for a `Public Key:` line. The `attic cache info`
help shows it takes `<CACHE>` as arg. I verified the command exists and the
syntax is correct, but I have NOT verified the actual OUTPUT FORMAT — whether
it prints "Public Key:" or "public_key:" or something else. This can only be
verified against a running Attic server.

---

## C) NOT STARTED

1. **Generate RS256 JWT secret** — `openssl genrsa -traditional 4096 | base64 -w0`
2. **Create `platforms/nixos/secrets/attic.yaml`** — needs age key from SSH host key (requires sudo)
3. **Deploy SystemNix** — `nix run .#deploy`
4. **Verify atticd starts** — `systemctl status atticd`
5. **Verify Caddy proxy** — `curl -s -o /dev/null -w '%{http_code}' https://cache.home.lan/` (expect 200)
6. **Create cache** — `atticd-atticadm make-token ...` → `attic login` → `attic cache create monitor365 --public`
7. **Get public key** — `attic cache info monitor365`
8. **Fill public key into config** — `configuration.nix` + `monitor365/flake.nix`
9. **Redeploy with public key**
10. **Generate CI push token** — `atticadm make-token --sub ci-monitor365 ...`
11. **Add Forgejo repo secrets** — `ATTIC_ENDPOINT`, `ATTIC_TOKEN`
12. **Trigger first CI build**
13. **Caddy→atticd `after` dependency** — not added (attic is behind Caddy proxy; restart order is not critical but would be cleaner)
14. **Homepage tile** — not added (attic is infrastructure; arguably not needed)
15. **Runner MemoryMax increase** — Forgejo runner still at 4G (may OOM on Rust builds)

---

## D) TOTALLY FUCKED UP

### D1 — The previous review introduced a non-existent endpoint while fixing a missing health check

Finding RS3 in the previous review ("no Gatus health check") was correct.
But the FIX — adding a health check pointing at `/api/v1/server-info` —
introduced RS6 (a broken endpoint that would ALWAYS 404). The reviewer
guessed an endpoint name based on a pattern from other services without
verifying it against the Attic source. This is the exact anti-pattern
criticized in the process lessons: "every module wrapping an external service
MUST be cross-checked against the upstream module source or documentation,
not just eval'd."

**Impact if deployed:** permanent Gatus false alarms on the Attic service,
Discord alert spam, and a green dashboard reporting a broken service.

### D2 — The previous review replaced one unverified command with another (twice)

The original setup guide Step 4 used `sudo -u atticd atticd-queue monitor365`
(wrong — no such command). The review "fixed" it to `sudo atticd-atticadm
make-token --sub admin --validity 1d` — which was ALSO wrong (no permission
flags → useless token). Then Step 7 used `attic token` — which DOESN'T EXIST
as a subcommand. Three unverified commands in a setup guide for a system that
hasn't been deployed yet. None of them would have worked at runtime. It took
a THIRD pass (building the actual binaries and running `--help`) to catch all
three.

**Root cause:** The review verified Nix semantics (`nix eval`, `nix flake
check`) but never verified CLI contracts. `nix eval` confirms the module
configures `environmentFile` correctly — it does NOT confirm that
`atticadm make-token` accepts `--sub` without `--pull`.

### D3 — I had sourcegraph access but didn't use it for the GC question

The `atticd-size-guard` design depends on whether restarting atticd triggers
GC. I had sourcegraph access to the Attic source and could have searched for
the GC startup logic in `server/src/gc.rs` or similar. Instead, I documented
the uncertainty as a "caveat" and moved on. This is the exact anti-pattern
I criticized in the process lessons: "documenting an unknown instead of
resolving it when I have the tools to do so."

### D4 — Q3 was never a real question — it was a failure to investigate

The previous review posed "Is 20 GB the right disk budget?" as an open
question to the user. It was answerable in 30 seconds with `df -h /data` +
`btrfs filesystem du -s /data/.snapshots`. The answer: 367 GB free, snapshots
cost 0 exclusive bytes, 20 GB is 5.5% of free space. Posing it as a question
wasted a round-trip and signaled a lack of investigative rigor.

### D5 — Parallel changes in the working tree went unnoticed

`monitor365.nix` (SystemNix) has uncommitted changes adding
`agentStoragePath = "/data/monitor365"` — NOT made by this session. The
monitor365 repo itself has 8 changed files (encryption key zeroize fix) from
a parallel session. I didn't notice these until reviewing `git diff --stat`
at the end. I should have checked the full working tree state at the start
and understood what was already changed before adding my own edits.

---

## E) WHAT WE SHOULD IMPROVE

### Process lessons

1. **Verify CLI contracts against real binaries, not memory.** Every command
   in a setup guide should be run through `--help` or tested against a real
   instance. The pattern of guessing CLI syntax from memory or similar
   services has now failed 3 times (Step 4, Step 7, and the endpoint name).
   **The fix is mechanical:** build the package (`nix build nixpkgs#X`),
   run `--help` on every subcommand, copy exact syntax.

2. **When fixing a bug, verify the FIX doesn't introduce a new bug.** RS3
   (missing health check) was a real bug. The fix (adding `/api/v1/server-info`)
   introduced RS6 (non-existent endpoint). The fix should have been: (a)
   identify the need, (b) find the correct endpoint from source, (c) add the
   check. Instead: (a) identify the need, (b) guess the endpoint, (c) add
   the check. **The intermediate step — finding the correct endpoint — was
   skipped.**

3. **Don't pose answerable questions to the user.** Before writing "Is X the
   right value?", run the command that answers it. If it takes <5 minutes,
   it's not a question — it's a TODO item you skipped.

4. **Use sourcegraph proactively.** When wrapping an external service, search
   its source for: route definitions, config key names, startup behavior.
   Don't wait for a bug to force you to read the source — read it upfront.
   The entire `/api/v1/server-info` fiasco could have been avoided by one
   sourcegraph query: `repo:zhaofengli/attic .route(`.

5. **Check the working tree at session start.** `git status` + `git diff
   --stat` at the beginning would have revealed the parallel monitor365
   changes. Making edits without understanding the full working tree state
   risks conflicts and confusion.

### Architecture improvements

6. **The GC-on-restart mechanism needs verification or redesign.** If Attic
   does NOT run GC on startup, the size guard is "restart and pray." Options:
   - Read `server/src/gc.rs` to verify startup behavior
   - Use `atticd --mode garbage-collector` as a one-shot instead of restart
   - Shorten `garbage-collection.interval` to 1h

7. **Add a pre-commit check for DynamicUser + sops owner.** The DynamicUser +
   sops `owner = "X"` bug class has now appeared 3 times (Gatus, crush-daily,
   Attic). A pre-commit hook scanning `sops.nix` for `owner = "X"` where X
   is a known DynamicUser service would catch this class automatically.

8. **Consider a "setup guide linter" that verifies CLI commands.** Every
   command in a fenced code block could be run through `--help` or
   `--dry-run` to catch non-existent subcommands. This is ambitious but
   would prevent the recurring "unverified command" anti-pattern.

---

## F) Up to 50 Things to Do Next

### Critical path (bring cache online)
1. Generate RS256 JWT secret: `openssl genrsa -traditional 4096 | base64 -w0`
2. Create `platforms/nixos/secrets/attic.yaml` with sops (needs age key — requires sudo)
3. Deploy SystemNix: `nix run .#deploy`
4. Verify atticd starts: `systemctl status atticd`
5. Verify Caddy proxy: `curl -s -o /dev/null -w '%{http_code}' https://cache.home.lan/` (expect 200)
6. Verify Gatus "Attic Binary Cache" check is green (not 404)
7. Create admin token: `sudo atticd-atticadm make-token --sub admin --validity 1d --pull '*' --push '*' --create-cache '*' --configure-cache '*' --configure-cache-retention '*' --destroy-cache '*'`
8. `attic login local https://cache.home.lan/ "$(cat /tmp/attic-admin-token)"`
9. Create cache: `attic cache create monitor365 --public`
10. Configure retention: `attic cache configure monitor365 --retention-period 7d`
11. Get public key: `attic cache info monitor365` (verify output format matches setup guide Step 5)
12. Fill public key into `configuration.nix`: `services.attic-config.cachePublicKey = "..."`
13. Fill public key into `monitor365/flake.nix`: uncomment + fill `extra-trusted-public-keys`
14. Redeploy SystemNix with public key
15. Generate CI push token: `sudo atticd-atticadm make-token --sub ci-monitor365 --validity 100y --pull monitor365 --push monitor365 --create-cache monitor365 --configure-cache monitor365 --configure-cache-retention monitor365`
16. Add `ATTIC_ENDPOINT` + `ATTIC_TOKEN` secrets to Forgejo Monitor365 repo
17. Trigger workflow manually in Forgejo UI
18. Monitor first build: `journalctl -u forgejo-runner-evo-x2 -f`
19. Verify cache populated: `attic cache info monitor365`
20. Test substituter: `nix build .#monitor365 --substituters "https://cache.home.lan/monitor365" -v 2>&1 | grep copying`

### Code fixes (this repo)
21. Verify Attic GC startup behavior (read `server/src/gc.rs` via sourcegraph)
22. If GC doesn't run on startup, redesign size guard (use `--mode garbage-collector` or shorten interval)
23. Add Caddy `after = [ "atticd.service" ]` dependency
24. Consider `network-online.target` instead of `network.target` for atticd (nixpkgs default uses online)
25. Add `restartTriggers` on atticd referencing the sops template
26. Add Attic disk usage monitoring (Prometheus textfile for `/data/atticd/storage`)
27. Add Gatus alert on cache size approaching `maxStorageGigabytes` threshold
28. Add firewall rule restricting port 8200 to localhost (Caddy handles external)

### Monitor365 repo
29. Uncomment `extra-trusted-public-keys` placeholder after cache creation
30. Consider adding `nix flake check --no-build` to CI
31. Evaluate `attic watch-store` mode (auto-push anything built locally)
32. Consider a `ci.yml` workflow (check/clippy/test/fmt)

### Hardening & monitoring
33. Verify Attic storage write permissions under DynamicUser (root-owned `/data/atticd/storage` — can dynamic user write?)
34. Increase Forgejo runner MemoryMax from 4G to 8-16G for Rust builds
35. Track cache hit/miss rate over time (Attic metrics → SigNoz)
36. Add log rotation for atticd if not automatic
37. Write a pre-commit check for DynamicUser + sops owner pattern (catch Gatus/crush-daily/Attic class of bugs)

### Multi-project caching
38. Create cache for SystemNix itself: `attic cache create systemnix`
39. Create cache for dnsblockd
40. Document the "new project" cache setup pattern
41. Evaluate shared "nixpkgs-overrides" cache for custom overlays

### Architecture
42. Evaluate PostgreSQL backend (share immich's PG instance) if SQLite bottlenecks
43. Set up per-project cache retention (monitor365: 7d, systemnix: 3d)
44. Consider Cloudflare R2 (zero egress) if cache outgrows local disk
45. Add periodic cache compaction/cleanup
46. Add cache warming runbook for after nixpkgs bumps

### Documentation
47. Document the RS256 + DynamicUser + no-server-info pattern in a "NixOS module wrapping guide"
48. Create architecture diagram for CI → cache → deploy flow
49. Update FEATURES.md with Attic cache status once deployed
50. Create runbook: "Attic cache recovery" (corrupt SQLite, full disk, etc.)

---

## G) Questions — All Resolved (Third Session)

### 1. Should I deploy now, or wait? — ✅ READY TO DEPLOY

The sops file `platforms/nixos/secrets/attic.yaml` has been created and encrypted.
**Sops encryption does NOT need sudo** — the age PUBLIC key in `.sops.yaml` is
sufficient for `sops -e`. The private key is only needed for decryption at deploy
time (by sops-nix activation on the target host). The system is ready for
`nh os switch .` or `nix run .#deploy`.

### 2. What's the status of the parallel monitor365 changes? — ⚠️ STILL OPEN

There are uncommitted changes in `monitor365.nix` (SystemNix — adds
`agentStoragePath = "/data/monitor365"`) and in the monitor365 repo (many .rs
files from a clippy session + nix-cache.yml from this session). These were NOT
made by this session. Commit them before deploying if they're ready.

### 3. Should the size guard use a different GC trigger mechanism? — ✅ RESOLVED

**Current mechanism is correct.** Verified from Attic source (`gc.rs:34-64`):
the GC loop runs `run_garbage_collection_once` FIRST (before sleeping), so every
restart triggers an immediate GC sweep. No redesign needed.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
