pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick
import qs.services
import qs.config

Singleton {
    property bool available: UPower.displayDevice.isLaptopBattery
    property var chargeState: UPower.displayDevice.state
    property bool isCharging: chargeState == UPowerDeviceState.Charging
    property bool isPluggedIn: isCharging || chargeState == UPowerDeviceState.PendingCharge
    property real percentage: UPower.displayDevice?.percentage ?? 1

    property bool isLow: available && (percentage <= 30 / 100)
    property bool isLowAndNotCharging: isLow && !isCharging

    property real energyRate: UPower.displayDevice.changeRate
    property real timeToEmpty: UPower.displayDevice.timeToEmpty
    property real timeToFull: UPower.displayDevice.timeToFull

    onIsLowAndNotChargingChanged: {
        if (available && isLowAndNotCharging)
            Quickshell.execDetached(["notify-send", "Low battery", "Consider plugging in your device", "-u", "critical", "-a", "Shell"]);
    }
}
