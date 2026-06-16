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
  property int entryIndex: 0

  signal clicked()
  signal entered()

  width: parent?.width ?? 0
  height: 64
  color: root.isCurrent ? Appearance.colors.surface_container : "transparent"
  radius: 10

  Behavior on color {
    ColorAnimation {
      duration: 120
    }
  }

  RowLayout {
    anchors {
      fill: parent
      margins: Appearance.padding.normal
    }
    spacing: Appearance.spacing.large

    Item {
      id: iconArea
      Layout.preferredWidth: 36
      Layout.preferredHeight: 36
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
        Layout.fillWidth: true
        text: root.primaryText
        color: Appearance.colors.on_surface
        font.pixelSize: Appearance.fontSize.base
        font.weight: Font.DemiBold
        font.family: Appearance.font.sans
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Text {
        Layout.fillWidth: true
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
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: root.entered()
    onClicked: root.clicked()
  }
}
