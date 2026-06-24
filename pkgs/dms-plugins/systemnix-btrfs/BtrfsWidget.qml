import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string timerName: pluginData.timerName || "btrbk.timer"
    property string diskMount: pluginData.diskMount || "/"
    property int ageDays: -1
    property int diskPercent: -1
    readonly property bool stale: ageDays > 3 || ageDays < 0
    readonly property string statusText: ageDays < 0 ? "---" : ageDays + "d"
    readonly property string diskText: diskPercent >= 0 ? diskPercent + "%" : ""
    readonly property color statusColor: stale ? Theme.error : Theme.primary
    readonly property color diskColor: diskPercent > 85 ? Theme.error : diskPercent > 70 ? Theme.warning : Theme.primary

    Process {
        id: timerProcess
        command: ["sh", "-c",
          "last=$(systemctl show " + root.timerName + " --property=LastTriggerUSec --value 2>/dev/null); " +
          "if [ -z \"$last\" ] || [ \"$last\" = \"n/a\" ]; then age=-1; " +
          "else age=$(( ($(date +%s) - $(date -d \"$last\" +%s 2>/dev/null || echo 0)) / 86400 )); fi; " +
          "disk=$(df --output=pcent " + root.diskMount + " 2>/dev/null | tail -1 | tr -dc '0-9'); " +
          "disk=${disk:- -1}; " +
          "echo \"$age $disk\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parts = this.text.trim().split(/\s+/);
                    root.ageDays = parseInt(parts[0]);
                    root.diskPercent = parseInt(parts[1]);
                    if (isNaN(root.diskPercent)) root.diskPercent = -1;
                }
                catch (e) { root.ageDays = -1; root.diskPercent = -1; }
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
            StyledText {
                text: root.diskText
                color: root.diskColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        DankIcon { name: "snapshot"; size: root.iconSize; color: root.statusColor }
    }
}
