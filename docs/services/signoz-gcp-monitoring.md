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
3. **Placeholder state is a structurally-valid throwaway key, not a junk
   string.** `google.FindDefaultCredentials` runs at receiver `Start()` —
   an unparseable `GOOGLE_APPLICATION_CREDENTIALS` file would fail the
   receiver start and **kill the whole collector at boot** (all local
   telemetry ingestion with it). The shipped sops value is a real
   locally-generated RSA key in service-account JSON shape: credentials
   LOAD, every scrape fails 401/403, the receiver label still appears in
   the collector self-metrics (Gatus green = receiver registered), and GCP
   data absence on the dashboard is the standing not-live-yet signal.

## Go-live runbook (user-gated: gcloud mutations on both accounts)

One-time service account + IAM + real key. `gcloud auth list` shows both
`lars@helpless.ai` (active) and `lartyhd@gmail.com`; projects marked "both"
in the inventory are grantable from either. The SA lives in one deployment
project (`lars-artmann` is the natural home) and reads cross-project.

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
gcloud iam service-accounts keys create /tmp/signoz-gcp-key.json \
  --iam-account=$SA

# 4. Paste into sops (interactive; never inline the key in a command):
SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) \
  sops platforms/nixos/secrets/signoz-gcp-monitoring.yaml
#    replace the placeholder JSON under signoz_gcp_credentials_json with the
#    file's content (indented block scalar), save, then:
trash /tmp/signoz-gcp-key.json

# 5. Deploy + verify:
nix run .#deploy
journalctl -u signoz-collector -f | grep -i googlecloud   # 403s must STOP
# after ~10 min: metrics explorer → run_googleapis_com_request_count
# dashboard "GCP Fleet" panels fill (bucket size panels up to 24h — GCP
# measures total_bytes/total_count once per day)
```

Rollback: delete the key (`gcloud iam service-accounts keys delete`) or the
whole SA; revert the sops value to the placeholder key (keep a copy in a
password store — or regenerate: any valid RSA key in SA shape works).

## Metric sets + Monitoring API cost

| Preset | Metrics | Kind | Interval |
| --- | --- | --- | --- |
| `cloudRun` | `run.googleapis.com/{container/billable_instance_time, container/containers, request_count, request_latencies, container/network/received_bytes_count, container/network/sent_bytes_count}` | delta/gauge | 300s |
| `cloudFunctions` | `cloudfunctions.googleapis.com/function/{execution_count, execution_times, active_instances}` | delta/gauge | 300s |
| `storage` | `storage.googleapis.com/{storage/v2/total_bytes, storage/v2/total_count, api/request_count, network/received_bytes_count}` | gauge/delta | 1800s (daily-measured gauges) |

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
  = true` etc.) + the IAM grant from the runbook + deploy. `restartTriggers
  ` on collector.yaml already restarts the collector on config change.
- Rotate the key: `gcloud iam service-accounts keys create` → sops-paste →
  deploy (secret `restartUnits` restarts the collector).
- What "down" looks like: the Gatus check turns red only if the receivers
  vanish from the collector config/unit. Credential death = 403 scrape
  errors in `journalctl -u signoz-collector` (grep `googlecloudmonitoring`)
  + GCP panels going flat while the check stays green — data-freshness
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
