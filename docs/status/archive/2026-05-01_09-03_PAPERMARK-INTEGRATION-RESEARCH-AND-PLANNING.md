# COMPREHENSIVE STATUS REPORT — SystemNix

**Date:** 2026-05-01 09:03 (Session 11)
**Previous:** Session 10 — `2026-05-01_08-48_SESSION-10-AUTOMODE-ENUM-AND-GO-REFACTORING.md`
**Focus:** Papermark integration research & planning

---

## Executive Summary

Session 11 was a **pure research and planning session** for adding [Papermark](https://github.com/papermark/papermark) (open-source DocSend alternative) to the NixOS evo-x2 configuration. No code was written. Extensive investigation was done into Papermark's architecture, Docker deployment, storage backends, and S3-compatible object storage options. A decision is pending on the storage backend (Garage vs RustFS).

Additionally, there are **3 uncommitted changes** from Session 10's mkGoTool refactoring that need to be committed.

**1 unpushed commit** from Session 10 remains on master.

---

## A) FULLY DONE ✅

### Research Complete — Papermark Integration

| Research Area              | Status  | Key Finding                                                                                                                            |
| -------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| **Papermark architecture** | ✅ Done | Next.js + PostgreSQL + Redis + S3 storage. Docker Compose is the self-hosting method.                                                  |
| **Papermark Docker image** | ✅ Done | Community image `ghcr.io/avnox-com/papermark:latest`. Official repo has no Dockerfile — community self-host repo does.                 |
| **Required services**      | ✅ Done | 3 containers: Papermark (Node.js), PostgreSQL 16, Redis 7                                                                              |
| **Required secrets**       | ✅ Done | NEXTAUTH_SECRET, POSTGRES_PASSWORD, S3 credentials, OAuth credentials (Google/GitHub)                                                  |
| **Caddy integration**      | ✅ Done | `papermark.${domain}` with forward auth (same pattern as Twenty/Immich)                                                                |
| **Implementation pattern** | ✅ Done | Follow `twenty.nix` — Docker Compose managed by systemd service, sops for secrets                                                      |
| **Database migrations**    | ✅ Done | `npx prisma db push --skip-generate` in Docker entrypoint                                                                              |
| **Health check**           | ✅ Done | `GET /api/health` on port 3000                                                                                                         |
| **Backup pattern**         | ✅ Done | Daily `pg_dump` via systemd timer (same as Immich/Twenty)                                                                              |
| **GCS S3 interop**         | ✅ Done | Fully supported via HMAC keys. Endpoint: `https://storage.googleapis.com`. No multipart upload support but Papermark doesn't need it.  |
| **RustFS investigation**   | ✅ Done | Rust-based MinIO alternative. Apache 2.0 license. S3-compatible. Has flake (builds binary only — no NixOS module). Very young project. |
| **Garage investigation**   | ✅ Done | Rust-based S3 storage. Full `services.garage` NixOS module in nixpkgs. AGPL v3. Production-ready.                                      |

### Cumulative Project Status (Sessions 1–11)

| Category         | Total  | Done   | %       |
| ---------------- | ------ | ------ | ------- |
| P0 Critical      | 6      | 6      | 100%    |
| P1 Security      | 7      | 3      | 43%     |
| P2 Reliability   | 11     | 11     | 100%    |
| P3 Code Quality  | 9      | 9      | 100%    |
| P4 Architecture  | 7      | 7      | 100%    |
| P5 Deploy/Verify | 13     | 0      | 0%      |
| P6 Services      | 15     | 9      | 60%     |
| P7 Tooling/CI    | 10     | 10     | 100%    |
| P8 Docs          | 5      | 5      | 100%    |
| P9 Future        | 12     | 2      | 17%     |
| **TOTAL**        | **95** | **62** | **65%** |

---

## B) PARTIALLY DONE 🔧

### Papermark Integration (0% implemented, 100% researched)

| Step                                          | Status         | Details                                                                  |
| --------------------------------------------- | -------------- | ------------------------------------------------------------------------ |
| Create `modules/nixos/services/papermark.nix` | ⬜ Not started | Pattern: `twenty.nix` Docker Compose via systemd                         |
| Add sops secrets for Papermark                | ⬜ Not started | Need: `papermark.yaml` with NEXTAUTH_SECRET, POSTGRES_PASSWORD, S3 creds |
| Wire Caddy vhost `papermark.${domain}`        | ⬜ Not started | Forward auth via Authelia, reverse_proxy to port 3000                    |
| Wire into `flake.nix` imports                 | ⬜ Not started | Add to `imports` list + `inputs.self.nixosModules.papermark`             |
| Enable in `configuration.nix`                 | ⬜ Not started | `services.papermark.enable = true`                                       |
| Storage backend decision                      | ⬜ **BLOCKED** | Waiting for user decision: Garage vs RustFS                              |
| Add Homepage dashboard entry                  | ⬜ Not started | Papermark card on `dash.${domain}`                                       |
| Test with `just test-fast`                    | ⬜ Not started | Syntax validation                                                        |

### Uncommitted Changes (from Session 10)

| File                                     | Change                                                     | Risk                           |
| ---------------------------------------- | ---------------------------------------------------------- | ------------------------------ |
| `pkgs/lib/mk-go-tool.nix`                | +18 lines: `modTidy` option with awk-based replace pruning | Medium — new feature, untested |
| `pkgs/auto-deduplicate.nix`              | +1 line: `modTidy = true`                                  | Low                            |
| `pkgs/terraform-diagrams-aggregator.nix` | +1 line: `modTidy = true`                                  | Low                            |

---

## C) NOT STARTED ⬜

### Papermark — Full Implementation Plan

**Architecture decided:**

- Papermark app + PostgreSQL + Redis → Docker Compose (systemd service, like `twenty.nix`)
- S3 storage → **Garage** (native NixOS) OR **RustFS** (Docker) — **awaiting user decision**
- Caddy → reverse proxy at `papermark.${domain}` with forward auth
- sops → secrets for all credentials

**Files to create/modify:**

| File                                       | Action                                            |
| ------------------------------------------ | ------------------------------------------------- |
| `modules/nixos/services/papermark.nix`     | CREATE — flake-parts module                       |
| `modules/nixos/services/sops.nix`          | MODIFY — add Papermark secrets                    |
| `modules/nixos/services/caddy.nix`         | MODIFY — add `papermark.${domain}` vhost          |
| `flake.nix`                                | MODIFY — add import + nixosModules reference      |
| `platforms/nixos/system/configuration.nix` | MODIFY — `services.papermark.enable = true`       |
| `platforms/nixos/secrets/papermark.yaml`   | CREATE — sops-encrypted secrets (requires evo-x2) |

**If choosing Garage (recommended):**

| File                                       | Action                                        |
| ------------------------------------------ | --------------------------------------------- |
| `modules/nixos/services/garage.nix`        | CREATE — flake-parts module for Garage config |
| `platforms/nixos/system/configuration.nix` | MODIFY — `services.garage.enable = true`      |
| Caddy vhost for `s3.${domain}`             | MODIFY — optional admin access                |

**If choosing RustFS:**

| File                                         | Action                 |
| -------------------------------------------- | ---------------------- |
| RustFS container in Papermark docker-compose | Add service to compose |
| OR custom NixOS module for RustFS            | Write from scratch     |

### P5 — Deployment & Verification (13 tasks, all require evo-x2)

All unchanged from Session 10. Zero progress.

### P9 — Future/Research (10 tasks remaining)

---

## D) TOTALLY FUCKED UP 💥

| Issue                        | Impact | Details                                                                            |
| ---------------------------- | ------ | ---------------------------------------------------------------------------------- |
| **3 uncommitted changes**    | LOW    | Session 10's `modTidy` feature for mkGoTool never committed. Need to commit.       |
| **1 unpushed commit**        | LOW    | Session 10 status report (`3708379`) not pushed to origin.                         |
| **No new code this session** | NONE   | Pure research session — this is fine, but means Papermark is 0% closer to running. |

---

## E) WHAT WE SHOULD IMPROVE 🔧

### Process Improvements

1. **Commit before research sessions** — The 3 uncommitted files should have been committed in Session 10 before ending.
2. **Decision-first approach** — Storage backend decision is blocking all Papermark implementation. Should have presented options faster.
3. **AGENTS.md not updated** — Papermark research findings are not in the project AGENTS.md yet. Storage backend comparison should be documented.

### Technical Improvements

4. **Docker dependency** — Papermark, Twenty, and SigNoz all depend on Docker. Consider whether this is the right long-term approach or if some could be nixpkgs modules.
5. **S3 storage strategy** — Adding Papermark introduces object storage for the first time. This is a new infrastructure primitive that should be designed carefully (could be reused by other services later).
6. **Twenty + Papermark overlap** — Both are Docker Compose services with PostgreSQL + Redis. Consider extracting a shared Docker Compose service pattern.
7. **Status doc sprawl** — 42 status docs in `docs/status/`. Should archive older ones.

---

## F) TOP 25 THINGS TO DO NEXT

### Immediate (this session)

| #   | Task                                              | Est. | Dependency     |
| --- | ------------------------------------------------- | ---- | -------------- |
| 1   | **Commit 3 uncommitted mkGoTool changes**         | 2m   | None           |
| 2   | **User decides: Garage or RustFS**                | 0m   | User decision  |
| 3   | **Create `modules/nixos/services/papermark.nix`** | 30m  | Decision on #2 |
| 4   | **Add Papermark secrets to sops.nix**             | 10m  | None           |
| 5   | **Wire Papermark into flake.nix**                 | 5m   | #3             |
| 6   | **Add Caddy vhost for Papermark**                 | 5m   | None           |
| 7   | **Enable Papermark in configuration.nix**         | 2m   | #3, #5         |
| 8   | **Run `just test-fast` to validate**              | 5m   | All above      |
| 9   | **Update AGENTS.md with Papermark docs**          | 5m   | All above      |

### Storage Backend (depends on decision)

| #   | Task                                                             | Est. | Dependency    |
| --- | ---------------------------------------------------------------- | ---- | ------------- |
| 10  | **If Garage: configure `services.garage` in flake-parts module** | 20m  | Garage chosen |
| 11  | **If Garage: bucket + key init via postStart**                   | 15m  | #10           |
| 12  | **If RustFS: add to Papermark docker-compose**                   | 10m  | RustFS chosen |
| 13  | **Wire S3 endpoint into Papermark env**                          | 5m   | #10 or #12    |

### Short-term (next session, requires evo-x2)

| #   | Task                                               | Est. | Dependency    |
| --- | -------------------------------------------------- | ---- | ------------- |
| 14  | **Push all commits to origin**                     | 1m   | Network       |
| 15  | **Create `papermark.yaml` sops secrets on evo-x2** | 10m  | evo-x2 access |
| 16  | **`just switch` on evo-x2**                        | 45m+ | evo-x2 access |
| 17  | **Verify Papermark health endpoint**               | 3m   | #16           |
| 18  | **Configure OAuth provider (Google/GitHub)**       | 10m  | #16           |
| 19  | **Test document upload via S3 storage**            | 5m   | #16 + storage |

### Medium-term (quality of life)

| #   | Task                                                    | Est. | Dependency         |
| --- | ------------------------------------------------------- | ---- | ------------------ |
| 20  | **P5: Deploy all pending changes to evo-x2**            | 45m+ | evo-x2 access      |
| 21  | **P1: Move Taskwarrior encryption to sops**             | 10m  | evo-x2             |
| 22  | **P1: Pin Docker digests for Voice Agents + PhotoMap**  | 10m  | evo-x2             |
| 23  | **P6: Hermes health check endpoint**                    | 20m  | Hermes code change |
| 24  | **P5: Pi 3 SD image build + DNS failover test**         | 60m+ | Pi 3 hardware      |
| 25  | **Archive old status docs (30+ files in docs/status/)** | 5m   | None               |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**Storage backend decision: Garage or RustFS?**

I cannot make this call because it's a values/architecture tradeoff, not a technical one:

- **Garage**: Battle-tested, native NixOS module (`services.garage`), AGPL v3, CLI-only (no admin UI), low RAM (~50-100MB), production-proven at Deuxfleurs and NGI projects.
- **RustFS**: Very young (pre-1.0, unproven), Apache 2.0 license, web console, would need Docker or custom NixOS module, ~100-200MB RAM, promising but zero production track record.

**My recommendation is Garage** (native NixOS, proven, less work). But the AGPL v3 license may matter to you, and RustFS's console and Apache licensing are legitimate advantages.

**This decision blocks all Papermark implementation work.**

---

## Session Statistics

| Metric                     | Value       |
| -------------------------- | ----------- |
| Commits this session       | 0           |
| Files changed this session | 0           |
| Services modules total     | 29          |
| Custom packages total      | 26          |
| Research hours (Papermark) | ~1h         |
| Uncommitted changes        | 3 files     |
| Unpushed commits           | 1           |
| Master TODO completion     | 65% (62/95) |
