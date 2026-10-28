# dnsblockd (DNS) — Agent Notes

> Module: `modules/nixos/services/dns-blocker.nix`. Body migrated verbatim from AGENTS.md on 2026-10-01 (restructure) — treat the section below as authoritative agent notes for this service.

**DataDir on the Samsung hot tier since 2026-10-14** (`services.hot-db.entries.dnsblockd` — wave 2; runbook `docs/services/hot-db.md`; the QLC original sits shadowed under the mountpoint as soak-end rollback insurance).

**Integration verdict (2026-10-28 architecture review, 3.57/5 "Good" — NOT superb):** operator-grade depth (runbook, measured readiness budget, OOM immunity, 5-layer monitoring, 22 negative-tested assertions, 0 phantom options) capped by one structural decision — `dns-blocker.nix` re-implements the config schema of a service that ships its own NixOS module (`nixosModules.dnsblockd`, 2,224 lines + 2 VM tests) at the rev already locked, so the live config carries **57 of ~110 upstream keys**. Two concrete defects came out of that review: the `dnsblockd-wait-listener` gate polls the **block-page port (:80, TCP)** rather than the DNS contract (:53 UDP+TCP), and the binary's own `sdnotify.Ready()` (the true readiness signal) is unused because the wrapper forces `Type = "simple"`. Full evidence, scores, and roadmap: `docs/architecture-understanding/2026-10-28_10-18_dnsblockd-integration.html`; queue rows in `docs/todo/services.md`.

## DNS (dnsblockd)

- **dnsblockd is the SOLE DNS resolver on :53** — Replaces unbound entirely. Embedded sdns handles DNSSEC, DoT/DoH, local zones, blocklists. "Sole" is per-host: rpi3-dns runs the same module and serves as the VRRP failover peer — see the second-host coverage section below for what that does and does not page.
- **dnsblockd is oomd-exempt + kernel-OOM-last (2026-09-06)** — `ManagedOOMPreference = "omit"` + `OOMScoreAdjust = -1000` on the unit (nix-daemon critical-infrastructure doctrine; the long-standing P0 closed). It was oomd-killed 730×/day at the old 50%/20s threshold; the 60%/30s threshold + MemoryMax=4G + GOMEMLIMIT=3GiB tamed it, but oomd still ranked it by memory.current under /system.slice PSI >60%/30s. A kill costs ~2min of DNS while the 3.9M-entry blocklist reloads, a kill loop hits StartLimitBurst → dead sole resolver, and DNS death cascades (local zones, deploy-blocking `cache.home.lan` resolution 2026-09-02 class, sev1/Discord alerting blind).
- **Stats API (:9090) wedge under IO starvation — mechanism CONFIRMED 2026-09-06, fix PUSHED and DEPLOYED (corrected 2026-09-13: the earlier "implemented upstream (unpushed)" claim was stale — the cached-response healthHandler is on dnsblockd origin AND is an ancestor of SystemNix lock rev `94c9cb93`, the deployed `dnsblockd-94c9cb9` binary; verified via `internal/server/health.go:97` calling `CachedResponse()` + merge-base ancestry)** — `/health` called `healthProbe.Evaluate(r.Context())` INLINE: go-health's Evaluate runs the tracking-DB `PingContext` synchronously on the request path, and under extreme IO PSI the 4-conn sqlite pool is starved by stalled batch-writer flushes → the handler wedges mid-request (CLOSE_WAIT) for as long as the pool stays starved. Wedged twice (2026-08-27, 2026-09-06); DNS itself kept resolving both times. **2026-09-06 forensics:** SIGTERM 09:15:09 progressed ("stopped data retention cleanup loop" 09:15:19) then hung 80s in batch-writer flush/DB close → `stop-sigterm` timeout → SIGKILL 09:16:39 (unit stats: 1.1G mem peak, 1.5G read/669M written over 2h). NO goroutine dump captured (runbook not used — evidence lost; ALWAYS run `scripts/dnsblockd-goroutine-dump.sh` before restarting a wedged instance). /metrics analysis: its collectors are all in-memory (promhttp over Go/Process/OTel — no DB); the tracking middleware dispatches post-response; the stats server's 30s WriteTimeout kills wedged CONNECTIONS but the handler GOROUTINES leak until the DB unsticks — CLOSE_WAIT pileup is clients closing before the server's 30s. **Upstream fix (dnsblockd, 2026-09-06, in the deployed lock rev):** healthHandler serves go-health's background cache (`CachedResponse()`, refreshed every 1s by the probe loop, each batch bounded by the 5s go-health timeout) instead of inline Evaluate; a staleness guard (>15s = background loop itself wedged) flips the response to 503 + failed database check so monitors see RED instead of a hanging endpoint; no-cache fallback (pre-Start) is one timeout-bounded live eval. Regression tests: burst-requests-serve-from-cache (eval counter must not advance per-request), stale-cache-serves-503-fast, pure degradeStaleHealth table. go-health's own ReadinessHandler already had this cache-first design — only dnsblockd's rich /health bypassed it. No dedicated release tag carries it yet (tag-pinning consumers would miss both this and the OTLP scheme fix; cutting one is tracked in docs/todo/upstream.md). **SUPERSEDED 2026-09-30: upstream v0.9.3 (released 2026-09-30) carries everything — the queued tag-cutting TODO is satisfiable and the tag-pin vs follow-master decision is unblocked; the lock moved past it to `f625cfee` (v0.9.3-73, the 2026-09-30 max-adoption wave; M11 deploy system-810 anchored), a descendant of `94c9cb93`, so both fixes remain deployed (live unit ExecStart = `dnsblockd-f625cfe`, live /health `version = f625cfe`, verified 2026-09-30).** Post-deploy live behavior confirmation (cache-served responses, fast 503 on staleness) still pending — docs/todo/services.md dnsblockd live-probe items. Detection layers that worked 2026-09-06: SigNoz "DNS Blocker Stats API Wedged" rule + `system_dnsblockd_metrics_fresh` gauge + Gatus check. The 2026-08-27 residual (deploy.sh dnsblockd-restart block not firing despite active bridge — unexplained) still stands; do not rely on it. Root driver: the ONE-USB-LINK IO storm class (2026-09-06: uncoordinated parallel agent sessions building/testing through `/mnt/buildcache` + pool sends on one link — IO PSI some avg10 hit 98.9%, load 722, 704 D-threads); heavy jobs must ride the `heavy-job` wrapper (workload-admission.nix), never raw `go test`/`cargo nextest` storms.
- **Max-adoption wave DEPLOYED LIVE 2026-09-30 (lock rev `f625cfee` = v0.9.3-73, plan `docs/planning/archived/2026-09-30_12-13_DNSBLOCKD-MAX-ADOPTION.md`; system-810 anchored)** — six config surfaces shipped at once, all verified in the deployed YAML + guarded by post-deploy smoke probes (config-path greps extracted from the RUNNING unit's ExecStart + a behavioral csrf probe; negative-proven against the pre-wave config `p6s93ln6`): (1) **allowlist persistence** — `allowlist_path = /var/lib/dnsblockd/allowlist` closes the silent data-loss window where every restart dropped manual unblocks; (2) **`csrf_enabled = true`** — block-page forms + unsafe API methods (POST/PUT/PATCH/DELETE) require the double-submit csrf_token; the middleware chain wraps csrf OUTSIDE requireAuth, so a bare `POST /api/allow` answers 403 when armed and 401 when not — do NOT probe the block page for csrf form fields (the template emits csrf_token fields even with csrf disabled); (3) **device/user registry** — `services.dns-blocker.devices` (id/name/ips/group) + `.users` (name/devices) options with eval assertions (caps 256 devices / 16 ips per device, dup ids/IPs, dangling user refs, single-ownership); evo-x2 runs evo-x2/rpi3-dns/lan-router/macbook + user Lars (evo-x2 + macbook) — both original `owner-confirm` markers resolved by the owner: pixel6 (.29, MAC 2e:fd:a5) DECOMMISSIONED 2026-10-01 (entry removed), and the lg-tv guess (.62, Realtek 00:e0:4c) FALSIFIED 2026-10-04: .62 is Lars's MacBook Air via its USB ethernet adapter (the actual LG TV SSCR2 is evo-x2's DP-2 monitor, not a network client) — entry renamed `macbook` + added to user Lars (DEPLOYED — verified live in the running generation's YAML 2026-10-06; Wi-Fi IPs are NOT covered — add them if the Mac roams); historical rows under the old id were re-attributed manually 2026-10-06 (tracking.db: 7,294 `request_tracks` + 1 `device_weekly_snapshots` row `lg-tv`→`macbook`, transactional, residual scan 0; rollback artifact `~/dnsblockd-lg-tv-rename-rollback.json`); (4) **DNS rate limits 50 q/s burst 100** (evo-x2 only — DoS belt; rpi3 stays unlimited as failover); (5) **log sampling 500/100**; (6) **`extraDomains` wiring** — `platforms/common/dns-blocklists.nix` `extraDomains` renders a synthetic `systemnix-extra` hosts-format blocklist appended LAST (consumed by evo-x2 AND rpi3; zero-delta today — all 5 listed domains already blocked — but it is the declarative lever for future one-off blocks). Render contract pinned by `checks.x86_64-linux.dns-blocker-render` (`tests/test-dns-blocker-render.nix`, incl. an anti-phantom `mkForce [ ]` variant asserting the greps actually read rendered output). **tracking_mode stays METADATA_ONLY** — the flip to METADATA_AND_DNS (unlocks Top Domains/Query Log/Likely-Broken/device×domain views; no headers/payloads stored; retention 30d tracks) is owner-gated: decision memo `docs/services/dnsblockd-tracking-dial.md`; flipping requires owner sanction AND a same-commit update of the render test's tracking_mode assertion. Root recursion WORKS without forwarders since upstream `8e598c01` (T299) — the DoT forwarders (Cloudflare + Quad9) are a deliberate owner choice, not a workaround.
- **Operator WAL (journal) enabled in-tree 2026-10-07** — owner decision (the "evo-x2 enablement" open question from dnsblockd's 2026-10-06 WAL landing, its TODO T354/W24 precondition): `journal_enabled: true` + `journal_dsn: /var/lib/dnsblockd/journal.db` in the dns-blocker.nix generated YAML (engine sqlite / durability normal / query-log off / retention 30d ride upstream defaults — the validated sentinels; tracking gate satisfied by METADATA_ONLY > NO_TRACK). The WAL rides BESIDE the tracking tables: `audit_entries` stays the evidence doctrine, NOTHING serves analytics reads from the WAL (the W24 read-model cutover remains owner-gated upstream). Pinned by the render test's python asserts (`tests/test-dns-blocker-render.nix` — journal_enabled/journal_dsn greps on the REAL rendered YAML, the anti-phantom contract) and watched by the SigNoz rule `DNS Blocker Journal Dropping` (`_signoz-alerts.nix`, mirrors upstream `DnsblockdJournalDropping`: `increase(dnsblockd_journal_drops_total[15m]) > 10`; absence-safe — no series until the first drop). Applies to BOTH dns-blocker hosts (evo-x2 + rpi3-dns share the module YAML; rpi3 activates on its next deploy). Inspect: extract the config path from the live unit's ExecStart, then `<dnsblockd> journal status|replay --last N|verify -c <config>` (read-only open, safe on the live DB; `verify` folds WAL↔`audit_entries` parity). `/health` carries a `journal` block; metrics `dnsblockd_journal_appends_total{kind}` / `dnsblockd_journal_drops_total`. Deploy was weather-blocked 2026-10-07 (IO PSI 40-98%, freeze-precursor gate — parallel-session build churn, not this change) — activates on the first successful deploy after the storm; post-deploy live probes (journal.db created, journal status CLI, /health block, appends counter) still pending.
- **`dnsIPv6Enabled = false`** — evo-x2 has no global IPv6. Omits IPv6 root servers, avoids 5-15s timeouts.
- **Scoped filter proxy (ADR-0018) wired 2026-10-08, OFF on the host** — `dns-blocker.nix` now exposes `proxyFilterDomains` / `proxyInjectScriptURL` / `proxyInjectStripCSP` / `proxyTLSPassthrough` (upstream contract: ADR-0018 in the dnsblockd repo). Enabling = set `proxyFilterDomains` to registrable-domain suffixes (DNS answers them with the block IP — the "scoped lie"; precedence allowlist > filter > block) + `proxyInjectScriptURL` to the classifier's `/inject/filter.js`. The URL rides the `DNSBLOCKD_PROXY_INJECT_SCRIPT_URL` systemd env var, NEVER the YAML (store is world-readable — same rule as upstream's auth_token); render test pins both halves (`tests/test-dns-blocker-render.nix` item 7). Constraints: requires `dnsBlockResponse = "zero_ip"` (eval assertion mirrors upstream `ErrFilterNeedsAddressResponse` — a lie needs an address); filter domains NEVER TLS-splice (termination on the dnsblockd CA — devices must trust it, already true on evo-x2 via `security.pki.certificates`); the filter set is read at startup, changes restart the service; classifier down fails OPEN (pages render unfiltered, the lie still lands on the working proxy). Feature stays owner opt-in — picking domains + classifier is an owner decision.
- **Block-page PHANTOM-200: a "blocked" domain answers HTTP 200 with the block-page HTML — API clients fail with JSON-parse errors, never network errors (found live 2026-09-29 on `monitoring.googleapis.com`)** — blocklists classify parts of `googleapis.com` as telemetry; the SigNoz GCP integration's scrapes hit the block page until the domain was whitelisted in `platforms/common/dns-blocklists.nix`. When an HTTPS API integration mysteriously returns HTML: `dig +short <host> @127.0.0.1` — the block IP (192.168.1.200) vs a real answer is the whole diagnosis. **Second instance found live 2026-10-14:** GeoMetrikks's default public-IP echo `api64.ipify.org` (HaGeZi telemetry category) returned the block page, breaking the app's JSON parse → its `map-home-undetected` advisory; `ipify.org` is now whitelisted in `dns-blocklists.nix`.
- **Wildcard `*.home.lan` RESOLVES since 2026-10-12** (dnsblockd `d5a22a4b` fixed RFC 4592 lookup + owner-name synthesis; configured-but-dead 2026-10-07→10-12 while LocalZoneStore was exact-match only) — unknown zone names answer with the server IP so Caddy's `https://*.home.lan` catch-all serves the branded 404; exact records and the apex still win. Consequence (2026-10-17, live-diagnosed): any client with search-domain completion resolves FAILED public names (offline, or typo'd/NXDOMAIN while online) onto this host through the wildcard — evo-x2 + rpi3-dns therefore dropped the `search` line from their managed resolv.conf (`dns-resolver.nix`, 2026-10-17; bare-label typing like `ping forge` no longer resolves there, measured usage zero; TLS bare-label SNI never worked anyway). Other LAN clients (MacBook) own their resolver config — owner decision tracked in `docs/todo/services.md`. Diagnosis: dnsblockd repo `docs/research/2026-10-17_search-domain-wildcard-offline-resolution-diagnosis.md`
- **`restartTriggers` on dnsblockd** — Without it, config changes may not restart the process → stale config → DNS outage.
- **`ProtectSystem=strict` + SQLite** — Needs `WorkingDirectory` alongside `StateDirectory` or CANTOPEN errors.
- **Manual `/etc/resolv.conf` edits break local DNS** — Nix config writes static resolv.conf with `127.0.0.1` first and `9.9.9.9` as fallback, and NO `search` line (dropped 2026-10-17 — see the wildcard bullet above). Every deploy restores it. Do NOT reorder: `127.0.0.1` MUST be first so `*.home.lan` resolves via dnsblockd; `9.9.9.9` provides resilience when dnsblockd is down or slow
  - **2026-09-02 incident (the class, proven live):** during a NIC-vanish DNS outage the user `sudo nano`'d resolv.conf to `1.1.1.1` as a workaround; after the NIC self-recovered (03:24, no reboot) the leftover edit killed `*.home.lan` for ~10h while dnsblockd was HEALTHY on :53 — gatus stayed green because its "DNS Resolver" check probes `127.0.0.1` directly, never the system-resolver path (blind spot). Cascade: attic substituter `cache.home.lan` unresolvable → `nix flake check --no-build` prints `error: unable to download ... .narinfo` → pre-deploy gate step 1 greps ANY `error:` → **deploy blocked by the very deploy that would fix DNS (chicken-and-egg)**. Fixes shipped: (1) gate filter excludes narinfo-unreachability errors (infra noise, never syntax); (2) `system_local_dns_resolves` textfile metric (getent `auth.home.lan` through the SYSTEM resolver) + anchored gatus check "Local DNS System Resolver" closes the blind spot. Recovery runbook for the class: verify dnsblockd health first (`dig cache.home.lan @127.0.0.1 +short` must answer), then `nix run .#deploy` (activation rewrites resolv.conf) — never hand-edit it back under pressure without confirming dnsblockd actually resolves
- **Dashboard auth token via sops env** — `auth_token` is passed via `DNSBLOCKD_AUTH_TOKEN` EnvironmentFile (koanf env override), NOT the nix-store config YAML. The sops secret `dnsblockd_auth_token` is owned by `primaryUser:users` so the DMS DnsStatsWidget can read it for its `Authorization: Bearer` header. The sops template `dnsblockd-auth-env` (root-owned) feeds the systemd EnvironmentFile. Two renderings of the same key, different owners, different consumers. Protected routes: `/stats`, `/api/allow`, `/api/report`, `/api/cache/flush`. Unprotected: `/health`, `/metrics`, `/dashboard`, `/api/dashboard-data` (cookie-gated).
- **HaGeZi blocklists come from the GitLab mirror** (`gitlab.com/hagezi/mirror`), NOT GitHub — GitHub's automated fraud detection repeatedly locks `hagezi/dns-blocklists` (404s all 22 fetch derivations, blocking every deploy). Lists track the mirror's mutable `main` branch with SRI-hash pinning: content drift fails the build loudly; fresh blocklists require periodic hash refreshes

## Startup hang — 5-phase discriminator + playbook (2026-10-12 13:06 incident)

dnsblockd init logs `startup phase complete` after each of FIVE phases. A
wedged init stops silently mid-sequence: the process stays up, the unit reads
"active" (Type=simple marks active immediately after fork, so TimeoutStartSec
NEVER fires), retention/tracking keep running, and `:53` is dead host-wide —
with ZERO error lines. Silence is the symptom. Live instance: PID 4478 logged
phases 1-3 at 13:06:10 and nothing more until the manual restart 8 min later.

**Discriminator** — count phases of the CURRENT start (anchored on the unit's
own ActiveEnterTimestamp so restart-retries can't interleave phase lines —
a bare `| tail -5` over the boot reads FALSE-HEALTHY when the
wait-listener gate produces 3-phase failed starts next to retries):

```console
journalctl -u dnsblockd \
  --since "$(systemctl show -p ActiveEnterTimestamp --value dnsblockd)" \
  --no-pager | grep -c 'startup phase complete'
```

- **5 phases = healthy.** Reference timings (recovery start 13:14:05, PID
  101150): `config_load` 0-1ms → `otel_setup` 1ms → `extras_and_validation`
  ~1.6s → `server_init` ~10.5s → `listeners_start` ~3.9s; all listeners (`:53`
  UDP+TCP, block page `:80`/`:443`, stats `:9090`) up ~16s after ExecStart.
- **0-3 phases = THIS start is wedged or still climbing** (`config_load`,
  `otel_setup`, `extras_and_validation` only, plus the "started data
  retention cleanup loop" line, then silence past ~300s — the wait-listener
  budget kills the start job there): `:53` dead,
  `ss -lun | grep :53` empty, no error logged. Working hypothesis (unproven,
  deliberately unreproduced — each attempt risks another host-wide DNS
  window): retention-cleanup sqlite contention during init.

**Playbook:**

1. Confirm: discriminator count = 3 + no `:53` listener. Host-wide symptom
   check: `getent hosts auth.home.lan` empty; OIDC consumers degrade (crm
   passkey-only), gatus crash-loops on its OIDC gate (see below).
2. Forensics BEFORE restarting (the 13:06 instance left zero clues):
   `scripts/dnsblockd-goroutine-dump.sh` — same doctrine as the stats-wedge
   wedge (2026-09-06: runbook not used, evidence lost).
3. `sudo systemctl restart dnsblockd` — manual restart verified clean
   (13:14:05 → 5/5 phases, listeners up in ~16s).
4. Heal the collateral: one-shot OIDC discoverers (crm-server, dnsblockd's
   own `oidc_issuer`) need their OWN restart to re-run discovery; gatus
   un-freezes when `auth.home.lan` resolves again.

**Structural gate (2026-10-20, closes the silent-window class; budget re-sized
same day twice — 60s → 150s → 300s, each re-size journal-forced):**
`dnsblockd-wait-listener` ExecStartPost (dns-blocker.nix) polls
`ss -ltn` for the blockPort listener, 300s bounded (inside
`TimeoutStartSec=330s`; an eval assertion pins budget < envelope), fail-OPEN
if the probe tooling cannot run in the sandbox — a monitoring blind spot must
never kill the sole resolver. The budget is JOURNAL-MEASURED, not a guess:
the healthy start→listeners tail spans 61.5s to **255.5s** (2026-10-18
01:42:40 boot, `server_init` 246.4s blocklist load; second-worst 115.5s,
2026-10-19 04:05:12, `server_init` 109.8s; plus a 61-79s cluster on
10-18/10-19) — both the original 60s AND a first 150s re-size sat INSIDE that
distribution and would have killed the resolver mid-load → restart churn →
StartLimitBurst. A wedged init now FAILS
the start job → `Restart=always` (3s) retries + `notify-failure@` desktop
toast + `notify-failure-p0@` Discord page + the SigNoz `DNS Blocker Down`
rule (unit-state based) fires — wedge paging stays on the gatus/SigNoz legs
(~1-2 min), so the longer gate budget costs no paging latency. The
discriminator stays as the tripwire for recurrence-despite-gate.

**Monitoring coverage (what catches this):** gatus probes the resolver three
ways — "DNS Resolver" (DNS query via `127.0.0.1`), "DNS Resolver TCP"
(`tcp://127.0.0.1:53`), and the anchored "Local DNS System Resolver" check on
the `system_local_dns_resolves` textfile metric (system-health collector;
catches resolv.conf drift the direct probes cannot) — plus the SigNoz
`DNS Blocker Stats API Wedged` rule (fires when the `:9090` scrape dies) and
`DNS Blocker Down` (unit failed), the SigNoz `Local DNS Resolution Dead`
rule (2026-10-20: fires when `system_local_dns_resolves` drops — the
evaluator-surviving watch over the RESOLUTION PATH itself, added after this
incident). CAVEAT proven live 2026-10-12: gatus gates
its own start on OIDC (`auth.home.lan`) resolution, so a sole-resolver hang
kills the watcher with the watched — gatus ran ZERO checks during the 8-min
window (start attempt 13:06:08 → OIDC wait 300s → exit 13:11:09 → ready only
13:14:26, after the manual dnsblockd restart), and the SigNoz rule evaluator
went silent 13:03→13:17 (restart riding the same deploy). Only
`notify-failure@gatus.service` fired (one desktop toast, 13:11:10).
`Local DNS Resolution Dead` provisioned LIVE 2026-10-20 09:32:20 (HTTP 200,
signoz-provision, rode the 09:26 deploy); its metric rides the
system_health textfile — DARK while the recurring invalid-escape rejection
class (line-763 `\x2d` cgroup label, 4th incident 2026-10-20) is unfixed,
so the rule is provisioned-but-vacuous until then.

**Second-host coverage (rpi3-dns) — enumerated 2026-10-21, no second host needed today:** rpi3-dns runs the same dns-blocker module but has NO own gatus (gatus-config.nix is not imported there), NO own textfile collector (`system-health.nix` is not imported; SigNoz scrapes evo-x2 loopback only, so `system_local_dns_resolves` exists ONLY for evo-x2). What DOES watch rpi3's resolution path is `dns-failover.nix`'s keepalived `chk_dns` VRRP script — `host google.com 127.0.0.1` every 5s (fall 3 / rise 2) — but its only consumer is VRRP priority: rpi3 resolution death DEMOTES it and the VIP fails over to evo-x2, silently, with no page. The two-host contract this yields: (a) rpi3-only failure self-heals via failover and is deliberately unpaged; (b) sole-resolver death (both hosts, or evo-x2 alone as primary) IS paged by the `Local DNS Resolution Dead` rule on evo-x2's metric. Residual gap: `chk_dns` probes `google.com @127.0.0.1` directly, so a resolv.conf DRIFT on rpi3 (the 2026-09-02 class) trips nothing — no VRRP demotion, no telemetry, and rpi3's own processes lose `*.home.lan` while failover clients stay fine. Owner decision tracked as the [decision] row in docs/todo/monitoring.md (rpi3-local drift watch vs accepted gap).

> Section authored by the 2026-10-20 task-queue dispatch
> (Task-Queue-ID: 000001a156f950c763a19396d72200000000); the section body
> itself landed via daemon sweep `44b8339bb` mid-flight — re-associated here.
> Evidence transcripts: docs/status/ (batch report).

**NetBird tunnel-IP :53 hijack — queries addressed to the VPN IP never reach
dnsblockd (proven live 2026-10-23):** the netbird client (v0.77.1) runs its own
DNS-management layer that intercepts every `:53` packet DESTINED to the tunnel
address (`100.112.252.86`) — its embedded resolver serves only the
dashboard-configured matched domains and REFUSES everything else. Proof
matrix: `src=192.168.1.150 → dst=100.112.252.86 example.com` = REFUSED
(source-independent — even an allowlisted LAN source is refused), while
`src=100.112.252.86 → dst=192.168.1.200 example.com` = NOERROR with recursion
(dnsblockd happily serves 100.x sources). Consequences: (a) NetBird dashboard
nameserver groups must point at the LAN dnsblockd address (`192.168.1.53` VRRP
or `.150`) — the ratified split-horizon plan D5 was right — never at the
tunnel IP; (b) `dns_allowed_networks` gained `100.64.0.0/10`
(dns-blocker-config.nix, deployed 2026-10-23) so VPN queries routed WITHOUT
masquerade (phone's 100.x source preserved) pass the recursion ACL — with
masquerade they arrive as `.150` regardless; (c) netbird's host-manager leg
logs a harmless ERRO on every DNS update (`server.go:779`, cannot back up the
read-only NixOS `/etc/resolv.conf`) — the interception itself still works via
the firewall path; the errors are noise, not breakage (fired all day
2026-10-23 while the dashboard DNS config was being edited).


## Size profile (2026-10-27 storage audit S17; corrected 2026-10-28)

`/var/lib/dnsblockd` (Samsung `hot/dnsblockd` subvol, btrfs `compress=zstd:3` — CORRECT tier): journal.db 4.6G (operator WAL, 30d retention, enabled 2026-10-07 — expect ~2× growth to steady state), tracking.db 2.55G + WALs, `trust-anchor.db` + `trust-anchor-tombstones.db` (0600 root, small), temp-allowlist* legacy stubs. Growth does not threaten the QLC root.

**Retention is NOT all 30d** — the wrapper renders no `retention_*` keys, so upstream defaults apply: request tracks **30d**, aggregated metrics **90d**, block-rate trend **365d**, journal **30d**. Same table, with the decision context, in `docs/services/dnsblockd-tracking-dial.md`.

**Resolved anomaly (was open 2026-10-27):** the second tracking DB (`dnsblockd_tracking.db`, 724M) is GONE — a live probe 2026-10-28 10:14 shows exactly one `tracking.db`. The remainder of that reclaim (the `/data/tmp-crush-test` copy) was trashed 2026-10-26 (TODO_LIST close-out). Do not re-open the class without a fresh `ls`: the earlier "two DBs coexist" note outlived its subject by one day. **Source:** docs/status/2026-10-27_10-38_var-storage-tier-audit-status.md §F + live probe 2026-10-27 15:1x, re-probed 2026-10-28 10:14.
