import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string gatusUrl: pluginData.gatusUrl || "http://127.0.0.1:9110/api/v1/endpoints/statuses"
    property var services: []
    property int upCount: 0
    property int downCount: 0
    readonly property bool allUp: downCount === 0 && upCount > 0
    readonly property string summary: upCount + "/" + (upCount + downCount)

    Process {
        id: healthProcess
        command: ["curl", "-sf", "--connect-timeout", "3", root.gatusUrl]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    var up = 0, down = 0;
                    for (var i = 0; i < data.length; i++) {
                        var s = data[i];
                        var isUp = s.results && s.results[0] && s.results[0].status === "UP";
                        if (isUp) up++; else down++;
                    }
                    root.upCount = up;
                    root.downCount = down;
                } catch (e) {
                    root.upCount = 0;
                    root.downCount = 0;
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: healthProcess.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            Rectangle {
                width: 10; height: 10; radius: 5
                color: root.downCount > 0 ? Theme.error : root.upCount > 0 ? Theme.primary : Theme.outline
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.summary
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        Rectangle {
            width: 10; height: 10; radius: 5
            color: root.downCount > 0 ? Theme.error : root.upCount > 0 ? Theme.primary : Theme.outline
        }
    }
}
