// SystemNix Quickshell Widgets — Server Pulse
// Monitors Minecraft player count + Forgejo CI/PR status
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: servers

  property int minecraftPlayers: 0
  property int minecraftMax: 20
  property int forgejoPendingPRs: 0
  readonly property string mcText: minecraftPlayers > 0 ? minecraftPlayers + "/" + minecraftMax : "off"
  readonly property string forgejoText: forgejoPendingPRs > 0 ? forgejoPendingPRs + " PRs" : ""

  function refresh() {
    mcProcess.running = true;
    forgejoProcess.running = true;
  }

  // Minecraft server query (simple TCP ping via curl)
  Process {
    id: mcProcess
    command: ["sh", "-c", "echo -ne '\\x00\\x04\\x05\\x00\\x00localhost\\x00' | timeout 2 nc -w2 127.0.0.1 25565 2>/dev/null | tail -c +6 | strings | head -1 || echo '0'"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var match = this.text.match(/(\d+)\/(\d+)/);
          if (match) {
            servers.minecraftPlayers = parseInt(match[1]);
            servers.minecraftMax = parseInt(match[2]);
          } else {
            servers.minecraftPlayers = 0;
          }
        } catch (e) {
          servers.minecraftPlayers = 0;
        }
      }
    }
  }

  // Forgejo pending PRs
  Process {
    id: forgejoProcess
    command: ["curl", "-sf", "--connect-timeout", "2",
      "http://127.0.0.1:3000/api/v1/repos/issues/search?type=pulls&state=open"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(this.text);
          servers.forgejoPendingPRs = data.length || 0;
        } catch (e) {
          servers.forgejoPendingPRs = 0;
        }
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: servers.refresh()
  }
}
