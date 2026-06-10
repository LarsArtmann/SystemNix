# SystemNix TODO List

**Updated:** 2026-06-11 (session 131)

---

## Active Tasks

### Priority 0: Fix Broken Services

- [ ] **Fix Monitor365 DB path** — `unable to open database file`, both agent + server crash-looping. Investigate `stateDir`, add tmpfiles rule for parent directory, verify SQLite path in the Rust binary's config
- [ ] **Fix aw-watcher-window-wayland startup race** — panics `Failed to connect to wayland display` before compositor ready. The watcher is configured via `services.activitywatch.watchers` in `platforms/common/programs/activitywatch.nix` — upstream HM module sets `After = ["activitywatch.service"]` but doesn't include `graphical-session.target`
- [ ] **Fix Twenty CRM intermittent 502s** — Caddy logs show `connection refused`/`connection reset` on port 3200. Likely container OOM or PG connection exhaustion. Run `docker logs twenty-server-1 --tail=100` on evo-x2

### Priority 1: Manual Steps (Blocked on Human)

- [ ] **Hermes: add OpenAI API key to sops** — `sops platforms/nixos/secrets/hermes.yaml`, add `openai_api_key`. Nix config already wired
- [ ] **Hermes: install SSH deploy key** — private key from `scripts/hermes-setup/id_ed25519` to `/home/hermes/.ssh/id_ed25519`, add public key to GitHub deploy keys
- [ ] **Hermes: set fallback model** — `sudo -u hermes hermes config set fallback_model openrouter/gpt-4o`
- [ ] **Pocket ID SMTP** — Wire SES or Resend SMTP credentials. SES infra exists in `domains` repo. Pocket ID supports `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD` env vars. Add to sops + pocket-id.nix settings

### Priority 2: Verify Deployed Changes

- [ ] **Reboot evo-x2** — verify boot time after NVMe APST fix + Caddy sops ordering fix. Target: ~35s (was 6m17s)
- [ ] **Verify Pocket ID OTel fix** — confirm no more `https://localhost:4318` log spam after `OTEL_METRICS_EXPORTER=prometheus` setting
- [ ] **Verify Caddy boot ordering** — confirm Caddy starts after sops-nix on reboot (no cert-not-found errors)
- [ ] **Verify DNS A records** — `dig status.home.lan`, `dig seo.home.lan`, `dig daily.home.lan`, `dig logs.home.lan`, `dig monitor.home.lan` should resolve
- [ ] **Audit Gatus health checks** — 6 services show DOWN with possibly wrong check URLs (SigNoz port 8080 root path, Immich `/api/server-info/ping`, Crush Daily `/api/health`, Ollama `/api/tags`, Monitor365 port 3001 root path)

### Priority 3: Infrastructure

- [ ] **BTRFS `/data` subvolume migration** — `just snapshot-migrate-data`. Currently toplevel (subvolid=5), no snapshot protection for Docker/Immich/AI data
- [ ] **Add weekly Nix GC timer** — prevent root disk from creeping back to 95%. `nix-collect-garbage -d` was run manually this session
- [ ] **PostgreSQL collation fix** — `ALTER DATABASE postgres REFRESH COLLATION VERSION;` in Twenty CRM's postgres container. Silences 15,000+ log lines/day
- [ ] **Swap investigation** — 8 GiB swap used on 128 GiB RAM. Run `smem -t -k | tail -20` and `swapoff -a && swapon -a`

### Priority 4: Documentation

- [ ] **Archive old status reports** — move pre-session-100 from `docs/status/` to `docs/status/archive/` (177 → ~30 files)
- [ ] **Create ROADMAP.md** — consolidate `docs/planning/` into single living doc
- [ ] **Create CHANGELOG.md** — 185 commits in 2 weeks with no changelog

### Priority 5: Long-Term

- [ ] **Provision Pi 3** for DNS failover cluster — hardware required
- [ ] **Auditd enablement** — blocked on NixOS 26.05 bug #483085
- [ ] **AppArmor enablement** — commented out in security-hardening.nix
- [ ] **Darwin Home Manager parity** — disk constrained (256GB, 90%+ full)
- [ ] **Monitor365 agent→server auth** — no auth, anyone on LAN can POST data
- [ ] **Disabled service triage** — voice-agents, minecraft, photomap: decide enable or remove
- [ ] **Split large modules** — monitor365 (716L), signoz (705L), forgejo (583L)

---

## Completed (session 131)

- [x] **Fix Caddy boot ordering** — `wants = ["sops-nix.service"]` + `after` prevents 14-hour outage recurrence
- [x] **Fix DNS A records for 5 subdomains** — status, seo, daily, logs, monitor added to both primary + RPi3 DNS
- [x] **Fix Pocket ID OTel log spam** — `OTEL_METRICS_EXPORTER=prometheus`, `OTEL_TRACES_EXPORTER=none`, `OTEL_LOGS_EXPORTER=none`
- [x] **Guard ALL sops secrets with optionalAttrs** — hermes, crush-daily, openseo, monitor365, signoz, voice-agents secrets + templates now wrapped in `lib.optionalAttrs config.services.X.enable`
- [x] **Root disk cleanup** — `nix-collect-garbage -d` run by user

## Completed (session 130)

- [x] **Homepage Dashboard YAML rewrite** — `mkGroup`/`mkService` helpers, ALLOWED_HOSTS, cache dir
- [x] **Manifest behind auth** — moved to `protectedVHost`
- [x] **Hermes icon fix** — `ai.png` → `hermes-icon.png`

## Completed (session 129)

- [x] **Pocket ID provision: header casing + URL encoding + race conditions** — fully working
- [x] **QDirStat** — Qt disk usage analyzer added
- [x] **NVMe APST boot delay fix** — `nvme_core.default_ps_max_latency_us=0` kernel param

## Completed (session 128)

- [x] **sops atomic failure fix** — discordsync owner blocked ALL secrets, wrapped with optionalAttrs
- [x] **SigNoz decoupled from boot** — custom `signoz.target`, ~2m faster boot
- [x] **SigNoz JWT auto-generation** — wrapper script on first start
- [x] **Crash-loop protection** — `startLimitBurst = 5` on 9 services
- [x] **notify-failure %i fix** — specifier passed as script argument
- [x] **plugdev group** — eliminated 36 udev warnings
- [x] **Deprecated amdgpu.gttsize removed**
- [x] **ClickHouse ports centralized** in lib/ports.nix
- [x] **Overview package build** — mkPreparedSource with 9 private Go repos
- [x] **Discordsync enabled** + bot token regenerated

## Completed (session 122)

- [x] Configure secondary LLM provider for hermes (Nix wiring done, manual sops step remaining)
- [x] Hermes git remote access (SSH key generated, manual install remaining)
- [x] nix-colors integration (164 colors migrated)
- [x] Create `just status` command
- [x] Create post-deploy verification script (`scripts/verify-deployment.sh`) + `just verify`
- [x] Per-threshold SigNoz channel routing
- [x] Flake inputs audit (45 inputs, all used)
- [x] Darwin home.nix parity (terminal, editor, theme, xdg)
