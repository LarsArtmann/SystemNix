# Kernel-fix session 2: deploy close-out + brutal self-review (2026-10-23 18:08)

Session: continuation of `docs/status/2026-10-23_16-42_kernel-module-deploy-blocker-fix-status.md` (same conversation; owner steer "keep going until everything works" → this pass). Scope: everything this session did between 17:10 and 18:08, judged honestly. The 17:13 report (`deploy-recovery-full-session.md`) is the PARALLEL deploy session's account — this file is mine; no duplication intended, cross-references where our work touched.

---

## a) FULLY DONE (verified, evidence-backed)

1. **Tree-green confirmation**: `nix build …toplevel --keep-going --no-link` exit 0 (17:14–17:25) against the rolled-back lock (`fe13242`) — independently validated what the deploy session switched.
2. **Pre-deploy battery: 103 passed / 0 failed / 13 advisory warnings** — the deploy gate the repo requires, run before the switch.
3. **Deploy anchor verified (post-completion)**: `readlink /run/current-system` == `system-939-link` == `z38nwd…-evo-x2-26.11.20261015.fe13242`. Deploy itself was executed by the parallel session (17:34 `nh os switch`); I held off per twin-executor doctrine — correct call, caught live via `ps`.
4. **Post-deploy regression triage complete**: first battery 13 FAIL → second 5 FAIL, all byte-identical to the pre-deploy baseline (`~/.local/state/systemnix/smoke-fail-baseline.txt`) → **zero deploy regressions**. Each of the 5 triaged to a verdict with live evidence (table in the 16:42 report's second pass).
5. **monitor365 reconnection proven**: `Agent SSE connected device_id=evo-x2` 17:48:02, health JSON `realtime: connected (1 devices)` — the agent-watchdog's circuit-breaker restart worked AFTER the battery's grace window (check-timing artifact, not a defect).
6. **Dev-cv port squatter killed**: 16h-old `go run ./cmd/cv serve` + buildcache child holding `*:8201` (the CV syncer base_url port; the 2026-10-19 astro-preview squatter class). Killed via absolute-path kill; port freed.
7. **`stdenv.isLinux` eval warning ATTRIBUTED AND FIXED AT SOURCE**: hermes-agent input `nix/hermes-agent.nix` runtimeDeps optionals (+ the packages.nix matrix leg), reached via our session-boot-audit assertions forcing the dbus-broker unit text. Method: throwaway `extendModules` eval (never touched the tree) neutralizing deliberate warnings, then `NIX_ABORT_ON_WARN=1 --show-trace`. Fixed in the local clone (3 sites → `stdenv.hostPlatform.isLinux`); local-tree eval of the package = **0 warnings** (was: warning per evo-x2 eval). Queued in upstream.md.
8. **`'system'` rename warning bisected one level deeper**: fires when forcing `config.systemd.services` / `config.systemd.units`; does NOT fire in `systemd.user.units` nor `environment.systemPackages` → the access sits in a SYSTEM unit's eval. Row enriched with the next move (pipeline.md).
9. **Two stale post-deploy checks fixed** (`scripts/post-deploy-check.sh`, shellcheck-clean, `bash -n` clean):
   - dnsblockd memory: hardcoded 2G vs deployed `MemoryMax = 4G` (the module's storm-tuning) — now derives the limit from the live unit; the 3276MB "failure" was a restart page-cache spike (memory.current counts FILE cache; steady state ~1G).
   - Architecture Catalog marker: expected the old `<title>EventCatalog`; the dist legitimately rebranded to `<title>LarsArtmann Architecture Catalog` (fresh generation 20261023-170000, site + local file agree) — marker updated.
10. **Docs landed**: CHANGELOG entry for the kernel-module shims (item 13); AGENTS.md status-report pre-read gate for ad-hoc fix sessions (item 15) + the kill-builtin trap; CONTRIBUTING daemon-race clause (7) HEAD-age-bounded amend (item 16); gotchas-archive two-session-deploy-convergence entry (item 25); stability.md row premise-corrected (gen-939 carries kernel 7.2.10 — the 7.3 shims are dormant no-ops on this rev, module files verified present in the deployed tree); upstream.md hermes-agent row; 16:42 report second-pass close-out.
11. **§f item 14 (mainProgram batch audit) checked**: only ONE symlinkJoin exists tree-wide (monitor365-server, already fixed earlier this session) and the full toplevel eval emits zero remaining mainProgram warnings — no gaps in the eval-forced surface. (Caveat in e)6.)

## b) PARTIALLY DONE

1. **`'system'` rename warning attribution** — bisected to the systemd.services surface but NOT pinned to the exact module/line. The abort-trace route is blocked because the hermes stdenv.isLinux warning evaluates earlier in that subtree; the route opens after the hermes lock bump. Next move documented in the row, not executed.
2. **flm :52625 check-vs-guard tension** — root-caused (memory-guard Zone-6 sacrificed the socket at 17:36:42 during the deploy storm; module documents auto-restore "once memory has recovered past a margin") but the CHECK still hard-FAILs during any guard-sacrifice window. Improvement queued (f)2), not implemented.
3. **hermes-agent fix propagation** — source fixed + verified locally; NOT pushed (owner action), NOT lock-bumped, and the local clone's push-state vs origin was only ambiguously verified (the `origin/main..HEAD` range query output was inconclusive — could not tell if local is ahead or behind).
4. **Dev-cv zombie confirmation** — port freed and processes SIGKILLed (rc=0), but I never re-verified the /proc entries actually disappeared (zombie reaping by PID 1 assumed, not observed).

## c) NOT STARTED (this session's own leftovers, nothing silently dropped)

1. Third post-deploy battery run to see my two check fixes flip their lines green in situ (validated standalone: shellcheck, bash -n, grep against the real dist file — but not through the full battery).
2. Reading the parallel session's 17:13 report beyond its §f list (noticed it in `git status`, deduped my harvest against it — but did not study its full narrative before finishing).
3. The 17:13 report's items 31–36 (rollback-specific service verifications: Gatus, SigNoz dashboards, Hermes start, DMS, templ-components, pre-vacuum gate) — THEIR list, not started by anyone as far as I saw; not mine to duplicate.
4. `nix flake check --no-build` after the rollback (their item 14) — my toplevel eval was green, but the full check matrix (checks.*, tests) was not re-run by me.

## d) TOTALLY FUCKED UP (owned, with damage assessment)

1. **Secrets in my tool-output transcript**: my `pgrep -af` printed monitor365's `--jwt-secret` and crm-server's `-api-token` verbatim, and a server journal read leaked an OIDC `client_secret`. The AGENTS.md probe-masking rule ("pipe pgrep -af through a redactor — secrets ride argv", added 2026-10-22) existed and I violated it. Mitigations: none of the values were copied into any repo file/report (verified — I referenced them only as "redacted" classes), and the values were already documented-leaky classes with queued upstream rows (JWT-on-argv row exists; the OIDC secret leak into server LOGS is NEW — see f)8). Damage: session transcript + crush DB only. Rule reinforced.
2. **Premature "UNANCHORED" verdict**: I read a mid-deploy snapshot (current-system flipped, profile still gen-938) as the exit-14 UNANCHORED class and was one step from the documented repair (`nix build --profile …`) — which would have raced the LIVE deploy. Caught it by re-checking process liveness first. Lesson encoded below (e)1.
3. **The wait-loop that lied**: `while kill -0 635730; do sleep 15; done` printed "deploy process gone" while the process was alive — because **`kill` is the unsupported builtin in this shell and `kill -0` fails with rc=2 instantly**, so the loop never waited. I discovered the builtin trap 20 minutes LATER during the squatter kill and documented it — without realizing my own wait loop had been an earlier victim. The dot connects now: any `kill`-based liveness check in this shell is a no-op (e)2).
4. **Two timestamp-arithmetic errors in one hour**: (a) `ls -t` on profile links surfaced system-840 (mtime sort ≠ generation order — GC/boot-mirror touching mtimes) and I initially called it "the newest"; (b) uptime math "574s → restarted 17:49" was off because I misjudged the current time (it was 17:48). Both corrected within minutes, but both were careless reads of time-ordered evidence.
5. **Resource discourtesy**: I ran TWO full post-deploy batteries (17:46, ~17:52) while the box was at PSI 37–65% — the parallel session likely ran its own. Three batteries + keep-going builds on a storming box is exactly the "warm-build coordination" failure I wrote into the gotchas entry in the SAME session. Mitigation: batteries are mostly cheap probes, and the second run was justified by the 13→5 delta; but the third would have been pure duplication of the storm-suspect noise, which is why I stopped.

## e) WHAT WE SHOULD IMPROVE! (process, concrete)

1. **Anchor verification must wait for the deploy's full process TREE**: single-PID liveness is insufficient — `nh` self-elevates through sudo and the profile `--set` lands LATE. Correct probe: `pgrep -f 'nh os|switch-to-configuration'` empty + THEN compare `readlink /run/current-system` to the NEWEST generation by NUMBER (`ls …/system-*-link | sort -V | tail -1`), never by mtime. This should go into the deploy anchor discipline paragraph in AGENTS.md.
2. **`kill` (any form, including `kill -0`) is dead in this shell — add the wait-loop corollary to the AGENTS trap line**: liveness checks must use `pgrep -f`/`/proc/<pid>` existence, never `kill -0`. The line I added documents the signal-delivery failure but NOT that conditional loops silently never wait.
3. **Probe-masking needs to be mechanical, not aspirational**: I knew the rule and still leaked argv secrets. The fix is a habit loop — `pgrep -af X | grep -vE 'secret|token|key'` is not enough (values are IN the args); the reliable form is `pgrep -af X | cut -d' ' -f1` (PIDs only) or sed-redacting everything after sensitive flags. Consider a tiny `scripts/redact-argv.sh` helper + a line in the AGENTS probe bullet.
4. **Batteries under storm should be serialized**: post-deploy-check re-runs are idempotent and cheap individually, but 3 concurrent runs (two sessions) inflate the very PSI that downgrades their own load-sensitive checks to STORM-SUSPECT. The storm-mode banner should carry a "another battery ran within N minutes" hint, or the check should take a lockfile.
5. **The flm check needs guard-awareness**: a hard FAIL for a by-design guard sacrifice trains operators to ignore the check. The check should read the guard state (journal or the guard's own metrics — `sev1_bridge_alerts_active`/trip metrics exist) and downgrade to WARN with "guard sacrifice active, auto-restores" when Zone-6 owns the socket.
6. **"Verified clean" claims need their evidence class named**: my mainProgram audit "verified clean" covers only the eval-forced surface; lazy paths (packages never forced in the toplevel eval) are unprobed. The report now says so (b)-grade, not a)-grade — I initially labeled it DONE without the caveat.
7. **Journal-driven app logs leak secrets** (monitor365 server logs a full SsoConfigRow incl. client_secret at INFO): server-side fix belongs upstream (redact secrets in tracing), SystemNix-side nothing. Noted for the upstream row family.

## f) NEXT — up to 50, ranked; [LIVE] = parallel session's queue, do not duplicate

1. **[ready] flm post-deploy check guard-awareness** — detect memory-guard sacrifice state (guard metrics/journal) and downgrade the :52625 check to WARN with the restore note; today it hard-FAILs by design. Impact: Medium · Effort: S · pipeline.md.
2. **[ready] Third battery run post-storm** — verify BOTH check fixes flip green (dnsblockm limit + catalog marker), flm socket restored (`ss -ltn | grep 52625`), tq-pool admitted + stable, dev-cv zombies reaped. Impact: Medium · Effort: S.
3. **[blocked:user] monitor365 agent re-enable confirmation** — the deploy restarted the enabled unit; the 2026-10-21 owner stop made restarts owner-gated pending the tenant event-cap restore (1B/day still vs rec 250k; collectors cut, so volume is low). If unintentional: stop + mask the unit; if intentional: update the CHANGELOG owner-gate note. services.md.
4. **[ready] hermes-agent push + lock bump** (owner pushes; agent then `--update-input hermes-agent`) — clears the stdenv.isLinux eval warning; also verify the local clone's push-state first (unpushed daemon commits there may need landing). upstream.md row exists.
5. **[ready] 'system' rename warning: final attribution** — after the hermes bump, `NIX_ABORT_ON_WARN=1` on `config.systemd.services` gives a clean trace; fix shape already documented (explicit `stdenv.hostPlatform.system` pin). pipeline.md row exists.
6. **[ready] monitor365 upstream: stop logging full SsoConfigRow at INFO** (client_secret lands in the journal — observed live this session). Add to the upstream monitor365 family.
7. **[ready] AGENTS.md: anchor-verification procedure upgrade** — process-tree liveness + generation-NUMBER comparison (e)1); one paragraph edit in the deploy anchor discipline section.
8. **[ready] AGENTS.md: kill-builtin trap addendum** — `kill -0` in loops never waits (the wait-loop victim); extend the trap line I added.
9. **[LIVE] lock gate + nixpkgs pin durability** (their §f.3/4) — the gate that refuses unbuilt floats; the rollback pin needs an allowlist entry with a LIFT condition.
10. **[LIVE] `nix flake check --no-build` after the rollback** (their §f.14) + VM-test eval legs — the toplevel eval is green; the check matrix is not yet re-proven on fe13242.
11. **[LIVE] node-26.12.1 prebuilt segfault upstream issue** (their §f.6) with the store-path + `26.12.0`-works evidence.
12. **[LIVE] rollback-exit criteria** (their §f.10) — how long fe13242 stays; per-package shims vs waiting for upstream fixes.
13. **[LIVE] post-rollback service verifications** (their §f.31–36: Gatus, SigNoz dashboards, Hermes/DMS start, templ-components, pre-vacuum gate).
14. **[ready] SigNoz coverage dark four** (hermes, monitor365-server, papdashboard, PMA) — pre-existing; hermes likely explains itself after its input work; PMA/papdashboard need their own OTel wiring checks. monitoring.md candidate.
15. **[ready] CHANGELOG tag refresh** — my shims entry says "deploy pending"; the deploy LANDED (shims dormant on 7.2.10). One-word accuracy fix when touching CHANGELOG next.
16. **[watch] flm socket restore** — confirm the guard re-arms :52625 once PSI clears (the module promises it; tonight's storm is the live test of the RESTORE branch).
17. **[ready] probe-masking helper** — `scripts/redact-argv.sh` or a documented sed pattern + AGENTS probe-bullet line (e)3).
18. **[decision] battery lockfile or cooldown** under storm mode (e)4).
19. **[ready] battery storm banner hint** "another battery ran <N> min ago" (e)4).
20. **[watch] hermes-agent local clone** — unpushed daemon commits may be accumulating there; owner sweep before push.
21. **[ready] dev-cv squatter prevention** — the 01:29 `go run` survived 16h because nothing owns dev-process hygiene; consider a login-shell reminder or a daily reaper for `go run`/`cargo run` processes older than N hours in user sessions (owner tolerance unknown — ask before building).
22. **[watch] architecture-catalog title stability** — the rebrand fixed the marker once; if the hub CI retitles again the check breaks the same way. The marker could grep for BOTH titles.
23. **[ready] `docs/services/monitor365.md` runbook update** — the watchdog's circuit-breaker restart behavior + grace-window interaction with the post-deploy check (the check's "not connected" FAIL is expected for ~2 min after every restart; the runbook should say so).
24. **[ready] queue-row for the third battery** should fold in the 17:13 report's §f.30 "capture the diff" so one run serves both sessions' verifications.
25. **[decision] secrets-on-argv sweep** — monitor365 `--jwt-secret` and crm `-api-token` both ride argv TODAY (both observed live this session; both world-readable via /proc). Both have upstream rows queued already (JWT one exists; add the crm api-token one) — but the SystemNix-side LoadCredential/EnvironmentFile conversion could land independently of upstream. Owner call on sequencing.

(Frozen at 25: the remaining candidates are the LIVE session's §f restated or ROADMAP-grade ideas — padding to 50 would violate the harvest schema's specific-and-actionable rule.)

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **monitor365 agent**: the deploy restarted it (unit is enabled in config). Was the re-enable intended since the 2026-10-21 owner stop, or should I stop+mask it until the tenant event-cap is restored to ~250k/day? (The collectors are cut, so the immediate volume risk is low — but this is your data-governance call, not mine.)
2. **hermes-agent push**: the local clone carries my stdenv fix (+ possibly other unpushed daemon commits). Should I prepare the push/PR flow, or do you push that repo yourself? (It's NousResearch upstream — a direct push vs fork-PR matters if you don't have write rights there.)
3. **Deploy cadence tonight**: the box is still storming (PSI ~50–60% at 18:08, 20+ live agent sessions). If another deploy becomes necessary (e.g. the lock floats again — 7 floats today), do you want a hard rule "no deploys while io PSI avg10 > 40%", or is deploy-anytime acceptable as long as pre-reboot-check passes?

---

## Evidence (this pass)

| Fact | Command | Result |
| --- | --- | --- |
| Tree green | `nix build …toplevel --keep-going --no-link` (17:14) | exit 0, final drv `z38nwd…fe13242` |
| Pre-deploy gate | `nix run .#pre-deploy-check` | 103 passed / 0 failed / 13 warn |
| Deploy anchored | `readlink /run/current-system` vs `system-939-link` | both → `z38nwdbirsmnqjkxpw6nkaq95w4sx15i` |
| Post-deploy regressions | battery ×2 + baseline file | 13→5 FAIL, all in `smoke-fail-baseline.txt` |
| monitor365 reconnect | journal 17:48:02 + `:3001/health` | `Agent SSE connected device_id=evo-x2`; `connected (1 devices)` |
| flm sacrifice cause | `journalctl 17:36:35–17:36:50` | memory-guard Zone-6 trip stopped the socket ("the trip already stopped the sockets") |
| Guard restore promise | fastflowlm.nix:35-36 | "the guard restores the socket once memory has recovered past a margin" |
| Catalog rebrand | dist gen `20261023-170000` title + live probe | `<title>LarsArtmann Architecture Catalog` both sides |
| dnsblockd real state | cgroup `memory.max`/`memory.current` | 4G / ~1G (anon 790M + file 227M) |
| stdenv.isLinux site | NIX_ABORT_ON_WARN + show-trace | hermes-agent.nix:162 optionals, via dbus-broker unit text ← session-boot-audit assertions |
| hermes fix verified | `nix eval ~/projects/hermes-agent#packages…default.drvPath` | 0 `stdenv.isLinux` warnings (local tree) |
| 'system' bisect | subtree evals ×5 | fires in systemd.services/units; not user.units/systemPackages |
| Dev cv squatter | ps lstart + ss pid= | up since 01:29, held *:8201; killed, port freed |
| kill builtin trap | typed `kill -9` ×3 | `kill: unsupported builtin`, rc=2, no signal delivered |

**HARVEST note (docs-health contract):** items f)1–2 + f)23 queued into TODO_LIST.md at authoring time; f)3 landed as `[blocked:user]` in docs/todo/services.md; f)6 appended to the monitor365 upstream family; f)4/5 already queued (upstream.md / pipeline.md — enriched earlier this pass); f)7–8 landed in AGENTS.md at authoring time; f)14 candidate noted for monitoring.md harvest; [LIVE] items deliberately NOT re-queued (the 17:13 report owns them — recorded here as "deliberately not harvested because live session owns it").

---

## Follow-through pass (18:10–18:3x, same conversation, user-directed "keep going")

Executed the remaining [ready] §f items that needed no owner input and no calm box:

| §f | Item | State | Evidence |
| --- | --- | --- | --- |
| f.1 | flm guard-awareness | **DONE** | post-deploy-check.sh flm block now reads `memory-emergency-guard.prom`: `sacrifice_socket_active 0` AND (`last_trip_recent 1` OR `restore_capped 1`) → WARN, two distinct messages (self-restore vs budget-exhausted owner-handoff). Conservative attribution: an unexplained dead socket falls through to the probe and FAILs honestly. `bash -n` + shellcheck clean; live dry-run against the real .prom (sacrifice=1 capped=1) fired the capped branch. Rows ticked (TODO_LIST:1705 + pipeline.md). |
| f.19 | battery cooldown banner | **DONE** | Every battery start stamps `~/.local/state/systemnix/post-deploy-last-run.epoch`; a start <60 min after the previous prints the overlap NOTE. Advisory-only by design (the lockfile/cooldown [decision] f.18 stays owner-gated). |
| f.17 | probe-masking helper | **DONE** | `scripts/redact-argv.sh` (flag-with-value + env-assignment shapes, conservative over-mask doctrine) + `scripts/test-redact-argv.sh` selftest (12 shapes, all hold) + AGENTS.md probe bullet now NAMES the script. Live-verified against real argv: `monitor365-server --jwt-secret=REDACTED`, `crm-server -api-token=REDACTED`, keyword-free argv byte-identical. |
| f.15 | CHANGELOG tag refresh | **DONE** | Shims entry retagged: deployed in gen-939 on the rolled-back lock (fe13242, kernel 7.2.10) — shims DORMANT, activate on the next forward lock move. The OTHER ~7 "(…, deploy pending)" entries (lines 17-53) were left to their owning sessions — mass-retagging needs per-entry activation verification (owner-gated agent restarts etc.), not a blanket stamp. |
| f.23 | monitor365 runbook grace-window | **DONE** | Bullet added to docs/services/monitor365.md (SSE reconnect ≤~2 min after any restart; FAIL inside window expected — re-probe or read the watchdog journal). Rows ticked (TODO_LIST:1707 + services.md:748). |
| f.2 | third battery | **PARTIAL — deferred with substance** | Storm-safe targeted probes replaced the full run (see below); full battery + §f.30 diff capture stays queued. PSI avg10 hit 80% at 18:2x under THREE parallel nix builds (`tls-vm-test`, `checks.build --keep-going`, `nix flake check`) + Go tests + the monitor365-ui FOD — running the battery then would be the §d.5 double-battery failure class, now banner-guarded by f.19. |

Targeted probe results (the battery's substance without its load):

| Probe | Result |
| --- | --- |
| dnsblockd memory (check fix 1) | **PASS** — 926MB < 4096MB deployed limit, read via cgroup `memory.max`/`memory.current` (typed `systemctl` is guard-blocked). Honest caveat: today's steady state passes under the OLD check too; the fix's discriminating case was the 3276MB transient — the fix is verified STRUCTURALLY (derivation reads the deployed 4G). |
| Catalog marker (check fix 2) | **PASS** — `<title>LarsArtmann Architecture Catalog` present in the served index. Legitimate companion WARN: `architecture_catalog_fresh 0` (hub sync stale in the storm window — the check's WARN message points at `architecture-catalog-sync`; worth a look when calm, not a regression). |
| flm guard-awareness (check fix 3, this pass) | WARN branch confirmed live: `sacrifice_socket_active 0` + `restore_capped 1` (141 restores total, 5 zone-6 trips in the last hour at 18:2x). **The socket will NOT self-restore today** — daily budget exhausted; owner handoff or midnight reset (f.16 watch row updated via the battery row note). |
| dev-cv zombies 3758025/3758499 | **gone** — both reaped. |
| tq-pool | **stable** — `tq serve` + `tq agent-pool` running, :8081 listening, a tq done-prompt reporter actively working. |

Coordination notes: CHANGELOG.md and the todo surfaces showed foreign mid-session modifications (parallel sessions + daemon sweeps at 18:10-18:11) — every edit was re-read before re-applying; TODO gate (`check-todo-system.sh`) rc=0 after all row edits. The untracked `docs/status/2026-10-23_18-09_dnsblockd-via-netbird-phone-dns-session.md` belongs to its own session (its B5 deliberately left the battery to this queue — honored).
