// SystemNix Quickshell Widgets — GPU/NPU Monitor
// Reads amdgpu VRAM + temperature from sysfs
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: gpu

  property int vramUsedMB: 0
  property int vramTotalMB: 0
  property real gpuTempC: 0.0
  property real npuUtilization: 0.0
  readonly property real vramPercent: vramTotalMB > 0 ? (vramUsedMB / vramTotalMB * 100) : 0
  readonly property string vramText: vramUsedMB + "/" + vramTotalMB + "M"
  readonly property string tempText: gpuTempC > 0 ? gpuTempC.toFixed(0) + "°C" : "---"
  readonly property bool available: vramTotalMB > 0

  function refresh() {
    vramUsedReader.running = true;
    vramTotalReader.running = true;
    tempReader.running = true;
  }

  FileView {
    id: vramUsedReader
    path: "/sys/class/drm/card0/device/mem_info_vram_used"
    onLoaded: {
      try {
        var bytes = parseInt(this.text().trim());
        gpu.vramUsedMB = Math.round(bytes / 1048576);
      } catch (e) {}
    }
  }

  FileView {
    id: vramTotalReader
    path: "/sys/class/drm/card0/device/mem_info_vram_total"
    onLoaded: {
      try {
        var bytes = parseInt(this.text().trim());
        gpu.vramTotalMB = Math.round(bytes / 1048576);
      } catch (e) {}
    }
  }

  FileView {
    id: tempReader
    path: "/sys/class/drm/card0/device/hwmon/hwmon3/temp1_input"
    onLoaded: {
      try {
        var millivolts = parseInt(this.text().trim());
        gpu.gpuTempC = millivolts / 1000;
      } catch (e) {}
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: gpu.refresh()
  }
}
