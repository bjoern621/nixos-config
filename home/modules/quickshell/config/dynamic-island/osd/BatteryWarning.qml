import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "../"

// Pure battery monitoring logic. Sends popups via PopupHost and
// hyprctl notifications when battery drops below thresholds.
Scope {
    id: batteryScope

    property bool _startupDone: false
    property bool _warningShown: false
    property bool _criticalShown: false

    readonly property real pct: UPower.displayDevice.percentage
    readonly property bool charging: UPower.displayDevice.state === UPowerDeviceState.Charging
    readonly property bool fullyCharged: UPower.displayDevice.state === UPowerDeviceState.FullyCharged

    readonly property bool isCritical: !charging && !fullyCharged && pct == 0.10
    readonly property bool isWarning: !charging && !fullyCharged && pct == 0.25

    Timer {
        interval: 2000
        running: true
        onTriggered: batteryScope._startupDone = true
    }

    Process {
        id: notifyProc
        command: ["hyprctl", "notify", "-1", "10000", "0", ""]
    }

    function sendNotification(msg) {
        notifyProc.command = ["hyprctl", "notify", "-1", "10000", "0", msg]
        notifyProc.running = true
    }

    onPctChanged: {
        if (!_startupDone) return
        const pctInt = Math.round(pct * 100)

        if (isCritical && !_criticalShown) {
            _criticalShown = true
            _warningShown = true
            sendNotification("⚠ Akku fast leer! " + pctInt + " %")
            PopupHost.show(
                "\uf244",
                "Akku fast leer!",
                "Nur noch " + pctInt + " % Akku übrig.\nBitte sofort das Ladegerät anschließen!",
                Colors.batteryCritical
            )
        } else if (isWarning && !isCritical && !_warningShown) {
            _warningShown = true
            sendNotification("🔋 Akku niedrig: " + pctInt + " %")
            PopupHost.show(
                "\uf243",
                "Akku niedrig",
                "Nur noch " + pctInt + " % Akku übrig.\nBitte bald das Ladegerät anschließen.",
                Colors.batteryWarning
            )
        }
    }

    // Reset thresholds when charger is connected
    onChargingChanged: {
        if (charging) {
            _warningShown = false
            _criticalShown = false
        }
    }

    onFullyChargedChanged: {
        if (fullyCharged) {
            _warningShown = false
            _criticalShown = false
        }
    }
}
