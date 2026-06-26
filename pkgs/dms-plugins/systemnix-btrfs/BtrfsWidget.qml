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
    property int chunkPercent: -1 // device-unallocated as % of device size (the metric that caused the 2026-06-26 crash)
    readonly property bool stale: ageDays > 3 || ageDays < 0
    readonly property bool chunkCritical: chunkPercent >= 0 && chunkPercent < 10
    readonly property string statusText: ageDays < 0 ? "---" : ageDays + "d"
    readonly property string diskText: diskPercent >= 0 ? diskPercent + "%" : ""
    readonly property string chunkText: chunkPercent >= 0 ? "CHK:" + chunkPercent + "%" : ""
    readonly property color statusColor: chunkCritical ? Theme.error : stale ? Theme.error : Theme.primary
    readonly property color diskColor: chunkCritical ? Theme.error : diskPercent > 85 ? Theme.error : diskPercent > 70 ? Theme.warning : Theme.primary

    Process {
        id: timerProcess
        command: ["sh", "-c",
          "last=$(systemctl show " + root.timerName + " --property=LastTriggerUSec --value 2>/dev/null); " +
          "if [ -z \"$last\" ] || [ \"$last\" = \"n/a\" ]; then age=-1; " +
          "else age=$(( ($(date +%s) - $(date -d \"$last\" +%s 2>/dev/null || echo 0)) / 86400 )); fi; " +
          "disk=$(df --output=pcent " + root.diskMount + " 2>/dev/null | tail -1 | tr -dc '0-9'); " +
          "disk=${disk:- -1}; " +
          "unalloc=$(awk '/^btrfs_device_unallocated_pct / {print $2}' /var/lib/prometheus-node-exporter/textfile_collectors/btrfs.prom 2>/dev/null || echo -1); " +
          "echo \"$age $disk $unalloc\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parts = this.text.trim().split(/\s+/);
                    root.ageDays = parseInt(parts[0]);
                    root.diskPercent = parseInt(parts[1]);
                    root.chunkPercent = parts.length > 2 ? parseInt(parts[2]) : -1;
                    if (isNaN(root.diskPercent)) root.diskPercent = -1;
                    if (isNaN(root.chunkPercent)) root.chunkPercent = -1;
                }
                catch (e) { root.ageDays = -1; root.diskPercent = -1; root.chunkPercent = -1; }
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
            StyledText {
                text: root.chunkText
                color: root.statusColor
                font.pixelSize: Theme.fontSizeSmall
                visible: root.chunkPercent >= 0
            }
        }
    }

    verticalBarPill: Component {
        DankIcon { name: "snapshot"; size: root.iconSize; color: root.statusColor }
    }
}
