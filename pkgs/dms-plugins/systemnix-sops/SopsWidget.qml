import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property string secretsDir: pluginData.secretsDir || "/run/secrets"
    // The sops-nix render FARM mount point (exists from activation; the old
    // "sopsFile" key pointed at /run/secrets/sops-nix-age-key — a path that
    // NEVER exists under age.sshKeyPaths mode (no key file is rendered), so
    // the widget showed a permanent error "locked" — superb-v3 S-0006).
    property string farmDir: pluginData.farmDir || "/run/secrets.d"
    property int secretCount: 0
    property bool farmLive: false
    readonly property bool healthy: farmLive && secretCount > 0
    readonly property string statusText: healthy ? secretCount + " keys" : farmLive ? "0 keys" : "down"
    readonly property color statusColor: healthy ? Theme.primary : farmLive ? Theme.warning : Theme.error

    Process {
        id: sopsProcess
        command: ["sh", "-c",
            "if [ -d \"" + root.farmDir + "\" ]; then live=1; else live=0; fi; " +
            "count=$(ls -1 " + root.secretsDir + "/ 2>/dev/null | wc -l); " +
            "echo \"$live $count\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parts = this.text.trim().split(/\s+/);
                    root.farmLive = parts[0] === "1";
                    root.secretCount = parseInt(parts[1]) || 0;
                } catch (e) {
                    root.farmLive = false;
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
