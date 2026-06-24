// SystemNix Quickshell Widgets — Service Health Dots
// Polls Gatus for service up/down status, renders as colored dots
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: health

  readonly property string gatusUrl: "http://127.0.0.1:9110/api/v1/endpoints/statuses"
  property var services: []
  property int upCount: 0
  property int downCount: 0
  readonly property bool allUp: downCount === 0 && upCount > 0
  readonly property string summary: upCount + "/" + (upCount + downCount)

  function refresh() {
    healthProcess.running = true;
  }

  Process {
    id: healthProcess
    command: ["curl", "-sf", "--connect-timeout", "3", health.gatusUrl]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(this.text);
          var up = 0, down = 0;
          var svcs = [];
          for (var i = 0; i < data.length; i++) {
            var s = data[i];
            var isUp = s.results && s.results[0] && s.results[0].status === "UP";
            svcs.push({name: s.name, up: isUp});
            if (isUp) up++; else down++;
          }
          health.services = svcs;
          health.upCount = up;
          health.downCount = down;
        } catch (e) {
          health.services = [];
          health.upCount = 0;
          health.downCount = 0;
        }
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: health.refresh()
  }
}
