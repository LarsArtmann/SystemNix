# Yellow top-strip banner (Quickshell layer-shell) while the desktop is offline.
#
# What "offline" means here and why the probe is NOT `nmcli networking
# connectivity`: NetworkManager manages WiFi only on this host — eno1 (the
# real uplink, static IP) is NM-unmanaged, so NM's connectivity state reads
# "none" even while the internet is perfectly reachable (live-verified
# 2026-10-16). The probe is the dual-wan-plugin check instead:
#   1. any real interface (lo/veth/tailscale/wg/... excluded) with carrier 1
#      — else "link" (cable out / wifi dead);
#   2. an ICMP echo to the probe host (default 9.9.9.9, the resolv.conf
#      fallback IP already trusted on this LAN) — else "net" (router up,
#      WAN down). An IP, not a name: DNS here is dnsblockd, and coupling
#      the banner to the resolver would blackhole the banner exactly when
#      the network is half-broken.
# `ping` needs no wrapper on NixOS (nixpkgs iputils ships cap_net_raw).
#
# Rendering follows the shutdown-overlay / sev1-overlay pattern: a SECOND
# Quickshell instance (DMS plugins cannot render layer-shell surfaces) with
# a top-anchored, click-through (mask: Region {}) Overlay-layer strip on
# every screen. STATIC yellow — the sev1 "non-flashing yellow" doctrine
# (2026-09-02): connectivity loss is a warning, not a page. The banner
# appears after `failuresToShow` consecutive failed probes (default 2 =
# ~10 s grace, no flash on a single lost ping) and hides on the first
# clean probe. A probe that cannot even run (empty output) counts as
# "net" — fail visible, never fail silent.
_: {
  flake.nixosModules.offline-banner =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.offline-banner;

      offlineBannerShell = pkgs.writeTextDir "shell.qml" ''
        pragma ComponentBehavior: Bound

        import QtQuick
        import Quickshell
        import Quickshell.Io
        import Quickshell.Wayland

        ShellRoot {
            id: root

            readonly property int intervalMs: {
                const raw = Quickshell.env("OFFLINE_BANNER_INTERVAL");
                const parsed = raw ? parseInt(raw) : 5000;
                return parsed > 500 ? parsed : 5000;
            }
            readonly property int failuresToShow: {
                const raw = Quickshell.env("OFFLINE_BANNER_FAILURES");
                const parsed = raw ? parseInt(raw) : 2;
                return parsed > 0 ? parsed : 2;
            }

            property int failures: 0
            property string reason: ""
            readonly property bool offline: root.failures >= root.failuresToShow
            readonly property string reasonText: root.reason === "link"
                ? "Network link is down"
                : "No internet connection"

            function applyProbe(text) {
                const result = (text ?? "").trim().split("\n")[0];
                if (result === "ok") {
                    root.failures = 0;
                    root.reason = "";
                    return;
                }
                // "link" = carrier gone; "net" = link up, probe host
                // unreachable; anything else = the probe itself failed
                // to run — all three keep the banner honest.
                root.reason = result === "link" ? "link" : "net";
                root.failures = root.failures + 1;
            }

            Process {
                id: probe

                command: ["sh", "-c",
                    "link=0; " +
                    "for c in /sys/class/net/*/carrier; do " +
                    "  case \"$c\" in " +
                    "    */lo/*|*/docker*/*|*/br-*/*|*/veth*/*|*/virbr*/*|*/tailscale*/*|*/zt*/*|*/wg*/*|*/tun*/*|*/tap*/*) continue ;; " +
                    "  esac; " +
                    "  read v < \"$c\" 2>/dev/null || v=0; " +
                    "  if [ \"$v\" = \"1\" ]; then link=1; break; fi; " +
                    "done; " +
                    "if [ \"$link\" = \"0\" ]; then echo link; exit 0; fi; " +
                    "if ping -n -c 1 -W \"$OFFLINE_BANNER_PROBE_TIMEOUT\" \"$OFFLINE_BANNER_PROBE_HOST\" >/dev/null 2>&1; then echo ok; else echo net; fi"]
                running: true

                stdout: StdioCollector {
                    id: probeOut

                    onStreamFinished: root.applyProbe(probeOut.text)
                }
            }

            Timer {
                interval: root.intervalMs
                running: true
                repeat: true
                triggeredOnStart: true

                onTriggered: {
                    // A still-running probe (ping up to -W timeout) is
                    // never stomped; the next tick catches it instead.
                    if (!probe.running)
                        probe.running = true;
                }
            }

            Variants {
                model: Quickshell.screens

                delegate: PanelWindow {
                    id: banner

                    required property var modelData

                    screen: modelData
                    visible: root.offline
                    updatesEnabled: root.offline

                    WlrLayershell.namespace: "systemnix:offline-banner"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.exclusionMode: ExclusionMode.Ignore

                    anchors {
                        top: true
                        left: true
                        right: true
                    }

                    implicitHeight: Math.max(44, Math.round(modelData.height * 0.03))
                    color: "transparent"
                    mask: Region {}

                    Rectangle {
                        anchors.fill: parent
                        color: "#f2f9e2af"

                        Text {
                            anchors.centerIn: parent
                            text: "⚠  OFFLINE — " + root.reasonText
                            color: "#1e1e2e"
                            font.pixelSize: Math.max(16, Math.round(modelData.height * 0.014))
                            font.weight: Font.Black
                            font.letterSpacing: 2
                        }
                    }
                }
            }
        }
      '';
    in
    {
      options.services.offline-banner = {
        enable = lib.mkEnableOption "yellow top-strip banner on every monitor while the network is offline (Quickshell layer-shell)";

        checkIntervalSeconds = lib.mkOption {
          type = lib.types.ints.positive;
          default = 5;
          description = "Seconds between connectivity probes";
        };

        probeHost = lib.mkOption {
          type = lib.types.str;
          default = "9.9.9.9";
          description = "IP pinged for the internet-reachability leg (an IP, not a name — DNS is dnsblockd's job and must not gate the banner)";
        };

        probeTimeoutSeconds = lib.mkOption {
          type = lib.types.ints.positive;
          default = 3;
          description = "ping timeout in seconds (must stay below checkIntervalSeconds)";
        };

        failuresToShow = lib.mkOption {
          type = lib.types.ints.positive;
          default = 2;
          description = "Consecutive failed probes before the banner appears (debounce)";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.probeTimeoutSeconds < cfg.checkIntervalSeconds;
            message = "services.offline-banner: probeTimeoutSeconds (${toString cfg.probeTimeoutSeconds}) must be < checkIntervalSeconds (${toString cfg.checkIntervalSeconds}) or probes overlap";
          }
        ];

        systemd.user.services.offline-banner = {
          description = "Yellow offline banner on all monitors (Quickshell layer-shell)";
          after = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          wantedBy = [ "graphical-session.target" ];

          environment = {
            OFFLINE_BANNER_INTERVAL = toString (cfg.checkIntervalSeconds * 1000);
            OFFLINE_BANNER_PROBE_HOST = cfg.probeHost;
            OFFLINE_BANNER_PROBE_TIMEOUT = toString cfg.probeTimeoutSeconds;
            OFFLINE_BANNER_FAILURES = toString cfg.failuresToShow;
            # mkForce: systemd's user-unit default PATH is also set via
            # environment.PATH and would collide (eval-hard error). The
            # probe is pure shell builtins + ping — bash provides sh,
            # iputils' ping ships cap_net_raw.
            PATH = lib.mkForce (lib.makeBinPath [
              pkgs.bash
              pkgs.iputils
            ]);
          };

          restartTriggers = [ offlineBannerShell ];

          serviceConfig = {
            Type = "simple";
            ExecStart = "${lib.getExe pkgs.quickshell} -p ${offlineBannerShell}";
            Restart = "always";
            RestartSec = "5s";
            MemoryMax = "256M";
          };

          unitConfig = {
            StartLimitBurst = 5;
            StartLimitIntervalSec = 120;
          };
        };
      };
    };
}
