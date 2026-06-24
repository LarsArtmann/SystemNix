import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string diskMount: pluginData.diskMount || "/"
    property int cpuPercent: 0
    property int ramPercent: 0
    property int diskPercent: 0
    readonly property int maxLoad: Math.max(cpuPercent, ramPercent, diskPercent)
    readonly property color loadColor: maxLoad > 85 ? Theme.error : maxLoad > 60 ? Theme.warning : Theme.primary
    readonly property string summary: cpuPercent + "/" + ramPercent + "/" + diskPercent

    Process {
        id: loadProcess
        command: ["sh", "-c",
            "cpu=$(top -bn1 | awk '/^%Cpu/ {print int(100 - $8)}'); " +
            "ram=$(free | awk '/^Mem:/ {printf \"%d\", $3/$2*100}'); " +
            "disk=$(df " + root.diskMount + " | awk 'NR==2 {print int($5)}'); " +
            "echo \"$cpu $ram $disk\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parts = this.text.trim().split(/\s+/);
                    root.cpuPercent = parseInt(parts[0]) || 0;
                    root.ramPercent = parseInt(parts[1]) || 0;
                    root.diskPercent = parseInt(parts[2]) || 0;
                } catch (e) {
                    root.cpuPercent = 0;
                    root.ramPercent = 0;
                    root.diskPercent = 0;
                }
            }
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: loadProcess.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon { name: "server"; size: root.iconSize; color: root.loadColor }

            // CPU bar
            Rectangle {
                width: 20; height: 10; radius: 2
                color: Qt.rgba(0.2, 0.2, 0.2, 0.4)
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { width: parent.width * (root.cpuPercent / 100); height: parent.height; radius: 2; color: Theme.primary }
            }
            // RAM bar
            Rectangle {
                width: 20; height: 10; radius: 2
                color: Qt.rgba(0.2, 0.2, 0.2, 0.4)
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { width: parent.width * (root.ramPercent / 100); height: parent.height; radius: 2; color: Theme.warning }
            }
            // Disk bar
            Rectangle {
                width: 20; height: 10; radius: 2
                color: Qt.rgba(0.2, 0.2, 0.2, 0.4)
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { width: parent.width * (root.diskPercent / 100); height: parent.height; radius: 2; color: Theme.outline }
            }

            StyledText {
                text: root.summary
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2
            DankIcon { name: "server"; size: root.iconSize; color: root.loadColor; anchors.horizontalCenter: parent.horizontalCenter }
            StyledText {
                text: root.maxLoad + "%"
                color: root.loadColor
                font.pixelSize: Theme.fontSizeTiny
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
