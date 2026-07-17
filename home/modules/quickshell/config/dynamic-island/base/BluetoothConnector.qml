pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../menus/BluetoothUtils.js" as BluetoothUtils

// Bluetooth audio connect state machine.
// Connects paired device, hands audio output over once PipeWire publishes its sink.
//
// Singleton: one radio serves one connect attempt.
// Volume menu is per-screen, so a per-menu machine runs one bluetooth_backend.py
// per monitor against the same device, and shows progress only on the clicked screen.
Singleton {
    id: root

    // Paired audio devices.
    // Listed in output menu while disconnected, so connecting needs no Bluetooth settings app.
    // Spare Anker: F4:2B:7D:54:EF:8A
    readonly property var targets: [
        {
            name: "Anker Soundcore Boost",
            mac: "F4:2B:7D:55:AE:AB"
        },
        {
            name: "LinkBuds S",
            mac: "F8:4E:17:CB:22:59"
        },
        {
            name: "Fractal Scape",
            mac: "98:FD:B4:6F:2E:B3"
        }
    ]

    property string connectingMac: ""
    property string connectingName: ""
    property string statusText: ""
    property string statusMac: ""
    property bool autoSwitchOnConnect: false
    readonly property bool busy: connectProcess.running || root.pendingSwitchMac.length > 0

    property string pendingSwitchMac: ""
    property int pendingSwitchAttempts: 0
    readonly property int switchMaxAttempts: 60
    readonly property string backendScriptPath: Qt.resolvedUrl("../bluetooth_backend.py").toString().replace("file://", "")

    function connectDevice(targetName, mac) {
        if (root.busy)
            return;

        root.connectingMac = mac;
        root.connectingName = targetName;
        root.statusMac = mac;
        root.autoSwitchOnConnect = true;
        root.statusText = "Starte Bluetooth-Backend...";
        connectProcess.resultSeen = false;
        connectProcess.targetMac = mac;
        connectProcess.running = true;
    }

    // Manual sink pick during an in-flight connect.
    // Connect still finishes, chosen sink survives the device showing up.
    function cancelAutoSwitch() {
        root.autoSwitchOnConnect = false;
    }

    function finishStatus(statusText) {
        root.statusText = statusText;
        statusClearTimer.restart();
    }

    function resetConnect() {
        root.pendingSwitchMac = "";
        root.connectingMac = "";
        root.autoSwitchOnConnect = false;
        switchTimer.stop();
    }

    function statusTextForBackendCode(code) {
        switch (code) {
        case "CHECK_BACKEND":
            return "Prüfe Bluetooth-Backend...";
        case "UNBLOCK_BLUETOOTH":
            return "Entsperre Bluetooth...";
        case "POWER_ON":
            return "Aktiviere Bluetooth...";
        case "CONNECT_DEVICE":
            return "Verbinde mit Gerät...";
        default:
            return code;
        }
    }

    Process {
        id: connectProcess
        running: false
        property string targetMac: ""
        // Backend printed RESULT line, so onExited has nothing left to finish.
        property bool resultSeen: false

        command: ["python3", root.backendScriptPath, "connect", targetMac]

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.indexOf("STATUS:") === 0) {
                    root.statusText = root.statusTextForBackendCode(line.substring(7));
                    return;
                }

                if (line === "RESULT:OK") {
                    connectProcess.resultSeen = true;
                    root.pendingSwitchMac = connectProcess.targetMac;
                    root.pendingSwitchAttempts = 0;
                    root.statusText = "Warte auf Audio-Ausgang...";
                    switchTimer.start();
                    return;
                }

                if (line === "RESULT:FAIL") {
                    connectProcess.resultSeen = true;
                    root.resetConnect();
                    root.finishStatus("Bluetooth-Verbindung fehlgeschlagen");
                    return;
                }

                if (line === "RESULT:BACKEND_UNAVAILABLE") {
                    connectProcess.resultSeen = true;
                    root.resetConnect();
                    root.finishStatus("Bluetooth-Backend ist nicht verfuegbar");
                }
            }
        }

        stderr: SplitParser {
            onRead: data => console.warn("bluetooth_backend:", data)
        }

        // Killed or crashed backend prints no RESULT line.
        // Without this, statusText sticks on the last STATUS and connectingMac never clears,
        // so the row spins for the rest of the session.
        onExited: {
            if (connectProcess.resultSeen)
                return;
            root.resetConnect();
            root.finishStatus("Bluetooth-Verbindung fehlgeschlagen");
        }
    }

    Timer {
        id: switchTimer
        interval: 300 // ms per retry, 18s total at switchMaxAttempts=60
        repeat: true
        running: false
        onTriggered: {
            if (!root.pendingSwitchMac.length) {
                switchTimer.stop();
                return;
            }

            root.pendingSwitchAttempts++;
            const sink = BluetoothUtils.findSinkByBluetooth(Pipewire.nodes.values, root.pendingSwitchMac, root.connectingName);
            if (sink) {
                const shouldAutoSwitch = root.autoSwitchOnConnect;
                if (shouldAutoSwitch)
                    Pipewire.preferredDefaultAudioSink = sink;
                root.resetConnect();
                root.finishStatus(shouldAutoSwitch ? "Verbunden" : "Verbunden im Hintergrund");
                return;
            }

            if (root.pendingSwitchAttempts >= root.switchMaxAttempts) {
                root.resetConnect();
                root.finishStatus("Verbunden, aber kein Audio-Ausgang gefunden");
            }
        }
    }

    Timer {
        id: statusClearTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!root.busy) {
                root.statusText = "";
                root.statusMac = "";
            }
        }
    }
}
