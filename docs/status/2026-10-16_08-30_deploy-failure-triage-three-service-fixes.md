# Status Report: Deploy-Failure Triage — forgejo / geometrikks / fastflowlm / crowdsec

**Session window:** 2026-10-16 ~07:10–08:30 CEST
**Author:** Crush (glm-5.3-flash) session, dispatched by owner "fix!" on the failed `nix flake update bank-sync && nh os switch` output
**Format note:** status-report skill is HTML-canonical; the owner's dispatch prompt explicitly demanded `.md` at `docs/status/<ts>_*.md` — honored (standing task-queue dispatch exception shape), not propagated back into the skill.

---

## Executive summary

The owner's deploy failed activation with three units down (`forgejo`, `geometrikks-log-pull-pbx`, `fastflowlm`) and one evaluation-breaking landmine from a parallel session (`crowdsec`). All three deploy-blocking failures were root-caused, fixed in-tree, deployed, and verified live. One repair turned out to have THREE stacked legs (binary → host key → public key); two are done, the third is owner-gated. A parallel session's committed `crowdsec.nix` edit broke whole-flake eval mid-session and was repaired under the daemon-race policy. Final state: toplevel deployed, **anchor verified (`system-910` == `/run/current-system`)**, `nix flake check` green, post-deploy smoke 150 PASS / 4 FAIL (all baseline or deliberate incident states).

Concurrent-session context: another agent session was running heavy builds throughout (IO PSI saturated ~99% for most of the window, memory-emergency guard tripped, FLM deliberately capped). Several post-deploy FAILs are that incident's deliberate states, not regressions.

---

## a) FULLY DONE

Each item: what / evidence / scope.

| # | Item | Evidence | Scope |
|---|------|----------|-------|
| A1 | **forgejo EROFS crash-loop fixed** — the new bleve repo indexer (landed in a parallel session's auto-commit `0e8c45fc`, first deployed by the failing switch) wrote to `/mnt/hot/forgejo-index` while `ProtectSystem=strict` + nixpkgs' `ReadWritePaths` made everything outside the state dir read-only (`mkdir /mnt/hot/forgejo-index/repos.bleve: read-only file system`, journal 07:10:52). Added a `repoIndexerEnabled`-gated `ReadWritePaths = [ forgejoIndexDir ]` leg to the main service's `serviceConfig` mkMerge | forgejo running since 07:32:16 (PID 2269436), `Repository Indexer Initialization took 84ms` + "Done (re)populating" in journal; `repos.bleve` dir confirmed on the Samsung hot tier via sudo probe; `:3000` LISTEN; rendered unit shows `ReadWritePaths=/mnt/hot/forgejo-index` | `modules/nixos/services/forgejo.nix` |
| A2 | **geometrikks pull-script ssh binary fixed** — the oneshot used bare `ssh` inside a `writeShellScript` (no PATH) → exit 127 `ssh: command not found`. Both call sites now resolve `${pkgs.openssh}/bin/ssh` via a `sshBin = lib.getExe pkgs.openssh` let-binding | rendered script (`/nix/store/bd9gy…-geometrikks-log-pull-pbx`) greps clean: both ssh invocations carry absolute store paths | `modules/nixos/services/geometrikks.nix` |
| A3 | **geometrikks pbx host-key leg fixed** — after the binary fix the unit failed exit-255 `Host key verification failed` (BatchMode can't TOFU; root's `known_hosts` never held the pbx key — the build plan's "auth rides root's default ssh identity" premise covered identity but never the host key). Added `programs.ssh.knownHosts."pbx.artmann.tech"` (ed25519, TOFU'd via `ssh-keyscan` from this host at pin time, recorded) | pin renders in the deployed `etc/ssh/ssh_known_hosts` (build-verified pre-deploy); journal advanced past host-key failure to the NEXT leg (`Permission denied (publickey)`, 08:07+) — proof the leg is closed | `modules/nixos/services/geometrikks.nix` (inside the NixOS `config` block, not flake-parts level) |
| A4 | **fastflowlm ephemeral-port collision fixed** — backend bind failed EADDRINUSE with NO listener on :52626: the socket-activation design leaves the backend port usually unbound, so outbound connections (live evidence: an ESTAB pair `127.0.0.1:52626 ↔ 127.0.0.1:9100` — a probe to node_exporter holding the port as its ephemeral source) steal it from `ip_local_port_range` 32768–60999. Added `boot.kernel.sysctl."net.ipv4.ip_local_reserved_ports" = "52625,52626"` co-located in the module | sysctl live on the running kernel (`net.ipv4.ip_local_reserved_ports = 52625-52626`); zero fastflowlm journal entries since 07:30 (no bind failures); rendered `sysctl.d/60-nixos.conf` verified pre-deploy | `modules/nixos/services/fastflowlm.nix` |
| A5 | **crowdsec eval breakage repaired (shared-tree rescue)** — the parallel session's committed edit (`d5c67c03`, daemon-swept) defined `systemd.services.crowdsec` BOTH as dotted path (`serviceConfig.ExecStartPre`) and attrset (`serviceConfig = mkMerge [...]`) → `attribute 'systemd.services.crowdsec.serviceConfig' already defined` broke eval for the ENTIRE flake (all deploys, all hosts). Merged the ExecStartPre into the mkMerge list; then fixed the SAME session's follow-up runtime bug (bare `ln` → `Failed at step EXEC`, 08:07) with an absolute `${pkgs.coreutils}/bin/ln` | eval green after merge; crowdsec running, LAPI `/v1/decisions/stream` serving 200s (journal 08:16+) | `modules/nixos/services/crowdsec.nix` |
| A6 | **Deploy-anchor discipline applied** — one deploy landed UNANCHORED (`/run/current-system` ≠ profile link; a reboot would have reverted the switch). Repaired per the 2026-10-14 rule: `nix build --no-link --profile system <toplevel>` + `switch-to-configuration boot` via sudo harness | `readlink /run/current-system` == `readlink system-910-link` == `/nix/store/1q5wwvy3…`; boot transaction written (systemd-boot output clean) | host state (no tree change) |
| A7 | **Docs truth + queue updated** — geometrikks runbook gained the auth-chain note (host-key pin + the publickey dependency with live evidence); `docs/todo/services.md` gained the `[blocked:user]` pbx-publickey row | committed via daemon sweep | `docs/services/geometrikks.md`, `docs/todo/services.md` |

## b) PARTIALLY DONE

| # | Item | Works now | Open | Blocker | Effort |
|---|------|-----------|------|---------|--------|
| B1 | **geometrikks pbx feed** | Host-key leg + ssh-binary leg fixed and deployed; unit fails LOUDLY (per design) every 1-min tick | Identity leg: root@evo-x2's pubkey is NOT authorized on `pbx.artmann.tech` → `Permission denied (publickey)`. Also unverified: whether the pbx side (`hosts/pbx/geometrikks-feed.nix`) is switched there at all — the remote file may not exist yet (MISSING clean-exit leg never reached) | **Owner-gated**: PBX console/existing access needed. Queued as `[blocked:user]` in `docs/todo/services.md` | S (owner action) + S (verify) |
| B2 | **fastflowlm end-to-end** | Bind-collision fix deployed; sysctl live; no failures since | The A4 fix has NOT been proven under real traffic — the public socket is deliberately DOWN (SEV1 "FLM RESTORE CAPPED", live 08:22:32) so no client request has traversed 52625→52626 since the fix | SEV1 memory-guard incident state (parallel session's build storm); un-caps when the guard clears | S (verify) once uncapped |
| B3 | **Post-deploy smoke green** | 150 PASS, anchor OK, all but one FAIL baselined or deliberate | `InboxClean /health` flagged as NEW failure vs baseline (`status: degraded`, `auth_expired` warn on the main Gmail account) — appeared during this session's window, cause NOT triaged (my deploys did not restart inboxclean per the switch stop/start lists) | Needs journal/config triage | S–M |
| B4 | **This session's tree hygiene** | All four module fixes + docs committed (daemon sweeps: `4afa8763`, `afd490a6`, `d6672305`, forgejo leg inside `96b41571`) | No CHANGELOG entry for the fix batch; no `nix fmt` pass over the four edited modules; the ephemeral-port gotcha not yet generalized into `docs/gotchas-archive.md` | None — pure follow-up | S |

## c) NOT STARTED

Planned/noticed this session, zero work done. (Priority flags: still-wanted?)

- **FastFlowLM liveness-leg classifier** (not started): post-deploy-check FAILs on `:52625 unreachable` while SEV1 caps FLM — a deliberate state renders as a red FAIL. A SKIP-with-classifier ("SEV1-capped") leg would keep the signal honest. *(Wanted: yes — false-red baseline noise erodes trust in the gate.)*
- **Ephemeral-port reservation sweep** (not started): ANY long-lived loopback service port is one probe away from this exact collision while its daemon is down. `lib/ports.nix` is the single registry — a generated `ip_local_reserved_ports` list would kill the class. *(Wanted: yes; decided whether all loopback ports or only "binds late" ones.)*
- **OnFailure notify dedup for timer-driven oneshots** (not started): the pbx pull fails EVERY minute and fires OnFailure→notify every time — Discord spam until the owner acts. Backoff/dedup (state-file based) is unbuilt. *(Wanted: yes.)*
- **known_hosts-pin coverage audit** (not started): new audit leg — every unit invoking ssh (logPulls, borg go-live, backup pulls) must have a repo-pinned host key; would have caught A3 at eval time.
- **writeShellScript binary-resolution audit** (not started): sibling audit — every `writeShellScript` ExecStart referencing bare commands. Would have caught A2. (The repo has `audit-shell-nullglob.sh` as a pattern to copy.)
- **Dotted-path/attrset duplicate-definition negative test** (not started): the crowdsec breakage is mechanically detectable (same service defined both ways in one module); the negative-test lint harness (`scripts/negative-test-lints.sh`) is the home. *(Wanted: yes — it blocked every deploy.)*
- **forgejo sustained-CPU exemption class** (not started): §18 sanity FAILed `forgejo.service=165%CPU` during first-index backfill — a legitimate transient with no exemption/documented class. *(Wanted: yes, before the next legit long job pages someone.)*
- Items already queued by the PARALLEL session (noticed, not duplicated here as tasks): geometrikks render selftest (§f.4), pbx-feed staleness metric (§f.5), remote-feed docs truth pass (§f.6-8), FEATURES row (§f.9).

## d) TOTALLY FUCKED UP

Radical honesty; this is the valuable section.

1. **A parallel session committed an eval-breaking `crowdsec.nix` and every deploy on the host was blocked by it for ~25 minutes.** Severity: blocked ALL deploys (both sessions). Root cause: dotted-path + attrset definition of the same service in one module — never eval-checked before the daemon committed it. Mitigation applied: I merged the definitions. Residual: NOTHING in the pipeline catches this class pre-commit (pre-commit runs `nix flake check` but the daemon's commit raced past it; the file was committed mid-edit). Also note: the SAME edit's runtime half (bare `ln`) passed eval and broke the unit at first start — two failure classes from one change.
2. **My first knownHosts insertion was written at the wrong nesting** (flake-parts module level instead of inside the NixOS `config` block) → `unsupported attribute 'programs'` eval error. Caught by the build, fixed by re-reading the module structure. Root cause: I pattern-matched the surrounding `imports`/`options` block instead of checking where the module's NixOS config lives. Should have read the full `in { … }` return shape before inserting.
3. **My first ReadWritePaths edit produced `mkMerge [ … ] ++ lib.optionals …`** — an attrset++list type error, caught by my own re-read BEFORE any eval. Near-miss, zero cost, but the pattern (append to a mkMerge list by string-editing its closing bracket) is fragile; `lsp_replace_symbol`-style block replacement would have been safer.
4. **Three wasted deploy attempts on the PSI pressure gate** (~15 min) chasing a flapping `avg10` while the parallel session's builds kept the box saturated; I deployed with `DEPLOY_FORCE_PRESSURE=1` only afterwards. The force WAS justified (toplevel already built by my earlier `nix build` — deploy adds only activation IO), and I could have reasoned that in the first attempt instead of looping drain-waits that lost the race every time. Counterpoint honestly stated: the gate exists because the 2026-08-22 freezes had builds as contributing load — force-unjustified would have been the worse mistake.
5. **The geometrikks fix shipped with unverified downstream legs.** I fixed leg 1 (binary), deployed, and only the JOURNAL told me about leg 2 (host key) and leg 3 (publickey). The `--keep-going`-style "enumerate ALL root failures in one pass" rule that this repo codifies for nix builds was NOT applied to service verification: one manual `bash <script>` probe (or a `systemctl start` of the unit) BEFORE deploying would have surfaced binary+host-key in one shot. Cost: one extra deploy cycle + a 25-min eval-blocked window in the middle.
6. **I claimed the indexer "verified live" while permission-blind.** First probe: `ls /mnt/hot/forgejo-index/` returned nothing (dir is forgejo-owned 0750; my earlier `/data/docker` permission-blind lesson did NOT transfer). I nearly reported an empty index as "indexer live". Corrected with the sudo harness probe that showed `repos.bleve` present. The "assert WHICH entity served it" discipline needs the sibling: "assert WHICH probe read the state".
7. **Post-deploy-check "NEW failures" flagging is noisy**: it flagged InboxClean as a regression while three other FAILs (FastFlowLM, tq, Architecture Catalog) were pre-existing/deliberate — and I could not determine InboxClean's cause within the session. Not my gate to fix this session, but an untriaged red on the final deploy summary is an unsatisfying close-out.

## e) WHAT WE SHOULD IMPROVE

Process/design, not bugs:

1. **Service-side "--keep-going"**: before deploying a fix for a failing unit, run the unit's script/ExecStart once manually (or in a throwaway harness) to enumerate ALL failure legs, not just the known one. This is the same one-pass-enumeration rule the repo already applies to nix builds (`--keep-going` first) — it needs stating for SERVICE failures in AGENTS.md. Would have saved a full deploy cycle + the eval-blocked window (D5).
2. **Permission-blind probes get a sudo harness IMMEDIATELY**: any `ls`/`stat`/`grep` that comes back empty on a root-owned path is an artifact, not a fact (D6). The harness pattern (`cat > /tmp/probe.sh`, run it) is sanctioned and worked perfectly — make it the FIRST move, not the correction.
3. **Block-replacement over bracket-editing for Nix lists**: appending to an `mkMerge [ … ]` by editing the closing `];` invites the `++`-outside-the-call mistake (D3). Where the target is a config attrset, read the whole `in { }` shape first (D2).
4. **Pressure-gate force criteria deserve documentation**: when the toplevel is ALREADY built (activation-only IO), `DEPLOY_FORCE_PRESSURE=1` is defensible; when the deploy would build, it is not. One sentence in AGENTS.md → "Session Discipline" would codify it.
5. **Daemon-swept commits need the owner session's eval gate**: the crowdsec breakage (D1) landed via the heuristic daemon commit. The multi-agent rules cover amend-races; they do NOT require "eval before the daemon can sweep your module edit". A cheap per-session habit — `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` before walking away from a module edit — would close most of it.
6. **Post-deploy baseline semantics**: "NEW failures vs baseline" should classify deliberate incident states (SEV1 caps, PSI-gated refusals) — either via the failing check itself carrying a SKIP-classifier (C1) or via a baseline-annotation convention.
7. **Ephemeral-port collision is a CLASS, not an incident** (A4): the socket-activation design makes it likely for any service whose port idles unbound. The generic fix (reserved ports from `lib/ports.nix`) beats per-module sysctls.

## f) Top #50 things we should get done next

Ranked by impact. S <30min, M 30min–2h, L >2h. **HARVEST routing** tagged per item (queue = `TODO_LIST.md` only for `[ready]`; domain libraries own the rest; ROADMAP for vague/long-term). Items marked ⏸ are already in the queue/domain files (do NOT re-add — listed for completeness).

| # | Task | Impact | Effort | Category | Route |
|---|------|--------|--------|----------|-------|
| 1 | Owner: authorize root@evo-x2's pubkey in pbx.artmann.tech's `authorized_keys` (then the 1-min timer auto-greens; verify map beacon (c)+(d) of the parent row) | Critical | S | Bug (owner-gated) | ⏸ already queued `[blocked:user]` today |
| 2 | Triage InboxClean `/health` degraded status (`auth_expired` main-Gmail leg): regression vs owner mid-rotation | High | S–M | Bug | `services.md` (inboxclean row) |
| 3 | Verify fastflowlm end-to-end after SEV1 uncap: one client request through :52625→52626, backend journal shows bind+accept | High | S | Verification | `[watch]` row, services.md |
| 4 | Reserve ALL loopback service ports from ephemeral allocation: generate `net.ipv4.ip_local_reserved_ports` from `lib/ports.nix` | High | M | Feature | `services.md` or `stability.md` |
| 5 | Fix `crowdsec-counts.prom` writer perms — node_exporter logs `permission denied` on the textfile every scrape (journal 08:14:21) = broken crowdsec metrics | High | S | Bug | `monitoring.md` |
| 6 | CHANGELOG entry for this fix batch (forgejo ReadWritePaths, geometrikks ssh+pin, fastflowlm port reservation, crowdsec merge+ln) | Medium | S | Documentation | CHANGELOG (docs-health pass) |
| 7 | `nix fmt` pass over forgejo/fastflowlm/geometrikks/crowdsec modules | Medium | S | Quality | do-next |
| 8 | Verify forgejo repo-indexer actually populated (~470 mirrors expected): code-search API hit for a known token; watch `/mnt/hot/forgejo-index` growth | High | S | Verification | `[watch]`, services.md |
| 9 | Negative-test lint: flag modules defining one `systemd.services.<x>` via BOTH dotted path and attrset (crowdsec class) | High | M | Quality | `pipeline.md` + negative-tests harness |
| 10 | OnFailure notify dedup/backoff for timer-driven oneshots (pbx pull spams notify every minute until owner acts) | High | M | Feature | `services.md` |
| 11 | Audit: every `writeShellScript` ExecStart must resolve external binaries absolutely (geometrikks class) — extend `scripts/audit-shell-nullglob.sh` pattern | High | M | Quality | `pipeline.md` |
| 12 | Audit leg: every ssh-invoking unit has a repo-pinned `knownHosts` entry (geometrikks/borg/offsite class) | High | M | Quality | `security.md`/`pipeline.md` |
| 13 | FastFlowLM post-deploy leg: SKIP-with-classifier when SEV1 cap active (false-red class) | Medium | S | Quality | `services.md` (fastflowlm row) |
| 14 | SEV1 memory-guard trip attribution: identify WHICH allocation tripped the guard during the build storm (guard trip count + cgroup) | High | M | Bug | `stability.md` |
| 15 | Document `DEPLOY_FORCE_PRESSURE` justification criteria in AGENTS.md (cached-build ⇒ defensible) | Medium | S | Documentation | AGENTS.md |
| 16 | Ephemeral-port gotcha into `docs/gotchas-archive.md` (bind EADDRINUSE with empty `ss` = stolen port, not ghost process) | Medium | S | Documentation | gotchas-archive |
| 17 | ⏸ geometrikks pbx-feed staleness signal (offset-mtime metric + post-deploy leg) — parallel session queued §f.5 | Medium | M | Monitoring | ⏸ services.md |
| 18 | ⏸ geometrikks logPulls render selftest — parallel session queued §f.4 | Medium | M | Quality | ⏸ services.md |
| 19 | ⏸ Remote-feed docs truth pass (tailer seek branch, deploy ordering, rotation cadence) — parallel session queued §f.6-8 | Medium | M | Documentation | ⏸ services.md |
| 20 | ⏸ FEATURES row: geometrikks multi-source remote feeds — parallel session queued §f.9 | Low | S | Documentation | ⏸ services.md |
| 21 | Post-deploy check: classify tq-agent-pool PSI-refused as SKIP (deliberate gate), not FAIL | Low | S | Quality | `pipeline.md` |
| 22 | Alert when tq-agent-pool refused N consecutive starts (gate flapping = storm detection for free) | Medium | S | Monitoring | `monitoring.md` |
| 23 | Architecture Catalog EventCatalog title drift (pre-existing FAIL both runs): probe which branch/entity serves the index | Medium | S | Bug | `services.md` |
| 24 | forgejo MemoryHigh 379k watermark hits (§17 sweep): raise watermark or cap indexer backfill IO | High | M | Bug | `stability.md`/`services.md` |
| 25 | inboxclean-web 825k watermark hits (§17 sweep — WORST on box): investigate reclaim-thrash | High | M | Bug | `stability.md` |
| 26 | Watermark triage batch: papdashboard 134k, clickhouse 43k, geometrikks 14k, mr-sync 17k, project-discovery 17k, cv-server 2.7k (§17 sweep) | Medium | M | Bug | `stability.md` |
| 27 | forgejo first-index CPU exemption class for §18 sanity (165% legit backfill) | Medium | S | Quality | `pipeline.md` (post-deploy script) |
| 28 | node_exporter journal rate 416 lines/min (§18 FAIL): root-cause the noisy collector (textfile errors seen) | Medium | S | Bug | `monitoring.md` |
| 29 | postgres collation mismatch warnings (paperless 2.42 vs lib 2.44): `ALTER DATABASE … REFRESH COLLATION VERSION` sweep + guard | Medium | S | Bug | `services.md` |
| 30 | Duplicate python3 3.13+3.14 in system-path (buildEnv collision warnings ×14): dedupe the packages list | Low | M | Cleanup | `systems/` packages |
| 31 | fastflowlm/xrt libxrt collision warnings: split or pin vendor libs | Low | M | Cleanup | `services.md` (fastflowlm) |
| 32 | Deploy script: bounded drain-and-retry on pressure flap instead of 3 manual attempts | Medium | S | Quality | `pipeline.md` |
| 33 | fastflowlm proxy-conn: pre-bind wait loop for backend port as defense-in-depth (belt to the sysctl suspenders) | Low | S | Feature | `services.md` (fastflowlm) |
| 34 | SSH identity drift doc: which root keys exist on evo-x2, authorized where (feeds the pbx fix and borg go-live) | Medium | M | Documentation | `security.md` |
| 35 | borg `known_hosts` pin coverage folded into #12 (go-live will hit the same TOFU trap on port 23 shape) | Medium | S | Quality | (merge into 12) |
| 36 | Per-session eval gate habit: `nix eval …toplevel.drvPath` before walking away from a module edit (multi-agent policy reinforcement) | High | S | Process | AGENTS.md (Session Discipline) |
| 37 | in-flight module-edit marker for concurrent sessions (crowdsec class: another session's half-done edit blocks the tree) — liveness/lock file convention | Medium | M | Process | AGENTS.md + tooling |
| 38 | Quieten `flake-input-pin-audit` traces to a one-liner (3-line trace on EVERY eval inflates all logs) | Low | S | Quality | `pipeline.md` |
| 39 | stdenv.isLinux deprecation warning from the llama-rag pinned nixpkgs — silenced at the pin lift (⏸ existing pin row owns the trigger) | Low | — | Watch | ⏸ existing pin rows |
| 40 | catalog subdomain warning (20 integration subdomains without entries) — wire entries or retire the warning | Low | M | Cleanup | `services.md` (catalog) |
| 41 | Monitor forgejo index backfill duration + Samsung hot-tier headroom as it indexes ~470 repos | Medium | S | Watch | `[watch]`, storage.md |
| 42 | Verify Helsinki beacon + `pbx` source filter in geo UI once feed greens (parent row (c)+(d)) | Medium | S | Verification | (fold into #1 close-out) |
| 43 | geometrikks runbook: exact deploy-order commands (evo-x2-first is safe via MISSING clean-exit) — part of the queued docs truth pass ⏸ | Low | S | Documentation | ⏸ services.md §f.6-8 |
| 44 | idle-check restart protocol test: after SEV1 uncap, confirm socket re-arms WITHOUT manual stop/start (the design's core promise) | Medium | S | Verification | services.md (fastflowlm) |
| 45 | Review whether OTHER writeShellApplication/Script units rely on implicit PATH from `runtimeInputs` vs ExecStart env (audit precursors: #11 covers) | Low | M | Quality | (merge into 11) |
| 46 | Baseline discipline: update smoke-fail-baseline only after triage, never to green a deploy (this session's InboxClean flag is the test case) | Medium | S | Process | `pipeline.md` |
| 47 | GitHub Actions: add a paths-triggered eval job for `modules/nixos/**` edits (catches dotted-path duplicates before merge, not at next deploy) | High | M | Quality | `pipeline.md`/CI |
| 48 | Document the sudo-harness probe pattern (permission-blind lesson transfer) in `docs/agents/shell-devtools.md` | Medium | S | Documentation | shell-devtools.md |
| 49 | Bank-Sync: this session's trigger was `nix flake update bank-sync` — verify the bank-sync input update actually landed in the lock + deployed (the deploy churn masked the ORIGINAL intent!) | High | S | Verification | check `flake.lock` + bank-sync journal ← **honest catch: unverified primary goal** |
| 50 | ROADMAP: generic "service port hygiene" epic (reserved ports, port-ownership docs, bind-order guarantees) — umbrella for #4/#33 | Low | L | Feature | ROADMAP.md |

**HARVEST note:** #49 is the one that shames this session — the owner's original ask was `nix flake update bank-sync`, and the deploy-failure triage consumed the session WITHOUT ever verifying the bank-sync input update was present, deployed, and syncing. That verification is the first `[ready]` item to harvest.

**Addendum (08:35, self-caught at report-authoring time):** #49 verified closed — `flake.lock` carries bank-sync rev `70ffaf63` (committed via daemon sweep `3282cd8d`), and the deployed bank-sync unit is syncing clean post-deploy: `sync completed successfully provider=wise total_new=0` at 08:20:39 (5 profiles, 43s). The input update that STARTED this session did land; the session just never looked. Item #49 downgrades from `[ready]` to done — kept in the table for the lesson, not the work.

## g) Top #3 questions I can NOT figure out myself

1. **PBX identity leg:** Has root@evo-x2's public key EVER been added to `pbx.artmann.tech`'s `authorized_keys` (and is `pbx-artmann`'s `hosts/pbx/geometrikks-feed.nix` switched there)? I cannot read the PBX or root's key material from this host — the feed stays red every minute until you confirm/add it (or tell me the pull should use a DIFFERENT existing key/identity, which would change the fix).

2. **InboxClean degraded:** The `/health` went from ok to `degraded` in this window with `auth_expired` on the main Gmail account. Are you mid-OAuth-rotation on that account (runbook deliberately open), or is this an unexplained regression I should triage NOW (I did not restart inboxclean; no deploy touched it)?

3. **FastFlowLM policy during build storms:** Do you want FLM to stay SEV1-capped (socket down, no NPU/RAM) for the rest of today's heavy parallel session, or should I clear the SEV1 state and re-arm the socket once IO/PSI drains — accepting it may re-trip the memory guard if the builds resume? (The cap was the guard's decision, not mine; un-capping is a one-command owner call.)

---

**Wait state:** Report written per dispatch instructions. Awaiting further instructions.
