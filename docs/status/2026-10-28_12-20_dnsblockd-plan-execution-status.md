# dnsblockd Pareto Plan — Execution Status (2026-10-28 12:20)

**Plan under execution:** `docs/planning/2026-10-28_10-40_SUPERB-dnsblockd-integration-plan.md`
(27 tasks / 115 ≤12-min steps, tombstone `EXECUTING (crush-dnsblockd-exec-1)`)
**Session window:** 2026-10-28 10:56 → 12:20 CET · **HEAD at writing:** `90f44ac70` · **origin:** in sync (0 ahead / 0 behind)
**Source of the findings this executes:** `docs/architecture-understanding/2026-10-28_10-18_dnsblockd-integration.html` (3.57/5) and
`docs/status/2026-10-28_10-32_dnsblockd-integration-review-status-and-self-review.md`

**Bottom line:** 10 of 27 plan tasks are implemented, verified, and committed; 1 is partial; 16 remain and every one of them is gated by
something I cannot do from an agent shell (deploy/root, an owner decision, or an upstream release). The two defects the review called
*concrete* are both closed **in-tree** — but neither is ACTIVE on the host until a deploy runs, which needs root.

---

## Verification actually performed this session

| # | Command / probe | Result |
| --- | --- | --- |
| V1 | `nix build .#checks.x86_64-linux.dnsblockd-readiness-gate` | green — `5/5 legs passed (2 negative, 3 positive)` |
| V2 | `nix build .#checks.x86_64-linux.dnsblockd-ca-parity-selftest` | green — 8 real-certificate fixture legs |
| V3 | `nix build .#checks.x86_64-linux.dns-blocker-render` | green — incl. the 7 new rpi3 parity assertions |
| V4 | `bash scripts/test-ca-parity-smoke.sh` | `PASS: all 8 dnsblockd CA-parity fixture legs` |
| V5 | `nix flake check --no-build` | **exit 0** (only the expected aarch64-darwin omission) |
| V6 | `bash scripts/check-todo-system.sh` | `OK: TODO queue/library structure clean` (145 unharvested-report WARN = pre-existing class) |
| V7 | `bash scripts/audit-shell-nullglob.sh` / `audit-textfile-tmp.sh` | `fail=0` both |
| V8 | Live: new gate script against real `ss` | exit 0 (finds `:53` on UDP **and** TCP) |
| V9 | Live: §22 CA parity against the real trust bundle | `WARN — trusted and identical, but the bundle appends the same CA 2x` |
| V10 | Live: §23 filter-proxy probe against the running unit | `PASS — 3 proxy keys rendered, no filter domains armed, unit active` |
| V11 | Rendered Gatus endpoint diff (T12) | 245 → 245 endpoints, `DNS Blocker` object **byte-identical** |
| V12 | Shipped observer script, path-redirected, 3 runs | healthy → `observer_ok 1`; set backdated 40d → `refresh_stale 1`; dead stats port → `observer_ok 0` + `export_broken 1` |
| V13 | T22 negative test (`lib.mkForce { }` over `services.caddy.virtualHosts`) | exactly 1 matching failed assertion, eval otherwise clean |
| V14 | `nix eval … security.pki.certificates --apply length` | `1` (so the duplicate CA is not a doubled option entry) |

---

## a) FULLY DONE

1. **T01 — the readiness gate now proves the DNS contract.** `dnsblockd-wait-listener` polled `ss -ltn` for `cfg.blockPort`
   (:80, TCP) while its own comment, its budget rationale and two queue rows all said "the :53 listener". It now probes
   `ss -ltnu` for `ports.dns-blocker` (53) on UDP **and** TCP, reads that port from the same registry entry the render writes
   into `dns_port` (so gate and binary cannot drift), and treats a single-transport bind as a **warning**, not a failure —
   restarting a resolver that still answers is the outage the gate exists to prevent. Verified: rendered config store path
   unchanged (`kxgximh…`, i.e. zero render drift), 5/5 selftest legs, live exit 0 against the real listener map.
2. **The negative test the gate never had** — `checks.dnsblockd-readiness-gate` executes the **deployed** script (taken from
   the unit's `ExecStartPost`, so a refactor that stops installing it fails here) against five fixture listener maps: a
   `:80`-only map and a `:5355`-only map must FAIL, `:53` both transports passes silently, UDP-only passes with a warning,
   a broken probe fails OPEN. This is what makes the regression impossible to reintroduce silently.
3. **T02 — CA parity is enforced.** The same CA lives in the trust store and in the sops secret the block-page proxy signs
   with; nothing compared them. `post-deploy-check.sh §22` now enumerates the bundle (296 certificates), fingerprints every
   `dnsblockd-CA`, and **FAILs** when the served CA is untrusted or a retired one is still trusted (a leaked old key would
   otherwise keep its power to intercept), **WARNs** on a duplicate entry and on <90-day expiry. Logic is a sourced library
   (`scripts/lib/ca-parity-smoke.sh`) driven by 8 fixtures with **real openssl certificates**, so every branch is exercised
   rather than asserted. Rotation procedure written up in the runbook ("CA rotation").
4. **T07 — doc-claim sweep.** `docs/agents/monitoring.md` claimed dnsblockd's `wiring = "config"` works; live it has been dead
   for the entire outage (964→991 refusals this boot, `otelInternalErrors` 40,667 → 49,450 and climbing ~14/min). Annotated
   inline with a dated LIVE CORRECTION, the cause and the structural lesson (`wiring = "config"` records CONFIG, never a live
   sample, and needs an expiring last-verified date). `docs/agents/sso-dns.md` was verified: its only dnsblockd content is
   provisioning history, nothing contradicted.
5. **T12 — registry inversion.** The HTTP `/health` check moved out of the shared monitoring list into
   `services.integration.dnsblockd.checks`; the three raw DNS protocol probes stayed, with a comment naming the `:53` contract
   they guard. Proven by diffing the rendered endpoint set: **245 → 245, zero added/removed, `DNS Blocker` byte-identical**.
6. **T13 — rpi3 parity pinned.** Seven eval-level assertions now pin both halves of the secondary host: it must keep the
   blocker enabled, answer blocked names with the same `zero_ip`, keep the **same 77-entry allowlist**, use a **different**
   block IP, keep the filter proxy OFF while evo-x2 has it ON, keep its rate-limit exemption (0 = unlimited) and never ship
   `tempAllowAll`. Scope is honest: rpi3 is `aarch64-linux`, so this x86_64 box cannot realize its config file — documented in
   the test header and the runbook rather than pretended away.
7. **T14 + T15 — blocklist freshness has a signal and the cadence is a decision, not an accident.** A new
   `dnsblockd-otel-observer` (oneshot + 60 s timer) emits `dnsblockd_blocklist_age_seconds` / `…_refresh_stale`, alarmed by
   Gatus at 30 days. The measurement had to change from the plan: **Nix store files carry mtime = 1**, so "max mtime of the
   loaded lists" read ~56 years; the observer hashes the loaded set and remembers the first epoch it saw that hash. Refresh
   stays manual **by design** (it edits SRI hashes that need a commit + deploy), and the runbook says so.
8. **T05 (observer half) — the exporter's failure is now visible without the exporter.** During the live collector outage the
   only metric that knew was the one that could not be delivered. The observer samples `dnsblockd_otel_errors_total` from
   `:9090/metrics` (which survives exporter failure), publishes `dnsblockd_otel_export_broken` and `…_observer_ok`, and the
   Gatus check fails when either is wrong — **fail-closed**: a blind sample reports broken instead of freezing the last good
   value. **Verified live pre-deploy: it already reports `export_broken 1`, correctly.**
9. **T22 — the wildcard/catch-all pair is now an eval failure.** New auto-discovered module
   `dns-caddy-wildcard-audit.nix` asserts the pair in **both** directions (the record without the site = a browser error
   instead of the branded 404; the site without the record = unreachable config), with `extraPairedDomains` and a documented
   `allowCatchAllWithoutWildcard` exemption — evo-x2 waives only the split-horizon cloud zone, which is explicit-record by
   design. Negative-tested. Module count 140 → 141, re-stamped in README + FEATURES.
10. **T23 — the filter-proxy contract is probed every deploy.** `post-deploy-check.sh §23` reads the rendered config path from
    the live unit's structured `ExecStart` and asserts the three proxy keys, the ABSENCE of `proxy_filter_domains` (the scoped
    lie stays off unless the owner arms it) and an active unit. Live verdict: PASS.
11. **A shared blocker repaired on sight:** `checks.scrub-guard` was double-wrapped (`runNixOSTest` applied to an already
    built test), which made the **check set** fail to evaluate — and because the pre-commit hook evaluates the check set for
    any Nix change, **no Nix commit on this tree could pass, for anyone**, since that test landed. Fixed in `tests/default.nix`;
    `nix flake check --no-build` is green again.

---

## b) PARTIALLY DONE

1. **T03 — falsified/stale rows.** Two rows were closed earlier in the session (the orphaned tracking DB is gone; the 60 s
   budget was already 300 s) and two were re-tagged. Remaining: `services.md:97` ("second-wave capabilities" — policies, trial
   lists, ECS, h3 are all rendered and live, so the row is stale), the `services.md:96` adoption-wave row (only the dashboard
   walk is real), and the ~10 `DONE`-prose-but-`[ ]` rows that **must** go through `scripts/prune-done-todos.sh`, not a hand
   edit. Reason for stopping: script-driven pruning is T27 and is being deferred (see d.5).
2. **T05 — the exporter itself is unchanged.** The observer reports the failure; it does not fix it. The exporter is dead
   because `signoz-collector.service` is `failed`/`start-limit-hit` (SEV1 in `docs/todo/monitoring.md`, dead since
   2026-10-27 20:21). Recovery is a deploy + `reset-failed`: **root-gated**.
3. **T23 — restart continuity** ("DNS kept resolving while the unit restarted during switch") is the only surviving half of
   the original ask; it rides the next deploy by construction.
4. **T13 — file-level coverage** is impossible on this host (aarch64 target, no aarch64 builder). Eval-level parity is what
   landed; the row says so rather than implying more.
5. **The plan's tombstone** still says `EXECUTING` — deliberate: 16 tasks are open, so flipping it to `EXECUTED` would be a lie.

---

## c) NOT STARTED (and why each one is not laziness)

| Task | Gated by |
| --- | --- |
| T04 allowlist backup | **owner answer Q3** (target path + whether tracking data may ride along — a privacy boundary) |
| T06 option validation (read `dns-blocker.nix:460-1195`) | unblocked; ~100 min of careful reading, deliberately last because it changes no behaviour |
| T08 `Type = "notify"` + `AF_UNIX` | **deploy** (a wrong family makes the unit sit in `activating`; must be one atomic switch) |
| T09/T10/T11 upstream-module migration + VM test adoption | **owner answer Q1** (unprivileged user + `chown` of 7 GB while the sole resolver is stopped) and **deploy** |
| T16 `hot/dnsblockd` coverage decision | doctrine decision (snapshot set vs a small copy-only unit) — needs an owner steer |
| T17 gateway surface | upstream release (issue #24 + T366/T367) |
| T18 search-domain LAN-client policy | **owner decision** (open since 2026-10-17) |
| T19 runbook pointers (4 docs) | unblocked, doc-only |
| T20 comment sweeps (pre-T299 claims + contradictions) | unblocked, doc-only |
| T21 h2 block-page / ALPN | unblocked probe; needs a decision on whether h2 should be on at all |
| T24 catalog/eval warning batch | unblocked but low value (3 duplicated rows for one 21-subdomain warning) |
| T25 upstream issues batch | needs `gh` write access + the verified repros already collected |
| T26 post-deploy battery | **deploy** (must run on a generation carrying the new revs) |
| T27 prune pass | script-driven, and it UNMASKS WARNs (163→221 last time) — wants a quiet window and a rev-pinned A/B |

---

## d) TOTALLY FUCKED UP (in the repo and the host, not in this session's work)

1. **All telemetry on this host has been dark for ~16 hours.** `signoz-collector.service` is `failed` with
   `start-limit-hit` (last attempt 00:45:24, "Start request repeated too quickly"); nothing listens on :4317/:4318. Every
   service's traces and logs are being dropped, the SigNoz UI still renders (query service + ClickHouse are up) so it *looks*
   healthy, and the in-band detector for it is scraped by the dead collector — a stack-scale phantom-green. The in-tree fix
   exists; the recovery needs root. This is the single biggest outstanding problem on the box and it is not a dnsblockd one.
2. **The pre-commit gate was red for everyone, for as long as that VM test existed.** A double-wrapped test meant
   `nix flake check` could not evaluate the check set, so every Nix commit aborted. Nothing reported it; I found it because my
   own commit was refused. Fixed, but the *class* (nobody runs the gate at HEAD on a shared tree) is unfixed.
3. **The derived Gatus count in README drifted twice inside 20 minutes.** Two sibling sessions added endpoints without
   re-stamping, and the count moved 243 → 244 → 245 → 247 while I was writing. Each is caught only when someone tries to
   commit; the number is owned by nobody.
4. **The dnsblockd CA is in the system trust bundle twice** (identical fingerprint, 2026-10-28). Harmless for trust, but
   `security.pki.certificates` has exactly **one** entry at eval and the repo has exactly **one** source file, so a second,
   unidentified mechanism appends it. A half-understood trust path is precisely how a future parity guard ends up trusting the
   wrong copy. Queued.
5. **Two queue rows named a metric that does not exist.** Both the plan and the queue said `dnsblockd_otel_internal_errors`;
   `/metrics` has `dnsblockd_otel_errors_total`, and `otelInternalErrors` is only a `/health` JSON field. A dispatch against
   the written row would have built a check that silently matched nothing — the exact failure the row existed to prevent.
6. **Commit attribution is degraded by the auto-commit daemon.** Two of this session's changes (the T01 gate + its check, and
   the T13 render-test work) landed inside `chore: auto-commit N changed file(s)` batches that also carried a sibling
   session's storage migration (`disko/samsung-tlc.nix`, `snapshots.nix`, `migrate-projects-subvol.sh`). One of my commits
   (`90f44ac70`) also had its message replaced by a parallel amend. The code is right; the history does not say who did what.
7. **`tests/test-scrub-guard.nix` shipped broken and stayed broken long enough to become the house blocker.** The lesson from
   the earlier `scrub-guard` work — "test the shipped artifact, not a reconstruction" — was applied, but nobody ever ran
   `nix flake check` at HEAD after it landed.

---

## e) WHAT WE SHOULD IMPROVE

**Process**

1. **Premise-check every queued row that names an identifier** (metric, option, file, port) before dispatch. Two rows in this
   plan named a non-existent metric; one named a port its code never touched. A grep at queueing time costs seconds.
2. **A shell gate is not tested until something executes it against a fixture.** Both defects the review found (wrong-port
   gate, unenforced CA parity) had green runtime evidence — a start job that passed, a deploy that succeeded — because the
   *evidence* could not distinguish right from wrong. Fixtures with real artifacts (listener maps, openssl certs) are the fix,
   and they are cheap.
3. **Derived numbers need a single owner.** README's module/endpoint counts are re-stamped by whoever happens to add the
   offending thing, which is to say nobody. Either generate the sentence or have the gate print the exact replacement line.
4. **`wiring = "config"` (and its cousins) must carry an expiring last-verified date.** A static registry entry asserted a dead
   leg for a day and would have asserted it forever.
5. **Run `nix flake check --no-build` at HEAD, not only on the staged diff.** A shared tree can be broken for hours without
   anyone noticing, and the pre-commit hook is the only thing that looks — which means a broken HEAD blocks all work silently.
6. **Name the commits you care about, or they will be swept.** On a tree with several sessions plus a 10-minute daemon, a
   commit that matters should be made the moment it is green, and verified by content (`git log -S`) not by message.
7. **Keep the "one question per row" rule.** The best rows in this plan were single-ask with a `Source:` pointer; the worst
   were three-asks-in-one that could never be closed cleanly.

**Code / config**

8. **Liveness must not share a failure domain with the thing it watches.** gatus-gated-on-OIDC (2026-10-12) and now
   OTel-errors-reported-via-OTel are the same anti-pattern; the pattern that works is a *third* channel (textfile → node
   exporter → Gatus), which is what §22/§23 and the observer now use.
9. **Prefer the readiness signal the binary already emits.** `sdnotify.Ready()` has been called by the deployed binary all
   along; the wrapper ignores it and re-implements readiness with a poll. T08 deletes that whole mechanism.
10. **Store mtimes are useless as data ages.** Any "how fresh is this" metric derived from a store path is wrong by
    construction; track a first-seen epoch in a state dir instead (now the documented pattern in the runbook).
11. **Assertions should be negative-tested at the moment they are written**, not later: T22's value is entirely in the
    `mkForce`-empty-vhost run that proves it fires.

---

## f) UP TO 50 NEXT THINGS

Harvest tags: `[Q]` = already in `TODO_LIST.md` + `docs/todo/*` · `[NQ]` = newly queued by this report · `[NH]` = deliberately
not harvested (reason given).

**Unblock the box (highest value, all root-gated)**

1. Deploy the in-tree collector `project_id` fix, `systemctl reset-failed signoz-collector`, verify samples/logs/traces resume —
   telemetry has been dark ~16 h. `[Q]` (SEV1 row, monitoring.md)
2. Add an OUT-OF-BAND unit-state leg for the collector itself (system-health textfile or a Gatus `:8888` probe): the current
   detector is scraped by the thing it watches. `[Q]`
3. Verify the dnsblockd exporter resumes the moment the collector returns; then confirm `dnsblockd_otel_export_broken` returns
   to 0 in the *next* observer sample — that is the end-to-end proof of T05. `[NQ]`
4. Deploy the observer + gate + §22/§23: they are in-tree only. One deploy activates T01, T02, T05(observer), T14, T12, T23.
   `[NQ]`
5. After that deploy: pull `journalctl -u dnsblockd-otel-observer` + the textfile and confirm `observer_ok 1`. `[NQ]`

**Close the two defects the review called concrete**

6. T08 `Type = "notify"` + `AF_UNIX`, delete the 300 s poll and its assertion pair. `[Q]`
7. Re-run `checks.dnsblockd-readiness-gate` in the same commit (it executes the deployed script). `[NH: it is already a flake
   check; running it is the commit gate, not a task]`

**Owner decisions (each blocks a task)**

8. Q1: adopt upstream's unprivileged `dnsblockd` user (needs `chown` of 4.6 G journal + 2.55 G tracking while stopped) or record
   `root` as deliberate. `[Q]`
9. Q3: where does the allowlist backup land, and may `tracking.db` ride along (per-device domain history offsite)? `[Q]`
10. T18: search-domain policy for non-NixOS clients (MacBook) — the wildcard makes failed public names resolve locally. `[Q]`
11. T16: `hot/dnsblockd` coverage — snapshot set vs a copy-only unit vs documented exclusion. `[Q]`

**Durability / migration**

12. T09: dump + map the 53 wrapper options to upstream `snake_case` (the migration's real cost, still unknown). `[Q]`
13. T10: migration execution with render-parity diff + rehearsed rollback. `[Q]`
14. T11: adopt upstream `nixos-vm-test` (our unit is never booted; upstream boots it plus a gateway variant). `[Q]`
15. T04: allowlist backup oneshot + timer once Q3 is answered. `[Q]`

**Observability truth-maintenance**

16. Give `signoz-coverage` entries an expiring `lastVerified` and fail eval when it is stale. `[NQ]`
17. Audit every other `signoz-coverage.expected` service for the same exporter-blindness. `[Q]`
18. Sweep for other "LIVE-VERIFIED in a doc, dead in reality" claims (the `wiring="config"` class) across
    `docs/agents/monitoring.md`. `[Q]`
19. Prove the collector's own Gatus/SigNoz rules are green once it is back. `[Q]`
20. Cut the `otelErrors` journal spam at its source OR ratelimit it — the spam buries absence-of-phase-line signals. `[Q]`
21. Migrate the remaining `dnsblockd_otel_internal_errors` spellings anywhere they survive (grep the tree). `[NQ]`

**Guards that are still missing**

22. T19: four runbook pointers (`/etc/hosts` zone shadow, the 443 listener IP map, "proxy" disambiguation, OIDC link). `[Q]`
23. T20: comment sweeps for pre-T299 claims and comments contradicting adjacent config. `[Q]`
24. T21: h2/ALPN — probe `openssl s_client -alpn h2` against the block page and decide whether h2 should be on. `[Q]`
25. T22's sibling: assert the **apex** record ↔ apex vHost pair the same way (the wildcard guard covers `*` only). `[NQ]`
26. T24: collapse the three duplicated catalog-warning rows into one working item and land the entries. `[Q]`
27. T25: file the three upstream defects (sdns cache globals vs otel bridge race, startup hang before `server_init`,
    `proxy_inject_script_url` scheme/reachability). `[Q]`
28. T06: read `dns-blocker.nix:460-1195` and record per-option verdicts (coherent / drifted / omit-on-purpose). `[Q]`
29. Add a `dnsblockd` selftest leg that executes the observer script's **blind** branch in CI (the fixture exists nowhere yet). `[NQ]`
30. Negative-test §22/§23 the way the T22 assertion was negative-tested (fixture path env vars already exist for both). `[Q]`
31. T26: run the post-deploy battery on a generation carrying these revs, incl. the vendorHash leg. `[Q]`
32. T27: prune pass via `scripts/prune-done-todos.sh` (dry-run, rev-pinned A/B, expect the WARN count to RISE). `[Q]`
33. T03 remainder: re-tag `services.md:97` (second-wave capabilities all live) and shrink `:96` to its real remainder. `[Q]`

**Host-level findings raised here**

34. Find the SECOND writer of the dnsblockd CA in the trust bundle (one option entry, one source file, two copies). `[Q]`
35. Make the CA-duplicate WARN explain how to find the writer (it currently only says "find the second writer"). `[NQ]`
36. Re-stamp README's Gatus count **after** the next endpoint wave, and decide whether the sentence should be generated. `[NQ]`
37. Add a tiny script that prints the exact README replacement lines for `doc-counts` (kills the treadmill). `[NQ]`
38. Add the observer's textfile to a SigNoz dashboard for the *post-recovery* view (it is the out-of-band leg while dead). `[NQ]`
39. Decide whether `dnsblockd_otel_errors_total` should also page (today it only warns via Gatus). `[Q]` (folded into 20)
40. Record in the runbook what the observer does NOT cover (it samples one counter and one age; not block-decision latency). `[NQ]`
41. Give `dnsblockd-otel-observer` the same `harden{}` treatment as its neighbours once it has run a cycle in prod. `[NQ]`
42. Re-verify `signoz` dotted/underscore suffix rules against the observer's new metric names (all verbatim counters/gauges). `[NH:
    the names are ours and underscore-verbatim by construction; the rule applies to exporter-declared families]`
43. Confirm `DNS Blocker OTel Export` actually goes RED on Gatus within one 60 s cycle after deploy (the fail-closed path). `[NQ]`
44. Confirm `DNS Blocker Blocklist Freshness` is GREEN after the first sample (age starts at 0 by design). `[NQ]`
45. Add a `docs/services/dnsblockd.md` "what a deploy must prove" checklist (gate, §22, §23, observer, freshness). `[NQ]`
46. Sweep the other sub-second gates for the same "proves the wrong port" class (`rg 'ss -ltn' modules/`). `[NQ]`
47. Sweep for other silent fixture gaps: gates/polls that no `checks.*` executes. `[NQ]`
48. Repair the shared-tree habit of adding Gatus endpoints without re-stamping (a pre-commit hint naming the two lines). `[NQ]`
49. Verify `docs/planning/2026-10-28_10-40_SUPERB-dnsblockd-integration-plan.md` §0 errata after T27 (the prune may close the
    rows it names). `[NH: the plan itself owns it; §0 is the record]`
50. Flip the plan tombstone to `EXECUTED` only when T04/T08/T09-T11/T16/T17/T18/T19-T21/T24-T27 are closed or re-scoped. `[NQ]`

---

## g) UP TO 3 QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Q1 (gates the migration):** adopt upstream's unprivileged `dnsblockd` user — which requires `chown -R` of a 4.6 G journal
   and a 2.55 G tracking DB while the host's only resolver is stopped — or keep `user = "root"` and record that as deliberate
   (the `CAP_NET_BIND_SERVICE` grant already exists)?
2. **Q3 (gates the allowlist backup, a privacy boundary):** where should the backup land, and may `tracking.db` ride along?
   `/var/backup/` for the allowlist alone is my pick; including the tracking DB ships per-device domain history offsite — the
   exact data the tracking dial deliberates.
3. **Deploy authority:** every fix from this session (readiness gate, CA guard, observer, §22/§23, freshness alarm) is inert
   until `nix run .#deploy` runs, and the SEV1 telemetry outage needs a deploy plus `reset-failed`. Is there a root path for
   that today, or should I keep stacking verified-but-inactive work in-tree?

---

## Appendix — commits this session touched

| Commit | What it carries |
| --- | --- |
| `0fdea5e14` | the Pareto plan + four falsified-row corrections (pushed via merge `7f4edadd0`) |
| `eb6ef83e2` | plan tombstone `EXECUTING` |
| `89ae69400` *(daemon batch)* | **T01** gate fix + `checks.dnsblockd-readiness-gate` + `flake.nix` import + runbook paragraph — rode a sibling's storage batch |
| `700d5c236` | **T02** CA-parity §22 + `scripts/lib/ca-parity-smoke.sh` + 8-leg fixture + README count re-stamp + the scrub-guard repair |
| `24233721d` | **T12** registry inversion + **T23** filter-proxy §23 |
| `dbb085a00` | **T05 + T14** observer, two Gatus checks, runbook section |
| `cddbffbc7` *(and `dce5b2135`)* | **T13** rpi3 parity assertions + runbook "Failover asymmetry" |
| `90f44ac70` | **T22** `dns-caddy-wildcard-audit` + cloud-zone exemption + module-count re-stamp |

**Files this session created:** `flake/parts/checks/dnsblockd-guards.nix`, `scripts/lib/ca-parity-smoke.sh`,
`scripts/test-ca-parity-smoke.sh`, `modules/nixos/services/dns-caddy-wildcard-audit.nix`,
`docs/planning/2026-10-28_10-40_SUPERB-dnsblockd-integration-plan.md` (earlier in the session), this report.
**Files this session modified:** `modules/nixos/services/dns-blocker.nix`, `modules/nixos/services/gatus-config.nix`,
`scripts/post-deploy-check.sh`, `platforms/nixos/system/dns-blocker-config.nix`, `tests/test-dns-blocker-render.nix`,
`tests/default.nix`, `flake.nix`, `docs/services/dnsblockd.md`, `docs/agents/monitoring.md`, `docs/agents/sso-dns.md`,
`README.md`, `FEATURES.md`, `TODO_LIST.md`, `docs/todo/services.md`.
