# DNS Blocker Improvement Ideas

**Last Updated:** 2026-03-27

---

## Implemented Features

### Temporary Bypass Button ✅ (2026-03-27)

- Added "Allow 5m/15m/1h" buttons to block page
- POST `/api/allow` endpoint accepts domain and duration
- GET `/api/temp-allowlist` shows current temp allows
- Temp allowlist persisted to `/var/lib/dnsblockd/temp-allowlist.json`
- Generates unbound config at `temp-allowlist.json.conf` with `local-zone: transparent` directives
- Background goroutine cleans expired entries every minute
- Unbound reloads automatically when allowlist changes

### Deduplication ✅ (2026-03-27)

- Blocklist domains are deduplicated with `lib.unique`
- Whitelisted domains filtered from final block list
- Combined blocklist shows unique domain count

### Additional Blocklists ✅ (2026-03-27)

Added to default config (need hash updates):

- OISD Small (ads+malware+tracking)
- HaGeZi TIF (threat intelligence)
- NoCoin (cryptojacking)

---

## User Experience

### 1. Temporary Bypass Button

Add "Allow for 5/15/60 min" button on block page. When clicked:

- Domain is added to a temporary allowlist (stored in `/var/lib/dnsblockd/temp-allowlist.json`)
- unbound reloads to use the updated allowlist
- After expiry, domain is automatically removed

**Implementation:**

- dnsblockd: Add `/api/allow?domain=example.com&duration=15m` endpoint
- dnsblockd: Store temp allowlist in JSON with expiry times
- dnsblockd: Background goroutine cleans expired entries every minute
- NixOS module: Add `tempAllowlistPath` option
- unbound: Add `include:` directive for temp allowlist file

### 2. Desktop Notifications

Send dbus notification when domains are blocked (optional, configurable).

**Implementation:**

- dnsblockd: Add `-notify` flag
- Use `github.com/godbus/dbus` to send `org.freedesktop.Notifications`
- Rate-limit to max 1 notification per 10 seconds

### 3. CLI Tool (`dnsblockctl`)

```bash
dnsblockctl check doubleclick.net     # Check if domain is blocked and why
dnsblockctl allow temp doubleclick.net 15m  # Temp allow
dnsblockctl allow list               # List temp allowed domains
dnsblockctl stats                    # Show blocking statistics
dnsblockctl top 10                   # Show top 10 blocked domains
```

---

## Analytics

### 4. Web Dashboard

Serve a simple dashboard at `http://127.0.0.2:8080/`:

- Real-time blocked request count (WebSocket)
- Graph: Blocked requests over last 24 hours
- Top blocked domains table
- Recent blocks list with timestamps
- Pie chart: Categories breakdown

**Implementation:**

- dnsblockd: Add `-dashboard-port 8080` flag
- Serve static HTML/CSS/JS (embedded in binary)
- WebSocket endpoint for real-time updates
- Stats persisted to SQLite for historical data

### 5. Per-Client Stats

Track which local user/client triggered the block:

- Parse `X-Forwarded-For` if behind proxy
- Or use unbound logging to correlate DNS queries with blocks

---

## Security

### 6. Malware/Phishing Blocklists

Add additional blocklists focused on security:

```nix
blocklists = [
  { name = "StevenBlack-ads"; url = "..."; hash = "..."; }
  { name = "StevenBlack-malware"; url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling/hosts"; hash = "..."; }
  { name = "OISD"; url = "https://big.oisd.nl/"; hash = "..."; }
  { name = "PhishingArmy"; url = "https://phishing.army/download/urlhaus-phishing/"; hash = "..."; }
];
```

### 7. Per-Category Blocking

Allow users to enable/disable categories:

```nix
categories = {
  enable = [ "Advertising" "Tracking" "Malware" ];
  disable = [ "Analytics" ];  # Allow analytics through
};
```

### 8. Click-to-whitelist for admins

Add a secret admin page at a special URL (e.g., `http://127.0.0.2/admin?secret=...`):

- Shows all blocked domains
- Click to permanently whitelist
- Password protected or localhost only

---

## Performance

### 9. DNS Caching Stats

Track cache hit rate:

- Add `/stats/cache` endpoint
- Report unbound cache statistics via unbound-control socket

### 10. Preload Common Domains

At startup, generate certs for top 100 blocked domains to avoid first-request latency.

---

## Operations

### 11. Blocklist Auto-update

Weekly systemd timer to fetch new blocklists:

```nix
systemd.timers.dnsblockd-update = {
  onCalendar = "weekly";
  script = "${pkgs.dnsblockd}/bin/dnsblockd-update";
};
```

### 12. Export Stats

Export statistics to Prometheus, InfluxDB, or JSON file:

```bash
dnsblockctl export prometheus  # Push to Prometheus pushgateway
dnsblockctl export json > stats.json
```

### 13. Allow/Deny Log

Audit log of all manual allow/deny actions with timestamp and user.

---

## Priority Ranking

| Priority | Feature                | Effort | Impact                   |
| -------- | ---------------------- | ------ | ------------------------ |
| 1        | Temporary Bypass       | Medium | High - UX improvement    |
| 2        | Web Dashboard          | High   | High - Visibility        |
| 3        | CLI Tool               | Low    | Medium - Convenience     |
| 4        | Desktop Notifications  | Low    | Medium - Awareness       |
| 5        | Malware Blocklists     | Low    | High - Security          |
| 6        | Per-Category Blocking  | Medium | Medium - Flexibility     |
| 7        | Blocklist Auto-update  | Low    | Medium - Maintenance     |
| 8        | Export Stats           | Medium | Medium - Observability   |
| 9        | DNS Caching Stats      | Low    | Low - Performance tuning |
| 10       | Per-Client Stats       | High   | Low - Debugging          |
| 11       | Preload Common Domains | Low    | Low                      | Performance |
| 12       | Allow/Deny Log         | Low    | Low                      | Audit       |

---

## Quick Wins (Easy to implement)

1. **CLI Tool** - Simple Go binary that calls the stats API
2. **Desktop Notifications** - dbus integration is straightforward
3. **Malware Blocklists** - Just add more URLs to config
4. **Blocklist Auto-update** - Simple systemd timer

## Recommended Implementation Order

1. Temporary bypass (biggest UX win)
2. CLI tool (enables easier testing/management)
3. Web dashboard (visibility into what's being blocked)
4. Desktop notifications (optional, nice to have)
5. Additional security blocklists
