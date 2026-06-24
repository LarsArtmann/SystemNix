import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string statsUrl: pluginData.statsUrl || "http://127.0.0.1:9090/stats"
    property int totalBlocked: 0
    property int blockedToday: 0
    property bool online: false

    function formatCount(n) {
        if (n >= 1000000) return (n / 1000000).toFixed(1) + "M";
        if (n >= 1000) return (n / 1000).toFixed(1) + "k";
        return n.toString();
    }

    readonly property string displayText: online ? formatCount(blockedToday) + " blocked" : "DNS off"

    Process {
        id: dnsProcess
        command: ["curl", "-sf", "--connect-timeout", "2", root.statsUrl]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.totalBlocked = data.totalBlocked || 0;
                    root.blockedToday = data.blockedToday || data.totalBlocked || 0;
                    root.online = true;
                } catch (e) {
                    root.online = false;
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: dnsProcess.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "shield"
                size: root.iconSize
                color: root.online ? Theme.primary : Theme.outline
            }
            StyledText {
                text: root.displayText
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "shield"
            size: root.iconSize
            color: root.online ? Theme.primary : Theme.outline
        }
    }
}
