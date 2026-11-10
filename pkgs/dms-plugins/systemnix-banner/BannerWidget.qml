import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

// Bar-level mirror of the offline-banner phase ladder. Runs the upstream
// contrib consumer (single-sourced logic: stale tell, degraded legs,
// offline age) every 5 s against the state file at
// $XDG_RUNTIME_DIR/offline-banner/state. The consumer emits waybar JSON or
// nothing while fine; empty output + zero exit = fine, empty output +
// non-zero exit or unparsable JSON = fail-closed "banner?" (a broken
// consumer must surface, not go silent — the dead-banner incident class).
// Colors: dim while fine, accent while degraded (info-blue strip parity),
// error for offline and stale.
PluginComponent {
    id: root

    property string consumerPath: pluginData.consumerPath || ""
    property int maxAge: parseInt(pluginData.maxAge) > 0 ? parseInt(pluginData.maxAge) : 15
    property string statusText: "net"
    property string statusDetail: "waiting for first probe"
    property color statusColor: Theme.outline

    Process {
        id: consumerProcess
        command: root.consumerPath.length > 0
            ? ["sh", "-c", "'" + root.consumerPath + "'"]
            : ["true"]
        environment: [
            { name: "OFFLINE_BANNER_MAX_AGE", value: String(root.maxAge) }
        ]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var out = this.text.trim();
                    if (out.length === 0) {
                        if (consumerProcess.exitCode !== 0) {
                            root.statusText = "banner?";
                            root.statusDetail = "consumer exited "
                                + consumerProcess.exitCode + " with no output";
                            root.statusColor = Theme.error;
                        } else {
                            root.statusText = "net";
                            root.statusDetail = "all legs up, heartbeat fresh";
                            root.statusColor = Theme.outline;
                        }
                        return;
                    }
                    var j = JSON.parse(out);
                    if (j.class === "stale") {
                        root.statusText = "banner?";
                        root.statusDetail = j.tooltip || "heartbeat stale";
                        root.statusColor = Theme.error;
                    } else if (j.class === "degraded") {
                        root.statusText = String(j.text || "degraded")
                            .replace(/^degraded:\s*/, "");
                        root.statusDetail = j.tooltip || "degraded";
                        root.statusColor = Theme.primary;
                    } else {
                        root.statusText = j.text || "offline";
                        root.statusDetail = j.tooltip || "offline";
                        root.statusColor = Theme.error;
                    }
                } catch (e) {
                    root.statusText = "banner?";
                    root.statusDetail = "consumer output unparsable: " + e;
                    root.statusColor = Theme.error;
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: consumerProcess.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: root.statusColor === Theme.error ? "wifi_off" : "wifi"
                size: root.iconSize
                color: root.statusColor
            }
            StyledText {
                text: root.statusText
                color: root.statusColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2
            DankIcon {
                name: root.statusColor === Theme.error ? "wifi_off" : "wifi"
                size: root.iconSize
                color: root.statusColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.statusText
                color: root.statusColor
                font.pixelSize: Theme.fontSizeTiny
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
