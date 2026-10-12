# Forgejo Actions go-live: setup-forgejo.sh resurrection ×3, runner label mismatch, deploy gate-blocked

- **Date:** 2026-10-11 03:46 CEST
- **Session span:** ~02:20–03:46 CEST (continues the 02-17 G1 closeout session's arc)
- **Content pin:** SystemNix `64d01da3` (tree clean — daemon swept this session's edits); hub repo `feb0aad`-lineage, tree clean
- **Scope:** post-G1 sync health, backup posture inquiry, Architecture-Catalog go-live chain execution (setup-forgejo.sh debugging ×3 → green), Actions-tab + runner-pickup root causes, label-fix deploy blocked by memory gate. **NOT in scope:** anything not touched this session.

> **ADDENDUM 2026-10-11 ~04:20 — §a.8/§a.9/§b.1 root cause CORRECTED (post-deploy falsification).** Owner force-deployed 03:50; the config labels LANDED (`runner-config.yaml` now carries `labels: [native:host]`, store-verified) and the daemon STILL declared `[native]` — the "config gap" premise was wrong. Source-verified from forgejo-runner **v13.2.0** (code.forgejo.org/forgejo/runner): label syntax is `name:schema` (`labels.Parse` → `native:host` = name `native`, schema `host`); the daemon declares label **NAMES ONLY** (`daemon.go` `Declare(ls.Names())`); config `runner.labels` are DefaultLabels applied only to label-less connections while the legacy `.runner` registration (still passed `--labels native:host` by the register ExecStartPre) supplies the labels. So the daemon always declared name `native` — the real bug was the **workflows**: `runs-on: native:host` matches no declared name under v15's exact-string `ItRunsOn`. Fix: hub `build.yml` + `stale-sources.yml` → `runs-on: native` (daemon-swept); forgejo.nix comment corrected to the real semantics (kept the `runner.labels` line — correct as DefaultLabels source). Run 1 carries the old `runs-on` and will never match — needs cancel (owner) or ignore. New dispatch needed: owner script step 6 or the nightly cron `23 3 * * *`.

---

## a) FULLY DONE

1. **First post-G1 sync verified healthy** — `forgejo-github-sync.service` Finished 02:08:20 (9m15s wall): _"✓ Done! 427 repos processed (367 user + 60 org), 0 failed"_, ~72 mirror creations, all 9 orgs fetched. Next run ~07:57 (6h timer restarted at deploy). Journal `forgejo-github-sync` since 01:50.
2. **Org-inclusive verification row CLOSED on both surfaces** — live node-exporter read 02:25: `forgejo_mirror_org_mirrors 60`, `total 463`, `transferred 2` (= DarkBlocks + DialogesWebInterface dual copies), `reconcile_scrape_errors 0`, `system_forgejo_mirror_errors_30m 0`. One benign `forgejo_mirror_health_scrape_errors 1` counter (consistent with the 01:52 family-stop window; not recurring). Rows: TODO_LIST org-mirrors row `[x]` + `docs/todo/services.md` org-inclusive row `[x]` (metric half closed — the row's last open remainder).
3. **Backup posture fully mapped (evidence-complete):**
   - **Layer 1 local:** btrbk instance `forgejo`, 3/day 05:40/13:40/21:40 → `/mnt/hot/.snapshots` (Samsung), keep 3d — rollback tier.
   - **Layer 2 HDD pool (DAS `/dev/sda`, btrfs):** (a) 8h incremental btrbk sends → `/mnt/pool/backups/forgejo-subvol` (keep 14d/8w); (b) nightly 03:30 transaction-consistent `forgejo dump` zips (repos+DB+config+LFS, 7d) — the deep-history path; (c) weekly restore drill unit (currently VOID until real data — rows :148/:151).
   - **Layer 3 offsite:** Borg→Hetzner includes `/mnt/pool/backups` (so dump zips go offsite); **deliberately EXCLUDES** `forgejo-subvol` ("mirror repos are re-mirrorable from GitHub; the origin never dies with this host", backup.nix:130).
   - **LIVE STATE 03:46: zero real-data backups exist yet** — all 24 pool-side + 7 local snapshots are the 10-01 phantom set (future-dated names, empty-subvol content, all created 2026-10-01 02:10); the nightly dump condition-skipped 11 nights (by design, with the family). First real dump ~03:40 tonight; first real snapshot + full ~67G pool seed at 05:40 (`btrbk-forgejo` TimeoutStartSec=6h provisions the DAS seed). **No data-loss exposure:** the data was frozen on QLC the whole outage (finalize delta 1.97MB), the old tree is parked at `/var/lib/forgejo.qlc-pre-subvol`, and GitHub remains the origin.
4. **setup-forgejo.sh silent death root-caused and fixed (run 1 → zero output):** default `FORGEJO_BIN=/run/current-system/sw/bin/forgejo` doesn't exist on NixOS (real: `/nix/store/2qhix…-forgejo-lts-15.0.9/bin/forgejo`); the first mint died inside a stderr-suppressed command substitution and `set -euo pipefail` killed the script BEFORE the friendly check — zero output, zero API calls (journal-proven). Fixed: binary auto-resolves from the live unit's `ExecStart` (parse verified against `/etc/systemd/system/forgejo.service`), fail-fast `-x` guard, and every silently-fatal `var=$(cmd)` hardened (3 mints, `gh auth token`, all curl captures get `|| true` → HTTP-code checks error loud). bash -n + shellcheck clean.
5. **v15.0.9 API surface verified from source-of-truth** (codeberg raw `templates/swagger/v1_json.tmpl` at tag v15.0.9, 828KB): `units_container` does NOT exist in v15 (all `units`/`units_map` fields belong to Team schemas); repo units are `has_actions` booleans in both `Repository` and `EditRepoOption`; secrets PUT takes `CreateOrUpdateSecretOption` → **201**; dispatch path is `{workflowfilename}` (script's `build.yml` compatible) with **201|204** success codes (script's strict `==204` fixed); `mirror-sync` exists. next.forgejo.org served HTML (rejected), codeberg `/api/swagger.json` 404 — the tagged template was the only clean source.
6. **setup-forgejo.sh END-TO-END GREEN (owner run ~03:15):** `✓ mirror exists` → `✓ Actions enabled (has_actions=true)` → `✓ GIT_CLONE_TOKEN stored` → `✓ sync token stored` (root-only file) → 3 source mirrors synced (bank-sync, cqrs-htmx, go-cqrs-lite) → `✓ build workflow dispatched`. **The Actions tab is live** on `lars/eventcatalog-hub`.
7. **"Why can't I see ANY Actions with Pocket ID?" answered with causal chain:** not SSO (admin session proven by private-repo 200s), not the runner (registered+polling 01:57:43), not instance config (`actions.ENABLED=true`, forgejo.nix:351) — the repo never carried the actions unit because the enabling script had never executed past its first line. All 463 repos are migrate-API mirrors; only the hub repo got the unit (by design).
8. **Runner no-pickup root cause CONFIRMED from v15.0.9 source:** task assignment reads `runner.AgentLabels` (the daemon-DECLARED labels; registration labels are overwritten at declare time — `models/actions/runner.go:62`, `task.go:363`) and matches via `ItRunsOn` — an **exact-string set comparison** (`run_job.go:119-125`). The rendered `runner-config.yaml` carried NO labels (only capacity/log/network — `runnerSettings` never included them) → daemon declared `[native]` → job wants `native:host` → never matches → run 1 queued forever with a silent poller. The rendered-config fact verified live (`cat /nix/store/ipb2…-config.yaml`).
9. **Fix staged + committed:** `forgejo.nix` `runnerSettings.runner.labels = runnerLabels` (native:host into the daemon config) with the 2026-10-11 comment. Eval clean (new toplevel derivation evaluated; the catalog-subdomain warning is pre-existing). Pre-deploy checks 77/77 passed.

## b) PARTIALLY DONE

1. **Runner label fix: STAGED, COMMITTED, NOT DEPLOYED** — `nix run .#deploy` at 03:35 was REFUSED by the memory-emergency gate (guard tripped 4×/60min, FastFlowLM storm active at 03:38:30 "sacrifice FastFlowLM", IO PSI avg300 26%). I did NOT override (freeze-#5 doctrine; override is an owner decision). The queued run 1 is safe and will start the moment the runner re-declares.
2. **Catalog go-live chain:** steps 1–2 executed (script green, run 1 dispatched+queued); step 3 (sops paste of `ARCHITECTURE_CATALOG_SYNC_TOKEN`) owner-gated and NOT done — ideally lands BEFORE the label-fix deploy so one deploy carries both; steps 4–5 (deploy+verify) wait on both.
3. **Hub repo fixes committed only via the daemon heuristic sweep** (unattributed commit; contents not yet `git show`-verified per daemon-race discipline).
4. **SystemNix docs not yet updated** with tonight's findings (v15 API shapes, runner-label gotcha, script failure modes) — harvested as §f items instead.

## c) NOT STARTED

1. sops paste (owner, interactive, never printed): runbook `docs/services/architecture-catalog.md` step 4.
2. Deploy with token → converge `architecture-catalog-sync` → `dist` branch serving → collector `dist_present 1`/`fresh 1` → 3 Gatus checks green → post-deploy §15 stops warning.
3. Runbook/library doc updates for the v15 API + label gotcha (§f).
4. setup-forgejo.sh promotion decision (SystemNix self-elevating app) — question asked earlier this session, unanswered (§g.2).
5. CI-run watch (nix-daemon reachability for the DynamicUser runner, npm in job env, job-token git-push/PUSH_TOKEN fallback) — starts after the label deploy.

## d) TOTALLY FUCKED UP

1. **The backup question was never answered to the user.** "How are we doing backups? HDD pool?" — I gathered the complete 3-layer picture + the phantom-snapshot live state, then got interrupted by the zero-output script run and the answer evaporated mid-draft. Every subsequent reply assumed it had been delivered. It ships in §a.3 of this report instead — three turns late.
2. **Predicted run 2's success without pre-verifying the script's remaining API shapes** ("Expected: ✓ mirror exists → … dispatched"). The `units_container` jq death cost the owner a round-trip that a 5-minute swagger pass (which I then did anyway) would have prevented. Lesson applied mid-session, but it should have been applied after the FIRST failure: an operator script that has never run needs its whole API surface verified against the deployed version, not just the line that broke.
3. **The label mismatch was visible in the G1 closeout's own evidence** — the 01:57:43 heal line reads `with labels: [native]` and was quoted as proof of health; nobody diffed that against `build.yml`'s `runs-on: native:host` until the owner stared at a 7-minute-silent queued run. "Runner healthy" was verified as "unit started clean", not "runner can actually take jobs".

## e) WHAT WE SHOULD IMPROVE

1. **Schema-verify operator scripts before first live run** — any script calling HTTP APIs gets its shapes checked against the DEPLOYED version's swagger/source (the entire `units_container` class was unforced).
2. **The `set -e` + `var=$(cmd 2>/dev/null)` zero-output death pattern** — now fixed in setup-forgejo.sh; other `scripts/` and hub scripts deserve a grep-guard (pre-commit or negative-test) for stderr-suppressed command substitutions in set-e scripts.
3. **Runner label-drift assertion** — an eval-time check or selftest asserting the rendered runner config declares exactly `runnerLabels` (config↔intent drift; this failure mode produced a "healthy" runner that could never take a job).
4. **Post-deploy smoke could assert the runner's declared labels** (`declared` journal line) alongside unit-active checks — same class as e.3.
5. **Interrupted-answer discipline** — a pending user answer must ship at the next natural point; evidence gathered is not an answer delivered (§d.1).
6. **"Prerequisite satisfied" claims should include the runtime-semantics tail** — forgejo up + runner registered ≠ CI runnable (labels, PATH, tooling); the go-live runbook's watch-list was right, but the rows treated "runner healed" as terminal.

## f) NEXT (self-harvested at authoring time)

1. **[blocked:deploy] Deploy the staged runner label fix** when the memory gate clears (≥60min trip-free) or owner overrides; verify daemon declares `native:host` and run 1 auto-starts. _(harvested: TODO_LIST + services.md runner-label row)_
2. **[blocked:user] sops paste `ARCHITECTURE_CATALOG_SYNC_TOKEN`** (runbook step 4) — ideally before item 1's deploy. _(harvested: catalog row)_
3. **[ready] Watch the first CI run** — green + `dist` branch; watch-list: nix-daemon reachability, npm in runner PATH, job-token git-push (PUSH_TOKEN fallback).
4. **[ready] Post-green chain:** deploy(token) → converge sync → `current/index.html` + stamp → 3 Gatus checks green → post-deploy §15 silent.
5. **[ready] Verify tonight's first REAL backup legs:** dump ~03:40 (zips in `/mnt/pool/backups/forgejo/`), snapshot 05:40 + ~67G pool seed over the DAS link. _(premise-updated rows :148/:151 on both surfaces)_
6. **[ready] Re-earn G1 gate evidence + F24 restore drill** on real-data snapshots (rows :148, both surfaces updated).
7. **[ready] Docs: runbook `architecture-catalog.md` + `forgejo.md`** — v15 API shapes (`has_actions`, dispatch filename+201/204), runner-label gotcha, setup-forgejo failure-mode fixes.
8. **[decision] setup-forgejo.sh promotion** to a SystemNix self-elevating app (`nix run .#architecture-catalog-setup`) — moves the cross-repo contract (binary path, token paths, sops key) into the repo that depends on it.
9. **[ready] Verify the hub repo's daemon commit contents** (`git show --stat` + diff check; re-message per daemon-race policy if it batched foreign files).
10. **[ready] Runner label-drift assertion check** (e.3) — eval-time or selftest.
11. **[ready] Grep-guard for silent-death substitutions** in set-e operator scripts (e.2).
12. **[watch] FLM storm vs deploy timing** — pre-existing baseline (FastFlowLM :52625 FAIL tracked); tonight it gates the deploy.
13. **[context, carried] Burn-in tail + QLC trash + dual-copies prune** (02-17 report §g1/g2) — legs 05:40/13:40 make trash eligible ~2026-10-12 13:40; §g.3 below re-surfaces it.

## g) QUESTIONS (cannot self-answer)

1. **Deploy timing under the FLM storm:** wait for a ≥60-min trip-free window (my recommendation — run 1 is safely queued and nothing decays), or do you want to force it now (`DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`, freeze-#5 class risk, your keypress)? The sops paste (§f.2) pairs with either path.
2. **setup-forgejo.sh home:** promote to a SystemNix self-elevating app (my earlier recommendation — the drift-prone cross-repo contract moves in-repo), or does it stay in the hub repo?
3. **(Carried from 02-17, now actionable soon) `/var/lib/forgejo.qlc-pre-subvol` (67G QLC reclaim):** trash after 2 real btrbk legs + 1 mirror cycle (~2026-10-12 13:40, pending tonight's legs landing clean), or hold longer? Same ruling family: keep or prune the dual DarkBlocks/DialogesWebInterface copies?

---

**Verification index:** sync journal (`journalctl -u forgejo-github-sync.service --since 2026-10-11 01:50`), metrics (`:9100/metrics` forgejo_mirror_*), mount (`findmnt -T /var/lib/forgejo` → nvme1n1p2[/hot/forgejo] subvolid 260), snapshots (`/mnt/hot/.snapshots`, `/mnt/pool/backups/forgejo-subvol` listings), dump skips (`journalctl -u forgejo-backup.service`), runner (`journalctl -u 'gitea-runner-evo\x2dx2.service'` + store config.yaml + v15.0.9 source task.go/run_job.go/runner.go), swagger (`/tmp/v15-swagger.tmpl` from codeberg tag v15.0.9), deploy gate refusal (systemnix-deploy-tail 03:38:38).
