import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string apiUrl: pluginData.apiUrl || "http://127.0.0.1:10222"
    property int pendingCount: 0
    property int overdueCount: 0
    readonly property bool hasOverdue: overdueCount > 0
    readonly property string displayText: pendingCount + " task" + (pendingCount === 1 ? "" : "s")
    readonly property color statusColor: hasOverdue ? Theme.error : pendingCount > 0 ? Theme.primary : Theme.outline

    Process {
        id: taskProcess
        command: ["curl", "-sf", "--connect-timeout", "2", root.apiUrl + "/tasks?status=pending"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    var pending = 0, overdue = 0;
                    var now = new Date().getTime();
                    for (var i = 0; i < data.length; i++) {
                        pending++;
                        if (data[i].due) {
                            var dueDate = new Date(data[i].due).getTime();
                            if (dueDate < now) overdue++;
                        }
                    }
                    root.pendingCount = pending;
                    root.overdueCount = overdue;
                } catch (e) {
                    root.pendingCount = 0;
                    root.overdueCount = 0;
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: taskProcess.running = true
    }

    SequentialAnimation on opacity {
        running: root.hasOverdue
        loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 0.5; duration: 800 }
        NumberAnimation { from: 0.5; to: 1.0; duration: 800 }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "checklist"
                size: root.iconSize
                color: root.statusColor
            }
            StyledText {
                text: root.displayText
                color: root.statusColor
                font.pixelSize: Theme.fontSizeSmall
            }
            StyledText {
                text: root.hasOverdue ? "(" + root.overdueCount + " overdue)" : ""
                color: Theme.error
                font.pixelSize: Theme.fontSizeTiny
                visible: root.hasOverdue
            }
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "checklist"
            size: root.iconSize
            color: root.statusColor
        }
    }
}
