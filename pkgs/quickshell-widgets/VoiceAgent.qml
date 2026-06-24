// SystemNix Quickshell Widgets — Voice Agent State
// Monitors Whisper ASR + LiveKit for active voice agent sessions
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: voice

  readonly property string whisperUrl: "http://127.0.0.1:7860"
  readonly property string livekitUrl: "http://127.0.0.1:7880"
  property bool whisperUp: false
  property bool livekitUp: false
  property bool listening: false
  readonly property bool active: whisperUp && livekitUp
  readonly property string statusText: active ? (listening ? "listening" : "ready") : "off"
  readonly property string statusColor: listening ? "#f9e2af" : (active ? "#a6e3a1" : "#6c7086")

  function refresh() {
    whisperCheck.running = true;
    livekitCheck.running = true;
  }

  Process {
    id: whisperCheck
    command: ["curl", "-sf", "--connect-timeout", "1", voice.whisperUrl]
    running: true

    stdout: StdioCollector {
      onStreamFinished: voice.whisperUp = this.text.length > 0
    }
  }

  Process {
    id: livekitCheck
    command: ["curl", "-sf", "--connect-timeout", "1", voice.livekitUrl]
    running: true

    stdout: StdioCollector {
      onStreamFinished: voice.livekitUp = this.text.length > 0
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: voice.refresh()
  }
}
