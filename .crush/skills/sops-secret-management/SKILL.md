---
name: sops-secret-management
description: Use when adding, editing, or removing sops secrets, debugging sops decryption failures, or running any `sops` CLI command. Also use when adding new services that need sops secrets, writing sops guards, or setting up SMTP/API key secrets.
---

# Sops Secret Management

## Key Facts

- Secrets are encrypted with **age** using the SSH host key (`/etc/ssh/ssh_host_ed25519_key`)
- sops-nix decrypts secrets at boot as a **single atomic operation** — if ANY secret's owner/group references a non-existent user, ALL secrets fail
- The `sops` CLI needs age key format, NOT SSH key format — `SOPS_AGE_SSH_PRIVATE_KEY_FILE` does NOT work

## Converting SSH Key to Age Format

`ssh-to-age` has two modes:

| Input | Flag | Output | Use case |
|-------|------|--------|----------|
| Public key (`.pub`) | *(none)* | `age1...` (recipient) | Encryption only — useless for CLI decryption |
| Private key | `-private-key` | `AGE-SECRET-KEY-...` (identity) | **This is what sops CLI needs** |

## One-Liner Pattern

Never write the age key to disk. Keep it in a shell variable:

```bash
# Set a secret value
SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) \
  sops --set '["key_name"] "value"' platforms/nixos/secrets/file.yaml

# Edit interactively
SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) \
  sops platforms/nixos/secrets/file.yaml
```

## Why sudo Is Tricky

- `sudo` strips env vars — `sudo env VAR=VALUE command` often fails
- `sudo` inside a `.sh` script called with `sudo bash script.sh` creates double-sudo issues
- **Solution:** Use `VAR=$(sudo cat ...) command` — the subshell runs sudo, captures output, passes as env var to the main shell. No temp files, no double-sudo.

## Common Mistakes

| Mistake | What Happens | Fix |
|---------|-------------|-----|
| Using `SOPS_AGE_SSH_PRIVATE_KEY_FILE` | sops CLI ignores it | Use `SOPS_AGE_KEY` with age-converted key |
| Running `ssh-to-age` on public key for decryption | Produces recipient, not identity — "unknown identity type" | Use `-private-key` flag with the private key |
| Writing age key to `/tmp/age-key` file | Leaks secret to disk | Use shell variable `SOPS_AGE_KEY=$(...)` |
| `sudo` before `sops --set` | sudo strips SOPS_AGE_KEY env var | Use inline `VAR=$(sudo ...) command` pattern |
| Adding secret to sops.nix but not to the encrypted file | sops-install-secrets fails at boot — ALL secrets blocked | Always set the value in the `.yaml` file AND add the key name to the nix config |

## Adding a New Secret (Full Workflow)

1. **Add the key to the encrypted file:**
   ```bash
   SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) \
     sops --set '["new_secret_key"] "secret_value"' platforms/nixos/secrets/file.yaml
   ```

2. **Add to `modules/nixos/services/sops.nix`:**
   - If using `mkSecrets` or `mkKeyedSecrets`, add the key name to the list
   - Set appropriate `owner`, `group`, `restartUnits`
   - **Always guard with `lib.optionalAttrs config.services.X.enable`** if the service can be disabled

3. **Reference in the service module:**
   ```nix
   config.sops.secrets.my_secret_key.path
   ```
   Use in `EnvironmentFile`, `ExecStart`, or `credentials` block.

4. **Test:** `just switch` — verify the service starts and the secret is populated.

## Guarding Secrets Against Atomic Failure

sops-nix decrypts ALL secrets atomically. One bad owner → everything fails. Guard pattern:

```nix
# In sops.nix secrets block:
// lib.optionalAttrs config.services.my-service.enable (
  mkSecrets "my-service.yaml" {
    owner = "my-service";
    group = "my-service";
    restartUnits = ["my-service.service"];
  } ["my_secret_key"]
)

# In sops.nix templates block:
// lib.optionalAttrs config.services.my-service.enable {
  "my-service-env" = {
    owner = "my-service";
    group = "my-service";
    restartUnits = ["my-service.service"];
    content = ''
      MY_SECRET=${config.sops.placeholder.my_secret_key}
    '';
  };
}
```

**Rule:** Every secret that references a service-specific `owner`/`group` MUST be guarded. Secrets with `owner = primaryUser` or `owner = "root"` are safe without guards (those users always exist).

## Encrypted Secret Files

| File | Contents |
|------|----------|
| `secrets.yaml` | forgejo_token, github_token, github_user |
| `pocket-id.yaml` | pocket_id_encryption_key, pocket_id_static_api_key, pocket_id_smtp_password, oauth2_proxy_client_secret, oauth2_proxy_cookie_secret, immich_oauth_client_secret |
| `dnsblockd-certs.yaml` | dnsblockd_ca_cert, dnsblockd_ca_key, dnsblockd_server_cert, dnsblockd_server_key |
| `voice-agents.yaml` | livekit_keys |
| `hermes.yaml` | discord_bot_token, glm_api_key, minimax_api_key, xiaomi_api_key, fal_key, firecrawl_api_key |
| `crush-daily.yaml` | synthetic_api_key |
| `openseo.yaml` | dataforseo_api_key |
| `monitor365.yaml` | cloud_auth_token, server_jwt_secret |
| `signoz.yaml` | discord_alert_webhook_url |
| `discordsync.yaml` | discordsync_discord_token, discordsync_turso_url, discordsync_turso_auth_token |
