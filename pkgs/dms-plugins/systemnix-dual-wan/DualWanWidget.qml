import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string primaryIface: pluginData.primaryIface || ""
    property string secondaryIface: pluginData.secondaryIface || ""
    property bool primaryUp: false
    property bool secondaryUp: false
    readonly property bool dualActive: primaryUp && secondaryUp
    readonly property bool anyUp: primaryUp || secondaryUp
    readonly property string statusText: dualActive ? "DUAL" : primaryUp ? "PRI" : secondaryUp ? "SEC" : "DOWN"
    readonly property color statusColor: !anyUp ? Theme.error : dualActive ? Theme.primary : Theme.warning

    Process {
        id: linkProcess
        command: ["sh", "-c",
            "pri=\"" + root.primaryIface + "\"; sec=\"" + root.secondaryIface + "\"; " +
            "# Auto-detect if configured interfaces don't exist " +
            "if [ ! -d \"/sys/class/net/$pri\" ]; then " +
            "  pri=$(ls /sys/class/net 2>/dev/null | grep -vE '^(lo|docker|br-|veth|virbr|tailscale)' | while read i; do " +
            "    if [ -d \"/sys/class/net/$i/wireless\" ]; then continue; fi; " +
            "    if [ -f \"/sys/class/net/$i/carrier\" ]; then echo \"$i\"; break; fi; " +
            "  done); " +
            "fi; " +
            "if [ ! -d \"/sys/class/net/$sec\" ]; then " +
            "  sec=$(ls /sys/class/net 2>/dev/null | while read i; do " +
            "    if [ -d \"/sys/class/net/$i/wireless\" ]; then echo \"$i\"; break; fi; " +
            "  done); " +
            "fi; " +
            "for iface in \"$pri\" \"$sec\"; do " +
            "  if [ -z \"$iface\" ]; then continue; fi; " +
            "  carrier=$(cat /sys/class/net/$iface/carrier 2>/dev/null || echo 0); " +
            "  if [ \"$iface\" = \"$pri\" ]; then echo \"pri $carrier\"; " +
            "  else echo \"sec $carrier\"; fi; " +
            "done"]
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
