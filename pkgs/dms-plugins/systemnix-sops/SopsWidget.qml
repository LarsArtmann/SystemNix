import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string secretsDir: pluginData.secretsDir || "/run/secrets"
    property string sopsFile: pluginData.sopsFile || "/run/secrets/sops-nix-age-key"
    property int secretCount: 0
    property bool keyAvailable: false
    readonly property bool healthy: keyAvailable && secretCount > 0
    readonly property string statusText: healthy ? secretCount + " keys" : keyAvailable ? "0 keys" : "locked"
    readonly property color statusColor: healthy ? Theme.primary : keyAvailable ? Theme.warning : Theme.error

    Process {
        id: sopsProcess
        command: ["sh", "-c",
            "count=$(ls -1 " + root.secretsDir + "/ 2>/dev/null | wc -l); " +
            "if [ -f \"" + root.sopsFile + "\" ]; then key=1; else key=0; fi; " +
            "echo \"$key $count\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parts = this.text.trim().split(/\s+/);
                    root.keyAvailable = parts[0] === "1";
                    root.secretCount = parseInt(parts[1]) || 0;
                } catch (e) {
                    root.keyAvailable = false;
                    root.secretCount = 0;
                }
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: sopsProcess.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon { name: "lock"; size: root.iconSize; color: root.statusColor }
            StyledText {
                text: root.statusText
                color: root.statusColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        DankIcon { name: "lock"; size: root.iconSize; color: root.statusColor }
    }
}
