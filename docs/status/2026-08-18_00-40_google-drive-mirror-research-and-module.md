# Google Drive Mirror Research + google-sync Module: Status Report

**Session:** 2026-08-17 evening → 2026-08-18 00:40 CEST
**Task evolution:** "ideas for backing up Google Photos/Drive to the HDD pool" → research deep-dive → user pivot ("Drive is easier") → user pivot ("FULL streaming mirror like Drive Desktop Mirror mode") → user pivot ("Drive-only native?") → **build `services.google-sync` (rclone Drive → pool mirror)** → user challenge ("most Nix-native way? proper paths?!") → refactor to central sops.nix.

**ADDENDUM 2026-08-18 00:50 (follow-up session):** the "deployed disabled" claim below was WRONG — the 00:33 deploy shipped the force-enable verification build ENABLED, and the unit crash-looped live with `status=226/NAMESPACE` (see §d.7). Fixed: enable reverted, new `google-sync-dirs` mount-gated dir oneshot + `google-sync-config-check` placeholder ExecStartPre (live-tested), AGENTS.md gotcha added. **Deploy of the fix still pending — the loop is live until the next `nix run .#deploy`.**

---

## a) FULLY DONE

### 1. Research (verified, not assumed)

| Finding | Source | Status |
|---|---|---|
| Google Photos Library API closed to third-party originals since **2025-03-31** (apps can only download what they uploaded) | rclone.org/googlephotos docs (updated 2026-07-31), nixpkgs gphotos-sync removal | VERIFIED |
| rclone gphotos backend is **Tier 5 (deprecated)**; shared client_id retires **during 2026** | rclone docs | VERIFIED |
| gphotos-sync **archived upstream**, removed from nixpkgs ("API changes ceased its functions") | `nix eval nixpkgs#gphotos-sync` error message | VERIFIED |
| gphotosdl (rclone author's headless-browser full-res downloader): alive (pushed 2026-05-30, 152 stars), but fragile (1 image at a time, hangs on error, periodic re-login, issue #16 "Deleted my backup") | GitHub API | VERIFIED |
| Takeout scheduled exports: **every 2 months × 1 year** (only recurring option), 1/2/4/10/**50 GB** splits, **auto-delivers to Drive** (`dest=drive`), albums + JSON sidecars included; partner-shared/other-people's photos **excluded** | Google support + takeoutreader + metadatafixer via research agent | VERIFIED |
| immich-go 0.32.0 in nixpkgs; `from-google-photos` eats takeout zips, preserves albums/descriptions/GPS/stacking/dedup, 100k+ photos proven | upstream README | VERIFIED |
| rclone drive backend: Tier 1, md5-in-listings (`--checksum` free), `--fast-list` (39k files: 22min → 4min), Docs export default `docx,xlsx,pptx,svg` (or `pdf`), `use_trash` default true, own client_id now mandatory | rclone drive docs (fetched to /tmp) | VERIFIED |
| `--drive-skip-checksum-gphotos` exists for Drive-stored photos with mutating md5s | rclone drive docs | VERIFIED |
| No native Google Drive Desktop for Linux; GNOME Online Accounts/kio-gdrive are browse-only GVfs; no new active 2026 Photos pull-tools (GitHub search) | search + docs | VERIFIED |
| Insync 3.9.8 in nixpkgs but commercial $30 and unnecessary | nixpkgs eval | VERIFIED |

**Ecosystem verdict:** Drive = rclone. Photos = Takeout (via Drive) + optional immich-go. Everything else is dead.

### 2. `services.google-sync` module (BUILT, not yet enabled)

- `modules/nixos/services/google-sync.nix` — rclone one-way sync `gdrive:` → `/mnt/pool/backups/google-drive`, **5-min timer** (Drive Desktop Mirror semantics), remote deletions parked in grace dir `/mnt/pool/backups/google-drive-deleted/` (30d retention via `--backup-dir` + timestamped `--suffix`) — better than Drive Desktop's instant deletion
- Correctly registered as `flake.nixosModules.google-sync` (auto-discovery contract — a bare module file was my first mistake, caught by eval)
- `harden {MemoryMax=1G; ReadWritePaths=…}` + `serviceOneshotDefaults` + `ioTier.background` + `onFailure` routing + `startLimitBurst/IntervalSec` (correct top-level placement) + `RequiresMountsFor=/mnt/pool` + `mkDnsGate` (www.googleapis.com) + mkdir ExecStartPre
- rclone flags: `--fast-list --checksum --drive-skip-checksum-gphotos --drive-export-formats pdf --backup-dir --suffix --transfers 8 --checkers 32 --retries 3`
- Config via `Environment = RCLONE_CONFIG_PATH=<sops path>` (file not EnvironmentFile — token JSON quoting footgun)
- Timer: `Persistent = true`, `RandomizedDelaySec = 90s`
- Freshness: touches `/var/lib/google-sync/last_success`; registered in `backup-coordination` (maxAge 25h) → existing `backup_all_healthy` Gatus alert covers it
- Options: `interval`, `exportFormats` (default pdf), `retentionDays` (default 30)

### 3. Secret plumbing (after user challenge — was genuinely wrong before)

- `platforms/nixos/secrets/google-sync.yaml` created + sops-encrypted (public key only, no sudo) + `git add -f` (tracked, verified `git ls-files`)
- Declaration **moved into central `sops.nix`** using the repo's own `mkSecrets "google-sync.yaml" { owner=root; restartUnits=… } [ "google_sync_rclone_config" ]` pattern with `svcEnabled "google-sync"` gating — no more cross-boundary `../../../platforms/...` path in the service module

### 4. Verification actually performed

- Module eval standalone + as part of evo-x2 (enable default false confirmed)
- **Force-enabled (`default = true` hack) → full `system.build.toplevel` built successfully** — validates script derivation (writeShellApplication shellcheck), sops manifest, all merges end-to-end; hack reverted after
- `nix flake check --no-build` — all checks passed
- statix + deadnix clean on both touched modules
- `nix fmt` applied

### 5. Documentation

- `AGENTS.md` — new "Google Sync (Drive → HDD pool mirror)" section (semantics, sops-file-not-env rationale, OAuth "In production" 7-day-refresh-token trap, load-bearing flags, freshness wiring, Photos-impossible-via-API verdict)
- `TODO_LIST.md` — P0 go-live entry with the 4 user steps (OAuth client → rclone authorize → sops fill → enable+deploy+verify)

---

## b) PARTIALLY DONE

- **Go-live:** module + secret scaffolding done; the OAuth token is a PLACEHOLDER. Ships disabled; the new `google-sync-config-check` ExecStartPre turns an accidental enable into a single actionable journal message instead of an inscrutable auth crash-loop.
- **Post-deploy checks:** `pre-deploy-check.sh` / `post-deploy-check.sh` NOT extended for google-sync (pool backup tiers like forgejo aren't smoke-checked there either — consistent with repo practice, but the first-run seed deserves a size sanity check).
- **Gatus:** covered only via the shared `backup_all_healthy` check; no dedicated endpoint check (defensible — the mirror has no HTTP surface; the sentinel IS the signal).

## c) NOT STARTED (explicitly deferred, with user agreement)

- Photos leg: scheduled Takeout ("Add to Drive") — would ride the mirror for free; not enabled by user yet
- immich-go ingestion of takeouts into Immich — documented as optional future
- Shared-with-me Drive items (`--drive-shared-with-me`) — My Drive only, decision not surfaced to user yet
- Actual deployment (`nix run .#deploy`)

## d) TOTALLY FUCKED UP (caught and fixed, but real failures)

1. **Bare module file, no `flake.nixosModules` wrapper** — first version broke the auto-discovery contract; eval error "option services.backup-coordination does not exist" exposed it (module never imported).
2. **Missing `sopsFile`** — secret declaration defaulted to global `secrets.yaml`; sops-install-secrets failed the BUILD (not eval!) with "key cannot be found". `nix flake check --no-build` does NOT catch this class — only the full toplevel build did.
3. **Secret in the wrong chain** — after moving to sops.nix I appended to the `templates =` chain (pattern-matched on the dns-blocker block which is a TEMPLATE, not a secret). Only an `attrNames` dump exposed it; `? google_sync_rclone_config` returned false.
4. **statix false positive obedience** — removed parens from `(serviceOneshotDefaults { })` because statix flagged "useless parentheses"; it's a FUNCTION call, the eval immediately broke ("definition is not of type attribute set — function"). Restored. Same lint debt exists in forgejo.nix:269.
5. **Stray `EnvironmentFile = []`** and duplicate `network-online.target` after/wants (mkDnsGate already includes them) — cleaned in the same pass.
6. **Wrong verification commands** twice: `systemd.build.toplevel` (correct: `system.build.toplevel`), and getFlake needs `--impure` + toString path.
7. **The force-enable verification build got DEPLOYED (00:33, follow-up session discovery)** — the revert existed only staged, never redeployed, so the live generation had `services.google-sync.enable = true` and failed every 5-min tick with `status=226/NAMESPACE` + OnFailure alerts. Root cause is a genuine module bug, NOT the placeholder token: `ReadWritePaths = [destination graceDir]` pointed at paths that did not exist, and systemd constructs the mount namespace BEFORE any ExecStartPre — the in-unit mkdir was structurally dead code. Fix: mount-gated `google-sync-dirs` oneshot (atticd-storage-dir pattern) + placeholder `configCheck` ExecStartPre; enable reverted. Lesson recorded in AGENTS.md (Systemd gotchas): ReadWritePaths entries must exist before unit start; an ExecStartPre mkdir can never create them.

## e) WHAT WE SHOULD IMPROVE

1. **Eval-time guard for "secret declared but module disabled" / placeholder tokens** — an assertion that `google_sync_rclone_config` doesn't contain `REPLACE_WITH` when `services.google-sync.enable` would have failed the deploy instead of relying on docs. Generalizable: sops.nix knows all secrets; a placeholder-scan assertion would protect every future secret.
2. **A `nix build` smoke gate for sops manifest validity** — the sopsFile class of error only surfaces at build. A cheap `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel.drv` in pre-commit for secret-touching commits would catch it (maybe too slow — at least document it).
3. **statix `W:8 useless-parens` on function-application-with-attrset-arg is a false positive** the repo hits repeatedly (forgejo, now here) — pre-commit only lints staged files so it bites exactly when someone stages a fixed file. Consider a statix.toml ignore or `# statix:ignore` comment convention.
4. **`mkDnsGate` hardcodes `dnsblockd.service`** in after/wants with no opt-out — services on hosts without dnsblockd would gain a dead dependency. Fine for evo-x2-only; worth an option later.
5. **backup-coordination can't monitor a directory MIRROR** (top-level files only). The sentinel-file workaround is fine, but a `directoryMode` (newest file anywhere in tree) would serve immich media too.
6. **Bare `Environment =` in serviceConfig vs `serviceConfig.Environment`** — works, but the repo convention is the latter in some modules; cosmetic.

## f) NEXT UP TO 50 (this session's scope only)

**Go-live (blocking on user):**
1. Create Google Cloud OAuth client (Drive API enabled, Desktop type)
2. Set publishing status **"In production"** (else refresh token dies in 7d)
3. Run `rclone authorize "drive" "<id> <secret>"` on a desktop browser machine
4. Fill token JSON + creds into sops (`SOPS_AGE_KEY` from sudo ssh host key)
5. Flip `services.google-sync.enable = true` in configuration.nix
6. `nix run .#deploy`
7. Watch first seed: `journalctl -u google-sync -f` (large libraries = hours)
8. Verify `/mnt/pool/backups/google-drive` populates + `last_success` appears
9. Verify `backup_healthy{google-sync}=1` in node-exporter metrics
10. Test deletion grace: delete a Drive file, confirm it lands in google-drive-deleted/

**Hardening follow-ups (me):**
11. ~~Placeholder-token eval-time assertion (e)1~~ DONE (follow-up session, runtime form): `google-sync-config-check` ExecStartPre greps REPLACE_WITH + `rclone listremotes` parse check — eval-time is impossible on sops-encrypted content; live-tested against synthetic configs
12. Extend pre-deploy-check with a google-sync section (mount present, secret non-placeholder when enabled) — PARTIALLY covered: RequiresMountsFor gates the mount, configCheck gates the placeholder; a pre-deploy-check section would still be nice-to-have
13. Consider `--drive-shared-with-me` decision + document
14. Consider `--drive-team-drive` if Workspace is ever in scope
15. Suffix pattern check: confirm `.del_<stamp>` files expire correctly after 30d (find -mtime)
16. Add rclone `--log-file` rotation consideration (journal-only now; 5-min INFO lines are fine)
17. Document restore path (pool → Drive is NOT synced back; restore = manual rclone copy)
18. Immich takeout ingestion runbook (when user enables Takeout)
19. Takeout scheduling checklist as a TODO_LIST sub-item
20. Consider `ioTier.heavyDB` vs `background` for the seed phase (first run is IO-heavy)
21. Metrics: rclone `--stats` to textfile collector for sync duration/transfer counts (optional)

**Research debt from this session:**
22. Verify Takeout 50GB split zips actually arrive in Drive root vs a folder (affects grace/sync)
23. immich-go dedup behavior when BOTH Immich app uploads AND takeout import overlap (phone photos double-present)
24. Decide Photos strategy explicitly: Takeout-only vs Immich-app-as-primary + Google as offsite
25. gphotosdl: revisit only if user wants full-res Photos streaming and accepts fragility

**Housekeeping:**
26. ~~Commit the working tree~~ DONE (auto-commit daemon: d51a6f06/b4adcea2; fix staged for next daemon run)
27. ~~CHANGELOG entry for google-sync module~~ DONE (follow-up session: Added + Fixed entries)
28. Consider a VM test for the timer/sentinel behavior (repo has the harness)
29. ~~Remove /tmp/rclone-drive.md scratch~~ DONE (follow-up session)
30. gitignore check: `platforms/nixos/secrets` pattern still requires `-f` adds — document in CONTRIBUTING?

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Do you use shared-with-me Drive items or Google Workspace team drives?** The mirror covers My Drive only; shared-with-me needs an extra flag + separate destination design (it's a flat namespace, not a tree).
2. **Roughly how big is your Drive (GB / file count)?** Determines whether the 4h first-seed timeout is enough and whether we should temporarily raise `--transfers` for the initial pull.
3. **For Photos: do you want me to prep the Takeout-to-Immich pipeline now** (scheduled Takeout + immich-go runbook), or leave Photos entirely alone until the Drive mirror has proven stable for a few weeks?

---
*Artifacts this session: `modules/nixos/services/google-sync.nix` (new), `modules/nixos/services/sops.nix` (+google_sync secret), `platforms/nixos/secrets/google-sync.yaml` (new, encrypted placeholder), `AGENTS.md` (+Google Sync section), `TODO_LIST.md` (+P0 go-live entry). All eval/build/lint green. CORRECTION (00:50): the session's final deploy shipped the module ENABLED by accident — crash-looping until the follow-up fix deploys; ships disabled thereafter, pending OAuth token.*
