// SystemNix Quickshell Widgets — Ollama AI Brain Monitor
// Polls Ollama /api/ps for loaded models + VRAM footprint
// Usage in DMS bar: import this and bind to the model/VRAM properties
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: ollama

  readonly property string apiBase: "http://127.0.0.1:11434"
  property var models: []
  property string activeModel: "idle"
  property int vramBytes: 0
  property string vramHuman: "0G"
  readonly property bool hasModel: models.length > 0

  function refresh() {
    ollamaProcess.running = true;
  }

  function formatBytes(bytes) {
    if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + "G";
    if (bytes >= 1048576) return (bytes / 1048576).toFixed(0) + "M";
    return bytes + "B";
  }

  Process {
    id: ollamaProcess
    command: ["curl", "-sf", "--connect-timeout", "2", ollama.apiBase + "/api/ps"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(this.text);
          if (data.models && data.models.length > 0) {
            ollama.models = data.models;
            ollama.activeModel = data.models[0].name;
            ollama.vramBytes = data.models[0].size_vram || 0;
            ollama.vramHuman = ollama.formatBytes(ollama.vramBytes);
          } else {
            ollama.models = [];
            ollama.activeModel = "idle";
            ollama.vramBytes = 0;
            ollama.vramHuman = "0G";
          }
        } catch (e) {
          ollama.models = [];
          ollama.activeModel = "off";
          ollama.vramBytes = 0;
          ollama.vramHuman = "0G";
        }
      }
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: ollama.refresh()
  }
}
