# PBX (Hetzner) traffic into GeoMetrikks (geo.home.lan) — Feasibility + Design

**Date:** 2026-10-16 · **Feeds:** owner ask "can we feed the Hetzner traffic into geo.home.lan too?" · **Context:** GeoMetrikks live on evo-x2 since 2026-09-29 (native Nix, v0.19.0 — runbook `docs/services/geometrikks.md`), tailing local Caddy vhost logs; the PBX is an internet-facing Hetzner box whose WEB traffic (nginx: webphone, webhooks, gates, operator, auth surfaces) is invisible to the map today.

**Verification discipline:** every upstream claim below was read from the PINNED v0.19.0 package in the nix store (`01g2i01c…-geometrikks-0.19.0`, site-packages read directly) or the tag's README on GitHub (fetched raw 2026-10-16). Repo facts from local reads; sibling-module facts from the pinned `telephony` input source (`31af29ae`).

---

## 1. Answer: yes — upstream built exactly for this, two shapes

GeoMetrikks v0.19.0 is multi-source by design (README "Multi-source setup"):

1. **Shipped files** — one full instance tails files from other machines; `LOGPARSER_HOST_NAME` is a JSON list positional to `LOGPARSER_LOG_PATHS`, so each file is labeled as its own source ("access-logs hostname filter, the map's Source filter, per-site homes treat those files like traffic from separate agents"). README: *"If the log files already reach one machine (a shared mount, rsyslog, log shipping), a single full instance can tail them all."*
2. **`APP_MODE=agent`** — a headless second instance on the PBX ingesting locally and writing straight into the SHARED TimescaleDB. Upstream's own WARNING: agent = ordinary DB credentials with full read/write, no tenant isolation — "run agent connections over a VPN or tailnet".

**Recommendation: shape 1 (shipped files, PULL-based).** Shape 2 puts a Python app + GeoLite2 state + DB credentials on the 8 GB PBX and demands agent↔head version lockstep across two repos; shape 1 puts ONE file on a timer and reuses the existing instance. The README's trust warning disappears entirely when nothing on the PBX talks to the DB.

## 2. Verified facts the design rests on

| Fact | Where verified |
| --- | --- |
| Formats supported per file: `auto`, `geometrikks-json`, `nginx`, `traefik-json`, `caddy-json`; `LOGPARSER_LOG_FORMATS` single-or-positional list | `config/settings.py` `log_formats` field, pinned package |
| `LOGPARSER_HOST_NAME` single-or-positional list; default = machine hostname | same, `host_name` field |
| nginx recommended `log_format` = keyed JSON (`geometrikks_json`, `escape=json`); only `client_ip`+`timestamp` required; `host` feeds the host filter; timings feed latency analytics; stock `combined` lines ALSO parse but lose host + timings | README v0.19.0 "Nginx setup" + "Backfilling logs written in another format" |
| Tailer rotation detection: inode change OR ≥99% size shrink ⇒ reopen, read new file from start; missing file ⇒ keep polling, reopen on reappear | `services/logparser/logparser.py` `_is_rotated_async` |
| `MAP_HOME_LOCATIONS={"<host>": [lat, lon]}` pins a source's map home; README explicitly lists "logs shipped from another machine" as the pin case | README "Site homes" |
| import-logs double-count warning applies to RE-importing tailed content; live rotation re-read is the new file only | README IMPORTANT box + tailer code |
| PBX nginx: sibling module enables `services.nginx` (web.nix:345) with default `access.log` (combined) untouched; ONE vhost overrides to the scanner log (fail2ban jail) | pinned `telephony` source `31af29ae`, web.nix:388 |
| Pull transport exists: evo-x2 → `root@pbx.artmann.tech` ssh (PBX's only authorized key = `lars@evo-x2`), rsync pull, PBX holds zero credentials | `pbx-artmann/backups/evo-x2/README.md` |
| Both hosts are NetBird peers (PBX peer since 2026-10-14) | pbx AGENTS.md + SystemNix docs |
| Module today sets ONLY `LOGPARSER_LOG_PATHS` (derived from local Caddy vhosts); no FORMATS/HOST_NAME envs, no extraLogFiles option | `modules/nixos/services/geometrikks.nix:485` |

## 3. Design

**PBX side (pbx-artmann repo, host-level — NO sibling-module change needed):**

- `services.nginx.commonHttpConfig` adds the upstream `geometrikks_json` log_format verbatim (README copy).
- The pbx vhost gets a SECOND `access_log /var/log/nginx/geometrikks.log geometrikks_json;` (nginx writes both; the scanner log and its fail2ban jail are untouched). Host-repo `extraConfig` mkAfter suffices.
- v0 fallback: ship the existing combined `access.log` as-is (parses; host filter + timing columns empty). The log_format change is the quality upgrade, not a gate.

**evo-x2 side (SystemNix repo):**

- New module option `services.geometrikks.extraLogFiles = [ { path, format ? "auto", hostName } ]`; the unit env gains `LOGPARSER_LOG_FORMATS` + `LOGPARSER_HOST_NAME` as positional lists covering ALL paths (caddy files labeled `evo-x2`, extras labeled per entry), `LOGPARSER_LOG_PATHS` extended.
- **Pull unit + timer (1 min)**: rides the existing `root@pbx.artmann.tech` ssh key (same path as the backup pull; PBX gets NO new credential, preserving the pull doctrine). Offset-state append-delta: remote `stat -c %s` → if size < stored offset (PBX-side rotation) reset offset to 0 → `tail -c +$((offset+1))` appended to `/var/lib/geometrikks-remote-logs/pbx-access.log` → persist new offset. Append keeps the same inode, so the tailer sees pure growth (verified rotation logic — no spurious re-reads). Local feed-file rotation is safe when done rename-style (new inode = clean rotation event, new file read from start).
- `MAP_HOME_LOCATIONS = { pbx = [ 60.17, 24.94 ]; }` — pin the PBX home beacon to Helsinki (Hetzner hel1); unpinned, a shipped source inherits the head's detected home and both beacons overlap.
- Runbook section + gatus/freshness: the pull timer's absence of new rows is worth a textfile staleness metric (phantom-metric rule applies — probe before wiring).

**Boundary (honest scope):** this feeds the PBX's **web plane** (nginx-fronted: webphone, Telnyx webhooks, gates, operator, recordings). SIP/5060 scanning, Stalwart mail, and NetBird-dashboard traffic do NOT pass nginx and stay off the geo map — that class remains CrowdSec/fail2ban territory (LAPI stage 2+ already queued), which is detection, not geo display.

## 4. Traps pinned in advance

- **Offset vs rotation race:** lines written between the last pull and a PBX-side logrotate are lost (~1 min window weekly — acceptable; document, don't engineer around).
- **Never `--append`-style rsync of the raw file** into the feed path: rename = inode flip = tailer rotation = re-read of FULL content each pull ⇒ duplicates. The offset-delta append exists precisely to avoid this.
- **Host label drift:** every caddy path must carry the SAME label today's rows have (hostname default) or the hostname filter splits — emit HOST_NAME for ALL paths from day one.
- **Format pinning:** `geometrikks-json` pinned per-file beats `auto` sniffing for determinism (a first-line binary probe could sniff wrong).
- **`client_ip` behind proxies:** the PBX sees visitors directly (no CDN) — `$remote_addr` is the real client. Re-check if a CDN/tunnel ever lands in front (README proxy-setup).

## 5. Staged go-path

- **Stage 0 (decision):** owner picks shipped-files shape (recommended) vs agent shape vs drop.
- **Stage 1 (SystemNix):** module `extraLogFiles` + FORMATS/HOST_NAME envs + pull unit/timer + `MAP_HOME_LOCATIONS` + runbook; deploy; verify ingestion rows labeled `pbx` appear in the UI live tail within minutes.
- **Stage 2 (pbx-artmann):** `geometrikks_json` log_format + second access_log (host repo only); switch the pull to the JSON file (`format = "geometrikks-json"`); verify host filter + timing columns populate.
- **Stage 3 (optional):** backfill history via `import-logs` over the pulled rotated archives (README: archived-only rule).

Effort: ~1–2 h across both repos + one deploy each.

## Verification status

| Claim | Status | Source |
| --- | --- | --- |
| Multi-source shipped-files + HOST_NAME/FORMATS positional lists; agent mode + trust warning | ✅ Verified | README v0.19.0 (fetched raw 2026-10-16) + `config/settings.py` in pinned store package |
| nginx JSON log_format field list + combined-format parse limits | ✅ Verified | README "Nginx setup"; parser `formats/nginx.py` + `constants.py` (pinned package) |
| Tailer rotation semantics (inode / ≥99% shrink / missing-file poll) | ✅ Verified | `services/logparser/logparser.py:434-473,689-693` (pinned package) |
| `MAP_HOME_LOCATIONS` per-source pin incl. shipped-logs case | ✅ Verified | README "Site homes" |
| PBX nginx default access.log + scanner-log override; vhost extraConfig reachable from host repo | ✅ Verified | pinned telephony source web.nix:345,388; pbx hosts/pbx gates.nix precedent (mkForce/extraConfig overrides in-tree) |
| ssh pull path + zero-PBX-credentials doctrine | ✅ Verified | pbx backups/evo-x2/README.md |
| Helsinki coords for hel1 | ⚠️ Approximate | hel1 = Helsinki (well-known); [60.17, 24.94] city-center coords — beacon precision is cosmetic; owner can refine |
| NetBird peer reachability pbx↔evo-x2 for ssh (vs public IP) | ❌ Unverified lead | both are peers, but the backup pull's actual target (netbird IP vs public DNS) must be read from the installed kit at implementation time |
