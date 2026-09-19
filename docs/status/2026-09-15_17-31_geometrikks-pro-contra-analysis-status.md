# Status Report: GeoMetrikks PRO/CONTRA Analysis Session

**Date:** 2026-09-15 17:31
**Session scope:** Research + recommendation on adding `github.com/GilbN/geometrikks` to SystemNix. NO code or config changes were made in this session — this report covers the analysis work, its gaps, and the decision path forward.

---

## a) FULLY DONE

| Item                                                                                                                                                                                                                                                                                                                                              | Evidence                                                                     | Scope         |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | ------------- |
| **GeoMetrikks README deep-read** — full feature set, Caddy/nginx/Traefik log formats, auth model (single-admin session, `APP_AUTH_DISABLED` option), MaxMind + CARTO credential requirements, CrowdSec integration, multi-source/agent mode, CLI backfill tooling, TimescaleDB/PostGIS storage requirement, WAL-sizing notes, PUID hardening path | Fetched `raw.githubusercontent.com/GilbN/geometrikks/main/README.md` in full | Analysis only |
| **Repo metadata pull** — 105★, MIT, created 2025-12-07, last push 2026-09-13, 6 open issues, Python (Litestar) + React, GHCR multi-arch (amd64/arm64), 3 forks, 1 subscriber, homepage geometrikks.dev                                                                                                                                            | `api.github.com/repos/GilbN/geometrikks` response                            | Analysis only |
| **PRO/CONTRA verdict delivered** — technically good citizen, strategically questionable; recommended DEFER unless (1) meaningful external traffic exists or (2) CrowdSec on-ramp is wanted; sketched the GO-path shape (mkDockerService compose + timescale container, Layer 2 vHost, pinned image, ioTier.background, tight memory caps)         | In-session answer                                                            | Analysis only |

**No repo mutations:** zero files changed, zero commits authored by this session. The auto-commit daemon's commits in the log are from other sessions — not this one.

---

## b) PARTIALLY DONE

| Item                             | What works                                                                                            | What remains                                                                                                                                                                                                                                                                                                                                                                                               | Blocker                                          | Effort         |
| -------------------------------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | -------------- |
| **Decision-input completeness**  | Core requirements, maturity signals, and integration cost are known                                   | Four inputs missing before a final GO/NO-GO: (1) contributor list / commit cadence — the "single maintainer" claim is unverified; (2) the 6 open issues unreviewed for known-broken areas; (3) resource sizing (TimescaleDB RAM/disk at homelab traffic volume); (4) **alternatives never evaluated** — notably GoAccess (in nixpkgs, file-based, zero DB) as the cheap option for plain traffic analytics | None — all are fetch-able in one pass            | S (total, ~1h) |
| **Caddy log-format feasibility** | GeoMetrikks parses Caddy native JSON natively (verified in README)                                    | Did NOT verify SystemNix's current Caddy access-log state (journald vs file output, rotation, existing consumers) — the "move logs off journald" blast radius is therefore unquantified                                                                                                                                                                                                                    | Needs a look at `caddy.nix` + journald consumers | S              |
| **CrowdSec value assessment**    | Integration mechanics understood (LAPI bouncer read-only + machine creds for ban/unban, audit-logged) | Whether CrowdSec itself is (or should be) on the homelab roadmap is an owner decision — without it, roughly half of GeoMetrikks' differentiating value evaporates                                                                                                                                                                                                                                          | Owner question (see g)                           | —              |

---

## c) NOT STARTED

All of the following are **contingent on the GO decision** (none started — deliberately, per the DEFER verdict; listed so the GO path is fully scoped):

- Service module (`modules/nixos/services/geometrikks.nix`, mkDockerService: app + timescale/postgis containers)
- Image pin + digest in `lib/images.nix`; port in `lib/ports.nix`; DNS entry in `dns-local.nix`
- `services.integration.geometrikks` registry entry (vHost, Gatus, homepage tile, system-health, signoz-coverage decision)
- Caddy access-log file output + `log_append upstream_duration_ms` + `trusted_proxies` for real client IPs
- sops file for `MAXMINDDB_USER_ID` / `MAXMINDDB_LICENSE_KEY` / `MAP_CARTO_API_KEY`
- Auth-mode decision: native session auth vs `APP_AUTH_DISABLED` behind `protectedVHost`
- Timescale retention tuning (`ANALYTICS_RAW_RETENTION_DAYS`), backup registration (backup-coordination + per-service subvolume doctrine decision)
- WebSocket (`/ws/live`, `/ws/crowdsec`, `/ws/logs`) proxy verification through Caddy
- post-deploy smoke section + `docs/services/geometrikks.md` runbook + AGENTS.md section

**Also not started (independent of GO):**

- GoAccess / lightweight-alternative evaluation
- Quantifying actual external (non-LAN) traffic share to judge whether a geo map has any payoff here

---

## d) TOTALLY FUCKED UP

**Nothing is broken** — no code, config, or repo state was touched. Radical honesty about the nearest misses instead:

| Item                                                                                                                                                                                                                                                                                                                                    | Severity                                                                                  | Root cause                                                               | Mitigation                                                                                                                                                                     |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Unverified external claim in the verdict**: asserted "single maintainer (GilbN of linuxserver.io)" without checking the contributors list or any fetched evidence. This is exactly the verify-external-claims class — the linuxserver association came from general knowledge, not this session's sources.                            | Low (analysis-only, no code landed on it)                                                 | Verdict written before the completeness pass                             | One `api.github.com/repos/.../contributors` call; correctness of the DEFER verdict does not hinge on it, but the claim should be confirmed before it's cited in a decision doc |
| **Analysis hole — cheapest alternative never named**: the CONTRA list gestured at "SigNoz covers traffic analytics" but did not name **GoAccess** (nixpkgs-native, file-based, zero DB, zero containers) — the obvious first candidate any evaluation should clear before recommending a TimescaleDB stack for a nice-to-have dashboard | Low (verdict still stands: "defer unless…" survives; GoAccess strengthens the DEFER case) | Evaluated the candidate in isolation instead of against the option space | Add to next-task list (f, item 2)                                                                                                                                              |

No data loss, no deploy risk, nothing blocking other work.

---

## e) WHAT WE SHOULD IMPROVE

| Pattern / practice                                                                                                                                                                         | Impact                                                                                                                    | Suggested fix                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Verdict-before-completeness**: the PRO/CONTRA was delivered the moment the two fetches returned, with open questions (maintainer bus factor, issues, sizing, alternatives) left implicit | Owner decisions get made on inputs that look complete but aren't; gaps surface only in hindsight (they did — this report) | A fixed pre-verdict checklist for any "evaluate service X" task: contributors/cadence, open issues scan, resource sizing, **alternative-space check (incl. nixpkgs-native options)**, current-infra blast radius (here: Caddy log format change). ~15 min, run BEFORE writing the verdict |
| **Candidate evaluated in isolation**                                                                                                                                                       | Led to missing GoAccess — recommending the heaviest tool that satisfies the need is a recurring failure mode              | Rule for future service evaluations: name the zero-dependency alternative first; the heavyweight candidate must justify the delta                                                                                                                                                         |
| **External-claim hygiene in analysis output**                                                                                                                                              | Unverified claims in verdicts can get quoted into decision docs (this one nearly was)                                     | Same discipline as verify-external-claims, applied to analysis prose, not just filed issues                                                                                                                                                                                               |

These three repeat across evaluations → candidate for a small "evaluate-candidate-service" skill/checklist (harvest ground).

---

## f) Next tasks (ranked by impact)

**Unconditional (decide/verify — do these regardless of GO/NO-GO):**

| #  | Task                                                                                                                                                          | Impact | Effort | Category      |
| -- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | ------------- |
| 1  | Verify GeoMetrikks bus factor: contributors list + commit cadence over its 9-month life                                                                       | Medium | S      | Quality       |
| 2  | Review the 6 open GeoMetrikks issues for known-broken areas / roadmap signals                                                                                 | Medium | S      | Quality       |
| 3  | Evaluate GoAccess (nixpkgs, zero-DB) as the lightweight traffic-analytics baseline; document why TimescaleDB stack is/isn't justified over it                 | High   | M      | Feature       |
| 4  | Verify SystemNix Caddy access-log current state (journald vs file, consumers, rotation) — prerequisite for ANY access-log analytics, GeoMetrikks or otherwise | High   | S      | Quality       |
| 5  | Quantify external vs LAN traffic share (from existing Caddy logs/SigNoz, no new tooling) to judge whether geo visualization has payoff at all                 | High   | S      | Quality       |
| 6  | Check whether SigNoz (existing OTel journald pipeline + Caddy metrics) can already answer top-URL/status/UA questions — closes the "overlap" CONTRA with data | Medium | M      | Quality       |
| 7  | Confirm image-update tooling compatibility: `scripts/check-image-updates.sh` digest-pinning policy for `ghcr.io/gilbn/geometrikks`                            | Low    | S      | Quality       |
| 8  | Estimate TimescaleDB container footprint (RAM/disk) at realistic homelab volume; sanity-check against the IO-fragile-QLC history                              | Medium | S      | Quality       |
| 9  | Decide DB home if GO: Docker volume on `/data` (btrfs) vs XFS hot-DB partition precedent (ClickHouse) vs HDD pool — per-service subvolume doctrine applies    | Medium | S      | Cleanup       |
| 10 | Record the final GO/NO-GO decision + revisit trigger in TODO_LIST (if NO-GO, this prevents re-litigating from scratch)                                        | Medium | S      | Documentation |

**Contingent GO-path work (only if GO):**

| #  | Task                                                                                                                                                                                                     | Impact | Effort    | Category      |
| -- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | --------- | ------------- |
| 11 | Create `modules/nixos/services/geometrikks.nix` (mkDockerService: app + timescaledb-postgis, pinned images)                                                                                              | High   | M         | Feature       |
| 12 | Pin app + DB image tag+digest in `lib/images.nix`                                                                                                                                                        | High   | S         | Feature       |
| 13 | Register port in `lib/ports.nix` (next free, e.g. ~8102)                                                                                                                                                 | High   | S         | Feature       |
| 14 | DNS entry `geometrikks` in `platforms/common/dns-local.nix`                                                                                                                                              | High   | S         | Feature       |
| 15 | `services.integration.geometrikks` registry entry: protected vHost, Gatus checks, homepage tile, system-health monitored units, signoz-coverage decision (binary lacks OTel → no env var, document skip) | High   | M         | Feature       |
| 16 | MaxMind GeoLite2 signup + license key (owner action, EULA acceptance) — hard gate: ingestion does not start without it                                                                                   | High   | S (owner) | Feature       |
| 17 | CARTO basemap API key signup (owner action; key is public-facing by design) — gate for the map tiles                                                                                                     | Medium | S (owner) | Feature       |
| 18 | sops file `platforms/nixos/secrets/geometrikks.yaml` (maxmind user/key, carto key, optional crowdsec creds) + `sops-key-audit` wiring                                                                    | High   | S         | Feature       |
| 19 | Caddy: add `log output file` JSON + `log_append upstream_duration_ms` to relevant vHosts; quantify journald-consumer impact first (task 4)                                                               | High   | M         | Feature       |
| 20 | Caddy `trusted_proxies` real-IP config so logged `client_ip` is the visitor, not a hop                                                                                                                   | High   | S         | Feature       |
| 21 | Auth-mode decision: keep native single-admin auth vs `APP_AUTH_DISABLED=true` behind `protectedVHost` (note: no login rate limiting either way — LAN-only exposure is the mitigations)                   | Medium | S         | Feature       |
| 22 | Decide exposure: LAN-only (no external vHost → geo map only matters if task 5 shows external traffic) vs protected vHost                                                                                 | Medium | S         | Feature       |
| 23 | Systemd/compose hardening per mkDockerService: `restart = "always"` on BOTH containers, mem limits (app ~512M, timescale 1-2G), IO tiering                                                               | High   | S         | Feature       |
| 24 | Timescale retention: set `ANALYTICS_RAW_RETENTION_DAYS` deliberately (default 180d is generous for homelab)                                                                                              | Medium | S         | Feature       |
| 25 | Backup registration: pg_dump of geometrikks DB in backup-coordination (staggered slot) + pool dir via mount-gated oneshot (226-class prevention)                                                         | Medium | M         | Feature       |
| 26 | WebSocket proxy check: `/ws/live`, `/ws/crowdsec`, `/ws/logs` through Caddy (upgrade headers) — Gatus can't see WS deadness, note in runbook                                                             | Medium | S         | Quality       |
| 27 | Gatus: `/health` (liveness) + `/health/ready` (readiness — 503 during schema wait; prevents phantom-green during cold start)                                                                             | High   | S         | Feature       |
| 28 | Handle geo-degraded state: app runs but ingestion is stopped without MaxMind db — Gatus must not phantom-green (the "connected ≠ valid" InboxClean class)                                                | High   | S         | Quality       |
| 29 | post-deploy-check smoke section: `/health` 200, login page renders, ingestion producing rows                                                                                                             | Medium | S         | Quality       |
| 30 | Runbook `docs/services/geometrikks.md` (credentials, backfill CLI, retention, ban of `--force` double-count trap on live-tailed files)                                                                   | Medium | S         | Documentation |
| 31 | AGENTS.md section: verdict rationale, resource notes, credential gates, the "import-logs double-counts live-tailed files" trap                                                                           | Medium | S         | Documentation |
| 32 | Verify container runs as non-root (PUID path vs `user:` override) and read-only log mount works against Caddy's file permissions                                                                         | Medium | S         | Quality       |
| 33 | VM/eval test decision: docker-service precedent (twenty/manifest style) — likely eval-only + smoke, no VM test                                                                                           | Low    | S         | Quality       |
| 34 | Agent-mode (multi-host) explicitly ruled out for single-box homelab — document                                                                                                                           | Low    | S         | Documentation |
| 35 | Privacy review: visitor IPs + geo stored in DB; confirm protected-vHost-only access + retention satisfy the homelab privacy bar                                                                          | Medium | S         | Quality       |
| 36 | Track releases: decide pin cadence (exact `X.Y.Z`) + who bumps (image-updates workflow issue-driven)                                                                                                     | Low    | S         | Cleanup       |

**Contingent CrowdSec-path (only if CrowdSec adoption is decided):**

| #  | Task                                                                                                                              | Impact | Effort | Category      |
| -- | --------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | ------------- |
| 37 | Evaluate CrowdSec adoption itself (engine + firewall bouncer on evo-x2) — GeoMetrikks is display/management only, not enforcement | High   | L      | Feature       |
| 38 | sops keys for `CROWDSEC_LAPI_URL` / bouncer key / machine creds; Gatus for LAPI reachability                                      | Medium | M      | Feature       |
| 39 | Ban/unban authorization review: with machine creds, the UI can ban IPs — confirm that surface is owner-only (protected vHost)     | Medium | S      | Quality       |
| 40 | Decide enforcement story: CrowdSec decides, a bouncer enforces — GeoMetrikks alone bans nothing                                   | Medium | S      | Documentation |

**Handoff note:** section (f) is the input for `docs-health` HARVEST into TODO_LIST/ROADMAP — items 1-10 and the decision record are TODO_LIST-grade; items 11+ stay ROADMAP until GO. Not harvested yet — awaiting instructions.

---

## g) Questions I cannot figure out myself

1. **Is there meaningful internet-facing traffic to visualize at all?** I did not probe live logs (out of session scope), but the deeper question is intent, not current state: is evo-x2 meant to serve meaningful external traffic (public services), or is it fundamentally a LAN box where a geo map would be mostly private-IP noise? This single answer likely decides GO/NO-GO.
2. **Is CrowdSec (or IP reputation/banning generally) on the homelab roadmap?** Roughly half of GeoMetrikks' differentiating value (Banned-IPs map, Security page, ban management) rides on it; without CrowdSec it's a prettier access-log viewer competing against GoAccess.
3. **What is the budget bar for a nice-to-have dashboard?** Is a second persistent database (TimescaleDB container: RAM + sustained per-request writes on the IO-fragile QLC/system disk) acceptable for a "cool map", or should nice-to-haves be restricted to zero-DB tooling unless they earn their keep?

---

_Point-in-time snapshot. Verdict as of this session: DEFER GeoMetrikks; run tasks 1-6 first; revisit with answers to (g)._
