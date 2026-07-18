# YouTube Frontend Alternatives for Self-Hosting

**Purpose:** Research self-hosted YouTube frontends to redirect blocked YouTube URLs to a local, privacy-respecting alternative.

**Status:** Research complete, awaiting implementation decision.

---

## Options Overview

| Option        | NixOS Support | Maintenance | Features | YT Blocking Resistance | Resource Usage           |
| ------------- | ------------- | ----------- | -------- | ---------------------- | ------------------------ |
| **Invidious** | Excellent     | Medium      | Basic    | Poor                   | Low (Crystal binary)     |
| **Piped**     | None          | High        | Full     | Better                 | High (Java + containers) |
| **FreeTube**  | Desktop only  | Low         | Full     | Medium                 | Medium (Electron)        |

---

## Invidious

**GitHub:** https://github.com/iv-org/invidious
**Language:** Crystal
**License:** AGPL-3.0

### Pros

- Native NixOS module: `services.invidious.enable = true`
- Single binary, lightweight
- No JavaScript required (works without JS)
- Built-in subscription system
- Reddit comments integration
- Simple single-container deployment

### Cons

- YouTube actively blocks instances (only 3 public instances remain)
- Known instability (requires hourly restarts)
- No SponsorBlock integration
- No Return YouTube Dislike
- IP blocks from YouTube possible

### NixOS Configuration

```nix
services.invidious = {
  enable = true;
  port = 3000;
  settings = {
    domain = "tube.local";
    https_only = false;
    channel_threads = 1;
    feed_threads = 1;
    db.user = "invidious";
    db.dbname = "invidious";
  };
};

# PostgreSQL required
services.postgresql = {
  enable = true;
  ensureDatabases = [ "invidious" ];
  ensureUsers = [{
    name = "invidious";
    ensureDBOwnership = true;
  }];
};
```

### Resource Requirements

- RAM: ~200-500MB
- CPU: Low
- Storage: ~1GB (including PostgreSQL)

---

## Piped

**GitHub:** https://github.com/TeamPiped/Piped
**Language:** Java (backend), Vue.js (frontend)
**License:** AGPL-3.0

### Pros

- SponsorBlock integration
- Return YouTube Dislike support
- Better YouTube blocking resistance (federated architecture)
- Modern Vue.js interface
- PWA support (installable)
- Multiple instances can share load

### Cons

- No NixOS module (requires Podman/Docker)
- Complex multi-container setup (4+ containers)
- Java backend = higher RAM usage
- More maintenance overhead
- Requires: backend, frontend, proxy, yt-dls-api, Postgres

### Container Setup Required

```bash
# Services needed:
# - piped-backend (Java)
# - piped-frontend (Vue.js, static)
# - piped-proxy (for video proxying)
# - piped-yt-dlp-api (for downloads)
# - postgres (database)
# - nginx/traefik (reverse proxy)
```

### Resource Requirements

- RAM: ~1-2GB
- CPU: Medium
- Storage: ~5GB

---

## FreeTube

**GitHub:** https://github.com/FreeTubeApp/FreeTube
**Language:** Electron/JavaScript
**License:** AGPL-3.0

### Pros

- Native desktop application
- Works offline (local database)
- Privacy-focused (no telemetry)
- Good NixOS package support
- SponsorBlock built-in
- Return YouTube Dislike built-in

### Cons

- Desktop app only (no web interface)
- Not self-hostable as a service
- Depends on external Invidious/Piped instances
- Can't redirect browser URLs to it

### NixOS Configuration

```nix
environment.systemPackages = [ pkgs.freetube ];
```

**Note:** Not suitable for our use case (redirect from dnsblockd).

---

## dnsblockd Integration

### Redirect Strategy

When dnsblockd blocks a YouTube URL, redirect to local instance:

```
https://www.youtube.com/watch?v=VIDEO_ID
    ↓ blocked by dnsblockd
    ↓ redirect to
http://tube.local:3000/watch?v=VIDEO_ID
```

### URL Patterns to Handle

```
# Videos
youtube.com/watch?v=VIDEO_ID
youtu.be/VIDEO_ID
m.youtube.com/watch?v=VIDEO_ID

# Channels
youtube.com/@channelname
youtube.com/c/channelname
youtube.com/channel/CHANNEL_ID
youtube.com/user/username

# Playlists
youtube.com/playlist?list=PLAYLIST_ID

# Shorts
youtube.com/shorts/VIDEO_ID
```

### Implementation in dnsblockd

```go
// In block page handler, parse YouTube URL and redirect
func buildRedirectURL(blockedURL string) string {
    // Extract video ID from various YouTube URL formats
    // Return local instance URL with same video ID
}
```

### Block Page Behavior

1. User navigates to YouTube URL
2. dnsblockd blocks and serves block page
3. Block page shows "YouTube blocked" with option:
   - "Watch on local instance" button
   - Auto-redirect option (configurable)
   - "Continue anyway" (temporary bypass)

---

## Recommendation

### Primary: Invidious

**Reasoning:**

1. Native NixOS support = easy deployment
2. Lightweight = low resource usage
3. Simple architecture = less maintenance
4. Good enough for personal use

**Mitigation for downsides:**

- Set up cron job to restart Invidious every hour
- Monitor for YouTube blocking, switch to Piped if needed
- Use with VPN to reduce IP blocking risk

### Fallback: Piped

If Invidious proves too unstable:

1. Deploy via Podman quadlet
2. Higher resource usage but better resilience
3. More features (SponsorBlock, Dislikes)

---

## Implementation Checklist

- [ ] Deploy Invidious on NixOS
- [ ] Configure local domain (tube.local or similar)
- [ ] Add YouTube domains to dnsblockd blocklist
- [ ] Implement redirect logic in dnsblockd block page
- [ ] Add "Watch on local instance" button to block page
- [ ] Test video/channel/playlist redirects
- [ ] Set up Invidious restart cron job
- [ ] Monitor for YouTube blocking issues

---

## References

- [Invidious Documentation](https://docs.invidious.io/)
- [Invidious NixOS Module](https://search.nixos.org/options?channel=unstable&query=invidious)
- [Piped Documentation](https://docs.piped.video/)
- [FreeTube Website](https://freetubeapp.io/)
- [Privacy Redirect Browser Extension](https://github.com/SimonBrazell/privacy-redirect)

---

## Notes

- YouTube has been aggressively fighting alternative frontends since 2023
- Public Invidious instances dropped from 40+ to 3
- Self-hosted instances work better (less likely to be blocked)
- Consider combining with VPN for additional protection
- SponsorBlock and Return YouTube Dislike require Piped or browser extensions
