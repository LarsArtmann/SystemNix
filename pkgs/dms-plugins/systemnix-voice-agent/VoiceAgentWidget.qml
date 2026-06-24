import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string whisperUrl: pluginData.whisperUrl || "http://127.0.0.1:7860"
    property string livekitUrl: pluginData.livekitUrl || "http://127.0.0.1:7880"
    property bool whisperUp: false
    property bool livekitUp: false
    readonly property bool active: whisperUp && livekitUp
    readonly property string statusText: active ? "voice" : "off"
    readonly property color statusColor: active ? Theme.warning : Theme.outline

    Process {
        id: whisperCheck
        command: ["curl", "-sf", "--connect-timeout", "1", root.whisperUrl]
        running: true
        stdout: StdioCollector { onStreamFinished: root.whisperUp = this.text.length > 0 }
    }

    Process {
        id: livekitCheck
        command: ["curl", "-sf", "--connect-timeout", "1", root.livekitUrl]
        running: true
        stdout: StdioCollector { onStreamFinished: root.livekitUp = this.text.length > 0 }
    }

    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: { whisperCheck.running = true; livekitCheck.running = true; }
    }

    SequentialAnimation on opacity {
        running: root.active; loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 0.4; duration: 600 }
        NumberAnimation { from: 0.4; to: 1.0; duration: 600 }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon { name: "mic"; size: root.iconSize; color: root.statusColor }
            StyledText { text: root.statusText; color: root.statusColor; font.pixelSize: Theme.fontSizeSmall }
        }
    }
    verticalBarPill: Component {
        DankIcon { name: "mic"; size: root.iconSize; color: root.statusColor }
    }
}
