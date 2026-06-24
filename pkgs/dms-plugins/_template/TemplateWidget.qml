import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    // Read settings from plugin_settings.json (declarative via Nix)
    property string apiUrl: pluginData.apiUrl || "http://127.0.0.1:8080"
    property string statusValue: "---"
    property color statusColor: Theme.primary

    // Pattern: Process + StdioCollector + Timer for periodic data fetching
    Process {
        id: dataProcess
        command: ["sh", "-c",
            "curl -sf --max-time 3 " + root.apiUrl + " 2>/dev/null || echo 'ERR'"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var result = this.text.trim();
                    if (result === "ERR" || result.length === 0) {
                        root.statusValue = "---";
                        root.statusColor = Theme.error;
                    } else {
                        root.statusValue = result;
                        root.statusColor = Theme.primary;
                    }
                } catch (e) {
                    root.statusValue = "---";
                    root.statusColor = Theme.error;
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: dataProcess.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon { name: "extension"; size: root.iconSize; color: root.statusColor }
            StyledText {
                text: root.statusValue
                color: root.statusColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2
            DankIcon { name: "extension"; size: root.iconSize; color: root.statusColor; anchors.horizontalCenter: parent.horizontalCenter }
            StyledText {
                text: root.statusValue
                color: root.statusColor
                font.pixelSize: Theme.fontSizeTiny
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
