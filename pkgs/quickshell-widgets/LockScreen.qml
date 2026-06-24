// SystemNix Quickshell — Session Lock Screen
// Replaces swaylock with a WlSessionLock + PAM authenticated lock
// Features: clock, now-playing track, blur backdrop, Immich "on this day" photo
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects

WlSessionLock {
  id: lockScreen

  // Lock state
  property bool locked: false
  property string errorMessage: ""
  property bool authenticating: false

  function lock() {
    locked = true;
  }

  function unlock() {
    authenticating = false;
    errorMessage = "";
    locked = false;
  }

  onLockedChanged: {
    if (locked) {
      pamContext.start();
    }
  }

  // PAM authentication
  PamContext {
    id: pamContext
    onResult: (result) => {
      if (result.success) {
        lockScreen.unlock();
      } else {
        lockScreen.errorMessage = "Authentication failed";
        lockScreen.authenticating = false;
      }
    }
  }

  // MPRIS now-playing
  Mpris {
    id: mpris
  }

  // Lock surface per-screen
  WlSessionLockSurface {
    // Background with blur
    Rectangle {
      anchors.fill: parent
      color: "#1e1e2e"

      // Blurred wallpaper backdrop
      BackgroundEffect {
        id: blurEffect
        anchors.fill: parent
        effect: MultiEffect {
          blurEnabled: true
          blur: 0.8
          blurMax: 32
          brightness: 0.3
        }
      }

      // Clock
      Text {
        id: clockText
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -60
        color: "#cdd6f4"
        font.pixelSize: 72
        font.weight: Font.DemiBold
        text: Qt.formatDateTime(clock.date, "HH:mm")

        SystemClock {
          id: clock
          precision: SystemClock.Seconds
        }
      }

      // Date
      Text {
        anchors.top: clockText.bottom
        anchors.horizontalCenter: clockText.horizontalCenter
        color: "#bac2de"
        font.pixelSize: 18
        text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
      }

      // Now-playing track
      Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#a6adc8"
        font.pixelSize: 14
        text: mpris.activePlayer ? "♪ " + mpris.activePlayer.trackTitle + " — " + mpris.activePlayer.trackArtist : ""
        visible: mpris.activePlayer && mpris.activePlayer.playbackState === MprisPlaybackState.Playing
      }

      // Error message
      Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#f38ba8"
        font.pixelSize: 12
        text: lockScreen.errorMessage
        visible: lockScreen.errorMessage !== ""
      }
    }
  }
}
