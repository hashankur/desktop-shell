pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

import qs.config

Rectangle {
  id: root

  property string primaryText: ""
  property string secondaryText: ""
  property string iconSource: ""
  property string thumbnailSource: ""
  property string hintText: ""
  property bool isCurrent: false
  property bool pinned: false
  property bool pinEnabled: false
  property int entryIndex: 0

  signal clicked()
  signal entered()
  signal pinClicked()

    width: parent?.width ?? 0
    height: 64
    radius: Appearance.rounding.normal
    color: root.isCurrent ? Appearance.colors.surface_container : "transparent"

  Behavior on color {
    ColorAnimation {
      duration: 120
    }
  }

  // Declared before the row layout: text/icon pass clicks through to it,
  // while the pin button (inside the layout) sits above and wins hit-testing.
  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    onEntered: root.entered()
    onClicked: root.clicked()
  }

  RowLayout {
    anchors {
      fill: parent
      margins: Appearance.padding.normal
    }
    spacing: Appearance.spacing.large

    Item {
      id: iconArea
      // Image previews get a larger window than plain icons.
      Layout.preferredWidth: root.thumbnailSource !== "" ? 48 : 36
      Layout.preferredHeight: root.thumbnailSource !== "" ? 48 : 36
      Layout.alignment: Qt.AlignVCenter
      visible: root.iconSource !== "" || root.thumbnailSource !== ""

      IconImage {
        anchors.fill: parent
        source: root.iconSource !== "" ? Quickshell.iconPath(root.iconSource, true) : ""
        visible: root.thumbnailSource === ""
        smooth: true
      }

      Image {
        anchors.fill: parent
        source: root.thumbnailSource !== "" ? root.thumbnailSource : ""
        visible: root.thumbnailSource !== ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
      }
    }

    Column {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: 2

      Text {
        width: parent.width
        text: root.primaryText
        color: Appearance.colors.on_surface
        font.pixelSize: Appearance.fontSize.base
        font.weight: Font.DemiBold
        font.family: Appearance.font.sans
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Text {
        width: parent.width
        text: root.secondaryText
        color: Appearance.colors.on_surface_variant
        font.pixelSize: Appearance.fontSize.sm
        font.family: Appearance.font.sans
        elide: Text.ElideRight
        visible: text.length > 0
        maximumLineCount: 1
      }
    }

    Text {
      text: root.hintText
      color: Appearance.colors.on_surface_variant
      font.pixelSize: Appearance.fontSize.xs
      font.family: Appearance.font.sans
      Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
      Layout.preferredWidth: 56
      horizontalAlignment: Text.AlignRight
      visible: text.length > 0
    }

    Item {
      id: pinArea
      Layout.preferredWidth: 20
      Layout.preferredHeight: 20
      Layout.alignment: Qt.AlignVCenter
      visible: root.pinEnabled && (root.pinned || rowMouse.containsMouse)

      IconImage {
        anchors.fill: parent
        source: root.pinned ? Qt.resolvedUrl("../../../assets/pin-filled.svg") : Qt.resolvedUrl("../../../assets/pin.svg")
        smooth: true
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.pinClicked()
      }
    }
  }
}
