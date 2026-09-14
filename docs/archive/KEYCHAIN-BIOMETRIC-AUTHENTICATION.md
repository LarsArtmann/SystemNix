# KeyChain Biometric Authentication Guide

**Last Updated:** 2026-01-17
**Status:** ✅ Implemented

---

## Overview

This guide covers KeyChain Touch ID/fingerprint authentication for **keys and application data** on macOS via nix-darwin and custom management commands.

## What's Included in KeyChain

### Keys

- **SSH keys:** For Git, remote servers, authentication
- **Signing keys:** Code signing, document signing
- **Encryption keys:** PGP, file encryption, secure messaging
- **Application keys:** API tokens, service credentials, secrets

### Other Data

- **Certificates:** SSL/TLS certificates, code signing certificates
- **Identities:** Certificate + private key pairs
- **Passwords:** WiFi passwords, app credentials (optional)

## Architecture

### What IS Configurable via nix-darwin

**Touch ID for sudo** (Already Configured):

```nix
# platforms/darwin/security/pam.nix
security.pam.services.sudo_local.touchIdAuth = true;
```

This enables Touch ID authentication for:

- `sudo` commands in Terminal
- Requires Touch ID once per 5 minutes (configurable timeout)
- Works in tmux sessions with `reattach` option

### What Requires Manual Configuration

**KeyChain Item Touch ID** (Per-Item Only):

- Touch ID requirements are embedded in individual KeyChain items
- No system-wide defaults or configuration files
- Must be set when items are created or modified

## Implementation

### 1. Nix-Darwin Module

**File:** `platforms/darwin/security/keychain.nix`

Automatically configures KeyChain security settings on activation:

- Locks KeyChain after 5 minutes of inactivity
- Validates login keychain existence
- Provides consistent security baseline

### 2. Just Commands

**Available Commands:**

```bash
# Show all available keychain commands
just keychain-help

# List all KeyChain items (keys, certificates, identities)
just keychain-list

# Check KeyChain status and Touch ID setup
just keychain-status

# List all keys (SSH, signing, encryption)
just keychain-keys

# List all certificates
just keychain-certs

# List all identities (certificate + private key pairs)
just keychain-identities

# Add SSH key to KeyChain with Touch ID
just keychain-ssh-add [key-path]

# Add application data/password
just keychain-add <account> <service> <password>

# Lock/unlock KeyChains
just keychain-lock
just keychain-unlock

# Configure KeyChain security settings
just keychain-settings
```

### 3. Manual KeyChain Access App

For existing KeyChain items, use the Keychain Access GUI:

1. Open **Keychain Access** app (Applications → Utilities)
2. Find the KeyChain item (key, certificate, or password)
3. Right-click → **Get Info**
4. Go to **Access Control** tab
5. Click **+** to add applications
6. Check **Touch ID** checkbox for biometric requirement

## Usage Examples

### Managing SSH Keys with Touch ID

```bash
# Add SSH key to KeyChain with Touch ID
just keychain-ssh-add ~/.ssh/id_ed25519

# Add all SSH keys from ~/.ssh/
just keychain-ssh-add

# List all keys
just keychain-keys

# Check loaded SSH keys
ssh-add -l
```

### Managing Application Keys

```bash
# Add API key with Touch ID (uses Keychain Access for Touch ID)
just keychain-add "api-service" "github-token" "ghp_xxxxxxxxxxxx"

# Add application secret
just keychain-add "myapp" "com.myapp.credentials" "secret-key-here"

# List all keys
just keychain-keys
```

### Managing Certificates

```bash
# List all certificates
just keychain-certs

# List all identities (cert + private key pairs)
just keychain-identities

# View full list of all items
just keychain-list
```

### Security Best Practices

1. **Lock KeyChain when idle:** Automatically locks after 5 minutes (configured)
2. **Use Touch ID for sensitive keys:** Requires fingerprint or password fallback
3. **Separate key types:** Different keys for different purposes
4. **Regular audits:** Use `just keychain-list` to review all keys and items
5. **SSH key management:** Use `just keychain-ssh-add` for SSH key integration
6. **Certificate management:** Monitor with `just keychain-certs` and `just keychain-identities`
7. **Key rotation:** Regularly rotate application keys and tokens

## Technical Details

### KeyChain Security Model

KeyChain uses the **Access Control Framework**:

- **kSecAttrAccessControl**: Controls item accessibility
- **kSecAccessControlTouchIDAny**: Requires any enrolled fingerprint
- **kSecAccessControlTouchIDCurrentSet**: Requires currently enrolled fingers
- **Password fallback:** Always available if Touch ID fails

### Activation Script

Runs on every `just switch`:

```bash
# Check login keychain
if [ -f "$HOME/Library/Keychains/login.keychain-db" ]; then
  echo "✓ Login keychain found"
fi

# Set security settings
security set-keychain-settings -l -u -t 300 login.keychain-db
```

### Security Command Options

```bash
# Add with biometric requirement
security add-generic-password \
  -a "account" \
  -s "service" \
  -w "password" \
  -U \
  --require-biometry
```

**Flags:**

- `-a`: Account name
- `-s`: Service name
- `-w`: Password
- `-U`: Update if exists
- `--require-biometry`: Require Touch ID/Face ID

## Troubleshooting

### Touch ID Not Prompting

**Problem:** KeyChain item doesn't prompt for Touch ID

**Solutions:**

1. Verify Touch ID is enrolled in System Settings
2. Check item Access Control in Keychain Access app
3. Ensure item was created with `--require-biometry`
4. Re-add the item using `just keychain-add`

### KeyChain Not Unlocking

**Problem:** Cannot unlock KeyChain

**Solutions:**

1. Use `just keychain-unlock` (requires password)
2. Check if login keychain exists: `ls ~/Library/Keychains/`
3. Verify correct password for login keychain
4. Reset KeyChain if corrupted (last resort)

### PAM Touch ID Not Working

**Problem:** sudo doesn't prompt for Touch ID

**Solutions:**

1. Check status: `just keychain-status`
2. Verify `/etc/pam.d/sudo_local` exists
3. Ensure `pam_tid.so` is enabled
4. Rebuild configuration: `just switch`

### Items Not Found

**Problem:** `just keychain-list` shows no items

**Solutions:**

1. Check if login keychain exists: `security list-keychains`
2. Ensure you're using correct keychain (login vs system)
3. Try manual search: `security dump-keychain -r login.keychain-db`

## Security Considerations

### What's Protected

✅ **SSH keys:** Git authentication, server access, SSH agent
✅ **Signing keys:** Code signing, document signing, Git signing
✅ **Encryption keys:** PGP keys, file encryption, secure messaging
✅ **Application keys:** API keys, tokens, service credentials
✅ **Certificates:** SSL/TLS certificates, code signing certificates
✅ **Identities:** Certificate + private key pairs for authentication

### What Requires Manual Setup

⚠️ **Existing keys:** Must use Keychain Access GUI for each key
⚠️ **Application-specific:** Each app manages its own keys
⚠️ **System items:** Some system keys don't support Touch ID

### Limitations

❌ **No system-wide configuration:** Touch ID is per-item only
❌ **Cannot force all keys:** Apps must implement biometric auth
❌ **No nix-darwin module:** No direct KeyChain item management for keys
❌ **macOS only:** Linux NixOS uses different mechanisms (GnuPG, etc.)

## Integration with Other Tools

### SSH Keys

SSH keys can be integrated with KeyChain for Touch ID authentication:

```bash
# Add SSH key to KeyChain
just keychain-ssh-add ~/.ssh/id_ed25519

# Verify key is loaded
ssh-add -l

# Use key with Touch ID prompt on first use
git pull
ssh user@server
```

**Enabling Touch ID for SSH Keys:**

1. Add key with `just keychain-ssh-add`
2. First use prompts for Touch ID
3. Key is cached for configurable duration
4. Use Keychain Access to adjust key access controls

### ActivityWatch

- Application data managed via KeyChain
- Use `just keychain-add` for credentials

### Git Signing

- Git signing keys can be stored in KeyChain
- Touch ID prompt on signed commits
- Configure with `git config gpg.format ssh`

### Browser Passwords

- Safari uses KeyChain natively
- Chrome can import/export KeyChain passwords
- Enable "Touch ID for autofill" in Safari preferences

### Developer Tools

- Code signing keys: Touch ID prompt on signing
- Notarization certificates: KeyChain managed
- API tokens: Store as application keys

## Advanced Usage

### Programmatic Access

```bash
# Find item programmatically
security find-generic-password -s "service.name" -w

# Update password
security add-generic-password -a "account" -s "service" -w "newpass" -U

# Delete item
security delete-generic-password -a "account" -s "service"
```

### Automation

```bash
# Add multiple items with Touch ID
cat passwords.txt | while read line; do
  IFS=',' read -r account service password <<< "$line"
  just keychain-add "$account" "$service" "$password"
done
```

### Backup and Restore

```bash
# Backup KeyChain
cp ~/Library/Keychains/login.keychain-db ~/keychain-backup.db

# Restore KeyChain
cp ~/keychain-backup.db ~/Library/Keychains/login.keychain-db
```

## References

- [Apple Security Framework](https://developer.apple.com/documentation/security)
- [LocalAuthentication Framework](https://developer.apple.com/documentation/localauthentication)
- [Keychain Access Guide](https://support.apple.com/guide/mac-help/keychain-access-app-mac3k1101/mac)
- [nix-darwin Documentation](https://nix-darwin.github.io/nix-darwin/)

## Summary

- ✅ **nix-darwin configures:** sudo Touch ID, KeyChain security settings
- ⚠️ **Per-item required:** Touch ID must be set on each KeyChain item
- 🛠️ **Just commands:** Easy management of keys, certificates, identities
- 🔐 **Security:** Biometric authentication enhances security significantly
- 📚 **Documentation:** Complete guide in this file
- 🔑 **SSH keys:** Integrated with KeyChain via `just keychain-ssh-add`
- 📜 **Certificates:** Full visibility with `just keychain-certs`

---

**For support:** Check troubleshooting section or run `just keychain-help`
