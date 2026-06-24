// SystemNix Quickshell — Immich Photo Memory
// Pulls "on this day" memories from Immich for the lock screen ambient display
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: immich

  readonly property string apiUrl: "http://127.0.0.1:2283/api"
  property string apiKey: "" // Set via environment variable IMMICH_API_KEY
  property var memories: []
  property string currentPhotoUrl: ""
  property int currentIndex: 0
  readonly property bool hasMemories: memories.length > 0

  function refresh() {
    if (!apiKey) {
      var key = Qt.environmentVariable("IMMICH_API_KEY");
      if (key) apiKey = key;
      else return;
    }
    memoryProcess.running = true;
  }

  function nextPhoto() {
    if (memories.length === 0) return;
    currentIndex = (currentIndex + 1) % memories.length;
    currentPhotoUrl = memories[currentIndex].url || "";
  }

  Process {
    id: memoryProcess
    command: ["curl", "-sf", "--connect-timeout", "3",
      "-H", "x-api-key: " + immich.apiKey,
      immich.apiUrl + "/memories"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(this.text);
          immich.memories = data || [];
          immich.currentIndex = 0;
          if (immich.memories.length > 0) {
            immich.currentPhotoUrl = immich.memories[0].url || "";
          }
        } catch (e) {
          immich.memories = [];
        }
      }
    }
  }

  // Rotate photo every 5 minutes
  Timer {
    interval: 300000
    running: hasMemories
    repeat: true
    onTriggered: immich.nextPhoto()
  }

  // Refresh daily
  Timer {
    interval: 86400000
    running: true
    repeat: true
    onTriggered: immich.refresh()
  }
}
