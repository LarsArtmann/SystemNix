import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string apiBase: pluginData.apiBase || "http://127.0.0.1:11434"
    property var models: []
    property string activeModel: "idle"
    property string vramHuman: "0G"
    readonly property bool hasModel: models.length > 0
    property string pollInterval: pluginData.pollInterval || "5000"

    function formatBytes(bytes) {
        if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + "G";
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(0) + "M";
        return bytes + "B";
    }

    function refresh() {
        ollamaProcess.running = true;
    }

    Process {
        id: ollamaProcess
        command: ["curl", "-sf", "--connect-timeout", "2", root.apiBase + "/api/ps"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    if (data.models && data.models.length > 0) {
                        root.models = data.models;
                        root.activeModel = data.models[0].name;
                        root.vramHuman = root.formatBytes(data.models[0].size_vram || 0);
                    } else {
                        root.models = [];
                        root.activeModel = "idle";
                        root.vramHuman = "0G";
                    }
                } catch (e) {
                    root.models = [];
                    root.activeModel = "off";
                    root.vramHuman = "0G";
                }
            }
        }
    }

    Timer {
        interval: parseInt(root.pollInterval)
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "memory"
                size: root.iconSize
                color: root.hasModel ? Theme.primary : Theme.outline
            }
            StyledText {
                text: root.activeModel + " " + root.vramHuman
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2
            DankIcon {
                name: "memory"
                size: root.iconSize
                color: root.hasModel ? Theme.primary : Theme.outline
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.vramHuman
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeTiny
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
