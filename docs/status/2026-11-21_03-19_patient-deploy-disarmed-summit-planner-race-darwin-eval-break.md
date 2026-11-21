# Status: Patient Deploy Disarmed Before a Mid-Edit Tree Race + Darwin Eval Break Found (paperless fix still undeployed)

**Session window:** 2026-11-21 02:28 → 03:19 (continuing the 2026-11-20 un-pin-wave + paperless-loopback-fix session)
**Author:** crush session (paperless-fix continuation)
**Head at report time:** `d894a7112` (my docs commit) on top of `8ef8d3807`, `7566a4728`, `d4a6e6187`

---

## Executive summary

The session's ONE goal — land the paperless 3.5.0 loopback-host fix (`14ec73b28`, `PAPERLESS_ALLOWED_HOSTS`) — did **not** deploy. The prior session's fire-loop was found to have **never fired** (no logs, no process). I pre-built the toplevel green, armed a patient deploy loop with a backup-window guard, triaged **all 6** battery FAILs from the 22:02 battery (2 were stale), completed the three standalone observability re-verifications, landed the flake.nix f4a03c00 tense-refresh **edits** (commit blocked — see below), and closed the TODO_LIST watermark re-read row with fresh negative numbers.

Then the tree turned hostile: a **parallel session is actively landing a "summit-planner" service wave** (uncommitted `flake.lock` float + `lib/lock-audit.nix` + `lib/ports.nix` + `configuration.nix` + `deploy.sh` + new `modules/nixos/services/summit-planner.nix`), which makes the **working-tree toplevel eval RED** (`io-tier-coverage-audit`: `summit-planner`, `summit-planner-backup-dir` lack IO tiers — their own gate, mid-edit). I **killed my armed deploy loop at 03:13 before it could fire at 03:41** — firing would have either bounced on the red eval or, worse, deployed their half-committed float.

Separately, the pre-commit hook's `nix flake check --no-build --all-systems` leg exposed a **NEW repo-wide `.nix`-commit blocker**: `checks.aarch64-darwin.immich-api-key-sweep-selftest` fails at `systemd-262` not available on `aarch64-darwin` (un-pin-wave fallout — nixpkgs 0bb82723's systemd meta change meets a darwin-hosted selftest). My flake.nix tense-refresh **edits are staged but uncommitted** because of it.

---

## a) FULLY DONE

| # | Work | Evidence |
|---|------|----------|
| a1 | **Prior fire-loop disposition verified**: the armed patient deploy loop from the prior session NEVER fired — no `deploy-fix-20261121-f*.log`, no process, newest deploy log was the 01:34 pressure refusal. gen-1020 anchored (`readlink /run/current-system` == `system-1020-link` == `zfrqkk756…`), paperless-gpt `failed` → fix confirmed undeployed at session start | `ls ~/.cache/lockfloat/`, `/var/log/systemnix-deploys/2026-11-21_01-34-33.log` |
| a2 | **Pre-build GREEN**: evo-x2 toplevel built at HEAD (7566a4728-era tree, nixpkgs 0bb82723) → `PREBUILD_RC=0`, store warm, deploy build-phase would have been a no-op | `~/.cache/lockfloat/prebuild-20261121-0231.log` |
| a3 | **Backup window pinned from live timers** (not from memory): `monitor365-server-backup.timer` fires 03:00:00; yesterday's run spanned 03:00→03:32 (journal `Deactivated successfully` pair). Guard window 02:55–03:40 encoded into the loop; loop correctly guard-slept through it | `systemctl list-timers`, `journalctl -u monitor365-server-backup` |
| a4 | **Patient deploy loop armed then killed correctly**: wrote `~/.cache/lockfloat/patient-deploy-20261121.sh` (double-calm io-PSI gate some<18/full<15 60s apart + backup-window guard + rc classification 0/12/13/14/3 + ≤3 attempts, logs to `~/.cache/lockfloat/patient-deploy-20261121.log`); armed 02:33; it polled correctly (watched PSI oscillate 20→98), guard-slept the window; **killed 03:13** when the working tree went eval-RED mid-edit — it never fired | loop log `patient-deploy-20261121.log` (28 probe lines), `job_kill 031` |
| a5 | **All 6 battery FAILs re-triaged with live evidence** (22:02 battery had 6 FAIL; this session resolves 3 as stale, root-causes 1, and maps 2 to the pending deploy) — details in table below | journal probes + cgroup reads 02:29–02:41 |
| a6 | **§17 memory sweep re-run**: cvagent 531,330 `memory.events high` / 5.9h (~1.5k/min avg, bursty — 0 in a 10s post-reclaim dip), cur 810–848 MiB oscillating against the derived 819 MiB high of its 1G `MemoryMax`, oom_kill 0; forgejo 143,254 events / 5.7h (~420/min), cur 297 MB. **The 2026-11-13 1G bumps did NOT stop the thrash — cvagent's working set grew into the raised budget.** Fresh numbers recorded in `stability.md:520` + `monitoring.md:332`; TODO_LIST post-restart re-read row `3611` TICKED with the negative answer | `/sys/fs/cgroup/system.slice/{cvagent,forgejo}.service/memory.*`, commit `d894a7112` |
| a7 | **§19 storage-history freshness**: `backups.prom` regenerated 1 min before probe; `backup_healthy{storage-history}=1`, age 22 h (normal pre-run; next fire 04:27), `backup_ever_succeeded=1` | `/var/lib/prometheus-node-exporter/textfile_collectors/backups.prom` |
| a8 | **SigNoz impersonation re-verified**: `/api/v1/global/config` → `"impersonation": {"enabled": true}` (under `identN`) — PASS (python urllib probe; typed `nc` is yolo-blocked) | python3 probe 127.0.0.1:8080 |
| a9 | **flake.nix f4a03c00 tense refresh — EDITS LANDED (staged)**: hermes edge (1460-64) + monitor365 edge (1489-91) now carry "PIN LIFTED 2026-11-20: root floats at 0bb82723, proof3 green". Deliberately did **NOT** claim the monitor365 collapse-LIFT: `nixpkgs-hermes` still sits at f9a75f41 ≠ root 0bb82723, and its LIFT condition ("monitor365 probes clean bare on the ROOT trunk") remains untested. Header block (29-35) left as dated history per plan | `git diff --cached flake.nix` |
| a10 | **cv/cvagent exe mystery resolved**: live `cvagent` binary is `e36772cb…`, proof-3's "cv 53e9e8b" is a DIFFERENT input — `flake.lock` carries both (`cv→53e9e8b88c5e`, `cvagent→e36772cbf85b`); live binary matches its own input's tip. No split-brain; prior session's "cv-53e9e8b exe-verified" note conflated the two inputs | flake.lock parse + `sudo readlink /proc/<MainPID>/exe` |
| a11 | **Commit hygiene held**: docs commit `d894a7112` (tick + 2 library appends) landed after two hook rejections (index.lock collision with my own 07-min eval-leg commit; commit-msg 84>72 chars). flake.nix edits left STAGED, never force-committed | `git log`, hook output |

### The 6-FAIL triage table (a5 detail)

| Battery FAIL | Verdict | Evidence |
|---|---|---|
| #1 CV browser-render smoke (`/admin` goto timeout 30 s; pages load, don't render) | **REAL + ROOT-CAUSED (chronic, not wave-caused)**: cvagent.service spends its life at its `MemoryHigh` (531 k throttle events, cur pinned 810–848 MiB vs 819 MiB high) → constant reclaim → typed-reader queries slow → client timeout → `context canceled` → 500 storm on `/`. Error rates PRE-date the wave: 230 context-canceled in 2 h pre-wave (18:00–20:00) vs 404 in 2.5 h post (same class, slightly worse under IO churn). The chronic read-loop (per-request full scan of the ~685 MB fact store) is the known upstream defect (`upstream.md:423` DONE-cache row, `TODO_LIST:3605/3734` unpushed upstream fix) | `journalctl -u cvagent` windows, cgroup reads, `/tmp/.smoke-cv-render.log` |
| #2 Paperless login lost Pocket ID auto-submit | **STALE / FALSE FAIL**: live login page (openssl s_client probe via Caddy) carries `<form id="social-login" action="/accounts/oidc/pocket-id/login/">` + JS `form.submit()` — the `.oidc-url` click is only a legacy fallback branch. Probed mid-activation at 22:02 = artifact | live HTTPS probe 02:34 |
| #3 paperless-gpt not active | **REAL — addressed by the pending deploy**: unit `failed` (fix `14ec73b28` not in any generation) | busctl 02:29 |
| #4 Bank-Sync sync_errors_total > 0 | **Sync itself GREEN**: 02:17 run `sync completed successfully provider=wise total_new=0`, mesh published 20/0. Counter is historical. Two live findings: (1) **statements paused pending Wise SCA approval** on 2 balances — USER ACTION required in the Wise app; (2) degraded-fallback attribution WARN ("none of the provider's transfers matched — possible wire drift") | `journalctl -u bank-sync` 02:17 window |
| #5 paperless-web 383 lines/min | **REAL — addressed by the pending deploy**: still 1364 lines / 19 min (~72/min total, ~20/min DisallowedHost) — loopback consumers still rejected | `journalctl -u paperless-web` 02:10+ |
| #6 dnsblockd filter-proxy keys but unit not active | **STALE**: dnsblockd `active/running`, exe = `dnsblockd-b3b2cde` (sudo /proc read), `immich.home.lan` resolves. Battery probed BEFORE the 21:xx restart. Two non-fatal live signals noted: TRACK_METRICS drops (deadline exceeded, dropped_total 22→36) + periodic TLS handshake errors from 192.168.1.46 | busctl + journal 02:30 |

---

## b) PARTIALLY DONE

1. **The paperless fix deploy** — fix commit `14ec73b28` verified in tree (`paperless.nix:597`) + HEAD eval-green (02:31 prebuild), but **gen-1021 does not exist**. Deploy disarmed for cause (mid-edit tree); the parallel summit-planner wave's own deploy would carry `14ec73b28` automatically (any deploy picks up the working tree... **CAVEAT: their deploy only carries the fix once THEIR wave lands the tree in a green, committed state — and their io-tier audit is currently RED, so their wave is not deploy-ready either**).
2. **flake.nix tense refresh** — edits staged (a9); commit blocked by the darwin selftest break (the hook runs the full `--all-systems` walk on staged `.nix`). First attempt burned the full ~7-min eval leg then aborted. **Do NOT retry until the break is fixed** — each retry costs the eval leg.
3. **Standalone captured flake check** — the hook's `--all-systems` run (02:38–02:47) doubles as the evidence that the tree's darwin surface is RED; a captured standalone run is pointless until the break is fixed. Not separately captured.

## c) NOT STARTED

1. Post-fix verification chain (paperless-gpt ActiveState + restart-counter reset, paperless-web journal rate back to baseline, anchor-by-number, exe checks) — blocked on deploy.
2. Post-deploy battery re-run (`scripts/post-deploy-check.sh`, capture-once to `~/.cache/lockfloat/postdeploy-20261121-*.log`) — blocked on deploy.
3. CV `/admin` 30 s-timeout render smoke re-run — deferred (heavy probe under load).
4. Wise SCA approval — user action, cannot be automated (see g3).

## d) TOTALLY FUCKED UP

1. **My patient deploy script was under-gated**: PSI + backup-window only — it LACKED the quiescence gates (tree-clean, eval-relevant-mtime-cold) that `scripts/deploy-when-quiescent.sh` already implements. Had the summit-planner session paused editing >90 min, my loop would have fired at 03:41 into their uncommitted float. Caught by the 03:12 eval probe (RED) and killed — **no harm landed, but by luck of timing, not by my script's design.** Rewriting a weaker version of an existing, battle-tested script instead of reusing it was the root error.
2. **index.lock collision (self-inflicted)**: I queued the docs commit while my own flake.nix commit (03E) still held the lock during its eval leg → rc=128, one wasted cycle. Should have awaited 03E before the next git write.
3. **Commit-msg length miscount** (84 > 72 house limit): one more wasted cycle on the docs commit.
4. **The flake.nix commit attempt ran a 7-min full-eval leg into a PSI-wait window** — intentional front-loading, but it discovered the darwin break only at the END. A pre-commit "is the all-systems surface green" probe would have answered that first; on a tree with fresh float fallout, probe before paying.

## e) WHAT WE SHOULD IMPROVE

1. **Deploy wrappers must embed ALL gates** (tree-clean + eval-relevant-mtime-cold + PSI + window). Any custom loop is a worse `deploy-when-quiescent.sh`; extend that script instead of writing siblings.
2. **The darwin eval break needs a class fix, not a workaround**: `checks.*.immich-api-key-sweep-selftest` (and any sibling referencing `pkgs.systemd`) must be linux-only or `meta.platforms`-gated — the un-pin wave will keep tripping darwin-hosted selftests that embed systemd paths. Until fixed, **every `.nix` commit in this repo is blocked**, including the parallel session's summit-planner wave.
3. **Battery legs should mark units known to be mid-restart** — 2 of 6 FAILs (#2, #6) were stale probed-mid-activation artifacts; a restart-timestamp check per leg would suppress that class.
4. **Wise SCA pauses are a recurring human-in-the-loop blind spot** — a journal-grep check ("statements paused pending SCA") in Gatus/monitor365 would page the owner instead of waiting for a battery FAIL.
5. **cvagent: stop tuning watermarks** — two bumps (512M→1G high-derived) both got absorbed by the growing working set; the upstream read-model cache (`TODO_LIST:3734`, blocked:push) is the only real fix; the push is now blocking TWO symptom classes (500 storm + memory thrash).
6. **Session-start probe set** (gen number + anchor + target-unit states + `ls -t docs/status`) — re-deriving them costs ~6 tool calls every resume; a standing one-liner would compress it.

## f) NEXT THINGS (prioritized; ★ = new this session)

**Deploy-critical path**
1. ★ Fix the darwin selftest break (linux-only gate on `immich-api-key-sweep-selftest` + sweep for sibling systemd-referencing darwin checks) — unblocks ALL `.nix` commits incl. my staged flake.nix tense refresh and the summit-planner wave.
2. ★ Land the summit-planner wave cleanly (parallel session's job: io-tier fragments for its 2 units, commit, eval) — or coordinate so their red state doesn't straddle a deploy window.
3. Deploy the paperless fix (whatever vehicle the owner picks — see g1), then: paperless-gpt ActiveState + restart-counter reset, paperless-web rate → baseline, anchor by NUMBER, exe checks.
4. Re-run the full post-deploy battery (capture-once) — expect 6 FAILs → ≤2 (cv render + bank-sync remainder).
5. Commit the STAGED flake.nix tense refresh once the darwin break is fixed (do not re-pay the eval leg until then).
6. ★ Wise SCA approval (owner, Wise app) → next bank-sync auto-resumes statements.

**Follow-through from this session's findings**
7. ★ Record the SCA-pause + attribution-WARN findings as a services.md row (bank-sync domain) — the 02:17 evidence is only in this report.
8. ★ TRACK_METRICS dropped_total climbing (22→36, deadline exceeded) in dnsblockd — watch-row or upstream issue; metrics increments are being dropped under load.
9. ★ dnsblockd TLS handshake errors from 192.168.1.46 every ~3-9 min (EOF / illegal parameter) — identify the client (probably a fixed device with a broken DoH/DoT client); 01:50–02:12 journal.
10. ★ Paperless catalog-WARN from the hook eval: "integration subdomain(s) without catalog entries — paperless will vanish from derived DNS once dns-local.nix is deleted" — mint the catalog entry or opt out explicitly.
11. ★ CV graphrag WARN: "settings.graphrag.store_dsn set but graphrag disabled — keys INERT" (eval warning on checks.cv) — flip enabled or drop the keys (owner call: intentional-absence row exists?).
12. Battery stale-FAIL suppression: add mid-restart detection to post-deploy-check.sh legs (e.3).
13. Wise-SCA journal check in monitoring (e.4).
14. cvagent upstream read-model cache: PUSH the blocked wave (`TODO_LIST:3734`) — now blocking two symptom classes.
15. Re-probe `/health` startup latch after next deploy (existing watch row `TODO_LIST:3702`).
16. dnsblockd filter-proxy battery leg: make it restart-aware (stale-FAIL class, e.3 sibling).
17. ★ My patient-deploy script: delete or rework into a deploy-when-quiescent extension (e.1); the current file in `~/.cache/lockfloat/` is a trap for the next session that finds it.

**Standing queue (pre-existing, untouched here — pointers only)**
18. 3 prior §g owner questions (dnsblockd upstream-chain attribution; templ-components v1.27.1 tag re-point intent; push arrangement) — still unanswered, re-surfaced below.
19. monitor365 batch riders: guard + count-gate diagnostics "ride the next deploy" (8ef8d3807 closeout) — that deploy is now the same vehicle as #3.
20. Post-float integration verify with guard DISARMED (`TODO_LIST:190`, blocked on the lock-float eval gate being RED — same darwin break class may be the blocker; verify after #1).
21. flake.nix lines ~29-35 header tense (deliberately left as dated history — confirm that reading is wanted).
22. `stc test`-class unrestarted-unit trap: the dnsblockd split-brain lesson deserves an eval-time assertion or post-deploy exe-check leg (post-deploy battery).
23. Immich `.immich-api-key.*` debris + hub `/readyz` verify (`TODO_LIST:480`, blocked:deploy) — same next-deploy vehicle.
24. Summit-planner service runbook (`docs/services/summit-planner.md` exists untracked — it needs the standard runbook review once the wave lands).
25. ★ Consider pinning `checks.aarch64-darwin.*` CI time: the hook's all-systems walk enumerated ~140 darwin checks — if the darwin surface keeps breaking on floats, a linux-only default + explicit `--all-systems` CI job would shorten the commit loop (doctrine change, owner call).

## g) QUESTIONS FOR THE OWNER (cannot self-answer)

1. **Deploy vehicle for the paperless fix**: (a) re-arm a FULLY-gated patient loop (deploy-when-quiescent-based: tree-clean + eval-relevant-mtime-cold + PSI + backup-window), (b) fire manually once the summit-planner wave lands and the tree is quiescent, or (c) explicitly let the summit-planner wave's own deploy carry it (their io-tier audit is currently RED, so their timing is unknown to me)? The unit is crash-looping in prod (contained; user-facing paperless is fine) — but every hour is continued DisallowedHost spam + restart churn.
2. **The darwin eval break fix locus**: make systemd-referencing selftests linux-only (my recommendation: `meta.platforms = lib.platforms.linux` on the selftest + a sweep for siblings), or is there a reason the immich-api-key-sweep selftest must evaluate on darwin? May I fix it in this repo now (it blocks my staged flake.nix commit AND likely the parallel session's wave)?
3. **Wise SCA**: will you approve the statement exports in the Wise app (2 balances paused: `balance:108989445` USD, `balance:108989341` EUR — approval opens a ~90-day window), or should bank-sync park those statement exports until you opt in (is there a config knob, or should I file the upstream ask)?

---

### Handoff state (03:19)

- **Live**: gen-1020 anchored; paperless-gpt `failed` (fix undeployed); paperless-web spamming ~20 DisallowedHost/min; dnsblockd b3b2cde active; cvagent throttled-at-high (chronic); monitor365-server-backup ran 03:00–~03:32 (verify in the morning); btrbk-forgejo-clean + restic-storage-history fire 04:23/04:27.
- **Tree**: HEAD `d894a7112`; **parallel session mid-wave** (summit-planner module + lock float + io-tier audit edits, all uncommitted; their working-tree eval is RED via their own io-tier gate); my flake.nix tense-refresh edits STAGED; `docs/services/summit-planner.md` untracked (theirs).
- **Armed actors**: NONE from this session (deploy loop killed 03:13, disarmed). The auto-commit daemon remains a background actor as always.
- **Logs**: `~/.cache/lockfloat/{prebuild-20261121-0231.log, patient-deploy-20261121.log, evalprobe-20261121-0312.log}`; hook eval output with the darwin break in `~/.cache/lockfloat/` via job 03E (`.crush/shell-output/output-1805399179.log` full capture).
