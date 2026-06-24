// SystemNix Quickshell — Mission Control OSD
// A popup panel with all quick-settings: volume, brightness, Wi-Fi, BT,
// power-profile, DND, caffeine, night-light — replaces GNOME quick settings
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupWindow {
  id: missionControl
  visible: false
  width: 380
  height: 520
  anchors {
    right: true
    bottom: true
    margin: 8
  }

  function toggle() {
    visible = !visible;
  }

  Rectangle {
    anchors.fill: parent
    color: "#1e1e2e"
    radius: 12
    border.color: "#313244"
    border.width: 1

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 12

      // Header
      Text {
        text: "Mission Control"
        color: "#cdd6f4"
        font.pixelSize: 16
        font.weight: Font.Bold
        Layout.fillWidth: true
      }

      // Volume slider with live meter
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text { text: "🔊"; font.pixelSize: 18 }
        Slider {
          Layout.fillWidth: true
          from: 0; to: 100
          value: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.volume * 100 : 50
          onMoved: {
            if (Pipewire.defaultAudioSink) {
              Pipewire.defaultAudioSink.volume = value / 100;
            }
          }
        }
        Pipewire {
          id: pipewire
        }
      }

      // Brightness slider
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text { text: "☀"; font.pixelSize: 18 }
        Slider {
          id: brightnessSlider
          Layout.fillWidth: true
          from: 0; to: 100
          value: 80
          onMoved: {
            brightnessCmd.args = [Math.round(value).toString()];
            brightnessCmd.running = true;
          }
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 1
        color: "#313244"
      }

      // Toggle row 1: Wi-Fi, Bluetooth, DND
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // DND toggle
        Rectangle {
          width: 80; height: 64
          radius: 8
          color: dndToggle.checked ? "#89b4fa" : "#313244"

          ColumnLayout {
            anchors.centerIn: parent
            Text { text: "🌙"; font.pixelSize: 20; Layout.alignment: Qt.AlignHCenter }
            Text { text: "DND"; color: "#cdd6f4"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
          }

          Check { id: dndToggle; anchors.fill: parent; opacity: 0 }
        }

        // Caffeine toggle
        Rectangle {
          width: 80; height: 64
          radius: 8
          color: caffeineToggle.checked ? "#f9e2af" : "#313244"

          ColumnLayout {
            anchors.centerIn: parent
            Text { text: "☕"; font.pixelSize: 20; Layout.alignment: Qt.AlignHCenter }
            Text { text: "Caffeine"; color: "#cdd6f4"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
          }

          Check { id: caffeineToggle; anchors.fill: parent; opacity: 0 }
        }

        // Night light toggle
        Rectangle {
          width: 80; height: 64
          radius: 8
          color: nightToggle.checked ? "#fab387" : "#313244"

          ColumnLayout {
            anchors.centerIn: parent
            Text { text: "🌇"; font.pixelSize: 20; Layout.alignment: Qt.AlignHCenter }
            Text { text: "Night"; color: "#cdd6f4"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
          }

          Check { id: nightToggle; anchors.fill: parent; opacity: 0 }
        }
      }

      // Power profile radios
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
          model: [
            {label: "Power", value: PowerProfile.Performance, icon: "⚡"},
            {label: "Balanced", value: PowerProfile.Balanced, icon: "⚖"},
            {label: "Saver", value: PowerProfile.PowerSaver, icon: "🍃"}
          ]
          delegate: Rectangle {
            width: 100; height: 56
            radius: 8
            color: PowerProfiles.activeProfile === modelData.value ? "#a6e3a1" : "#313244"

            ColumnLayout {
              anchors.centerIn: parent
              Text { text: modelData.icon; font.pixelSize: 18; Layout.alignment: Qt.AlignHCenter }
              Text { text: modelData.label; color: "#cdd6f4"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
            }

            MouseArea {
              anchors.fill: parent
              onClicked: PowerProfiles.activeProfile = modelData.value
            }
          }
        }

        UPower { id: upower }
        PowerProfiles { id: powerProfiles }
      }

      Item { Layout.fillHeight: true } // Spacer
    }
  }

  // Caffeine idle inhibitor
  IdleInhibitor {
    active: caffeineToggle.checked
  }
}
