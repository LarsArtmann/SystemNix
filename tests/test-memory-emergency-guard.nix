# VM test for the memory emergency guard.
#
# Regression test for BOTH 2026-08-22 kernel-freeze incidents. Exercises the
# REAL guard script (the deployed ExecStart binary) against REAL systemd with
# dummy fastflowlm units — only the kernel data sources (meminfo, zram mm_stat,
# PSI) are faked via the script's env overrides.
#
# Scenarios:
#   1. Healthy: no trip, no stops, metrics written (incl. the new PSI + socket
#      gauges), socket stays up.
#   2. Zone 1 (MemAvailable 4% < absolute floor): trip — socket AND backend
#      AND template instances stopped (the 05:49 feedback loop fix: a trip
#      must kill the ACTIVATION PATH, not just the backend).
#   3. Zone 2 (MemAvailable 8% + zram 95%): trip.
#   4. Zone 3 (PSI 55% + zram 85%, MemAvailable HEALTHY at 30%): MUST trip —
#      the 05:49 refault-thrash freeze mode the old guard was blind to.
#   5. Cooldown: repeat trip within 600 s → service stop skipped (counter
#      unchanged) but the socket stays enforced down.
#   6. Restore: healthy margins + last trip 700 s ago → socket restarted,
#      reset-failed issued.
#   7. Restore blocked by residual PSI (10% ≥ 5% threshold): socket stays down.
{ pkgs }:
let
  # zram disksize: 30 GiB in bytes; orig_data_size scaled per scenario.
  disksize = "32212254720";
  zramOrig = pct: toString (builtins.floor (32212254720 * pct));

  # Single 5-line kernel-file blob: meminfo (2) + mm_stat (1) + psi (2).
  # Built as ONE line with literal \n escapes so the Nix interpolation into
  # the Python testScript stays a valid single-line string literal.
  sourcesBlob =
    {
      availPct,
      zramPct,
      psiAvg10,
    }:
    "MemTotal:       10000000 kB\\nMemAvailable:    "
    + (toString (builtins.floor (10000000 * availPct)))
    + " kB\\n"
    + (zramOrig zramPct)
    + " 1000000000 1000000000 0 0 0 0 0\\nsome avg10="
    + psiAvg10
    + " avg60=10.00 avg300=5.00 total=1000000\\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=100000";

  # Writes /tmp/gt/<name>-meminfo, -mmstat, -psi from the blob (line 3 is
  # mm_stat, line 4 the PSI "some" line the guard's awk reads).
  writeFakes =
    name: attrs:
    "mkdir -p /tmp/gt && "
    + "printf '"
    + (sourcesBlob attrs)
    + "\\n' > /tmp/gt/"
    + name
    + "-all && "
    + "sed -n '1,2p' /tmp/gt/"
    + name
    + "-all > /tmp/gt/"
    + name
    + "-meminfo && "
    + "sed -n '3p' /tmp/gt/"
    + name
    + "-all > /tmp/gt/"
    + name
    + "-mmstat && "
    + "sed -n '4p' /tmp/gt/"
    + name
    + "-all > /tmp/gt/"
    + name
    + "-psi";
in
{
  name = "memory-emergency-guard";

  nodes.machine =
    { config, ... }:
    {
      imports = [
        # The module file is a flake-parts wrapper (top-level lambda
        # `_:`) — apply it, then pull the NixOS module out of the
        # flake.nixosModules option it declares.
        ((import ../modules/nixos/services/memory-emergency-guard.nix) { }).flake.nixosModules.memory-emergency-guard
      ];

      services.memory-emergency-guard.enable = true;

      # Dummy stand-ins with the real unit names: backend, per-connection
      # template, and the activation socket. sleep(1) processes so systemctl
      # stop is observable.
      systemd.services.fastflowlm = {
        description = "dummy flm backend";
        serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
        wantedBy = [ "multi-user.target" ];
      };
      systemd.services."fastflowlm@" = {
        description = "dummy flm per-connection instance";
        serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
      };
      systemd.sockets.fastflowlm = {
        description = "dummy flm activation socket";
        socketConfig.ListenStream = "/run/flm-test.sock";
        wantedBy = [ "sockets.target" ];
      };

      system.stateVersion = "25.11";
    };

  testScript =
    let
      healthy = {
        availPct = 0.30;
        zramPct = 0.20;
        psiAvg10 = "0.10";
      };
      zone1 = {
        availPct = 0.04;
        zramPct = 0.20;
        psiAvg10 = "0.10";
      };
      zone2 = {
        availPct = 0.08;
        zramPct = 0.95;
        psiAvg10 = "0.10";
      };
      # The 05:49 freeze signature: healthy MemAvailable, thrashing PSI,
      # zram mostly full.
      zone3 = {
        availPct = 0.30;
        zramPct = 0.85;
        psiAvg10 = "55.00";
      };
      restoreBlockedPsi = {
        availPct = 0.30;
        zramPct = 0.20;
        psiAvg10 = "10.00";
      };
    in
    ''
      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("fastflowlm.service")
      machine.wait_for_unit("fastflowlm.socket")
      # Stop the timer so background runs cannot race the assertions.
      machine.succeed("systemctl stop memory-emergency-guard.timer")
      # The guard's StateDirectory is created by systemd when the unit first
      # runs; we stopped the timer before its OnBootSec=2min first fire, so
      # create it like the unit contract would.
      machine.succeed("mkdir -p /var/lib/memory-emergency-guard")

      script = machine.succeed(
          "grep -oP '^ExecStart=\\K.*' /etc/systemd/system/memory-emergency-guard.service"
      ).strip()

      def run_guard(case):
          return machine.succeed(
              f"MEMINFO_SRC=/tmp/gt/{case}-meminfo"
              f" ZRAM_MM_STAT_SRC=/tmp/gt/{case}-mmstat"
              f" ZRAM_DISKSIZE_SRC=/tmp/gt/disksize"
              f" PSI_SRC=/tmp/gt/{case}-psi {script} 2>&1"
          )

      def reset_state():
          machine.succeed("rm -f /var/lib/memory-emergency-guard/last-trip"
                          " /var/lib/memory-emergency-guard/tripped.count")
          # Bring every sacrifice unit back up (the restore path only
          # restarts the socket; activation would re-spawn the backend).
          # Order matters: the socket FIRST — systemd refuses a socket whose
          # service is already active ("Socket service ... refusing").
          # A stale /run/flm-test.sock (left when the guard stopped the
          # socket mid-listen) makes ListenStream fail with EADDRINUSE.
          machine.succeed("rm -f /run/flm-test.sock")
          machine.succeed("systemctl start fastflowlm.socket")
          machine.succeed("systemctl start fastflowlm.service"
                          " 'fastflowlm@1.service'")

      def assert_all_down():
          machine.fail("systemctl is-active --quiet fastflowlm.socket")
          machine.fail("systemctl is-active --quiet fastflowlm.service")
          machine.fail("systemctl is-active --quiet 'fastflowlm@1.service'")

      # Shared zram disksize file.
      machine.succeed("mkdir -p /tmp/gt && echo '${disksize}' > /tmp/gt/disksize")

      # --- 1. Healthy: no trip ------------------------------------------
      machine.succeed("${writeFakes "healthy" healthy}")
      out = run_guard("healthy")
      assert "MEMORY EMERGENCY" not in out, "healthy input must not trip"
      machine.succeed("systemctl is-active --quiet fastflowlm.socket")
      prom = machine.succeed("cat /var/lib/prometheus-node-exporter/textfile_collectors/memory-emergency-guard.prom")
      assert "memory_emergency_guard_avail_percent 30.0" in prom
      assert "memory_emergency_guard_psi_some_avg10_percent 0.10" in prom
      assert "memory_emergency_guard_sacrifice_socket_active 1" in prom

      # --- 2. Zone 1 (absolute floor) -----------------------------------
      reset_state()
      machine.succeed("${writeFakes "zone1" zone1}")
      out = run_guard("zone1")
      assert "below absolute floor" in out
      assert_all_down()

      # --- 3. Zone 2 (low avail + full zram) ----------------------------
      reset_state()
      machine.succeed("${writeFakes "zone2" zone2}")
      out = run_guard("zone2")
      assert "shmem-unevictable trap" in out
      assert_all_down()

      # --- 4. Zone 3 (PSI thrash, healthy avail) — the 05:49 blind spot --
      reset_state()
      machine.succeed("${writeFakes "zone3" zone3}")
      out = run_guard("zone3")
      assert "refault-thrash freeze mode" in out, (
          "Zone 3 must trip on PSI>=40 + zram>=80 with healthy MemAvailable "
          "(the 05:49 kernel freeze happened exactly here)"
      )
      assert_all_down()
      counter = machine.succeed("cat /var/lib/memory-emergency-guard/tripped.count").strip()
      assert counter == "1"

      # --- 5. Cooldown: repeat trip within 600 s ------------------------
      out = run_guard("zone3")
      assert "cooldown active" in out
      counter = machine.succeed("cat /var/lib/memory-emergency-guard/tripped.count").strip()
      assert counter == "1", "cooldown must not double-count trips"
      # The socket stays enforced down even during cooldown.
      machine.fail("systemctl is-active --quiet fastflowlm.socket")

      # --- 6. Restore after cooldown with healthy margins ---------------
      machine.succeed(
          "echo $(( $(date +%s) - 700 )) > /var/lib/memory-emergency-guard/last-trip"
      )
      out = run_guard("healthy")
      assert "sacrifice sockets restored" in out
      machine.succeed("systemctl is-active --quiet fastflowlm.socket")

      # --- 7. Restore blocked by residual PSI ---------------------------
      reset_state()
      machine.succeed("${writeFakes "psiblock" restoreBlockedPsi}")
      out = run_guard("psiblock")  # healthy: no trip, no restore either
      machine.succeed("echo $(( $(date +%s) - 700 )) > /var/lib/memory-emergency-guard/last-trip")
      machine.succeed("systemctl stop fastflowlm.socket")
      out = run_guard("psiblock")
      assert "restored" not in out, "restore must be blocked while PSI is elevated"
      machine.fail("systemctl is-active --quiet fastflowlm.socket")
    '';
}
