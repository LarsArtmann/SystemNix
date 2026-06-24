// SystemNix Quickshell Widgets — DNS Blocker Stats
// Polls dnsblockd stats API for blocked-query count
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: dnsStats

  readonly property string statsUrl: "http://127.0.0.1:9090/stats"
  property int totalBlocked: 0
  property int blockedToday: 0
  property real percentBlocked: 0.0
  property bool online: false
  readonly property string displayText: online ? formatCount(blockedToday) : "off"

  function formatCount(n) {
    if (n >= 1000000) return (n / 1000000).toFixed(1) + "M";
    if (n >= 1000) return (n / 1000).toFixed(1) + "k";
    return n.toString();
  }

  function refresh() {
    dnsProcess.running = true;
  }

  Process {
    id: dnsProcess
    command: ["curl", "-sf", "--connect-timeout", "2", dnsStats.statsUrl]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(this.text);
          dnsStats.totalBlocked = data.totalBlocked || 0;
          dnsStats.blockedToday = data.blockedToday || data.totalBlocked || 0;
          dnsStats.percentBlocked = data.percentBlocked || 0.0;
          dnsStats.online = true;
        } catch (e) {
          dnsStats.online = false;
        }
      }
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: dnsStats.refresh()
  }
}
