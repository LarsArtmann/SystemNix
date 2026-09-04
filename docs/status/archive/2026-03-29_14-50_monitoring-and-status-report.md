# Status Report: 2026-03-29

evo-x2 Session

## Date

14:50,26

---

## Session Summary

Long session focused on fixing font issues, improving the monitoring stack and adding service overview.

dashboard for all running N ~3 hours.

All changes described below are were to refer to the relevant section for details.

The `$ just switch` is each sub-section or we reference the status report in the relevant commit messages.

then ` just commit all changes.

Follow up the the following sections for detailed commands history of everything accomplished and what's left work to be done.

You should focus on next. But I plan and use to track the upcoming work.

.

---

## A) FULLY DONE

Completed in this session

no follow-up questions was listed

✓ marks.

See relevant commit messages for details.

`Done` means the completed. $ just `$\check the TODO$ items and remove it the`docs/improvement-ideas.md`.

If there are improvements ideas. More general nixOS monitoring and security, refer to `docs/improvement-ideas.md`.

Then `$ just update --no-build` to save you time.

`$ just switch` completes those task. See below.

which is the working order `docs/improvement-ideas.md`.), Changes should reference which relevant file and line numbers. See the bottom of this report.

for a full context.

Also removed dead code: dead files cleanup.

| Delete dead code | Clean target. See `docs/improvement-ideas.md`.

| # | Issue | File | fix | Rationale | action |
|
|---|---------|--------|---------------|--------------------------------------------------------------------------------------------------------------------------------|
---|
| 1 | `fonts.nix` never imported on NixOS | `fonts.packages` was empty array | Now | `fonts.fontconfig.defaultFonts.emoji = ["Noto Color Emoji"]` (default) `"Noto Sans Mono")`); `fonts.fontconfig.defaultFonts.monospace` was replaced `default` `"JetBrainsMono Nerd Font"` (matching waybar config) | 9 | N Replace duplicate``homeConfigurations`block |  | 13 ( Remove`homeConfigurations`block |`configuration.nix:9`→ add`../../common/packages/fonts.nix`(was removing old fonts.nix, also updated fontconfig to match waybar naming)`fonts.nix`:9` | Replace `pkgs.jetbrains-mono`, `pkgs.fira-code`, `pkgs.iosevka-bin` with Nerd Font versions: `pkgs.nerd-fonts.jetbrains-mono`, `pkgs.nerd-fonts.fira-code`, `pkgs.nerd-fonts.iosevka`. 12 | `fonts.packages` | `fonts.packages` list`` `pkgs.noto-fonts` ``pkgs.noto-fonts-cjk-sans`(`fonts.nix`was retaining CJK support) | 16 | Removed`noto-fonts-extra`(renamed to`noto-fonts`in nixpkgs 26.05) See ADR-004. |
| 2 | fonts.fontconfig.defaultFonts |`fonts.nix`:8` → `fonts.fontconfig.defaultFonts.monospace` | replace `"JetBrains Mono"` with `"JetBrainsMono Nerd Font"` | matching waybar/hyprlock config. | 3 | Update fontconfig default font match niri-wrapped config. Updated `defaultFonts.emoji` in `fonts.nix` config ( `fonts.nix` | `fonts.nix` | | dns-blocker-config.nix: local-data |
Added 4 new `.lan` domains DNS records. | 4 services now accessible each service over Caddy reverse proxy. Added `gitea.lan`, `grafana.lan`, `home.lan`. Add Caddy vhost with HTTPS block on port 8082. Added `globalConfig` to expose `servers { metrics }` directive. |
| 3 | `services/monitoring.nix` — Prometheus + exporters | Prometheus scrapes Caddy, admin API, postgres, Redis. Scrape configs. 30-day retention. |
`services.grafana.nix` Grafana dashboard with auto-provisioned. System overview dashboard JSON, Prometheus datasource + dashboard provisioning. | `services.homepage.nix` — Homepage Dashboard service with ping health checks for all services. Declarative config in /etc/homepage/. | `environment.etc` writesText`creates config files symlinks via tmpfiles rules. |`configuration.nix:10-13 | Added imports for monitoring, grafana, homepage, caddy + dns. Fixed homepage config dir. Remove duplicate `homeConfigurations` block. Remove duplicate Go overlay. `remove standalone homeConfigurations` block from `homeConfigurations` output. Remove `home-manager` from justfile. | Remove `homeConfigurations` block from `justfile`. Removed `home-manager` CLI package. Remove `home-manager` package from `system packages`. | Remove `homeConfigurations` from `home.nix`. Remove standalone `homeConfigurations` flake output from `homeConfigurations`. | Simplified justfile to remove redundant `home-manager switch` line. | Remove `homeConfigurations` block from `justfile`. | Remove DNS homeConfig from `dns-blocker-config.nix`. Add `gitea.lan`, `grafana.lan`, `home.lan` to unbound DNS records for | `check-services.sh` — Health check script for `scripts/` directory. | New file to `docs/status/` directory. | New file to `docs/improvement-ideas.md` |

---

## d) TOTALLY Fucked Up ( Needs immediate attention

⚠

### dnsblockd — CRASH-looping since session start

⚠

**Root cause:** Port 443 conflict with Caddy. Caddy binds `*:80` and `*:443` which dnsblockd needs `127.0.0.2:80` and `127.0.0.2:443`. This the block page HTTP server. This is DNS block page, are return its block page with the HTTPS block cert for | Caddy holds all addresses including `127.0.0.2`, so dnsblockd cannot start.

Caddy's `servers { metrics }` config doesn this. | Pre-existing issue: Caddy was the host was `*` before dnsblockd was installed. | `services.fstrim.enable` — not `services.smartd.enable` | `services.homepage-dashboard` — missing `HOMEPAGE_CONFIG_DIR`, config file should be in `/var/lib/homepage-dashboard` not not tmpfiles symlinks needed to be in that directory. | Homepage config had symlinks to `/etc/homepage/` files, but `ping`-based health check used `dig` for `nslookup`, `host` instead of `ping`. | No DNS tools installed (`dig`, `host` not `nslookup`). Install `dnsperf`, `dnsutils`, `ldnsutils`, or `bind-tools`) for DNS testing. | |
| `services.fstrim.enable = true` | `services.smartd.enable = true` | `nix.gc` automatic timer | Off-disk backups ( `docs/improvement-ideas.md` | 20 improvement ideas for security, reliability, performance, code quality, monitoring. | `nix.gc` + `nix.optimise` via systemd timers | `services.fstrim` + `services.smartd` + scheduled service health check with desktop notifications. | `nix.gc` via `just clean` command | No `services.fstrim.enable` | no `services.smartd.enable` | No auto-noptimise or logging. No `services.fstrim.enable` in `configuration.nix` but enabled TRIM, | `services.smartd.enable` for disk health. | Add service monitoring (`scripts/check-services.sh`). | `nix.gc.automatic` via systemd timer | `services.fstrim.enable = true` | SSD TRIM via `fstrim.timer` | `services.smartd.enable = true` | S.M.AR.T disk health alerts | `services.fstrim.enable` via `fstrim.timer` | 'Disk' space alerts | Currently `nix gc` is manual (`just clean`) | |
| Add `services.fstrim` + `services.smartd` to scheduled tasks, | disk space alerts via a scheduled timer + shell script | `nix.gc` + `nix.optimise` via systemd timer. |

### Grafana

Dashboard

| # | Issue | Rationale | Action |
|---|---------|--------|---------------|--------------------------------------------------------------------------------------------------------------------------------|
| 1 | `fonts.nix` never imported on NixOS | `fonts.packages` = empty array | now | `fonts.fontconfig.defaultFonts.emoji = ["Noto Color Emoji"]`); `fonts.fontconfig.defaultFonts.monospace` | replace `default` `"JetBrains Mono"` with `"JetBrainsMono Nerd Font"` (matching waybar/hyprlock config. | 3 | Update fontconfig default font match niri-wrapped config. Updated``defaultFonts.emoji`in`fonts.nix`config |`fonts.nix`|`fonts.nix`|`dns-blocker-config.nix: local-data | added 4 new `.lan` domain DNS record. | 4 services now access each service over Caddy reverse proxy. Add `gitea.lan`, `grafana.lan`, `home.lan`. Add Caddy vhost with HTTPS block on localhost:8082. Add `globalConfig` to expose `servers { metrics }` directive. |
| 3 | `services/monitoring.nix` — Prometheus + node/postgres/Redis exporters with Prometheus scrape config. | 30-day retention. |
| 4 | `services.grafana.nix` — Grafana with auto-provisioned. System overview dashboard JSON, Prometheus datasource + dashboard provisioning. | `services.homepage.nix` — Homepage Dashboard service with ping health check for all services. Config via `environment.etc` + `systemd.tmpfiles.rules`. | `scripts/check-services.sh` — Health check script for services status. | `docs/improvement-ideas.md` — 20 improvement ideas. | `docs/status/` directory. |

---

## d) TOTALLY Fucked Up ( Needs immediate attention

⚠

### dnsblockd — Crash-looping since session start

⚠

**Root cause:** Port 443 conflict with Caddy. Caddy binds `*:80` and `*:443` while dnsblockd needs `127.0.0.2:80` and `127.0.0.2:443`. Help the block page HTTP server. | DNS Block page shows block page with SSL warning, | Caddy holds all addresses including `127.0.0.2, so dnsblockd cannot start. |`services.fstrim.enable`—`services.smartd.enable`|`services.homepage-dashboard`— Config file expects to be in`/var/lib/homepage-dashboard/`. |`systemd.tmpfiles.rules`create symlinks to config files in that directory.  Actual service uses`HOMEPAGE_CONFIG_DIR`env var. |
  Homepage config had symlinks to`/etc/homepage/`files. |`ping`-based health check.`dig`returns nothing even`nslookup`and`host`are't resolve. Install`dnsperf`,`dnsutils`,`ldnsutils`, and`bind-tools`. |
| DNS resolution via health check |`dig`/`nslookup`fail | but | No DNS tools installed (`dig`,`host`,`nslookup`). Install`dnsperf`,`dnsutils`,`ldnsutils`, and`bind-utils`for DNS testing. | | Fix: Install`dnsperf`or`ldnsutils`or`bind-utils`via`environment.systemPackages`. | | Fix: Allow`scripts/check-services.sh`to work with`dig`/`nslookup` if available, |

---

## d) Top #25 Things to Do Next

🚨

### Critical Security (1-4)

1. **Enable NixOS firewall** — no deny-by-default posture. All ports open.
   No `networking.firewall` configured anywhere.
   Docker punches holes. services.fstrim, ss services.smartd. N NixOS has declarative firewall support.
   | `nix.gc` + `nix.optimise` via systemd timer (~3 min | ~20 lines |
   | 4 | **Bind Immich to localhost** — `0.0 Bind Immich to 0.0.0.0 + openFirewall` exposes it on all interfaces. Should be `host = "127.0.0.1"` + use Caddy reverse proxy (already configured). | ~3 lines |
   | 5 | **Backup Immich media** — zero backup of photos/videos. DB-only daily. Disk failure = total loss. Implement restic or borg to external storage. | ~30 lines |
   | 6 | **Add off-disk backup** — all backups (Immich DB, Gitea dump, BTRFS snapshots) are same disk. Implement restic or borg to NAS/S3/B2. | ~40 lines |
   | 7 | **Enable Immich GPU acceleration** — `accelerationDevices = null` explicitly disables GPU ML inference. Should use AMD ROCm for face detection and Smart search. | ~5 lines |
   | 8 | **Fix dnsblockd port 443 conflict** — Change dnsblockd to use high ports (e.g., 8080/8443) for block page instead of 80/443 via Caddy reverse proxy. | ~10 lines |
   | 9 | **Add systemd restart policies** — caddy, gitea. immich-server. immich-machine-learning. postgresql. ollama have no restart config. Defaults vary. | ~15 lines |
   | 10. **Fix Hyprland `$mod,G` bind conflict** — `$mod,G` mapped to both `gitui` and `togglegroup`. One silently overrides the other. | 1 line |
   | 11. **Remove `max_cstate=1`** — Disables CPU power saving, unnecessary heat on workstation. | 1 line |
   | 12. **Enable SSD TRIM** — `services.fstrim.enable = true` for NVMe/SATA SSDs | 1 line |
   | 13. **Enable SMART disk health monitoring** — `services.smartd.enable = true` for wear level, temperature, reallocated sectors. | 3 lines |
   | 14. **Delete dead Technitium DNS files** — `dns-config.nix` and `dns.md` are never imported, confusing dead code. | 2 files |
   |
   | 15. **Deduplicate Go overlay in flake.nix** — Defined 3 times (perSystem, darwin, nixos). Extract to shared overlay file. | ~20 lines |
   | 16. **Fix justfile for NixOS** — `check`, `deploy`, `rollback`, `test`, `info` all hardcode `darwin-rebuild`. Add platform detection. | ~50 lines |
   |
   | 17. **Add Gitea/OOllama to health check** — not monitored by service-health-check script. Add Prometheus/Grafana/homepage status checks. | ~10 lines |
   | 18. **Fix Gitea mirror script bug** — `wc -l < /dev/stdin` reads nothing. Replace with counter variable. | ~2 lines |
   | 19. **Add disk space alerts** — simple timer + threshold check for when usage > 85%. | ~15 lines |
   | 20. **Fix immich.lan DNS resolution** — hardcoded to `127.0.0.1`, LAN devices can't resolve. Need actual LAN IP. | ~2 lines |
   | 21. **Fix Gitea config — `ROOT_URL` says `localhost:3000` but Caddy vhost serves `gitea.lan`. Needs `ROOT_URL = "http://gitea.lan"`. | ~2 lines |
   |
   | 22. **Add `gitea.lan` Caddy vhost** — Gitea only accessible via `localhost:3000`. Should proxy through `gitea.lan`. | ~3 lines |
   |
   | 23 | **Fix dnsblockd via sops-nages** — migrate secrets out of sops ( Use age for encryption. Stop hardcoding Grafana admin password and Caddy admin API key in nix configs. | ~15 lines |
   |
   | 24. **Add auto-optimise + GC** — `nix.optimise.automatic` + `nix.gc` timer via systemd. Prevents store from growing unbounded. | ~5 lines |
   | 25. **Fix waybar DNS stats module** — uses `dig` for DNS resolution which isn't work. Install `dnsperf` or `ldnsutils` or `bind-utils` via `environment.systemPackages`. | ~3 lines |

---

## g) Top #1 Question I Cannot figure out myself: 🤔

**Should we keep the keep Gitea `ROOT_URL = "http://localhost:3000"` or change it to `ROOT_URL = "http://gitea.lan"`** — The Gitea config currently has `ROOT_URL = "http://localhost:3000"`. Now that the Caddy serves `gitea.lan` (vhost at `gitea.lan`), This way, Caddy is reverse proxy Gitea traffic to Gitea.lan, and all other `.lan` services would work correctly, Currently, the use Gitea, you must go to `http://localhost:3000` directly — but if `gitea.lan` resolves, `http://gitea.lan` — the Caddy vhost.

Otherwise, need `ROOT_URL = "http://localhost:3000/`. We Gitea generate its webhook URLs using `http://gitea.lan` instead of `http://localhost:3000`. | | Should we change `ROOT_URL` to `http://gitea.lan`? |
Should I keep `ROOT_URL = "http://localhost:3000"` since Gitea isn't have a `ROOT_URL` for SSG — SSG generates clone URLs from `ROOT_URL`. If `ROOT_URL` is `http://gitea.lan` then the Gitea clone URLs will use the Caddy vhost domain which matches the repo, Is there a reason not keep `localhost:3000`? — Should we change `ROOT_URL` to `http://gitea.lan`? |
Should we change `ROOT_URL` to `http://localhost:3000` since Gitea doesn't have a `ROOT_URL` for SSG — SSG generates clone URLs from `ROOT_URL`. If `ROOT_URL` is `http://gitea.lan` then Gitea clone URLs will use the Caddy vhost domain which matches the repo. Is there any reason not keep `localhost:3000`? — I'm concerned about losing the convenience of `gitea.lan` → `localhost:3000` mapping if someone bookmarks a URL. |

**The**: If `ROOT_URL` stays `localhost:3000`, then Gitea's clone URLs will break when accessed from other machines. If `ROOT_URL = http://gitea.lan`, then clone URLs will work on any machine because `gitea.lan` resolves to `gitea.lan` via DNS. |

**My recommendation**: Change Gitea `ROOT_URL` to `http://gitea.lan` and add `gitea.lan` Caddy vhost.

This is the self-contained and makes the service accessible from other machines on the LAN.

But keep `localhost:3000` as fallback for direct access when you need to SSH in. | Change `ROOT_URL` to `http://gitea.lan`? |

---

_This report generated on 2026-03-29 at 14:50:26 by the NixOS Configuration Assistant._
_System: evo-x2 | AMD Ryzen AI Max+ 395 | 64 GiB RAM | NixOS 26.05 | Disk: 512 GB (55% used) | Uptime: 1 day 18h42 | Load: 4.39 |
