# Verification Re-Fire: §11 Premise Correction + Tripwire, Packaging & §18 Sweep Fixes, Smoke Re-Runs

**Session:** 2026-10-10 ~05:55 → 08:43 CEST (follow-on to the 05-52 Kith-OIDC report; the "THEN WAIT FOR INSTRUCTIONS" continuation)
**Tree:** SystemNix `master` (all work swept by the auto-commit daemon: `93808057`, `1cb4ac25`, `3e8505ec` + `d96bbf53`/HEAD~2 tail)
**Backdrop storm:** the owner's own crush fleet held io PSI some avg60 at 49-73% nearly the whole session. Attribution performed before any mitigation: ALL sshd sessions originate **192.168.1.62** (the owner's MacBook) → the cross-session SIGSTOP license's owner carve-out applies → **hands off**, storm-labeled verification only.

---

## a) FULLY DONE

1. **§11 "false-green" premise VERIFIED FALSE and corrected everywhere.** The 05-52 report's §d.7 ("Pre-deploy §11 lied") and pipeline row 449 claimed §11 validated a stale FOD state that a build then rejected. Deploy-log + session-history evidence disproves it: (i) `t1CRZVb6` was the vendorHash of the PRE-fix crm rev `9df0c4a` (the `[blocked:push]` staging pin), (ii) the failing build was the session's MANUAL toplevel run ~30 min BEFORE deploy attempt 1 (mismatch text first in `.crush/crush.db` at 02:18), (iii) §11's 03:16 pass ran on the post-re-pin tree — an exit-0 FOD build is impossible on a stale hash — and (iv) 03:49 "all cached" is the same FOD staying cached. Surfaces corrected: pipeline.md:449 (closed, full evidence chain), TODO_LIST.md §11 row (closed, mirrored), report §d.7 (inline CORRECTION annotation).
2. **§11 verdict-to-tree binding IMPLEMENTED** (the real gap the false premise gestured at; closes row 436's tripwire ask): `scripts/lib/vendor-freshness.sh` pins the eval-relevant tree (`git rev-parse HEAD` + sha256 of `git status --porcelain` over `VENDOR_FRESHNESS_EVAL_PATHS` = flake.nix flake.lock flake lib modules overlays pkgs platforms systems) before the dry-run, re-pins before EVERY verdict (including the "all cached" early return), FAILs loud on mid-gate mutation ("verdict void, re-run §11"), and stamps every message `[tree <shortrev><*>]`. Deliberate refinement over row 436's literal ask: eval-path-scoped pin instead of whole-tree porcelain, so a mid-gate docs commit from the daemon can't false-trip the gate; rev-moves resolve via `git diff`, unresolvable states fail closed.
3. **§11 hardening verification:** 7 new fixture cases in `scripts/test-pre-deploy-vendor.sh` (deterministic in-repo AND in the git-less selftest sandbox), `checks.pre-deploy-vendor-selftest` green in-sandbox, shellcheck clean, live `--section-11-only` run printed the stamp (`[tree 9380805]`) and honestly built the one uncached FOD.
4. **Post-deploy packaging FIXED** (pipeline row closed): `service-sanity-sweep.sh` staged in the post-deploy-check app derivation (`flake/parts/apps.nix`); the realized app verified to carry all four libs. Both 2026-10-10 deploys' line-187 abort class is dead.
5. **§18 silent-failure seam FIXED** (discovered by the first-ever packaged §18 run): the sweep's FAIL path called the smoke's silent `record_fail` — no verdict printed, FAIL count skipped, tripped-service detail discarded, while the lib-level "never go silent" selftest passed for months. `report_fail` now (prints + counts + baseline-records); contract header + fixture stub updated; `post-deploy-service-sanity-selftest` green. First loud verdict: `Service Sanity CPU — nix-daemon.service=2250%CPU` (correctly attributed to the owner fleet's parallel build).
6. **Two packaged smoke runs completed** (`nix run .#post-deploy-check`, STORM-labeled): run 2 = 123 PASS / 10 FAIL / 7 SKIP / 15 WARN / 2 STORM-SUSPECT. CV browser render + CV proxy-path render cleared STORM-SUSPECT → real PASS. The exit-3 regression detector worked as designed (new names surfaced, old names advisory).
7. **CV `/rest` verdict GREEN on crm `2db45bb`** (report §f.7): auth differential `GET /rest/opportunities` → 200 JSON with bearer vs 401 without. Adjacent finding: the long-running cv-server's 06:23 sync batch PATCHed 37 phantom opportunity ULIDs → 42×404 in one 45 s burst (first 404s in the crm journal since 10-08; zero successful CV writes since the deploy) — folded into row 155 as evidence for the checkpoint/upsert work.
8. **Gatus "Kith CRM (HTTPS)" conditions replay GREEN** (report §f.12): `https://crm.home.lan/login` → 200 text/html, `/healthz` → 200 text/plain with the Gatus UA; gatus journal shows only a 05:26 check CANCEL (deploy race), no FAIL. Dashboard-visual confirmation stays owner-side (no agent-readable verdict surface, row 234).
9. **/data/docker "reads 0" ANSWERED as a permission artifact** (report §f.10, TODO_LIST reconcile row closed): `drwx--x--- root root` — du/ls print 0/empty while stderr says "Permission denied" (earlier probes suppressed stderr). Top-dir mtime 2026-10-07 11:05 (pre-removal) = no reclaim evidence; the ~15.5G AGENTS.md claim stands UNVERIFIED-unchanged. Three doc surfaces corrected: AGENTS.md Docker bullet, storage.md row-205 clause, TODO_LIST row closed with the third-branch answer. The Twenty import source dump (`/mnt/pool/backups/twenty/20261008_020523.sql`, 2.9M) confirmed present.
10. **paperless-gpt :8106 "NOT loopback-only" FAIL proven a transient false positive:** live `ss` shows `127.0.0.1:8106`, no unit restart in journal — storm-racy probe; row queued to storm-downgrade that leg.
11. **Forgejo 502s attributed:** unit is in the documented unmet `.subvol-migrated` condition-gate state (deliberate skip, pre-existing baseline) — no action, no surprise.
12. **Verification appendix appended** to the 05-52 report (re-fire convention: dated appendix, not a new report), covering §f.7/§f.9/§f.10/§f.12 verdicts + all fixes + unchanged §g questions.
13. **Self-harvest at authoring time** (this report's §f follow-ups): 3 new rows landed on BOTH surfaces (TODO_LIST + pipeline.md) — storm-downgrade the ss-parse probes; §18 CPU storm-aware downgrade or two-sample discriminator; assert §18 output visibility at the integration seam. Plus row-286 growth re-stamp (below).
14. **`nix flake check --no-build` green twice** (after apps.nix and after everything; the aarch64-darwin omission warning is the documented expected one).

## b) PARTIALLY DONE

1. **Storm-suspect re-run (report §f.9): 2 of 4 cleared.** CV render + proxy-path render → PASS. Still STORM-SUSPECT: Caddy catch-all 404 probe, InboxClean `/health` — genuinely un-verifiable while the owner fleet holds io PSI avg60 ≈ 49-73%. Re-run condition: io PSI some avg60 < 20.
2. **§17 throttle watch advanced, not fixed:** row-286 re-stamped with live growth — inboxclean-web 136k → **374k** MemoryHigh events in ~2.5 h (≈1.6k/min; the dominant ACTIVE grower), papdashboard 44k → 112k, mr-sync-dashboard 149k → 158k, clickhouse stable. Triage (fix undersized vs justify designed) remains queued.
3. **Bank-Sync:** `sync_errors_total > 0` FAIL + "no successful sync yet" WARN persist (pre-existing baseline; not triaged this session).
4. **FastFlowLM :52625 dead** (pre-existing baseline; kill-or-legitimize row untouched).

## c) NOT STARTED (owner-gated, deliberately untouched)

1. **Twenty→Kith people import** (139 contacts staged at `~/.local/state/crm-migration/export/`): route decision (UI passkey import vs API bearer push) + all-139 consent.
2. **CRM Google-sync ladder:** GCP client choice → secret → consent → module wiring → deploy.
3. **InboxClean→CRM feed go-live scope:** all correspondents vs filtered subset.
4. **First Pocket-ID-login LINK verification** (email-match rule) — requires the owner's first real login.
5. **/data/docker sudo inventory** (services.md step-0) — the ONLY truthful size probe; owner action.

## d) TOTALLY FUCKED UP

1. **The 05-52 report shipped a false load-bearing claim (§d.7 "§11 lied") and it was queued as a `[ready]` row unverified.** The deploy logs sat on disk the whole time — the AGENTS queue-authoring rule (spot-verify premises at queueing time) would have caught it with one grep. Cost: this session spent ~30 min building the evidence chain to disprove our own report; benefit: the correction tightened into a real fix (tree-binding) anyway, and the false premise is now annotated at every surface it touched. Lesson recorded in row 449's close-out.
2. **I nearly falsified AGENTS.md the same way:** my first `/data/docker` probe took the `0` at face value with stderr suppressed (`2>/dev/null`). Caught ONLY because the services.md row's "root-only" caveat triggered a premise re-check before editing. A permission-artifact probe masquerading as a size reading is exactly the count-claim class that burned this repo before. Rule reinforced: never suppress stderr on a probe whose whole point is a magnitude.
3. **§18 was silently broken since it shipped:** the "must never go silent" selftest asserted callback INVOCATION, not output VISIBILITY — so the real smoke wiring swallowed every sweep failure for its entire life, and the packaging bug (item 4 in the 05-52 report) hid it. Two independent gates both green while the user-facing property was false. Fixed + new seam-assertion row queued, but the meta-failure (fixture fidelity ≠ integration fidelity) is the thing to stop repeating.
4. **Process friction, no data loss:** 3 edit-tool conflicts with parallel sessions (re-read + retry each time — correct outcome, but TODO_LIST.md/pipeline.md/report are hot files tonight); 1 banned-command attempt (`systemctl` for scope attribution — tool refused; `ss -tn` + `/proc/*/cgroup` did the job).

## e) WHAT WE SHOULD IMPROVE

1. **Mechanical premise checks for queue rows:** any row claiming "tool X lied/failed/validated Y" must attach the captured output (deploy log path + line) AT QUEUEING TIME — row 449 would have been born dead instead of costing a dispatch cycle.
2. **Storm-aware probes everywhere:** the storm-downgrade set (storm_mode legs) should be derived from a leg registry, not per-site edits — the paperless-gpt :8106 racy-`ss` FAIL shows the next storm will find the next unlisted probe.
3. **§18 CPU leg needs a burst-vs-sustained discriminator:** a 10 s window will name `nix-daemon` on every storm-hours smoke; either two-sample confirmation or a storm downgrade (row queued).
4. **Assert integration seams, not just library contracts:** the seam-assertion pattern (real wiring must print/count/record) generalizes to every sourced-lib-with-callbacks in the repo (offsite-borg, memory-throttle, metrics-gate).
5. **SIGSTOP attribution deserves a script:** the scope → sshd-origin → owner-carve-out flow (cgroup walk, `ss -tn` peer-IP check) worked and took ~4 tool calls; it will be needed again — codify it next to `scripts/crash-autopsy.sh`.
6. **First-run §18 names entered the fail baseline as names** (`Service Sanity CPU/journal` from run 1) — correct semantics, but it means the baseline file now carries names whose first occurrence was itself an artifact; the baseline wants a prune note when the underlying checks change shape.
7. **The 98-unharvested-report gate still blocks every footer commit** (pre-existing campaign row; my report is cited by its rows and self-resolves — the other 98 remain the batching campaign).

## f) Up to 50 things we should get done next

Sorted by impact; tagged: **NEW** = harvested this session (rows landed on both surfaces), **ROW <n>** = existing queue row I read this session, **OWNER** = gated on you.

1. **OWNER — Twenty→Kith people import:** route (UI vs API bearer push) + all-139 consent; CSVs staged and verified.
2. **OWNER — CRM Google-sync:** GCP client choice (reuse InboxClean's vs fresh), then the secret → consent → wiring → deploy ladder.
3. **OWNER — InboxClean→CRM feed scope:** all correspondents vs filtered; conflict policy vs post-import people.
4. **NEW — Storm-downgrade the ss-parse smoke probes** (paperless-gpt :8106 leg first; audit the other ss-parse legs).
5. **NEW — §18 CPU leg:** storm-aware downgrade or two-sample burst discriminator (nix-daemon 2250% will re-fire every storm-hours smoke).
6. **NEW — Assert §18 output visibility at the integration seam** (printed FAIL + counted + baseline-recorded, through the REAL wiring).
7. **ROW 155 — CV syncer durable replay checkpoint + opportunity idempotency:** now carries live 06:23 404-batch evidence (37 phantom ULIDs, zero successful CV writes since the deploy); owner reprioritized the dedupe chain — this is the enabling half.
8. **ROW 286 — Triage the §17 throttled units,** inboxclean-web first (136k → 374k in 2.5 h, active growth).
9. **ROW 284 — §17 user-slice leg** (HM units are invisible to the runtime sweep).
10. **ROW 283 — Continuous throttle observability** (textfile metric + SigNoz rule; §17 only fires at deploy time).
11. **ROW 285 (DONE-example) —** parallel session already TRIAGED InboxClean sync 55% (storm-dominant, stamped 07:16) — remaining half is the Google-split confirmation when calm.
12. **Calm-window re-run of the 2 remaining STORM-SUSPECT legs** (Caddy catch-all 404, InboxClean /health) — agent-actionable the moment io PSI avg60 < 20.
13. **ROW (pipeline) — Harvest/marker-close the 98 standing unharvested §f reports** so the pre-commit todo gate stops blocking footer commits repo-wide.
14. **ROW (pipeline) — Footer-only `--allow-empty` commit path** through the todo gate (every agent rediscovers the block live).
15. **ROW (pipeline) — §11 tree-mutation gotchas-archive entry** (row 438): the tripwire now ENFORCES it; the narrative entry is still unwritten.
16. **ROW (pipeline) — got-hash handoff file** (row 345): on a §11 mismatch FAIL, write got-hash + drv path where `buildflow -s nix-hash-fix` can consume it.
17. **ROW (pipeline) — Per-host §11 gate** (row 346): rpi3-dns + darwin get no FOD preview today (`--host` arg).
18. **ROW (pipeline) — §11/§10-only mutual exclusion** (row 348): exit 64 instead of silent §10-wins.
19. **ROW (pipeline) — Suppress nix trusted-setting notices in gate captures** (row 349).
20. **ROW (pipeline) — Nix-output-shape drift canary for §11 fixtures** (row 350): re-capture REAL output from the locked nix and diff fixture shapes.
21. **ROW (pipeline) — Pre-deploy §11 input-hygiene ghost probe** (row 290): verify the CI probe list is lock-derived (monitor365 ghost).
22. **ROW (pipeline) — deploy.sh entry gate ordering** (stability row): pressure/guard checks BEFORE the 13-section battery (+ fail-close the 15 s journalctl timeout).
23. **ROW (pipeline) — deploy-concurrency guard** (row 429): detect a live nh/switch process, refuse unless forced (the 2026-10-09 double-switch-by-luck).
24. **ROW (pipeline) — Post-deploy-check §1 eval-failure stderr tail** (row 303): one gate run should answer WHY.
25. **ROW (pipeline) — §11-after-lock-wave enforcement point** (row 384, decision): pre-commit vs bot-PR vs accept-and-enumerate.
26. **ROW (TODO_LIST) — Pathspec-commit task edits immediately** (daemon-race codification, row citing 05-10 §d.3).
27. **ROW (TODO_LIST) — check-todo-system.sh DONE-stamp hash reachability leg** (row 342 pairing).
28. **ROW (TODO_LIST) — check-todo-system.sh duplicate-row detection** (row 149).
29. **ROW (TODO_LIST) — Multi-stamp queue-row compaction** (rows 30/69; ≥3 stamps → collapse convention, then apply to existing rows).
30. **ROW (TODO_LIST) — Machine-readable gate fields** (`gate:sudo/owner/deploy`, row 50) + the tq `sudo -n true` pre-flight (row 52) — kills the paid-dispatch-on-sudo-gated-item class.
31. **ROW (TODO_LIST) — Re-fire evidence-appendix convention into CONTRIBUTING** (row 278; practiced live twice now).
32. **ROW (TODO_LIST) — Store-hit identity as sufficient re-dispatch evidence** (row 375 codification).
33. **ROW (TODO_LIST) — Trash-prune mechanism** (weekly `trash-empty 30d` timer; 55G parked in Trash).
34. **ROW (TODO_LIST) — Deploy-gate assertion:** live btrbk retention vs flake (textfile/Gatus), closes the committed-but-undeployed retention class.
35. **ROW (TODO_LIST) — Co-change guard:** `snapshot_preserve` edits must touch the freshness-alarm comment in the same commit.
36. **ROW (TODO_LIST) — io-psi-forensics bundle retention + durability** (1,716 unpruned bundles; atomic-rename+fsync).
37. **ROW (TODO_LIST) — `scripts/crash-autopsy.sh`** codified boot forensics (freezes #3-#13 all paid the manual tax).
38. **ROW (TODO_LIST) — Freeze #8-#11 entries into docs/agents/stability.md** (taxonomy ends at #7).
39. **ROW (TODO_LIST) — IO-pressure admission gate for midnight maintenance** (nix-gc/balance timers abort on zone-6 trip).
40. **ROW (TODO_LIST) — visionreviewd `OnFailure` in the wrong unit section** (journal-proven ignored every boot; one-move fix).
41. **ROW (services) — forgejo.nix stale `runnerSettings.container.network` key** (dead since the native-runner purge).
42. **ROW (services) — paperless postgres `REFRESH COLLATION VERSION`** (warning every cycle; silent index-corruption drift window).
43. **ROW (monitoring) — Fix `\x2d` label escaping in the system-health textfile writer** (whole-file rejection = all system-health metrics blind).
44. **ROW (monitoring) — system_health series-presence Gatus canary** (textfile rejection is invisible today).
45. **ROW (monitoring) — Gatus "Memory Pressure CRITICAL" reads the wrong PSI file** (fired at ~0.06% memory PSI during an IO storm).
46. **ROW (monitoring) — Push-lag tripwire** (daemon commits but never pushes; >N ahead or push-age > M).
47. **ROW (monitoring) — Gatus UI "Logs" button → `logs.home.lan`** (redirect exists; Dozzle button gone with Docker).
48. **ROW (upstream) — extract-twenty `--from-dump` mode** (migration tooling should not require the runtime it migrates FROM).
49. **ROW (TODO_LIST) — `/data` usage alarm at ~85%** (Gatus rule or textfile threshold on existing node_filesystem metrics).
50. **OWNER — Twenty dump archive retention/backup decision** for `/mnt/pool/backups/twenty/` (now the sole people-data source pre-import; nightly dumps stopped with Docker on 10-08).

*Not harvested on purpose:* §f items that are pure ROADMAP fuel (SigNoz time_series_v2 retention study, log→trace correlation, library-deep-dive candidates) stay in ROADMAP per the HARVEST routing rules; the three owner-gated items stay `[blocked:user]` in services.md.

## g) Questions I can NOT figure out myself

1. **People import:** do you want ALL 139 staged contacts imported (event-sourced = permanent), and which route — UI passkey import (your browser time, import actor = you) or API bearer push via `/rest`+`/api/email-sync/people` (agent-side, actor = the api-token)? If filtered: which subset?
2. **Google sync client:** should the CRM's Google sync reuse the InboxClean GCP OAuth client (new scope added) or get a fresh client — and is the standing re-auth discipline worth it to you at all right now?
3. **InboxClean→CRM feed scope:** when live, does every feed-matched correspondent become a CRM person (volume = your inbox), or only a filtered subset — and do imported people win over feed-created ones on conflicts?

---
*Point-in-time snapshot; stales on the next deploy/lock wave. Point-in-time corrections to the 05-52 report were applied inline (non-destructive) per the docs-health ANNOTATE convention. Report not manually committed (harness rule): the auto-commit daemon sweeps it.*
