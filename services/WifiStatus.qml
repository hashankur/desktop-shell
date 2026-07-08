pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    // Display properties that always reflect current system state
    readonly property bool connected: root.activeNetwork ? (root.activeNetwork.connected || root.activeNetwork.state === ConnectionState.Connected) : (root.wifiDevice ? (root.wifiDevice.connected || root.wifiDevice.state === ConnectionState.Connected) : false)
    readonly property int signal: root.activeNetwork ? Math.round((root.activeNetwork.signalStrength || 0) * 100) : 0
    readonly property string ssid: root.activeNetwork ? (root.activeNetwork.name || "") : ""

    // Computed properties that always reflect current system state
    readonly property var wifiDevice: {
        var devices = Networking.devices.values || []
        for (var i = 0; i < devices.length; i++) {
            var device = devices[i]
            if (device && device.type === DeviceType.Wifi) {
                return device
            }
        }
        return null
    }

    readonly property var activeNetwork: {
        var device = root.wifiDevice
        if (!device || !device.networks) {
            return null
        }

        var networks = device.networks.values || []
        var fallback = null
        for (var i = 0; i < networks.length; i++) {
            var network = networks[i]
            if (!network) {
                continue
            }

            if (network.state === ConnectionState.Connected || network.connected) {
                return network
            }

            if (fallback === null && network.state === ConnectionState.Connecting) {
                fallback = network
            }
        }

        return fallback
    }

    // Monitor WiFi device state changes
    Connections {
        target: root.wifiDevice
        enabled: root.wifiDevice !== null

        function onStateChanged() {
            // Accessing readonly properties forces re-evaluation
            root.wifiDevice
            root.activeNetwork
        }

        function onConnectedChanged() {
            root.wifiDevice
            root.activeNetwork
        }
    }

    // Monitor active network state changes
    Connections {
        target: root.activeNetwork
        enabled: root.activeNetwork !== null

        function onStateChanged() {
            root.wifiDevice
            root.activeNetwork
        }

        function onConnectedChanged() {
            root.wifiDevice
            root.activeNetwork
        }

        function onNameChanged() {
            root.wifiDevice
            root.activeNetwork
        }

        function onSignalStrengthChanged() {
            root.wifiDevice
            root.activeNetwork
        }
    }
}
