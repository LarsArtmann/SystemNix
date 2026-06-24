import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string daemonUrl: pluginData.daemonUrl || "http://127.0.0.1:8090"
    property bool daemonUp: false
    property string cameraName: "---"
    readonly property string statusText: daemonUp ? cameraName : "off"
    readonly property color statusColor: daemonUp ? Theme.primary : Theme.outline

    Process {
        id: cameraProcess
        command: ["curl", "-sf", "--connect-timeout", "2", root.daemonUrl + "/api/status"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.daemonUp = true;
                    root.cameraName = data.camera || data.device || "on";
                } catch (e) {
                    root.daemonUp = false;
                    root.cameraName = "---";
                }
            }
        }
        onFailed: {
            root.daemonUp = false;
            root.cameraName = "---";
        }
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: cameraProcess.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon { name: "camera"; size: root.iconSize; color: root.statusColor }
            StyledText {
                text: root.statusText
                color: root.statusColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        DankIcon { name: "camera"; size: root.iconSize; color: root.statusColor }
    }
}
