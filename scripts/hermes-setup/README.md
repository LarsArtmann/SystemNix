# Hermes Git Remote Access Setup

Generated: 2026-06-08

## What This Is

Hermes (the AI agent gateway) needs git remote access to clone/manage repositories.
The `hermes` system user requires an SSH deploy key for GitHub access.

## Generated Key Pair

- **Private key**: `id_ed25519` (keep secure — move to `/home/hermes/.ssh/`)
- **Public key**: `id_ed25519.pub` (add to GitHub deploy keys)

## Setup Steps

### 1. Install Private Key on evo-x2

Run as root or via sudo:

```bash
sudo mkdir -p /home/hermes/.ssh
sudo cp /path/to/id_ed25519 /home/hermes/.ssh/
sudo chown -R hermes:hermes /home/hermes/.ssh
sudo chmod 700 /home/hermes/.ssh
sudo chmod 600 /home/hermes/.ssh/id_ed25519
```

### 2. Add Public Key to GitHub

1. Go to: https://github.com/settings/keys (personal) or repo Settings > Deploy keys
2. Click "New SSH key" or "Add deploy key"
3. Paste the contents of `id_ed25519.pub`
4. Title: `hermes@evo-x2`
5. For deploy keys: enable "Allow write access" if hermes needs push permissions
6. Click "Add SSH key"

### 3. Test Connection

```bash
sudo -u hermes ssh -T git@github.com
```

Expected response: `Hi LarsArtmann! You've successfully authenticated...`

### 4. Configure Git for Hermes

```bash
sudo -u hermes git config --global user.email "hermes@evo-x2"
sudo -u hermes git config --global user.name "Hermes Agent"
```

### 5. Hermes Config (runtime)

In hermes' config.yaml (located in `/home/hermes/`):

```yaml
# Set git provider credentials if needed
git:
  default_remote: "origin"
  ssh_key_path: "/home/hermes/.ssh/id_ed25519"
```

Or use env vars in the hermes `.env` file:

```bash
GIT_SSH_COMMAND="ssh -i /home/hermes/.ssh/id_ed25519 -o IdentitiesOnly=yes"
```

## Security Notes

- The private key is **never committed** to git
- The public key is safe to share (it's in this README for documentation)
- Rotate keys if compromised
- Consider using a GitHub App or Fine-Grained PAT instead of deploy keys for finer access control

## Public Key

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJaILE0oNXoyRG5BPARdRFWpdxi+KDJhNnYI+k71jwue hermes@evo-x2
```
