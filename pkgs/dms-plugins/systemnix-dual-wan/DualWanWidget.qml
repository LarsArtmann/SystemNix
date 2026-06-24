import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string primaryIface: pluginData.primaryIface || "enp2s0"
    property string secondaryIface: pluginData.secondaryIface || "wlp1s0"
    property bool primaryUp: false
    property bool secondaryUp: false
    readonly property bool dualActive: primaryUp && secondaryUp
    readonly property bool anyUp: primaryUp || secondaryUp
    readonly property string statusText: dualActive ? "DUAL" : primaryUp ? "PRI" : secondaryUp ? "SEC" : "DOWN"
    readonly property color statusColor: !anyUp ? Theme.error : dualActive ? Theme.primary : Theme.warning

    Process {
        id: linkProcess
        command: ["sh", "-c",
            "ip -o link show 2>/dev/null | awk '{print $2, $9}' | while read iface state; do " +
            "iface=$(echo $iface | tr -d ':'); " +
            "if [ \"$iface\" = \"" + root.primaryIface + "\" ]; then " +
            "  carrier=$(cat /sys/class/net/" + root.primaryIface + "/carrier 2>/dev/null || echo 0); " +
            "  echo \"pri $carrier\"; " +
            "elif [ \"$iface\" = \"" + root.secondaryIface + "\" ]; then " +
            "  carrier=$(cat /sys/class/net/" + root.secondaryIface + "/carrier 2>/dev/null || echo 0); " +
            "  echo \"sec $carrier\"; " +
            "fi; done"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var lines = this.text.trim().split("\n");
                    var pri = false, sec = false;
                    for (var i = 0; i < lines.length; i++) {
                        var parts = lines[i].trim().split(/\s+/);
                        if (parts[0] === "pri" && parts[1] === "1") pri = true;
                        if (parts[0] === "sec" && parts[1] === "1") sec = true;
                    }
                    root.primaryUp = pri;
                    root.secondaryUp = sec;
                } catch (e) {
                    root.primaryUp = false;
                    root.secondaryUp = false;
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: linkProcess.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon { name: "lan"; size: root.iconSize; color: root.statusColor }
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
            DankIcon { name: "lan"; size: root.iconSize; color: root.statusColor; anchors.horizontalCenter: parent.horizontalCenter }
            StyledText {
                text: root.statusText
                color: root.statusColor
                font.pixelSize: Theme.fontSizeTiny
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
