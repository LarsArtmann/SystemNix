import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string cardPath: pluginData.cardPath || "/sys/class/drm/card0/device"
    property int vramUsedMB: 0
    property int vramTotalMB: 0
    property real gpuTempC: 0.0
    readonly property real vramPercent: vramTotalMB > 0 ? (vramUsedMB / vramTotalMB * 100) : 0
    readonly property string vramText: vramTotalMB > 0 ? (vramUsedMB / 1024).toFixed(1) + "G/" + (vramTotalMB / 1024).toFixed(0) + "G" : "---"
    readonly property string tempText: gpuTempC > 0 ? gpuTempC.toFixed(0) + "\u00B0C" : ""
    readonly property bool available: vramTotalMB > 0
    readonly property color tempColor: gpuTempC > 90 ? Theme.error : gpuTempC > 75 ? Theme.warning : Theme.primary

    Process {
        id: vramReader
        command: ["sh", "-c", "cat " + root.cardPath + "/mem_info_vram_used 2>/dev/null; echo '|'; cat " + root.cardPath + "/mem_info_vram_total 2>/dev/null; echo '|'; cat " + root.cardPath + "/hwmon/hwmon*/temp1_input 2>/dev/null || echo 0"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parts = this.text.split('|').map(function(s) { return s.trim(); });
                    if (parts[0]) root.vramUsedMB = Math.round(parseInt(parts[0]) / 1048576);
                    if (parts[1]) root.vramTotalMB = Math.round(parseInt(parts[1]) / 1048576);
                    if (parts[2]) root.gpuTempC = parseInt(parts[2]) / 1000;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: vramReader.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "developer_board"
                size: root.iconSize
                color: root.available ? Theme.primary : Theme.outline
            }
            StyledText {
                text: root.vramText
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
            StyledText {
                text: root.tempText
                color: root.tempColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2
            DankIcon {
                name: "developer_board"
                size: root.iconSize
                color: root.available ? Theme.primary : Theme.outline
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.tempText
                color: root.tempColor
                font.pixelSize: Theme.fontSizeTiny
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
