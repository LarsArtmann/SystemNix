# SEV1 escalation bridge — making critical alerts unmissable.
#
# The 2026-08-22 double freeze postmortem: Gatus fired "Memory pressure
# CRITICAL" to Discord 43 min before freeze #1 and 17 s before freeze #2 —
# the warnings existed, the human loop did not. User decision (2026-08-22):
# Discord stays the phone channel; when a graphical session is online,
# criticals additionally get (a) a DMS desktop notification and (b) a
# fullscreen red overlay (shutdown-overlay pattern) that cannot be missed
# from across the room.
#
# Architecture:
#   sev1-bridge.service (system, root, every 10 s):
#     - Evaluates SEV1 conditions from the local textfile collectors
#       (guard trip, guard DEAD, monitoring stale, DAS link down, LAN NIC
#       absent, btrfs critical, zram critical).
#     - Active: rewrites /run/systemnix/sev1/alert every run (title,
#       detail, generated-at epoch). The overlay SELF-EXPIRES when the
#       file is older than alertTtlSeconds — a dead bridge can never
#       leave a stuck overlay on screen.
#     - Transitions into a NEW alert set: one DMS notification via
#       `systemd-run --machine=<user>@.host --user` (the AGENTS-documented
#       machined bus proxy; best-effort, no session = no-op) — deduped via
#       a state file, so a persistent alert notifies once, not every 10 s.
#     - Clear: removes the alert file.
#     - Emits sev1-bridge.prom (fail-closed presence metric).
#   sev1-overlay.service (user, graphical-session.target):
#     - Quickshell fullscreen banner while the alert file is fresh.
#
# Overlay triggers (user decision): guard-trip, infra-criticals,
# guard-dead. The PSI warning tier (psi-metrics) deliberately does NOT
# overlay — Discord + notification only.
_: {
  flake.nixosModules.sev1-escalation =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        mkStateDir
        ;

      cfg = config.services.sev1-escalation;
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      stateDir = "/var/lib/sev1-escalation";
      alertFile = "/run/systemnix/sev1/alert";

      bridgeScript = pkgs.writeShellApplication {
        name = "sev1-bridge-check";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.gnused
          pkgs.systemd
        ];
        text = ''
          set -euo pipefail

          # Env-overridable sources for the VM regression test.
          GUARD_PROM="''${GUARD_PROM:-${textfileDir}/memory-emergency-guard.prom}"
          HEALTH_PROM="''${HEALTH_PROM:-${textfileDir}/system_health.prom}"
          ALERT_FILE="''${SEV1_ALERT_FILE:-${alertFile}}"
          STATE_FILE="${stateDir}/last-alert-key"
          OUT="''${SEV1_PROM_OUT:-${textfileDir}/sev1-bridge.prom}"
          TMP="''${OUT}.tmp"
          DESKTOP_USER="${cfg.desktopUser}"

          mkdir -p "$(dirname "$ALERT_FILE")" "$(dirname "$OUT")"

          now=$(date +%s)
          titles=()
          details=()

          # Boot grace: on a fresh boot the textfile metrics are legitimately
          # absent/stale (their last write happened pre-shutdown; collectors
          # haven't ticked yet) and system_health.prom may hold pre-shutdown
          # values. Skipping DEAD/STALE and infra-critical evaluation for the
          # first bootGraceSeconds avoids a false SEV1 page on EVERY reboot
          # (observed 2026-08-31: "MEMORY GUARD DEAD (303s old)" paged 60s
          # after boot). Env-overridable for the VM regression test.
          BOOT_GRACE_SEC=''${SEV1_BOOT_GRACE_SEC:-${toString cfg.bootGraceSeconds}}
          BOOT_GRACE=0
          if [ -r /proc/uptime ]; then
            if [ "$(cut -d' ' -f1 /proc/uptime | cut -d. -f1)" -lt "$BOOT_GRACE_SEC" ]; then
              BOOT_GRACE=1
            fi
          fi

          # Module presence gates: on a host where the guard/health modules
          # are DISABLED their prom files legitimately never exist — treat
          # that as "not applicable", not as DEAD/STALE. SYSTEMCTL_BIN is
          # env-overridable for the VM regression test (the wrapper's
          # runtimeInputs PREPEND to PATH — a PATH-shim systemctl loses).
          SYSTEMCTL_BIN="''${SYSTEMCTL_BIN:-systemctl}"
          guard_enabled=false
          "$SYSTEMCTL_BIN" is-enabled --quiet memory-emergency-guard.timer 2>/dev/null && guard_enabled=true
          health_enabled=false
          "$SYSTEMCTL_BIN" is-enabled --quiet system-health-metrics.timer 2>/dev/null && health_enabled=true

          prom_value() {
            # prom_value <file> <metric> [expected-args] -> prints first match
            awk -v m="$2" '$0 == m || index($0, m " ") == 1 { print $2; exit }' "$1" 2>/dev/null
          }

          file_age() {
            local f=$1
            if [ -f "$f" ]; then
              echo $(( now - $(stat -c %Y "$f" 2>/dev/null || echo "$now") ))
            else
              echo -1
            fi
          }

          # --- Guard trip (the guard ACTED: machine entered a pre-freeze zone)
          guard_trip=0
          if [ "$BOOT_GRACE" = "0" ] && [ "$guard_enabled" = "true" ] && [ -f "$GUARD_PROM" ]; then
            v=$(prom_value "$GUARD_PROM" "memory_emergency_guard_last_trip_recent")
            [ "$v" = "1" ] && guard_trip=1
          fi
          if [ "$guard_trip" = "1" ]; then
            titles+=("MEMORY EMERGENCY GUARD TRIPPED")
            details+=("The machine entered a pre-freeze zone; FastFlowLM + socket were force-stopped. journalctl -u memory-emergency-guard -n 30")
          fi

          # --- Sustained memory stall (2026-08-31 16:34 freeze class: the
          #     box froze with zram EMPTY, MemAvailable healthy, zero OOM
          #     kills — Discord flapped "Memory pressure CRITICAL" for 2 h
          #     while the user sat at the machine. The desktop must page on
          #     the same SUSTAINED signal Zone 4 trips on: avg60 >= 45,
          #     slightly below the trip threshold so the page can precede
          #     the guard action. Guard-gated, NOT health-gated: during the
          #     final stall the system-health collector dies FIRST (live
          #     16:33) — only its own stale-page would fire, without the
          #     actionable shed-load detail.)
          if [ "$guard_enabled" = "true" ] && [ -f "$GUARD_PROM" ]; then
            g_avg60=$(prom_value "$GUARD_PROM" "memory_emergency_guard_psi_some_avg60_percent")
            g_avg60="''${g_avg60:--1}"
            if awk "BEGIN{exit !($g_avg60 >= 45)}"; then
              titles+=("MEMORY STALL SUSTAINED")
              details+=("PSI memory some avg60=''${g_avg60}% — over half the tasks on the machine have been stalled on memory for a full minute (freeze precursor, 2026-08-31 class). Stop heavy builds / VM tests NOW; the guard is sacrificing FastFlowLM.")
            fi
          fi

          # --- Guard dead (trip capability lost — the guard that should fire
          #     during an emergency is itself down or its metrics vanished)
          guard_age=$(file_age "$GUARD_PROM")
          if [ "$BOOT_GRACE" = "0" ] && [ "$guard_enabled" = "true" ] && { [ "$guard_age" -lt 0 ] || [ "$guard_age" -gt $(( ${toString cfg.staleGuardSeconds} )) ]; }; then
            titles+=("MEMORY GUARD DEAD")
            details+=("memory-emergency-guard metrics are missing/stale (''${guard_age}s old). The automated freeze protection is DOWN. systemctl status memory-emergency-guard")
          fi

          # --- Monitoring stale (system-health textfile collector dead)
          health_age=$(file_age "$HEALTH_PROM")
          if [ "$BOOT_GRACE" = "0" ] && [ "$health_enabled" = "true" ] && { [ "$health_age" -lt 0 ] || [ "$health_age" -gt $(( ${toString cfg.staleHealthSeconds} )) ]; }; then
            titles+=("SYSTEM MONITORING STALE")
            details+=("system_health metrics missing/stale (''${health_age}s old). Most Gatus conditions are phantom right now. systemctl status system-health-metrics")
          fi

          # --- Infra criticals from system_health.prom
          if [ "$BOOT_GRACE" = "0" ] && [ "$health_enabled" = "true" ] && [ -f "$HEALTH_PROM" ]; then
            v=$(prom_value "$HEALTH_PROM" "system_das_link_present")
            if [ "$v" = "0" ]; then
              titles+=("DAS USB LINK DOWN")
              details+=("All external disks (pool + buildcache) share one USB link that just dropped. Physical reseat + reboot may be needed.")
            fi
            v=$(prom_value "$HEALTH_PROM" "system_lan_nic_present")
            if [ "$v" = "0" ]; then
              titles+=("LAN NIC ABSENT")
              details+=("The RTL8125 fell off the PCIe bus. Power-cycle (full shutdown ~10s, not warm reboot).")
            fi
            v=$(prom_value "$HEALTH_PROM" "btrfs_health_critical")
            if [ "$v" = "1" ]; then
              titles+=("BTRFS CRITICAL")
              details+=("Filesystem in CRITICAL state (unalloc/meta envelope). btrfs-health metrics; do not add load.")
            fi
            v=$(prom_value "$HEALTH_PROM" "system_zram_fill_over_threshold")
            if [ "$v" = "1" ]; then
              # zram near-full ALONE is steady-state normal on this box
              # (swappiness=150 keeps cold anon compressed in zram; measured
              # 98.5% with PSI 0.00 and 25% avail on 2026-08-22 evening).
              # Escalate only when margins are ALSO degraded — mirror the
              # emergency guard's combined-zone semantics. Guard metrics are
              # the PSI/avail source (-1 = guard absent → no escalation).
              g_psi=$(prom_value "$GUARD_PROM" "memory_emergency_guard_psi_some_avg10_percent")
              g_avail=$(prom_value "$GUARD_PROM" "memory_emergency_guard_avail_percent")
              g_psi="''${g_psi:--1}"
              g_avail="''${g_avail:--1}"
              if awk "BEGIN{exit !($g_psi >= 5)}" || awk "BEGIN{exit !($g_avail >= 0 && $g_avail < 15)}"; then
                titles+=("ZRAM SWAP CRITICAL")
                details+=("zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=''${g_psi}%, MemAvailable=''${g_avail}%) — shmem becomes unevictable past 100%. The guard should trip; shed load now.")
              fi
            fi
          fi

          alerts_active=''${#titles[@]}

          if [ "$alerts_active" -gt 0 ]; then
            title=$(printf '%s; ' "''${titles[@]}" | sed 's/; $//')
            detail=$(printf '%s | ' "''${details[@]}" | sed 's/ | $//')

            # Rewrite every run: freshness IS the liveness signal for the
            # overlay (it self-expires when the file goes stale).
            printf '%s\n%s\n%s\n' "$title" "$detail" "$now" > "$ALERT_FILE"
            chmod 0644 "$ALERT_FILE"
            echo "SEV1 active (''${alerts_active} condition(s)): $title" >&2

            # Notify ONLY on transition into a new alert set (dedup via
            # state file) — a persistent condition notifies once.
            key=$(printf '%s\n' "''${titles[@]}" | sort | tr '\n' ',')
            prev_key=""
            [ -f "$STATE_FILE" ] && prev_key=$(cat "$STATE_FILE" 2>/dev/null || true)
            if [ "$key" != "$prev_key" ]; then
              echo "$key" > "''${STATE_FILE}.tmp"
              mv "''${STATE_FILE}.tmp" "$STATE_FILE"
              # Best-effort DMS desktop notification via the machined user
              # bus proxy (AGENTS: root -> user-manager needs --machine).
              systemd-run --machine="$DESKTOP_USER@.host" --user --collect \
                ${lib.getExe' pkgs.libnotify "notify-send"} \
                -u critical -t 0 "SEV1: $title" "$detail" 2>/dev/null || true
            fi
          else
            rm -f "$ALERT_FILE"
            if [ -f "$STATE_FILE" ]; then
              rm -f "$STATE_FILE"
              echo "SEV1 cleared — conditions recovered" >&2
            fi
          fi

          {
            # Persist the run counter BEFORE the redirected emission block —
            # inside `{ ... } > "$TMP" every echo is redirected to the
            # metrics file, not the state file.
            runs=0
            if [ -f "${stateDir}/runs.count" ]; then
              runs=$(cat "${stateDir}/runs.count" 2>/dev/null) || runs=0
            fi
            runs="''${runs:-0}"
            runs=$(( runs + 1 ))
            echo "$runs" > "${stateDir}/runs.count.tmp" 2>/dev/null && mv "${stateDir}/runs.count.tmp" "${stateDir}/runs.count" || true

            echo "# HELP sev1_bridge_alerts_active Number of active SEV1 conditions (guard trip/dead, monitoring stale, infra criticals)"
            echo "# TYPE sev1_bridge_alerts_active gauge"
            echo "sev1_bridge_alerts_active ''${alerts_active}"
            echo "# HELP sev1_bridge_runs_total Total bridge runs since first deploy"
            echo "# TYPE sev1_bridge_runs_total counter"
            echo "sev1_bridge_runs_total ''${runs}"
          } > "$TMP"
          mv "$TMP" "$OUT"
        '';
      };

      sev1OverlayShell = pkgs.writeTextDir "shell.qml" ''
        pragma ComponentBehavior: Bound

        import QtQuick
        import Quickshell
        import Quickshell.Io
        import Quickshell.Wayland

        ShellRoot {
            id: root

            // Written by sev1-bridge.service every 10s while ANY SEV1
            // condition is active: line 1 title, line 2 detail, line 3
            // generated-at epoch. SELF-EXPIRY: a bridge death can never
            // leave this overlay stuck — it hides once the file is older
            // than the TTL (the bridge refreshes it every run).
            readonly property string alertPath: Quickshell.env("SEV1_ALERT_FILE") || "/run/systemnix/sev1/alert"
            property int alertTtl: {
                const raw = Quickshell.env("SEV1_ALERT_TTL");
                const parsed = raw ? parseInt(raw) : 300;
                return parsed > 0 ? parsed : 300;
            }

            property string alertTitle: ""
            property string alertDetail: ""
            property real generatedAt: 0
            readonly property bool active: root.generatedAt > 0 && (Date.now() / 1000 - root.generatedAt) < root.alertTtl

            function parseAlert(text) {
                const lines = (text ?? "").split("\n");
                const gen = parseInt(lines[2]);
                if (!gen || gen <= 0) {
                    root.generatedAt = 0;
                    root.alertTitle = "";
                    root.alertDetail = "";
                    return;
                }
                root.alertTitle = lines[0] ?? "SEV1";
                root.alertDetail = lines[1] ?? "";
                root.generatedAt = gen;
            }

            FileView {
                id: alertFile
                path: root.alertPath
                watchChanges: true
                printErrors: false
                onLoaded: root.parseAlert(alertFile.text())
                onLoadFailed: {
                    root.generatedAt = 0;
                }
            }

            Timer {
                interval: 500
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    alertFile.reload();
                }
            }

            Variants {
                model: Quickshell.screens

                delegate: PanelWindow {
                    id: overlay

                    required property var modelData

                    screen: modelData
                    visible: root.active
                    updatesEnabled: root.active

                    WlrLayershell.namespace: "systemnix:sev1-overlay"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.exclusionMode: ExclusionMode.Ignore

                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }

                    color: "transparent"
                    mask: Region {}

                    Rectangle {
                        anchors.fill: parent
                        color: "#e61a0505"

                        SequentialAnimation on opacity {
                            running: overlay.visible
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.6
                                duration: 700
                            }
                            NumberAnimation {
                                to: 1
                                duration: 700
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 24

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "SEVERE — SYSTEM EMERGENCY"
                                color: "#ffe0e0"
                                font.pixelSize: Math.min(overlay.width, overlay.height) * 0.035
                                font.weight: Font.Black
                                font.letterSpacing: 10
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.alertTitle
                                color: "#ff2b2b"
                                font.pixelSize: Math.min(overlay.width, overlay.height) * 0.05
                                font.weight: Font.Black
                                font.family: "monospace"
                                wrapMode: Text.Wrap
                                width: Math.min(overlay.width * 0.85, 1400)
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.alertDetail
                                color: "#ffd7d7"
                                font.pixelSize: Math.min(overlay.width, overlay.height) * 0.025
                                font.weight: Font.Bold
                                maximumLineCount: 4
                                wrapMode: Text.Wrap
                                width: Math.min(overlay.width * 0.8, 1200)
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
      '';
    in
    {
      options.services.sev1-escalation = {
        enable = lib.mkEnableOption "SEV1 escalation bridge: local unmissable escalation (DMS notification + fullscreen overlay) for guard-trip, guard-dead and infra-critical conditions when a graphical session is online (2026-08-22 freeze lesson: Discord fired 43min early, nobody saw it)";

        desktopUser = lib.mkOption {
          type = lib.types.str;
          default = "lars";
          description = "User whose graphical session receives the DMS notification and overlay";
        };

        checkInterval = lib.mkOption {
          type = lib.types.str;
          default = "10s";
          description = "Bridge polling interval. Also the alert-file freshness period — the overlay self-expires after two missed refreshes";
        };

        staleGuardSeconds = lib.mkOption {
          type = lib.types.int;
          default = 300;
          description = "Guard metrics age (seconds) beyond which the guard counts as DEAD (SEV1)";
        };

        staleHealthSeconds = lib.mkOption {
          type = lib.types.int;
          default = 600;
          description = "system-health metrics age (seconds) beyond which monitoring counts as STALE (SEV1)";
        };

        bootGraceSeconds = lib.mkOption {
          type = lib.types.int;
          default = 600;
          description = ''
            Seconds after boot during which DEAD/STALE and infra-critical
            evaluations are suppressed: collectors haven't produced fresh
            metrics yet, so every check would page falsely on each reboot
            (live 2026-08-31: a stale pre-shutdown guard prom paged
            "MEMORY GUARD DEAD" one minute into boot). The grace can be
            disabled per-invocation with SEV1_BOOT_GRACE_SEC=0 (used by the
            VM regression test).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        systemd = {
          tmpfiles.rules = [
            (mkStateDir textfileDir "1777" "nobody" "nogroup")
            "d /run/systemnix/sev1 0755 root root -"
          ];

          services.sev1-bridge = {
            description = "SEV1 escalation bridge: local overlay + notification for critical conditions";
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "64M";
                # Sticky 1777 textfile dir: rename-over-foreign-file needs
                # CAP_FOWNER (the 2026-08-22 guard dead-on-arrival lesson).
                CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_OVERRIDE";
              })
              (serviceOneshotDefaults { })
              {
                Type = "oneshot";
                StateDirectory = "sev1-escalation";
                ExecStart = lib.getExe bridgeScript;
                ReadWritePaths = [
                  textfileDir
                  "/run/systemnix/sev1"
                ];
              }
            ];
          };

          timers.sev1-bridge = {
            description = "Run the SEV1 escalation bridge";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "1min";
              OnUnitActiveSec = cfg.checkInterval;
            };
          };

          user.services.sev1-overlay = {
            description = "Fullscreen SEV1 emergency overlay on all monitors";
            after = [ "graphical-session.target" ];
            partOf = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" ];

            environment = {
              SEV1_ALERT_TTL = "120";
            };

            restartTriggers = [ sev1OverlayShell ];

            serviceConfig = {
              Type = "simple";
              ExecStart = "${lib.getExe pkgs.quickshell} -p ${sev1OverlayShell}";
              Restart = "always";
              RestartSec = "5s";
              MemoryMax = "256M";
            };
            startLimitBurst = 5;
            startLimitIntervalSec = 120;
          };
        };
      };
    };
}
