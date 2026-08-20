import Quickshell
import Quickshell.Services.UPower
import QtQuick
import "../"

// Battery monitoring.
// Popups via PopupHost and libnotify when battery drops below thresholds.
Scope {
    id: batteryScope

    // -1, not a binding on pct: threshold checks below assign it,
    // and an imperative write destroys a binding.
    // Seeded once startup settles.
    property real _lastPct: -1

    readonly property real pct: UPower.displayDevice.percentage
    readonly property bool charging: UPower.displayDevice.state === UPowerDeviceState.Charging
    readonly property bool fullyCharged: UPower.displayDevice.state === UPowerDeviceState.FullyCharged

    readonly property real shutdownThreshold: 0.03
    readonly property real criticalThreshold: 0.10
    readonly property real warningThreshold: 0.25

    Connections {
        target: ShellStartup

        function onSettledChanged() {
            if (ShellStartup.settled)
                batteryScope._lastPct = batteryScope.pct;
        }
    }

    // execDetached, not a shared Process: mutating a Process's command and setting running=true
    // are both no-ops while it still runs, silently dropping a second threshold crossed inside
    // notify-send's runtime.
    //
    // This shell is the notification daemon (base/NotificationListener.qml), so notify-send
    // round-trips over D-Bus back into this process.
    // That files the alert in the notification center.
    // PopupHost.show below draws the on-screen alert.
    //
    // -t is milliseconds.
    // Warning passes 15: toast expires before it can be seen, leaving only the
    // history entry, so no toast duplicates the modal.
    // Criticals pass 10000: toast stays 10 s next to the modal, then expires
    // (NotificationToast.expiryMs honors an explicit timeout even at critical urgency).
    function sendNotification(summary, body, urgency, timeoutMs) {
        Quickshell.execDetached(["notify-send", "-u", urgency, "-a", "Quickshell", "-t", String(timeoutMs), summary, body]);
    }

    function crossedBelow(threshold) {
        return _lastPct > threshold && pct <= threshold;
    }

    onPctChanged: {
        if (!ShellStartup.settled) {
            _lastPct = pct;
            return;
        }

        if (charging || fullyCharged) {
            _lastPct = pct;
            return;
        }

        const pctInt = Math.round(pct * 100);

        if (crossedBelow(shutdownThreshold)) {
            sendNotification("Akku kritisch", "Nur noch " + pctInt + " % Akku übrig. Das System schaltet sich gleich ab!", "critical", 10000);
            PopupHost.show("../icons/icons8-battery-25.svg", "System schaltet sich gleich ab!", "Nur noch " + pctInt + " % Akku übrig.\nLadegerät jetzt anschließen!", Colors.batteryCritical);
        } else if (crossedBelow(criticalThreshold)) {
            sendNotification("Akku fast leer", "Nur noch " + pctInt + " % Akku übrig. Bitte sofort Ladegerät anschließen!", "critical", 10000);
            PopupHost.show("../icons/icons8-battery-25.svg", "Akku fast leer!", "Nur noch " + pctInt + " % Akku übrig.\nBitte sofort das Ladegerät anschließen!", Colors.batteryCritical);
        } else if (crossedBelow(warningThreshold)) {
            sendNotification("Akku niedrig", "Nur noch " + pctInt + " % Akku übrig. Bitte bald das Ladegerät anschließen.", "normal", 15);
            PopupHost.show("../icons/icons8-battery-50.svg", "Akku niedrig", "Nur noch " + pctInt + " % Akku übrig.\nBitte bald das Ladegerät anschließen.", Colors.batteryWarning);
        }

        _lastPct = pct;
    }

    // Re-seed on power-state flip, else a stale _lastPct reads as a threshold crossing.
    onChargingChanged: {
        _lastPct = pct;
    }

    onFullyChargedChanged: {
        _lastPct = pct;
    }
}
