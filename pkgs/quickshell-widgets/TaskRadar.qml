// SystemNix Quickshell Widgets — Taskchampion Task Radar
// Polls Taskchampion sync server for pending/overdue task counts
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: tasks

  readonly property string apiUrl: "http://127.0.0.1:10222"
  property int pendingCount: 0
  property int overdueCount: 0
  property int highPriorityCount: 0
  readonly property bool hasOverdue: overdueCount > 0
  readonly property string displayText: pendingCount + " pending"
  readonly property string overdueText: overdueCount + " overdue"

  function refresh() {
    pendingProcess.running = true;
  }

  Process {
    id: pendingProcess
    command: ["curl", "-sf", "--connect-timeout", "2", tasks.apiUrl + "/tasks?status=pending"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(this.text);
          var pending = 0, overdue = 0, highPri = 0;
          var now = new Date().getTime();
          for (var i = 0; i < data.length; i++) {
            var t = data[i];
            pending++;
            if (t.due) {
              var dueDate = new Date(t.due).getTime();
              if (dueDate < now) overdue++;
            }
            if (t.priority === "H" || t.priority === "high") highPri++;
          }
          tasks.pendingCount = pending;
          tasks.overdueCount = overdue;
          tasks.highPriorityCount = highPri;
        } catch (e) {
          tasks.pendingCount = 0;
          tasks.overdueCount = 0;
          tasks.highPriorityCount = 0;
        }
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: tasks.refresh()
  }
}
