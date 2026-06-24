// SystemNix Quickshell Widgets — BTRFS Snapshot Freshness
// Checks btrfs-verify systemd timer last-run to warn if snapshots are stale
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: btrfs

  property string lastSnapshotDate: ""
  property int ageDays: -1
  readonly property bool stale: ageDays > 3 || ageDays < 0
  readonly property string statusText: ageDays < 0 ? "off" : ageDays + "d ago"
  readonly property string statusColor: stale ? "#f38ba8" : "#a6e3a1"

  function refresh() {
    timerProcess.running = true;
  }

  Process {
    id: timerProcess
    command: ["systemctl", "list-timers", "btrfs-verify.timer", "--no-pager", "--all", "--output=json"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(this.text);
          if (data && data.length > 0) {
            var next = data[0].next_elapse || "";
            // Estimate last run from next_elapse (timer runs daily)
            if (next) {
              var nextDate = new Date(next);
              var now = new Date();
              var diffMs = now - nextDate;
              btrfs.ageDays = Math.floor(diffMs / 86400000) + 1; // +1 because next is future
              btrfs.lastSnapshotDate = nextDate.toISOString().split('T')[0];
            }
          } else {
            btrfs.ageDays = -1;
          }
        } catch (e) {
          btrfs.ageDays = -1;
        }
      }
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: btrfs.refresh()
  }
}
