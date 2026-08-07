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
    attic_storage_over_threshold 0
    system_gatus_endpoints_in_error_long 0
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
              "[BODY] == pat(*btrfs_scrub_error_free 1*)"
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

    # All endpoints should be GREEN (health status 200)
    import json
    statuses = json.loads(result)

    failures = []
    for endpoint in statuses:
        name = endpoint.get("name", "unknown")
        results = endpoint.get("results", [])
        if results:
            health = results[-1].get("status", "")
            if health != 200:
                failures.append(f"{name}: status={health}")

    if failures:
        machine.fail(f"Gatus pattern test FAILURES: {'; '.join(failures)}")
    else:
        machine.log(f"All {len(statuses)} Gatus endpoints are GREEN")
  '';
}
