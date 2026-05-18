# Gitea → Forgejo Migration Plan

**Status:** Phase 1 COMPLETE — code migrated, build passes. Phase 2 (data migration) pending `just switch`.
**Risk:** Medium — data is safe (SQLite backup), but 2h downtime window needed
**Estimated effort:** 4-6 hours (implementation + testing + migration)

---

## Why Migrate?

| Reason | Detail |
|--------|--------|
| Governance | Forgejo is community-governed (Codeberg e.V.); Gitea is for-profit |
| License | Forgejo = GPLv3 (fully free); Gitea = MIT + proprietary add-ons |
| Security | Forgejo patches available to everyone; Gitea advance notice for paying customers |
| Future | Federation (ActivityPub/ForgeFed) — cross-instance issues/PRs |
| Compatibility | Drop-in replacement — same API, same data format, same config keys |

---

## Current State Inventory

### Files that reference Gitea (must change)

| File | What | Change needed |
|------|------|---------------|
| `modules/nixos/services/gitea.nix` | Main module (554 lines) | **Rewrite** → `forgejo.nix` |
| `modules/nixos/services/gitea-repos.nix` | Declarative repo mirroring (313 lines) | **Rewrite** → `forgejo-repos.nix` |
| `modules/nixos/services/caddy.nix:67` | `gitea.${domain}` virtual host | Change subdomain + port reference |
| `modules/nixos/services/authelia.nix:198-203` | OIDC client `client_id = "gitea"` | Update client ID + callback URL |
| `modules/nixos/services/homepage.nix:116-120` | Dashboard entry | Update URL + icon |
| `modules/nixos/services/gatus-config.nix:58-61` | Health check | Update port reference |
| `modules/nixos/services/signoz.nix:536` | Log collection `gitea.service` | Update unit name |
| `modules/nixos/services/sops.nix:41-45` | Secrets `restartUnits` | Update service names |
| `modules/nixos/services/sops.nix:129-137` | Template `gitea-sync.env` | Rename template |
| `platforms/nixos/system/dns-blocker-config.nix:55` | DNS A record `"gitea"` | Change subdomain |
| `platforms/nixos/rpi3/default.nix:144` | DNS A record `"gitea"` | Change subdomain |
| `platforms/nixos/system/configuration.nix:126` | `gitea.enable = true` | Switch to forgejo |
| `platforms/nixos/system/configuration.nix:267-274` | `gitea-repos` config | Switch to forgejo-repos |
| `flake.nix:358-364` | serviceModules entries | Replace gitea → forgejo |
| `justfile:454-463` | `gitea-sync-repos`, `gitea-update-token` | Rename recipes |
| `AGENTS.md` | Documentation references | Update module name, commands |

### Data on disk

| Path | Contents | Size estimate |
|------|----------|---------------|
| `/var/lib/gitea/` | SQLite DB + repos + LFS + logs | 1-5 GB |
| `/var/lib/gitea/gitea.db` | SQLite database | 10-100 MB |
| `/var/lib/gitea/repositories/` | Mirrored Git repos | Bulk of space |
| `/var/lib/gitea/lfs/` | LFS objects | Varies |
| `/var/lib/gitea/.admin-password` | Auto-generated admin pass | Small |
| `/var/lib/gitea/.admin-token.env` | API token | Small |
| `/var/lib/gitea/.runner-token` | Actions runner token | Small |

### Secrets in sops

| Key | Used by |
|-----|---------|
| `gitea_token` | API access for sync scripts |
| `github_token` | GitHub API for mirroring |
| `github_user` | GitHub username |

These don't need to change — Forgejo API tokens are generated fresh.

---

## Migration Strategy

### Subdomain Decision

**Option A: Keep `gitea.home.lan`** (recommended for simplicity)
- Zero DNS changes, zero Authelia client changes
- Bookmark compatibility
- Just change the backend service

**Option B: Change to `git.home.lan` or `forgejo.home.lan`**
- Cleaner naming but requires DNS + Authelia + homepage updates
- More disruptive, no real benefit for a personal instance

**Recommendation: Option A** — keep `gitea.home.lan` as the subdomain. Rename later if desired.

### State Directory Decision

**Option A: Migrate `/var/lib/gitea` → `/var/lib/forgejo`** (recommended)
- Clean — matches Forgejo conventions
- Requires `mv` + chown during migration window
- The Forgejo nixpkgs module creates `forgejo:forgejo` user/group

**Option B: Point Forgejo at `/var/lib/gitea`**
- No data migration needed
- But confusing naming, and user/group mismatch (`gitea` vs `forgejo`)

**Recommendation: Option A** — clean migration. Data stays in one place, names match.

---

## Phase 1: Preparation (no downtime)

### Step 1.1: Create backup

```bash
# Full Gitea backup before anything changes
just test  # ensure current config builds cleanly
systemctl stop gitea
cp -a /var/lib/gitea /var/lib/gitea.bak.$(date +%Y%m%d)
systemctl start gitea
```

### Step 1.2: Write `modules/nixos/services/forgejo.nix`

Port `gitea.nix` to use `services.forgejo` module options. Key differences:

| Gitea | Forgejo |
|-------|---------|
| `services.gitea.package = pkgs.gitea` | `services.forgejo.package = pkgs.forgejo-lts` |
| `services.gitea.stateDir = "/var/lib/gitea"` | `services.forgejo.stateDir = "/var/lib/forgejo"` |
| User `gitea:gitea` | User `forgejo:forgejo` |
| `services.gitea.settings.*` | `services.forgejo.settings.*` (identical keys) |
| CLI: `gitea admin user ...` | CLI: `forgejo admin user ...` (identical subcommands) |
| `services.gitea-actions-runner` | Same package works (Forgejo Actions is API-compatible) |

Config keys in `settings` are **identical** — Forgejo reads the same `app.ini` format.

### Step 1.3: Write `modules/nixos/services/forgejo-repos.nix`

Port `gitea-repos.nix` with:
- `config.services.forgejo.settings.server.HTTP_PORT` instead of gitea
- Service names changed from `gitea-*` to `forgejo-*`
- API URL remains `http://localhost:<port>` (same API v1)

### Step 1.4: Update all references

Mechanical find-replace across all files listed in the inventory above:

```
services.gitea           → services.forgejo
gitea.service            → forgejo.service
gitea-github-sync        → forgejo-github-sync
gitea-ensure-repos       → forgejo-ensure-repos
gitea-generate-token     → forgejo-generate-token
gitea-runner-token       → forgejo-runner-token
gitea-sync.env           → forgejo-sync.env
```

Subdomain stays `gitea.home.lan` (Option A).

### Step 1.5: Update flake.nix serviceModules

Replace the two gitea entries with forgejo entries:
```nix
{ path = ./modules/nixos/services/forgejo.nix; module = "forgejo"; }
{ path = ./modules/nixos/services/forgejo-repos.nix; module = "forgejo-repos"; }
```

### Step 1.6: Update justfile

Rename recipes:
```just
forgejo-sync-repos:   # was gitea-sync-repos
forgejo-update-token: # was gitea-update-token
```

### Step 1.7: Validate build

```bash
just test  # Must pass before proceeding to Phase 2
```

---

## Phase 2: Migration (downtime window ~30 min)

### Step 2.1: Pre-migration backup

```bash
# Stop everything that touches gitea data
sudo systemctl stop gitea-runner-evo-x2 gitea-github-sync.timer gitea-ensure-repos.timer gitea-generate-token gitea-runner-token gitea

# Full backup
sudo cp -a /var/lib/gitea /var/lib/gitea.pre-forgejo-migration

# Verify backup
ls -la /var/lib/gitea.pre-forgejo-migration/gitea.db
```

### Step 2.2: Migrate data

```bash
# Move state directory
sudo mv /var/lib/gitea /var/lib/forgejo

# Change ownership to forgejo user (will be created by nixpkgs module)
# Note: user created by 'just switch' in next step, so we chown after
```

### Step 2.3: Apply new configuration

```bash
just switch
```

This will:
1. Create `forgejo:forgejo` user/group
2. Set up `forgejo.service` systemd unit
3. Start Forgejo on the same port (3000)
4. Caddy continues proxying `gitea.home.lan` → `localhost:3000`

### Step 2.4: Fix ownership

```bash
sudo chown -R forgejo:forgejo /var/lib/forgejo
sudo systemctl restart forgejo
```

### Step 2.5: Verify

```bash
# Check service is running
systemctl status forgejo

# Check web UI
curl -s http://localhost:3000/api/v1/version

# Check existing repos survived
curl -s -H "Authorization: token $TOKEN" http://localhost:3000/api/v1/repos/search | jq '.data | length'

# Check Caddy proxy
curl -sk https://gitea.home.lan/api/v1/version

# Check Actions runner
systemctl status forgejo-runner-evo-x2

# Check mirrors are still syncing
curl -s -H "Authorization: token $TOKEN" http://localhost:3000/api/v1/admin/cron | jq '.[] | select(.name | contains("mirror"))'
```

### Step 2.6: Regenerate tokens

The old Gitea tokens won't work with the new Forgejo instance. Need to:
1. Generate new API token: `forgejo admin user generate-access-token ...`
2. Generate new runner token: `forgejo actions generate-runner-token`
3. These are auto-generated by the token services on first start

---

## Phase 3: GitHub Sync Strategy (improved)

### Current Sync (one-way: GitHub → Gitea)

```
GitHub ──mirror──► Forgejo (pull only, every 30 min)
```

Problems with one-way mirrors:
- Can't push to GitHub from local instance
- Changes on Forgejo side get overwritten on next sync
- No bidirectional collaboration

### Recommended Sync Strategy

**For repos you own (LarsArtmann/*):**

```
Forgejo (primary) ──push mirror──► GitHub (visibility/backup)
```

- Develop locally on Forgejo (`gitea.home.lan`)
- Push mirror automatically syncs to GitHub on every push
- GitHub becomes the public face; Forgejo is the source of truth
- Configure in Forgejo repo settings → "Push mirror" → add GitHub remote

**For third-party repos (starred/forks):**

```
GitHub ──pull mirror──► Forgejo (read-only, every 8h)
```

- Keep existing pull mirror behavior
- These repos aren't pushed to, so one-way is correct

**How to set up push mirrors:**

1. Create a GitHub Personal Access Token with `repo` scope
2. In Forgejo, repo Settings → Mirror → Add push mirror
3. URL: `https://LarsArtmann:<token>@github.com/LarsArtmann/<repo>.git`
4. Check "Sync on commit" for automatic push on every local push

### Automating push mirrors via API

Add to `forgejo-repos.nix` — after creating a pull mirror, also create a push mirror:

```bash
# For each owned repo, create a push mirror to GitHub
curl -X POST \
  -H "Authorization: token $FORGEJO_TOKEN" \
  "$FORGEJO_URL/api/v1/repos/$GITHUB_USER/$repo_name/mirror" \
  -d '{
    "repo_name": "github",
    "remote_address": "https://LarsArtmann:${GITHUB_TOKEN}@github.com/LarsArtmann/'$repo_name'.git",
    "sync_on_commit": true
  }'
```

This ensures every push to Forgejo automatically appears on GitHub.

### Sync safety guarantees

| Concern | Mitigation |
|---------|------------|
| Data loss | Full backup before migration; SQLite dump |
| Token expiry | GitHub tokens stored in sops; auto-refresh via `gh auth token` |
| Mirror conflicts | Owned repos = push mirror (Forgejo→GitHub); third-party = pull mirror (GitHub→Forgejo) |
| Rollback | Keep `gitea.nix` + `gitea-repos.nix` until migration verified; `just rollback` restores previous generation |
| API compatibility | Forgejo API v1 = Gitea API v1; all scripts work unchanged |

---

## Phase 4: Cleanup (after verification period)

### Step 4.1: Remove old modules (after 1 week of stable operation)

```bash
git rm modules/nixos/services/gitea.nix
git rm modules/nixos/services/gitea-repos.nix
```

### Step 4.2: Remove backup data

```bash
# After confirming everything works
sudo rm -rf /var/lib/gitea.pre-forgejo-migration
```

### Step 4.3: Update documentation

- Update AGENTS.md (all gitea references → forgejo)
- Update FEATURES.md
- Remove `docs/forgejo-federation.md` migration note (or update it)

---

## Rollback Plan

If Forgejo doesn't work as expected:

```bash
# 1. Stop Forgejo
sudo systemctl stop forgejo forgejo-runner-evo-x2

# 2. Revert data
sudo mv /var/lib/forgejo /var/lib/gitea
sudo chown -R gitea:gitea /var/lib/gitea

# 3. Rollback NixOS config
just rollback

# 4. Start Gitea
sudo systemctl start gitea
```

Total rollback time: ~5 minutes. Data is safe — Forgejo doesn't modify the DB schema in incompatible ways.

---

## Execution Checklist

### Phase 1 (prep, no downtime)
- [ ] Create full backup of `/var/lib/gitea`
- [ ] Write `modules/nixos/services/forgejo.nix` (port from gitea.nix)
- [ ] Write `modules/nixos/services/forgejo-repos.nix` (port from gitea-repos.nix)
- [ ] Update `caddy.nix` — change `config.services.gitea` → `config.services.forgejo`
- [ ] Update `authelia.nix` — keep `gitea` client_id (subdomain unchanged)
- [ ] Update `homepage.nix` — update port reference
- [ ] Update `gatus-config.nix` — update port reference + service name
- [ ] Update `signoz.nix` — change `gitea.service` → `forgejo.service` in journald units
- [ ] Update `sops.nix` — rename service references in restartUnits + template name
- [ ] Update `dns-blocker-config.nix` — keep `gitea` subdomain (no change needed)
- [ ] Update `rpi3/default.nix` — keep `gitea` subdomain (no change needed)
- [ ] Update `flake.nix` — replace gitea serviceModules entries with forgejo
- [ ] Update `configuration.nix` — switch `gitea.enable` → `forgejo.enable`
- [ ] Update `justfile` — rename gitea recipes to forgejo
- [ ] Run `just test` — verify build passes
- [ ] Commit Phase 1 changes

### Phase 2 (migration, ~30 min downtime)
- [ ] Stop all gitea services
- [ ] Create pre-migration backup
- [ ] Move `/var/lib/gitea` → `/var/lib/forgejo`
- [ ] Run `just switch`
- [ ] Fix ownership (`chown -R forgejo:forgejo`)
- [ ] Verify Forgejo starts and serves repos
- [ ] Verify token generation works
- [ ] Verify Actions runner connects
- [ ] Verify Caddy proxy works
- [ ] Verify GitHub mirrors still sync
- [ ] Set up push mirrors for owned repos (Forgejo → GitHub)
- [ ] Commit Phase 2 (any hotfixes)

### Phase 3 (cleanup, after verification)
- [ ] Remove old `gitea.nix` and `gitea-repos.nix`
- [ ] Remove backup data
- [ ] Update AGENTS.md
- [ ] Final commit

---

## Open Questions

1. **Subdomain rename?** — Recommendation: keep `gitea.home.lan` for now, rename later
2. **Database upgrade?** — Forgejo may auto-migrate the SQLite schema on first start (irreversible but safe)
3. **Actions runner compatibility** — `gitea-actions-runner` package should work with Forgejo; may want to switch to `forgejo-runner` package if available in nixpkgs
4. **Push mirror token storage** — GitHub PAT for push mirrors needs to be in sops or a Forgejo secret
