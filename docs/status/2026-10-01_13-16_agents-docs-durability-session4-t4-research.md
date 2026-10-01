# AGENT-DOCS-DURABILITY-PLAN — Session 4 Status (T4 research phase)

**Date:** 2026-10-01 13:16 · **Plan:** `docs/planning/2026-10-01_03-00_AGENT-DOCS-DURABILITY-PARETO-PLAN.md`
**Sessions 1–3:** Phase 0 (T1/T2/T3) + Batch A + T8 + T17 landed (see `2026-10-01_12-03_agents-docs-durability-plan-execution-session3.md`).
**This session:** resumed on "execute the whole todo list" instruction, ran T4 research, was interrupted twice for status (12:32 report never written — user redirected to "keep going"), now reporting again at 13:16.

---

## a) FULLY DONE (this session)

1. **Todo list recreated** (9 items: T4a-d → closeout) via the todos tool.
2. **Repo-state verified at resume:** session-3 report landed via daemon sweep (`3b070a18`); working tree clean except ONE foreign untracked file (`docs/status/2026-10-01_12-04_deploy-813-triage-session-self-review.md` — parallel session's, untouched). Daemon very active (8 heuristic commits visible at resume).
3. **Runbook gap verification:** `docs/services/` has NO `pocket-id|oauth2-proxy|signoz|immich|twenty|taskchampion|dozzle|openseo|crush-daily|atticd.md`; `twenty-FREELANCE-PROJECTS.md` + `twenty-POST-SETUP.md` are content docs, not runbooks; T5b (manifest) confirmed MOOT (service removed).
4. **Plan re-read in full** (196 lines): coarse table, micro table (M-ids), execution graph, sequencing notes, gates (D1′/D2′/D2″/T7 folds/W1 remain owner-gated).
5. **Shape model re-read:** `docs/services/indexer-web.md` (header → What it serves table → Ops bullets → Related; appendix model = `emeet-pixyd.md`).
6. **T4 module research, complete (3 of 4):**
   - `pocket-id.nix` (823 lines, 100%): provisioner flow (admin user → avatar → OIDC clients via `extraOidcClients` fan-in → user groups w/ authoritative membership), multi-secret API (`POST …/secrets` PLURAL, secret returned exactly once, atomic mktemp+mv write), `regenerateSecretsFor` desync recovery (RESTART not `start` — RemainAfterExit), `clearStaleWal`, encryption-key + static-API-key checks, SMTP options (`UI_CONFIG_DISABLED=true` env-only config, `SMTP_TLS=tls`:465), `CIMD_URL_ALLOWLIST="[]"` pin, units (`pocket-id` w/ 180s start + healthz probe; `pocket-id-provision`; `pocket-id-secret-rotation` 1h timer, 90d threshold; `pocket-id-backup` 04:00, 14d retention, pool-gated), integration entry (vHost none, monitored, Secret Rotation Health + SQLite Health checks, backup row), paperless SSO-only eval assertion.
   - `oauth2-proxy.nix` (139 lines, 100%): OIDC provider w/ PKCE S256, `whitelist-domain .home.lan` + cloud-domain variant, cookie secret 16/24/32-byte base64 check, `partOf pocket-id-provision` (LoadCredential restart chain), `mkOidcGate` + 6min TimeoutStartSec, `SSL_CERT_FILE` pin, `/ping` readiness probe.
   - `immich.nix` (206 lines, 100%): pool mediaLocation w/ RequiresMountsFor, VAAPI (`video`+`render` groups), native OIDC (`clientSecret._secret` from provisioner path), redis TCP listener added FOR the Gatus check, ML unit 4G/300%/HOME override, `immich-db-backup` 01:00/7d pool-side, integration entry incl. PKCE callbacks (web + mobile `app.immich:///oauth-callback`).
7. **Signoz auxiliary wiring located:** Discord "Discord Alerts" channel provisioned from sops `discord_alert_webhook_url` (`_signoz-scripts.nix`), alerts/dashboards via `_signoz-alerts.nix`, retention model (14d TTLs, `metric_log` partition-drop fallback).

## b) PARTIALLY DONE

- **T4c signoz research (~65%):** read lines 1–120 (header/impersonation rationale, GCP receiver notes), 170–200 (log-TTL retention doctrine), 402–540 (full options surface), 540–660 (signoz.yaml generation, external_url, ClickHouse config w/ prometheus endpoint + keeper), 983–1140 (signoz service wrapper w/ impersonation env + root-password file, migration-lock clear, provision unit, cadvisor, collector head), 1540–1636 (integration entries: XFS mount/usage checks, GCP receiver check, tiles). **Unread:** ~200–400 (log-TTL script detail), ~660–983 (clickhouse unit tail, log-ttl/backup/xfs-metrics units), ~1140–1540 (collector.yaml: journald OTTL pipeline, scrape job list, GCP receiver wiring). Known-from-AGENTS.md but unverified-at-module: scrape job inventory.
- **T4 wave overall: 0 of 4 runbooks written.** All research so far lives only in session context — no artifact, no commit.

## c) NOT STARTED

- T5a/c/d/e runbooks (twenty, taskchampion, dozzle, openseo) — modules not yet read.
- T6a/b runbooks (crush-daily, atticd) — not read.
- Post-backfill claim updates (`AGENTS.md:25`, `docs/agents/README.md:11`) + backfill row closures (TODO_LIST + `docs/todo/services.md`).
- T9 module→runbook pointers (~40 files), T10 registry↔monitoring cross-links, T11 superseded-chain cleanup (7 docs/agents files), T12 AGENTS.md mention sweep.
- Session-3 §f harvest (37 items), session-4 closeout report.

## d) TOTALLY FUCKED UP

- **Nothing broken:** zero bad edits, zero wrong commits, zero damaged files, gates untouched and green as left in session 3.
- Honest friction (no damage, but wasted motion):
  1. **The 12:32 status report was never written** — user redirected to "just keep going" immediately after I ran `date`; one turn produced no artifact.
  2. **Research is batched-then-write, not incremental:** pocket-id read in 3 sequential passes; a mid-research interruption (this one) leaves ZERO durable progress — everything learned lives only in context summaries.
  3. **Start-of-session baseline probe skipped:** did not re-run `bash scripts/check-doc-links.sh` before researching (it was green at session-3 close and nothing docs-touching landed since, but the habit is cheap and was skipped).

## e) WHAT WE SHOULD IMPROVE

1. **Write runbooks incrementally** (research module → write its runbook → next) instead of all-research-then-write; interruptions then leave durable, committable artifacts.
2. **Distill a facts skeleton immediately after each module read** (bullet notes into the future file) so context loss costs minutes, not the whole read.
3. **Batch file reads in parallel more aggressively** (2–3 views per round where independent).
4. **Run the cheap gate at session start** (check-doc-links ≈3s) — baseline before any docs work.
5. **Commit smaller, earlier:** one runbook per commit within a wave is fine and daemon-race-safer than one batch commit.
6. **Fact-check claims against module truth while writing** (this session already caught one: see f/#48).

## f) NEXT — up to 50 things

**T4 completion (7):**
1. Finish `signoz.nix` read (660–983 units detail; 1140–1540 collector.yaml/journald/scrape/GCP wiring; 200–400 TTL script).
2. Grep `docs/agents/{sso-dns,secrets,monitoring}.md` headings for valid runbook Related anchors.
3. Write `docs/services/pocket-id.md`.
4. Write `docs/services/oauth2-proxy.md`.
5. Write `docs/services/signoz.md` (link `signoz-coverage.md` + `signoz-gcp-monitoring.md`).
6. Write `docs/services/immich.md` — FIRST resolve the layer discrepancy (f/#48).
7. `bash scripts/check-doc-links.sh` green → pathspec commit.

**T5 wave (5):**
8. Read `twenty.nix` → write `twenty.md` (link the two content docs; note pending v2.43.0 bump row).
9. `taskchampion.nix` → `taskchampion.md`.
10. `dozzle.nix` → `dozzle.md` (attach-flavor: docker-restart kills it, needs manual start).
11. `openseo.nix` → `openseo.md` (hand-rolled GSC-exempt vHost — do NOT simplify).
12. Checker green → commit.

**T6 wave (3):**
13. `crush-daily.nix` → `crush-daily.md` (link parent `crush.md`; sops synthetic key; PMA-commit-blackout lesson pointer).
14. `attic.nix` → `atticd.md` (RS256, `atticd-storage-dir` ConditionPathIsDirectory skip, `cache.home.lan` substituter deploy-blocking class).
15. Checker green → commit.

**Post-backfill (4):**
16. Update `AGENTS.md:25` ("a few older services still lack runbooks").
17. Update `docs/agents/README.md:11` routing claim.
18. Re-grep (line churn!) + close TODO_LIST backfill row.
19. Close `docs/todo/services.md` backfill row (~174) — both surfaces, same commit, `check-todo-system.sh` green.

**T9–T12 (6):**
20. Generate module↔runbook mapping (`ls` both dirs).
21. Add `# Runbook: docs/services/x.md` comments in batches of ~8.
22. Grep-verify 100% pointer coverage.
23. T10: bidirectional links integration-registry step 9 ↔ monitoring.md Gatus patterns (anchors must pass T2 checker).
24. T11: superseded-chain cleanup ×7 (nix-flakes, systemd, storage, stability, secrets, desktop, monitoring) — verbatim-first, deletion list per file.
25. T12: repo-wide prose AGENTS.md mention sweep + classification table in closure report; fix stale live-pointers on sight.

**Closeout (4):**
26. Harvest session-3 §f (37 items — most map to steps above) or explicit re-defers.
27. §f.31: fix stale "53-report" count on the unharvested-backlog row.
28. §f.33: M2.6 anchor-note decision stands unless owner overrules.
29. Write session-4 closeout report.

**Runbook content obligations from this session's research (14):**
30. pocket-id: `regenerateSecretsFor` recovery (RESTART, then clear the list), multi-secret API trap, client-row-vanish vs secret-desync diagnosis (`GET /authorize?client_id=…` 302 = client OK), SQLITE_BUSY storm semantics, env-only SMTP (`UI_CONFIG_DISABLED`), CIMD deny-all pin, secret-rotation 90d timer, backup 04:00/14d, paperless SSO-only eval guard.
31. oauth2-proxy: PKCE S256, whitelist-domain incl. cloud, cookie-secret byte-length check, `partOf` provision restart chain, 6min gate budget, SSL_CERT_FILE, `/ping`.
32. signoz: impersonation mode, XFS mount fail-closed, 14d log TTLs + `metric_log` partition-drop, provisioner CONVERGES never delete+recreate (fake RESOLVED/FIRING pairs), route policies wiped on restart (restartTriggers mandatory on all three configs), dashboards exactly-one-query rule, `external_url` bake-at-startup, Discord channel from sops webhook, 03:00 `File()`-only backup w/ allowed_path, contrib 0.144-vs-0.158 cumulative-rate note.
33. immich: pool gating, VAAPI groups, redis TCP-for-Gatus trick, ML HOME/4G, DB backup 01:00/7d, PKCE callbacks incl. mobile scheme.
34. twenty: mkDockerService pattern, postgres sidecar `restart=always` (dependency-failure class), migration review before major/minor bumps.
35. dozzle: attach-flavor caveat verbatim.
36. openseo: GSC exemption is load-bearing.
37. atticd: RS256 + DynamicUser ⇒ root-owned sops, storage-dir skip-cleanly, substituter DNS deploy-block class.
38. crush-daily: parent `crush.md` link, no duplication.
39. Every runbook: Gatus check names + Homepage tile from its integration entry.
40. Every runbook: port numbers cited from `lib/ports.nix` mapping (pocket-id 1411/9464, oauth2-proxy 4180, signoz 8080 + family, immich 2283…).
41. Plan's per-runbook Verify column also says "routing claim row updated" — locate that row in `docs/agents/README.md` and update per runbook wave.
42. Link, don't duplicate: signoz sub-docs already own coverage/GCP topics.
43. pocket-id/oauth2-proxy runbooks should cross-ref `docs/agents/sso-dns.md` as the architecture layer.

**Process/governance (7):**
44. Gated: D1′ core slim, D2′/D2″ crush hook, T7a–e folds — never without owner go.
45. W1 watch: mr-sync post-deploy verification only (their scope).
46. f/#48 immich layer discrepancy (below) — verify + fix AGENTS.md SSO table if stale.
47. Pathspec-commit discipline (daemon churn high this morning).
48. **immich vHost.layer discrepancy found this session:** `immich.nix` integration entry sets `vHost.layer = "protected"` while AGENTS.md's SSO table lists Immich under Layer 1 native OIDC (plain reverse_proxy; the double-auth gotcha warns protected+native-OIDC loops). One of them is stale — resolve from the rendered caddy config BEFORE writing the immich runbook; fix the stale surface on sight.
49. Re-grep all queue rows before closing (line numbers churned twice already).
50. Keep gated work parked; if owner answers §g questions, fold answers into the closeout report.

## g) QUESTIONS (cannot figure out myself)

1. **Session-3 §g carryover — D1/D2/D3 defaults:** keep 34KB core, no crush context hook, on-touch-only appendix folds? (Defaults hold until you say otherwise; they gate optional waves D1′/D2′/D2″/T7a–e.)
2. **Session-3 §g carryover — push policy:** session 1–3 commits are already public via a parallel session's push. For the remaining waves: keep never-push-by-me (passive), or push after each wave lands?
3. **In-flight row claims:** should the convergent-execution collision (two sessions claiming the same queue row, session-2 finding) become a TODO_LIST governance item now, or stay a convention note until the waves finish?

---

**Status:** STOPPED, awaiting instructions. Next concrete action on resume: finish signoz.nix read (f/#1), then write the four T4 runbooks incrementally (f/#3–6).
