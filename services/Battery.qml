pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick
import Quickshell.Io
import qs.services
import qs.config

Singleton {
    property bool available: UPower.displayDevice.isLaptopBattery
    property var chargeState: UPower.displayDevice.state
    property bool isCharging: chargeState == UPowerDeviceState.Charging
    property bool isPluggedIn: isCharging || chargeState == UPowerDeviceState.PendingCharge
    property real percentage: UPower.displayDevice?.percentage ?? 1
    readonly property bool allowAutomaticSuspend: false

    property bool isLow: available && (percentage <= 30 / 100)
    property bool isCritical: available && (percentage <= 15 / 100)
    property bool isSuspending: available && (percentage <= 10 / 100)

    property bool isLowAndNotCharging: isLow && !isCharging
    property bool isCriticalAndNotCharging: isCritical && !isCharging
    property bool isSuspendingAndNotCharging: allowAutomaticSuspend && isSuspending && !isCharging

    property real energyRate: UPower.displayDevice.changeRate
    property real timeToEmpty: UPower.displayDevice.timeToEmpty
    property real timeToFull: UPower.displayDevice.timeToFull

    onIsLowAndNotChargingChanged: {
        if (available && isLowAndNotCharging)
            Quickshell.execDetached(["notify-send", "Low battery", "Consider plugging in your device", "-u", "critical", "-a", "Shell"]);
    }

    // onIsCriticalAndNotChargingChanged: {
    //     if (available && isCriticalAndNotCharging)
    //         Quickshell.execDetached(["notify-send", "Critically low battery", "Please charge!\nAutomatic suspend triggers at %1".arg(Config.data.power.battery.suspend), "-u", "critical", "-a", "Shell"]);
    // }

    onIsSuspendingAndNotChargingChanged: {
        if (available && isSuspendingAndNotCharging) {
            Quickshell.execDetached(["sh", "-c", `systemctl suspend || loginctl suspend`]);
        }
    }
}
