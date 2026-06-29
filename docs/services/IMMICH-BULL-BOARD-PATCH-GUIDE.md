# Applying the Bull Board Patch to SystemNix Immich

## What This Patch Does

Adds a Bull Board dashboard to Immich at `/admin/queues`, exposing all 18 BullMQ job queues with real-time status, job inspection, retry/delete controls, and queue pause/resume. Admin-only access via existing Immich auth.

## Files

| File | Purpose |
|------|---------|
| `immich-bull-board.patch` | Git patch against upstream Immich v2.6.3 |
| `immich.nix` | NixOS module (needs modification) |

## Patch Contents

| Changed file | Change |
|-------------|--------|
| `server/package.json` | Added `@bull-board/api`, `@bull-board/nestjs`, `@bull-board/express` |
| `pnpm-lock.yaml` | Updated lockfile for new dependencies |
| `server/src/modules/bull-board.module.ts` | **New** — NestJS module registering all 18 queues |
| `server/src/middleware/bull-board-auth.middleware.ts` | **New** — admin-only auth middleware |
| `server/src/app.module.ts` | Import `ImmichBullBoardModule` into `ApiModule` |
| `server/src/constants.ts` | Added `/admin/queues` to `excludePaths` |

## Step 1 — Patch Already Saved

The patch file is at:

```
modules/nixos/services/immich-bull-board.patch
```

Generated from commit `00591f1b2` in `/home/lars/forks/immich`.

## Step 2 — Update `immich.nix`

Add a `package` override that applies the patch:

```nix
{inputs, ...}: {
  flake.nixosModules.immich = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.immich;
  in {
    services.immich = {
      package = pkgs.immich.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or []) ++ [
          ./immich-bull-board.patch
        ];
        pnpmDeps = pkgs.fetchPnpmDeps {
          inherit (oldAttrs) pname;
          version = oldAttrs.version;
          src = oldAttrs.src;
          hash = "";  # <-- will be filled in step 3
        };
      });

      enable = true;
      port = 2283;
      host = "127.0.0.1";
      openFirewall = false;
      mediaLocation = "/var/lib/immich";

      accelerationDevices = null;

      database.enable = true;
      redis.enable = true;
      machine-learning.enable = true;

      settings = {
        oauth = {
          enabled = true;
          issuerUrl = "https://auth.home.lan";
          clientId = "immich";
          clientSecret._secret = config.sops.secrets.immich_oauth_client_secret.path;
          scope = "openid profile email";
          autoLaunch = false;
          autoRegister = true;
          buttonText = "Login with Authelia";
        };
      };
    };

    users.users.immich.extraGroups = ["video" "render"];

    services.postgresql.settings = {
      shared_buffers = "512MB";
      effective_cache_size = "2GB";
      work_mem = "16MB";
      maintenance_work_mem = "256MB";
      max_connections = 100;
      checkpoint_completion_target = "0.9";
      random_page_cost = "1.1";
    };

    systemd = {
      services = {
        immich-server.serviceConfig = {
          Restart = lib.mkForce "on-failure";
          RestartSec = lib.mkForce "5s";
        };
        immich-machine-learning.serviceConfig = {
          Restart = lib.mkForce "on-failure";
          RestartSec = lib.mkForce "10s";
        };
        immich-db-backup = {
          description = "Immich PostgreSQL database backup";
          path = [config.services.postgresql.package];
          after = ["postgresql.service" "immich-server.service"];
          requires = ["postgresql.service"];
          serviceConfig = {
            Type = "oneshot";
            User = "immich";
            Group = "immich";
          };
          script = ''
            set -euo pipefail
            backupDir="${cfg.mediaLocation}/database-backup"
            mkdir -p "$backupDir"
            stamp="$(date +%Y%m%d-%H%M%S)"
            pg_dump --host=/run/postgresql --clean --if-exists --dbname=${cfg.database.name} \
              > "$backupDir/immich-$stamp.sql"
            find "$backupDir" -name "immich-*.sql" -mtime +7 -delete
            echo "immich-db-backup: completed -> immich-$stamp.sql"
          '';
        };
      };
      timers.immich-db-backup = {
        description = "Daily Immich database backup";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };
    };
  };
}
```

## Step 3 — Get the pnpmDeps Hash

First build will fail with a hash mismatch:

```bash
sudo nixos-rebuild build 2>&1 | grep "got:"
```

Copy the `got: sha512-...` value and paste it into the `hash` field:

```nix
hash = "sha512-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
```

## Step 4 — Deploy

```bash
sudo nixos-rebuild switch
```

## Step 5 — Access

Navigate to `https://<your-immich-domain>/admin/queues`. Requires admin login (Authelia SSO session works).

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Patch fails to apply | Upstream Immich version may have drifted — regenerate the patch from the fork |
| Helmet CSP blocks the UI | Exclude `/admin/queues` from Helmet middleware in `app.common.ts` |
| Blank page / 401 loop | Ensure you're logged in as an admin user |
| pnpmDeps hash mismatch after Immich update | Delete the hash, rebuild, paste the new one |

## Updating the Patch

When upstream Immich updates and you want to rebase:

```bash
cd /home/lars/forks/immich
git checkout main
git remote add upstream https://github.com/immich-app/immich.git
git fetch upstream
git rebase upstream/main

# Resolve any conflicts in the 4 changed files, then:
pnpm install
pnpm run check
pnpm run build

# Regenerate the patch:
git diff HEAD~1 -- server/ pnpm-lock.yaml > /home/lars/projects/SystemNix/modules/nixos/services/immich-bull-board.patch
```
