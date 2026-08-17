# Status Report: Three-Drive Repurposing — Pool Backups Completion

**Task:** Continue and complete the 3-drive repurposing execution (resumed session), then extend per live user request: "all backups Forgejo and co should be also on the HDDs".
**Date:** 2026-08-17 00:59 (session ran 22:00–01:00)
**Working copy:** clean (auto-commit daemon captured everything in `26beaf0c`; two foreign commits `8ffb2762`, `8fc2b80c` landed on top from concurrent sessions)

---

## a) FULLY DONE

1. **Interruption resolved autonomously.** All 3 open questions from the prior session were answered by investigation or safe defaults: (1) foreign edits were already auto-committed (`e350b32e`) and documented — treated as intentional, built on top; (2) deployed generation was verified to predate my config edits (live immich unit still pointed at `/var/lib/immich`), so a stopgap immich restart was never needed — went straight to the pool deploy; (3) paperless admin password generated randomly into sops (handed over below).
2. **Forensic-move job verified complete.** All 4 `/data/backup-2026-08-11-private-cloud*` dirs relocated to `/mnt/pool/archive/private-cloud-forensics` with count+size verification, sources removed. `/data` dropped 85% → 82%.
3. **Immich migration integrity re-confirmed at deploy time.** Both sides identical: 11,929 regular files / 20,705 entries / 17,241,720,562 bytes. Immich now serves from `/mnt/pool/services/immich` (fstab-mounted via by-id, `RequiresMountsFor` on both units). Old `/var/lib/immich` removed after verification (pre-checks: service active + API ping before rm).
4. **Paperless-ngx live end-to-end.** Module (`modules/nixos/services/paperless.nix`): port 2892, `dataDir=/mnt/pool/services/paperless`, `domain` (sets `PAPERLESS_URL`), sops `paperless_admin_password` via upstream `LoadCredential` → superuser auto-created, OCR langs `deu+eng`, exporter on, `ioTier.background` + `MemoryMax` ceilings + `onFailure` on all 5 units. **Pipeline proven live:** dropped a test doc into `consume/` → consumer picked it up in 28s → OCR → archived as document 1 (originals + thumbnail on pool) → exporter wrote `manifest.json`/`metadata.json`. Exposed at `paperless.home.lan` (protectedVHost + dnsblockd subdomain + homepage tile + Gatus check).
5. **Safety-net sends live.** `btrbk-root`/`btrbk-data` converted `snapshotOnly=false` with targets `/mnt/pool/backups/{root,data}` (`target_preserve 30d 12w`), `TimeoutStartSec=6h` (seed-sized), `RequiresMountsFor` gates, `onFailure` routing. New `btrbk-pool` instance (23:45) snapshots the 5 `services/*` subvols on-pool. Both NVMe seeds running; 424G received at report time (oldest-retained snapshots first). `/mnt/pool` added to weekly `autoScrub`. New `btrfs-verify-pool-backups` daily guard (mount + `btrfs device stats` + received-backup freshness by name-parsed date).
6. **All application backups now land on the HDDs (the live request).**
   - **Immich** db-backup: already pool-side via mediaLocation.
   - **Paperless** exporter: pool-side via dataDir.
   - **Twenty + Manifest** pg_dumps: redirected `/var/lib/*/backup` → `/mnt/pool/backups/{twenty,manifest}` via new `backup.dir` support in `lib/docker.nix` `mkDockerService` (tmpfiles + `RequiresMountsFor` mount-gating so a detached DAS fails the unit instead of contaminating `/mnt/pool` on the root fs). Existing 30-day dump history migrated off NVMe (`rsync --remove-source-files`).
   - **Forgejo** — previously had **zero** application-level backup — new `forgejo-backup` oneshot+timer (03:30): `forgejo dump` zip (repos+DB+config+LFS) → `/mnt/pool/backups/forgejo`, 7-day retention, forgejo-user hardening, `ioTier.background`. First manual run: **3.7G zip on the pool**.
   - **Pocket-ID** (SSO backbone) — new `pocket-id-backup` oneshot+timer (04:00): WAL-safe `sqlite3 ".backup"` → `/mnt/pool/backups/pocket-id`, 14-day retention. First manual run green (524K).
   - `backup-coordination` entries updated for all of the above; Gatus alerts unchanged (`backup_all_healthy`).
7. **smartd** now monitors both MG08ACA16TE members (`-d sat`, by-id).
8. Four deploys executed; post-deploy smoke 44–45 PASS / 0 FAIL each time.

## b) PARTIALLY DONE

1. **Seed sends in flight.** `btrbk-root` + `btrbk-data` mid-send (`activating`), catching up from the oldest retained snapshots. Root-side 712G+ total expected on pool; verify tonight ~00:45+.
2. **monitor365 backup-entry gating written but NOT deployed** — the deploy was blocked by the 95% disk gate (see d.5). Until it lands, `backup_healthy{monitor365}=0` keeps `backup_all_healthy` at 0 → recurring Discord alerts.
3. **Paperless admin password handover** — generated and in use, but user has not received it yet (below).

## c) NOT STARTED

1. Plan-doc decision-record amendment (`2026-08-16_20-22_three-drive-repurposing.md` still describes borg + sdf offsite).
2. AGENTS.md storage section (pool layout, DAS topology, btrbk targets, "do not touch sdf/SanDisks").
3. TODO_LIST/CHANGELOG entries for the repurposing + backup work.
4. Boot-resilience test (DAS powered off → boot must stay clean).
5. Pool-usage Gatus alert (fill-rate early warning).
6. hd-idle spin-down for the HDDs (undecided).

## d) TOTALLY FUCKED UP

1. **paperless.nix was deployed UNTRACKED.** Wrote the module but didn't `git add` it before deploying — nix flakes only see tracked files, so the first deploy ran paperless with upstream defaults (port 28981, `/var/lib/paperless`, no pool, no hardening). Detected via `granian listening on 28981`; fixed by `git add` + redeploy. One full wasted deploy cycle; the misconfigured paperless was live ~5 minutes and wrote its initial DB to the wrong path (harmlessly — real data landed on pool after redeploy; stray `/var/lib/paperless` remains, see f).
2. **forgejo-backup NAMESPACE failure, twice.** (i) `ReadWritePaths=/var/tmp/forgejo-dump` on a nonexistent dir → status 226; added a tmpfiles rule → (ii) still 226 because `harden {}` sets `PrivateTmp=true` — the unit's `/var/tmp` is a private namespace that can't see host paths. Final fix: `mktemp -d` inside the private `/tmp` (writable, auto-reaped). Cost: one extra failed run + one extra deploy.
3. **snapshots.nix syntax breakage.** A 6-edit multiedit partially applied (3/6); my follow-up edit assumed full application and created a nested duplicate `services = {` block + missing brace. Caught by `nix flake check`, fixed. Should have diffed the file immediately after any partial multiedit.
4. **Seed-vs-verify race (expected, but not pre-mitigated).** `btrfs-verify-pool-backups` fired at 00:46 mid-seed: only the Aug-12 base snapshot was received → "5 days old" > 3d threshold → FAIL → Discord alert. Known false-positive during first catch-up; will self-heal once tonight's fresh snapshots are received. Should have either started seeds earlier or temporarily disabled the verify timer.
5. **Disk-gate deploy block at 95%.** I left the old immich copy in place after the verified 22:28 deploy (the plan's own step said remove it then); by the time the monitor365-gating deploy ran at 00:08 the root hit 95% and the gate blocked it. Removal at 00:08 freed only ~5G visible — CoW: the last 14 days of root snapshots still reference the extents (and the running seed is sending them). Net: one config change stranded undeployed.
6. **Smartd live-verification incomplete.** `/etc/smartd.conf` grep failed ("path differs" — NixOS renders smartd config elsewhere); I never confirmed the two TOSHIBA devices are actually being polled. Declarative intent is right; runtime unproven.

## e) WHAT WE SHOULD IMPROVE

1. **`git add` new files at write time, before any deploy.** The untracked-module failure was silent — the deploy "succeeded". Consider a pre-deploy guard: warn when `git status --porcelain` shows untracked files under `modules/` or `platforms/` (they will be silently invisible to the flake).
2. **PrivateTmp-awareness when choosing temp paths.** House rule candidate: "hardened oneshots get their scratch space from `mktemp -d` (private /tmp), never from host paths under ReadWritePaths."
3. **Verify file syntax (`nix-instantiate --parse`) + `git diff` after every partial multiedit**, not just after flake check.
4. **Remove declared-redundant data immediately after the verification that justifies it** — the 95% wall was self-inflicted by deferring a planned step.
5. **Kick the `backup-health-metrics` collector manually after creating/emitting backup artifacts** — the .prom lags the collector timer; verification loops otherwise show stale zeros (burned one round-trip on paperless before remembering).
6. **Snapshot-vs-free-space mental model:** `rm` on CoW-referenced data frees nothing until snapshots expire; plan space-heavy operations around btrbk retention (14d root).
7. **Pool-side dumps are not themselves snapshotted** — `btrbk-pool` covers `services/*` but not `backups/`. Acceptable (they ARE the backup tier), but a future `backups/` subvol could get coarse monthly snapshots for ransomware/typo protection.

## f) NEXT THINGS (ordered)

1. Free root below 95% and deploy the stranded monitor365-gating change (see g.2 for the /home/hermes question; `/nix/store` GC is the other lever).
2. Monitor `btrbk-root`/`btrbk-data` to completion; confirm nightly incrementals are minutes-scale.
3. Confirm `btrfs-verify-pool-backups` turns green after the seed finishes (next run ~00:45 tomorrow).
4. Remove the stray `/var/lib/paperless` initial-DB remnants from the misconfigured first deploy (verify pool instance healthy first).
5. Verify smartd is actually polling both TOSHIBA drives at runtime (`smartctl -a` data timestamps / correct rendered config path).
6. Deliver paperless password (below) → user logs in, changes password in UI.
7. Amend the plan doc with the decision record (btrfs-send not borg; sdf/SanDisks frozen; Google offsite; backup-tier layout).
8. Write the AGENTS.md storage section (pool layout, DAS topology, backup tiers, btrbk targets, sdf/SanDisk freeze).
9. TODO_LIST: own-tools (monitor365/discordsync/browser-history) NVMe→pool migrations into the pre-created subvols; stray `/var/lib/paperless` cleanup; /rust-cache partition deletion batch.
10. CHANGELOG entry for the repurposing + backup tier.
11. Boot-resilience test: detach DAS → `nixos-rebuild build-vm` or real boot → expect clean boot with failed-but-contained btrbk units, no `/mnt/pool` contamination on root.
12. Pool-usage Gatus alert (>80% warn) — cheap while near-empty.
13. Watch tomorrow-morning journal for the first full nightly cycle (btrbk ×3 + verify ×2 + dumps ×5 + exporter).
14. Optional: hd-idle spin-down for the HDDs; DAS fan/thermal check after sustained seed writes (38 °C idle earlier).
15. Optional: coarse snapshots of `/mnt/pool/backups` (see e.7).
16. Optional: revisit sdf (WOOACME) after the pool proves stable — original vault idea may be moot now.

## g) QUESTIONS (cannot resolve alone)

1. **`/home/hermes` is 58G on the 95%-full root** — biggest single reclaim after `/nix` GC. Is that Hermes' model/state data, and may it move to `/mnt/pool` (or archive) the same way immich moved?
2. **Disk-gate policy at 95%:** do you want me to run `nix.gc`-style store cleanup tonight to unblock the stranded deploy, or wait for the daily 00:00 GC + snapshot expiry to free space naturally (monitor365 stale-alerts keep firing until then)?
3. **Paperless admin password:** generated randomly, stored encrypted in `platforms/nixos/secrets/paperless.yaml` (sops). Plaintext copy sits in `/tmp/paperless-pw.txt` until the next reboot; recoverable anytime via the sops private-key workflow. Log in as `admin` at `paperless.home.lan` and change it in the UI — or should I instead set a password you choose?

---

**Standing state at write time:** immich + paperless + all 5 backup jobs healthy on the pool; seeds mid-flight (424G received); root 95%/38G free; tree clean at `26beaf0c`; one config change (monitor365 gating) written but undeployed behind the disk gate.
