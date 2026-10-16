# CrowdSec Wave Session 2 — #1943 Patch-Apply LIVE, Observability Battery, Caddy-Log Mode Root Cause

**Session:** 2026-10-16 ~07:00–08:30 + reconciliation 16:20 (crush glm-5.3-flash)
**Trigger:** owner ask "Can we patch apply our #1943 PR via nix?" + "DO THE WHOLE TODO LIST"
**Verdict:** The hub PR IS live on evo-x2 via a nix-managed taint override (source-verified mechanism, live-proven parse). Geo stage-2 battery fully green. A second root cause under the caddy acquis fix was found (file mode 0600), fixed in-tree, deploy owed (a deploy carrying it started 16:19). Three own design errors made and corrected this session; all documented below.

---

## §a FULLY DONE

1. **#1943 patch-apply via nix — LIVE AND PROVEN.** Route: crowdsec.nix `pr1943Parser` (`pkgs.fetchurl` @ PR head `99985ff6`, hash-pinned, byte-verified vs the hubtest clone) re-pointed over the hub item's install symlink by an ExecStartPre (`mkAfter`, after upstream setup) + `restartTriggers` on crowdsec.service. Mechanism source-verified at v1.8.1 (pkg/cwhub sync.go `setVersionState`/`newLocalItem`, pkg/parser unix_parser.go `NewParsers` loads each item's `State.LocalPath`; engine stage-loop breaks on first `onsuccess: next_stage` match). LIVE PROOF: setup logs `parsers:crowdsecurity/sshd-success-logs - not downloading local item` (cscli now classifies it local — hub never touches it), and `cs_node_hits_ok_total{name="crowdsecurity/sshd-success-logs"} = 3` on real Accepted logins since the 08:14 restart (impossible under the old `program == 'sshd'` filter). Removal condition documented on all surfaces: delete the override when PR #1943 merges.
2. **T7 bouncer battery — GREEN ×3.** `crowdsec-bouncer-register` converged at 07:10:50, 08:05:01 AND 08:14:29 (two activations 9 min apart = idempotency proven), `cscli bouncers list` shows `geometrikks` valid/streaming (python-httpx2, 993+ stream pulls, fresh last-pull every 15 s).
3. **T8 geo battery — GREEN, all legs.** 36500-day retention verified on ALL 11 TimescaleDB tables (06:26:34 startup block); OIDC-only login live-proven by a rejected-password probe (HTTP 401 "Password login is not enabled" + journal `login_failed … provider=password reason=password_login_disabled`); CrowdSec client configured (`url=127.0.0.1:8082`); a real `login_success provider=oidc` at 06:43:34.
4. **T14 SigNoz coverage — in-tree, eval-green.** `crowdsec` scrape job (:6061); "CrowdSec Agent Down" rule (unit-state-gauge pattern — the anti-phantom class); "CrowdSec Parse Pipeline Errors (s00-raw)" rule **calibrated against live data** (s00-raw 714/714 OK by design; s01 ko ≈97.6% is noise behaving correctly — the retracted-alarm lesson encoded as a threshold). Gatus CrowdSec check gained the `[BODY] == pat(*cs_parser_hits_total*)` health leg.
5. **T15 gatus/register liveness — IMPLEMENTED (was decide-or-non-goal).** The counts collector now emits `crowdsec_bouncer_geometrikks_registered` (LAPI-observed, revoked-aware) + SigNoz rule "CrowdSec Bouncer Not Registered" (below 1) — the plan's oneshot-result-based shape.
6. **T20 VM-test ask — `checks.crowdsec-render`** (pure-eval render pin, geometrikks-caps pattern): 17 assertions covering unit order, acquis contents, sops EnvironmentFile, graceful-skip branch, ExecStartPre override, restartTriggers, counts unit/timer, fail-closed emission, gatus health leg, caddy mode 0640, group-read timer. Green (`rc=0`).
7. **T22 docs pass — FEATURES.md CrowdSec row added** + Updated-chain entry; runbook (crowdsec.md) acquis caveat, hub-override gotcha + tmpfiles-platform-trap, stage-2/3 sections current.
8. **Caddy acquis root cause ESCALATED AND FIXED (second layer).** After the group fix deployed, the glob matched ("Adding file … to datasources" ×61) but every tail errored: `open /var/log/caddy/access-*.log: permission denied`. Files are **0600 caddy:caddy — no group bits at all**, so the group fix can never open them. Fix in-tree (dc09d036): (a) caddy.nix overrides ALL vhost logFormats with `mode 0640` (docs-verified option; restart-not-reload caveat documented), (b) 5-min `crowdsec-caddy-logs-readable` timer re-asserts group-read on existing files until they roll over, (c) counts collector `chmod 0644` before mv (see §d3).
9. **Pre-deploy gate re-run on the current tree: 100 passed / 9 warnings / 0 failed** — the earlier `signoz_logs_pipeline_stale` phantom leg cleared exactly as predicted (storm artifact: ClickHouse 58 s query timeouts).
10. **Deploy-anchor discipline held.** Caught the 07:10 manual `switch-to-configuration test` (unanchored: current-system ≠ profile) and flagged it; the 07:32 parallel deploy re-anchored properly (gen 908 → 910, current == profile verified).

## §b PARTIALLY DONE

1. **The mode-0640/timer/collector-perms/bouncer-gauge batch** — committed (dc09d036), eval+render green, but NOT in any deployed generation (gen 910 predates it). A deploy carrying it started 16:19:24 and is mid-flight at report time.
2. **14.4 scrape verify** (crowdsec job series landing in ClickHouse; rule provisioning 43→44) — blocked on that deploy's switch + provisioner run.
3. **CrowdSec counts prom visibility** — the collector runs healthy (08:22:29, 167 ms) but its 0600 file is unreadable by node-exporter until the 0644 fix deploys.
4. **sshd-success-logs freshness watch** — override proven live, but hub-update clobber behavior across future hub version bumps relies on the local-item classification holding; the removal-on-merge row is the watch.

## §c NOT STARTED

- GeoMetrikks rotated-log backfill timer (T18 — approved in principle, next geo wave).
- Port 6060 pprof firewall drop (fix staged in docs, next wave).
- sops orphan key rotation (deferred by design).
- Stage-3 firewall-bouncer enablement (7-day clean-alert window opened 2026-10-16; owner-gated).
- PR #1943 upstream merge tracking (watch row only).
- VM-boot-level test for crowdsec (render pin covers the plan's assertions; a full boot test with DNS/hub mocking was not attempted).
- TODO-prune of the retracted/corrected sshd rows to CHANGELOG (docs-health pass owns it).

## §d TOTALLY FUCKED UP (own errors this session, each caught and corrected)

1. **The tmpfiles L+ override design was inert.** I wired the patch-apply as a tmpfiles rule (mirroring the nixpkgs module's own pattern) without knowing that **switch-to-configuration on this NixOS never runs systemd-tmpfiles** (0 invocations in the switch binary; the deploy script heals /run entries only). The first deploy carrying it changed nothing at runtime — caught by hash-verifying the install symlink (local_hash ≠ my file's sha256). Cost: one deploy cycle + a mid-session mechanism redesign to ExecStartPre. The platform trap is now documented in the runbook gotcha and the module comment.
2. **Nix nesting collision** — `systemd.services.crowdsec.serviceConfig.ExecStartPre = …` alongside the existing `serviceConfig = lib.mkMerge [...]` in the same module = "attribute already defined" eval failure. Basic mistake; fixed by moving both the ExecStartPre and restartTriggers into the unit block.
3. **The counts collector shipped with `mktemp`-0600 output.** node-exporter (its own user — I verified its user only during the battery) cannot read a 0600 crowdsec file, so the first live run exported NOTHING into node metrics. The sibling collectors all ship 0644. Worse: `scripts/audit-textfile-tmp.sh` exists and did not flag it — a lint gap (§e).
4. **Raced the deploy lock once** — launched `nix run .#deploy` without checking `/tmp/.systemnix-deploy.lock` first; the guard bounced it cleanly (exit 13). No harm, pure sloppiness; the parallel session deploys constantly and has carried my committed content every time since 07:25.
5. **PSI watcher shipped broken** — the python float-parse inside the loop truncated its input and spam-errored for minutes before I killed it. Never rebuilt a working watcher; lull detection fell back to manual polling (which worked).
6. **Three parse-guard trips** (typed `systemctl`, typed `ssh`, and a python one-liner with braces the guard mis-parsed) — each cost a cycle; the ssh probe needed the sanctioned throwaway-harness pattern.
7. **Mis-read the rendered config once** — reported `acquisition_path:` empty from a line-grep; it was a multi-line YAML value. Corrected by reading the full file. (Reported as a false alarm in-session, corrected before any action.)

## §e WHAT WE SHOULD IMPROVE

1. **Deploy-content diff**: a helper that compares the deployed generation's module content vs the working tree ("is a deploy a no-op?") — this session's parallel-session deploys carried my content 3× and I nearly re-deployed identical content twice.
2. **Deploy-intent enforcement (T25 tooling)**: the convention exists, but neither session's deploys wrote/checked the intent file consistently — unenforced conventions decay.
3. **audit-textfile-tmp.sh gap**: extend it to catch the mktemp-0600-into-textfile-dir class (and the missing chmod) so the §d3 mistake is structurally impossible.
4. **Storm-aware post-check baseline**: the 07:32 deploy's post-check FAILED 7 legs (forgejo 165 % CPU, node-exporter 416 journal lines/min) under storm load; `STORM-SUSPECT: 0` says the detector didn't classify them — tune or annotate.
5. **Memory-throttle churn**: project-discovery-daemon hit its MemoryHigh watermark 16,982× and signoz-collector 1,342× (warning-level, from the deploy log §17 sweep) — candidates for watermark review.
6. **Every live-verified fix gets a render pin same-session** — the crowdsec-render check caught two of my own regressions before deploy; extending that pattern to the caddy mode override (done) should be the default.
7. **The crowdsec journal accumulates ~90+ error lines per restart while any 0600 log file exists** — the mode fix + timer silences it; consider a gatus/SigNoz "acquisition tail errors" counter so this class pages instead of lurking.

## §f NEXT — up to 50 things to get done (grouped, highest impact first)

**This wave's tail (blocked only on the running deploy):**
1. Verify gen ≥911 carries: `mode 0640` in the rendered Caddyfile (75 blocks), crowdsec-caddy-logs-readable unit+timer, collector script with chmod 0644.
2. Battery: first file-source hits in :6061 metrics (cs_parser_hits_total with caddy source) + one synthetic request parsed.
3. Battery: counts prom now 0644 and visible in node-exporter /metrics (crowdsec_decisions_active / crowdsec_alerts_24h / crowdsec_bouncer_geometrikks_registered / scrape_errors 0).
4. Verify SigNoz provisioner converged 44 rules (2 crowdsec + bouncer rule) with no route-policy orphans.
5. Verify the crowdsec scrape job produces series in ClickHouse (query API `up{service_name=…}`-class check or time_series presence).
6. Confirm the gatus CrowdSec check stays green with the new pat() health leg (config-parse + runtime).
7. Update rows: services.md acquis row (0600 layer), monitoring.md 14.4 close, FEATURES row deploy state — on BOTH surfaces per queue discipline.
8. Post-deploy §17/§19 sweeps (memory throttle + storage-history freshness) — the deploy script runs them; read the verdict.
9. Close the [watch] stage-2 row (bouncer + geo UI unlock) once the owner flips `geo.home.lan/settings/status` → Enabled (owner UI step, runbook step 4).

**Direct follow-ups (this session's findings):**
10. Extend `audit-textfile-tmp.sh` for the mktemp-0600 class (§e3).
11. Deploy-content-diff helper ("would this deploy change anything?") (§e1).
12. Deploy-intent tooling build + wire into the deploy app (queued T25 — now with live evidence of non-compliance).
13. Storm-aware classification for post-deploy-check service-sanity legs (§e4).
14. MemoryHigh watermark review: project-discovery-daemon (16,982 hits), signoz-collector (1,342) (§e5).
15. Acquisition tail-error counter → SigNoz rule (§e7).
16. sshd-success-logs: hub-merge watch — when crowdsecurity/hub#1943 merges, remove `pr1943Parser` + the ExecStartPre + the render-pin cases + runbook caveat (single commit, all surfaces listed).
17. Self-retire logic (or explicit keep decision) for the group-read timer once every live log is 0640.
18. geo.home.lan Enabled flip (owner) → then the Security-page render check (T7 leg 3).

**Queued items already on the books (unchanged, cross-referenced):**
19. GeoMetrikks rotated-log backfill timer (T18; next geo wave).
20. 6060 pprof firewall drop (staged fix; next wave).
21. sops orphan key rotation (next natural rotation).
22. Stage-3 firewall-bouncer decision after the 7-day window (opened 2026-10-16).
23. TODO-prune of retracted/corrected sshd rows → CHANGELOG (docs-health pass).
24. VM-boot crowdsec test (beyond the render pin) — decide if worth the DNS/hub mock complexity.
25. Forgejo GitHub-outage fire drill (queued).
26. RAG over the forgejo mirror corpus (queued).
27. Two-way GitHub↔Forgejo issue sync (queued).
28. memcg OOM textfile collector (queued).
29. nvme-health-monitor module default by-id flip (queued).
30. SigNoz dashboards inventory (queued).
31. browser-history render-p99 threshold calibration after ~1 week of series (queued).
32. Deploy-anchor post-check: fold the "test-activation class" into pre/post-deploy checks (this session's §a10 finding is manual-only today).

**Watch (no action until trigger):**
33. hub update behavior across the next real hub version bump (local-item classification must hold).
34. cdn-hub TLS flap recurrence through the whitelist (fatality decision revisit trigger).
35. PrivateUsers/cap drop candidate once the group fix is proven in /metrics.
36. PR #535319 (nixpkgs crowdsec module refactor) — re-audit the four local mitigations when it lands.
37. nixpkgs crowdsec >1.8.1 bump drill (runbook §Bump).
38. The retracted parse-alarm class: any new "100 %-ko" alarm must be checked node-level first (runbook doctrine).

## §g QUESTIONS (cannot answer myself)

1. **Deploy ownership:** the parallel session has been driving deploys all day (07:10 test-activation, 07:25, 07:44-fail, 07:57, 08:09, 08:36, now 16:19) and each one carried my committed content. Do you want me to keep queueing behind it (verify-and-skip when content matches), or take the deploy lead myself on the next lock-free lull — and should unanchored manual test-activations be formally off-limits (the 07:10 one rebooted-revert-risked the wave)?
2. **Stage-3 timing:** the 7-day clean-alert window opened 2026-10-16. When it closes clean (~2026-10-23), do you want the firewall-bouncer enforcement flip prepared as a ready row (with the LAN-false-positive review gate), or explicitly deferred until you ask?
3. **Override patience:** if upstream sits on crowdsecurity/hub#1943 for weeks, do you want the local override kept indefinitely (it is restart-safe and hub-update-safe as deployed), or should I set a review date after which we discuss alternatives (e.g. nudging the PR, or a follow-up hub PR with the fixtures)?
