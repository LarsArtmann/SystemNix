# Nix Binary Cache Setup Guide

> **Status**: Steps 1-2 are ✅ DONE (secret generated + sops file created).
> Steps 3-9 are runtime steps that require deployment.

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

## Step 1: Generate the Attic JWT RS256 Secret ✅ DONE

Attic uses RS256 (RSA) JWT signing — not a random symmetric string. Generate
an RSA private key and base64-encode it:

```bash
openssl genrsa -traditional 4096 | base64 -w0
```

## Step 2: Create the Sops Secret File ✅ DONE

```bash
cd ~/projects/SystemNix

# Create the encrypted secret file.
# NOTE: sops encryption only needs the age PUBLIC key from .sops.yaml —
# NO sudo or SSH host key access is required. The private key is only
# needed for decryption at deploy time (by the sops-nix activation script
# on the target host).
echo "attic_token_rs256_secret_base64: $(openssl genrsa -traditional 4096 | base64 -w0)" \
  > platforms/nixos/secrets/attic.yaml

# Encrypt with sops (reads age recipients from .sops.yaml)
sops -e -i platforms/nixos/secrets/attic.yaml

# Force-add past .gitignore (secrets/ matches 'secrets*' pattern)
git add -f platforms/nixos/secrets/attic.yaml
```

The sops file `platforms/nixos/secrets/attic.yaml` has been created and
encrypted. It is tracked by git (force-added past `.gitignore`).

## Step 3: Deploy SystemNix

```bash
cd ~/projects/SystemNix
nh os switch .
```

This starts `atticd` behind Caddy at `https://cache.home.lan/`.

Verify:
```bash
systemctl status atticd
# Attic's root endpoint returns a placeholder HTML page (200).
# There is no /api/v1/server-info endpoint — the server only exposes
# / (placeholder), /{cache}/nix-cache-info, and /_api/v1/* (internal).
curl -s -o /dev/null -w '%{http_code}' https://cache.home.lan/
# Expected: 200
```

## Step 4: Create the Monitor365 Cache

Attic needs an initial cache created via the admin token. The nixpkgs module
ships an `atticd-atticadm` wrapper that runs `atticadm` with the server's
config file (so it has access to the JWT signing key).

First generate a bootstrap token WITH PERMISSIONS (without `--pull`/`--push`/
`--create-cache` flags, the token is useless):

```bash
# Mint an admin token valid for 1 day with full permissions.
sudo atticd-atticadm make-token --sub admin --validity 1d \
  --pull '*' --push '*' \
  --create-cache '*' --configure-cache '*' \
  --configure-cache-retention '*' --destroy-cache '*' \
  > /tmp/attic-admin-token

# Point the attic client at the local server and authenticate.
# (attic-client is installed system-wide via the attic module's
# environment.systemPackages)
attic login local https://cache.home.lan/ "$(cat /tmp/attic-admin-token)"

# Create a public cache (public = pullable without a token).
attic cache create monitor365 --public

# Set 7-day retention — paths older than this are GC'd.
attic cache configure monitor365 --retention-period 7d
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

The `attic` client has NO `token` subcommand. CI tokens are minted server-side
via `atticadm make-token` (same tool as Step 4, but with scoped permissions):

```bash
# Generate a long-lived token scoped to the monitor365 cache only.
sudo atticd-atticadm make-token --sub ci-monitor365 --validity 100y \
  --pull 'monitor365' --push 'monitor365' \
  --create-cache 'monitor365' --configure-cache 'monitor365' \
  --configure-cache-retention 'monitor365'
```

The output is a JWT string — use it as `ATTIC_TOKEN` in Step 8.

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
  (`/mnt/pool/services/atticd/storage/`), independent of the host's `/nix/store`. The
  host's 3-day GC does NOT affect cached paths. Attic has its own GC
  (`garbage-collection.interval = "4 hours"`) with a 7-day default retention.
  GC runs immediately on startup (verified from source: `gc.rs:34-64` — the
  loop calls `run_garbage_collection_once` first, then sleeps for the
  interval), so the size guard's restart-to-trigger-GC mechanism works.

- **LAN-only**: The cache is only reachable on `cache.home.lan`. GitHub Actions
  CI cannot use it. To expose externally, use a Tailscale funnel or Cloudflare
  tunnel (out of scope for this setup).

- **Multiple projects**: Create additional caches in Attic for other projects
  (e.g., `attic cache create dnsblockd --public`). Each gets its own substituter
  URL and public key.
