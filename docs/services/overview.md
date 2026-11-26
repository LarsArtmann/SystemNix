# overview (project discovery dashboard)

**Service:** `services.overview` — `modules/nixos/services/overview.nix` wrapping `inputs.overview.nixosModules.default` (upstream owns every option). Port 8083 (`lib/ports.nix`), loopback. URL: `overview.<domain>` (**Layer 2 protected** via the registry — no native auth). DNS `overview`.

Web dashboard over the project fleet (repos, stats, activity), fed by the **project-discovery daemon** — the standalone `project-discovery-daemon.service` owns the unix socket at `/run/project-discovery/daemon.sock` (2026-09-07 flip out of PMA; the flip's leftovers — overview's deps still pointing at PMA, PMA still co-declaring the socket's RuntimeDirectory — were completed 2026-10-08).

## What it serves

| Route             | Auth                    | What                                                  |
| ----------------- | ----------------------- | ----------------------------------------------------- |
| `/`               | forward-auth / open LAN | Project dashboard                                     |
| `/compliance`     | forward-auth / open LAN | BuildFlow compliance heatmap (repo × gate class)      |
| `/risk`           | forward-auth / open LAN | Code-risk hotspots (churn × complexity, worst first)  |
| `/api/compliance` | forward-auth / open LAN | JSON compliance snapshot (ETag, SSE-live)             |
| `/api/hotspot`    | forward-auth / open LAN | JSON hotspot snapshot (ETag, SSE-live)                |

## Compliance + code risk (enabled 2026-11-26)

Both upstream integrations are opt-in and were off on this host. They are now
wired in `configuration.nix` (`complianceSource`, `hotspotSource`) with the
support machinery in the wrapper module. The two legs have DIFFERENT shapes
because the overview service user (`overview`) cannot read the primary user's
0700 home:

- **Compliance — `file:` source (producer/consumer split).** The upstream
  `auto` source execs `buildflow compliance --json`, but BuildFlow's state DB
  lives in `~lars/.local/state/buildflow` — unreachable for `overview`, and a
  root-run producer would leave root-owned SQLite `-wal`/`-shm` files in the
  user's state dir. So `overview-compliance-evidence.service` (oneshot,
  `User=lars`, timer 15min after boot then every 6h) writes
  `/var/lib/overview-evidence/compliance.json`; overview reads it through
  `OVERVIEW_COMPLIANCE_SOURCE=file:/var/lib/overview-evidence/compliance.json`.
  The write is atomic (mktemp + `mv`): a partial file would flip the whole
  heatmap to Unknown. Evidence dir is (re)created by a `+`-privileged
  `install -d` on every run — NOT a tmpfiles rule (tmpfiles application has
  proven unreliable across switches, 2026-11-04). Window: `--since 14d`,
  `--stale-after 336h` matching the consumer's staleness threshold.
- **Code risk — in-process `auto` source.** go-hotspot analyzes ONE repo per
  invocation with `git log --numstat` over a year, against the ABSOLUTE paths
  the discovery daemon reports (`/home/lars/projects/...`). A service user
  cannot traverse the 0700 home, and home-dir ACLs are FORBIDDEN (the
  mask-recalc trap that silently killed hermes' access, 2026-08-20). Instead
  the unit gets `TemporaryFileSystem=/home/lars` + `BindReadOnlyPaths=
  [/home/lars/projects]` (with `ProtectHome=false`): a fresh tmpfs over the
  home containing ONLY the projects tree, so the discovered paths stay valid
  and nothing else from the home is exposed. `path = [ git ]` supplies the git
  the CLI shells out to, and `GIT_CONFIG_GLOBAL` points at a store gitconfig
  with `[safe] directory = *` (git ≥2.35.2 otherwise refuses foreign-owned
  work trees).
- **Cost knobs** — `hotspotRefreshInterval = 6h` (a full pass is ~293
  `git log --numstat` walks; measured 12.7s for SystemNix alone) and the unit
  runs at BE/6 (`ioTier.background`) so the fleet scan never contends with the
  desktop on the QLC root. `memoryMax = 2G` (4 concurrent analyses + the
  ~250MB dashboard).
- **Verify** — `journalctl -u overview-compliance-evidence` shows the pass;
  `stat /var/lib/overview-evidence/compliance.json` must be fresh and
  lars-owned. For code risk, `/risk` fills in one refresh AFTER a restart
  (first fetch is a background pass) — an empty matrix right after a deploy is
  expected, not a failure. `/proc/<overview-pid>/mountinfo` shows the
  tmpfs+bind pair.

## Ops

- **Daemon coupling (rewired 2026-10-08)** — `after`/`wants`/`partOf` `project-discovery-daemon.service` (the socket OWNER): daemon restarts bounce Overview and it re-discovers on start; PMA restarts no longer touch it (previously `partOf` PMA — an incomplete-2026-09-07-flip leftover that bounced overview on every PMA deploy/restart). The daemon socket mode is 0666 via `socketMode` in configuration.nix (a locked rev once ignored it — the readiness-gate lesson below).
- **Ghost-socket incident (2026-10-07 16:28 → 2026-10-08 ~19:40, ~26h crash-loop)** — PMA's upstream module still declared `RuntimeDirectory=project-discovery` (pre-flip leftover); PMA's deploy-stop flushed `/run/project-discovery/`, unlinking the LIVE daemon's socket, and PMA's restart recreated the dir empty. The daemon stayed `active` but unreachable → the (correct) 60s daemon-gate exit-1'd → restart loop to start-limit. Fix triple: PMA `RuntimeDirectory = lib.mkForce []` (exactly one dir owner), daemon `ExecStartPost` socket-existence start-contract, and systemd-shape-audit class 6 (eval-fails any RuntimeDirectory declared by more than one unit).
- **`overview-discovery-watchdog`** — periodic guard: Overview 503 + daemon `/v1/health` HEALTHY ⇒ restart overview (stale 503 discovery failure class). Both-unhealthy = wait (restart wouldn't help).
- **Readiness gates must probe AS THE SERVICE USER** — the `+`-privileged gate once passed green as root while the overview process got EACCES dialing the 0600 socket (the 2026-09-09 start-limit incident; now 0666 + daemon honors `PROJECT_DISCOVERY_SOCKET_MODE`).
- **OTel** — `OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4318` (mkDefault; upstream initializes the tracer from it — historically with zero span sites, so it sits in signoz-coverage as a known upstream gap).
- **Monitoring** — two Gatus checks via the registry entry: `Overview` (backend `http://localhost:8083`, liveness+HTML) and `Overview vHost` (`https://overview.<domain>/`, full chain — dnsblockd TLS + Caddy + LAN-bypass forward-auth + backend, title-anchored body; added 2026-11-23 after the 2026-10-07 outage showed the auth-gateway 502 class had no standing probe). The :8083 backend check itself PREDATES the outage (alert attached since the 2026-09-15 registry migration) — the outage's non-page is a DELIVERY question, not a coverage gap; evidence vacuumed, unadjudicable. Plus Homepage tile; partOf-chain restarts are expected churn, not incidents.

## Related

- [projects-management-automation.md](./projects-management-automation.md) — the discovery daemon + its watchdog/memory shape
- [papdashboard.md](./papdashboard.md) — the alerting hub (not the project view)
