# RustFS — Evaluation

**Date:** 2026-08-17
**URL:** https://github.com/rustfs/rustfs
**Version evaluated:** 1.0.0-rc.2 (2026-08-14 — still a release candidate, no stable 1.0 yet)
**License:** Apache-2.0 (explicitly marketed as "avoiding the restrictions of AGPL" — no relicensing event in LICENSE history)
**Status:** NOT ADOPTED — evaluation only. Candidate follow-up to the pool-completion master plan.

## Overview

RustFS is an S3-compatible high-performance object storage system written in Rust, positioned as a MinIO alternative for AI/data-lake workloads. Relevance trigger: nixpkgs has marked **MinIO as abandoned** (six unfixed CVEs — CVE-2026-40344, -41145, -33322, -33419, -34204, -39414 — with the note "users should migrate to alternatives such as Garage, SeaweedFS, or Ceph"), and SystemNix currently runs **zero S3 endpoints**.

## Technical Profile

| Aspect          | Details                                                                                          |
| --------------- | ------------------------------------------------------------------------------------------------ |
| APIs            | S3 + OpenStack Swift; AWS SigV2/V4, presigned URLs                                               |
| AuthN           | Built-in AWS-style IAM: users, groups, service accounts, STS (`AssumeRole`), OIDC identities     |
| Deployment      | Single binary, official Nix flake (`nix run github:rustfs/rustfs`), Docker images, distributed mode |
| Data protection | Erasure coding, bitrot protection, versioning, bucket replication, multi-tenancy                  |
| Metrics         | **No native `/metrics` endpoint** — pushes `rustfs_*` metrics via OTLP to a collector             |
| Nix support     | **Not in nixpkgs** (issue #1897 requests package + module); official flake exists; **no NixOS module** |

## Motivation (what gap would it fill)

1. **#1 flagged data-loss risk (since 2026-06-25):** all backups are LOCAL-ONLY. The MacBook has no off-machine backup target at all. An S3 endpoint on the `/mnt/pool` BTRFS RAID1 pool (2×16 TB MG08, near-new) closes the real gap.
2. **sccache is a per-machine island** — evo-x2 has `/mnt/buildcache/sccache`; the MacBook has nothing. sccache's S3 backend would give both machines one shared Rust compile cache.
3. MinIO (the reflex answer) is a dead end in nixpkgs — an alternative is needed regardless if any S3 use case is ever adopted.

## Use-case ranking

| Use case                        | Value | Reasoning                                                                                                                                            |
| ------------------------------- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| **restic target for the MacBook** | High  | restic speaks S3 natively (SigV4 + IAM access keys work). Closes the off-NVMe/off-machine backup gap on near-new pool disks.                          |
| **Shared sccache backend**      | Med   | sccache S3 mode = one cross-machine Rust compile cache. Replaces/augments the per-machine buildcache islands.                                         |
| Attic S3 backend                | Low   | Single node — local `/data/atticd/storage` + size-guard already works. Adding an S3 hop is churn for no gain.                                         |
| Immich storage / pool redesign  | Skip  | BTRFS RAID1 + btrbk-pool snapshots is simpler than an S3 migration; erasure coding on top of RAID1 is pure write amplification.                       |

**Honest Pareto caveat:** for the backup use case alone, `restic` over **SFTP** to `/mnt/pool` needs ZERO new services. S3 only earns its keep if the shared-sccache (or future multi-client) use case is also wanted.

## SystemNix integration sketch (if adopted)

- **Route:** Docker image via `mkDockerService` (`lib/docker.nix`) — dataDir on `/mnt/pool/services/rustfs`, mount-gated so a detached DAS FAILS the unit instead of contaminating the root fs (same guard as Twenty/Manifest pg_dumps).
- **I/O:** `ioTier.background`; time-slice against buildcache-gc (all four DAS disks share ONE USB link `8-1`).
- **Observability:** OTLP push → existing SigNoz collector (`localhost:4317`). Register in `otel-endpoint-audit.nix` expectations. This replaces the textfile-collector dance — but see gotcha below.
- **Secrets:** access keys via sops env template, root-owned `EnvironmentFile` (same DynamicUser-safe pattern as attic/dnsblockd).
- **Ports:** `lib/ports.nix` (RustFS defaults: 9000 S3, 9001 console).
- **Gatus:** liveness only (`[STATUS] == 200` on the health route); functional check needs a PUT/GET roundtrip probe — phantom-green-proof pattern, because there is no scrapeable metrics endpoint to `pat()` against.
- **Homepage tile** + `backup-coordination` registration if it becomes a backup-producing dependency.

## Gotchas

- **`protectedVHost` breaks S3 clients** — SigV4 signing + oauth2-proxy forward-auth do not compose. Must use plain TLS `reverse_proxy` + native RustFS access keys, LAN/VPN-gated (same exception class as OpenSEO's GSC callback path).
- **No `/metrics`** — monitoring must go through the OTLP pipeline; Gatus functional checks must be built around probe scripts, not `pat()`.
- **RC status** — fine as a target for *rebuildable* data (cache, CI artifacts). Wrong for *irreplaceable primary* storage until a stable 1.0 ships. If used as the restic target, the "no remote backup" risk is only partially closed — schedule `restic check` + restore drills.
- **No nixpkgs package / NixOS module** — Docker route avoids the packaging work; a native module would mean vendoring the flake input (upstream flake exists but exports no module).

## Alternatives

|           | RustFS                          | Garage (Deuxfleurs)                        | SeaweedFS                  | restic-over-SFTP            |
| --------- | ------------------------------- | ------------------------------------------ | -------------------------- | --------------------------- |
| nixpkgs   | No (flake only)                 | **Yes, package + NixOS module + tests**    | Yes                        | n/a (no service needed)    |
| License   | Apache-2.0                      | AGPL-3.0 (fine for internal use)           | Apache-2.0                 | n/a                         |
| Maturity  | RC (1.0.0-rc.2)                 | Stable (1.3.1 / 2.3.0)                     | Stable                     | Battle-tested               |
| S3 + IAM  | Full AWS-style IAM              | S3 subset, keys via `garage` CLI           | S3 subset                  | n/a                         |
| Best for  | MinIO-parity features + OTel    | **Lowest-risk native-Nix S3**              | Filenames/volumes          | **Just the backup gap**     |

## Decision

Not adopted. If the pool-completion plan wants an S3 layer: **Garage is the lower-risk move** (native nixpkgs module, stable, tested); **RustFS is the higher-feature bet** (MinIO parity, Apache-2.0, OTel-native) gated on a stable 1.0 release and someone packaging it. If only the MacBook backup gap matters, **restic-over-SFTP to `/mnt/pool` closes it with zero new services**.
