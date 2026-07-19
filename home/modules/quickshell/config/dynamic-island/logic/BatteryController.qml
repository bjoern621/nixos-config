import Quickshell.Services.UPower
import QtQuick

// Battery menu behavior: UPower reads + string formatting. No visuals.
// View binds to `dev` and calls the format* helpers; holds no logic.
QtObject {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool isCharging: dev.state === UPowerDeviceState.Charging
    readonly property bool isDischarging: dev.state === UPowerDeviceState.Discharging
    readonly property bool isFullyCharged: dev.state === UPowerDeviceState.FullyCharged

    readonly property string statusText: isCharging ? "Wird geladen" : isFullyCharged ? "Vollständig geladen" : isDischarging ? "Wird entladen" : "Unbekannt"

    // Non-zero rate means charging or draining.
    readonly property bool hasPowerFlow: Math.abs(dev.changeRate) > 0

    function formatTime(seconds) {
        if (seconds <= 0)
            return "—";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (h > 0)
            return h + " Std " + m + " Min";
        return m + " Min";
    }

    // Sign marks direction: + charging, - draining.
    function formatPower() {
        const w = Math.abs(dev.changeRate).toFixed(1);
        return (isCharging ? "+" : "-") + w + " W";
    }

    function formatEnergy() {
        return dev.energy.toFixed(1) + " / " + dev.energyCapacity.toFixed(1) + " Wh";
    }

    function formatHealth() {
        return Math.round(dev.healthPercentage * 100) + " %";
    }
}
