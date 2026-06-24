// SystemNix Quickshell — Clipboard Manager with Image Previews
// A QML picker over cliphist that renders image thumbnails — not just text lines
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupWindow {
  id: clipboardManager
  property bool visible: false
  width: 500
  height: 500
  anchors {
    right: true
    bottom: true
    margin: 8
  }

  function toggle() {
    visible = !visible;
    if (visible) refreshList();
  }

  property var items: []

  function refreshList() {
    listProcess.running = true;
  }

  Process {
    id: listProcess
    command: ["cliphist", "list"]

    stdout: StdioCollector {
      onStreamFinished: {
        var lines = this.text.split('\n').filter(l => l.trim());
        var parsed = lines.slice(0, 50).map(function(line) {
          var tabIdx = line.indexOf('\t');
          var id = line.substring(0, tabIdx);
          var content = line.substring(tabIdx + 1);
          var isImage = content.startsWith('image/');
          return {id: id, content: content, isImage: isImage, preview: isImage ? content : null};
        });
        clipboardManager.items = parsed;
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    color: "#1e1e2e"
    radius: 12
    border.color: "#313244"
    border.width: 1

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 8

      Text {
        text: "Clipboard History"
        color: "#cdd6f4"
        font.pixelSize: 14
        font.weight: Font.Bold
      }

      ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
          model: clipboardManager.items
          spacing: 4
          delegate: Rectangle {
            width: ListView.view.width
            height: itemData.isImage ? 60 : 36
            radius: 6
            color: mouseArea.containsMouse ? "#313244" : "transparent"
            border.color: "#45475a"
            border.width: 1

            property var itemData: modelData

            RowLayout {
              anchors.fill: parent
              anchors.margins: 8
              spacing: 8

              // Image thumbnail or text icon
              Item {
                visible: itemData.isImage
                width: 44; height: 44
                Image {
                  anchors.fill: parent
                  source: "image://cliphist/" + itemData.id
                  fillMode: Image.PreserveAspectCrop
                  cache: false
                }
              }
              Text {
                visible: !itemData.isImage
                text: "📋"
                font.pixelSize: 16
              }

              // Content preview
              Text {
                Layout.fillWidth: true
                text: itemData.isImage ? "[Image]" : itemData.content.substring(0, 80)
                color: "#cdd6f4"
                font.pixelSize: 12
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: mouseArea
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                copyProcess.args = [itemData.id];
                copyProcess.running = true;
                clipboardManager.visible = false;
              }
            }
          }
        }
      }

      // Clear button
      Button {
        text: "Clear All"
        onClicked: {
          clearProcess.running = true;
          clipboardManager.items = [];
        }
      }
    }
  }

  Process {
    id: copyProcess
    command: ["sh", "-c"]
    property var args: []
    function start() {
      var cmd = "echo '" + args[0] + "' | cliphist decode | wl-copy";
      this.command = ["sh", "-c", cmd];
      running = true;
    }
  }

  Process {
    id: clearProcess
    command: ["cliphist", "wipe"]
  }
}
