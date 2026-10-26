# OpenCloud Pilot Execution — Status (interrupted mid-Phase-D verification)

_2026-10-26 07:09 CET · session: opencloud-executor-1 (plan tombstone `975ac1d7f`, 2026-10-25 21:54) · scope: executing `docs/planning/2026-10-25_13-30_SUPERB-opencloud-pilot-adoption.md` after the owner's full-plan GO directive_

## Verdict

**Phases A–C fully landed and eval-verified; Phase D ~90% (one interrupted verification); Phases E–H not started.** The pilot service module is COMMITTED (`444ba1272`, + runbook in `43360d2e6`) and the targeted evo-x2 toplevel eval is GREEN — but the FULL `nix flake check --no-build` re-run (after the doc-counts re-stamp) was interrupted when the session died overnight (~22:30 → 07:09) and has NOT been completed. **No deploy has happened; the live host is untouched.** The plan tombstone is still EXECUTING (not flipped to done).

## a) FULLY DONE (verified this session)

1. **Plan-execution tombstone** set + committed (`975ac1d7f`) — added the missing `**Created:**` anchor header the marker script requires; instance `opencloud-executor-1`.
2. **A1 owner gate**: recorded the GO directive (complement + LAN/VPN-only per plan scope) in the marker note.
3. **A2 collision sweep**: `rg -l -i opencloud` over TODO_LIST/docs/todo/CHANGELOG → only our own `[decision]` row in `docs/todo/services.md`. Zero parallel work.
4. **A3 pin re-verify**: `opencloud-production` 7.2.4 + `opencloud-desktop` 4.0.0 confirmed at nixpkgs `fe13242281a6` (live `nix eval` pair).
5. **Phase B IdP spike → DP1 = Pocket ID GO**, evidence at source level:
   - provisioner supports `isPublic` + `pkceEnabled` + pinned client IDs (`id = client.clientId` on create) — read from `modules/nixos/services/pocket-id.nix` provision script;
   - Pocket ID implements the OIDC **loopback-port exemption** for `http://127.0.0.1[:port]` (upstream `callback_url_util.go`);
   - exact callback URIs from the official opencloud-compose keycloak configs: web `…/oidc-callback.html` + `…/oidc-silent-redirect.html`, desktop `http://127.0.0.1` + `http://localhost`, android `oc://android.opencloud.eu`;
   - `preferred_username → username` user mapping is the proxy DEFAULT; autoprovision flag is the only flip needed;
   - desktop-with-oidc-driver limitation (opencloud-eu/desktop#217) CLOSED 2026-09-02 → **no two-deploy bootstrap dance needed**: steady-state `PROXY_ROLE_ASSIGNMENT_DRIVER=oidc` + the UPSTREAM DEFAULT role mapping (claim values `opencloudAdmin`/`opencloudUser`) + Pocket ID userGroups with exactly those names. Fail-closed login (unmapped users rejected) is the intended LAN-only posture; one-deploy fallback flip documented.
   - OpenCloud external-IDP contract verified from the canonical docs repo (`docs/admin/.../external-idp.md`): public PKCE clients, predefined client IDs, webfinger discovery, `OC_EXCLUDE_RUN_SERVICES=idp`, `PROXY_OIDC_ACCESS_TOKEN_VERIFY_METHOD=jwt`, `PROXY_OIDC_REWRITE_WELLKNOWN=true`, `IDP_DOMAIN` CSP wiring.
   - **init-flow finding** (from the upstream nixpkgs Selenium test): `opencloud init` MUST run once (it persists embedded-IDM secrets into `/etc/opencloud/opencloud.yaml`; the service cannot write there) → `services.opencloud.settings` deliberately EMPTY; all overrides ride `environment` (env > YAML deterministic). `ADMIN_PASSWORD` feeds init → single sops secret.
6. **Phase C module** `modules/nixos/services/opencloud.nix` (376 lines, committed `444ba1272`): production line, loopback 9200, stateDir pool subvol, external-OIDC env block, webfinger scopes WITH `groups` on all three clients, sops template `opencloud-env` → `environmentFile`, upstream tmpfiles neutralized (`mkForce {}` — shadow-dir class) + `createHome = false`, mount-gated `opencloud-storage-dir` oneshot (tq pattern: subvol create + idm subdir, CAP_SYS_ADMIN/CHOWN/FOWNER/DAC_OVERRIDE), `opencloud-init-config` convergence (TimeoutStartSec 5min + ioTier — both audit catches), `opencloud.service` overlay (harden MemoryMax=1G, serviceDefaults, ioTier.background, RequiresMountsFor, onFailure, start limits, TimeoutStartSec 5min), 3 Pocket ID public PKCE clients (web via registry `oidc` field; desktop+android via `extraOidcClients`), 2 userGroups, integration registry entry (subdomain `cloud`, plain vHost, 2 gatus checks incl. webfinger-discovery functional check, URL-icon tile, monitored).
7. **Wiring** (same commit): port 9200 in `lib/ports.nix`; `cloud` in `platforms/common/dns-local.nix`; btrbk-pool `subvolume."services/opencloud"`; pool-recovery `restartUnits += opencloud.service`; deploy.sh provisioner loop += `opencloud-storage-dir`; evo-x2 `opencloud.enable = true`.
8. **sops secret** `platforms/nixos/secrets/opencloud.yaml` created (`openssl rand` → `sops -e -i`; value never on a command line, never in the tree plaintext).
9. **Eval battery (targeted)**: `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` GREEN after fixing the two audit catches (io-tier + oneshot-timeout). All host-level audits pass: port-registry, systemd-shape, mount-gating, deploy-restart, pool-recovery converge-coverage, memory-watermark, tile-coverage, dns-local, gatus-pattern-lint.
10. **D6 inert probe** GREEN: throwaway `extendModules` with `enable = mkForce false` → `[]` (zero opencloud units).
11. **Scoped formatting** `nix fmt --no-update-lock-file -- <6 files>` — 1 file restyled, no lock churn.
12. **doc-counts re-stamp**: README (132→133 modules, 232→234 gatus) + FEATURES (133, 138 files); standalone `nix build .#checks.x86_64-linux.doc-counts` GREEN.
13. **Runbook** `docs/services/opencloud.md` (committed via daemon batch `43360d2e6`): auth table (all 3 clients + callbacks + scopes), role-mapping design + fallback flip, config-flow rationale, 7-item trap catalogue (xattr rsync -X, no-downgrade lines, role-claim fail-closed, /etc/opencloud secrets on root fs, watch-fs, tmpfiles/subvol ownership, first-deploy ordering), verify recipes, rollback ladder, owner-hands items.
14. **Milestone commit hygiene**: daemon absorbed my 8 staged files mid-commit (stale `index.lock` fight); verified `git show --stat` (exactly my files) then amended into `444ba1272` per daemon-race policy. Stale lock removed via `trash` (not rm).

## b) PARTIALLY DONE

1. **D5 full `nix flake check --no-build`**: FIRST full run failed on exactly ONE check — doc-counts (module count 132→133). After the re-stamp, doc-counts green standalone, but the **re-run of the full sweep was interrupted** (session died ~22:30; background shell gone). Unverified remainder of the sweep: gatus-config-parse (`gatus validate` over the rendered config — my webfinger check uses a `?resource=` query in `path`, unvalidated), VM-test evals, selftests, darwin leg. **This is the mandatory pre-deploy gate — must complete before Phase E.**
2. **README**: two late edits (line-18 monitoring count 232→234 + OpenCloud service-table row) are UNCOMMITTED in the working tree (the daemon took the line-82 re-stamp earlier).
3. **Daemon batch `43360d2e6`** (my FEATURES/README/runbook, docs-only) carries a heuristic message — verified contents, NOT amended-forward (unpushed; low-value amend left open).

## c) NOT STARTED

- **Phase E entirely**: E1 `pre-deploy-check.sh --section-16-only` (tile icon is an http URL — §16 behavior for URL icons unproven), E2 deploy + full-tree wait, E3 anchor discipline (newest-by-NUMBER system-N-link), E4 post-deploy battery, E5 first login (owner passkey — creates the admin user), E6 web smoke (upload/download/share/delete→trash), E7 trash+versions-on-posix verify (Addendum-2 item), E8 rclone WebDAV smoke, E9 journal + memory.events sweep.
- **Phase F entirely**: desktop pkg into evo-x2 home.nix, connect + sync smoke (owner-assisted GUI login), Android owner-hands, mobile webfinger login.
- **Phase G remainder**: G2 backup/xattr live verify (btrbk entry wired but unproven), G3 SigNoz memory-rule decision, G4 VM-test defer-or-do decision (my module has VM-test co-import requirements: catalog.nix + integration.nix + pocket-id.nix + sops-nix), G5 gatus green + tile dot.
- **Phase H entirely**: usage window kickoff (2–4 weeks), mid-window checkpoint, Phase-3 complement/successor/drop review, closeout report, CHANGELOG row, `[decision]` row resolution, docs-health VERIFY, tombstone flip to EXECUTED.

## d) TOTALLY FUCKED UP (honest list)

1. **`rg -rn` typed twice** → host hook blocks (the documented third-strike trap). Wasted two round trips; correct form is `rg -n`.
2. **`umask` (and earlier knowledge of `kill`) are unsupported builtins** in the tool shell — the sops file was briefly created 0644 with PLAINTEXT before encrypt-in-place (fixed by `sops -e -i` immediately; perms normalized to match house convention; the plaintext never left local disk. Mitigation was fast but the correct pattern is `install -m 600 /dev/null file` first).
3. **Left the tree in a partially-verified state overnight**: uncommitted README edits + the mandatory full flake check incomplete when the session was interrupted. Nothing broke (daemon committed the docs) but a fresh session could have mistaken D5 for done — this report exists precisely to prevent that.
4. **Did not pre-read the audit list before writing the module**: two preventable audit failures (io-tier coverage on BOTH oneshots, oneshot unbounded timeout) cost one eval cycle (~2 min). The audit army is documented; a 5-minute checklist pass would have written it right the first time.

## e) WHAT WE SHOULD IMPROVE (session-level lessons)

1. **Pre-eval audit checklist for new units**: ioTier on EVERY unit (incl. oneshots + upstream-module-generated ones), TimeoutStartSec on every oneshot, start-limit placement, RequiresMountsFor for any /mnt path, deploy.sh name for any `-storage-dir`-shaped unit. Write it into the runbook template mentally before the first eval.
2. **Upstream-module units are OUR audit surface**: nixpkgs-generated units (opencloud-init-config) don't get house convergence for free — wrapper modules must overlay timeout/ioTier/etc. proactively.
3. **Long-running verifications should be restarted immediately after any interruption** — background job IDs do not survive session death; the tree's verification state must be re-derived, not assumed.
4. **Daemon docs-batches**: verify-then-amend policy applied to code commits but skipped (deliberately, low value) for docs — either amend docs batches too or note the acceptance explicitly; inconsistency is drift fuel.
5. **Secret-file creation pattern**: `install -m 600 /dev/null` + write + `sops -e -i` beats umask (which doesn't exist in this shell).

## f) NEXT (ordered; ≤50)

**Gate (must be green before anything else):**
1. Commit the pending README edits (line-18 count + service table row) — pathspec.
2. Re-run FULL `nix flake check --no-build` to completion; fix anything it finds (most likely candidates: gatus-config-parse on the webfinger query-path form; doc-counts already green).
3. `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going --no-link` sanity (realizes the FOD layer cheaply pre-deploy; opencloud comes from cache.nixos.org at pin — verify substitution, no 40-min local Go build expected).

**Phase E (deploy + verify):**
4. E1: `bash scripts/pre-deploy-check.sh --section-16-only` (tile URL-icon behavior; then full pre-deploy-check).
5. Quiescence heat-check per the 2026-10-25 deploy-vs-executor doctrine (clean tree + no eval-relevant mtime < 5 min across ≥4 polls) — I am the only executor but the DAEMON still commits.
6. E2: `nix run .#deploy`; wait FULL process tree (`pgrep -f 'nh os|switch-to-configuration'` EMPTY).
7. E3: anchor check — `readlink /run/current-system` == newest-by-NUMBER `system-N-link`.
8. E4: `bash scripts/post-deploy-check.sh` full battery.
9. Live probes: `ss -ltnp | grep 9200`; `systemctl status opencloud opencloud-storage-dir opencloud-init-config`; journal sweep since deploy.
10. E5 (owner): first login at `https://cloud.home.lan` (passkey) — creates the admin user via opencloudAdmin mapping; then verify role=admin via graph API probe or web UI admin menu.
11. E6: web smoke — upload/download/share-link-create/delete→trash (owner or via an app-password/API session if available).
12. E7: trash + versions restore verify on posix driver (the Addendum-2 item — do NOT assume).
13. E8: rclone WebDAV smoke (list/put/get against cloud.home.lan; rclone from nix shell).
14. E9: journal error sweep + `cat /sys/fs/cgroup/.../opencloud.service/memory.events` high-counter sweep (§17 class).
15. Gatus eyeball: OpenCloud + OpenCloud WebFinger Discovery checks green; tile renders on dash.home.lan (URL icon — confirm monogram-fallback doesn't fire).

**Phase F (clients):**
16. F1: `opencloud-desktop` into evo-x2 home-manager packages (nixpkgs at pin) + deploy (can ride the next switch).
17. F2/F3 (owner-assist): desktop connect to cloud.home.lan, folder pair sync, delta re-upload — WATCH for the oidc-driver desktop class; if it fails with "no roles in user claims" → execute the documented one-deploy flip to `driver=default`.
18. F4-F6 (owner): F-Droid Android app + login; camera-upload OFF (Immich owns photos); mobile webfinger login from both client legs.

**Phase G (trust depth):**
19. G2: verify btrbk-pool picked up `services/opencloud` at 23:45 (snapshot exists under /mnt/pool/.snapshots); verify xattr preservation (compsize/getfattr sample on the state tree).
20. G2b: decide/verify whether restic-app-dumps or any dump-style backup needs an opencloud leg (state is snapshotted, not dumped — likely NO; document the reasoning in the runbook).
21. G3: SigNoz memory-rule decision — recommend DEFER with a docs/todo/monitoring.md row (pilot; gatus liveness + memory.events sweep already cover it) unless the owner wants parity now.
22. G4: VM-test defer-or-do — DEFER recommended with a TODO row; document the co-import set (catalog.nix, integration.nix, pocket-id.nix, sops-nix + mock-sops) the future test needs.
23. G5: final gatus + tile live-dot confirmation.

**Phase H (window + closeout):**
24. H1: usage-window kickoff note in the runbook (2–4 weeks, weekly journal-glance cadence — name the dates).
25. H2: schedule the mid-window checkpoint (calendar-bound; queue a TODO row with the date).
26. H3 (owner, after window): Phase-3 review — complement/successor/drop.
27. H5a: closeout status report (self-harvesting §f).
28. H5b: CHANGELOG row; resolve/rewrite the `[decision]` row in docs/todo/services.md (pilot LIVE, Phase-3 pending); docs-health VERIFY pass over every doc touched; prune TODO queue rows; flip plan tombstone to EXECUTED (noting owner-bound remainder).

**Hygiene / opportunistic (this session's debris):**
29. Amend-forward the daemon docs-batch `43360d2e6` OR leave with a note (decide + do one).
30. Add the "pre-eval audit checklist" (§e.1) as a CONTRIBUTING.md paragraph or the module template header so the next service module gets it right first try.
31. Record the `install -m 600` secret-creation pattern in the sops skill (it currently shows a plain redirect).
32. Negative-test consideration: the tile-coverage + gatus-pattern lints now have my shapes in the live tree — `scripts/negative-test-lints.sh` group run to confirm the harnesses still behave (nightly CI covers it; a local run is cheap).
33. Watch item: if the full flake check stays green but §16 flags the URL icon, swap to a self-hosted icon path under papdashboard's served assets (documented alternative).

**Backlog-adjacent (NOT this plan — do not start without owner):** public share-link exposure design, openvfs/pin-bump, Collabora, drive-paperless `opencloud` SOURCE, successor-migration planning — all bound by the plan's NOT-doing list until Phase 3.

## g) QUESTIONS FOR THE OWNER (cannot be figured out from the tree)

1. **Deploy autonomy:** may I run `nix run .#deploy` for the first OpenCloud-carrying switch on my own (build + activate + full post-deploy battery), or do you want to be at the keyboard for the first one? (The plan authorizes it; this is a presence-preference question.)
2. **Role-driver posture ratification:** the plan said "default-role driver, one promoted admin"; my research landed on the BETTER-VERIFIED alternative now shipped — `oidc` driver + Pocket ID groups (`opencloudAdmin`/`opencloudUser`), fail-closed, no bootstrap dance (desktop#217 closed 2026-09-02, desktop 4.0.0 honors webfinger scopes). Keep the shipped posture, or flip to the plan's default-driver posture at first login?
3. **Hold point:** the first login (E5) needs your passkey — should I run everything up to and including E4 (deploy + automated battery) and then HOLD for you, or is a specific time today better so the login→trash/versions→WebDAV chain (E5–E8) runs in one sitting with you present?

## Evidence index

**§f self-harvest disposition:** items 1–28 are plan-execution work owned by THIS session (tombstone `opencloud-executor-1` guards the plan; queueing in-flight execution rows would invite the tq pool into a live executor's scope) — deliberately NOT harvested into TODO_LIST.md; the `[decision]` row in docs/todo/services.md stays the living tracker until closeout (H5b), exactly as the plan §7 states. Items 29–33 (hygiene) are candidates for the docs/todo pipeline/services libraries at closeout if not done by then.

- Commits: `975ac1d7f` (tombstone), `444ba1272` (module + wiring, amended over daemon batch after stat verification), `43360d2e6` (daemon docs batch: runbook + count stamps).
- Green evals: evo-x2 toplevel drvPath `5kh8bh65…-nixos-system-evo-x2-26.11.20261015.fe13242.drv`; D6 inert probe `[]`; doc-counts standalone build.
- Failing-then-fixed: full flake check #1 (doc-counts 132→133 — fixed); targeted eval #1 (io-tier + oneshot-timeout audit throws — fixed in-module).
- Live tree at report time: `43360d2e6` HEAD, `README.md` modified (2 pending hunks), everything else clean; tombstone still EXECUTING.
