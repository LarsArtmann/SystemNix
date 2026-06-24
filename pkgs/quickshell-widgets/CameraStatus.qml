// SystemNix Quickshell Widgets — Camera Status
// Replaces waybar-camera — checks emeet-pixyd daemon status
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: camera

  property bool online: false
  property bool tracking: false
  property string device: "EMEET PIXY"
  readonly property string statusText: online ? (tracking ? "tracking" : "on") : "---"
  readonly property string statusIcon: online ? "📷" : "⊘"

  function refresh() {
    cameraProcess.running = true;
  }

  Process {
    id: cameraProcess
    command: ["emeet-pixyd", "status"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(this.text);
          camera.online = data.online || false;
          camera.tracking = data.tracking || false;
        } catch (e) {
          camera.online = false;
          camera.tracking = false;
        }
      }
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: camera.refresh()
  }
}
