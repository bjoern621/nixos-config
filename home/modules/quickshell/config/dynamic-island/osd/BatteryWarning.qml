import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "../"

// Battery monitoring. Sends popups via PopupHost and libnotify  when battery drops below thresholds.
Scope {
    id: batteryScope

    property bool _startupDone: false
    property real _lastPct: UPower.displayDevice.percentage

    readonly property real pct: UPower.displayDevice.percentage
    readonly property bool charging: UPower.displayDevice.state === UPowerDeviceState.Charging
    readonly property bool fullyCharged: UPower.displayDevice.state === UPowerDeviceState.FullyCharged

    readonly property real shutdownThreshold: 0.03
    readonly property real criticalThreshold: 0.10
    readonly property real warningThreshold: 0.25

    Timer {
        interval: 2000
        running: true
        onTriggered: {
            batteryScope._lastPct = batteryScope.pct;
            batteryScope._startupDone = true;
        }
    }

    Process {
        id: notifyProc
        command: ["notify-send", "", ""]
    }

    function sendNotification(summary, body, urgency) {
        notifyProc.command = ["notify-send", "-u", urgency, "-a", "Quickshell", "-t", "15", summary, body];
        notifyProc.running = true;
    }

    function crossedBelow(threshold) {
        return _lastPct > threshold && pct <= threshold;
    }

    onPctChanged: {
        if (!_startupDone) {
            _lastPct = pct;
            return;
        }

        if (charging || fullyCharged) {
            _lastPct = pct;
            return;
        }

        const pctInt = Math.round(pct * 100);

        if (crossedBelow(shutdownThreshold)) {
            sendNotification("Akku kritisch", "Nur noch " + pctInt + " % Akku übrig. Das System schaltet sich gleich ab!", "critical");
            PopupHost.show("../icons/icons8-battery-25.svg", "System schaltet sich gleich ab!", "Nur noch " + pctInt + " % Akku übrig.\nLadegerät jetzt anschließen!", Colors.batteryCritical);
        } else if (crossedBelow(criticalThreshold)) {
            sendNotification("Akku fast leer", "Nur noch " + pctInt + " % Akku übrig. Bitte sofort Ladegerät anschließen!", "critical");
            PopupHost.show("../icons/icons8-battery-25.svg", "Akku fast leer!", "Nur noch " + pctInt + " % Akku übrig.\nBitte sofort das Ladegerät anschließen!", Colors.batteryCritical);
        } else if (crossedBelow(warningThreshold)) {
            sendNotification("Akku niedrig", "Nur noch " + pctInt + " % Akku übrig. Bitte bald das Ladegerät anschließen.", "normal");
            PopupHost.show("../icons/icons8-battery-50.svg", "Akku niedrig", "Nur noch " + pctInt + " % Akku übrig.\nBitte bald das Ladegerät anschließen.", Colors.batteryWarning);
        }

        _lastPct = pct;
    }

    // Keep previous value aligned when power state changes.
    onChargingChanged: {
        _lastPct = pct;
    }

    onFullyChargedChanged: {
        _lastPct = pct;
    }
}
