import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string devfreqPath: pluginData.devfreqPath || "/sys/class/devfreq"
    property bool npuAvailable: false
    property int freqMHz: 0
    property int maxFreqMHz: 0
    property int loadPercent: 0
    readonly property string statusText: npuAvailable ? (loadPercent > 0 ? loadPercent + "%" : freqMHz + "MHz") : "off"
    readonly property color statusColor: !npuAvailable ? Theme.outline : loadPercent > 80 ? Theme.warning : Theme.primary

    Process {
        id: npuProcess
        command: ["sh", "-c",
            "npu=$(ls " + root.devfreqPath + " 2>/dev/null | grep -i -E 'npu|aie|ryzen' | head -1); " +
            "if [ -z \"$npu\" ]; then echo \"0 0 0\"; exit 0; fi; " +
            "base=" + root.devfreqPath + "/$npu; " +
            "cur=$(cat $base/cur_freq 2>/dev/null || echo 0); " +
            "max=$(cat $base/max_freq 2>/dev/null || echo 0); " +
            "load=$(cat $base/load 2>/dev/null | awk -F'@' '{gsub(/[^0-9]/,\"\",$1); print $1+0}' 2>/dev/null || echo 0); " +
            "if [ \"$cur\" = \"0\" ]; then cur=1; fi; " +
            "pct=$((load > 0 ? load : max > 0 ? cur * 100 / max : 0)); " +
            "echo \"1 $((cur / 1000000)) $((max / 1000000)) $pct\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parts = this.text.trim().split(/\s+/);
                    root.npuAvailable = parts[0] === "1";
                    root.freqMHz = parseInt(parts[1]) || 0;
                    root.maxFreqMHz = parseInt(parts[2]) || 0;
                    root.loadPercent = parseInt(parts[3]) || 0;
                } catch (e) {
                    root.npuAvailable = false;
                    root.freqMHz = 0;
                    root.maxFreqMHz = 0;
                    root.loadPercent = 0;
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: npuProcess.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon { name: "developer_board"; size: root.iconSize; color: root.statusColor }
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
            DankIcon { name: "developer_board"; size: root.iconSize; color: root.statusColor; anchors.horizontalCenter: parent.horizontalCenter }
            StyledText {
                text: root.loadPercent > 0 ? root.loadPercent + "%" : "NPU"
                color: root.statusColor
                font.pixelSize: Theme.fontSizeTiny
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
