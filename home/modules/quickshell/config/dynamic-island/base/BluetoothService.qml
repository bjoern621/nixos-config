pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// BlueZ state + actions for the whole shell, over the native Quickshell.Bluetooth
// module (D-Bus, reactive). No bluetoothctl scraping.
//
// Singleton: radio state is machine-global, the menu is per-screen. One adapter,
// one action path feed every Bar's menu and icon. Mirrors NetworkService.
//
// Power-on routes through bluetooth_backend.py: a rfkill soft-block cannot be
// cleared by writing Adapter1.Powered over D-Bus, so the backend runs
// `rfkill unblock` first, idempotently. Every other action is a native call.
Singleton {
    id: root

    readonly property string backendScriptPath: Qt.resolvedUrl("../bluetooth_backend.py").toString().replace("file://", "")

    // ---- adapter ----
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: adapter !== null
    // state is the truth; enabled is the last-written target.
    readonly property bool powered: hasAdapter && adapter.state === BluetoothAdapterState.Enabled
    readonly property bool transitioning: hasAdapter && (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling)
    readonly property bool discovering: hasAdapter && adapter.discovering
    readonly property bool discoverable: hasAdapter && adapter.discoverable

    // ---- devices ----
    // .values tracks add/remove. Every derived list below iterates this array and
    // reads each device's properties, so QML's binding tracker registers a
    // dependency on those per-device signals (connected/paired/name): a flip
    // re-runs the list with no manual signal fan-in.
    readonly property var devices: root.hasAdapter ? root.adapter.devices.values.slice() : []

    // Connected first, then alphabetical. Sort is stable enough for a short list.
    function _sorted(list) {
        const copy = list.slice();
        copy.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return (a.name || "").localeCompare(b.name || "");
        });
        return copy;
    }

    readonly property var pairedDevices: root._sorted(root.devices.filter(d => d && (d.paired || d.bonded)))
    readonly property var availableDevices: root._sorted(root.devices.filter(d => d && !d.paired && !d.bonded))

    readonly property int connectedCount: {
        let n = 0;
        const list = root.devices;
        for (let i = 0; i < list.length; i++)
            if (list[i].connected)
                n++;
        return n;
    }
    readonly property var primaryConnected: {
        const list = root.pairedDevices;
        for (let i = 0; i < list.length; i++)
            if (list[i].connected)
                return list[i];
        return null;
    }

    // ---- bar-icon selector ----
    readonly property string iconMode: {
        if (!hasAdapter || !powered)
            return "off";
        if (connectedCount > 0)
            return "connected";
        return "on";
    }

    // ---- header subtitle ----
    readonly property string summary: {
        if (!hasAdapter)
            return "Kein Adapter";
        if (!powered)
            return transitioning ? "Wird eingeschaltet…" : "Aus";
        if (discovering && connectedCount === 0)
            return "Suche nach Geräten…";
        if (connectedCount === 1)
            return "Verbunden · " + (primaryConnected ? primaryConnected.name : "");
        if (connectedCount > 1)
            return connectedCount + " Geräte verbunden";
        return "Nicht verbunden";
    }

    // ---- transient feedback ----
    property string statusText: ""
    function _flash(text) {
        root.statusText = text;
        statusClearTimer.restart();
    }
    Timer {
        id: statusClearTimer
        interval: 3500
        onTriggered: root.statusText = ""
    }

    // ---- menu open tracking (per-screen refcount) ----
    // Discovery runs for exactly as long as any menu is open: start on first open,
    // stop on last close, no manual toggle. BlueZ keeps a started discovery running
    // until StopDiscovery, so "indefinitely while open" needs no re-assert.
    property int _openMenus: 0
    function openMenu() {
        root._openMenus++;
        if (root._openMenus === 1 && root.powered)
            root.setDiscovering(true);
    }
    function closeMenu() {
        root._openMenus = Math.max(0, root._openMenus - 1);
        if (root._openMenus === 0)
            root.setDiscovering(false);
    }
    // Radio powered up while a menu is open: begin scanning. BlueZ drops discovery
    // when the adapter powers down, so the off direction needs no handling.
    onPoweredChanged: if (root.powered && root._openMenus > 0) root.setDiscovering(true)

    // ---- power (backend, idempotent) ----
    readonly property bool powerBusy: powerProc.running
    function setPowered(on) {
        if (!root.hasAdapter || powerProc.running)
            return;
        if (root.powered === on)
            return;
        if (!on && root.discovering)
            root.adapter.discovering = false;
        powerProc.resultSeen = false;
        powerProc.command = ["python3", root.backendScriptPath, "power", on ? "on" : "off"];
        root.statusText = on ? "Bluetooth wird eingeschaltet…" : "Bluetooth wird ausgeschaltet…";
        powerProc.running = true;
    }
    function togglePowered() {
        root.setPowered(!root.powered);
    }

    // ---- discovery ----
    function setDiscovering(on) {
        if (!root.powered)
            return;
        if (root.adapter.discovering === on)
            return;
        root.adapter.discovering = on;
    }

    // ---- discoverable ----
    function setDiscoverable(on) {
        if (!root.powered)
            return;
        if (root.adapter.discoverable === on)
            return;
        root.adapter.discoverable = on;
        if (on)
            root._flash("Für andere Geräte sichtbar");
    }
    function toggleDiscoverable() {
        root.setDiscoverable(!root.discoverable);
    }

    // ---- per-device actions (guarded, idempotent) ----
    // The native call is idempotent on its own; the guards keep status text honest
    // and skip no-op D-Bus round-trips.
    function _busy(device) {
        return device && (device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting || device.pairing);
    }

    function connectDevice(device) {
        if (!device || device.connected || _busy(device))
            return;
        root._flash("Verbinde mit " + device.name + "…");
        device.connect();
    }
    function disconnectDevice(device) {
        if (!device || !device.connected)
            return;
        device.disconnect();
    }
    // Row tap dispatch: pair, then toggle connection.
    function activate(device) {
        if (!device)
            return;
        if (!device.paired && !device.bonded) {
            root.pairDevice(device);
            return;
        }
        if (device.connected)
            root.disconnectDevice(device);
        else
            root.connectDevice(device);
    }

    function pairDevice(device) {
        if (!device || device.paired || device.pairing)
            return;
        root._flash("Koppelt mit " + device.name + "…");
        device.pair();
    }
    function cancelPair(device) {
        if (device && device.pairing)
            device.cancelPair();
    }
    function forgetDevice(device) {
        if (!device)
            return;
        root._flash(device.name + " entfernt");
        device.forget();
    }
    function setTrusted(device, on) {
        if (device && device.trusted !== on)
            device.trusted = on;
    }
    function setBlocked(device, on) {
        if (device && device.blocked !== on)
            device.blocked = on;
    }
    function rename(device, name) {
        const n = (name || "").trim();
        if (device && n.length && device.name !== n)
            device.name = n;
    }

    // Detached GUI launch; uses the session PATH, not the private wrapper PATH.
    function openSettings() {
        Quickshell.execDetached(["blueman-manager"]);
    }

    // ---- power backend process ----
    Process {
        id: powerProc
        running: false
        property bool resultSeen: false
        command: ["python3", root.backendScriptPath, "power", "on"]

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.indexOf("STATUS:") === 0)
                    return; // native state drives the UI; STATUS is backend chatter
                if (line === "RESULT:OK") {
                    powerProc.resultSeen = true;
                    root.statusText = "";
                    return;
                }
                if (line.indexOf("RESULT:") === 0) {
                    powerProc.resultSeen = true;
                    root._flash("Bluetooth-Schaltung fehlgeschlagen");
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("bluetooth_backend:", data)
        }
        // Killed/crashed backend prints no RESULT line; clear status so nothing sticks.
        onExited: {
            if (powerProc.resultSeen)
                return;
            root._flash("Bluetooth-Schaltung fehlgeschlagen");
        }
    }
}
