# Status Report — CrowdSec verification, stage-2 declarative, GeoMetrikks OAuth/retention, sshd retraction

**Date:** 2026-10-16 04:16 CEST
**Session scope:** one continuous session, ~00:45–04:16. Owner prompts: CrowdSec status → domain/LAPI/WebUI questions → geometrikks-integration status → "make stage 2 nix managed" → three geo asks (OAuth-only / infinite retention / "Fjord green") → two WHY questions (geo caddy gaps, sshd parse-ko). A parallel session ran the whole time (PBX→geometrikks work: `docs/status/2026-10-16_02-38_pbx-traffic-into-geometrikks.md`, queue row `docs/todo/services.md` [decision]; geo restarted 3× at 03:09–03:12 from their loop — no tree collisions occurred; daemon-race rules followed, land-on-top, no amends).

**Live tree state at writing:** HEAD ~`668fc09c` + uncommitted docs; `nix flake check --no-build` exit 0 (run twice this session, after each nix change batch); nothing deployed — all landings below ride the next switch.

---

## a) FULLY DONE (evidence-anchored)

1. **CrowdSec stage-1 live verification battery executed and CLOSED** — the `[watch]` row from `docs/status/2026-10-15_04-51` is resolved: `crowdsec-prereq` fix IS live (runs per-start, DNS gate ~1 s), machine added + creds written 05:47 Oct 15, service ACTIVE since 00:54:55 Oct 16 (PID 1607147 verified via /proc), LAPI 127.0.0.1:8082 + metrics 127.0.0.1:6061 listening (`ss -ltn`), heartbeats 200/min. Both surfaces closed: `docs/todo/services.md` + `TODO_LIST.md:1331`.
2. **CrowdSec caddy-acquisition root cause + queue row** — `PrivateUsers=true` (rendered unit, live-read) puts the engine in a user namespace; caps held inside a userns are inert for host inodes, so the ambient `CAP_DAC_READ_SEARCH` added for `/var/log/caddy` (0750 caddy:caddy) grants nothing → file acquisition globs ZERO files ("No matching files" at every start, zero file-source hits in /metrics). CapEff=0x4 confirmed set AND confirmed useless — mechanism, not guesswork. Queued `[ready]` with fix (crowdsec → caddy group; auxiliary gids map through the userns). Module comment (was: "group membership is NOT enough, the ambient capability is what grants the read") CORRECTED — the geometrikks lesson doesn't transfer (that unit has no PrivateUsers).
3. **Hub-update TLS outage diagnosed + queued** — `cscli hub update` failed twice against cdn-hub.crowdsec.net ("remote error: tls: internal error", 22:37 + 23:30 Oct 15), the setup leg treats that as start-FATAL → **crowdsec down ~2h18m** until the 00:54 switch whose download succeeded (block is intermittent, dnsblockd-interception class). `[ready]` row: whitelist cdn-hub/hub-data in `platforms/common/dns-blocklists.nix` + decision whether hub-update failure may keep the engine offline at all. Runbook gotchas added.
4. **CrowdSec stage 2 made DECLARATIVE (owner: "make it nix managed")** — the owner-interactive `cscli bouncers add` print-once flow is gone:
   - Key `geometrikks_crowdsec_bouncer_api_key` machine-generated into sops via throwaway 0700 script; value never in any typed command, history, repo surface, or journal (sops diff plaintext-leak-checked before commit).
   - `crowdsec-bouncer-register.service` in `modules/nixos/services/crowdsec.nix`: oneshot after crowdsec + before geometrikks, User/Group=crowdsec, repairConfig sqlite access (pattern live-proven by the prereq repair leg), delete+add per boot = converges the LAPI DB to the sops value (rotation-safe, same-key re-register keeps sessions valid), graceful-skip while key absent, `--key` stdout echo silenced (key-echo verified in `clibouncer/add.go` v1.8.1).
   - Flags verified against crowdsec v1.8.1 SOURCE (`clibouncer/{add,delete}.go`), not docs.
   - Two eval audits caught hazards before they shipped: sops-key-audit (missing key → created it) + dynamic-user owner audit (template owner=crowdsec rejected → root:root 0400, which works because systemd's MANAGER reads EnvironmentFile and injects the var — the engine process never opens the file).
   - Gates: `nix flake check --no-build` green; rendered unit verified by eval (`systemd.units."crowdsec-bouncer-register.service".text`); script derivation built (forces shellcheck) and content reviewed.
   - Consumer env wired: `geometrikks-env` template += `CROWDSEC_LAPI_URL` + `CROWDSEC_BOUNCER_API_KEY`. Runbook §Stage 2 rewritten DECLARATIVE. Queue: `[blocked:user]` row → `[x] OBSOLETE` + `[watch]` post-deploy battery, both surfaces.
5. **GeoMetrikks OAuth-only (owner ask)** — `APP_ADMIN_PASSWORD` removed from the env template (+ `geometrikks_admin_password` undeclared). Verified in upstream v0.19.0 source (`server/auth.py` + `config/settings.py`): password login is gated off exactly when admin_password is unset AND OIDC configured (`password_login_disabled, reason="APP_ADMIN_PASSWORD unset, OIDC enabled"`). `APP_AUTH_DISABLED` deliberately NOT used — that flag disables ALL auth (proxy-fronted mode), which is not what was asked. OIDC completeness verified live (oidc.env bridge writes issuer/client/secret; file fresh). Flake check green.
6. **GeoMetrikks retention = 100 years (owner ask)** — `ANALYTICS_{RAW,DEBUG,HOURLY}_RETENTION_DAYS=36500` in the env template (env-prefix + semantics verified in settings.py; daily tier already permanent upstream; raw floor is 4, we're far above).
7. **"Fjord green" honesty check (owner ask)** — upstream has NO such theme: accents are `teal` (default) / `green` / `copper` (`resources/lib/accent.ts`), themes are system/light/dark, and the accent is a per-BROWSER localStorage preference with no server-side knob in v0.19.0. Reported instead of fabricating a config key.
8. **sshd parse-ko RETRACTION + real finding** — my earlier "100% parse-ko, engine blind" claim was WRONG and is now fully retracted on all surfaces (see §d). The retraction deep-dive produced a REAL bug: hub parser `sshd-success-logs` filters `evt.Parsed.program == 'sshd'` while OpenSSH ≥9.8 logs via `sshd-session` (the sibling `sshd-logs.yaml` WAS updated upstream — this one was missed) → our 182 accepted-publickey logins go unparsed. Queued `[ready]`. Also documented: the journalctl datasource runs plain `journalctl --follow -n 0` (no backfill — attack lines landing during restart windows are never analyzed; v1.8.1 `run.go::getCommandArgs`).
9. **Geo caddy-ingestion question answered with evidence** — LOGPARSER_LOG_PATHS enumerates per-vhost files matching the nixpkgs caddy log derivation; **76 listed = 76 streaming, zero open failures** (diff computed live). The "not ALL logs" feeling = (a) rotated `*.log.gz` never backfilled (documented upstream gap; `import-logs` exists), (b) 374 format-sniff warnings = 60 s validation window on quiet vhosts, cosmetic, recovers on the next real request line, (c) pre-geo history. Runbook gotchas updated (format-sniff note + Banned-IPs gotcha refreshed to the declarative stage-2 reality).
10. **Multi-agent discipline held** — parallel session active throughout; content-pinned before every edit; one mid-edit race on `docs/todo/services.md` + two on `TODO_LIST.md` detected and re-read; daemon sweeps verified via `git show --stat` before proceeding (my crowdsec.nix + sops file rode `66bee4db`/`668fc09c` mixed with parallel-session files — landed on top, no amend, per the daemon-race policy).

## b) PARTIALLY DONE

1. **Stage-2 declarative registration — landed, NOT live.** Tree + sops key + gates complete; the RUNNING system still has no bouncer registered (unit not activated). Remains: one deploy, then the `[watch]` battery (converge log line, `cscli bouncers list`, geo UI Enabled flip by owner, second-boot no-op). Blocker: deploy discipline (PSI/deploy-ownership), not work. Effort: S.
2. **Geo OAuth-only + retention — landed, NOT live.** Same deploy rides the battery: `password_login_disabled` journal line, OIDC login still works, `ANALYTICS_*` in rendered unit, TimescaleDB policies actually show 36500. Blocker: same. Effort: S.
3. **CrowdSec detection coverage — green but partial.** sshd leg healthy (after retraction); caddy leg DARK (queued fix); hub updates intermittently TLS-blocked (queued whitelist + policy decision); sshd-success-logs parser dead on this host (queued). Stage 1's headline promise (HTTP-scenario coverage of caddy logs) is NOT yet real. Effort: M total.
4. **Report self-harvest — mostly done in-session, 3 landings pending.** New §f items land right after this file (CHANGELOG row, catalog-comment staleness fix; the rest reference existing queue rows). Explicitly noted per-item in §f.
5. **Theme ask — answered, not implemented (by design).** No server-side accent knob exists; needs owner decision (see §g Q2) before any code.

## c) NOT STARTED (noticed this session, no work yet)

1. **Caddy acquis fix implementation** (crowdsec → caddy group) — queued `[ready]`, not implemented; module comment already corrected so nobody builds on the wrong claim.
2. **sshd-success-logs fix** — local declarative override vs upstream hub PR — route undecided (§g Q3).
3. **dnsblockd whitelist for cdn-hub/hub-data + hub-update fatality policy** — queued; includes the embedded decision (content-filter flap must not take detection offline).
4. **Upstream nixpkgs crowdsec-module issue** (rootDir tmpfiles gap, PrivateUsers×ambient-cap trap, non-idempotent machine add) — carried since 2026-10-15 (#520206/#526506 family); needs verify-before-filing gate.
5. **CrowdSec stage 3 (firewall bouncer)** — queued; deliberately gated on a week of alert review; also depends on detection coverage being real (§b.3).
6. **Geometrikks ban/unban machine creds** (`CROWDSEC_MACHINE_ID/_PASSWORD`) — stage-3 follow-up, queued.
7. **VM test for the crowdsec module** (unit order + acquis assertions) — queued since the stage-1 report.
8. **SigNoz rule + textfile collector for crowdsec** (agent-down, decisions count) — queued from the stage-1 report.
9. **`geometrikks_admin_password` orphan cleanup in sops** — undeclared key still sits in the encrypted file (harmless; audit passes both directions); needs a `sops --unset` pass at next rotation.
10. **Upstream default-accent option for geometrikks** — would make the owner's "Fjord green" ask real; needs §g Q2 first.
11. **MaxMind/CARTO keys for geo** — pre-existing `[blocked:user]` row; map stays degraded until the owner pastes keys (ingestion itself runs).
12. **6060 pprof listener taming** — pre-existing `[decision]`, untouched this session (crowdsec moved to 6061 to avoid it).

## d) TOTALLY FUCKED UP (radical honesty — the most valuable section)

1. **I shipped a false "engine is blind" alarm across three doc surfaces — and my "correction" made it worse before it got better.** Sequence: (1) read the AGGREGATE `cs_parser_hits_ko_total 189/189` and concluded "sshd parses NOTHING", (2) queued a `[ready]` row with that premise, (3) "corrected" the stage-1 DONE row text to say "parsing is 0% (all lines ko)" — encoding the error DEEPER, (4) wrote a runbook data-sources note claiming the leg was dead. Reality: node-level `cs_node_hits_ok_total` — IN THE SAME SCRAPE I already had on disk — showed syslog-logs parsing 189/189 OK; every line was session/pam/accepted-publickey noise that no parser should match, and there were ZERO attack lines in the process window (counted live: 43×4 noise patterns). Root cause: I verified at the coarsest metric grain and stopped; the queue-rule "spot-verify config claims at queueing time" exists for exactly this and I applied it to the caddy row but NOT the sshd row. Cost: ~1.5 h of wrong claims across `docs/todo/services.md`, `TODO_LIST.md`, and the runbook; the owner's follow-up question ("why do sshd journal lines fail to parse?") was the only thing that forced the deep-dive. Detection lesson: **node-level metrics before stage-level conclusions; re-verify the previous conclusion before writing its "correction"** — a correction that restates the old error is a second error.
2. **Chat-level wrong claims along the way** — "sshd journal source healthy (189 parse hits)" in an interim answer, and "constant SSH probes" earlier (unverified; actually the LAN box sees almost no attack traffic in the current window). Both superseded by the retraction, but they shipped first.
3. **The hub-update TLS flap silently took detection offline for 2h18m and NOTHING paged.** Gatus checks the metrics endpoint (engine alive), not "did the engine START" — the service was failed/in start-failure while gatus stayed... actually gatus DID see metrics down during the window (alert exists: "CrowdSec metrics down — engine may be dead"), so monitoring said red; the GAP is that a content-filter flap can fail a service at all (fatal hub update in ExecStartPre). Queued as a policy decision — not yet fixed.
4. **Nothing from this session is deployed.** All three landings (stage-2 declarative, geo OAuth-only, geo retention) plus the two queued acquis fixes wait on one switch. The RUNNING system still: has no bouncer, password-auth enabled, 180-day retention, dead caddy acquis. Not forgotten — explicitly deploy-gated — but "landed" ≠ "live" until then.

## e) WHAT WE SHOULD IMPROVE

1. **Verify at the finest metric grain.** CrowdSec /metrics carries per-node ok/ko; aggregate `parser_hits` cannot distinguish "parser broken" from "input is legitimately unparseable". Add to the verification habit (and the runbook now documents the node-level read). Generalizes: any prometheus-enabled check — read the most granular counter before claiming failure.
2. **Retraction hygiene: a correction must RE-VERIFY, not restate.** My 02:4x "correction" of the DONE row propagated the same wrong claim with new authority. Rule going forward: before writing a correction, re-derive the fact from the live source; name every surface that carried the wrong claim and fix all of them in the same pass (I needed two passes).
3. **Queue premise-check is not optional for metric-backed claims.** The rule says grep the claimed config before queueing; extend it: before queueing "X is broken because metric Y", open Y's label breakdown.
4. **The sops skill's own example violates the fish_history critical rule** (`sops --set '["key"] "VALUE"'` with a literal value). The skill predates/contradicts the rule; fix the example in the skill source (crush-config repo, commit-based per the global-install policy) to the runtime-expansion pattern I used.
5. **Fatal-ExecStartPre fragility:** any network fetch inside ExecStartPre makes boot-time content-filter flaps into service outages. The crowdsec hub-update case is queued; the pattern likely repeats elsewhere (worth one sweep).
6. **Geo's LOGPARSER list is config-time-derived and exact (76/76 verified) — good design, keep it**; but rotated-file backfill remains an upstream gap: `import-logs` should get a systemd timer or be documented as an explicit non-goal (currently a manual runbook note only).

## f) Top 50 things to get done next (impact-ranked; harvest status marked)

**Deploy + verify the session's landings (Critical):**
1. Run the lull deploy carrying stage-2 declarative + geo OAuth-only + geo retention; execute the two `[watch]` batteries (bouncers list, converge log line, password_login_disabled, ANALYTICS_* env, TimescaleDB policies) — **harvested ✓** (`docs/todo/services.md` watch rows + `TODO_LIST.md`).
2. Fix crowdsec caddy acquis: add crowdsec to the caddy group, re-check ambient cap, verify file-source hits > 0 — **harvested ✓** (`[ready]` row exists).
3. Fix `sshd-success-logs` sshd-session gap (route per §g Q3) — **harvested ✓** (`[ready]` row exists).
4. dnsblockd whitelist cdn-hub/hub-data + decide hub-update fatality policy — **harvested ✓** (`[ready]` row exists).
5. Land CHANGELOG rows for 2026-10-16: stage-2 declarative, geo OAuth-only + retention, acquis findings/retraction — **landing right after this report** (new).
6. Fix the stale crowdsec.nix header/catalog description ("bouncer stage pending" → stage-2 registration landed, stage-3 enforcement still pending) — **landing right after this report** (new, comment-only).
7. Post-deploy: confirm `/run/current-system` == latest `system-N-link` (anchor discipline — the exit-14 class) — **standing rule**; fold into the deploy battery.
8. After deploy: re-scrape crowdsec /metrics and confirm caddy file-source + sshd-success-logs counters move (closes §b.3) — folded into rows 2–3 batteries.

**CrowdSec depth (High):**
9. Test whether cdn-hub.crowdsec.net resolves/fetches clean RIGHT NOW behind dnsblockd (evidence for row 4's whitelist + policy decision) — **not harvested separately**: it IS row 4's first step.
10. Upstream hub check: does master already fix sshd-success-logs' filter? (determines PR vs backport note) — **not harvested separately**: it is row 3's verify-before-filing gate step.
11. Upstream nixpkgs crowdsec module issue (tmpfiles rootDir + PrivateUsers×cap trap + non-idempotent machine add) with our fixes as the proposal — **queued ✓** (stage-1 report #28; carry).
12. Hub-update retry/backoff INSIDE the setup leg (degrade to warning instead of start-fatal) if the policy decision in row 4 says so — part of row 4.
13. Decide + document CrowdSec console enrollment (needs CAPI enabled — currently disabled by design) — **not harvested**: owner-decision, see §g; ROADMAP fuel.
14. CrowdSec stage 3: firewall bouncer enable decision after the alert-review window — **queued ✓** (runbook §Stage 3).
15. Geometrikks ban/unban machine creds (stage-3 unlock) — **queued ✓** (stage-2 row notes it).
16. VM test for the crowdsec module (unit order, acquis files, bouncer-register render) — **queued ✓** (stage-1 report #47).
17. SigNoz rule for crowdsec (agent-down / parse-error rate) beyond gatus liveness — **queued ✓** (stage-1 report #35).
18. Textfile collector: expose decisions/alerts count for the health dashboard — **queued ✓** (stage-1 report #36).
19. Upstream bump drill note: when nixpkgs moves crowdsec past 1.8.1, re-audit our three mitigations + bouncer-register — **queued ✓** (stage-1 report #48).
20. Watch the 00:59-style `QueryDecisionCountByScenario: context canceled` one-off at restarts — transient, only escalate if it repeats across restarts — **not harvested**: single occurrence, no action exists yet.
21. Watch the journald "truncated journal file" stderr warning in crowdsec acquis — cosmetic — **not harvested**: cosmetic, noted here only.

**GeoMetrikks (High/Medium):**
22. Owner flips geo.home.lan/settings → Enabled post-deploy (unlocks Security/Banned-IPs views) — **harvested ✓** (in the stage-2 watch row).
23. Verify TimescaleDB retention jobs actually show 36500 + confirm compression-policy interaction (retention ≥ compression keep-window is expected-safe; confirm empirically) — **harvested ✓** (geo watch row).
24. MaxMind/CARTO keys (owner) — map stays degraded until then — **queued ✓** (`[blocked:user]` row 179).
25. PBX traffic feed decision (parallel session's design; owner picks shipped-files/agent/drop) — **queued ✓** (row 181, not mine to touch).
26. `import-logs` automation decision: timer for rotated logs vs documented non-goal — **not harvested**: upstream-shape question, needs the owner's retention intent confirmed first (36500 says "keep everything" — if so, a backfill timer becomes MORE valuable; fold into the next geo conversation).
27. Upstream geometrikks PR: server-side default-accent env (makes theme asks nix-manageable) — **blocked on §g Q2**.
28. sops orphan key `geometrikks_admin_password` removal at next sops touch — **not harvested**: harmless, one-command cleanup on the next natural rotation; queueing a row for it would outlive its worth.

**Repo hygiene noticed this session (Medium):**
29. sops-skill example fix (inline literal secret value conflicts with the fish_history rule) — lives in the crush-config repo (commit there, not here) — **not harvested here**: wrong repo; noted for the crush-config pass.
30. Re-red CI nix-flake-check workflow (VM-test tarball auth + statix leg) — **queued ✓** (`TODO_LIST:1339`, pre-existing).
31. InboxClean Gmail OAuth re-consent (service-health-check reds every tick) — **queued ✓** (`[blocked:user]`, pre-existing).
32. Hot-db bootstrap CAP_DAC_OVERRIDE deploy + verify — **queued ✓** (pre-existing `[ready]` row).
33. Ratify-or-port the vendored systemd-audit.py — **queued ✓** (pre-existing `[decision]`).
34. `/data/docker` reclaim (owner sudo steps) — **queued ✓** (pre-existing `[blocked:user]`).
35. Tame the 6060 pprof listener — **queued ✓** (`security.md` `[decision]`, pre-existing).
36. deploy-intent convention for concurrent agent loops (two sessions deploying again today; the PSI-gate refusal loop is real) — **queued ✓** (`pipeline.md`, pre-existing, hit again this session).

**Small/cosmetic (Low):**
37. Runbook: add a "verify at node-level metrics" line to the ops section (so the §d lesson lives where the next verification happens) — **landing right after this report** (new, one line).
38. Gatus: consider a check on `crowdsec-bouncer-register.service` result (currently only engine liveness) — **not harvested**: the watch battery covers the first verify; a permanent check is worth a row only after we see the unit behave in production.
39. Confirm the LOGPARSER list-vs-disk invariant stays exact after the next vhost change (the nix derivation is the source of truth — 76/76 today) — **not harvested**: invariant is config-time-derived; re-check opportunistically in the geo watch battery.
40. ROADMAP: a real custom accent (owner's "Fjord green" as an actual theme) if §g Q2 answer is (c) — **blocked on §g Q2**.
41. Prune the retracted/corrected sshd rows to CHANGELOG per the `[x]`-row lifecycle at the next todo pass — **not harvested**: routine docs-health HARVEST work, not session-specific.
42. Consider `cscli alerts list` snapshot into the post-deploy check (baseline "what did crowdsec see" after every switch) — **not harvested**: scope-creep risk; needs a design thought, ROADMAP fuel.
43. Doc-drift sweep: older crowdsec status reports still say "stage 2 owner-interactive" — point-in-time snapshots, DO NOT rewrite (ANNOTATE-only doctrine) — **not harvested**: by doctrine.
44. README/FEATURES: crowdsec + geo entries if the user-facing docs track services — **not harvested**: not verified whether FEATURES.md tracks services this session; next docs-health pass.

*(44 concrete items — the ask was "up to 50"; the remaining slots would be padding, and vague items are worse than none.)*

## g) Three questions I cannot figure out myself

1. **Deploy ownership + timing:** stage-2 declarative, geo OAuth-only/retention, AND the parallel session's pending PBX work are all stacked on the next switch. Do you want THIS session to drive the lull deploy now-ish (I'll run the two verify batteries after), or should the parallel session own the switch and I only verify? Both deploying is safe but doubles the storm windows we burn — I can't judge who's mid-what on the other side.
2. **The theme, precisely:** "Fjord green" doesn't exist upstream and there is no server-side accent knob. Pick one: **(a)** you just pick the existing `green` accent in your browser's UI toggle (zero code), **(b)** I upstream a `DEFAULT_ACCENT` env option to GilbN/geometrikks so it becomes nix-managed, or **(c)** you actually want a custom "Fjord" palette (I patch our package build with a fourth accent) — (c) is the only one that gives you a literally-named theme.
3. **sshd-success-logs fix route:** local declarative parser override in our tree (works at next deploy, but hub-state is runtime-mutable per the runbook gotcha — an override can drift/conflict on hub updates) vs upstream hub PR (clean, but your successful logins stay unparsed until merged + a hub refresh). Which trade do you want?

---

*Prepared per the status-report skill (`.md` per the owner's explicit path demand — HTML-canonical format overridden this once). §f items marked "landing right after this report" land below; everything else references its existing queue surface. THEN WAITING FOR INSTRUCTIONS.*
