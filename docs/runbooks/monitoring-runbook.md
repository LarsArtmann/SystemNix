# Monitoring Runbook

**What to do when each Discord alert fires.**

This runbook covers every Discord alert configured in `gatus-config.nix`.
When an alert fires, find the service name below and follow the steps.

---

## General Triage Steps

1. **Check if it's a deploy** — deploys cause transient failures. If you just ran `nix run .#deploy`, wait 2 minutes.
2. **Check Gatus dashboard** — `https://status.home.lan` shows all endpoint statuses and history.
3. **Check failed units** — `systemctl --failed` and `systemctl --user --failed`
4. **Check journal logs** — `journalctl -u <service-name> -n 50 --no-pager`

---

## Infrastructure

### Caddy reverse proxy down

- **Impact:** ALL services unreachable (Caddy is the gateway)
- **Fix:** `sudo systemctl restart caddy`
- **If persistent:** Check TLS certs — `ls -la /run/secrets/` for `dnsblockd_server_cert`/`dnsblockd_server_key`

### Pocket ID down — SSO broken

- **Impact:** No service login works (Forgejo, Immich, Gatus, all forward-auth services)
- **Fix:** `sudo systemctl restart pocket-id`
- **If persistent:** Check SQLite DB at `/var/lib/pocket-id/` — may need `pocket-id-provision.service` re-run

### oauth2-proxy down — all external service access broken

- **Impact:** External (non-LAN) access to all `protectedVHost` services fails
- **Fix:** `sudo systemctl restart oauth2-proxy`
- **Check:** Pocket ID must be healthy first (oauth2-proxy depends on it)

### Homepage dashboard down

- **Impact:** No visual dashboard for navigating services
- **Fix:** `sudo systemctl restart homepage-dashboard`
- **Note:** Homepage has no built-in auth — relies on Caddy forward-auth

### DNS Resolver down

- **Impact:** All DNS resolution fails, no service reachable by hostname
- **Fix:** `sudo systemctl restart dnsblockd`
- **If persistent:** Check `dnsblockd-attach-ip.service` — the block IP may not be attached. Also check `restartTriggers` ensure config changes propagate.

---

## Development

### Forgejo down — git forge unavailable

- **Fix:** `sudo systemctl restart forgejo`
- **Check:** SQLite DB at `/var/lib/forgejo/data/forgejo.db` — may need `sqlite3 ... "DELETE FROM migration_lock;"` if stale lock
- **Note:** Uses native OIDC (not forward-auth) — Caddy vHost is plain `reverse_proxy`

---

## Media

### Immich down — photo/video management unavailable

- **Fix:** `sudo docker compose -f /var/lib/immich/docker-compose.yml restart` (or check OCI containers)
- **Check:** PostgreSQL + Redis containers must be healthy first
- **GPU:** Check `/dev/dri/renderD128` exists for VA-API transcoding

---

## Productivity

### TaskChampion down — task sync unavailable

- **Fix:** `sudo systemctl restart taskchampion-sync-server`

### Twenty CRM down

- **Fix:** `sudo docker compose -f /var/lib/twenty/docker-compose.yml restart`
- **Check:** PostgreSQL container must be healthy

### Manifest down — LLM router unavailable

- **Fix:** `sudo systemctl restart manifest`

### OpenSEO down — SEO suite unavailable

- **Fix:** `sudo systemctl restart openseo`

### Crush Daily down — AI insights unavailable

- **Fix:** `sudo systemctl restart crush-daily`
- **Data access check:** Verify the service can read `/home/lars/.local/share/crush/.crush/crush.db`
  (the `ProtectHome=false` + `ReadOnlyPaths` override must be present)

---

## AI

### Ollama down — local AI unavailable

- **Note:** Ollama starts automatically with `ai-stack.enable = true`. Idle ollama uses ~34 MB RSS (models load on demand via OLLAMA_KEEP_ALIVE).
- **Fix:** `sudo systemctl start ollama`

### Hermes down — AI gateway unavailable

- **Fix:** `sudo systemctl restart hermes`
- **Manual steps:** May need SSH deploy key installed or fallback model set (see TODO_LIST.md)

---

## Monitoring

### SigNoz down — observability platform unavailable

- **Fix:** `sudo systemctl restart signoz` (triggers custom `signoz.target`)
- **Check:** All SigNoz components (query-service, frontend, alertmanager, otel-collector, clickhouse, clickhouse-keeper)
- **SQLite lock:** If `attempt to acquire lock failed`, run `sqlite3 /var/lib/signoz/signoz.db "DELETE FROM migration_lock;"`

### Gatus down — health monitoring unavailable

- **Fix:** `sudo systemctl restart gatus`
- **Note:** Gatus uses native OIDC via Pocket ID — must be healthy

### Dozzle down — container log viewing unavailable

- **Fix:** Restart the Dozzle container

### Monitor365 server down — device telemetry unavailable

- **Fix:** `sudo systemctl restart monitor365-server` (system service, not user)
- **Package check:** Verify it uses `pkgs.monitor365-server` (not `pkgs.monitor365` which is the agent CLI)
- **DuckDB WAL:** If crash-looping, the ExecStartPre heal script removes stale `.wal` files automatically

### Monitor365 server crash loop — start-limit-hit

- **Impact:** Server is completely down, agent circuit breaker opens, all telemetry buffered to disk
- **Root cause:** Usually DuckDB WAL corruption from unclean shutdown (OOM, WDT reset) or OOM under load
- **Fix:**
  ```bash
  sudo systemctl reset-failed monitor365-server
  sudo systemctl start monitor365-server
  ```
- **If it crash-loops again:** Check DuckDB WAL healing in ExecStartPre logs: `journalctl -u monitor365-server -n 50`
- **Nuclear option:** Delete the DuckDB file and restore from backup:
  ```bash
  sudo systemctl stop monitor365-server
  sudo rm /var/lib/monitor365-server/monitor365.duckdb
  sudo systemctl start monitor365-server  # ExecStartPre restores from latest backup
  ```

### Monitor365 buffer pressure — DuckDB exceeding memory budget

- **Impact:** Server approaching MemoryMax, risk of OOM kill under load
- **Fix:** Consider reducing data retention or increasing MemoryMax in the module config
- **Check DuckDB size:** `stat -c %s /var/lib/monitor365-server/monitor365.duckdb`
- **If consistently >1.6G:** The buffer cache is growing beyond the 2G MemoryMax. Increase `MemoryMax` in `monitor365.nix` or configure DuckDB `PRAGMA memory_limit='512M'`

### Monitor365 UI not serving — WASM dashboard missing

- **Root cause:** Server package missing UI artifacts (wrong package)
- **Fix:** Verify `cfg.server.package = pkgs.monitor365-server` in module config

### Overview dashboard down — project stats unavailable

- **Fix:** `sudo systemctl restart overview`

### Node Exporter / cAdvisor down

- **Impact:** Metrics collection gap (SigNoz dashboards will have holes)
- **Fix:** `sudo systemctl restart prometheus-node-exporter` / restart cAdvisor

### BTRFS disk space critical

- **Impact:** Imminent filesystem ENOSPC → I/O deadlock → WDT reset
- **Fix:** `sudo nix-collect-garbage -d`, `sudo nix store optimise`, check `btrfs filesystem df /`
- **Check device-unallocated:** `btrfs filesystem usage /` — if `<10%`, DO NOT run `nix-gc`
- **Emergency:** Grow partition (`sfdisk` → `partx` → `btrfs filesystem resize max /`)

### BTRFS snapshots stale — root filesystem unprotected

- **Impact:** No snapshot rollback available if root FS corrupts
- **Fix:** `sudo systemctl restart btrbk-root.service`

---

## Infrastructure (Extended)

### Redis down — Immich/CRM cache unavailable

- **Fix:** `sudo systemctl restart redis-immich` (or the Redis container)
- **Impact:** Immich ML and Twenty CRM will be slow/degraded

### DNS-over-TLS upstream unreachable

- **Impact:** DNS queries fall back to cleartext (ISP sees queries)
- **Fix:** Check internet connectivity — this is an upstream issue (Mullvad/Quad9 DoT endpoint)

### External HTTPS connectivity failed — possible ISP outage

- **Impact:** System can't reach the internet
- **Fix:** Check router, check `ip route`, check `ping 1.1.1.1`

### DiscordSync backup bot down — Discord messages not being captured

- **Fix:** `sudo systemctl restart discordsync`
- **Check:** Turso credentials in sops template, GCS bucket access if enabled

### EMEET PIXY daemon down — webcam auto-management broken

- **Fix:** `sudo systemctl restart emeet-pixyd`

### PostgreSQL backup failed

- **Impact:** No database recovery point
- **Fix:** Check `immich-db-backup`, `manifest-db-backup`, `twenty-db-backup` services
- **Manual:** `sudo systemctl start immich-db-backup.service`

### SSH brute-force detected

- **Impact:** fail2ban has banned IPs — legitimate access may be blocked
- **Fix:** `sudo fail2ban-client status sshd` to see banned IPs, `sudo fail2ban-client set sshd unbanip <ip>` to unblock

### GPU VRAM metrics missing

- **Impact:** Blind to GPU memory pressure (the GPUActive crisis)
- **Fix:** `sudo systemctl restart amdgpu-metrics.timer`
- **Check:** `/sys/class/drm/card*/device/mem_info_vram_used_bytes` exists

### GPUActive exceeds 60G — GTT buffer objects consuming excessive RAM

- **Impact:** GPUActive (GTT buffer objects) is the #1 RAM consumer on Strix Halo. At 60G+, only ~34G remains for all system processes.
- **Root cause:** Helium/Electron renderers, Quickshell Qt buffers, or Wayland compositor surfaces allocating GTT memory that cannot be reclaimed (GPUReclaim=0).
- **Diagnosis:**
  ```bash
  grep GPUActive /proc/meminfo
  grep GPUReclaim /proc/meminfo
  ```
- **Mitigation:**
  1. Close unnecessary Helium tabs/windows (each renderer holds GTT BOs)
  2. Restart Quickshell: `systemctl --user restart systemnix-quickshell.service`
  3. Check for runaway processes: `btop` sorted by memory
- **Long-term:** The TTM pool is configured with `pages_limit = 112 GiB` (exceeds visible RAM). Consider reducing this via kernel parameter or sysfs.

### user-1000.slice memory exceeds 40G — desktop memory pressure

- **Impact:** Desktop processes (Helium, DMS, niri) are consuming >40G. The slice has MemoryHigh=56G (throttle) and MemoryMax=64G (kill). At 40G+, the system is heading toward the OOM cascade chain.
- **The OOM cascade chain:** user processes grow → journald starved → sp5100-tco WDT fires (60s) → hard reset
- **Diagnosis:**
  ```bash
  systemctl show user-1000.slice -p MemoryCurrent -p MemoryHigh -p MemoryMax
  systemd-cgtop -n 1 /user.slice/user-1000.slice
  ```
- **Mitigation:**
  1. Close Helium tabs (each Chromium renderer can hold 500MB-2GB)
  2. Check for leaked processes: `ps aux --sort=-%mem | head -20`
  3. If chronic: the zram swap may be full (`swapon --show`). Consider increasing zram size or adding physical swap.

### PMA daemon down — automated project tracking stopped

- **Impact:** Projects Management Automation is not tracking git repos or running automations.
- **Fix:** `sudo systemctl restart projects-management-automation`
- **Common cause:** Type=notify timeout (upstream bug — overridden to Type=exec in SystemNix). If still cycling, check:
  ```bash
  journalctl -u projects-management-automation -n 50
  ```
- **Dependency:** Overview depends on PMA's discovery daemon. If PMA is down, Overview may OOM-loop trying local discovery.

### Service restart metrics missing

- **Impact:** Systemd health monitoring (crash-loop detection, restart counts) is disabled.
- **Fix:** `sudo systemctl restart system-health-metrics.timer`
- **Check:** The collector writes to `/var/lib/prometheus-node-exporter/textfile_collectors/system_health.prom`

---

## Recovery Procedures

### Full system recovery (after hard reset / OOM crash)

1. **Wait for boot** — systemd will auto-start everything
2. **Reset failed units:** `sudo systemctl reset-failed && systemctl --user reset-failed`
3. **Run post-deploy check:** `nix run .#post-deploy-check`
4. **Check critical services:** `systemctl status caddy pocket-id forgejo immich`
5. **Check BTRFS:** `btrfs device stats /` and `btrfs filesystem usage /`
6. **Check Nix store:** `nix-collect-garbage --dry-run` (check for space)

### Docker containerd corruption recovery

```bash
sudo systemctl stop docker
cd /data/docker/containerd/daemon/io.containerd.metadata.v1.bolt/
sudo mv meta.db meta.db.bak
sudo rm -rf /data/docker/containers/ /data/docker/containerd/ /data/docker/network/
sudo systemctl start docker
```

### SigNoz stale migration lock

```bash
sqlite3 /var/lib/signoz/signoz.db "DELETE FROM migration_lock;"
sudo systemctl restart signoz
```
