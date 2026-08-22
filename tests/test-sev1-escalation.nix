# VM test for the SEV1 escalation bridge.
#
# Regression test for the 2026-08-22 freeze lesson: Gatus fired
# "Memory pressure CRITICAL" 43 min before freeze #1 and 17 s before
# freeze #2 — the warnings existed, the human loop did not. Exercises the
# REAL bridge script (the deployed ExecStart binary) with env-overridden
# prom sources — only the metrics inputs are faked.
#
# Scenarios:
#   1. Healthy: no alert file, alerts_active 0, prom written.
#   2. Guard trip (last_trip_recent 1): alert file with title, dedup state
#      written, alerts_active 1.
#   3. Dedup: repeat run with the same condition — alert refreshed (new
#      generated-at epoch) but the alert KEY unchanged.
#   4. Guard dead (guard prom deleted while the guard timer is ENABLED):
#      MEMORY GUARD DEAD fires — the trip-capability-lost signal.
#   5. Module-absent gate: guard timer DISABLED + prom still missing —
#      must NOT fire GUARD DEAD (host simply does not run the guard).
#   6. Infra critical (system_das_link_present 0): DAS USB LINK DOWN.
#   7. Clear: healthy inputs again — alert file REMOVED, state cleared,
#      alerts_active 0.
{pkgs}: {
  name = "sev1-escalation";

  nodes.machine = {config, ...}: {
    imports = [
      ((import ../modules/nixos/services/sev1-escalation.nix) {}).flake.nixosModules.sev1-escalation
    ];

    services.sev1-escalation.enable = true;

    # Dummy stand-ins for the timers the bridge's module-presence gate
    # checks (is-enabled) — avoids importing the full guard/system-health
    # modules into the VM.
    systemd.timers.memory-emergency-guard = {
      wantedBy = ["timers.target"];
      timerConfig.OnBootSec = "1h";
    };
    systemd.timers.system-health-metrics = {
      wantedBy = ["timers.target"];
      timerConfig.OnBootSec = "1h";
    };

    system.stateVersion = "25.11";
  };

  testScript = let
    guardPromHealthy = ''
      # HELP memory_emergency_guard_last_trip_recent 1 if an emergency stop happened within the last 30 min, 0 otherwise
      # TYPE memory_emergency_guard_last_trip_recent gauge
      memory_emergency_guard_last_trip_recent 0
    '';
    guardPromTripped = ''
      # HELP memory_emergency_guard_last_trip_recent 1 if an emergency stop happened within the last 30 min, 0 otherwise
      # TYPE memory_emergency_guard_last_trip_recent gauge
      memory_emergency_guard_last_trip_recent 1
    '';
    healthPromHealthy = ''
      # HELP system_das_link_present 1 if the DAS USB link exists
      # TYPE system_das_link_present gauge
      system_das_link_present 1
      # HELP system_lan_nic_present 1 if the primary LAN NIC exists
      # TYPE system_lan_nic_present gauge
      system_lan_nic_present 1
      # HELP btrfs_health_critical 1 if btrfs is critical
      # TYPE btrfs_health_critical gauge
      btrfs_health_critical 0
      # HELP system_zram_fill_over_threshold 1 if zram fill exceeds threshold
      # TYPE system_zram_fill_over_threshold gauge
      system_zram_fill_over_threshold 0
    '';
    healthPromDasDown = ''
      # HELP system_das_link_present 1 if the DAS USB link exists
      # TYPE system_das_link_present gauge
      system_das_link_present 0
      # HELP system_lan_nic_present 1 if the primary LAN NIC exists
      # TYPE system_lan_nic_present gauge
      system_lan_nic_present 1
      # HELP btrfs_health_critical 1 if btrfs is critical
      # TYPE btrfs_health_critical gauge
      btrfs_health_critical 0
      # HELP system_zram_fill_over_threshold 1 if zram fill exceeds threshold
      # TYPE system_zram_fill_over_threshold gauge
      system_zram_fill_over_threshold 0
    '';

    # Single-line blobs with literal \n escapes for the Python heredocs.
    blob = text: builtins.replaceStrings ["\n"] ["\\n"] (pkgs.lib.removeSuffix "\n" text);

    writeProms = name: guard: health: "mkdir -p /tmp/sev1 && printf '${blob guard}\\n' > /tmp/sev1/${name}-guard.prom && printf '${blob health}\\n' > /tmp/sev1/${name}-health.prom";
  in ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    # Stop the bridge timer so background runs cannot race assertions.
    machine.succeed("systemctl stop sev1-bridge.timer")
    # StateDirectory contract (the unit never ran via systemd yet).
    machine.succeed("mkdir -p /var/lib/sev1-escalation")

    script = machine.succeed(
        "grep -oP '^ExecStart=\\K.*' /etc/systemd/system/sev1-bridge.service"
    ).strip()

    def run_bridge(case):
        return machine.succeed(
            f"GUARD_PROM=/tmp/sev1/{case}-guard.prom"
            f" HEALTH_PROM=/tmp/sev1/{case}-health.prom"
            f" SEV1_ALERT_FILE=/tmp/sev1/alert"
            f" SEV1_PROM_OUT=/tmp/sev1/bridge.prom {script} 2>&1"
        )

    # --- 1. Healthy: no alert -----------------------------------------
    machine.succeed("${writeProms "healthy" guardPromHealthy healthPromHealthy}")
    out = run_bridge("healthy")
    assert "SEV1" not in out, "healthy inputs must not escalate"
    machine.fail("test -f /tmp/sev1/alert")
    prom = machine.succeed("cat /tmp/sev1/bridge.prom")
    assert "sev1_bridge_alerts_active 0" in prom
    assert "sev1_bridge_runs_total" in prom

    # --- 2. Guard trip: alert + notification dedup state ---------------
    machine.succeed("${writeProms "trip" guardPromTripped healthPromHealthy}")
    out = run_bridge("trip")
    assert "GUARD TRIPPED" in out
    alert = machine.succeed("cat /tmp/sev1/alert")
    assert "MEMORY EMERGENCY GUARD TRIPPED" in alert
    assert "journalctl -u memory-emergency-guard" in alert
    # Third line = generated-at epoch (the overlay's self-expiry anchor).
    lines = alert.strip().split("\n")
    assert len(lines) == 3 and lines[2].isdigit(), "alert file must be title/detail/epoch"
    machine.succeed("test -f /var/lib/sev1-escalation/last-alert-key")
    prom = machine.succeed("cat /tmp/sev1/bridge.prom")
    assert "sev1_bridge_alerts_active 1" in prom

    # --- 3. Dedup: same condition again — key unchanged ----------------
    key1 = machine.succeed("cat /var/lib/sev1-escalation/last-alert-key").strip()
    run_bridge("trip")
    key2 = machine.succeed("cat /var/lib/sev1-escalation/last-alert-key").strip()
    assert key1 == key2, "unchanged alert set must not re-notify"

    # --- 4. Guard dead: prom deleted while timer ENABLED ---------------
    machine.succeed("rm -f /tmp/sev1/dead-guard.prom; printf 'irrelevant\\n' > /tmp/sev1/dead-health.prom")
    out = machine.succeed(
        "GUARD_PROM=/tmp/sev1/does-not-exist.prom"
        " HEALTH_PROM=/tmp/sev1/dead-health.prom"
        " SEV1_ALERT_FILE=/tmp/sev1/alert"
        " SEV1_PROM_OUT=/tmp/sev1/bridge.prom {script} 2>&1".format(script=script)
    )
    assert "MEMORY GUARD DEAD" in out, (
        "missing guard metrics with the guard ENABLED must escalate "
        "(trip capability lost)"
    )

    # --- 5. Module-absent gate: timer "not enabled", prom still missing ---
    # /etc is a read-only store link in NixOS VMs, so systemctl disable
    # cannot flip the real unit — fake systemctl on PATH instead (every
    # is-enabled probe reports "not enabled" = module absent on this host).
    machine.succeed(
        "mkdir -p /tmp/fakebin && printf '#!/bin/sh\\nexit 1\\n' > /tmp/fakebin/systemctl"
        " && chmod +x /tmp/fakebin/systemctl"
    )
    out = machine.succeed(
        "SYSTEMCTL_BIN=/tmp/fakebin/systemctl"
        " GUARD_PROM=/tmp/sev1/does-not-exist.prom"
        " HEALTH_PROM=/tmp/sev1/dead-health.prom"
        " SEV1_ALERT_FILE=/tmp/sev1/alert"
        " SEV1_PROM_OUT=/tmp/sev1/bridge.prom {script} 2>&1".format(script=script)
    )
    assert "GUARD DEAD" not in out, (
        "a host without the guard module must not page GUARD DEAD forever"
    )
    assert "MONITORING STALE" not in out, (
        "a host without system-health must not page STALE forever either"
    )

    # --- 6. Infra critical: DAS link down -------------------------------
    machine.succeed("${writeProms "das" guardPromHealthy healthPromDasDown}")
    out = run_bridge("das")
    assert "DAS USB LINK DOWN" in out
    alert = machine.succeed("cat /tmp/sev1/alert")
    assert "DAS USB LINK DOWN" in alert

    # --- 7. Clear: healthy again — alert removed ------------------------
    out = run_bridge("healthy")
    assert "SEV1 cleared" in out
    machine.fail("test -f /tmp/sev1/alert")
    machine.fail("test -f /var/lib/sev1-escalation/last-alert-key")
    prom = machine.succeed("cat /tmp/sev1/bridge.prom")
    assert "sev1_bridge_alerts_active 0" in prom
  '';
}
