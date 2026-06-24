import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string crmUrl: pluginData.crmUrl || "http://127.0.0.1:3200"
    property bool crmUp: false
    property int latencyMs: 0
    readonly property string statusText: crmUp ? (latencyMs > 0 ? latencyMs + "ms" : "up") : "down"
    readonly property color statusColor: crmUp ? (latencyMs > 500 ? Theme.warning : Theme.primary) : Theme.error

    Process {
        id: crmCheck
        command: ["sh", "-c",
            "start=$(date +%s%3N); " +
            "code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 3 " + root.crmUrl + " 2>/dev/null); " +
            "end=$(date +%s%3N); " +
            "if [ \"$code\" = \"200\" ] || [ \"$code\" = \"302\" ]; then echo \"$((end - start))\"; else echo \"-1\"; fi"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var val = parseInt(this.text.trim());
                    if (val >= 0) {
                        root.crmUp = true;
                        root.latencyMs = val;
                    } else {
                        root.crmUp = false;
                        root.latencyMs = 0;
                    }
                } catch (e) {
                    root.crmUp = false;
                    root.latencyMs = 0;
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: crmCheck.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon { name: "contact_mail"; size: root.iconSize; color: root.statusColor }
            StyledText {
                text: root.statusText
                color: root.statusColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        DankIcon { name: "contact_mail"; size: root.iconSize; color: root.statusColor }
    }
}
