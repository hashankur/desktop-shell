pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick
import qs.services
import qs.config

Singleton {
    property var device: UPower.displayDevice
    property bool available: device?.isLaptopBattery ?? false
    property var chargeState: device?.state ?? UPowerDeviceState.Unknown
    property bool isCharging: chargeState == UPowerDeviceState.Charging
    property bool isPluggedIn: isCharging || chargeState == UPowerDeviceState.PendingCharge
    property real percentage: device?.percentage ?? 1

    property bool isLow: available && (percentage <= 30 / 100)
    property bool isLowAndNotCharging: isLow && !isCharging

    property real energyRate: device?.changeRate ?? 0
    property real timeToEmpty: device?.timeToEmpty ?? 0
    property real timeToFull: device?.timeToFull ?? 0

    onIsLowAndNotChargingChanged: {
        if (available && isLowAndNotCharging)
            Quickshell.execDetached(["notify-send", "Low battery", "Consider plugging in your device", "-u", "critical", "-a", "Shell"]);
    }

    Component.onCompleted: {
        // onIsLowAndNotChargingChanged only fires on changes; cover the
        // case where the shell starts with the battery already low.
        if (isLowAndNotCharging)
            Quickshell.execDetached(["notify-send", "Low battery", "Consider plugging in your device", "-u", "critical", "-a", "Shell"]);
    }
}
