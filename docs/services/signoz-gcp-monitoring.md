# SigNoz GCP Cloud Monitoring Integration

Self-hosted variant of [SigNoz's documented GCP integration](https://signoz.io/docs/integrations/gcp/gcp-integration/):
named `googlecloudmonitoring` receivers on the **existing** `signoz-collector`
pull metrics from the Cloud Monitoring API into the local metrics pipeline.
Zero new services, ports, or exporters — the fleet's GCP footprint (from the
[Google-Cloud-Inventory](https://github.com/LarsArtmann/Google-Cloud-Inventory)
reports) becomes dashboards + alertable series in SigNoz.

- Module: `modules/nixos/services/signoz.nix` (`services.signoz.gcpMonitoring`)
- Dashboard: `modules/nixos/services/dashboards/gcp.json` ("GCP Fleet")
- Secret: `platforms/nixos/secrets/signoz-gcp-monitoring.yaml`
  (`signoz_gcp_credentials_json` = raw service-account key JSON)
- Gatus: "GCP Metrics Receiver" (receiver-liveness on the collector's own
  `otelcol_*` self-metrics at `127.0.0.1:8888/metrics`)

## Why this shape (architecture decisions)

1. **Same mechanism as the official integration, without Enterprise.** The
   documented UI flow (connect account, toggle services) is SigNoz Cloud /
   Enterprise-gated, but the mechanism is just an OTel collector with the
   `googlecloudmonitoring` receiver exporting OTLP — which the OSS collector
   already accepts. We skip the docs' Cloud Run deployment (~$110/month) by
   running the receivers on the evo-x2 collector; the Monitoring API is
   public-internet, ADC works from anywhere.
2. **The deployed fork (contrib v0.144.0) is BELOW the documented v0.158.0
   floor — and that is verified-safe for our metric set.** The floor exists
   for exactly one fix (contrib PR #49826): CUMULATIVE metrics were not
   marked `IsMonotonic`, breaking `rate()`. Source-verified 2026-09-29: the
   DELTA path (`ConvertDeltaToMetrics`) is byte-equivalent in behavior at
   0.144 and current main — delta sums are non-monotonic at every version
   and are queried by **direct aggregation** (`sum(...)`), never `rate()`.
   All presets (Cloud Run / Functions / Storage) are DELTA or GAUGE kinds.
   **Do NOT add CUMULATIVE GCP metrics** (e.g. `cloudsql.googleapis.com/
   database/uptime`) to `gcpRunMetrics`-style presets without either
   bumping the fork or running a standalone collector ≥ 0.158.0.
3. **There is NO safe inert key state — CORRECTED 2026-09-29 (the original
   "structurally-valid placeholder" assumption was FALSIFIED live).**
   `google.FindDefaultCredentials` runs at receiver `Start()` — an
   unparseable `GOOGLE_APPLICATION_CREDENTIALS` file fails the start and
   kills the whole collector at boot. The original design assumed a
   structurally-valid SA-shaped key would merely fail 401/403 per scrape
   (pipeline intact, receiver label present in self-metrics). The first
   deploy carrying the receivers falsified this: **the token fetch answers
   `400 invalid_grant` AT `Start()` (account not found), which is FATAL —
   signoz-collector crash-loops to start-limit-hit and ALL telemetry
   ingestion goes dark**, not just the GCP leg (contained same day:
   `gcpMonitoring.enable = false`). Consequence: keep the receivers
   disabled until the REAL key is provisioned and rotated into sops;
   after go-live verify `journalctl -u signoz-collector | grep -i
   googlecloud` shows NO 400/invalid_grant and the receiver label present
   in `:8888/metrics`.

## Go-live runbook (user-gated: gcloud mutations on both accounts)

One-time service account + IAM + real key. `gcloud auth list` shows both
`lars@helpless.ai` (active) and `lartyhd@gmail.com`; projects marked "both"
in the inventory are grantable from either. The SA lives in one deployment
project (`lars-artmann` is the natural home) and reads cross-project.

**STATUS 2026-09-29: steps 1-4 EXECUTED** (SA `signoz-integration@lars-artmann`
created; `roles/monitoring.viewer` granted on all 15 monitored projects +
monitoring API enabled; real key `64cc3cdf…` rotated into sops; verified
16/16 projects answer HTTP 200 with live series AS the SA — 6 projects show
real `request_count` data). **REMAINING: re-arm `gcpMonitoring.enable = true`
(containment-disabled after the falsification above), deploy, + verification** —
the agent sandbox cannot `sudo`, and `nix run .#deploy` self-elevates.

**dnsblockd dependency (found live at go-live):** blocklists classify
`monitoring.googleapis.com` as telemetry — dnsblockd served its block page
(HTTP **200**, HTML!) instead of the API, so failures look like JSON parse
errors, never network errors. The domain is whitelisted in
`platforms/common/dns-blocklists.nix` since 2026-09-29; the whitelist rides
the SAME deploy. `oauth2.googleapis.com` (token endpoint) is NOT blocked.
If GCP panels stay flat after deploy: `dig +short
monitoring.googleapis.com @127.0.0.1` must return a Google IP, not
192.168.1.200.

```bash
# 1. Pick the deployment project and create the SA (no Cloud Run needed —
#    the collector runs on evo-x2, so ONLY monitoring.googleapis.com must
#    be enabled, not run/secretmanager):
gcloud config set project lars-artmann
gcloud services enable monitoring.googleapis.com
gcloud iam service-accounts create signoz-integration \
  --display-name="SigNoz GCP metrics collector (evo-x2)"

SA=signoz-integration@lars-artmann.iam.gserviceaccount.com

# 2. Grant monitoring.viewer on every monitored project (the full list
#    from configuration.nix; monitoring API must be enabled per project):
for PROJECT in nobletary skylines-one issue-shield issuesafe lars-software \
  artmann-technologies law-gov-pl myfitment-app swetty-swipper re-cycular \
  deepbackup toms-343020 autocont-34d1e lars-artmann discordsync-backup \
  signal-backups; do
  gcloud services enable monitoring.googleapis.com --project=$PROJECT
  gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:$SA" --role="roles/monitoring.viewer" \
    --condition=None >/dev/null && echo "granted: $PROJECT"
done

# 3. Create the key (the one place a JSON key is legitimate: the collector
#    runs OUTSIDE GCP, so ADC-via-attach is unavailable):
gcloud iam service-accounts keys create /run/user/$(id -u)/signoz-gcp-key.json \
  --iam-account=$SA

# 4. Rotate into sops WITHOUT the value ever touching a command line —
#    file-based python rebuild + in-place public-key encrypt (no age key
#    needed; the placeholder file is replaced wholesale):
python3 - <<'EOF'
key = open("/run/user/$(id -u)/signoz-gcp-key.json").read().rstrip("\n")
plain = "signoz_gcp_credentials_json: |\n" + "".join("  " + l + "\n" for l in key.splitlines())
open("platforms/nixos/secrets/signoz-gcp-monitoring.yaml", "w").write(plain)
EOF
sops -e -i platforms/nixos/secrets/signoz-gcp-monitoring.yaml
rm /run/user/$(id -u)/signoz-gcp-key.json

# 5. Deploy + verify (user/root session required — deploy.sh self-elevates):
nix run .#deploy
journalctl -u signoz-collector -f | grep -i googlecloud   # 403s must NOT appear
# after ~10 min: metrics explorer → run_googleapis_com_request_count
# dashboard "GCP Fleet" panels fill (bucket size panels up to 24h — GCP
# measures total_bytes/total_count once per day)
```

Rollback: delete the key (`gcloud iam service-accounts keys delete`) or the
whole SA; revert the sops value to the placeholder key (keep a copy in a
password store — or regenerate: any valid RSA key in SA shape works).

## Metric sets + Monitoring API cost

| Preset           | Metrics                                                                                                                                                                                     | Kind        | Interval                      |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | ----------------------------- |
| `cloudRun`       | `run.googleapis.com/{container/billable_instance_time, container/containers, request_count, request_latencies, container/network/received_bytes_count, container/network/sent_bytes_count}` | delta/gauge | 300s                          |
| `cloudFunctions` | `cloudfunctions.googleapis.com/function/{execution_count, execution_times, active_instances}`                                                                                               | delta/gauge | 300s                          |
| `storage`        | `storage.googleapis.com/{storage/v2/total_bytes, storage/v2/total_count, api/request_count, network/received_bytes_count}`                                                                  | gauge/delta | 1800s (daily-measured gauges) |

Current fleet (2026-09-20 inventory): 14 fast receivers (84 metric-polls) +
9 storage receivers (36) ≈ **26k read-calls/day ≈ 780k/month** — inside
GCP's 1M free Monitoring API reads per billing account/month ($0 beyond;
prorated $0.01/1k if the project list grows). Keep the free-tier margin in
mind when adding projects: each extra fast project ≈ +50k/month.

## SigNoz query notes

- Metric names arrive **dot→underscore mangled**: `run.googleapis.com/
  request_count` → `run_googleapis_com_request_count` (storage/functions
  likewise). Dashboard queries already use the mangled forms.
- Delta sums: query with `sum by (...) (metric)` directly — values ARE the
  interval deltas. Never `rate()` (non-monotonic delta sums at every
  collector version; `rate()` is only for the cumulative class we don't
  scrape).
- Histograms (request_latencies) expose dotted suffix series (`.sum`) in
  SigNoz. The dashboard shows total latency; refine to quantiles after
  go-live once live label shapes are verified.
- Label names: `service_name` (Cloud Run), `function_name` (Functions),
  `bucket_name` (Storage), plus `location` etc. **The dashboard queries
  have NOT been verified against live data yet** (impossible pre-go-live);
  first go-live session must check Metrics Explorer for actual label keys
  and adjust `gcp.json` (deterministic uuid5 regeneration: `uuid5(
  NAMESPACE_URL, "systemnix-gcp/<slug>")`).

## Operations

- Add a project: one line in `configuration.nix` (`projects.<id>.cloudRun
  = true` etc.) + the IAM grant from the runbook + deploy. `restartTriggers` on collector.yaml already restarts the collector on config change.
- Rotate the key: `gcloud iam service-accounts keys create` → sops-paste →
  deploy (secret `restartUnits` restarts the collector).
- What "down" looks like: the Gatus check turns red only if the receivers
  vanish from the collector config/unit. Credential death = 403 scrape
  errors in `journalctl -u signoz-collector` (grep `googlecloudmonitoring`)
  - GCP panels going flat while the check stays green — data-freshness
    alerting is deliberately NOT a Gatus pat (GCP series live in SigNoz's
    ClickHouse, not node-exporter textfiles).
- Related standing alarm (from the inventory, not this integration): the
  `signal-backups.appspot.com` nightly backup pipeline has been stale since
  **2026-09-05** — `storage_googleapis_com_api_request_count{bucket_name=
  "signal-backups.appspot.com"}` going flat/zero is this integration's
  most direct window into it; fixing the writer is tracked in the GCI
  report's backup-pipeline section.

## Verification checklist (first go-live)

1. `systemctl status signoz-collector` — active, no start-limit hits.
2. `journalctl -u signoz-collector | grep -i "failed to scrape"` — 403s
   stopped within one interval of the real key landing.
3. Metrics Explorer: `run_googleapis_com_request_count` returns series.
4. Dashboard "GCP Fleet": API/requests panels fill within ~10 min; bucket
   size panels within 24h.
5. `curl -s 127.0.0.1:8888/metrics | grep googlecloudmonitoring | head` —
   receiver labels with growing accepted/error counters.

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### SigNoz GCP Cloud Monitoring (self-hosted GCP integration, 2026-09-29)

**Option:** `services.signoz.gcpMonitoring` in `signoz.nix` — named `googlecloudmonitoring/<project>` receivers ON THE EXISTING collector (zero new services/ports), pulling Cloud Monitoring metrics over the public API. The self-hosted OSS variant of SigNoz's documented GCP integration (which is Cloud/Enterprise-gated in the UI but pure OTLP underneath). Runbook incl. the SA+IAM+key go-live: `docs/services/signoz-gcp-monitoring.md`. Project set derives from the Google-Cloud-Inventory reports (Cloud Run 12 + Functions 4 + Storage 9 projects, ~780k Monitoring API reads/month — inside GCP's 1M/month free tier).

- **Contrib version trap (source-verified)**: the locked fork pins otel-collector-contrib v0.144.0, below the v0.158.0 floor the SigNoz docs demand — but that floor is exactly ONE fix (contrib PR #49826: CUMULATIVE metrics not marked IsMonotonic → broken rate()). The DELTA path is behavior-identical at 0.144 and main; all presets are DELTA/GAUGE. Query delta sums with direct `sum(...)`, NEVER rate(). Do NOT add CUMULATIVE GCP metrics without a standalone ≥0.158.0 collector.
- **GO-LIVE EXECUTED 2026-09-29 (everything except the deploy, which is CONTAINED)**: SA `signoz-integration@lars-artmann` created, `roles/monitoring.viewer` + monitoring API on all 15 monitored projects, real key `64cc3cdf…` (the ONLY user-managed key on the SA — 5 probe keys were created + revoked during verification) rotated into sops, and 16/16 projects verified HTTP 200 WITH LIVE SERIES authenticated AS the SA (nobletary, lars-software, law-gov-pl, issue-shield, artmann-technologies, re-cycular had real request_count data in 24h). **The first deploy carrying the receivers FALSIFIED the placeholder-safety design (next bullet); the receivers were containment-disabled (`gcpMonitoring.enable = false`, 2026-09-29 storm-closeout) — re-arm enable=true + `nix run .#deploy` (sudo-gated) is the remaining go-live step, carrying the receivers + dnsblockd whitelist together.**
- **`google.FindDefaultCredentials` runs at receiver Start() — there is NO safe inert key state (CORRECTED 2026-09-29, live-falsified)**: an unparseable credential file kills the whole collector at boot, AND the original "structurally-valid SA-shaped key fails 403 per scrape, pipeline intact" assumption was FALSIFIED live — the token fetch answers `400 invalid_grant` AT Start() (account not found), FATAL for the whole receiver chain (signoz-collector start-limit-hit, ALL telemetry ingestion dark, not just the GCP leg). Consequence: `gcpMonitoring.enable` stays `false` until the REAL key is provisioned (it is; real key sits in sops). Runbook design note 3 carries the corrected mechanism.
- **dnsblockd PHANTOM-200 class (found live at go-live): blocklists classify `monitoring.googleapis.com` as telemetry** — dnsblockd served its block PAGE with HTTP 200 HTML, so API clients fail with JSON-parse errors, never network errors. Whitelisted in `platforms/common/dns-blocklists.nix` since 2026-09-29 (rides the same deploy as the receivers). `oauth2.googleapis.com` (token endpoint) is NOT blocked. Post-deploy probe: `dig +short monitoring.googleapis.com @127.0.0.1` must return a Google IP, not 192.168.1.200.
- **Metric naming**: SigNoz stores GCP metric names dot→underscore mangled (`run_googleapis_com_request_count`). The "GCP Fleet" dashboard (`dashboards/gcp.json`, deterministic uuid5 `systemnix-gcp/<slug>`) uses mangled names — its queries are doc-derived and need live verification at go-live (label keys esp.).
- **Monitoring**: Gatus "GCP Metrics Receiver" (registry check on the signoz entry) pats the collector self-metrics `127.0.0.1:8888/metrics` for `receiver="googlecloudmonitoring/` — receiver-liveness only (label strings never appear in HELP/TYPE comments). Credential death = flat GCP panels + 403 lines in `journalctl -u signoz-collector`, NOT a red check.
- Standing context: the inventory's signal-backups nightly pipeline has been stale since 2026-09-05 — `storage_googleapis_com_api_request_count{bucket_name="signal-backups.appspot.com"}` is this integration's direct window into it.

