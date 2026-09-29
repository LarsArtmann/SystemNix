# SigNoz GCP Cloud Monitoring Integration — Build + Go-Live Execution

**Session:** 2026-09-29 ~21:00–22:45 CEST · **Prompt:** SigNoz GCP docs + Google-Cloud-Inventory + "signoz = SUPERB!" — read the docs, configure everything "as System Admin God like as possible".
**Status:** Built, committed, GCP-side LIVE-VERIFIED. **One step remains: the deploy** (sudo blocked in the agent sandbox).

---

## a) FULLY DONE

1. **Docs research** — full GCP-relevant tree of signoz.io/docs (integration overview, 4-step manual setup, Cloud Storage + Cloud SQL service pages, Cloud Run + Cloud Functions metric pages from the gcp-monitoring section, llms.txt + sitemap). Key extracted facts: SA + `roles/monitoring.viewer` auth model, `googlecloudmonitoring` receiver shape (`project_id`/`collection_interval` ≥60s/`metrics_list`), one-block-per-project naming, contrib ≥0.158.0 floor, dot→underscore metric-name mangling, Monitoring API $0.01/1k reads with 1M/month free.
2. **Version-floor root-cause (source-verified, not doc-trusted)** — the deployed fork (rev `29e18e65`) pins contrib **v0.144.0**; the 0.158 floor is exactly ONE fix (PR #49826: `SetIsMonotonic(true)` in `ConvertSumToMetrics` — the CUMULATIVE path only). Diffed 0.144 vs 0.158 vs main: the DELTA path is behavior-identical at every version. All chosen presets are DELTA/GAUGE → **0.144 is provably safe for this metric set**; documented as a hard rule (no CUMULATIVE metrics without a ≥0.158 standalone collector).
3. **Fleet scoping from the GCI 2026-09-20 inventory** — 0 VMs/GKE/SQL (official "supported services" are irrelevant); real fleet = 12 Cloud Run projects, 4 Functions projects, 9 storage-worthy projects (incl. `discordsync-backup`, 13.9 GiB, changed same-day; `signal-backups`, 48.4 GiB, **backup pipeline ALARM since 09-05**). Read-call budget computed: ~26k/day ≈ 780k/month — inside the free tier.
4. **Module** — `services.signoz.gcpMonitoring` in `signoz.nix`: preset flags per project (`cloudRun`/`cloudFunctions`/`storage`/`extraMetrics`), two-tier intervals (300s fast / 1800s storage — GCP measures bucket bytes once daily), renders **23 named receivers** (deepbackup correctly merges run+fn = 9 metrics), pipeline wiring, `GOOGLE_APPLICATION_CREDENTIALS` env (list-merge verified), 3 assertions (sops present, secret file tracked, projects non-empty).
5. **Placeholder-safety design** — identified that `google.FindDefaultCredentials` runs at receiver **Start()**: an unparseable key would kill the ENTIRE collector at boot (all local telemetry). Shipped the placeholder as a structurally-valid locally-generated RSA key in SA-JSON shape (loads → 403 per scrape → pipeline intact).
6. **Dashboard** — `dashboards/gcp.json` ("GCP Fleet", 10 panels, deterministic uuid5 `systemnix-gcp/<slug>`, 12-col grid, overlap-check clean, single-query-per-panel v2 rule), registered in `_signoz-alerts.nix`.
7. **Monitoring** — Gatus "GCP Metrics Receiver" (enable-gated registry check on the signoz entry, pat on collector self-metrics for `receiver="googlecloudmonitoring/` — phantom-green-safe: label strings never appear in HELP/TYPE comments).
8. **sops + enable** — `platforms/nixos/secrets/signoz-gcp-monitoring.yaml` encrypted (public-key, no sudo needed); configuration.nix enable block with all 15 projects.
9. **GCP go-live EXECUTED** (lartyhd@gmail.com, owner on all projects):
   - SA `signoz-integration@lars-artmann` created; `monitoring.googleapis.com` enabled on all 15 projects; `roles/monitoring.viewer` granted on all 15.
   - Real key `64cc3cdf…` created → rotated into sops via file-based python + `sops -e -i` (value never touched a command line / fish_history; tmpfs key deleted).
   - **End-to-end verification AS the SA: 16/16 projects HTTP 200, 6 with live `request_count` series in 24h** (nobletary, lars-software, law-gov-pl, issue-shield, artmann-technologies, re-cycular).
   - Hygiene: 5 probe keys created during verification → all revoked (exactly 1 user-managed key remains); tokenCreator grant added for impersonation → rolled back (least privilege).
10. **Live find: dnsblockd phantom-200** — `monitoring.googleapis.com` classified as telemetry by the blocklists; dnsblockd served its block PAGE with **HTTP 200 HTML** (clients fail with JSON-parse errors, never network errors). Whitelisted in `platforms/common/dns-blocklists.nix`; rides the same deploy.
11. **Docs** — runbook `docs/services/signoz-gcp-monitoring.md` (architecture rationale, executed-state record, full go-live commands incl. the non-interactive sops rotation pattern, cost math, query notes, ops, verification checklist); AGENTS.md: new "SigNoz GCP Cloud Monitoring" section + DNS phantom-200 gotcha; TODO harvest (queue row + 3 library entries, updated to deployed-pending state).
12. **Verification** — `nix flake check --no-build` green ×3 (assertions, gatus-pattern-lint, dashboard overlap lint, sops-key-audit, port/deploy audits all pass); rendered collector.yaml eval-inspected (23 receivers + pipeline); `nix fmt -- --ci` clean (0 changed); all commits landed (mine via pathspec where possible; daemon swept the rest — normal for this repo).

## b) PARTIALLY DONE

- **The go-live itself** — everything except `nix run .#deploy` (sandbox sudo gate). The deploy carries: 23 receivers, the real key, the dnsblockd whitelist.
- **Dashboard query correctness** — names are docs-derived (mangled) + label keys assumed (`service_name`/`function_name`/`bucket_name`); NOT verified against live series (impossible pre-deploy). Runbook carries the verification checklist.
- **Data-freshness alerting** — deliberately deferred (needs live-verified names; Gatus check covers receiver-liveness only). TODO'd.

## c) NOT STARTED

- VM test for the new wiring (house doctrine: `tests/test-*.nix` for new module surface — none written).
- CHANGELOG.md entry for the feature.
- post-deploy-check.sh smoke entry for the GCP receiver wiring.
- Live post-deploy verification (Metrics Explorer names, dashboard panels, journal 403 absence, dnsblockd probe).

## d) TOTALLY FUCKED UP

Nothing destroyed. **Process misses, honestly:**

- **Wasted a verification gift**: the 16/16 API probe returned real timeSeries bodies and I only counted them — I could have read `metric.labels`/`resource.labels` from those responses to pre-verify the dashboard's label-key assumptions. Threw the evidence away.
- **5 probe keys created where 1 would do** — key-deletion-vs-file-deletion confusion (deleting the local file does NOT revoke the key). Caught and fully revoked, but sloppy IAM hygiene mid-flight.
- **Deploy blocker surfaced too late** — I discovered the sudo gate only at deploy time; should have probed it BEFORE executing the go-live and told the user earlier that one command would remain theirs.
- **Token-lifetime flag fumbling + curl-blocked sandbox retries** — several probe attempts burned on sandbox constraints (curl banned, sudo banned, python CA quirks). Recovered each time, but the first failure of each class should have informed the approach.

## e) WHAT WE SHOULD IMPROVE (systemic)

1. **dnsblockd block-page HTTP-200 is a fleet-wide trap** — any future HTTPS API integration can silently hit it. A pre-flight step ("does the endpoint resolve to a real IP through 127.0.0.1?") belongs in the go-live runbook TEMPLATE, and possibly a Gatus check for known-API domains.
2. **Agent-sandbox capability probe at session start** — sudo/curl/CA constraints discovered mid-task cost ~15 min. A capability checklist run before executing runbooks would prevent the fumbling.
3. **Label/name verification from probe responses** — when an integration go-live includes API probes, ALWAYS dump label/resource metadata from the responses; it's free dashboard-verification data.
4. **IAM runbooks should state key-revocation semantics explicitly** (file ≠ key).

## f) NEXT — up to 50

**Complete this feature (P0):**

1. `nix run .#deploy` (user/root session) — carries receivers + key + whitelist.
2. Post-deploy checklist (runbook §verification): journal 403s absent, `dig +short monitoring.googleapis.com @127.0.0.1` returns Google IP, Metrics Explorer `run_googleapis_com_request_count`, GCP Fleet panels fill (~10 min; bucket-size panels ≤24h).
3. Verify live metric names + label keys; fix `gcp.json` queries if mangled forms differ.
4. Refine request_latencies panel from `.sum` to quantiles once histogram suffixes verified.
5. SigNoz data-freshness alert rule ("GCP metrics stale", `count(...) or vector(0)` pattern) after names verified.
6. CHANGELOG.md entry.
7. VM test `tests/test-signoz-gcp.nix` (collector starts with receivers + placeholder key; no assertion regressions; gatus check shape).
8. post-deploy-check.sh §: rendered collector.yaml carries GOOGLE_APPLICATION_CREDENTIALS + receiver count matches config.
9. Verify dnsblockd restart semantics for whitelist changes (does the filtered-blocklist path change restart the unit? if not, manual restart note in runbook).

**Fleet extension (owner decisions):**
10. App Engine metrics (7 live apps: `appengine.googleapis.com/http/server/response_count` etc.).
11. Firestore (deepbackup is Firestore-heavy: document counts, listeners).
12. BigQuery (datasets in us/europe-west4/us-east1: stored bytes, slot consumption — cost visibility).
13. Pub/Sub (42 topics: unacked/backlog — `subscription/num_undelivered_messages`).
14. Cloud Build (nobletary/skylines cloudbuild churn: build duration/failure).
15. GKE/Cloud SQL presets stay unused (0 instances) — revisit if fleet changes.

**Cross-system:**
16. **signal-backups pipeline death (since 09-05)** — the inventory ALARM; once live, `api_request_count` on that bucket shows it; root cause = the phone-side writer (user knowledge needed).
17. GCI→SystemNix drift guard: a check that new live GCP resources get monitoring (compare inventory.json services vs `gcpMonitoring.projects`).
18. SA key rotation policy (90d, `pocket-id-secret-rotation` class collector or a TODO reminder).
19. Monitoring API quota panel (read-calls/month vs 1M free tier) — from collector self-metrics `otelcol_receiver_accepted_metric_points` or a GCP quota metric.
20. Post-live: measure collector memory delta (asserted negligible, never measured).

**Small polish:**
21. Cross-link the runbook from `docs/services/signoz-coverage.md`.
22. Runbook: document which hagezi list classifies monitoring.googleapis.com (currently unidentified).
23. Consider `extraMetrics` examples in option docs.
24. (If dashboards grow) GCP dashboard variables (project/service dropdowns — SigNoz dashboard variables feature).

## g) QUESTIONS (cannot figure out myself)

1. **The signal-backups nightly writer — what is it and do you still have it?** The pipeline stopped uploading 2026-09-05 (your inventory's ALARM, 59857 objects, 48.4 GiB). If the writer is a phone app/container that's gone, the right move may be archiving the bucket rather than monitoring a dead pipeline.
2. **Deploy now or batch?** The next `nix run .#deploy` carries this feature + the dnsblockd whitelist + parallel sessions' work (geometrikks migration was mid-flight in the tree). Run it now, or wait for the parallel sessions to settle?
3. **GCP surface ambition:** is the goal "see what's running + storage costs" (current presets), or full-stack watch (App Engine/Firestore/BigQuery/Pub/Sub — items 10–14)? Affects Monitoring API read budget (~220k reads/month headroom left in the free tier).

---

**Evidence:** GCP API probe transcript (16/16 HTTP 200 as SA) in session; `git log` — feature commits `61ef14f4`/`5be64526`/`b243defe`/`dfeb838d`/`34396139` + `95d8641d` (real-key rotation); flake check green runs in session.
