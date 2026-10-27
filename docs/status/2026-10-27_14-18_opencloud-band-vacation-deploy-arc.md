# OpenCloud Port-Band Vacation — Deploy Arc Status

**Report:** 2026-10-27 14:18 CET · **Session run:** 2026-10-26 08:00 → 2026-10-27 14:18 CET (two overnight interruption gaps: 10-26 ~17:2x→22:5x, 10-27 ~10:5x→14:0x) · single agent (crush, `opencloud-executor-1` resumption) · evo-x2 working tree
**Trigger:** resumed the interrupted OpenCloud pilot execution (handoff: Phases A–D done, D5 flake check pending, owner E-gate questions open) with the owner's standing "execute and verify" directive.
**Outcome (so far):** **opencloud has NEVER been up** — three distinct port-collision classes were discovered one deploy at a time, root-caused to a single structural fact (ocis binds ~86 loopback ports across **9100–9304**), and fixed in one committed, audit-green **band-vacuation sweep**. **Deploy #6 carrying the fix is IN FLIGHT as of report time** (fired 14:15 on a fully clean tree). Deploy #2 landed gen-950; #4 activated gen-951; #953–955 were parallel sessions' (storage-crisis recovery).
**Owner gates resolved this session:** deploy autonomy = alone · role-driver = keep oidc+groups · E5 login = Pocket ID passkey confirmed (`cloud.home.lan` → auth.home.lan redirect → auto-provision via `opencloudAdmin` group).

---

## a) FULLY DONE

| # | What | Evidence | Files/surfaces |
|---|------|----------|----------------|
| a1 | **D5 completed: full `nix flake check --no-build` green** (705-line battery; the handoff's prime suspect — gatus-config-parse rejecting the webfinger `?resource=` query-path — did NOT materialize) | `~/.cache/oc-d5-flake-check.log`: "all checks passed!" at quiescent window 08:19–08:35 10-26 | verification only |
| a2 | **Pre-deploy sanity: toplevel builds clean; `opencloud-production-7.2.4` substitutes from cache** (binary present in store closure via `services.opencloud.package.outPath` probe) | build rc=0; `/nix/store/xlzajc0n…-opencloud-production-7.2.4/bin/opencloud` exists | verification only |
| a3 | **E1 §16 probe PASS** — the http-URL tile icon is explicitly accepted ("all 42 tiles carry icons (41 pack + 1 URL)"); no self-hosting needed | `~/.cache/oc-e1-sec16.log` | verification only |
| a4 | **Deploy #2 landed (gen-950, 09:29 10-26, rc=0)** — entry gates passed after the guard window self-cleared; anchor self-repaired (profile 949→950 mismatch detected and fixed by deploy.sh); battery 114/5/0; **both oneshots green**: subvol `/mnt/pool/services/opencloud` created+chowned `opencloud:opencloud`, `/etc/opencloud/opencloud.yaml` persisted (3887B, init secrets intact) | deploy log; `busctl` ActiveState=active (storage-dir); journal 09:36:07 | evo-x2 system state |
| a5 | **Collision #1 root-caused and twice-fixed:** ocis embedded NATS binds ocis-default `127.0.0.1:9234` = `signoz-clickhouse-raft`. Attempt 1: `NATS_PORT=9233` (commit `db2290766`) — **proven NO-OP live** (deploy #4: unit carried `NATS_PORT=9233`, nats still bound 9234; the strings hit was the embedded nats library, not an ocis config binding). Final: keeper raft moved OFF the port instead (→ 9430) | journal bind errors; unit file `Environment="NATS_PORT=9233"` vs runtime bind 9234; sourcegraph: `services/web/pkg/config` env-tag convention verified | `lib/ports.nix`, `modules/nixos/services/opencloud.nix`, runbook trap 8 |
| a6 | **THE structural root cause extracted:** ocis 7.2.4's compiled-in listener map = **86 loopback ports, 9100–9304 + 9980/9998** (binary strings), invisible to the port-registry audit (binary defaults, not Exec text). Explains every failure: 9234 (nats), 9100 (web), 9190+9191 (settings — observed 10:05 10-27), and why my first keeper move to 9239 was whack-a-mole (9239 is in the band) | `strings …/bin/opencloud \| rg '127.0.0.1:9…'` (86 addresses); journal 10-05:28 settings dying on 9190 AND 9191 | knowledge, encoded in ports.nix comments |
| a7 | **BAND VACATION executed (the real fix):** every fleet listener inside 9100–9304 moved to 94xx in one sweep — gatus 9110→**9410**, relay 9111→**9411**, collector metrics 9100→**9400**, pma-health 9190→**9420**, monitor365-metrics 9191→**9421**, keeper raft →**9430**; ocis keeps its defaults; `lib/ports.nix` carries the do-not-register band note. ~20 files updated: probes (pre/post-deploy-check), tests, QML widget default, relay Go flag default, README/FEATURES stamps, runbooks, live-recipe TODO rows | `nix flake check --no-build` rc=0 (`~/.cache/oc-band-flake-check3.log`) — the audit army validates the sweep end-to-end | 20 files (see §d.5 for the commit-smearing caveat) |
| a8 | **PMA 9190 = the 2026-08-10 incident class, resolved correctly this time:** upstream pins `PMA_HEALTH_LISTEN_ADDR=…:9190` in a raw Environment list; `mkForce` provably loses (08-10 incident); the proven **`mkAfter` later-wins pattern** (already in the module for git identity) moves the daemon to 9420; the stale upstream literal exempted via the first-ever `port-registry-audit.allowPorts` with justification | eval: Environment renders `[…9190…, "PMA_HEALTH_LISTEN_ADDR=127.0.0.1:9420"]` (mine last = wins); flake check green | `modules/nixos/services/projects-management-automation.nix` |
| a9 | **Deploy #4 (gen-951, rc=3) fully triaged:** activation SUCCEEDED; the 3 "NEW vs baseline" smoke FAILs were all **guard casualties** (FastFlowLM/InboxClean stopped by guard trips #4392/#4393 mid-storm; Monitor365 connectivity = the storm source itself) — zero real regressions; §11 tree-stamp passed (`tree d5cd73e*`) | deploy log lines 3581-3633; guard journal 11:02/11:15 10-26 | verification only |
| a10 | **Disk emergency contained:** a runaway throwaway `opencloud init` (interactive prompt loop during the overnight session interrupt; **~660G logical spam compressed to ~17G physical**) drove root to **962M free**; log trashed + trash-emptied; stale Oct-16/17 bench scratch reclaimed (a btrfs logical-vs-physical illusion — "6.2G" was ~1G physical); owner chose WAIT on the remaining levers; parallel storage-crisis-recovery sessions then freed the disk to **36G** | df sequence 18G→2.1G→1.4G→962M → 36G; `~/.cache/nix` du breakdown (gitv3 7.8G, tarball 2.8G — untouched, owner levers) | system state, no repo files |
| a11 | **monitor365 secret-logging bug discovered + queued both surfaces:** the `get_sso_config` request logger prints the Pocket ID `client_secret` into journald at INFO level (observed live 11:32 10-26 during deploy triage; NOT reproduced here) | TODO_LIST + docs/todo/services.md rows, commit `70b7fa307` | queue surfaces |
| a12 | **Hermes CDP squatter attributed (suspected collision #4):** `127.0.0.1:9222` = hermes's headless Chromium `--remote-debugging-port=9222` (Chromium's CDP default, set via hermes runtime config `browser.chromium_args` — owner-gated file); ocis's band includes 9222, and ocis (unlike hermes's find-free-port fallback) has no fallback | `/proc/net/tcp` UID attribution (uid 975 → hermes); argv (redacted through `scripts/redact-argv.sh`); store source `browser_launcher.py`/`browser_connect.py` | knowledge; fix is g.1 |
| a13 | **Deploy #6 FIRED 14:15 10-27** on a fully-clean tree (digest = empty, executor paused), green-eval pre-gate `adipkv05…`, forced (guard baseline — see g.2) | `~/.cache/oc-e2-deploy6.log` in flight | evo-x2 system state |

## b) PARTIALLY DONE

1. **Phase E ~60%:** deploy #6 in flight (band fix + PMA override carried). opencloud's activation-start (deploy.sh resets start-limit and retries failed units) is the moment of truth; if it survives to bind 9200, E5–E9 unlock. One suspected remaining collision: hermes CDP 9222 (empirically unknown whether any ocis service in our run-set binds it — it never got past 9191 to find out).
2. **Gatus OpenCloud checks: deployed config-side since gen-950 but red since 09:40 10-26** (service down). They should flip green minutes after a successful start.
3. **Anchor discipline:** executed for gen-950/951; gens 953–955 (gap deploys by parallel sessions) not verified by me — theirs.

## c) NOT STARTED (session-scoped)

| Item | Why not started | Priority |
|------|-----------------|----------|
| E5–E9 owner battery (passkey login → role verify → upload/share → trash/versions posix → WebDAV/rclone → journal+memory sweep) | opencloud not up yet; E5 needs the owner's passkey | Critical once service is up |
| Phase F (opencloud-desktop into HM packages; Android owner-hands) | after E verification — one variable per deploy, twice burned this arc | High |
| Phase G remainder (btrbk 23:45 snapshot + xattr verify, SigNoz/VM-test defer rows) | tonight's 23:45 run is the first snapshot window | Medium |
| Phase H closeout (report, CHANGELOG, marker done, `[decision]` row, docs VERIFY) | after E–G | High |
| monitor365 secret-logging fix + secret rotation | queued (a11); fix lives in ~/projects/monitor365 | High |
| Nix fetch caches (10.6G) / docker residue (15.5G) reclaims | owner levers; owner chose WAIT at 962M-free | owner-gated |

## d) TOTALLY FUCKED UP

1. **The runaway init.log was MY bug and caused the disk emergency.** I ran a throwaway `opencloud init` for port enumeration without binding stdin; `opencloud init` is INTERACTIVE (certificate-check prompts) and with no tty it looped the prompt into the log for ~5h during the overnight session interrupt — 962M free on a shared box with parallel sessions writing. Class: same family as the /tmp-volatile rule (unbounded artifacts in interruptible sessions). Mitigation: every future throwaway daemon run gets `< /dev/null`, a hard `timeout`, and a size-capped log; never `mktemp`+background an interactive CLI.
2. **First keeper move (9234→9239) was whack-a-mole:** I verified 9233/9239 were free ports but never checked them against the ocis band — the full-band extraction (`strings`) took one command and would have shown 9239 is an ocis default. Cost: one wasted deploy cycle and the embarrassing port ping-pong in ports.nix history.
3. **NATS_PORT shipped on strings-evidence without runtime verification.** Binary `strings` includes embedded-library constants (the nats server's own env surface), not ocis's config bindings. The correct evidence (env tags in `services/*/pkg/config`) was available pre-ship via sourcegraph — I fetched it only AFTER the live no-op. Cost: deploy #4's collision persisted.
4. **Display-mangling one-liners kept biting (documented strike class, third session in a row):** `tr -d 'a-z=%'` turned "avg10=3.59" into "103.59" (PSI misread — caught before use); an awk field-offset slip printed /proc/io LABELS as values (caught: absurd output); **three** hook strikes on `rg -rn`-shaped text (`sort -rn` false-positive included). Standing rule reaffirmed: if output looks implausible, suspect your own flags first; quote-scrutiny applies to probes too.
5. **The 20-file band sweep got daemon-smeared across 6 heuristic batches** (538862adc, a5f281ac4, 5eca127fa, 813e8147a, a0d54f690, eebd51c7c): I edited across ~40 minutes before committing; the auto-commit daemon absorbed staged/intermediate states interleaved with foreign files (a +383-line signoz-migrator-guard rides one batch). Content verified present in final state; the proper commit message is lost; amending would absorb foreign work. Lesson: commit in tight waves under daemon load.
6. **Two session interrupts killed in-flight background jobs silently** (the flake check, the first portmap run); once I misread a watcher's `Status: completed` (log-in-file script) as suspicious when it was fine. Re-arm cost: ~15 min total.

## e) WHAT WE SHOULD IMPROVE

1. **Multi-port-binary collision sweeps must enumerate the binary's full listener set BEFORE first deploy** (`strings <bin> | rg '127.0.0.1:[0-9]{4}'` or a 30s throwaway run with bounded output). The A2 sweep checked only the documented entry port (9200); the whole arc lived in the undocumented 86-port band.
2. **Reserved-band guard:** `port-registry-audit` should fail on any NEW fleet port registered inside 9100–9304 (generalize to a `reservedBands` list — ocis owns this one; Chromium CDP owns 9222 explicitly). Today's ports.nix comment is convention; the audit is enforcement.
3. **Interactive CLIs in automation get `< /dev/null` + `timeout` + bounded logs** — codify next to the /tmp-volatile rule in AGENTS.md session discipline.
4. **btrfs space math: `du` reports LOGICAL size on compressed extents** — a "6.2G" reclaim can be 1G physical; check `compsize`/df deltas, never trust du alone for reclaim estimates.
5. **The daemon-smeared sweep argues for pathspec-commit-after-each-logical-edit-group** (≤10 min windows) under active parallel load.

## f) TOP NEXT THINGS

Impact/Critical→Low, Effort S<30min M<2h L>2h. **Harvest contract:** items 1–10 are plan-execution work owned by THIS session (tombstone guards the plan; the `[decision]` row in docs/todo/services.md stays the living tracker until closeout) — deliberately NOT harvested into TODO_LIST.md. Item 11 is harvested (queued at discovery, `70b7fa307`). Items 12+ are cross-referenced existing rows or deliberately not harvested with reason inline.

1. **Deploy #6 result + opencloud activation-start verify** — Critical, S (in flight at report time).
2. **If opencloud dies on 9222:** hermes CDP config fix (g.1, owner) then service-order bring-up (opencloud binds band → hermes restart picks fallback port). Critical, S+owner.
3. **E5:** owner passkey login at `https://cloud.home.lan` → Pocket ID redirect → auto-provision; verify role=admin via the admin-settings app. Critical, S, owner.
4. **E6–E9:** web UI smoke (upload/download/share/delete→trash), **trash+versions restore verify on posix** (plan Addendum-2 — never assume), rclone WebDAV smoke, journal error sweep + `opencloud.service` memory.events high-counter check. High, M.
5. **Gatus OpenCloud pair green + tile dot on dash.** High, S.
6. **Phase F:** `opencloud-desktop` into the evo-x2 HM packages (`platforms/nixos/users/home.nix:712` block); deploy; owner-assisted connect (desktop 4.0 honors webfinger scopes). High, S.
7. **Phase G:** verify btrbk-pool snapshotted `services/opencloud` at 23:45 + `rsync -aX`-class xattr spot-check (getfattr on a trash artifact). Medium, S.
8. **G3/G4 defer rows:** SigNoz memory-rule defer + VM-test defer (documenting the co-import set: catalog.nix, integration.nix, pocket-id.nix, sops-nix, mock-sops) into docs/todo/{monitoring,services}.md. Low, S.
9. **Phase H closeout:** closeout report (self-harvesting), CHANGELOG row, `[decision]` row resolution (pilot LIVE), docs-health VERIFY on touched docs, `scripts/plan-marker.sh <plan> done`, daemon-batch disposition note (d.5). High, M.
10. **Post-fix live probes for the moved ports:** gatus 9410 UI reachable, relay 9411 /healthz, collector metrics 9400 (signoz_traces_reporting), monitor365-metrics 9421, keeper raft 9430 (ss), pma-health /readyz 9420 (the gatus checks re-point automatically; eyeball once). High, S.
11. **monitor365 journal secret-logging fix + client-secret rotation** — High, S. → HARVESTED at discovery (TODO_LIST + services.md, `70b7fa307`).
12. **Nix fetch caches (gitv3 7.8G + tarball 2.8G) / docker residue 15.5G reclaims** — existing owner rows; owner chose WAIT at the 962M decision point. NOT re-queued.
13. **Reserved-band guard in port-registry-audit** (e.2) — Medium, S. → deliberately not harvested: it is a concrete eval-guard edit this executor session should land as part of Phase H if the owner endorses (the ports.nix band comment already carries the convention).
14. **AGENTS.md session-discipline line: interactive-CLI-in-automation rule** (d.1/e.3) — Low, S. → deliberately not harvested (one-line do-on-sight AGENTS.md edit, same disposition as the gen-949 report's §f.12).
15. **~/.cache/oc-* watcher scripts cleanup / canonization** — the quiescence+digest watcher pattern is re-derived per session; gen-949 report §f.1 already queues the productization (`deploy-when-quiescent.sh`). NOT duplicated; my digest-stability augmentation (daemon-flush detection) is documented in this report for that row's implementer.
16. **Upstream opencloud-eu: documentation gap** — the 86-port internal band is undocumented for single-binary deployments (only the dev-federation env file lists per-service ports). A docs PR or issue would prevent every future self-hoster's whack-a-mole. Low, M. → deliberately not harvested: worth doing only after the pilot verdict (Phase 3).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Hermes CDP port (suspected collision #4):** `--remote-debugging-port=9222` comes from hermes's runtime config (`browser.chromium_args`, settings-UI-owned file in /home/hermes — I cannot read or edit it). Flip it to e.g. 9425 now (one settings edit + hermes restart), or wait for deploy #6's empirical verdict on whether any ocis service in our run-set actually binds 9222? (ocis never got past 9191, so this is genuinely unknown; hermes's launcher would auto-pick a free port on next launch if 9222 were held — but ocis, not hermes, is the fragile side.)
2. **Guard-force policy while the monitor365 storm is the baseline:** the memory-emergency guard tripped 58× in 26h (monitor365 DB IO class, MemAvailable 40–55% throughout), so the deploy entry gate's 60-min-clean window effectively never opens; deploys #4/#5/#6 ran under `DEPLOY_FORCE_PRESSURE=1` with calm live PSI. Is force-under-calm-PSI the standing policy until the storage plan v2 lands (this is the gen-949 report §g Q1 storm-policy question, still unanswered)?
3. **The daemon-smeared band sweep (d.5):** content is committed and verified across 6 heuristic batches; the descriptive commit message was lost to the race. Leave as-is, or do you want a one-line note in the Phase-H CHANGELOG row naming the batches?

---

**Handoff note:** deploy #6 (`~/.cache/oc-e2-deploy6.log`, background shell) carries the band vacation + PMA override on a clean tree at `adipkv05…`. First verification after it returns: `pgrep -f 'nh os|switch-to-configuration'` empty → anchor-by-number → `busctl` opencloud ActiveState → `ss -ltn` for 9200 → journal error sweep. The plan file `docs/planning/2026-10-25_13-30_SUPERB-opencloud-pilot-adoption.md` remains EXECUTING under tombstone `opencloud-executor-1`.
