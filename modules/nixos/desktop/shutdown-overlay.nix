# Fullscreen shutdown countdown overlay on all monitors (Quickshell layer-shell)
_: {
  flake.nixosModules.shutdown-overlay =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.shutdown-overlay;

      shutdownOverlayShell = pkgs.writeTextDir "shell.qml" ''
        pragma ComponentBehavior: Bound

        import QtQuick
        import Quickshell
        import Quickshell.Io
        import Quickshell.Wayland

        ShellRoot {
            id: root

            // /run/systemd/shutdown/scheduled appears whenever systemd has a
            // shutdown/reboot queued: line 1 = planned time in microseconds since
            // epoch, line 5 = the wall message. It vanishes on `shutdown -c` and
            // when the shutdown executes.
            readonly property string scheduledPath: Quickshell.env("SHUTDOWN_OVERLAY_FILE") || "/run/systemd/shutdown/scheduled"
            property int thresholdSeconds: {
                const raw = Quickshell.env("SHUTDOWN_OVERLAY_THRESHOLD");
                const parsed = raw ? parseInt(raw) : 60;
                return parsed > 0 ? parsed : 60;
            }

            property real scheduledAt: 0
            property real remaining: 0
            property string wallMessage: ""
            readonly property bool imminent: root.scheduledAt > 0 && root.remaining <= root.thresholdSeconds && root.remaining > -30
            readonly property bool counting: root.remaining > 0

            function parseScheduled(text) {
                const lines = (text ?? "").split("\n");
                const usec = parseInt(lines[0]);
                if (!usec || usec <= 0) {
                    root.scheduledAt = 0;
                    root.wallMessage = "";
                    return;
                }
                root.scheduledAt = usec / 1e6;
                root.wallMessage = (lines[4] ?? "").trim();
            }

            FileView {
                id: scheduledFile

                path: root.scheduledPath
                watchChanges: true
                printErrors: false

                onLoaded: root.parseScheduled(scheduledFile.text())
                onLoadFailed: {
                    root.scheduledAt = 0;
                    root.wallMessage = "";
                }
            }

            Timer {
                interval: 200
                running: true
                repeat: true
                triggeredOnStart: true

                onTriggered: {
                    // watchChanges may miss creation/removal races; poll reload
                    scheduledFile.reload();
                    if (root.scheduledAt > 0)
                        root.remaining = Math.ceil(root.scheduledAt - Date.now() / 1000);
                }
            }

            Variants {
                model: Quickshell.screens

                delegate: PanelWindow {
                    id: overlay

                    required property var modelData

                    screen: modelData
                    visible: root.imminent
                    updatesEnabled: root.imminent

                    WlrLayershell.namespace: "systemnix:shutdown-overlay"
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
                        color: "#cc1a0505"

                        SequentialAnimation on opacity {
                            running: overlay.visible && root.remaining <= 10
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.55
                                duration: 400
                            }
                            NumberAnimation {
                                to: 1
                                duration: 400
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 24

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.counting ? "SYSTEM SHUTDOWN IN" : "SYSTEM SHUTDOWN NOW"
                                color: "#ffe0e0"
                                font.pixelSize: Math.min(overlay.width, overlay.height) * 0.045
                                font.weight: Font.Black
                                font.letterSpacing: 8
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.counting ? String(Math.max(Math.round(root.remaining), 0)) : "0"
                                color: "#ff2b2b"
                                font.pixelSize: Math.min(overlay.width, overlay.height) * 0.42
                                font.weight: Font.Black
                                font.family: "monospace"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.wallMessage.length > 0 ? root.wallMessage : "Scheduled reboot/shutdown"
                                color: "#ffd7d7"
                                font.pixelSize: Math.min(overlay.width, overlay.height) * 0.028
                                font.weight: Font.Bold
                                maximumLineCount: 3
                                wrapMode: Text.Wrap
                                width: Math.min(overlay.width * 0.8, 1200)
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "sudo shutdown -c  to cancel"
                                color: "#ffffff"
                                font.pixelSize: Math.min(overlay.width, overlay.height) * 0.03
                                font.weight: Font.Bold
                            }
                        }
                    }
                }
            }
        }
      '';
    in
    {
      options.services.shutdown-overlay = {
        enable = lib.mkEnableOption "Fullscreen shutdown countdown overlay on every monitor, above fullscreen windows";

        thresholdSeconds = lib.mkOption {
          type = lib.types.ints.positive;
          default = 60;
          description = "Show the overlay once the scheduled shutdown is this many seconds away";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.user.services.shutdown-overlay = {
          description = "Fullscreen shutdown countdown overlay on all monitors";
          after = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          wantedBy = [ "graphical-session.target" ];

          environment = {
            SHUTDOWN_OVERLAY_THRESHOLD = toString cfg.thresholdSeconds;
          };

          restartTriggers = [ shutdownOverlayShell ];

          serviceConfig = {
            Type = "simple";
            ExecStart = "${lib.getExe pkgs.quickshell} -p ${shutdownOverlayShell}";
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
