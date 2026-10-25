# Status Report — OpenCloud Adoption PRO/CONTRA Session

_2026-10-25 12:52 CET · session type: exploration/Q&A (read-only analysis) · zero config changes, zero deploys_

**Session scope (complete list of what happened):**

1. Owner question: "PRO CONTRA of adopting https://github.com/opencloud-eu/opencloud"
2. Planning-layer pre-read honored: `rg -il` for opencloud/nextcloud/owncloud/ocis/seafile/file-sync across `docs/`, `TODO_LIST.md`, `ROADMAP.md` — NO prior plan, brainstorm, or todo row exists for a self-hosted cloud drive. The "private-cloud" hits (2026-08 archive) are the PREDECESSOR infrastructure (old repo/host, ZFS, Immich+Paperless origins), not a drive platform. Closest live work: `google-sync` (Drive → HDD-pool one-way mirror, DORMANT, user-gated go-live) + `drive-paperless` ingest (dormant, coupled to it).
3. Current-state grounding: service inventory (`docs/services/` + `modules/nixos/services/`), SSO layer facts (`docs/agents/sso-dns.md`: Layer-1 native-OIDC pattern via Pocket ID provision, the `groups`-scope and `email_verified` fleet traps), port registry shape (`lib/ports.nix`), big-data placement precedent (`/mnt/pool/services/immich` + `RequiresMountsFor`).
4. Upstream research (docs.opencloud.eu, opencloud.eu, nixpkgs, heise, trackers): fork history, licensing, release model, deployment options, external-OIDC requirements, known limitations.
5. Live verification where cheap: `nix eval` against the PINNED nixpkgs rev `fe1324228` (flake.nix:33) for package availability; raw-file fetches at that exact rev for the NixOS module and VM test; icon-pack 404 probes at the pinned dashboard-icons rev `6d31345` and at main.
6. PRO/CONTRA answer delivered in chat with a decisive recommendation; this report + 1 todo row are the self-harvest.

No file in `modules/`, `systems/`, `platforms/`, `flake/`, or `scripts/` was touched.

---

## The Answer Itself (persisted here — chat is not durable)

**Verdict: engineering-feasible TODAY at near-zero packaging cost (nixpkgs ships server + NixOS module + desktop client at our pin), and it fills a REAL gap (interactive self-hosted file access/share/sync — nothing in the fleet does this). ADOPT as a pilot — but the decision is gated on ONE owner question upstream of it: what becomes the canonical general-files store? If Google Drive stays canonical, OpenCloud is a complement (pilot behind SSO); if self-hosted becomes canonical, it is the centerpiece and the Drive mirror's direction eventually flips.**

### Ground truth established

- **No self-hosted cloud drive exists today.** Immich (photos), Paperless (documents), Forgejo (code) own specialized verticals; general files live in Google Drive with a dormant one-way mirror (`docs/services/google-sync.md`: enable=false, go-live is a user sequence). No Syncthing either. The gap "browser + share links + native sync clients for my files, self-hosted" is real and unoccupied.
- **NixOS-native deployment is solved at our exact pin** (all live-verified 2026-10-25 against `github:NixOS/nixpkgs/fe1324228`):
  - `opencloud` 8.1.0 (rolling line) AND `opencloud-production` 7.2.4 (production line, ~6-month cadence) — both packaged.
  - `nixos/modules/services/web-apps/opencloud.nix` EXISTS at the pin: `services.opencloud` renders ONE hardened systemd unit (`opencloud.service`: MemoryDenyWriteExecute, ProtectSystem=strict, …), /etc/opencloud YAML settings, `environmentFile` for secrets (sops-shaped), `stateDir` free to point at `/mnt/pool/services/opencloud` (immich precedent).
  - `nixos/tests/opencloud.nix` EXISTS at the pin: nixpkgs CI boots the module and Selenium-tests web login (admin + demo user) every channel bump — the module is exercised upstream, not just compiled.
  - `opencloud-desktop` 4.0.0 (Qt Linux client) at the pin — vendor ships AppImage-only, but nixpkgs packages it properly.
  - NOT at the pin: `openvfs` (FUSE files-on-demand, opencloud-eu's own) — eval-miss confirmed; would need a pin bump if virtual-files on Linux is ever wanted (official client's Files-on-Demand is Windows-only).
- **Upstream shape:** fork of ownCloud Infinite Scale by ~15 original oCIS engineers after Kiteworks acquired ownCloud; OpenCloud GmbH under the Heinlein Group (mailbox.org), launched 2025-01, v1.0 2025-02. Server Apache-2.0, no license keys, community edition is the full server. Single Go binary, **no database** — metadata in filesystem xattrs. ~6.2k stars, 39 committers/12mo, rolling release every ~3 weeks. LTS = paid only; Production line is the sane self-host target (module itself warns: no downgrade support across lines).
- **SSO fit:** external OIDC IdP is first-class (embedded LibreGraph Connect is optional/excludable). Requirements: auth-code + PKCE public clients, PREDEFINED client IDs (`web`, `OpenCloudDesktop`, `OpenCloudAndroid`, `OpenCloudIOS` — configurable via WEBFINGER env), and — the trap — automatic role assignment via the `oidc` driver needs a role claim in the token; **unmapped users FAIL LOGIN** (`PROXY_ROLE_ASSIGNMENT_DRIVER=oidc`, claim default `roles`, maps e.g. `opencloudAdmin→admin`; recommend `GRAPH_ASSIGN_DEFAULT_USER_ROLE=false`). Pocket ID already speaks this class: `groups` claim is emittable when the client holds the `groups` scope + groups are declared in `pocket-id-config.provision.userGroups` (fleet fact, sso-dns.md). A single-admin household can alternatively run the default-role driver (everyone gets `user`, one bootstrapped admin) and skip claim mapping entirely.
- **Icon pack:** NO `opencloud` icon in dashboard-icons — 404 at the pinned rev `6d31345` AND at main. A papdashboard tile would need an http(s) URL icon (eval-allowed) or ride the existing semantic-glyph [decision] row; §16 stays green either way as long as the tile declares a resolvable icon.

### PRO

| # | Argument | Evidence |
|---|---|---|
| 1 | **Zero packaging debt** — module + server (both release lines) + desktop client already in OUR pinned nixpkgs; no Docker (removed 2026-10-08) needed anywhere | live `nix eval` @ fe1324228; module/test raw-fetched at the same rev |
| 2 | **Architecture fits this box** — single Go binary, no DB to back up/upgrade, ~100-400 MB RAM; state = one plain tree (+xattrs) under BTRFS → snapshots + Borg story unchanged; no PHP CVE class; delta sync | upstream docs + architecture; contrast Nextcloud 1-2 GB + PHP+MariaDB |
| 3 | **Real gap filled** — interactive web file browser, share links, native clients (Linux desktop in nixpkgs, Android on F-Droid, iOS), WebDAV for the rclone fleet; nothing in the fleet provides this today | service inventory; google-sync is a mute one-way mirror |
| 4 | **Layer-1 SSO pattern match** — external-OIDC-native, same shape as Forgejo/Paperless/Gatus/CV/Kith CRM (pocket-id.nix provision + secret bridge); PKCE public clients are Pocket-ID-compatible in principle | sso-dns.md Layer 1 table; external-idp docs |
| 5 | **Credible stewardship** — original oCIS team + Heinlein (30-yr German ISP pedigree), Apache-2.0 server, all features free in community edition, active cadence, its own Android/iOS apps | press + docs + tracker |
| 6 | **Specialized tools stay** — Immich/Paperless/Forgejo untouched; OpenCloud is the general-files layer, NOT a suite migration (we never wanted Talk/Deck/Mail) | repo layout |
| 7 | **Cheap exit** — plain files on disk; abandoning it later loses nothing but the xattr metadata (filenames/bytes remain browsable) | filesystem-storage design |

### CONTRA

| # | Argument | Evidence / mitigation |
|---|---|---|
| 1 | **The canonical-store question is unanswered** — adopting before answering it risks a THIRD truth source (Drive ↔ mirror ↔ OpenCloud); drive-paperless ingest, backup budgets, and the mirror's direction all depend on it | the actual gate; see [decision] row queued |
| 2 | **Young project, fast-moving config surface** — ~1.5 y old; rolling 8.x vs production 7.2.x; nixpkgs module description itself says config "currently not well documented, see source code"; module maintained by 2-3 downstream maintainers | mitigate: pin `opencloud-production` 7.2.4 line; runbook cost is real (new `docs/services/opencloud.md` + pipeline wiring) |
| 3 | **Vendor's happy path is Docker Compose** — native/systemd runs are downstream territory (bare metal "on your own" upstream); if the module lags a breaking env-var change, WE own the gap | acceptable: our whole fleet is native-systemd; the VM test makes silent breakage unlikely |
| 4 | **OIDC role-claim wiring is fiddly** — `oidc` role driver fails logins for users without a mapped claim; needs provisioned Pocket-ID userGroups + `groups` scope + WEBFINGER client-ID overrides | mitigate: single-admin pilot can use default-role driver; claim mapping is a phase-2 hardening |
| 5 | **Share links = a new public-exposure class** — the FEATURE is unauthenticated links; community edition lacks the paid tiers' ransomware protection/file firewall/antivirus (ICAP ClamAV wiring is self-service); a young Go file server facing the internet | mitigate: pilot LAN/VPN-only (cloud-zone mirror + NetBird exist); public-link exposure is an explicit owner call |
| 6 | **xattr metadata fragility** — naive copies (rsync without `-X`) strip metadata; runbook must pin Borg/rsync flags; trash/versions live in-tree (counts against pool space) | documentation discipline |
| 7 | **Not groupware** — CalDAV/CardDAV only via bundled best-effort Radicale (no UI, unwarranted); if the owner expects a Nextcloud-suite replacement this is the wrong tool | scope note, not a defect |
| 8 | **No pack icon** (minor) — tile needs URL icon or semantic glyph | verified 404 @ pin + main |
| 9 | **Fleet costs** — port registry entry (9200 free, verified), gatus coverage check, integration-registry entry + tile, sops secret (admin/JWT), restic/borg row, runbook, VM-test co-import if wanted | the standard adoption tax every service here pays |

### Alternatives, dismissed

- **Nextcloud (PHP)** — the default answer, wrong for THIS box: 1-2 GB RAM + MariaDB + PHP CVE class + upgrade-orbit on a freeze-history host; its app suite (Talk/Deck/Mail) duplicates nothing we want — Immich/Paperless/Forgejo already own the verticals. Category dismissed: resource + security posture.
- **Seafile** — mature sync, but stores data in its own chunked format (not plain files) — breaks the plain-files/BTRFS/Borg doctrine directly. Category dismissed: opaque storage.
- **Syncthing** — solves sync only; no browser, no share links, no accounts; would not reduce Drive dependency at all. Category dismissed: doesn't answer the actual gap.
- **ownCloud oCIS (Kiteworks)** — same lineage but license-key tiers and Kiteworks steering; OpenCloud is the continuation by the original team with a clean all-free community edition. Category dismissed: superseded lineage.
- **rclone serve webdav** — no auth UX, no shares, no clients. Category dismissed: too primitive.

### Recommendation

**Pilot-adopt on the production line (7.2.4), Pocket-ID-fronted, LAN/VPN-only first.** Sequence if the owner answers the canonical-store question in favor of trying it: (1) `services.opencloud` with `package = opencloud-production`, stateDir `/mnt/pool/services/opencloud` (immich mount-gating pattern), embedded IdP initially or Pocket ID with default-role driver; (2) `cloud.home.lan` integration-registry entry + port 9200 + gatus probe + tile with URL icon; (3) desktop client on evo-x2 via nixpkgs; (4) 2-4 weeks real usage; (5) then decide Drive relationship (keep Drive canonical + OpenCloud as interactive complement, or migrate canonical inward and re-target google-sync/drive-paperless). Dismissed alternative: full adoption + Drive migration in one step — migrating 1.9 TB BEFORE the canonical question is answered inverts the risk order for zero benefit.

---

## a) FULLY DONE

1. Planning-layer pre-read ran BEFORE analysis (no prior plan outranks a fresh design — the check was empty, honestly so).
2. Every packaging claim live-verified at the EXACT pinned rev (not registry nixpkgs): package versions via `nix eval github:NixOS/nixpkgs/fe1324228#…`, module + VM test via raw fetches at that rev, `openvfs` eval-miss confirmed at the same pin.
3. Port 9200 confirmed free of `lib/ports.nix` (0 matches).
4. Icon-pack absence verified at BOTH the pinned rev and main (two 404s — the §16-relevant fact is the pinned one).
5. Upstream facts sourced beyond the README (docs.opencloud.eu lifecycle/external-idp pages, heise on the fork, subscription page for the community/paid split) — not folklore.
6. Self-harvest at authoring time: 1 `[decision]` row queued in `docs/todo/services.md` (§f.1). No `[ready]` agent rows — the next concrete step is owner-gated by design.

## b) PARTIALLY DONE / LIMITS

1. **Pocket-ID-as-external-IdP is pattern-proven, not implementation-proven** — no live check that Pocket ID 2.17 accepts the predefined client IDs (`web`, `OpenCloudDesktop`, …) as PKCE public clients with our provision shape; flagged as step-0 of any implementation session, NOT asserted as working here.
2. Web-sourced ecosystem numbers (stars, pricing, cadence medians) come from vendor docs + third-party trackers as of 2026-10; not independently re-counted.
3. No resource benchmark of our own — the ~100-400 MB RAM figure is upstream/community-sourced; a pilot MemoryMax (e.g. 1-2G) would confirm on-host.
4. CalDAV/Radicale, federation (OCM), and migration-tooling claims rest on docs pages; none exercised.

## f) Self-harvested follow-ups

1. **[decision] row queued** in `docs/todo/services.md`: the canonical-store question + exposure appetite (the two owner gates identified above). — done in the same pass as this report.

## g) Owner questions (blocking)

1. **Canonical store intent**: is OpenCloud a (a) complement (Drive stays canonical; OpenCloud = interactive access/share layer), (b) successor (self-hosted becomes canonical; mirror direction eventually flips; drive-paperless re-targets), or (c) experiment only?
2. **Exposure appetite**: LAN/VPN-only pilot (recommended) vs cloud-zone-public share links from day one (accepts the unauthenticated-link surface without the paid-tier protections)?

---

## Addendum 2026-10-25 13:01 — "OpenCloud vs RustFS OR with RustFS?"

**Verdict: not a vs — different layers. OpenCloud stays the answer for the cloud-drive gap (posix driver). RustFS is NOT chained behind it on a single node, and is not adopted standalone now — it becomes the designated S3 building block the day a real S3 consumer appears.**

### Ground truth (verified this session)

- **RustFS** (rustfs/rustfs): S3-compatible distributed object storage in Rust, Apache-2.0, positioned as the MinIO successor after MinIO's community-edition gutting/restrictive AGPL posture. Single binary, SNSD + distributed EC modes, versioning, bitrot, replication, lifecycle, KMS, OIDC console SSO, WebDAV/SFTP/FTPS gates, IAM policies. Young (2025-origin, 1.0.x line), single corporate steward (RustFS, Inc.), fast-moving feature matrix. **Nix story is first-class at OUR pin (fe1324228): `rustfs` 1.0.1 package + `services.rustfs` NixOS module (hardened unit, secrets via environmentFile, fail-loud preStart) + `nixos/tests/rustfs.nix` VM test** — same module+VM-test quality signal as OpenCloud. Upstream ALSO ships its own flake with a NixOS module.
- **Fleet S3 demand today: ZERO.** Repo-wide `s3` scan: the only matches are a blocklist URL example (dns-blocker.nix:545) and a `pass3` md5 false positive. atticd (the only object-store-shaped consumer) is deliberately pool-native local (`/mnt/pool/services/atticd/storage`, docs/services/atticd.md). Loki/SigNoz/Immich/Paperless all run local storage.
- **OpenCloud × S3 IS architecturally wired**: storage driver matrix `posix` | `decomposed` | `decomposeds3` | `owncloudsql` (upstream source, tests/acceptance + compose; env-selected at runtime, no build-tag gating in the nixpkgs binary). `decomposeds3` = DecomposedFS metadata tree stays LOCAL posix while file blobs go to the S3 backend — free community edition, CI-exercised in upstream acceptance tests.

### The three readings, answered

1. **"vs" for the cloud-drive gap → RustFS does not compete.** It is infrastructure (buckets + IAM for PROGRAMS), not a product: no sync clients, no human sharing model, no trash/versions UX, no Spaces. Choosing RustFS "instead of" OpenCloud leaves the actual gap (interactive private drive) unfilled — you would still need the access layer, which is what OpenCloud is.
2. **"with" (OpenCloud → decomposeds3 → RustFS) → net loss on THIS box.** (a) Single node: EC distribution is RustFS's point; SNSD mode is just an S3 API over one path — zero durability gained over BTRFS+snapshots+Borg. (b) Kills the plain-files doctrine: blobs become opaque objects + a second local metadata tree — the exact reason Seafile was dismissed. (c) Two stateful services, two port/secret/backup/monitor surfaces instead of one, plus a loopback S3 hop on every byte. (d) The pool is the slow tier by design. When chaining WOULD be right: multi-node scale-out or an existing S3 estate to reuse — neither exists here.
3. **"RustFS standalone" → not now, designated later.** No consumer exists (verified). Adopting it speculatively is the YAGNI class this repo forbids. The day a real S3 need appears (atticd S3 offload of the pool, restic/Borg offsite diversification via S3 target, ML artifact storage, a future service demanding S3), RustFS is the OBVIOUS pick over MinIO here: Apache-2.0, no telemetry posture concerns, nixpkgs-native module+VM-test at our pin. Record kept via the updated [decision] row.

### Net effect on the main verdict

None — the recommendation is unchanged (pilot-adopt OpenCloud on the production line, posix driver, stateDir on the pool). RustFS is neither a blocker nor a dependency; it is a future building block with its adoption path pre-verified.

