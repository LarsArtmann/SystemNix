# Nix Binary Cache Setup Guide

This guide covers the manual steps required to bring the Attic binary cache online.
All code changes are already in place — these are the runtime/secret steps that
cannot be automated declaratively.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  evo-x2 (SystemNix)                                          │
│                                                              │
│  Forgejo Actions ──▶ nix build ──▶ attic push ──▶ Attic     │
│  (native:host)      .#monitor365              (port 8200)   │
│                                                      │       │
│  nix-settings.nix ◀── substituter ───────────────────┘       │
│  (all LAN machines pull from cache.home.lan)                 │
└─────────────────────────────────────────────────────────────┘
```

## Files Changed

### SystemNix (`/home/lars/projects/SystemNix`)
- `modules/nixos/services/attic.nix` — Attic server NixOS module (NEW)
- `lib/ports.nix` — Added `attic = 8200`
- `platforms/common/dns-local.nix` — Added `"cache"` subdomain
- `modules/nixos/services/caddy.nix` — Added `cache.${domain}` reverse proxy
- `modules/nixos/services/sops.nix` — Added Attic JWT secret + env template
- `platforms/nixos/system/configuration.nix` — Enabled `attic-config`

### Monitor365 (`/home/lars/projects/monitor365`)
- `.forgejo/workflows/nix-cache.yml` — CI workflow (NEW)
- `flake.nix` — Added `nixConfig.extra-substituters` (placeholder key)

---

## Step 1: Generate the Attic JWT Secret

```bash
openssl rand -base64 32
```

Copy the output (a base64 string like `aB3dE6f...`).

## Step 2: Create the Sops Secret File

```bash
cd ~/projects/SystemNix

# Create the encrypted secret file
cat > platforms/nixos/secrets/attic.yaml << 'EOF'
attic_token_hs256_secret_base64: PASTE_BASE64_HERE
EOF

# Encrypt with sops (uses age key from SSH host key)
sops -e -i platforms/nixos/secrets/attic.yaml
```

Verify it's encrypted:
```bash
cat platforms/nixos/secrets/attic.yaml
# Should show ENC[AES256_GCM,...] values, not plaintext
```

## Step 3: Deploy SystemNix

```bash
cd ~/projects/SystemNix
nh os switch .
```

This starts `atticd` behind Caddy at `https://cache.home.lan/`.

Verify:
```bash
systemctl status atticd
curl -sk https://cache.home.lan/api/v1/server-info
```

## Step 4: Create the Monitor365 Cache

Attic needs an initial cache created via the admin tool. Run as the atticd user:

```bash
sudo -u atticd atticd-queue monitor365 --public
```

Or if the above doesn't work (atticd-queue may not exist in all versions):

```bash
# Generate a bootstrap token (server must be running)
attic token --endpoint https://cache.home.lan/ \
  --jwt-config /run/secrets-rendered/attic-env

# Create the cache
attic login local https://cache.home.lan/ <bootstrap-token>
attic cache create monitor365 --public
attic cache configure monitor365 --retention-period 30d
```

## Step 5: Get the Cache Public Key

```bash
attic cache info monitor365
```

Look for the `Public Key:` line. It will look like:
```
monitor365:Bp6yF...some-base32-string...=
```

## Step 6: Configure the Substituter

### In SystemNix (`nix-settings.nix`):
Add the public key to the attic module config:

```nix
# In configuration.nix, update the attic-config settings:
services.attic-config.cachePublicKey = "monitor365:Bp6yF...=";
```

Then redeploy: `nh os switch .`

### In Monitor365 (`flake.nix`):
Replace the placeholder in `nixConfig`:

```nix
nixConfig = {
  extra-substituters = [ "https://cache.home.lan/monitor365" ];
  extra-trusted-public-keys = [
    "monitor365:Bp6yF...="  # ← paste actual key
  ];
};
```

## Step 7: Create CI Token for Forgejo Actions

Generate a scoped push token:

```bash
attic token --endpoint https://cache.home.lan/ \
  monitor365 \
  --pull \
  --push \
  --create-cache \
  --configure-cache \
  --configure-cache-retention
```

## Step 8: Add Forgejo Repo Secrets

In Forgejo, go to the Monitor365 repo → Settings → Actions → Secrets:

| Secret Name      | Value                              |
| ---------------- | ---------------------------------- |
| `ATTIC_ENDPOINT` | `https://cache.home.lan/`          |
| `ATTIC_TOKEN`    | (token from Step 7)                |

## Step 9: Trigger the First Build

Push a commit to `master` (or run manually):

```bash
# In Forgejo UI: Actions → Nix Cache → Run workflow
```

Or trigger locally:

```bash
cd ~/projects/monitor365
git commit --allow-empty -m "ci: trigger nix cache build" && git push
```

The first build will compile everything from scratch (~20-40 min for Monitor365).
Subsequent builds will pull from the cache in seconds.

---

## Verification

After the first CI run completes:

```bash
# Check cache contents
attic cache info monitor365

# Test substituter from any LAN machine
nix build github:LarsArtmann/monitor365#monitor365 --substituters "https://cache.home.lan/monitor365" --trusted-public-keys "monitor365:YOUR_KEY=" -v 2>&1 | grep "copying"
```

## Notes

- **Runner memory**: The Forgejo runner has `MemoryMax = 4G` per job. If Rust
  builds OOM, increase it in `forgejo.nix`:
  ```nix
  serviceConfig.MemoryMax = "16G";  # or more
  ```

- **GC interaction**: Attic stores NAR files in its own storage
  (`/var/lib/atticd/storage/`), independent of the host's `/nix/store`. The
  host's 3-day GC does NOT affect cached paths. Attic has its own GC
  (`garbage-collection.interval = "12 hours"`) with a 30-day default retention.

- **LAN-only**: The cache is only reachable on `cache.home.lan`. GitHub Actions
  CI cannot use it. To expose externally, use a Tailscale funnel or Cloudflare
  tunnel (out of scope for this setup).

- **Multiple projects**: Create additional caches in Attic for other projects
  (e.g., `attic cache create dnsblockd --public`). Each gets its own substituter
  URL and public key.
