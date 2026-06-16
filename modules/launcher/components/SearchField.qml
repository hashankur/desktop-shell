pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs.config

Item {
  id: root

  property string placeholderText: "Search..."
  property string iconSource: "system-search-symbolic"
  property string text: ""
  property int maxVisibleEntries: 5

  signal accepted()
  signal searchChanged(string text)
  signal upPressed()
  signal downPressed()
  signal escapePressed()
  signal altNumberPressed(int index)

  implicitHeight: 48
  implicitWidth: 200

  Rectangle {
    anchors.fill: parent
    radius: 24
    color: Appearance.colors.surface_container

    IconImage {
      id: searchIcon
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: 16
      width: 18
      height: 18
      source: Quickshell.iconPath(root.iconSource, true)
    }

    TextField {
      id: searchField
      anchors.fill: parent
      anchors.leftMargin: 42
      anchors.rightMargin: 12
      anchors.topMargin: 2
      anchors.bottomMargin: 2
      background: Rectangle {
        color: "transparent"
      }
      placeholderText: root.placeholderText
      font.pixelSize: Appearance.fontSize.sm
      color: Appearance.colors.on_surface
      placeholderTextColor: Appearance.colors.on_surface_variant
      text: root.text
      focus: true
      activeFocusOnTab: true

      onTextChanged: {
        root.text = text;
        root.searchChanged(text);
      }
      onAccepted: root.accepted()
      Keys.onEnterPressed: root.accepted()
      Keys.onReturnPressed: root.accepted()
      Keys.onPressed: function (event) {
        if (!(event.modifiers & Qt.AltModifier)) return;
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
          var targetIndex = event.key - Qt.Key_1;
          if (targetIndex < root.maxVisibleEntries) {
            root.altNumberPressed(targetIndex);
            event.accepted = true;
          }
        }
      }
      Keys.onDownPressed: root.downPressed()
      Keys.onUpPressed: root.upPressed()
      Keys.onEscapePressed: root.escapePressed()
    }
  }
}
