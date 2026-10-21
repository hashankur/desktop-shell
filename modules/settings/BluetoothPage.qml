pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

import qs.components
import qs.config
import qs.services

// Bluetooth: adapter switch, scan, paired devices and (while scanning)
// nearby ones that can be paired. Native Quickshell.Bluetooth only.
Item {
    id: root

    implicitHeight: 400

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: root.adapter !== null && root.adapter.enabled

    function _label(d) {
        return d.name || d.deviceName || d.address || "";
    }

    function _byConnected(a, b) {
        return (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || _label(a).localeCompare(_label(b));
    }

    readonly property var pairedDevices: {
        if (!root.adapter)
            return [];
        return (root.adapter.devices.values || []).filter(d => d && (d.bonded || d.paired)).sort(_byConnected);
    }

    // Unnamed advertisements (bare addresses) are noise in a scan.
    readonly property var nearbyDevices: {
        if (!root.adapter)
            return [];
        return (root.adapter.devices.values || []).filter(d => d && !(d.bonded || d.paired) && d.name).sort(_byConnected);
    }

    // Scanning is a battery and radio cost: never leave it on after the page
    // closes.
    onVisibleChanged: {
        if (!visible && root.adapter && root.adapter.discovering)
            root.adapter.discovering = false;
    }

    component DeviceRow: Item {
        id: dev

        required property var device
        property bool paired: false
        // Passed in: an inline component cannot see the page's ids.
        property string label: ""

        Layout.fillWidth: true
        implicitHeight: 38

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: devMouse.containsMouse ? Appearance.colors.surface_container_high : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }

        MouseArea {
            id: devMouse
            anchors.fill: parent
            hoverEnabled: true
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.small
            spacing: Appearance.spacing.normal

            Icon {
                centerVertically: false
                Layout.alignment: Qt.AlignVCenter
                source: Quickshell.iconPath(dev.device.icon || "bluetooth-symbolic", true)
            }

            StyledText {
                Layout.fillWidth: true
                text: dev.label
                elide: Text.ElideRight
                color: dev.device.connected ? Appearance.colors.on_surface : Appearance.colors.on_surface_variant
            }

            StyledText {
                visible: dev.device.batteryAvailable
                text: dev.device.batteryAvailable ? Math.round(dev.device.battery * 100) + "%" : ""
                mono: true
                color: Appearance.colors.on_surface_variant
                font.pixelSize: Appearance.fontSize.xs
            }

            StyledText {
                text: dev.device.pairing ? "Pairing" : (dev.device.connected ? "Connected" : (dev.paired ? "Paired" : ""))
                mono: true
                color: dev.device.connected ? Appearance.colors.primary : Appearance.colors.on_surface_variant
                font.pixelSize: Appearance.fontSize.xs
            }

            StyledButton {
                visible: dev.paired
                text: dev.device.connected ? "Disconnect" : "Connect"
                onClicked: dev.device.connected ? dev.device.disconnect() : dev.device.connect()
            }

            StyledButton {
                visible: dev.paired
                text: "Forget"
                onClicked: dev.device.forget()
            }

            StyledButton {
                visible: !dev.paired
                text: dev.device.pairing ? "Cancel" : "Pair"
                onClicked: dev.device.pairing ? dev.device.cancelPair() : dev.device.pair()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledButton {
                text: "Bluetooth"
                checkable: true
                checked: root.enabled
                enabled: root.adapter !== null
                onClicked: root.adapter.enabled = !root.adapter.enabled
            }

            StyledButton {
                text: root.adapter && root.adapter.discovering ? "Scanning" : "Scan"
                checkable: true
                checked: root.adapter !== null && root.adapter.discovering
                enabled: root.enabled
                onClicked: root.adapter.discovering = !root.adapter.discovering
            }

            StyledText {
                Layout.fillWidth: true
                text: root.adapter === null ? "No Bluetooth adapter" : (root.enabled ? `${root.pairedDevices.length} paired` : "Bluetooth is off")
                mono: true
                color: Appearance.colors.on_surface_variant
                font.pixelSize: Appearance.fontSize.sm
            }
        }

        Rule {
            Layout.fillWidth: true
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: list.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: list
                width: parent.width
                spacing: 2
                visible: root.enabled

                HudLabel {
                    visible: root.pairedDevices.length > 0
                    label: "Paired"
                }

                Repeater {
                    model: root.pairedDevices

                    delegate: DeviceRow {
                        required property var modelData

                        device: modelData
                        label: root._label(modelData)
                        paired: true
                    }
                }

                HudLabel {
                    Layout.topMargin: Appearance.spacing.normal
                    visible: root.adapter !== null && root.adapter.discovering
                    label: "Nearby"
                }

                Repeater {
                    model: root.adapter && root.adapter.discovering ? root.nearbyDevices : []

                    delegate: DeviceRow {
                        required property var modelData

                        device: modelData
                        label: root._label(modelData)
                        paired: false
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Appearance.spacing.large
                    visible: root.pairedDevices.length === 0 && !(root.adapter && root.adapter.discovering)
                    text: "No paired devices. Press Scan to look for nearby ones."
                    color: Appearance.colors.on_surface_variant
                    font.pixelSize: Appearance.fontSize.sm
                }
            }
        }
    }
}
