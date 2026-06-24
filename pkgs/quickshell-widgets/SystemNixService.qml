// SystemNix Quickshell Widgets — Shared Service Base
// Provides common HTTP polling, error handling, and graceful degradation
// for all SystemNix service widgets. Reduces boilerplate per widget.
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
  id: service

  // Configuration — override in instances
  property string endpoint: ""
  property int pollIntervalMs: 10000
  property int connectTimeoutSec: 2
  property bool enabled: true

  // State
  property bool online: false
  property string lastError: ""
  property var lastData: null
  readonly property string statusColor: online ? "#a6e3a1" : (lastError ? "#f38ba8" : "#6c7086")
  readonly property string statusDot: online ? "●" : "○"

  // Override in instances to parse response
  function parseResponse(text) {
    return JSON.parse(text);
  }

  // Override in instances to handle parsed data
  function onData(data) {}

  function poll() {
    if (!enabled || !endpoint) return;
    pollProcess.running = true;
  }

  Process {
    id: pollProcess
    command: ["curl", "-sf", "--connect-timeout", service.connectTimeoutSec.toString(), service.endpoint]
    running: service.enabled && service.endpoint !== ""

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = service.parseResponse(this.text);
          service.lastData = data;
          service.online = true;
          service.lastError = "";
          service.onData(data);
        } catch (e) {
          service.online = false;
          service.lastError = e.toString();
        }
      }
    }

    onFailed: {
      service.online = false;
      service.lastError = "connection failed";
    }
  }

  Timer {
    interval: service.pollIntervalMs
    running: service.enabled
    repeat: true
    onTriggered: service.poll()
  }
}
