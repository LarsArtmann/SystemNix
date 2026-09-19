# VM test for Gatus pat() health check patterns.
#
# Verifies that Gatus can evaluate the EXACT pat() patterns from
# gatus-config.nix against real /metrics responses. Catches:
#   - pat() syntax errors (regex-in-glob, wrong wildcard semantics)
#   - Metric name mismatches (phantom metrics that never appear)
#   - Value-assertion failures (pat(*metric 0*) when value is non-zero)
#
# Uses a mock HTTP server serving canned Prometheus-format /metrics output.
{ pkgs }:
let
  # Canned /metrics output matching SystemNix textfile + node_exporter metrics.
  mockMetrics = pkgs.writeText "mock-metrics.prom" ''
    # HELP system_signoz_alert_rules_healthy SigNoz alert rules provisioned
    # TYPE system_signoz_alert_rules_healthy gauge
    system_signoz_alert_rules_healthy 1
    backup_all_healthy 1
    secret_rotation_all_fresh 1
    btrfs_scrub_status 1
    btrfs_scrub_error_free 1
    btrfs_emergency_reserve_present 1
    pool_usb_recovery_mounted 1
    pool_usb_recovery_members_present 2
    pool_usb_recovery_device_errors 0
    pool_usb_recovery_recoveries_total 1
    pool_usb_recovery_last_recovery_seconds 1760000000
    btrfs_device_unallocated_pct 42
    btrfs_metadata_utilization_pct 55
    system_emeet_pixyd_expected_down 0
    system_gpu_active_over_threshold 0
    system_user_slice_memory_over_threshold 0
    system_tmpfs_tmp_over_threshold 0
    system_fstrim_duration_over_threshold 0
    system_any_service_cpu_over_threshold 0
    system_monitor365_buffer_pressure 0
    system_service_start_limit_hit{service="monitor365-server"} 0
    system_service_active{service="projects-management-automation"} 1
    system_service_cpu_over_threshold{service="projects-management-automation"} 0
    system_service_memory_over_threshold{service="projects-management-automation"} 0
    system_service_nrestarts{service="gatus"} 2
    node_psi_memory_alert 0
    node_psi_io_alert 0
    node_nvme_temperature_celsius 35
    node_nvme_percentage_used 11
    node_nvme_media_errors_total 0
    node_nvme_endurance_warning 0
    node_memory_MemAvailable_bytes 64000000000
    node_memory_MemTotal_bytes 128000000000
    node_memory_SwapFree_bytes 8000000000
    node_memory_SwapTotal_bytes 8000000000
    node_filesystem_avail_bytes{mountpoint="/"} 500000000000
    node_amdgpu_mem_info_vram_used_bytes 3000000000
    node_amdgpu_gpu_busy_percent 15
    niri_running 1
    niri_graphical_session 1
    # The four sibling niri checks, WITH adversarial HELP comments: the
    # comments deliberately contain the bare-form match text
    # "<metric> 0 if ..." so the production line-anchored VALUE-0 patterns
    # are the only form that can match the real value lines below. With a
    # bare pat(*niri_desktop_died 0*) body, the HELP line alone would keep
    # the check green even if every real line said 1 (2026-08-22
    # phantom-green class; niri.prom is one collector rewrite from HELP
    # comments existing).
    # HELP niri_desktop_died 0 if the compositor is healthy while a graphical session is active, niri_desktop_died 1 if the desktop died
    # TYPE niri_desktop_died gauge
    niri_desktop_died 0
    # HELP niri_crash_loop 0 if niri did not restart 3+ times in 10 min, 1 if crash-looping
    # TYPE niri_crash_loop gauge
    niri_crash_loop 0
    # HELP niri_zombie 0 if niri is not running headless, 1 if a zombie session exists
    # TYPE niri_zombie gauge
    niri_zombie 0
    # HELP niri_aw_watcher_late 0 if the AW watcher attached, 1 if late into an active session
    # TYPE niri_aw_watcher_late gauge
    niri_aw_watcher_late 0
    attic_storage_over_threshold 0
    system_gatus_endpoints_in_error_long 0
    # bank-sync sync-health surface (mirrors the "Bank-Sync Sync Health"
    # endpoint in gatus-config.nix): errors counter zero + last-sync
    # timestamp present (that metric only renders after a successful sync —
    # its absence is exactly the never-synced outage class).
    # HELP bank_sync_sync_errors_total Total number of failed sync cycles.
    # TYPE bank_sync_sync_errors_total counter
    bank_sync_sync_errors_total 0
    # HELP bank_sync_last_sync_timestamp_seconds Unix timestamp of last successful sync.
    # TYPE bank_sync_last_sync_timestamp_seconds gauge
    bank_sync_last_sync_timestamp_seconds 1760000000
    # signoz-coverage textfile metrics (HELP lines deliberately present — the
    # anchored forms must reject value-matches inside comments):
    # HELP signoz_traces_missing enforced services without a span inside their budget, healthy value is zero
    # TYPE signoz_traces_missing gauge
    signoz_traces_missing 0
    # HELP signoz_coverage_scrape_errors 1 if the ClickHouse coverage queries failed, healthy value is zero
    # TYPE signoz_coverage_scrape_errors gauge
    signoz_coverage_scrape_errors 0
    # HELP signoz_traces_upstream_gaps_over_threshold 1 if upstream gaps exceed the budget, healthy value is zero
    # TYPE signoz_traces_upstream_gaps_over_threshold gauge
    signoz_traces_upstream_gaps_over_threshold 0
    signoz_logs_pipeline_stale 0
    # system-health collector-freshness composite (2026-08-24 SDDM fix —
    # emitted into system_health.prom, same body node_exporter serves):
    # HELP system_niri_metrics_fresh 1 if the niri-health-metrics textfile was rewritten within 300s (collector ALIVE), 0 if frozen/stale
    # TYPE system_niri_metrics_fresh gauge
    system_niri_metrics_fresh 1
  '';

  mockMetricsServer = pkgs.writeShellApplication {
    name = "mock-metrics-server";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      python3 -c '
      import http.server
      metrics = open("${mockMetrics}").read()
      class H(http.server.BaseHTTPRequestHandler):
          def do_GET(self):
              if self.path == "/metrics":
                  self.send_response(200)
                  self.send_header("Content-Type", "text/plain")
                  self.end_headers()
                  self.wfile.write(metrics.encode())
              else:
                  self.send_response(200)
                  self.send_header("Content-Type", "text/html")
                  self.end_headers()
                  self.wfile.write(b"<html><body>OK</body></html>")
          def log_message(self, *_):
              pass
      http.server.HTTPServer(("127.0.0.1", 9100), H).serve_forever()
      '
    '';
  };
in
{
  name = "gatus-patterns";

  nodes.machine = { lib, ... }: {
    systemd.services.mock-metrics = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = lib.getExe mockMetricsServer;
        Restart = "always";
      };
    };

    # Use the nixpkgs gatus module (same as SystemNix production config)
    services.gatus = {
      enable = true;
      settings = {
        web.port = 8081;
        storage = {
          type = "sqlite";
          path = "/tmp/gatus.db";
        };
        endpoints = [
          {
            name = "[TEST] HTML check";
            url = "http://127.0.0.1:9100/";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*<html*)"
            ];
          }
          {
            name = "[TEST] Metric presence";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*node_memory_MemAvailable_bytes*)"
            ];
          }
          {
            name = "[TEST] Value assertion zero";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*node_psi_memory_alert 0*)"
            ];
          }
          {
            name = "[TEST] Label metric";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*system_service_start_limit_hit{service=\"monitor365-server\"} 0*)"
            ];
          }
          {
            name = "[TEST] Multiple conditions";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*btrfs_scrub_status*)"
              "[BODY] == pat(*node_nvme_percentage_used*)"
            ];
          }
          {
            # Anchored form regression (2026-08-22): the "\n" in these
            # patterns must reach gatus as a REAL newline. A literal
            # backslash-n is filepath.Match's ESCAPE for a literal 'n' and
            # can NEVER match — the positive condition goes permanently red
            # (7 deployed checks sat red on exactly this). A phantom-green
            # regression (bare pat(*metric 1*)) would pass here vacuously
            # via the HELP-less body, so the lint + pre-deploy check cover
            # that half; this endpoint covers the newline-escaping half.
            name = "[TEST] Anchored value assertion";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] != pat(*btrfs_scrub_error_free 0\n*)"
              "[BODY] == pat(*\nbtrfs_scrub_error_free *)"
            ];
          }
          {
            # The four sibling niri checks in their EXACT production
            # line-anchored VALUE-0 form (gatus-config.nix "Niri Desktop
            # Died"/"Crash Loop"/"Zombie Session"/"AW Watcher Attached").
            # The mock body carries HELP comments repeating the metric names
            # with value text — these anchored conditions must still match
            # the REAL value lines, proving the real newline reaches gatus
            # and the anchors hold against a HELP-laden textfile.
            name = "[TEST] Niri sibling anchored value-zero";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*\nniri_desktop_died 0\n*)"
              "[BODY] == pat(*\nniri_crash_loop 0\n*)"
              "[BODY] == pat(*\nniri_zombie 0\n*)"
              "[BODY] == pat(*\nniri_aw_watcher_late 0\n*)"
            ];
          }
          {
            # INVERSE (expected RED, see testScript): the anchored VALUE-1
            # form must NOT match anywhere in the healthy body — the mock
            # HELP comment deliberately carries the contiguous trap text
            # "niri_desktop_died 1 if ..." so a bare (unanchored) form would
            # green-vacuously match the comment and this meta-assertion
            # would catch the sibling checks regressing to it.
            name = "[TEST-RED] Niri sibling anchored value-one must not match";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*\nniri_desktop_died 1\n*)"
            ];
          }
          {
            name = "[TEST] Bank-Sync sync health (errors zero + ever synced)";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*bank_sync_sync_errors_total 0*)"
              "[BODY] == pat(*bank_sync_last_sync_timestamp_seconds*)"
            ];
          }
          {
            # Pool RAID1 Membership (pool-recovery module): the production
            # conditions verbatim against the HEALTHY mock (members_present 2
            # must NOT match the " 1\n" line; device_errors must be present).
            name = "[TEST] Pool RAID1 membership (healthy = 2 members)";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] != pat(*pool_usb_recovery_members_present 1\n*)"
              "[BODY] == pat(*\npool_usb_recovery_members_present *)"
              "[BODY] == pat(*\npool_usb_recovery_device_errors *)"
            ];
          }
          {
            # SigNoz coverage checks (gatus-config.nix "SigNoz Traces
            # Coverage" + "SigNoz Trace Gap Budget") verbatim against the
            # healthy mock: the [1-9] anchored forms must NOT match the 0-value
            # lines NOR the HELP comments ("... healthy value is zero" never
            # contains "<metric> <digit>").
            name = "[TEST] SigNoz coverage (anchored zero-value)";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*\nsignoz_traces_missing *)"
              "[BODY] != pat(*\nsignoz_traces_missing [1-9]*)"
              "[BODY] == pat(*\nsignoz_traces_upstream_gaps_over_threshold *)"
              "[BODY] != pat(*\nsignoz_traces_upstream_gaps_over_threshold [1-9]*)"
              "[BODY] == pat(*\nsignoz_logs_pipeline_stale *)"
              "[BODY] != pat(*\nsignoz_logs_pipeline_stale [1-9]*)"
            ];
          }
          {
            # INVERSE of the above (expected RED, see testScript): the [1-9]
            # form as a POSITIVE condition must NOT match the healthy 0-value
            # body — proving the anchored rejection is real and not vacuous.
            # If this endpoint ever goes GREEN, the anchored forms have lost
            # their meaning (glob regression / gatus pattern engine change).
            name = "[TEST-RED] SigNoz coverage phantom-value rejection";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*\nsignoz_traces_missing [1-9]*)"
            ];
          }
          {
            # "Niri Compositor" (gatus-config.nix) production conditions
            # verbatim against the HEALTHY mock (2026-08-24 SDDM hard-down
            # false-negative fix): the niri_running presence pat must be in
            # line-anchored VALUE form and the system-health freshness
            # composite must be present and non-zero.
            name = "[TEST] Niri Compositor (value-anchored + fresh)";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*\nniri_running *)"
              "[BODY] == pat(*\nniri_graphical_session *)"
              "[BODY] != pat(*system_niri_metrics_fresh 0\n*)"
              "[BODY] == pat(*\nsystem_niri_metrics_fresh *)"
            ];
          }
          {
            # INVERSE (expected RED, see testScript): the frozen-collector
            # value must actually MATCH a line-anchored glob — proving the
            # production reject-half (!= pat(*system_niri_metrics_fresh 0\n*))
            # trips on a real frozen emission instead of being vacuous. Note
            # the mock HELP comment above deliberately repeats the metric
            # name — the anchor must reject comment matches ("# HELP ..."
            # never starts with the bare name).
            name = "[TEST-RED] Niri freshness frozen (0 must be matchable)";
            url = "http://127.0.0.1:9100/metrics";
            interval = "5s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*\nsystem_niri_metrics_fresh 0*)"
            ];
          }
        ];
      };
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("mock-metrics.service")
    machine.wait_for_open_port(9100)
    machine.wait_for_unit("gatus.service")
    machine.wait_for_open_port(8081)

    # Give Gatus time to run at least 2 evaluation cycles (interval=5s)
    import time
    time.sleep(15)

    # Query Gatus API for endpoint statuses
    result = machine.succeed("curl -sf http://127.0.0.1:8081/api/v1/endpoints/statuses")

    # All endpoints should be GREEN — EXCEPT those named [TEST-RED], which
    # assert that a condition that MUST NOT match really does not (the
    # phantom-green protection half: a green [TEST-RED] endpoint means the
    # pattern lost its meaning). NOTE: gatus's per-result `status` is the
    # HTTP status code ONLY — a failed BODY condition keeps status=200, so
    # asserting on status alone (the original form) never caught condition
    # failures. Assert `errors`/`success` for conditions, status for HTTP.
    import json
    statuses = json.loads(result)

    failures = []
    for endpoint in statuses:
        name = endpoint.get("name", "unknown")
        results = endpoint.get("results", [])
        if results:
            last = results[-1]
            http_status = last.get("status", 0)
            errors = last.get("errors") or []
            conditions_ok = last.get("success", len(errors) == 0)
            if name.startswith("[TEST-RED]"):
                if conditions_ok:
                    failures.append(f"{name}: expected condition FAILURE but none (pattern vacuous or conditions not enforced)")
            else:
                if http_status != 200:
                    failures.append(f"{name}: http status={http_status}")
                if not conditions_ok:
                    failures.append(f"{name}: condition errors: {errors}")

    if failures:
        machine.fail(f"Gatus pattern test FAILURES: {'; '.join(failures)}")
    else:
        machine.log(f"All {len(statuses)} Gatus endpoints are GREEN")
  '';
}
