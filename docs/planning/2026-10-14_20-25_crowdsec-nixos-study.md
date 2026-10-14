# CrowdSec on NixOS — Adoption Study

**Date:** 2026-10-14 · **Feeds:** the `[decision]` row in [docs/todo/security.md](../todo/security.md) (CrowdSec adoption) · **Context:** GeoMetrikks' CrowdSec views are inert today (`docs/services/geometrikks.md`), and `geo.home.lan/settings/status` shows `CrowdSec = Disabled` because no LAPI exists on this host.

**Verification discipline:** every external claim below is marked verified (primary source + date) or labeled unverified. Sources: pinned nixpkgs store tree (`7fd4004d`, resolved via `nix flake metadata`), `gh issue view` against NixOS/nixpkgs (2026-10-14), raw upstream GeoMetrikks README (2026-10-14), hub.crowdsec.net collection pages (2026-10-14), and local repo/config reads.

---

## 1. What CrowdSec is (architecture in one paragraph)

CrowdSec is a fail2ban successor: an **agent** tails logs (files or journald), parses them with hub-provided parsers, runs leaky-bucket **scenarios** over parsed events, and records **decisions** (ban/captcha + duration) in a local SQLite DB. Decisions are served by the **LAPI** (Local API, `cscli` is its CLI). **Bouncers** poll the LAPI decision stream and ENFORCE — the firewall bouncer programs nftables/iptables sets. Separately, the **CAPI** (central API, api.crowdsec.net) pulls community-curated blocklists of known-bad IPs and (optionally, off by default) shares your alerts. The **hub** is a runtime-downloaded git collection of parsers/scenarios/collections (`crowdsecurity/caddy`, `crowdsecurity/linux`, …). GeoMetrikks is display/management only — it reads decisions and (with machine creds) creates them; it never blocks traffic itself.

## 2. What pinned nixpkgs ships (verified: store tree `7fd4004d`, 2026-10-14)

| Artifact | Version | Notes |
| --- | --- | --- |
| `pkgs.crowdsec` | 1.8.1 | agent + LAPI + `cscli` + notification plugins (slack, email, http, splunk, …) in one package |
| `pkgs.crowdsec-firewall-bouncer` | 0.0.38 | `cs-firewall-bouncer`, nftables/iptables/ipset modes |
| `services.crowdsec` module | nixos/modules/services/security/crowdsec.nix | 3 maintainers; full option surface (below) |
| `services.crowdsec-firewall-bouncer` module | …/crowdsec-firewall-bouncer.nix | assertions + registration oneshot + secret plumbing |

### `services.crowdsec` module shape (verified from source)

- **Declarative surface:** `localConfig.acquisitions` (file AND `source: journalctl` — journalctl source needs agent ≥1.7.4; we ship 1.8.1), `scenarios`, `parsers.{s00Raw,s01Parse,s02Enrich}` (parser whitelists live here), `postOverflows.s01Whitelist`, `contexts`, `notifications`, `profiles` (defaults: 4h IP+range bans), `hub.{collections,scenarios,parsers,postOverflows,appSecConfigs,appSecRules,branch}`, `settings.{general,lapi.credentialsFile,capi.credentialsFile,console.{tokenFile,configuration}}`.
- **Defaults:** SQLite + WAL at `/var/lib/crowdsec/state/crowdsec.db`; LAPI **disabled by default** (`api.server.enable = mkDefault false`), listens `127.0.0.1:8080` when enabled; Prometheus metrics `127.0.0.1:6060` (level `full`); service user joins `systemd-journal`; local scenario/parser files tmpfile-linked (`L+`) into `/etc/crowdsec/…`.
- **`cscli` wrapper in systemPackages:** re-execs as the crowdsec user via `sudo -u` — **requires `security.sudo.enable`** (aborts otherwise). SystemNix does not disable sudo (no `security.sudo.*`/`security.doas` lines in `platforms/` — verified 2026-10-14), so this works.
- **Setup script (`crowdsec-setup`, ExecStartPre of crowdsec.service):** runs `cscli hub update` **unconditionally on every start** (network + DNS required at boot), installs declarative hub lists, `cscli machine add --auto` when the LAPI server is on (this line interpolates `settings.lapi.credentialsFile` — enabling the LAPI server with it `null` is an **eval-time failure**, source-read inference from the interpolation site), `capi register` when a CAPI credentials file is configured, console enroll when a token file is configured.
- **`autoUpdateService`:** default OFF; when on, a daily `crowdsec-update-hub` oneshot+timer runs `cscli hub update` + `systemctl reload crowdsec`. NOTE: this timer does **not** gate the unconditional ExecStartPre hub update — two independent update paths.
- **Units:** `crowdsec.service` is `Type=notify`, `RestartSec=60`, heavily hardened upstream (ProtectSystem=strict, SystemCallFilter, CAP_SYSLOG, DynamicUser). Hub installs are **runtime-mutable state** in `/var/lib/crowdsec/state/hub` — the declarative lists only seed them.

### `services.crowdsec-firewall-bouncer` module shape (verified from source)

- **Mode default:** `nftables` iff `networking.nftables.enable`, else `iptables`. SystemNix sets neither (verified: no `nftables` refs in `platforms/`+`modules/`) → **iptables mode** with `CAP_NET_ADMIN`+`CAP_NET_RAW`; `createRulesets = true` (default) renders the blacklist chains; `ipset` mode + createRulesets is assertion-rejected.
- **Registration:** `registerBouncer.enable` (default: follows crowdsec.enable) runs a `crowdsec-firewall-bouncer-register` oneshot that creates the bouncer via `cscli bouncers add` at boot and stores the key in `/var/lib/crowdsec-firewall-bouncer-register/api-key.cred` (StateDirectory, 0700) → `LoadCredential` → `replace-secret` into a `/run` config. **No secret ever lands in the nix store.** Alternative for a REMOTE LAPI: `secrets.apiKeyPath` (mutually exclusive with auto-register).
- Boot ordering fixed upstream: `after`/`partOf` nftables/firewall service (this was nixpkgs #476253, now closed — fix visible in our pinned source).

## 3. Known module pain points (verified via `gh issue view`, 2026-10-14)

| Issue | State | Why it matters here |
| --- | --- | --- |
| [#445342](https://github.com/NixOS/nixpkgs/issues/445342) "sensible defaults so the module does not fail when simply enabling it" | OPEN | Confirms the defaults friction (LAPI off, credential paths, hub update at start). We would NOT "simply enable" — a real config avoids most of it. |
| [#520206](https://github.com/NixOS/nixpkgs/issues/520206) ExecStartPre hub update fails without network; cascades to bouncer-register EACCES | OPEN | The unconditional hub update at every start is verified in our pinned source (scriptArray). On this host: internet is present, but `crowdsec.service` has **no DNS-gate** — during the ~2 min dnsblockd boot window `cscli hub update` may transiently fail. RestartSec=60 + `Restart` (from the upstream packaged unit — unverified here) should recover; if not, the mitigation is a `mkDnsGate`-style ExecStartPre addition or hub.branch pinning. |
| [#476253](https://github.com/NixOS/nixpkgs/issues/476253) bouncer boot ordering | CLOSED (fixed) | Fix present in pinned source. |
| [#526506](https://github.com/NixOS/nixpkgs/issues/526506) bouncer auto-register broke after a 25.11→26.05 upgrade | OPEN | Upgrade-fragility class. We pin nixpkgs; the mitigation is running the register oneshot's own verification after bumps (its script already fails loudly). |
| #473707 / #476728 hub-update timer failures | referenced | Keep `autoUpdateService` off initially; hub updates then happen at service start only. |

**Maturity verdict:** usable-with-care, not set-and-forget. The two live traps for us are (a) the unconditional network-dependent hub update at start, and (b) version-bump fragility of auto-registration.

## 4. Fit on evo-x2 (verified local facts, 2026-10-14)

- **Ports:** LAPI default `8080` collides with SigNoz (`lib/ports.nix:34`) → move to `8082` (free, verified) via `settings.general.api.server.listen_uri = "127.0.0.1:${ports.crowdsec-lapi}"`; metrics `6060` free → registry as `crowdsec-metrics`. Both must land in `lib/ports.nix` (port-registry-audit is eval-enforced). Bind LAPI to loopback — GeoMetrikks and the bouncer are same-host; no `openFirewall`.
- **Log sources:**
  - Caddy: `/var/log/caddy/access.log` is `format json` with 100MiB×3 rolls + per-vhost files (verified `modules/nixos/services/caddy.nix:423`) → acquisition `filenames: [/var/log/caddy/*.log]`, `labels.type: caddy`, hub collection `crowdsecurity/caddy` (verified hub: caddy-logs parser + base-http-scenarios).
  - SSH: `crowdsecurity/linux` + journalctl acquisition (`_SYSTEMD_UNIT=sshd.service`, `labels.type: syslog`) — the module's own example; agent user is in `systemd-journal`.
- **Firewall backend:** iptables mode today; NOTE the pending `[decision]` row for an **nftables migration** in `docs/todo/security.md` — if that lands later, bouncer mode flips to nftables via the option default and its rulesets become declarative `networking.nftables.tables`. Sequence them consciously, not accidentally.
- **GeoMetrikks integration (env vars verified verbatim from upstream README, 2026-10-14):** `CROWDSEC_LAPI_URL` (+ `CROWDSEC_BOUNCER_API_KEY` = read-only Security page / Banned-IPs map / badges) and, to unlock ban/unban from the UI, `CROWDSEC_MACHINE_ID` + `CROWDSEC_MACHINE_PASSWORD` (`cscli machines add geometrikks --auto -f -`). `CROWDSEC_STREAM_POLL_INTERVAL` defaults 15s. Upstream explicitly: CrowdSec decides, GeoMetrikks manages, only a bouncer enforces.
- **Secrets path:** owner runs the two `cscli` commands interactively (sudo) and pastes the outputs into `platforms/nixos/secrets/geometrikks.yaml` via sops — NEVER on a command line (`fish_history` rule). Render into the geometrikks unit via sops template. Keep these env vars on the **geometrikks** unit (static user), not on crowdsec's DynamicUser units — `dynamic-user-audit.nix` cross-references DynamicUser with sops.
- **LAN false-positive trap (homelab-specific):** default profiles ban by IP, and Caddy acquisition sees LAN clients — a scanner-ish desktop could get itself (or the whole household) firewalled. Mitigation: parser whitelist in `localConfig.parsers.s02Enrich` for the LAN CIDR + own public IP, and/or start with `settings.simulation.simulation = true` (verified option; alerts without enforcement), and ban scope decisions before enabling the bouncer.
- **CAPI reachability:** outbound api.crowdsec.net — unverified whether HaGeZi/dnsblockd blocks it (ipify precedent); live-check and whitelist at implementation time.
- **Conventions checklist for the eventual module:** `services.integration.crowdsec` entry (subdomain n/a — loopback service; Gatus probe on the 6060 `/metrics` 200; registry-checks requirement applies), `services.catalog` entry, `services.signoz-coverage.expected` only if OTel env is set (upstream has no OTel — `wiring` gap n/a), gatus-coverage for the two new ports, memory cap via serviceConfig override (`MemoryMax` — upstream module declares none, so plain assignment wins), and a runbook `docs/services/crowdsec.md`.
- **Costs:** one more always-on agent (RAM footprint unverified — typical reports are ~50–200 MiB; cap with `MemoryMax`), SQLite WAL on QLC root (tiny, fine), hub mutable state (accepted drift surface; document `cscli` discipline in the runbook).

## 5. Recommendation + staged go-path

**Recommendation: adopt, staged, read-only first.** The marginal *enforcement* value on a LAN-bound homelab is modest; the real drivers are (1) unlocking GeoMetrikks' differentiating half (banned map, security page, ban/unban UI), (2) SSH brute-force visibility with community intel, (3) it is the prerequisite for any future exposure (net-vpn endgame, public endpoints). If none of those matter, do not adopt — an inert GeoMetrikks Security tab is honest today.

- **Stage 0 (decision):** owner picks scope — LAPI+agent only (display) vs + firewall bouncer (enforcement) vs simulation-only trial.
- **Stage 1:** `crowdsec.nix` module (agent+LAPI on `127.0.0.1:8082`, metrics `6060`, acquis: sshd journalctl + caddy files, collections `linux`+`caddy`, LAN whitelist, `autoUpdateService = false`, MemoryMax), ports, DNS-gate mitigation for the hub-update-on-start trap, gatus checks, runbook. Deploy. Verify LAPI up.
- **Stage 2:** owner-generated GeoMetrikks bouncer key → sops → env wiring; `CrowdSec = Enabled` (read-only) on geo settings.
- **Stage 3:** trial the firewall bouncer (iptables mode) — first with `simulation` on the agent, then real bans after a week of alert review.
- **Stage 4 (optional):** machine creds for geo ban/unban; CAPI pull; console enrollment.

## Verification status

| Claim | Status | Source |
| --- | --- | --- |
| `crowdsec` 1.8.1 / bouncer 0.0.38 in pinned nixpkgs | ✅ Verified | store `pkgs/by-name/cr/*` (rev `7fd4004d`), 2026-10-14 |
| Module option surface, defaults (LAPI off/8080, metrics 6060, sqlite+WAL, sudo-dependent cscli wrapper) | ✅ Verified | store `nixos/modules/services/security/crowdsec.nix`, read in full |
| Bouncer module shape (mode default, register oneshot, LoadCredential plumbing, assertions, nftables ordering) | ✅ Verified | store `nixos/modules/services/security/crowdsec-firewall-bouncer.nix`, read in full |
| Unconditional ExecStartPre hub update; autoUpdateService gates only the timer | ✅ Verified | same file (scriptArray + timers), corroborated by nixpkgs #520206 |
| Issue numbers/titles/states #445342 #520206 #476253 #526506 | ✅ Verified | `gh issue view` (2026-10-14) |
| GeoMetrikks env var names + semantics | ✅ Verified | raw upstream README (2026-10-14) |
| `crowdsecurity/caddy` + `crowdsecurity/linux` collections; journalctl source needs ≥1.7.4 | ✅ Verified | hub.crowdsec.net collection pages (2026-10-14); pkg.go.dev journalctl module |
| SigNoz owns 8080; 8081=crush-daily; 8082/6060 free; no nftables config; sudo not disabled; caddy json file logs | ✅ Verified | `lib/ports.nix`, repo grep, `caddy.nix:423` (2026-10-14) |
| CAPI reachability behind dnsblockd; agent RAM footprint; `Restart` on crowdsec.service | ❌ Unverified leads | live-check / unit-file read at implementation time |
