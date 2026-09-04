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
#   4b. Burst resistance (PSI avg10 55% but avg60 12%, zram LOW): must NOT
#      trip — a big nix build's transient avg10 spike is not a freeze.
#   4c. Zone 4 (PSI avg60 55% SUSTAINED, zram ~empty, MemAvailable healthy):
#      MUST trip — slow-burn stall variant (NOTE: SigNoz calibration showed
#      the REAL 16:34 freeze never lifted avg60 above ~4%).
#   6b. Zone 5 (episodic avg10 ≥40%, avg60 LOW): 7 episode runs → no trip,
#      8th → trip — the leaky bucket calibrated against the real incident.
#   6c. Episode decay: 4 episodes + clean runs → bucket drains, no trip.
#   5. Cooldown: repeat trip within 600 s → service stop skipped (counter
#      unchanged) but the socket stays enforced down.
#   6. Restore: healthy margins + last trip 700 s ago → socket restarted,
#      reset-failed issued.
#   6a. Restore with zram STILL ≥92% (53% avail, 0.26% PSI): MUST restore —
#      the 2026-09-02 lockout regression: stopping the sacrifice cannot
#      drain zram (its pages belong to other processes), so a zram-gated
#      restore kept the socket down for hours on a healthy machine.
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
      psiAvg60 ? "4.00",
    }:
    "MemTotal:       10000000 kB\\nMemAvailable:    "
    + (toString (builtins.floor (10000000 * availPct)))
    + " kB\\n"
    + (zramOrig zramPct)
    + " 1000000000 1000000000 0 0 0 0 0\\nsome avg10="
    + psiAvg10
    + " avg60="
    + psiAvg60
    + " avg300=5.00 total=1000000\\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=100000";

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
    { lib, ... }:
    {
      imports = [
        # The module file is a flake-parts wrapper (top-level lambda
        # `_:`) — apply it, then pull the NixOS module out of the
        # flake.nixosModules option it declares.
        ((import ../modules/nixos/services/memory-emergency-guard.nix) { })
        .flake.nixosModules.memory-emergency-guard
      ];

      services.memory-emergency-guard.enable = true;

      # Small restore budget so the anti-churn cap scenario can exhaust it
      # within the test run (production default is 3).
      services.memory-emergency-guard.maxRestoresPerDay = 2;

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

      # The guard's trip path STOPS these units and reset_state() restarts
      # them — 9 socket starts across the scenarios, several within one
      # 10 s window when adjacent scenarios run back-to-back. systemd's
      # default StartLimitBurst=5/10s then rate-limits the restart as
      # start-limit-hit (the flake that blocked every pre-commit
      # `nix flake check`). The rate limiter is not under test here —
      # the guard's own burst settings live on the GUARD unit.
      systemd.sockets.fastflowlm.startLimitBurst = lib.mkForce 100;
      systemd.services.fastflowlm.startLimitBurst = lib.mkForce 100;
      systemd.services."fastflowlm@".startLimitBurst = lib.mkForce 100;

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
      # Transient burst: avg10 spiking like a big nix build, but the full
      # minute average stays low and zram is uninvolved. Must NOT trip.
      burst = {
        availPct = 0.30;
        zramPct = 0.20;
        psiAvg10 = "55.00";
        psiAvg60 = "12.00";
      };
      # The 2026-08-31 16:34 freeze signature: SUSTAINED stall (avg60 over
      # half the boot), zram ~empty, MemAvailable healthy, no OOM kills.
      zone4 = {
        availPct = 0.30;
        zramPct = 0.05;
        psiAvg10 = "20.00";
        psiAvg60 = "55.00";
      };
      # The 2026-08-31 16:34 REAL signature (SigNoz-calibrated): episodic
      # avg10 spikes (>=40%), avg60 NEVER above ~4%, zram ~empty, avail
      # healthy. Zone 5's leaky bucket accumulates one count per episode
      # run (decay on clean runs) and trips at 8.
      episodic = {
        availPct = 0.30;
        zramPct = 0.05;
        psiAvg10 = "55.00";
        psiAvg60 = "3.00";
      };
      restoreBlockedPsi = {
        availPct = 0.30;
        zramPct = 0.20;
        psiAvg10 = "10.00";
      };
      # The 2026-09-02 LIVE state that exposed the lockout: zram 97% (28 GiB
      # of OTHER processes' swapped pages that the sacrifice cannot drain),
      # but memory fully recovered (53% avail, PSI 0.26). Restore must fire.
      restoreZramFull = {
        availPct = 0.53;
        zramPct = 0.97;
        psiAvg10 = "0.26";
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
                          " /var/lib/memory-emergency-guard/tripped.count"
                          " /var/lib/memory-emergency-guard/psi-episodes"
                          " /var/lib/memory-emergency-guard/zone-counts"
                          " /var/lib/memory-emergency-guard/trip-history"
                          " /var/lib/memory-emergency-guard/restored.count")
          machine.succeed("rm -f /var/lib/memory-emergency-guard/restores-*")
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

      # --- 4b. Burst resistance: avg10 spike, avg60 low → no trip --------
      reset_state()
      machine.succeed("${writeFakes "burst" burst}")
      out = run_guard("burst")
      assert "MEMORY EMERGENCY" not in out, (
          "A transient avg10 burst with low avg60 must not trip (big nix "
          "builds spike avg10 legitimately — Zone 4 keys on the SUSTAINED avg60)"
      )
      machine.succeed("systemctl is-active --quiet fastflowlm.socket")

      # --- 4c. Zone 4 (sustained stall, zram empty) — the 16:34 blind spot
      machine.succeed("${writeFakes "zone4" zone4}")
      out = run_guard("zone4")
      assert "sustained stall" in out, (
          "Zone 4 must trip on PSI avg60>=50 ALONE with healthy zram and "
          "MemAvailable (the 2026-08-31 16:34 freeze happened exactly here: "
          "zram-gated zones never fired, box froze with zero OOM kills)"
      )
      assert_all_down()
      counter = machine.succeed("cat /var/lib/memory-emergency-guard/tripped.count").strip()
      assert counter == "1"
      prom = machine.succeed("cat /var/lib/prometheus-node-exporter/textfile_collectors/memory-emergency-guard.prom")
      assert "memory_emergency_guard_psi_some_avg60_percent 55.00" in prom

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

      # --- 6a. Restore with zram STILL nearly full — the 2026-09-02
      #      lockout regression: the sacrifice cannot drain zram, so a
      #      zram-gated restore locked the socket down for hours on a
      #      machine with 53% avail / 0.26% PSI. Pressure margins + the
      #      trip zones (which all COMBINE zram with pressure) are the
      #      real protection, not the restore gate.
      reset_state()
      machine.succeed("${writeFakes "zone2" zone2}")
      out = run_guard("zone2")
      assert_all_down()
      machine.succeed(
          "echo $(( $(date +%s) - 700 )) > /var/lib/memory-emergency-guard/last-trip"
      )
      machine.succeed("${writeFakes "zramfull" restoreZramFull}")
      out = run_guard("zramfull")
      assert "sacrifice sockets restored" in out, (
          "restore must NOT require zram headroom: stopping the sacrifice "
          "cannot drain zram (2026-09-02 live lockout — socket stayed down "
          "for hours at 53% avail / 0.26% PSI / 97% zram)"
      )
      machine.succeed("systemctl is-active --quiet fastflowlm.socket")
      prom = machine.succeed("cat /var/lib/prometheus-node-exporter/textfile_collectors/memory-emergency-guard.prom")
      assert "memory_emergency_guard_restored_total 1" in prom, (
          "restore #1 after the 6a counter reset — the restored counter must track"
      )
      assert "memory_emergency_guard_zone2_trips_total 1" in prom, (
          "6a tripped Zone 2 once since the counter reset — per-zone "
          "counters must attribute trips without journal digging"
      )
      assert "memory_emergency_guard_trips_last_hour " in prom

      # --- 6b-cap. Daily restore budget exhausted (maxRestoresPerDay = 2 in
      #      this VM): burn the budget with one more trip->restore cycle,
      #      then the NEXT restore is REFUSED — the socket stays down and
      #      restore_capped hands the restart to a human. The 2026-09-02
      #      re-wake loop (trip -> restore -> consumer reconnect -> 21.6 GB
      #      cold load -> re-trip within ~40 min) made unlimited self-healing
      #      an I/O churn engine.
      machine.succeed(
          "echo $(( $(date +%s) - 700 )) > /var/lib/memory-emergency-guard/last-trip"
      )
      out = run_guard("zone2")
      assert_all_down()
      machine.succeed(
          "echo $(( $(date +%s) - 700 )) > /var/lib/memory-emergency-guard/last-trip"
      )
      out = run_guard("zramfull")
      assert "sacrifice sockets restored" in out, "restore #2 of the day must still succeed (budget 2)"
      prom = machine.succeed("cat /var/lib/prometheus-node-exporter/textfile_collectors/memory-emergency-guard.prom")
      assert "memory_emergency_guard_restored_total 2" in prom

      machine.succeed(
          "echo $(( $(date +%s) - 700 )) > /var/lib/memory-emergency-guard/last-trip"
      )
      out = run_guard("zone2")
      assert_all_down()
      machine.succeed(
          "echo $(( $(date +%s) - 700 )) > /var/lib/memory-emergency-guard/last-trip"
      )
      out = run_guard("zramfull")
      assert "restore capped" in out, (
          "the third restore of the day must be refused (anti-churn cap) — "
          "socket stays down, restore_capped 1, human restart required"
      )
      machine.fail("systemctl is-active --quiet fastflowlm.socket")
      prom = machine.succeed("cat /var/lib/prometheus-node-exporter/textfile_collectors/memory-emergency-guard.prom")
      assert "memory_emergency_guard_restore_capped 1" in prom
      assert "memory_emergency_guard_zone2_trips_total 3" in prom

      # --- 6b. Zone 5 (episodic avg10, avg60 LOW) — the CALIBRATED 16:34
      #      signature: the real boot's avg60 peaked at 3.93% (SigNoz); only
      #      the episode PATTERN was the observable pre-freeze signal.
      reset_state()
      machine.succeed("${writeFakes "episodic" episodic}")
      for i in range(1, 8):
          out = run_guard("episodic")
          assert "MEMORY EMERGENCY" not in out, (
              f"episode run {i}/8 must not trip yet (leaky bucket not full)"
          )
      out = run_guard("episodic")
      assert "episodic stall" in out, (
          "Zone 5 must trip at the 8th accumulated avg10 episode with avg60 "
          "LOW — the calibrated 2026-08-31 16:34 signature the averages never saw"
      )
      assert_all_down()
      prom = machine.succeed("cat /var/lib/prometheus-node-exporter/textfile_collectors/memory-emergency-guard.prom")
      assert "memory_emergency_guard_psi_episodes 8" in prom

      # --- 6c. Episode decay: bursts then clean runs drain the bucket ------
      reset_state()
      for i in range(4):
          run_guard("episodic")
      run_guard("healthy")
      out = run_guard("healthy")
      assert "MEMORY EMERGENCY" not in out, (
          "4 episodes + clean runs must decay below the trip count — a burst "
          "pattern must not latch the trip"
      )
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
