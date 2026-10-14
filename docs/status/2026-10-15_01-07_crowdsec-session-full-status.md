# CrowdSec setup session — full status (what worked, what's stuck, what I'd do better)

**Date:** 2026-10-15 01:07 CEST · **Session scope:** owner said "set it up!" after the ratified CrowdSec study (`docs/planning/2026-10-14_20-25_crowdsec-nixos-study.md`) → implement Stage 1 end-to-end.
**Supersedes/extends:** `2026-10-15_00-31_crowdsec-stage1-implemented-deploy-storm-blocked.md` (same session, pre-close-out).

**One-line verdict:** everything code/doc-side is DONE and committed; the service is NOT live — the fix toplevel is committed but still unactivated (gen 891 runs the broken pre-fix config), deployment is gated by a real IO storm from the parallel session's build mission, and a NEW unknown surfaced in the last 10 minutes: the fix toplevel's build reports "1 dependency failed" (§d.4 — top open item).

---

## a) FULLY DONE ✅

1. **Study + decision groundwork** — CrowdSec+NixOS study with every external claim source-verified (pinned nixpkgs store tree read in full, `gh issue view` on all cited nixpkgs issues, raw upstream GeoMetrikks README, hub.crowdsec.net pages) → `docs/planning/2026-10-14_20-25_crowdsec-nixos-study.md`. Owner approved staged adoption.
2. **Ports registered** (`lib/ports.nix`, daemon commit c112fce0): `crowdsec-lapi = 8082`, `crowdsec-metrics = 6061`, both live-probe-verified free, comments carry the 8080=SigNoz and 6060-taken warnings.
3. **Module written** (`modules/nixos/services/crowdsec.nix`, c112fce0 + fix c41a21ad): LAPI `127.0.0.1:8082`, metrics 6061, acquisitions (sshd via journald + `/var/log/caddy/*.log` glob), LAN whitelist (RFC1918/loopback never alert — un-bannable household clients), `mkDnsGate` prepended via `lib.mkBefore` (eval-verified order: `crowdsec-wait-dns → crowdsec-machine-repair → crowdsec-setup → config test`), `CAP_DAC_READ_SEARCH` (0750 dir/0600 files caddy-log pattern, geometrikks precedent), MemoryMax 1G/High 768M (watermark-audit-compliant), startLimit burst/interval, integration registry entry (gatus `CrowdSec` check on `/metrics`, `monitored`, vHost layer "none"), unconditional catalog entry (ADR-008 inline-imports pattern).
4. **First-deploy bug root-caused + fixed** (c41a21ad): upstream nixpkgs module gap — `/var/lib/crowdsec` never tmpfiles-created (only `state/`, `confDir` are), materialized root:root → `machine add --auto` wrote the DB row but EACCES'd the credentials file → orphan machine → permanent `user already exist` start failure. Three-layer fix: tmpfiles `20-crowdsec-root` (d-entries re-chown existing dirs), `registerBouncer.enable = false` for stage 1 (its `StateDirectory = … crowdsec` re-owns the dir to a DynamicUser — latent re-breaker), `crowdsec-machine-repair` ExecStartPre (creds missing → `cscli machines delete <host> --ignore-missing`; flag verified against v1.8.1 `climachine/delete.go` raw source — no `--force` on delete, no prompt, nil-on-absent).
5. **Service enabled** in `platforms/nixos/system/configuration.nix` (7d4239c1-era sweep).
6. **Runbook** `docs/services/crowdsec.md`: unit topology, acquis, ops cheatsheet, Stage 2 owner steps (exact `cscli` + sops flow, fish_history rule), Stage 3 bouncer plan, gotchas (6060, hub mutable state, dnsblockd reachability, no-backup rationale).
7. **Eval gates green twice**: `nix flake check --no-build` all-pass before AND after the fix patch; standalone pre-deploy-check passed 98/11w/0f at 20:5x.
8. **Docs/harvest complete, both surfaces, no drift**: status report (00-31), TODO_LIST queue row (deploy-loop convention), `docs/todo/services.md` ([watch] live verification + [blocked:user] stage 2), `docs/todo/pipeline.md` ([ready] deploy-intent convention), `docs/todo/security.md` ([decision] 6060 pprof + adoption decision row marked decided with provenance), geometrikks runbook staleness fixed on sight. `check-todo-system.sh`: structure clean.

## b) PARTIALLY DONE ⏳

1. **Deployment/activation** — the ONLY thing between "configured" and "working": fix toplevel committed, but current system = gen 891 = PRE-fix toplevel (`6hd6lr16…`), crowdsec.service dead (start-limit hit), LAPI down. Blocked by: (a) sustained real IO storms (sdb 101-105%, PSI 19-80% over 30+ min of monitoring, `memory-emergency-guard tripped 4×/h` — freeze #5 class; my last three deploy attempts correctly refused, one §11 voided by a mid-run tree mutation from the parallel session), (b) a deploy-lock convoy with the parallel session's `/tmp/deploy-retry.sh` loops (now quiescent — no holders for 30 min, but PSI never dropped below 19%).
2. **Live functional verification** — never executed: LAPI has never completed a start; `cscli metrics`/acquis parsing/gatus green all pending activation. Queued as [watch], bundled with the existing lull-deploy row (services.md row 492).
3. **Fix toplevel BUILD verification** — `nix build …toplevel` (00:5x, pre-warming for a fast lull switch) reported **"1 dependency failed"**; my identification greps were killed before naming it (user called the report). Eval passes (`flake check --no-build` green), so this is a BUILD-graph issue (FOD/hash/sandbox class), not eval. UNRESOLVED and now the #1 next action.

## c) NOT STARTED 📋

1. Stage 2 — GeoMetrikks bouncer key (owner-interactive: `cscli bouncers add` + sops paste; my env-wiring half comes after) — queued [blocked:user].
2. Stage 3 — firewall bouncer (time-gated on ~1 week of alert review; decision already made in the study).
3. Upstream nixpkgs issue for the rootDir/machine-add gap (verify-before-filing gate first; locally mitigated).
4. `*:6060` pprof listener identification (queued [decision]; needs root-side `ss -ltnp`).
5. Deploy-intent convention implementation (queued [ready]; I only wrote the finding + ask).
6. Console enrollment / CAPI pull / hub auto-update flip-on (deliberately post-stabilization per runbook).

## d) TOTALLY FUCKED UP 💥

1. **Study premise error — "6060 free"**: I verified freedom against `lib/ports.nix` only and declared the upstream default metrics port free; the live box has an UNREGISTERED Go pprof listener on `*:6060` bound to ALL interfaces. Caught at implementation (the port-registry discipline saved the deploy), but the study's verification coverage was incomplete — live probe should have been in the study pass. Cost: metrics port moved to 6061, one study correction, one [decision] row.
2. **Fought the storm instead of reading it** — my first three deploy attempts each burned a ~10-min pre-deploy (eval-heavy) into a box already at 100% sdb; I was ADDING the load that refused me. The memory-emergency-guard signal (4×/h) came from MY OWN attempt logs. Should have gone passive after the FIRST refusal and diagnosed the source before retrying.
3. **`kill -0` cross-user false negative** — poll declared the deploy holder "gone" when the check actually returned EPERM; nearly raced the other session's deploy. The lock script's own /proc-fd scan was authoritative. (Root lesson recorded: cross-user liveness needs `[ -d /proc/$pid ]`, not kill -0.)
4. **Never pre-built the fix toplevel before the deploy war began** — the "1 dependency failed" build error surfaced only at 00:5x, AFTER ~90 minutes of deploy attempts that could never have succeeded even in a lull (the switch would have built then failed). If that failure is real, every deploy attempt tonight was doomed twice over. Cheap insurance skipped.
5. **Minor:** `DEPLOY_EXIT=$?` after `cmd | tail` captured tail's exit code twice (masked a non-zero deploy rc until I re-read logs); integration.port=metrics vs catalog.port=lapi asymmetry is deliberate but only implied, not stated in the module header.

## e) WHAT WE SHOULD IMPROVE 🔧

1. **Deploy under concurrency is unsolved**: two retry loops + pressure gate = guaranteed refusal spiral (each cycle's eval re-trips the gate), §11 voids on any mid-run commit, lock serializes attempts but not intent. Needs the queued convention (jitter/backoff/quiet-precondition/single-driver marker) — freeze-adjacent, not cosmetic.
2. **Pre-deploy §11 tree-mutation check should retry-once on mutation** instead of failing the whole deploy — with an auto-commit daemon + parallel sessions, mutation-during-check is COMMON, and re-running costs 10 min of the same IO that causes the pressure refusals.
3. **Premise-checks belong in studies**: the 6060 miss argues for a "live-probe every port/context claim" step in the study template (the 2026-10-08 rule already says this for owner questions — extend to study docs).
4. **The upstream nixpkgs crowdsec module is usable-with-care, not set-and-forget** — our local mitigations (gate, repair, tmpfiles) should be extracted into a documented "SystemNix upstream-hardening" section of the runbook so the next upstream bump re-audits them consciously.
5. **Agent-side IO citizenship**: my session's eval/build loops contributed hours of load tonight. A soft self-throttle (defer non-essential builds while io PSI > 40%) would make parallel sessions better neighbors.

## f) NEXT — up to 50 things (prioritized, crowdsec session scope first)

**Immediate (this service, blocking):**
1. Name + fix the "1 dependency failed" in the fix-toplevel build (background job killed mid-grep — re-run `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` and read the failing drv; candidates: crowdsec FOD hash/sandbox or a unit-wiring build step).
2. Deploy the fix toplevel in a genuine lull (bundled with services.md row 492's hot-db CAP_DAC_OVERRIDE fix + no-heavy-gate removal — ONE switch, one storm window).
3. Verify anchor discipline post-switch: `readlink /run/current-system` == latest `system-N-link`, then `nix run .#pre-reboot-check`.
4. Verify crowdsec.service active; second-boot no-op of machine-repair.
5. Verify LAPI `127.0.0.1:8082` + metrics `127.0.0.1:6061` listening.
6. `cscli metrics` — confirm BOTH acquis sources parsing (sshd journalctl + caddy files), no parse-error pileup.
7. Confirm hub collections installed (`cscli hub list`: linux + caddy trees present).
8. Gatus `CrowdSec` check green (6061 /metrics 200).
9. Confirm the tmpfiles `20-crowdsec-root` chown healed `/var/lib/crowdsec` ownership (root:root → crowdsec:crowdsec) — live `ls -la`.
10. Confirm `crowdsec-firewall-bouncer-register` unit is GONE from the activated tree (registerBouncer=false took effect).
11. Simulate one restart (`systemctl restart crowdsec`-equivalent in a deploy or lull) to prove idempotent setup (hub update + creds-file short-circuit).
12. Close the [watch] services.md row with the verification narrative; update the runbook Status line to LIVE.
13. Watch one full boot-or-restart cycle for the DNS gate budget (crowdsec-wait-dns must not eat the full 180s when dnsblockd is healthy).
14. Check hub-update reachability behind dnsblockd (www.crowdsec.net / hub-data.crowdsec.net GeoLite2 fetches already succeeded once at 22:03 — re-confirm no HaGeZi block page garbage in journal on later runs).

**Stage 2 (GeoMetrikks unlock):**
15. Owner: `sudo -u crowdsec cscli bouncers add geometrikks` (key prints once).
16. Owner: sops-paste `geometrikks_crowdsec_lapi_url` + `geometrikks_crowdsec_bouncer_api_key` into `platforms/nixos/secrets/geometrikks.yaml`.
17. Agent: sops template → EnvironmentFile on geometrikks.service (`CROWDSEC_LAPI_URL`, `CROWDSEC_BOUNCER_API_KEY`).
18. Verify `geo.home.lan/settings/status` flips CrowdSec = Enabled; Banned-IPs map renders.
19. Add the sops keys to the sops-key-audit wiring for geometrikks.yaml (audit must know the new keys exist).
20. gatus-coverage: confirm geometrikks' new env doesn't trip port-registry-audit (8082 literal inside EnvironmentFile content is NOT scanned — verify the audit agrees).

**Stage 3 (enforcement, ~1 week out):**
21. Review a week of `cscli alerts list` for LAN false positives.
22. Decide ban scope/durations for the homelab (default 4h profiles vs custom).
23. Enable `services.crowdsec-firewall-bouncer` + re-enable `registerBouncer` deliberately; iptables mode (no nftables yet).
24. Verify the bouncer's iptables chains + one controlled ban → unban round-trip.
25. Re-audit CAP_NET_RAW grant + firewall.service ordering at activation.

**Findings from tonight:**
26. Identify the `*:6060` Go pprof listener (root-side `ss -ltnp`); bind loopback or kill; register port if it stays (security.md [decision] row).
27. Implement the deploy-intent convention (pipeline.md [ready] row: jitter, pre-check PSI precondition, driver marker, AGENTS.md doc).
28. File the upstream nixpkgs crowdsec issue (rootDir tmpfiles gap + non-idempotent machine add; #520206 family) — after verify-before-filing gate, with our working fix as the proposal.
29. Consider `hub.updateOnStart` opt-out upstream proposal (their PR #521985) once identified live.
30. Add "live-probe every port claim" to the study template (from the 6060 miss).

**Hygiene/robustness (noticed during the session):**
31. Cross-user process-liveness: standardize `[ -d /proc/$pid ]` in scripts that poll other users' deploys (kill -0 EPERM trap).
32. The `cscli` wrapper's sudo dependency — document in the runbook that `security.sudo.enable` must stay true (the wrapper aborts without it).
33. Consider pinning `hub.branch` (default `master` = moving target) once the collections stabilize.
34. Decide `autoUpdateService` flip-on after a stable week (currently off; hub updates only at agent start).
35. SigNoz rule for crowdsec (e.g. `crowdsec_acquis_failed`/parse-error rate or agent-down via system-health) — gatus covers liveness only.
36. textfile-collector angle: expose crowdsec decision count as a node metric if ops wants it on the health dashboard.
37. Runbook: add the SQLite WAL location + "decisions are ephemeral, no backup by design" rationale (drafted, finalize post-live).
38. Runbook: document the orphan-machine failure signature + its self-repair for the next agent that sees it.
39. Review `protectProc=invisible` vs the repair script's needs (it only touches its own DB — fine, but re-verify once live).
40. Memory: watch MemoryMax 1G under real caddy-log churn; adjust with watermark rule (High ≥ 50%).

**Repo-wide (touched-adjacent, non-blocking):**
41. The other session's browser-history/crm/paperless work owns its own rows — do NOT co-verify (shared-tree discipline; flag only).
42. The 22:19 first-activation deployed via the OTHER session's loop — confirm their deploy log shows gen 891 anchor discipline held (they may have the same unanchored-exit-14 exposure).
43. After the nftables-migration decision lands: flip bouncer mode + re-verify rulesets (queued interplay in security.md).
44. AGENTS.md: if CrowdSec becomes permanent, add the runbook pointer line to the platform constraints (ports + "6060 taken" warning already in ports.nix).
45. Study doc: append a "deployment outcome" addendum once live (closes the loop the study opened).
46. CHANGELOG entry when stage 1 goes live (docs-health pass prunes the [x] decision row).
47. Consider a VM test for the crowdsec module (co-imports: integration + catalog; assert unit order + acquis files) — cheap regression guard for nixpkgs bumps.
48. Upstream bump drill: when nixpkgs moves crowdsec past 1.8.1, re-read the module diff against our three local mitigations (#526506 class breakage).
49. Check whether dnsblockd whitelist needs `www.crowdsec.net`/`hub-data.crowdsec.net` entries PROACTIVELY (HaGeZi-ultimate precedent: ipify) instead of waiting for a block.
50. Close-out my two monitor background shells cleanly (061 already completed; no strays left — verified).

## g) Questions I can NOT answer myself

1. **`*:6060`** — is the Go pprof listener bound to all interfaces something YOU started/know (a dev server, a tool of yours), or is it unknown to you too? (I can't read root-owned fds; one root `ss -ltnp` names it instantly — and the answer decides "tame it" vs "investigate it".)
2. **LAN whitelist policy for stage 3**: whitelist ALL of RFC1918 (current config — no household device can ever be banned) or only `192.168.1.0/24`, so VPN/IoT/other-subnet clients remain bannable? This is owner policy, not derivable from the repo.
3. **Deploy ownership tonight**: should MY session keep driving the lull deploy for the crowdsec fix (bundled with the hot-db fix in row 492), or do you want the other session's loop to own the switch while I only verify? (Both deploying the same tree is safe but doubles the storm windows we burn.)

— Waiting for instructions.
