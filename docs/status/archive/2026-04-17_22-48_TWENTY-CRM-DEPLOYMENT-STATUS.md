# Comprehensive Status Report — 2026-04-17 22:48

**System:** evo-x2 (NixOS 26.05, x86_64-linux, AMD Ryzen AI Max+ 395, 128GB)
**Reporting Agent:** Crush (GLM-5.1)
**Session Focus:** Twenty CRM self-hosted deployment on evo-x2

---

## A) Fully Done

### Twenty CRM Integration (Module + Wiring)

- **`modules/nixos/services/twenty.nix`** — New flake-parts service module created
  - Docker Compose with 4 containers: server, worker, PostgreSQL 16, Redis
  - Sops-managed secrets (`twenty_app_secret`, `twenty_db_password`)
  - Bind to `127.0.0.1:3200` (not exposed to LAN directly)
  - Daily database backup timer (`twenty-db-backup.timer`)
  - Tmpfiles rules create `/var/lib/twenty` and `/var/lib/twenty/backup`
  - Pre-start script writes `.env` from sops secrets
- **`flake.nix`** — Module imported and wired to evo-x2 nixosConfiguration
- **`configuration.nix`** — `services.twenty.enable = true`
- **`caddy.nix`** — `crm.home.lan` reverse proxy with Authelia forward auth → `localhost:3200`
- **`homepage.nix`** — Twenty CRM entry added to Productivity section with health monitor
- **`dns-blocker-config.nix`** — `crm` subdomain added to Unbound local DNS records
- **Secrets** — `twenty_app_secret` and `twenty_db_password` added to sops-encrypted `secrets.yaml`
- **Lint fixes** — Statix repeated-key warning resolved (merged `systemd` attr block)
- **All checks pass** — `just test-fast` green, pre-commit hooks pass (gitleaks, deadnix, statix, alejandra, flake check)

### Existing Services (Unchanged, Stable)

| Service        | Status  | URL                          |
| -------------- | ------- | ---------------------------- |
| Caddy          | Running | All `*.home.lan`             |
| Authelia       | Running | `auth.home.lan`              |
| Immich         | Running | `immich.home.lan`            |
| Gitea + Mirror | Running | `gitea.home.lan`             |
| SigNoz         | Running | `signoz.home.lan`            |
| Homepage       | Running | `dash.home.lan`              |
| PhotoMapAI     | Running | `photomap.home.lan`          |
| TaskChampion   | Running | `tasks.home.lan`             |
| Unbound DNS    | Running | `127.0.0.1:53`               |
| DNS Blocker    | Running | 25 blocklists, 2.5M+ domains |
| EMEET PIXY     | Running | User systemd service         |
| Docker         | Running | `/data/docker`               |

---

## B) Partially Done

### Twenty CRM — Running but PostgreSQL Container Failing

- **Root Cause:** `docker-compose` was not explicitly passed `--env-file ${stateDir}/.env`, so the `PG_DATABASE_PASSWORD` variable was never substituted into the compose YAML. PostgreSQL container logs show: `Database is uninitialized and superuser password is not specified.`
- **Fix Applied:** Added `--env-file ${stateDir}/.env` to both `ExecStart` and `ExecStop` in `twenty.nix`
- **Status:** Fix committed, **needs `just switch` to apply and verify**
- **After fix:** First start will pull Docker images (~2GB), initialize DB, run migrations, then server becomes available at `https://crm.home.lan`

---

## C) Not Started

1. **Twenty CRM workspace setup** — After containers are healthy, need to create first workspace at `https://crm.home.lan`
2. **Twenty CRM OAuth/SSO** — Integrate with Authelia for login (currently behind forward-auth but Twenty has its own auth)
3. **Twenty CRM email configuration** — SMTP setup for sending invites/notifications
4. **Twenty CRM data volume persistence** — Verify Docker named volumes survive `docker-compose down` and NixOS rebuilds
5. **Twenty CRM backup verification** — Confirm `twenty-db-backup.timer` runs and produces valid SQL dumps
6. **Twenty CRM monitoring** — Add to SigNoz tracing or at least basic health-check alerting
7. **Twenty CRM update strategy** — Currently pinned to `latest` tag; should pin to a specific version for reproducibility

---

## D) Totally Fucked Up

### Nothing critically broken outside of Twenty

- The Twenty deployment had two bugs hit in sequence:
  1. **Missing state directory** (`WorkingDirectory` didn't exist) → Fixed with `tmpfiles.rules`
  2. **Missing `--env-file`** → PostgreSQL couldn't initialize → Fix committed, pending deploy
- No other services were affected or degraded by these changes
- Both fixes were straightforward and caught during deployment, not in production

---

## E) What We Should Improve

### Twenty CRM Module

1. **Pin Docker image version** — `latest` tag is not reproducible. Should use a specific version like `v0.9.0` and update explicitly via flake input or version variable
2. **Use `--env-file` explicitly** — Already fixed in this session, but the pattern of relying on CWD `.env` auto-discovery was fragile
3. **Add `IS_CONFIG_VARIABLES_IN_DB_ENABLED=true`** — Enables admin-panel config changes without redeploy
4. **Disable dangerous features** — `LOGIC_FUNCTION_TYPE=DISABLED` and `CODE_INTERPRETER_TYPE=DISABLED` for production safety
5. **Consider S3 storage** — `STORAGE_TYPE=local` uses Docker volumes; S3 (MinIO?) would be more robust for production data

### General Infrastructure

6. **Replace `docker-compose` with native `docker run` or `oci-containers`** — NixOS has `virtualisation.oci-containers` which integrates better with systemd than wrapping docker-compose
7. **Centralize PostgreSQL** — Twenty, SigNoz (ClickHouse), and Immich each run their own DB. Consider a shared PostgreSQL instance with separate databases
8. **Add structured logging** — Twenty service logs go through docker-compose stdout; consider journald integration or Loki
9. **Secret ownership** — Twenty secrets owned by `root:root` but service also runs as root. Consider a dedicated `twenty` system user
10. **Sops access from user session** — Currently requires host SSH key (root-only) to edit secrets. Document or automate the workflow

### Development Workflow

11. **Status docs are accumulating** — 100+ files in `docs/status/`. Consider archiving older ones (there's an `archive/` dir but it's underused)
12. **Justfile missing Twenty commands** — No `just twenty-status`, `just twenty-logs`, `just twenty-backup` commands yet

---

## F) Top 25 Things We Should Get Done Next

### P0 — Immediate (This Session)

1. **Deploy Twenty fix** — `just switch` to apply `--env-file` fix, verify containers come up healthy
2. **Verify Twenty health** — Check `https://crm.home.lan/healthz` returns 200
3. **Create Twenty workspace** — First-time setup at `https://crm.home.lan`

### P1 — High Priority (Next Few Days)

4. **Pin Twenty Docker image version** — Replace `latest` with a specific tag
5. **Add `just twenty-*` commands** — status, logs, backup, restart to justfile
6. **Test Twenty backup timer** — Verify `twenty-db-backup.timer` produces valid SQL
7. **Add `IS_CONFIG_VARIABLES_IN_DB_ENABLED`** — Allow admin-panel configuration
8. **Verify Twenty survives `just switch`** — Docker named volumes should persist across NixOS rebuilds

### P2 — Medium Priority (This Week)

9. **Migrate Twenty to `virtualisation.oci-containers`** — Native NixOS pattern instead of docker-compose wrapper
10. **Add Authelia OIDC to Twenty** — Proper SSO instead of just forward-auth
11. **Twenty SMTP configuration** — Email for invites and notifications
12. **Twenty monitoring in SigNoz** — Add OTEL instrumentation or health-check alerts
13. **Archive old status docs** — Move pre-April status files to `docs/status/archive/`
14. **Centralized PostgreSQL** — Evaluate sharing one PG instance across services

### P3 — Nice to Have (This Month)

15. **MinIO/S3 for Twenty storage** — Object storage instead of Docker volumes
16. **Twenty worker health check** — Add healthcheck endpoint or watchdog for worker container
17. **Twenty CRM custom fields/views** — Configure CRM for actual use case (contacts, deals, pipeline)
18. **Add Twenty to Gitea mirror** — Mirror twenty-related config to self-hosted Gitea
19. **Twenty API documentation** — Document available endpoints for integrations
20. **Homepage service ping for Twenty** — Verify `crm.home.lan/healthz` works through Caddy+Authelia

### P4 — Future Consideration

21. **Evaluate Twenty alternatives** — If CRM needs grow, consider if Twenty is the right fit long-term
22. **Multi-workspace mode** — `IS_MULTIWORKSPACE_ENABLED=true` with wildcard DNS if needed
23. **Twenty mobile access** — Test via Tailscale or VPN for mobile CRM access
24. **Automated Twenty upgrades** — Renovate/Dependabot for Docker image version tracking
25. **Twenty data export plan** — Strategy for migrating data out if needed

---

## G) Top #1 Question I Cannot Figure Out Myself

**What is your actual CRM use case?** Twenty CRM is highly customizable — it supports contacts, companies, deals, tasks, notes, emails, calendar, workflows, and custom objects. To configure it properly after deployment, I need to know:

- Are you tracking **personal contacts**, **business leads**, or both?
- Do you need **deal pipeline stages** (e.g., Lead → Qualified → Proposal → Won/Lost)?
- Will you use the **email integration** (Gmail/Outlook) or keep it manual?
- Do you need **calendar sync**?
- Any **custom objects** beyond the defaults (e.g., projects, invoices, events)?

This determines what to configure after the first workspace is created — custom fields, views, permissions, and integrations.

---

## Commits This Session

| Commit      | Description                                                                       |
| ----------- | --------------------------------------------------------------------------------- |
| `976e954`   | feat(services): add Twenty CRM self-hosted service with Docker Compose deployment |
| `12775a7`   | style(twenty): merge repeated systemd attribute keys to fix statix lint           |
| `fb765a0`   | fix(twenty): create state directories via tmpfiles before service start           |
| _(pending)_ | fix(twenty): pass --env-file explicitly to docker-compose for DB password         |
