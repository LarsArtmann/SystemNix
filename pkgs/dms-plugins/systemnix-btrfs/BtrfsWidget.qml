import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string timerName: pluginData.timerName || "btrbk.timer"
    property int ageDays: -1
    readonly property bool stale: ageDays > 3 || ageDays < 0
    readonly property string statusText: ageDays < 0 ? "---" : ageDays + "d"
    readonly property color statusColor: stale ? Theme.error : Theme.primary

    Process {
        id: timerProcess
        command: ["sh", "-c",
          "last=$(systemctl show " + root.timerName + " --property=LastTriggerUSec --value 2>/dev/null); " +
          "if [ -z \"$last\" ] || [ \"$last\" = \"n/a\" ]; then echo -1; " +
          "else echo $(( ($(date +%s) - $(date -d \"$last\" +%s 2>/dev/null || echo 0)) / 86400 )); fi"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try { root.ageDays = parseInt(this.text.trim()); }
                catch (e) { root.ageDays = -1; }
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: timerProcess.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon { name: "snapshot"; size: root.iconSize; color: root.statusColor }
            StyledText {
                text: root.statusText
                color: root.statusColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        DankIcon { name: "snapshot"; size: root.iconSize; color: root.statusColor }
    }
}
