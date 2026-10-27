# 2026-10-27 21:06 — opencloud deploy #7 LANDED (system-956); first-ever start fixed live; port-correction deploy #8 pending

**Session:** opencloud-executor-1 resume (continuation of the 17:58 handoff arc).
**Trigger:** owner resume directive (execute + verify) at ~18:22; **STOP directive received 21:05** — this report closes the session.

## Headline

**OpenCloud is UP for the first time ever** (ActiveState=active since 20:41, zero crash-recurrences after a live bleve-index repair), deploy #7 landed as **system-956** (anchor verified by number), the 94xx fleet band is green, and the ocis loopback band is live. The vHost `cloud.home.lan` still answers bodiless 400s because the proxy ignores `PROXY_HTTP_ADDR` and binds compiled-in **9100** while Caddy targets 9200 (a TLS-speaking internal ocis service) — the fix (`ports.opencloud = 9100`) is committed in-tree but **deploy #8 has not landed** (blocked by a foreign eval assertion, see §b).

## a. Fully done (verified)

| Item | Evidence |
| --- | --- |
| Diagnosed the dead sequencer 0A1 + the parallel session's half-done float ceremony (killed 18:03 mid-run, proof log had 4 stale-FOD roots) | `~/.cache/lockfloat/float-proof-20261027-172949/-180357.log`; session-reconstruction via mtimes + `session-run2` log |
| **Fired float ceremony #4 — GREEN** (registered dankMaterialShell→853b3999 + monitor365→b2809e024; all four vendorHash surfaces were already fixed by the parallel session by the time I verified them) | `float-proof-20261027-185300.log` `rc=0`; pair landed via daemon `7845a1763`/`08c92c05e` chain, content verified by the ceremony itself |
| Closed the registry-commit gap + landed the foreign 19:02 unblock report + gatus re-stamp 239→241 | commits `6b1aa4c58`, daemon `9961a58ea`; doc-counts battery green |
| **Deploy #7 fired via sequencer v2** (quiescence 4×60s clean, PSI 2-min window 0.0%/0.0%, green-eval, no foreign deploy) → attempt 1 blocked on the README example-anchor (see §d) → fixed → **attempt 2 landed: system-956, anchor verified** (`readlink /run/current-system` == newest `system-N-link` by number) | `~/.cache/oc-e2-deploy7b.log`: FIRING 19:29:47 → battery 109 pass → activation → post-switch; second FIRING 20:04:57 → PATHS 5364→5447 (+561 MiB) |
| **opencloud first-ever start diagnosed + fixed LIVE**: corrupt bleve index (`search/bleve/root.bolt` seeded without its mapping by an aborted Oct-26 start) crash-looped the `search` service 5×/second into start-limit; quarantined `bleve` → `bleve.corrupt-20261027`, reset-failed + start → **active, 0 fatal/terminations since** | journal 20:24-20:30 (5.99 failures of 5 threshold, `error parsing mapping JSON: unexpected end of JSON input`) → clean after 20:41; bleve source: `vendor/github.com/blevesearch/bleve/v2/index_impl.go` GetInternal(MappingInternalKey) |
| **94xx fleet band verified**: gatus 9410 UI 200, relay 9411 /healthz 200, collector 9400 /metrics 200, monitor365-metrics 9421 /metrics 200, keeper raft 9430 listening; ocis's full loopback band live; NATS INFO answers on **9233** (9234 is an ocis HTTP service — the runbook's old claim was inverted) | `ss -ltn` band scan + per-port HTTP probes, 20:37-20:44 |
| **Proxy-port discovery**: `PROXY_HTTP_ADDR=127.0.0.1:9200` is IGNORED by opencloud 7.2.4 (NATS_PORT no-op class) — proxy binds compiled-in **9100 plain HTTP** (200 on /); 9200 is a TLS listener with a generated self-signed cert ("O=Acme Corp, CN=OpenCloud") | band scan + `openssl s_client` on 9200 ("Client sent an HTTP request to an HTTPS server") + env dump from the unit |
| `lib/ports.nix`: `opencloud = 9100`, `opencloud-nats = 9233` with live-verified comments (rides deploy #8; in tree, daemon-swept) | ports.nix diff in tree |
| Runbook traps **9** (PROXY_HTTP_ADDR ignore + 9200-TLS + wrong-port symptom) and **10** (bleve corrupt-index crash-loop + quarantine recipe) written; trap 8's NATS claim corrected | `docs/services/opencloud.md` |
| cv vendorHash SIXTH re-stale (cv@0d50fb7: N9Zsy7bb → 0YovMWLa, first-hand from proof 202139) applied in-tree | `modules/nixos/services/cv.nix` |

## b. Partially done / in flight at stop

1. **Deploy #8 (the 9100 port fix) NOT landed.** Sequence at stop: the parallel session's blanket `nix flake update` (20:5x) floated cv+crm+~dozen inputs; its ceremony 202139 went RED (cv hash — fixed by me); the daemon then swept the **regenerated-but-unproven** registry rows, so the drift gate is disarmed and `float-register` no-ops ("no drift"). My **direct keep-going proof** (20:59) is RED on an eval assertion, not a build failure: `forgejo-family-condition-audit: gitea-runner-evo\x2dx2-ensure` lacks the `.subvol-migrated` ConditionPathExists gate (new unit arrived with the floated gitea-runner input). This is a foreign arc's guard; fixing it needs the gate-vs-exemption decision (§g.1).
2. **vHost cloud.home.lan still 400s** through Caddy (upstream 9200 is the wrong port) — resolves with deploy #8; then re-verify login redirect + webfinger JSON through the full chain.
3. **Post-deploy smoke rc=1**: `InboxClean :8099/health unreachable` — **pre-existing** (inboxclean-sync was in the failed-units list BEFORE the deploy; the deploy did not cause it). Not triaged (out of arc scope, foreign service); flagged.
4. My tree edits (`ports.nix`, `cv.nix` hash, runbook traps) are daemon-swept/commit-pending — pathspec commits blocked while the flake battery is red (drift disarmed but assertion red).

## c. Not started (plan phases)

- **E5** (owner-interactive passkey login at cloud.home.lan → admin role), **E6-E9** (web smoke, trash/versions posix restore, rclone WebDAV, journal/memory sweep) — all gated on deploy #8 + owner presence.
- **Phase F** (opencloud-desktop into home.nix; nixpkgs-fe13242 package existence unverified).
- **Phase G** (23:45 btrbk-pool snapshot of `services/opencloud` + `getfattr` xattr spot-check; SigNoz/VM-test defer rows).
- **Phase H** closeout (report, CHANGELOG naming daemon batches per owner Q3, resolve opencloud `[decision]` row, docs VERIFY, plan-marker done).
- Owner §g follow-through from the 17:58 report (Stalwart route, PSI encoding, monitor365 intervention) — no owner answers received on any channel this session.

## d. Fucked up / near-misses (own goals, all caught)

1. **My loopback HTTP probes were malformed** (`$path` unexpanded inside single quotes → literally `GET $path HTTP/1.1`); the resulting `HTTP/1.0 400 Bad Request` answers sent me chasing a phantom TLS story for one cycle — until the robust re-probe printed the REAL 9200 TLS error. Lesson re-confirmed: sanity-check the probe itself before theorizing about the target.
2. **My gatus re-stamp missed the anchor occurrence**: README line 82 carries the count TWICE (prose "Gatus (239 …)" + the embedded example `… length x'` → 239`); I updated only the prose. The pre-commit hook skips the flake battery for .md-only commits, so my commit passed and the deploy's section-1 check failed 8 minutes later — deploy #7 attempt 1 aborted. Attempt 2 (after syncing the example anchor) landed clean.
3. Typed `rg -r…` twice more (hook caught both; the `-rn` muscle memory is persistent).

## e. Improvements (structural, for backlog)

1. **doc-counts anchor duality is a trap**: two occurrences of the count on one line, only one is the anchor. Make the example count-free (e.g. `→ NNN`) or have the check assert a single canonical occurrence.
2. **The pre-commit hook skips the flake battery for .md-only commits** — doc-embedded eval anchors can rot invisibly exactly as (d.2) happened. Wire doc-counts-relevant README/FEATURES edits into the battery regardless of filetype.
3. **The daemon sweeping unproven registry rows disarms the drift gate** (bcaa65167 class; recurred TWICE tonight: 18:29 and 20:55). float-register's red-path registry revert races the ~10-min daemon. Consider: daemon path-exclusion for `flake/expected-locks.nix`, or a "proven-through" hash stamp the ceremony sets and the audit checks.
4. **ocis port no-ops deserve a module-level assert**: PROXY_HTTP_ADDR and NATS_PORT are both ignored by the 7.2.4 binary; the nixpkgs module's `port` option silently misleads. An eval-time comment/assert in our wrapper (or the ports.nix comments, now landed) is the pragmatic mitigation.

## f. Next (sorted; NOT harvested into TODO_LIST — owner stop-directive supersedes; harvest on resume)

1. Decide + implement the gitea-runner gate: `ConditionPathExists = [ "/var/lib/forgejo/.subvol-migrated" ]` on `gitea-runner-evo\x2dx2-ensure` (+ RequiresMountsFor) OR `forgejo-family-condition-audit.exemptUnits` with reason — per the audit message's own two options (§g.1).
2. Re-run the direct keep-going proof to green (cv rebuild + gitea-runner gate fix are the only known deltas).
3. Fire deploy #8 (`DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`) under the sequencer gates; verify anchor system-957+.
4. Verify opencloud through the vHost: `/` redirect, `/login` → Pocket ID, webfinger JSON `pat(*oidc-callback*)`; gatus "OpenCloud" + "OpenCloud WebFinger Discovery" checks green.
5. Triage InboxClean :8099 (pre-existing failure; journal + unit state; foreign arc — coordinate or take with attribution).
6. Schedule E5 with the owner (passkey login → admin role via opencloudAdmin group).
7. E6-E9 headless portions (web smoke via probes, rclone WebDAV, journal/memory sweeps).
8. Phase F: verify `opencloud-desktop` exists at nixpkgs fe13242 BEFORE editing home.nix; deploy; owner-assisted connect.
9. Phase G: 23:45 btrbk-pool snapshot check + `getfattr` xattr spot-check; SigNoz/VM-test defer rows.
10. Phase H closeout: CHANGELOG entry (name the daemon batches per owner Q3 disposition), resolve opencloud `[decision]` row, docs VERIFY pass, `scripts/plan-marker.sh <plan> done`.
11. Harvest this report's §f into TODO_LIST.md + domain libraries (pipeline: anchor-duality + hook-filetype-gap; pipeline: daemon-vs-registry race; services: opencloud port fix row).
12. Commit my three tree edits properly (pathspec) once the battery is green; report-name the daemon batches that carried them meanwhile.

## g. Questions for the owner (max 3)

1. **gitea-runner gate decision**: does `gitea-runner-evo\x2dx2-ensure` consume forgejo state (→ add the `.subvol-migrated` ConditionPathExists gate) or is it stateless for this family (→ exemptUnits with reason)? The audit offers both; I can determine it empirically from the unit's ExecStart but the family-guard is your doctrine — which disposition do you want?
2. **PSI policy permanent encoding** (carried from 17:58 §g.2): confirm wording for the pipeline row — "deploy may FORCE when a 2-min window (total-µs deltas) averages ≤80% on both some+full" — and whether the old avg10≥20%/disk-busy≥20% entry gates stay as the non-FORCE path.
3. **opencloud search reindex**: after the bleve quarantine the index is empty and will rebuild lazily as content lands. For the pilot, is lazy enough, or do you want an explicit reindex once E6 test files exist (a search-verification step in E6)?
