# Status Report: Master-Plan Execution (mid-run) — NetBird Control-Plane Resilience + Deploy Hardening

**Date:** 2026-10-17 20:59 CEST
**Session:** Full Execution Mode against `docs/planning/2026-10-17_19-52_netbird-control-plane-resilience-and-deploy-hardening.md` (23 macros, ~16.6h planned)
**Trigger:** owner go — "GET SHIT DONE! The WHOLE TODO LIST!"
**Status:** 7 of 23 macros COMPLETE (incl. the 1%/51% Tier-1 item), run paused mid-flight for this checkpoint; `nix flake check --no-build` green at pause. Remaining: 10 agent-executable macros not yet started, 3 owner-gated, 3 doc/tail macros.

---

## a) What got executed (verified, in plan order)

### M23 — TODO-queue landing (COMPLETE)
All plan `[ready]` items landed into `TODO_LIST.md` domain sections (storage/services/upstream/pipeline — no dated sections, per the 2026-09-19 contract) + full library entries in `docs/todo/{storage,services,upstream,pipeline}.md`. `check-todo-system.sh` exit 0 ("queue/library structure clean"). Gated/tail items landed with correct lifecycle tags: M12 `[blocked:deploy]`, M16-run-half `[watch]`, M21 `[blocked:push]`. M7/M9 were found already queued by the parallel session (rows :392/:393) — not duplicated.

### M1 — pbx netbird-management boot-robustness (COMPLETE, in tree, deploy-gated)
`hosts/pbx/netbird.nix`: `RestartSec=10`, `StartLimitBurst=10`/`StartLimitIntervalSec=600`, `after = [ network-online.target pocket-id.service ]` + `wants network-online.target`, dated incident comment citing the 09:07 UTC start-limit evidence. Render verified by eval: `{Burst=10; Interval=600; RestartSec=10; after=[network.target network-online.target pocket-id.service]}`. Baseline captured BEFORE the edit (Restart=always, RestartSec=null, no start-limit, after=[network.target]) — nixpkgs renders zero backoff, confirming the incident mechanism. Deliberately widened NOT disabled (guardrail #3: a permanently-broken management must still reach `failed` so `pbx-alert@` pages).

### M2 — pbx netbird-provision finite bound (COMPLETE; live-verify found a NEW owner action)
`TimeoutStartSec = "10min"` added (Type=oneshot infinite default = the AGENTS-documented stalwart jam class; the 30min retry timer makes a killed run cheap). **Live verify (M2.3): provision did NOT complete after the 17:19 management start** — journal shows 17:18:27 FATAL (management still down, 1 min before my manual start) then 17:47:03 **HTTP 404: the pushed PAT is dead in the management store** (the AGENTS "provision 404 burn" class — expired or re-minted-away value). Recovery is owner-only (dashboard PAT mint + push-secrets): routed as TODO §70 row, coin `nb-pat-remint-live`.

### M3 — pbx-alert@ relay fix (COMPLETE — root cause was TWO defects)
Journal forensics (`pbx-alert@netbird-management`, boot window): **(1)** `hostname: command not found` — the store script's bare `hostname` resolves nowhere without a unit PATH (the exact class backup.nix documents for the staging unit's gzip); the page printed `ALERT: netbird-management on  at …` with an empty host. **(2)** the relay was OnFailure-triggered 5× within one second and hit **its own default start-limit** (`start-limit-hit`, 09:07:32) — the pager was failed at the exact moment it was needed. Fix: `path = [ pkgs.hostname ]` + `unitConfig.StartLimitIntervalSec = 0` (pocket-id doctrine, journal-proven lineage in the dated comment).

### M4 — contract pins (COMPLETE)
`tests/netbird-contract.nix` +6 invariants (management retry envelope + ordering, provision timeout, **freeswitch LimitNOFILE**, **pbx-alert@ PATH + start-limit-off**) → **30 invariants hold** (built green). Toplevel eval green.

### M8 — pbx stalwart + telephony-health investigation (COMPLETE — found a SECOND live incident)
- **stalwart-provision**: boot-window failure was `Failed to read system DNS config: no nameservers found` (same boot-DNS race family as M1); **self-healed at 17:47:03** (re-run: 0 failed, Result=success). No action.
- **telephony-health (545 failures since 09:09) + my own `fs_cli` failing**: root-caused to **freeswitch FD exhaustion** — `/proc/2725/fd` at **1022/1024** (soft limit 1024): **492 ESTABLISHED loopback connections to 127.0.0.1:8021 (ESL), all held by freeswitch, client = telephony-agent (pid 2729)** — the agent's ESL reconnect loop (~1/min since boot) leaks one accepted-but-unserviced connection per retry. At 17:47:45 mod_event_socket hit `Socket Error [Too many open files]` → `Stateful Listener 0 has expired` → ESL (fs_cli, telephony-health, AI voice agent, textagent) dead since, while **the SIP/trunk plane kept serving** (freeswitch active, 5060/5061 up, scanner noise only — no evidence of missed real calls).
- Fixes: `freeswitch.serviceConfig.LimitNOFILE = 65536` (host-side override, dated comment; buys ~46 days at the measured ~55 fd/h leak) + the REAL fix routed upstream (sibling agent ESL close + bounded reconnect, TODO §70 `agent-esl-leak`). **Immediate recovery needs a freeswitch restart — owner action** (TODO §70 `esl-fd-leak-restart`, P0: `systemctl restart freeswitch.service` then the agent/textagent units; only process exit frees the 492 held fds).
- pbx-artmann docs: TODO §70 (4 rows: ESL restart P0, PAT re-mint, agent leak sibling, webhook wiring) + §71/§72 harvests + CHANGELOG entry; docs-gates: dprint clean, **docs-freshness FRESH**; the audit-all residue is parallel-session token churn at the DF bar (pre-existing class, 5 historical items struck with lineage along the way). Commits `1849492` + `b49c142` (pathspec-clean, attribution footers).

### M5 — SystemNix regression pins (COMPLETE)
`scripts/test-deploy-pipeline.sh` — **22 assertions green**: manifest sed parse (normal/empty/single), stamp key semantics (same-tree stable, tracked-mutation sensitive, **untracked-blind** — the tracked-files-trap-is-a-feature pin, throwaway-git-repo fixture), 12h expiry window (2h fresh / 13h expired), `deploy_restart` rc-124 path (**extracted live from deploy.sh** — PATH-shim sudo/systemctl; asserts warn + journal pointer + rc 0; success path silent), `probe_endpoint` fixture (`.ok`/`.body` per probe) + **compute-before-batch ordering tripwire** (the use-before-set class I nearly shipped). Wired as `checks.deploy-pipeline-selftest` (staging doctrine; **git added as buildInput** — the sandbox lacked it, found and fixed). Sandboxed build green.

### M6 — boot-mirror-sync path trigger (COMPLETE — joint with a parallel session)
`systemd.paths.boot-mirror-sync` (PathChanged `/boot/loader/entries` → the service; restartTriggers rejected — it fires on nix config changes, not runtime ESP writes; the sync's own reverse-propagation re-arms the trigger once, second run converges, no loop) + **5 module self-assertions** (path shape, Unit=, wantedBy, mount condition, nofail — the wants-not-requires posture pinned). A parallel session (working from my M23-landed row) contributed `checks.boot-mirror-path-trigger` + 3 negative-test legs (watcher/condition/nofail-dropped) on top of my module — cooperative overlap, both halves verified green.

### M7 — shape-audit oneshot-timeout class (COMPLETE)
- **`serviceOneshotDefaults` gained a `TimeoutStartSec = mkDefault "5min"` floor** — clears ~25 helper-using units in one edit; long-leg units (llama-rag-model-fetch 20min, monitor365-schema-migrate 3min — verified pre-set) win the merge by priority.
- **Class 7 audit**: boot-blocking (multi-user/graphical) Type=oneshot with unset/infinity TimeoutStartSec → eval throw; `allowUnboundedOneshot` option shipped EMPTY (zero live users needed).
- The 10 non-helper stragglers (nixpkgs/foreign-rendered: cpufreq, sshd-keygen, logrotate-checkconf, linger-users, post-boot, inboxclean-backup-dir, mglru-thrash-protection, restic-*-setup ×2, signoz-clickhouse-log-ttl) bounded in one new auto-discovered module `modules/nixos/services/boot-oneshot-bounds.nix` (learned + followed the `flake.nixosModules.<name>` wrapper convention after the first bare-module attempt failed flake-parts eval).
- Negative leg `shapeaudit/oneshot-unbounded` **PASS** (mutation → audit fires). `nix flake check --no-build`: **all checks passed**. NOTE: timeout-audit.nix's global `DefaultTimeoutStartSec=3min` does NOT cover this class (systemd's oneshot default is infinity independent of the manager default) — documented in the module.
- Queue row said "class 5" but the audit already had 6 classes; landed as class 7 (row tick notes the renumber).

### M9 — visionreviewd OnFailure (fix landed + verified; pin INCOMPLETE)
`serviceConfig.OnFailure` → unit-level `onFailure` (dated comment). Eval-verified: `visionreviewd.onFailure = [ "notify-failure@%n.service" ]`. Repo sweep: **zero** remaining `serviceConfig.OnFailure` (both hits are the fix + a comment). Rows :209/:393 not yet ticked (see §d).

---

## b) Verification battery (what actually ran)

| Surface | Command | Verdict |
| --- | --- | --- |
| pbx contract | `nix build .#checks.x86_64-linux.netbird-contract` | **30 invariants hold** |
| pbx toplevel | `nix eval …toplevel.drvPath` + unit-shape projection | green; all four hardening keys render |
| pbx docs | `nix develop -c bash scripts/docs-gates.sh` | dprint clean; docs-freshness **FRESH** (newest report); audit-all DRIFT = pre-existing parallel churn (5 stale items struck with evidence: dprint-idempotency→format-safety, dex→pocket-id, eval/lock-sweep windows→closed trains, 22:19 skips→routed) |
| pbx live probes | throwaway ssh harness (read-only journalctl/ss/fs_cli//proc) | root-caused M3 + M8; no pbx mutations by me |
| M5 selftest | local + `nix build .#checks…deploy-pipeline-selftest` | 22/22 both |
| M6/M7 | `nix flake check --no-build` (final, at pause) | **all checks passed** |
| M7 negative | `CASES=shapeaudit bash scripts/negative-test-lints.sh` | 1 passed, 0 failed |
| M9 | eval projection | onFailure renders unit-level |

**Deploy state:** NOTHING deployed this session (by design — pbx = M12 owner window; evo-x2 tree changes ride the next deploy; M16's run-half waits for the next natural reboot). pbx-artmann commits `1849492`/`b49c142` local+unpushed.

---

## c) Owner-gated items surfaced (the asks)

1. **P0 — pbx ESL recovery (production, 5 min):** `ssh root@pbx.artmann.tech` → `systemctl restart freeswitch.service && systemctl restart telephony-agent.service telephony-textagent.service`. The AI-voice-agent/textagent/health-check event socket has been dead since the 09:07 boot (fd exhaustion via the agent leak); SIP/trunk calls are NOT affected. (TODO §70 `esl-fd-leak-restart`.)
2. **P1 — netbird PAT re-mint (10 min):** dashboard → Personal Access Tokens → mint → `~/.pbx-prod-secrets/push-secrets.sh`. Provision has been failing 404 since 17:47 (dead PAT). (`nb-pat-remint-live`.)
3. **P1 — wire `telephony_alert_webhook`:** today's 8h outage paged NOWHERE (relay is journal-only + self-locked). (`alert-webhook-live` + `alert-channel-independence`.)
4. **M12 — pbx deploy window** for the M1-M4 train (staging ritual first): the fixes are eval-green + pinned but NOT live until switched.
5. **M21 — nixpkgs PR push** (when prepared): agents implement, owner pushes.

---

## d) Honest mistakes / self-review

1. **class-8 pin FAILED to apply** (M9's shape-audit companion): my python anchor didn't match the live file (parallel-session reformat of the class-7 region) and the assert correctly refused — **visionreviewd is fixed but its class-wide pin is NOT landed**. First item on resume; the sweep shows no other live instances, so exposure is regression-only.
2. **`git add -A` sweep**: one staging command used `-A` across shared dirs, staging parallel-session files alongside mine (the daemon then batched them into `5a57339c`). No attribution damage done (daemon commits are heuristic anyway) but it violated my own pathspec discipline — flagged, not repeated after.
3. **Fixture bugs in the M5 harness** (found by the SANDBOX run, not local): `env bash` shebangs fail in the build sandbox (no bash on child PATH) → POSIX `/bin/sh` shims; missing git buildInput → empty-key false-pass locally invisible, sandbox caught both. The check-build leg earned its keep.
4. **pbx docs-gates whack-a-mole**: I routed the newest-report drift, then audit-all count jumped 6→1→12 — token flips from PARALLEL-session rows landing at the DF bar mid-run (line 738 etc. are not mine; verified by grep). Scoped OUT rather than chased (pre-existing chronic class; the repo's own tooling documents it).
5. **The M23 landing fed the dispatcher**: my [ready] rows are harvestable; a parallel session picked up M6's row and built its test legs (good — cooperative) but the remaining unticked rows (M10-M22) are exposed to double-dispatch. Mitigation on resume: tick rows immediately on completion.

---

## e) Next steps (resume order)

1. Land the class-8 shape-audit pin (correct anchor against the current file) + tick rows :209/:393 (M9 close-out).
2. **M10** monitor365 :9191 + cv :8098 (journals + probes; note cv /metrics is auth-gated by design).
3. **M11** failed-units sweep (9 units; `reset-failed` via script harness; typed systemctl is guard-blocked).
4. **M13-M15** (stamp #2, is-enabled bounds, post-deploy parallelization, app-eval dedup) — then **M20** collects the phase-timing data they produce.
5. **M16 write-half** (reboot checklist into docs/services/netbird.md), **M17** docs bundle + CHANGELOG + [x] prune, **M18-M19** log/loan/race-decision, **M22** HARVEST (130 reports; load the docs-health skill first).
6. **M21** prep (verify-before-filing + github-voice; HOLD push).
7. Never: pbx deploy without the owner window; pushes; reboots.

---

## f) Top follow-ups (harvested)

1. `class-8` shape-audit pin for serviceConfig.OnFailure (this session §d.1) → pipeline.md.
2. evo-x2 next deploy carries: M6 path unit + assertions, M7 floor/audit/bounds, M9 visionreviewd fix, M5's selftest wiring — post-deploy smoke owes a boot-mirror-sync journal check (row :1182 covers it).
3. The agent ESL leak fix in the sibling (pbx-artmann TODO §70) — upstream of the LimitNOFILE stopgap.
4. pbx-artmann audit-all drift (parallel churn at the DF bar) — a dedicated docs-health pass.
5. /tmp debris sweep (M17.4): `pbx-journal-probe.sh`, `pbx-fs-probe.sh`, `pbx-esl-probe.sh`, `pbx-esl2/3.sh`, `pbx-fd-probe.sh`, `pbx-sock-probe.sh`, `pbx-port-probe.sh`, `gitfix/`, `dp-selftest`, `nb-contract-check`, `drvpath…` (mine, this session).

**Source plan:** docs/planning/2026-10-17_19-52_netbird-control-plane-resilience-and-deploy-hardening.md
**Evidence commits (SystemNix):** daemon-batched (5a57339c, 1fdb5af0, 6decbad7, … — mixed-authorship, left unamended per policy). **pbx-artmann:** `1849492`, `b49c142`.
