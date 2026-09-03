# VM test for the SEV1 escalation bridge.
#
# Regression test for the 2026-08-22 freeze lesson: Gatus fired
# "Memory pressure CRITICAL" 43 min before freeze #1 and 17 s before
# freeze #2 — the warnings existed, the human loop did not. Exercises the
# REAL bridge script (the deployed ExecStart binary) with env-overridden
# prom sources — only the metrics inputs are faked.
#
# TIER CONTRACT (2026-09-02 user decisions, the movie-interruption finale
# + "yellow, non-flashing, once" refinement):
#   NO memory-related condition may EVER overlay. page = RESERVED (red
#   pulsing, no current emitter). warn = infra hardware criticals
#   (DAS/NIC/btrfs): static amber TOP-STRIP banner (non-fullscreen), shown
#   ONCE per alert set (the
#   bridge downgrades same-set refreshes to "warn-seen"). notify = one
#   self-expiring notification, no overlay.
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
#   6b. Monitoring stale: NOTIFY tier — alert file written with severity
#       "notify" (line 4), page_alerts_active 0, and re-notification
#       after a clear/refire cycle suppressed by the cooldown (the
#       2026-08-31 movie-night flap class: 4 consecutive collector
#       timeouts re-paged the fullscreen overlay every cycle).
#   7. Clear: healthy inputs again — alert file REMOVED, state cleared,
#       alerts_active 0.
#   8. Boot grace: pre-shutdown-stale guard prom on a FRESH boot (< 600s
#      uptime) must NOT page GUARD DEAD / STALE (2026-08-31 false-page class).
{ pkgs }: {
  name = "sev1-escalation";

  nodes.machine = { ... }: {
    imports = [
      ((import ../modules/nixos/services/sev1-escalation.nix) { }).flake.nixosModules.sev1-escalation
    ];

    services.sev1-escalation.enable = true;

    # Dummy stand-ins for the timers the bridge's module-presence gate
    # checks (is-enabled) — avoids importing the full guard/system-health
    # modules into the VM.
    systemd.timers.memory-emergency-guard = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnBootSec = "1h";
    };
    systemd.timers.system-health-metrics = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnBootSec = "1h";
    };

    system.stateVersion = "25.11";
  };

  testScript =
    let
      guardPromHealthy = ''
        # HELP memory_emergency_guard_last_trip_recent 1 if an emergency stop happened within the last 30 min, 0 otherwise
        # TYPE memory_emergency_guard_last_trip_recent gauge
        memory_emergency_guard_last_trip_recent 0
      '';
      guardPromTripped = ''
        # HELP memory_emergency_guard_last_trip_recent 1 if an emergency stop happened within the last 30 min, 0 otherwise
        # TYPE memory_emergency_guard_last_trip_recent gauge
        memory_emergency_guard_last_trip_recent 1
        # HELP memory_emergency_guard_sacrifice_socket_active 1 when any sacrifice socket is accepting, 0 when sacrificed
        # TYPE memory_emergency_guard_sacrifice_socket_active gauge
        memory_emergency_guard_sacrifice_socket_active 0
      '';
      # 2026-09-02: the trip RESOLVED — the guard restored the sockets (the
      # machine recovered to 53% avail / 0.26% PSI while zram stayed at 97%).
      # last_trip_recent is still 1 inside its 30-min window, but the
      # EMERGENCY is over: the bridge must NOT keep fullscreen-paging.
      guardPromTripResolved = ''
        # HELP memory_emergency_guard_last_trip_recent 1 if an emergency stop happened within the last 30 min, 0 otherwise
        # TYPE memory_emergency_guard_last_trip_recent gauge
        memory_emergency_guard_last_trip_recent 1
        # HELP memory_emergency_guard_sacrifice_socket_active 1 when any sacrifice socket is accepting, 0 when sacrificed
        # TYPE memory_emergency_guard_sacrifice_socket_active gauge
        memory_emergency_guard_sacrifice_socket_active 1
      '';
      # ZRAM SWAP CRITICAL fixtures (combined-gate): fill over threshold +
      # degraded margins must notify; the LIVE 2026-09-02 steady state
      # (97% fill, 53% avail, 0.26% PSI) must stay silent.
      guardPromZramMarginal = ''
        memory_emergency_guard_last_trip_recent 0
        memory_emergency_guard_sacrifice_socket_active 1
        memory_emergency_guard_psi_some_avg10_percent 2.00
        memory_emergency_guard_avail_percent 12.00
      '';
      guardPromZramSteady = ''
        memory_emergency_guard_last_trip_recent 0
        memory_emergency_guard_sacrifice_socket_active 1
        memory_emergency_guard_psi_some_avg10_percent 0.26
        memory_emergency_guard_avail_percent 53.00
      '';
      # Churn: a trip alert with >=2 trips in the last hour - the detail
      # must carry the re-wake-loop warning (2026-09-02).
      guardPromChurn = ''
        memory_emergency_guard_last_trip_recent 1
        memory_emergency_guard_sacrifice_socket_active 0
        memory_emergency_guard_trips_last_hour 3
      '';
      # Anti-churn cap spent + socket still down: notify tier with the
      # manual restart path (the trip alert has long cleared by then).
      guardPromCapped = ''
        memory_emergency_guard_last_trip_recent 0
        memory_emergency_guard_sacrifice_socket_active 0
        memory_emergency_guard_restore_capped 1
      '';
      # 2026-08-31 16:34 freeze signature: sustained stall, guard NOT (yet)
      # tripped, zram/avail invisible to this condition.
      guardPromStall = ''
        # HELP memory_emergency_guard_last_trip_recent 1 if an emergency stop happened within the last 30 min, 0 otherwise
        # TYPE memory_emergency_guard_last_trip_recent gauge
        memory_emergency_guard_last_trip_recent 0
        # HELP memory_emergency_guard_psi_some_avg60_percent PSI memory some avg60 stall percent
        # TYPE memory_emergency_guard_psi_some_avg60_percent gauge
        memory_emergency_guard_psi_some_avg60_percent 52.00
      '';
      # The CALIBRATED 16:34 signature (SigNoz): avg60 NEVER exceeded ~4% —
      # the observable pre-freeze signal is the episode bucket alone.
      guardPromEpisodic = ''
        # HELP memory_emergency_guard_last_trip_recent 1 if an emergency stop happened within the last 30 min, 0 otherwise
        # TYPE memory_emergency_guard_last_trip_recent gauge
        memory_emergency_guard_last_trip_recent 0
        # HELP memory_emergency_guard_psi_some_avg60_percent PSI memory some avg60 stall percent
        # TYPE memory_emergency_guard_psi_some_avg60_percent gauge
        memory_emergency_guard_psi_some_avg60_percent 3.00
        # HELP memory_emergency_guard_psi_episodes Leaky-bucket count of avg10 stall episodes
        # TYPE memory_emergency_guard_psi_episodes gauge
        memory_emergency_guard_psi_episodes 5
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
      healthPromZram = ''
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
        system_zram_fill_over_threshold 1
      '';

      # Single-line blobs with literal \n escapes for the Python heredocs.
      blob = text: builtins.replaceStrings [ "\n" ] [ "\\n" ] (pkgs.lib.removeSuffix "\n" text);

      writeProms =
        name: guard: health:
        "mkdir -p /tmp/sev1 && printf '${blob guard}\\n' > /tmp/sev1/${name}-guard.prom && printf '${blob health}\\n' > /tmp/sev1/${name}-health.prom";
    in
    ''
      machine.start()
      machine.wait_for_unit("multi-user.target")
      # Stop the bridge timer so background runs cannot race assertions.
      machine.succeed("systemctl stop sev1-bridge.timer")
      # StateDirectory contract (the unit never ran via systemd yet).
      machine.succeed("mkdir -p /var/lib/sev1-escalation")

      script = machine.succeed(
          "grep -oP '^ExecStart=\\K.*' /etc/systemd/system/sev1-bridge.service"
      ).strip()

      def run_bridge_raw(guard_prom, health_prom):
          return machine.succeed(
              f"SEV1_BOOT_GRACE_SEC=0"
              f" GUARD_PROM={guard_prom}"
              f" HEALTH_PROM={health_prom}"
              f" SEV1_ALERT_FILE=/tmp/sev1/alert"
              f" SEV1_PROM_OUT=/tmp/sev1/bridge.prom {script} 2>&1"
          )

      def run_bridge(case):
          # SEV1_BOOT_GRACE_SEC=0: the VM is freshly booted (< 600s uptime),
          # so the boot-grace window would otherwise suppress the very
          # DEAD/STALE scenarios these assertions verify.
          return machine.succeed(
              f"SEV1_BOOT_GRACE_SEC=0"
              f" GUARD_PROM=/tmp/sev1/{case}-guard.prom"
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
      # Third line = generated-at epoch (the overlay's self-expiry anchor),
      # fourth line = severity ("page" = fullscreen overlay eligible).
      lines = alert.strip().split("\n")
      assert len(lines) == 4 and lines[2].isdigit(), "alert file must be title/detail/epoch/severity"
      assert "severity=notify" in out, (
          "guard trip must be NOTIFY tier (2026-09-02 movie-interruption "
          "decision: high memory must never fullscreen-page)"
      )
      assert lines[3] == "notify", "guard trip must be NOTIFY tier (no fullscreen overlay)"
      machine.succeed("test -f /var/lib/sev1-escalation/last-alert-key")
      prom = machine.succeed("cat /tmp/sev1/bridge.prom")
      assert "sev1_bridge_alerts_active 1" in prom
      assert "sev1_bridge_page_alerts_active 0" in prom, (
          "a memory trip alone must never count as page-tier"
      )

      # --- 3. Dedup: same condition again — key unchanged ----------------
      key1 = machine.succeed("cat /var/lib/sev1-escalation/last-alert-key").strip()
      run_bridge("trip")
      key2 = machine.succeed("cat /var/lib/sev1-escalation/last-alert-key").strip()
      assert key1 == key2, "unchanged alert set must not re-notify"

      # --- 3b. Sustained memory stall (avg60 >= 45) escalates WITHOUT a
      #         guard trip — the 2026-08-31 16:34 class: Discord flapped
      #         for 2 h while the user sat at the machine. Desktop
      #         visibility via the notify tier (one self-expiring
      #         notification) — NEVER a fullscreen overlay (2026-09-02
      #         movie-interruption decision).
      machine.succeed("${writeProms "stall" guardPromStall healthPromHealthy}")
      out = run_bridge("stall")
      assert "MEMORY STALL SUSTAINED" in out, (
          "guard avg60 >= 45% must escalate to the desktop even without a "
          "guard trip (the 16:34 freeze class)"
      )
      assert "severity=notify" in out, "memory stall must be NOTIFY tier (no fullscreen overlay)"
      alert = machine.succeed("cat /tmp/sev1/alert")
      assert "MEMORY STALL SUSTAINED" in alert
      assert "Stop heavy builds" in alert
      assert alert.strip().split("\n")[3] == "notify"

      # --- 3c. EPISODIC stall (episode bucket >= 4, avg60 LOW) — the
      #         CALIBRATED 16:34 signature: the real boot's avg60 never
      #         exceeded ~4%; the episode pattern is the only pre-freeze
      #         observable. Must escalate — notify tier, no overlay.
      machine.succeed("${writeProms "episodic" guardPromEpisodic healthPromHealthy}")
      out = run_bridge("episodic")
      assert "MEMORY STALL SUSTAINED" in out, (
          "episode bucket >= 4 with LOW avg60 must escalate — the calibrated "
          "2026-08-31 signature (avg60 averaged the episodic spikes away)"
      )
      alert = machine.succeed("cat /tmp/sev1/alert")
      assert "episode bucket=5" in alert
      assert alert.strip().split("\n")[3] == "notify", "episodic stall must be NOTIFY tier"

      # --- 4. Guard dead: prom deleted while timer ENABLED ---------------
      machine.succeed("rm -f /tmp/sev1/dead-guard.prom; printf 'irrelevant\\n' > /tmp/sev1/dead-health.prom")
      out = machine.succeed(
          "SEV1_BOOT_GRACE_SEC=0"
          " GUARD_PROM=/tmp/sev1/does-not-exist.prom"
          " HEALTH_PROM=/tmp/sev1/dead-health.prom"
          " SEV1_ALERT_FILE=/tmp/sev1/alert"
          " SEV1_PROM_OUT=/tmp/sev1/bridge.prom {script} 2>&1".format(script=script)
      )
      assert "MEMORY GUARD DEAD" in out, (
          "missing guard metrics with the guard ENABLED must escalate "
          "(trip capability lost)"
      )
      assert "severity=notify" in out, "guard dead must be NOTIFY tier (meta condition, no overlay)"
      alert = machine.succeed("cat /tmp/sev1/alert")
      assert alert.strip().split("\n")[3] == "notify"

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
          " SEV1_BOOT_GRACE_SEC=0"
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

      # --- 6. Infra critical: DAS link down — WARN tier (2026-09-02
      #        user decision: yellow, NON-FLASHING, shown ONCE per alert
      #        set). First exposure writes "warn" (the overlay renders
      #        the amber strip); refreshing the SAME alert set
      #        downgrades to "warn-seen" (overlay ignores it). The
      #        "once" lives in the BRIDGE so it survives quickshell
      #        restarts and is testable here.
      machine.succeed("${writeProms "das" guardPromHealthy healthPromDasDown}")
      out = run_bridge("das")
      assert "DAS USB LINK DOWN" in out
      assert "severity=warn" in out, "infra critical must be WARN tier (static yellow banner, no pulsing)"
      alert = machine.succeed("cat /tmp/sev1/alert")
      assert "DAS USB LINK DOWN" in alert
      assert alert.strip().split("\n")[3] == "warn", "first warn exposure must render the banner"
      prom = machine.succeed("cat /tmp/sev1/bridge.prom")
      assert "sev1_bridge_page_alerts_active 0" in prom, "warn is not page-tier"
      # Repeat run: SAME alert set → warn-seen (shown ONCE).
      out = run_bridge("das")
      alert = machine.succeed("cat /tmp/sev1/alert")
      assert alert.strip().split("\n")[3] == "warn-seen", (
          "the yellow banner must show only ONCE per alert set (same-set "
          "refreshes must downgrade to warn-seen)"
      )
      # A CHANGED alert set re-arms the banner: DAS + BTRFS is a new key.
      machine.succeed(
          "printf 'system_das_link_present 0\\nsystem_lan_nic_present 1\\nbtrfs_health_critical 1\\nsystem_zram_fill_over_threshold 0\\n'"
          " > /tmp/sev1/das-health.prom"
      )
      out = run_bridge("das")
      assert "BTRFS CRITICAL" in out
      alert = machine.succeed("cat /tmp/sev1/alert")
      assert alert.strip().split("\n")[3] == "warn", "a changed alert set must re-arm the warn banner"

      # --- 6b. Monitoring stale: NOTIFY tier, no overlay, cooldown-gated --
      # The 2026-08-31 movie-night class: the collector flapped stale for
      # ~10 min and the bridge fullscreen-paged on EVERY cycle. Stale must
      # write the alert file with severity "notify" (overlay ignores it),
      # report page_alerts_active 0, and suppress re-notification within
      # the cooldown window across a clear/refire cycle.
      out = run_bridge_raw("/tmp/sev1/healthy-guard.prom", "/tmp/sev1/does-not-exist.prom")
      assert "MONITORING STALE" in out, "missing health prom with the module ENABLED must still escalate"
      assert "severity=notify" in out, "monitoring stale must be NOTIFY tier (no fullscreen overlay)"
      alert = machine.succeed("cat /tmp/sev1/alert")
      stale_lines = alert.strip().split("\n")
      assert stale_lines[3] == "notify", "alert file line 4 must carry the notify severity for the overlay"
      prom = machine.succeed("cat /tmp/sev1/bridge.prom")
      assert "sev1_bridge_alerts_active 1" in prom
      assert "sev1_bridge_page_alerts_active 0" in prom, "stale-only must not count as page-tier"
      machine.succeed("ls /var/lib/sev1-escalation | grep -q '^last-notify-'")

      # Flap: clear, then immediately re-fire stale — within the 1800s
      # cooldown the notify-tier notification must be suppressed (the
      # alert file itself is still written; only the desktop notification
      # is gated).
      run_bridge("healthy")
      out = run_bridge_raw("/tmp/sev1/healthy-guard.prom", "/tmp/sev1/does-not-exist.prom")
      assert "suppressed (cooldown" in out, "a stale clear/refire flap must not re-notify within the cooldown"
      machine.succeed("test -f /tmp/sev1/alert")

      # --- 7. Clear: healthy again — alert removed ------------------------
      out = run_bridge("healthy")
      assert "SEV1 cleared" in out
      machine.fail("test -f /tmp/sev1/alert")
      machine.fail("test -f /var/lib/sev1-escalation/last-alert-key")
      prom = machine.succeed("cat /tmp/sev1/bridge.prom")
      assert "sev1_bridge_alerts_active 0" in prom

      # --- 8. Boot grace: stale guard prom on a FRESH boot must NOT page ---
      # No SEV1_BOOT_GRACE_SEC override: the VM's uptime is < 600s, so the
      # grace window applies — the pre-boot-stale prom from scenario 4's
      # inputs is exactly the false-page class fixed on 2026-08-31.
      out = machine.succeed(
          "GUARD_PROM=/tmp/sev1/does-not-exist.prom"
          " HEALTH_PROM=/tmp/sev1/dead-health.prom"
          " SEV1_ALERT_FILE=/tmp/sev1/alert"
          " SEV1_PROM_OUT=/tmp/sev1/bridge.prom {script} 2>&1".format(script=script)
      )
      assert "GUARD DEAD" not in out, (
          "a fresh boot (< bootGraceSeconds) must not page GUARD DEAD from "
          "pre-shutdown-stale metrics"
      )
      assert "MONITORING STALE" not in out, "boot grace must suppress STALE too"
      machine.fail("test -f /tmp/sev1/alert")

      # --- 9. Trip alert lifecycle (2026-09-02): the alert tracks the
      #         EMERGENCY, not the 30-min last_trip_recent window.
      # 9a. Trip resolved (sockets restored, machine healthy): NO alert.
      machine.succeed("${writeProms "resolved" guardPromTripResolved healthPromHealthy}")
      out = run_bridge("resolved")
      assert "GUARD TRIPPED" not in out, (
          "a resolved trip (sacrifice restored at 53% avail) must not keep "
          "alerting — the 2026-09-02 30-min-overlay spam class"
      )
      machine.fail("test -f /tmp/sev1/alert")

      # 9b. Trip ACTIVE (sacrifice still down) alerts even 30+ min later if
      #     the sockets never came back — the alert IS "flm is unreachable"
      #     (notify tier — the guard contains the emergency automatically;
      #     fullscreen for memory states is banned, 2026-09-02).
      machine.succeed("${writeProms "tripactive" guardPromTripped healthPromHealthy}")
      out = run_bridge("tripactive")
      assert "MEMORY EMERGENCY GUARD TRIPPED" in out
      alert = machine.succeed("cat /tmp/sev1/alert")
      assert alert.strip().split("\n")[3] == "notify", (
          "an active trip must be NOTIFY tier — no memory fullscreen, ever"
      )

      # 9c. Churn context: >=2 trips in the last hour appends the re-wake
      #     warning to the trip alert detail (same title set -> the dedup
      #     keeps the notification quiet, but the alert file carries it).
      machine.succeed("${writeProms "churn" guardPromChurn healthPromHealthy}")
      out = run_bridge("churn")
      assert "MEMORY EMERGENCY GUARD TRIPPED" in out
      alert = machine.succeed("cat /tmp/sev1/alert")
      assert "TRIP CHURN" in alert, (
          "trip churn (>=2 trips/hour) must be surfaced in the alert detail"
      )
      assert alert.strip().split("\n")[3] == "notify"

      # --- 10. ZRAM SWAP CRITICAL is NOTIFY tier (2026-09-02 user
      #         decision): combined-gated; the guard handles the cliff
      #         automatically and NO memory state may fullscreen (the
      #         2026-09-02 movie-interruption decision).
      machine.succeed("${writeProms "zram" guardPromZramMarginal healthPromZram}")
      out = run_bridge("zram")
      assert "ZRAM SWAP CRITICAL" in out
      assert "severity=notify" in out, "zram critical must be NOTIFY tier (no overlay)"
      alert = machine.succeed("cat /tmp/sev1/alert")
      assert alert.strip().split("\n")[3] == "notify"
      assert "suppressed (cooldown" not in out, (
          "a ZRAM notify after a STALE notify must still deliver - the "
          "notify cooldown is PER-KEY since 2026-09-02 (the old single "
          "epoch file cross-suppressed unrelated conditions)"
      )
      prom = machine.succeed("cat /tmp/sev1/bridge.prom")
      assert "sev1_bridge_alerts_active 1" in prom
      assert "sev1_bridge_page_alerts_active 0" in prom, (
          "zram-only must not count as page-tier"
      )
      assert "sev1_bridge_page_active_seconds 0" in prom, (
          "notify-tier only: the active page duration must be back to 0"
      )
      assert "sev1_bridge_page_last_duration_seconds" in prom

      # 10b. The LIVE 2026-09-02 steady state (97% fill, 53% avail,
      #      0.26% PSI) must stay completely silent. The bridge's
      #      clear-transition message ("SEV1 cleared") is expected here —
      #      scenario 10 had just armed the notify-tier alert — so assert
      #      on the ACTIVE marker, not the bare "SEV1" prefix.
      machine.succeed("${writeProms "zramsteady" guardPromZramSteady healthPromZram}")
      out = run_bridge("zramsteady")
      assert "SEV1 active" not in out, (
          "zram near-full with healthy margins is steady-state normal on "
          "this box (the live 2026-09-02 alert-spam source)"
      )
      assert "SEV1 cleared" in out, "the scenario-10 notify alert must clear on healthy margins"
      machine.fail("test -f /tmp/sev1/alert")

      # --- 11. Restore capped (anti-churn budget spent, socket down):
      #         notify tier with the manual restart path - without this,
      #         flm would silently stay unusable after the trip alert
      #         clears.
      machine.succeed("${writeProms "capped" guardPromCapped healthPromHealthy}")
      out = run_bridge("capped")
      assert "FLM RESTORE CAPPED" in out
      assert "severity=notify" in out
      alert = machine.succeed("cat /tmp/sev1/alert")
      assert "systemctl start fastflowlm.socket" in alert
      assert alert.strip().split("\n")[3] == "notify", (
          "capped is a degraded-service heads-up, not a drop-everything page"
      )
      prom = machine.succeed("cat /tmp/sev1/bridge.prom")
      assert "sev1_bridge_page_alerts_active 0" in prom
    '';
}
