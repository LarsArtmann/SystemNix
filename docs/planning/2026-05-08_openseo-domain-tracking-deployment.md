# OpenSEO — Domain Tracking & SEO Suite Deployment Plan

**Date:** 2026-05-08
**Scope:** Deploy OpenSEO (self-hosted Ahrefs/Semrush alternative) on NixOS (evo-x2) for tracking all owned domains
**Source Research:** `~/projects/reports/docs/research/2026-05-08_open-source-seo-tools-competitive-analysis.md`

---

## Why OpenSEO

- Most feature-complete open-source SEO suite (keyword research, rank tracking, backlinks, domain insights, site audits)
- Self-hosted, pay-as-you-go via DataForSEO ($2–20/mo vs $99–130/mo for Ahrefs/Semrush)
- First-class Docker support with pre-built GHCR images
- Active development with GEO/AI visibility on roadmap

## Container Details

| Attribute | Value                                                          |
| --------- | -------------------------------------------------------------- |
| Image     | `ghcr.io/every-app/open-seo:latest`                            |
| Port      | `3001` (localhost only)                                        |
| Volume    | `/var/lib/openseo/data` → `/app/.wrangler` (SQLite)            |
| Auth      | `local_noauth` (behind Authelia forward auth via Caddy)        |
| Env       | `DATAFORSEO_API_KEY`, `PORT=3001`, `ALLOWED_HOST=seo.home.lan` |
| URL       | `https://seo.home.lan`                                         |

---

## Tasks (sorted by importance → impact → effort → customer-value)

Each task ≤12 min. Total estimated time: ~51 minutes.

| #   | Task                                                                                      | Impact   | Effort | Status |
| --- | ----------------------------------------------------------------------------------------- | -------- | ------ | ------ |
| 1   | Create sops secrets file `platforms/nixos/secrets/openseo.yaml` with `DATAFORSEO_API_KEY` | Critical | 2min   | ☐      |
| 2   | Register secrets in `sops.nix` — add `mkSecrets` + sops template `openseo-env`            | Critical | 5min   | ☐      |
| 3   | Create `modules/nixos/services/openseo.nix` — full flake-parts module                     | Critical | 12min  | ☐      |
| 4   | Add `openseo.nix` to `flake.nix` imports                                                  | Critical | 2min   | ☐      |
| 5   | Add `inputs.self.nixosModules.openseo` to evo-x2 modules list in `flake.nix`              | Critical | 1min   | ☐      |
| 6   | Enable `services.openseo.enable = true` in `configuration.nix`                            | Critical | 1min   | ☐      |
| 7   | Add `seo.home.lan` virtual host in `caddy.nix` with forward auth                          | High     | 3min   | ☐      |
| 8   | Add OpenSEO endpoint to `gatus-config.nix` monitoring                                     | Medium   | 2min   | ☐      |
| 9   | Add OpenSEO to Homepage dashboard in `homepage.nix`                                       | Medium   | 3min   | ☐      |
| 10  | Add OpenSEO docs to `AGENTS.md`                                                           | Medium   | 5min   | ☐      |
| 11  | Add justfile recipes: `openseo-status`, `openseo-restart`, `openseo-logs`                 | Low      | 3min   | ☐      |
| 12  | Run `just test-fast` to validate syntax                                                   | High     | 2min   | ☐      |
| 13  | Run `just switch` — deploy and verify container starts + UI loads                         | High     | 5min   | ☐      |
| 14  | Configure initial domains in OpenSEO UI for rank tracking                                 | High     | 5min   | ☐      |

---

## Task Details

### Task 1: Create sops secrets file

**File:** `platforms/nixos/secrets/openseo.yaml`

Single encrypted key:

```yaml
openseo_dataforseo_api_key: <base64 login:password from DataForSEO>
```

Encrypt with existing age key:

```bash
sops --encrypt --age age133ckftlye8snhzga95fnl4np7npjry90qr3g84ya0kddctecx5hsx9uyh6 \
  platforms/nixos/secrets/openseo.yaml
```

**Prerequisite:** Sign up at [dataforseo.com](https://dataforseo.com), get API credentials (new accounts get $1 free credit, min top-up $50).

---

### Task 2: Register secrets in sops.nix

Add to `modules/nixos/services/sops.nix`:

1. **`mkSecrets`** call for `openseo.yaml` → produces `sops.secrets.openseo_dataforseo_api_key`
2. **`sops.templates."openseo-env"`** → renders `DATAFORSEO_API_KEY` into `/run/secrets-rendered/openseo-env`
3. Set `restartUnits = [ "openseo.service" ]` so service restarts on key rotation

---

### Task 3: Create openseo.nix — flake-parts module

**File:** `modules/nixos/services/openseo.nix`

**Pattern:** Follow `manifest.nix` (docker-compose systemd wrapper)

**Module options (`services.openseo`):**

| Option       | Default                             | Description                                |
| ------------ | ----------------------------------- | ------------------------------------------ |
| `enable`     | false                               | Enable OpenSEO service                     |
| `port`       | 3001                                | HTTP port (via `serviceTypes.servicePort`) |
| `user`       | "openseo"                           | System user                                |
| `group`      | "openseo"                           | System group                               |
| `stateDir`   | "/var/lib/openseo"                  | State directory                            |
| `restartSec` | "5"                                 | Restart delay                              |
| `image`      | "ghcr.io/every-app/open-seo:latest" | Container image                            |

**Inline docker-compose.yml:**

```yaml
services:
  openseo:
    image: ghcr.io/every-app/open-seo:latest
    restart: unless-stopped
    environment:
      - PORT=3001
      - AUTH_MODE=local_noauth
      - DATAFORSEO_API_KEY
      - ALLOWED_HOST=seo.home.lan
      - VITE_SHOW_DEVTOOLS=false
    ports:
      - "127.0.0.1:3001:3001"
    volumes:
      - /var/lib/openseo/data:/app/.wrangler
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    mem_limit: 512m
    pids_limit: 100
```

**Systemd service:**

- `Type = "forking"` with `docker compose up -d`
- `ExecStop = "docker compose down"`
- `ExecStartPre` copies sops-rendered env file into state dir
- `After = ["docker.service" "sops-nix.service"]`
- `harden { MemoryMax = "1G"; ReadWritePaths = [stateDir]; }`
- `serviceDefaults {}`

**User/group:** Dedicated system user `openseo`/`openseo`

**Tmpfiles:** Create `/var/lib/openseo` + `/var/lib/openseo/data` with proper ownership

---

### Task 4: Add to flake.nix imports

Add to the `imports` list (flake-parts modules section):

```nix
./modules/nixos/services/openseo.nix
```

---

### Task 5: Add to evo-x2 modules list

Add to `nixosConfigurations."evo-x2".modules`:

```nix
inputs.self.nixosModules.openseo
```

---

### Task 6: Enable in configuration.nix

Add to `platforms/nixos/system/configuration.nix`:

```nix
services.openseo.enable = true;
```

---

### Task 7: Caddy virtual host

Add to `modules/nixos/services/caddy.nix`:

```nix
(protectedVHost "seo" config.services.openseo.port)
```

This creates `seo.home.lan` with Authelia forward auth for external requests, direct access for LAN.

Update Caddy port reference table in AGENTS.md.

---

### Task 8: Gatus health check

Add to endpoint list in `modules/nixos/services/gatus-config.nix`:

```nix
{
  name = "OpenSEO";
  group = "Productivity";
  url = "http://localhost:${toString cfg.port}";
  interval = "5m";
  conditions = [ "[STATUS] == 200" ];
}
```

---

### Task 9: Homepage dashboard card

Add to `modules/nixos/services/homepage.nix` `services.yaml`:

```nix
"OpenSEO" = {
  href = svcUrl "seo";
  description = "SEO suite — rank tracking, keyword research, backlinks";
  icon = "openseo.png";
  statusStyle = "dot";
  siteMonitor = "https://seo.${domain}";
};
```

Place under new "SEO" group or existing "Tools" group.

---

### Task 10: AGENTS.md documentation

Add OpenSEO section to `AGENTS.md` covering:

- Module options table
- Architecture (Docker container, sops secrets, Caddy reverse proxy)
- Caddy port reference (`config.services.openseo.port`)
- Commands (`just openseo-status`, etc.)
- DataForSEO pricing context

---

### Task 11: Justfile recipes

```make
# SEO (NixOS only)
@openseo-status:
    systemctl status openseo.service && docker compose -f /var/lib/openseo/docker-compose.yml ps

@openseo-restart:
    systemctl restart openseo.service

@openseo-logs:
    journalctl -u openseo.service -f
```

---

### Task 12: Syntax validation

```bash
just test-fast
```

Must pass before proceeding to deployment.

---

### Task 13: Deploy and verify

```bash
just switch
```

Verify:

1. `systemctl status openseo` — active (running)
2. `https://seo.home.lan` — loads OpenSEO UI
3. Gatus shows OpenSEO as healthy
4. Homepage dashboard shows green dot

---

### Task 14: Configure initial domains

In OpenSEO UI (`https://seo.home.lan`):

1. Add domains to track:
   - `larsartmann.cloud`
   - `larsartmann.de`
   - Any GitHub Pages sites
   - Any other public domains
2. Set up first keyword batch per domain
3. Run initial site audit for each domain
4. Review domain insights dashboard

---

## Dependency Graph

```
Task 1 (sops file)
  └→ Task 2 (sops.nix registration)
       └→ Task 3 (openseo.nix module)
            ├→ Task 4 (flake.nix import)
            ├→ Task 5 (evo-x2 modules)
            ├→ Task 6 (configuration.nix enable)
            └→ Task 7 (caddy vhost)
                 ├→ Task 8  (gatus)  ──┐
                 ├→ Task 9  (homepage)──┤
                 ├→ Task 10 (docs)     ├──→ Task 12 (test-fast) → Task 13 (switch) → Task 14 (configure)
                 └→ Task 11 (justfile)─┘
```

---

## Domains to Track (initial list)

| Domain              | Purpose                     | Priority |
| ------------------- | --------------------------- | -------- |
| `larsartmann.cloud` | Primary domain (Twenty CRM) | High     |
| `larsartmann.de`    | Personal domain             | High     |
| GitHub Pages sites  | Open-source projects        | Medium   |
| `home.lan` services | N/A (internal, not public)  | Skip     |

> Action item: Audit all owned domains before Task 14. Check registrar for full list.
