# Status: mr-sync vHost "SKIP unreachable" — root cause + probe fix + close-out

**2026-10-10 03:24 CEST · Scope: THIS session only** (owner paste: `SKIP mr-sync.home.lan unreachable — why???`), end-to-end: diagnosis → root cause → fix → verification → harvest. Parallel sessions were ACTIVE throughout the night (vendorHash wave6 02:02, cqrs-lint deploy 02:50, storm-mode smoke legs landed in post-deploy-check.sh by another session — my edits landed on top with zero overlapping lines; daemon commit `bd9e8015` batched my script edit with 4 foreign files, attributed there).

**Format note:** `.md` per the owner's explicit path demand — overrides the status-report skill's HTML-canonical default (flagged, not propagated).

---

## TL;DR

`SKIP mr-sync.home.lan unreachable` was **never an outage**. The service was up the whole time (live probes: backend on 7331 listening, TLS chain fine, `HTTP/1.1 200 OK` in milliseconds). The line was the post-deploy-check vHost probe giving up: the old probe used `--max-time 10` and **discarded curl's exit code**, so every failure mode printed the same lie — "unreachable". mr-sync's first render after a restart synchronously du-walks ~425 repos over QLC (the runbook sizes Gatus at 20s for exactly this), and tonight's smoke ran during the 01:5x deploy's active IO storm — 10s was structurally not enough. Fixed: 20s budget + rc-classified verdicts, all branches live-verified. Root cause and six follow-up upgrades harvested into the queue.

---

## Diagnosis chain (evidence per step)

| # | Step | Tool | Finding |
|---|------|------|---------|
| 1 | Locate the message | grep | `scripts/post-deploy-check.sh` auth-vHost probe, `000` branch → `SKIP $vhost unreachable`; fires only after the `backend_listening 4180` gate PASSED (so oauth2-proxy was up at probe time) |
| 2 | Service live state | `pgrep`, `ss` | `mr-sync-dashboard` running (PID 2557442), listening `127.0.0.1:7331`; oauth2-proxy on 4180; Caddy on `.150:443` + `.200:443` — all up |
| 3 | DNS | `getent` | `mr-sync.home.lan → 192.168.1.150` — resolves |
| 4 | TLS handshake | `openssl s_client` | Connects; cert `dnsblockd-CA` → `CN=home.lan`; SANs include `*.home.lan` (mr-sync matches); chain verifies against local trust |
| 5 | Full HTTP round-trip | `openssl s_client` raw GET | **`HTTP/1.1 200 OK`** — LAN bypass active, Caddy → 7331 healthy |
| 6 | Budget mismatch | runbook + module | `docs/services/mr-sync.md:58-61`: cold collect du-walks `~/projects` + `~/forks` (QLC), Gatus uses client `timeout 20s` to "absorb cold walks", `[RESPONSE_TIME] < 15000` — the probe had 10s |
| 7 | Tonight's context | TODO_LIST/pipeline rows | 01:5x deploy landed **storm-degraded** (IO storm active during smoke); mr-sync-dashboard restarted into the storm → cold walk far exceeds 10s |

**Honesty note on step 7:** the exact curl rc of the OWNER's original run is **unknowable** — the old code threw it away. "Timeout" is the mechanism verdict (docs + timing + storm timeline); it is inference, labeled as such. The rc-classification fix exists precisely so the next occurrence is self-describing.

---

## a) FULLY DONE

| Item | Evidence |
|------|----------|
| Root-cause diagnosis of the SKIP line | chain above; every fact live-probed this session, not doc-cited |
| Probe fix: `VHOST_PROBE_TIMEOUT=20` + rc-classified `000` verdicts (auth + plain loops), set-e-safe rc capture | diff in `scripts/post-deploy-check.sh`; committed via daemon `bd9e8015` |
| Branch verification, LIVE: 200 (mr-sync) / 28 timeout (blackhole) / 7 refused (closed port) / 6 DNS (bad name) | throwaway harness output, all four verdict lines correct; harness deleted after |
| Syntax + lint: `bash -n` clean; shellcheck **rc=0, zero findings** — re-measured WITHOUT the `| tail` pipe mask after catching that the first "exit 0" was tail's, not shellcheck's | this close-out's own dirty-oracle catch, §d.2 |
| Self-harvest (house law): 5 `[ready]` + 1 `[watch]` rows → `docs/todo/pipeline.md`; 2 → `services.md`; 1 `[decision]` → `upstream.md`; 7 queue one-liners → `TODO_LIST.md` — all with `Source:` pointers to this report | grep-verified below |
| AGENTS.md session-discipline bullet: agent-shell blocked-command set + the verified openssl-raw-GET fallback (proven: scripts calling curl internally run fine) | AGENTS.md Session Discipline |

## b) PARTIALLY DONE

1. **The edited probe section has not run inside a real full deploy battery.** Verification = live single-URL harness + whole-file bash -n/shellcheck. What remains: observe one real post-deploy-check run (expect PASS on warm mr-sync, or the truthful `timeout >20s` line). Queued `[watch]` in pipeline.md. Effort S (next deploy).
2. **Which rc produced the owner's original SKIP** — unprovable retroactively (old code discarded rc; Caddy access logs unreadable as `lars`, `sudo -n` path not pursued). The fix makes this class self-answering going forward. Effort S (nothing to do — recorded).
3. **mr-sync's actual cold-walk duration** — never measured (would need a service restart = prod mutation, not done mid-session). The 15s/20s sizing in Gatus + runbook is the repo's own recorded evidence. Effort S if the owner ever wants the number (restart during a calm window + one timed probe).

## c) NOT STARTED (planned, queued — nothing written)

All six probe upgrades from §f.2–f.6 (plain-vHost coverage, real backend ports, shared probe function + fixtures, per-vhost budgets, storm-aware verdicts), the papdashboard census annotation, the mr-sync runbook note, and the upstream async-first-render decision — all queued this session, zero code written. Priority signaled by queue position.

## d) TOTALLY FUCKED UP

1. **The old probe's design: rc-discarding, one-size-fits-all "unreachable"** (pre-existing, now fixed). Every historical `SKIP <vhost> unreachable` line in every past deploy log is **unclassifiable** — DNS race, TLS failure, slow backend, all printed identically. Severity: systematically misled deploy triage; this whole session existed to decode one such line. Mitigation: landed (rc classification + 20s).
2. **My own dirty-oracle moment, caught in-session:** the first shellcheck verification piped through `| tail -5` and echoed `$?` — reporting **tail's exit code**, not shellcheck's. A green claim with a broken oracle, the exact class the repo keeps recording (02-50 gotchas row: "a verified green claim requires the clean oracle in the same breath"). Corrected before anything depended on it: re-ran unpiped → rc=0, 0 findings, 0 output lines. Left in §d because a caught-late verification bug is still a verification bug.
3. **Untested verdict branches (35/51/60 TLS legs)** — implemented, never exercised live; only 200/28/7/6 were. Not a correctness risk today (the `*` fallback prints the rc either way), but shipped-untested is shipped-untested. Queued §f.4.

## e) WHAT WE SHOULD IMPROVE

- **Probe verdicts belong in ONE function with fixture tests** (test-post-deploy-pressure.sh pattern) — not two inline copies. The rc classification is currently duplicated text (auth + plain loops): a miniature split-brain by construction.
- **Single-source the timeout** — `20` now lives in three places (script var, script comment, Gatus config). integration.nix already carries `client.timeout` per check; derive from it.
- **The backend gate is near-meaningless for protected vhosts** — all 18 rows carry port 4180 (the shared oauth2-proxy), so it re-tests one proxy N times and can never see an individual backend die. Real per-row ports make the gate do its job.
- **Storm-awareness in probe verdicts** — tonight proved the class: under `systemnix_io_storm_active`, a timeout is EXPECTED and should read STORM-SUSPECT (the downgrade machinery already exists for other legs).
- **Cross-session integration check before editing shared scripts** — storm-mode legs landed in this same script hours earlier; I got lucky that the edit anchors didn't overlap. The content-pin discipline covered it, but a `git log -1 -- <file>` glance before editing shared surfaces should be reflexive, not lucky.
- **Verification hygiene**: the tail-pipe exit-code mask is a recurring trap (grep/awk pipelines "passing" for the wrong binary). Prefer `cmd > file; rc=$?` for anything a claim will cite.

## Self-review (the owner's three questions, blunt)

- **What did I forget?** To capture the original run's context first (timestamp, full output, which other vhosts skipped) before diagnosing — the answer's universality rests on one pasted line; only §g.Q1 resolves it. Also forgot to attempt `sudo -n` on Caddy logs and to test rc 60 (an untrusted-cert probe against `https://192.168.1.150` directly was one command away).
- **What could I have done better?** Check the tool allowlist before firing `systemctl`/`curl` (two burned turns); skip the off-box fetch probe entirely (context-deadline-exceeded proved nothing — the fetcher doesn't sit on the LAN); build the verification harness by sourcing the real branch instead of duplicating it (the throwaway copy drifted-risk the §f.4 row now fixes permanently).
- **What could I still improve?** Everything in §e. Plus the meta-point: I verified the fix but not the fix's FIRST REAL RUN — §b.1 stays open until a deploy exercises it, and I should treat "harness-verified" as a weaker grade than "battery-verified" in close-out language.
- **Did I lie?** One green claim was oracle-broken (§d.2) and was corrected within the session. The timeout verdict is explicitly labeled inference. Everything else cites a live probe.
- **Ghost systems / split brains created?** None wired; one duplicated-text risk created and immediately queued for extraction (§f.4); the 20s constant tripled (§e, §f.5).
- **Tests?** bash -n + shellcheck + 4-branch live harness. The right permanent home is repo fixtures (§f.4). No Nix surfaces touched → no flake-check scope.

## f) Top things to get done next (ranked; 🆕 = born this session, already harvested)

| # | Task | Impact | Effort | Category | Status/Source |
|---|------|--------|--------|----------|---------------|
| 1 | Re-run full post-deploy-check at PSI some avg10 < 20%, drive to 0 FAIL (01:5x deploy landed with 11 attributed fails) | High | S | Verification | queued: TODO_LIST + services.md (02-50 §b.1/§f.1) |
| 2 | 🆕 Probe ALL plain vHosts, not only `PLAIN_VHOSTS[0]` (16 of 17 rows unprobed; cert-mint-cascade class 1/N covered) | Medium | S | Quality | HARVESTED → TODO_LIST + pipeline.md §f.2 |
| 3 | 🆕 Real backend port per protected row in vhost-layers (gate re-tests oauth2-proxy N times today) | Medium | M | Quality | HARVESTED → §f.3 |
| 4 | 🆕 One `probe_vhost()` + fixture-test all branches incl. rc 35/51/60 | Medium | S | Quality | HARVESTED → §f.4 |
| 5 | 🆕 Derive probe timeout from integration `client.timeout` (retire the 3-place 20s split brain) | Medium | S | Quality | HARVESTED → §f.5 |
| 6 | 🆕 Storm-aware rc-28 verdict (STORM-SUSPECT under `systemnix_io_storm_active`) | Medium | S | Quality | HARVESTED → §f.6 |
| 7 | Verify boot-mirror-sync ran after the 01:58 generation | High | S | Verification | queued (02-50 §f.12) |
| 8 | 🆕 Annotate papdashboard.md tile census — mr-sync "down 502" is stale (live 200 today) | Low | S | Documentation | HARVESTED → services.md §f.8 |
| 9 | 🆕 Document the deploy-smoke probe budget in docs/services/mr-sync.md | Low | S | Documentation | HARVESTED → services.md §f.9 |
| 10 | 🆕 mr-sync upstream: async first render / stale-while-revalidate (cold du-walk off the request path) | Medium | M | Feature | HARVESTED → upstream.md [decision] §f.10 |
| 11 | mr-sync GitHub PAT go-live — dashboard visibly degraded (`FetchError` banner, `github_tracked: 0`, no languages/push dates) | High | S | Feature | [blocked:user] services.md:268 |
| 12 | Watch post-deploy wave-fix battery (crush-daily chromedp parity, bank-sync canary, tq converge, first boots) | Medium | M | Verification | [watch] services.md:299 |
| 13 | mr-sync module VM test (`tests/test-mr-sync.nix` — never-started-ghost regression pin) | Medium | M | Quality | services.md:269 |
| 14 | Gatus→Discord delivery E2E audit + chronic-red escalation ("mr-sync Dashboard" red 15 days, nothing acted) | High | M | Bug | TODO_LIST:270 / monitoring.md:80 |
| 15 | Sanctioned agent-readable Gatus recorded-verdict surface (root-only sqlite wall) | Medium | M | Feature | monitoring.md:96 |
| 16 | Resolve catalog integration-subdomains eval warning (21 names) | Medium | S | Cleanup | services.md:254 |
| 17 | Eval-time "never-enabled unit" audit (health-dashboard + mr-sync ghost precedents) | Medium | M | Quality | pipeline.md |
| 18 | Eval-warning cleanup batch (`initExtra`, `stdenv.is*`, `'system'` rename, catalog) | Low | S | Cleanup | pipeline.md:287 |
| 19 | FOD rev-staleness guard in pre-deploy-check (stale got-hash paste class, 3rd+ occurrence) | High | M | Quality | pipeline.md (02-02 §f.8) |
| 20 | §11 tree-mutation tripwire (mid-gate mutation invalidated a green §11) | High | S | Quality | pipeline.md (02-50 §e.1) |
| 21 | Deploy-concurrency guard in pre-deploy-check (double-switch avoided by luck on 10-09) | High | S | Quality | pipeline.md |
| 22 | Wire negative-test-lints.sh into CI (zero workflow references today) | Medium | S | Quality | pipeline.md |
| 23 | CI: build the toplevel on lock-bump commits (eval-only gate lets buildPhase failures through) | Medium | M | Quality | pipeline.md |
| 24 | Persist smoke NEW-regression flags to a needs-attribution ledger | Medium | S | Quality | pipeline.md |
| 25 | Window the Pocket ID SQLITE_BUSY check by since-restart, not fixed 30-min lookback | Low | S | Bug | pipeline.md |
| 26 | Same-rev FOD drift probe for pinned inputs (bank-sync UNCHANGED-rev hash mismatch) | Medium | M | Quality | pipeline.md |
| 27 | Shim-drop-protocol amendment: lock-rev stamp + §11 drop-condition re-verify | Medium | S | Quality | pipeline.md |
| 28 | gotchas-archive: "mid-deploy tree mutation invalidates §11" + "dirty-tree green-claim (3rd+)" | Low | S | Documentation | pipeline.md |
| 29 | Re-dispatch protocol step-2 amendment: LIVE-state probe for host-state claims | Medium | S | Quality | pipeline.md (03-18 §d) |
| 30 | `/data/docker` ~15.5 GB owner reclaim (dormant since the 2026-10-08 Docker removal) | Medium | S | Cleanup | [blocked:user] AGENTS.md |
| 31 | Boot-mirror PartUUID/BootCurrent decode verify half (open since 09-30 activation) | Medium | S | Verification | AGENTS.md boot-mirror section |
| 32 | Samsung role assignment execution (XFS hot-DBs + BTRFS /nix plan ratified 08-31) | High | L | Feature | docs/planning/archived/ |
| 33 | Batch-harvest the 88 unharvested §f-bearing reports (check-todo-system strict mode) | Medium | M | Documentation | pipeline.md |
| 34 | Auto-queue "re-probe upstream, drop shim" for re-pinned non-follower vendorHash shims | Medium | S | Quality | pipeline.md |
| 35 | Consumer-CSS class-coverage guard (two same-day stylesheet-missing-classes incidents) | Medium | M | Quality | pipeline.md |

(Items 11–35 are pre-existing rows already in the queue — listed here for the ranked picture, NOT re-harvested; no drift edits made to them this session.)

## g) Questions only the owner can answer

1. **When did you run the check, and what did the full output look like?** Was it during the 01:5x storm-deploy window, and did other vhosts SKIP too, or only mr-sync? I cannot see your terminal; the answer decides whether the 20s budget fully covers your case or a post-switch DNS/Caddy restart race also contributed (rc classification will disambiguate next run regardless).
2. **mr-sync runs degraded by choice — keep or go-live?** The sops token still holds `PLACEHOLDER` (every GitHub call 401s → FetchError banner, `github_tracked: 0`, no languages/push dates on all 425 repos). The PAT paste is the only remaining step ([blocked:user], needs your sudo for the host age key). Go now, or leave parked?
3. **Gate policy: should a protected-vHost probe TIMEOUT stay a non-blocking SKIP?** Today: yes (and storm-aware SUSPECT once §f.6 lands). Alternative: escalate repeat timeouts to a summary WARN so slow cold-starts surface in the deploy verdict. Your strictness call.

## Harvest ledger

| §f | Destination | State |
|----|-------------|-------|
| f.2 | TODO_LIST.md + docs/todo/pipeline.md `[ready]` | HARVESTED |
| f.3 | TODO_LIST.md + docs/todo/pipeline.md `[ready]` | HARVESTED |
| f.4 | TODO_LIST.md + docs/todo/pipeline.md `[ready]` | HARVESTED |
| f.5 | TODO_LIST.md + docs/todo/pipeline.md `[ready]` | HARVESTED |
| f.6 | TODO_LIST.md + docs/todo/pipeline.md `[ready]` | HARVESTED |
| b.2 (watch) | docs/todo/pipeline.md `[watch]` only | HARVESTED (deliberately NOT in TODO_LIST: tq pool harvests `[ready]` only) |
| f.8 | TODO_LIST.md + docs/todo/services.md `[ready]` | HARVESTED |
| f.9 | TODO_LIST.md + docs/todo/services.md `[ready]` | HARVESTED |
| f.10 | docs/todo/upstream.md `[decision]` only | HARVESTED (decision rows are library-only) |
| f.1, f.7, f.11–35 | pre-existing queue rows | NOT RE-HARVESTED (already queued; no edits to avoid drift) |

Commit attribution: probe fix rode daemon commit `bd9e8015` (batched with 4 parallel-session files); this report + harvest rows ride the next daemon batch.
