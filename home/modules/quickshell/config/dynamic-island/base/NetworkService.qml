pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../menus/NetworkUtils.js" as NetworkUtils

// NetworkManager state + actions for the whole shell.
// Singleton: network state is machine-global, the menu is per-screen. One monitor,
// one scan loop, one action queue feed every Bar's menu and icon.
//
// Reads run in QML (nmcli -t, parsed in NetworkUtils). Mutations run through
// network_backend.py, which emits STATUS:/RESULT: lines, mirroring BluetoothConnector.
Singleton {
    id: root

    readonly property string backendScriptPath: Qt.resolvedUrl("../network_backend.py").toString().replace("file://", "")

    // ---- published state ----
    property bool wifiEnabled: true
    property string connState: ""
    property string connectivity: ""
    property bool airplaneMode: false

    property var wifiNetworks: []
    property var _nmVpns: []
    property var ethernet: null

    // Tailscale up/down live in the daemon, read via `tailscale status --json`.
    property bool tailscaleAvailable: false
    property bool tailscaleUp: false

    // NM-managed VPN/WireGuard profiles plus Tailscale (a tun device NM cannot
    // toggle). Tailscale carries the `tailscale` flag so the row routes its
    // toggle through the CLI instead of `nmcli connection up/down`.
    readonly property var vpnConnections: {
        const list = _nmVpns.slice();
        if (tailscaleAvailable)
            list.push({
                name: "Tailscale",
                uuid: "tailscale",
                kind: "Tailscale",
                active: tailscaleUp,
                tailscale: true
            });
        return list;
    }
    property var activeDetail: ({
            ip: "",
            gateway: "",
            dns: [],
            mac: ""
        })

    readonly property string activeSsid: {
        for (let i = 0; i < wifiNetworks.length; i++)
            if (wifiNetworks[i].active)
                return wifiNetworks[i].ssid;
        return "";
    }
    readonly property bool ethernetActive: ethernet !== null
    // Header three-way toggle position. airplane wins; else wifi radio state.
    readonly property string radioMode: airplaneMode ? "airplane" : (wifiEnabled ? "on" : "off")
    readonly property bool vpnActive: {
        for (let i = 0; i < vpnConnections.length; i++)
            if (vpnConnections[i].active)
                return true;
        return false;
    }
    readonly property string activeVpnName: {
        for (let i = 0; i < vpnConnections.length; i++)
            if (vpnConnections[i].active)
                return vpnConnections[i].name;
        return "";
    }

    // Bar-icon shape selector.
    readonly property string iconMode: {
        if (ethernetActive)
            return "ethernet";
        if (!wifiEnabled)
            return "wifi-off";
        if (activeSsid.length)
            return "wifi";
        return "disconnected";
    }
    readonly property int iconLevel: {
        for (let i = 0; i < wifiNetworks.length; i++)
            if (wifiNetworks[i].active)
                return wifiNetworks[i].level;
        return 0;
    }

    // ---- transient action feedback ----
    // busyKey identifies the spinning element: "wifi:<ssid>" or "vpn:<uuid>".
    property string busyKey: ""
    property string statusText: ""

    // ---- throughput (menu-open only) ----
    property real rxRate: 0   // bytes/s
    property real txRate: 0
    property real _lastRx: -1
    property real _lastTx: -1

    // ---- QR of the active network ----
    property string qrImagePath: ""
    property int _qrGen: 0

    property int _openMenus: 0
    property var _scan: []
    property var _connections: []
    property string _activeDevice: ""

    // True while a menu is open and wifi can scan. rescanTimer keeps NetworkManager
    // scanning on a fixed interval; exposes that loop as one state for the spinner.
    readonly property bool scanning: root._openMenus > 0 && root.wifiEnabled

    function openMenu() {
        root._openMenus++;
        if (root._openMenus === 1) {
            root.refresh();
            root.rescan();
        }
    }
    function closeMenu() {
        root._openMenus = Math.max(0, root._openMenus - 1);
        if (root._openMenus === 0) {
            root._lastRx = -1;
            root._lastTx = -1;
            root.rxRate = 0;
            root.txRate = 0;
            root.qrImagePath = "";
        }
    }

    function scheduleRefresh() {
        refreshTimer.restart();
    }
    function refresh() {
        generalProc.running = true;
        wifiProc.running = true;
        connProc.running = true;
        tailscaleProc.running = true;
    }

    function _rebuildWifi() {
        root.wifiNetworks = NetworkUtils.buildWifiModel(root._scan, root._connections);
    }

    // ---- reads ----
    Process {
        id: generalProc
        command: ["nmcli", "-t", "-f", "STATE,CONNECTIVITY,WIFI", "general", "status"]
        stdout: StdioCollector {
            id: generalOut
            onStreamFinished: {
                const g = NetworkUtils.parseGeneral(generalOut.text);
                root.connState = g.state;
                root.connectivity = g.connectivity;
                root.wifiEnabled = g.wifiEnabled;
                if (g.wifiEnabled)
                    root.airplaneMode = false;
            }
        }
    }

    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,FREQ,SSID", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            id: wifiOut
            onStreamFinished: {
                root._scan = NetworkUtils.parseWifiScan(wifiOut.text);
                root._rebuildWifi();
            }
        }
    }

    Process {
        id: connProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE,ACTIVE,AUTOCONNECT", "connection", "show"]
        stdout: StdioCollector {
            id: connOut
            onStreamFinished: {
                root._connections = NetworkUtils.parseConnections(connOut.text);
                root._rebuildWifi();
                root._nmVpns = NetworkUtils.buildVpnModel(root._connections);
                root.ethernet = NetworkUtils.findEthernet(root._connections);

                const dev = NetworkUtils.activeDevice(root._connections);
                root._activeDevice = dev;
                if (dev.length)
                    detailProc.running = true;
                else
                    root.activeDetail = {
                        ip: "",
                        gateway: "",
                        dns: [],
                        mac: ""
                    };
            }
        }
    }

    Process {
        id: detailProc
        command: ["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,GENERAL.HWADDR", "device", "show", root._activeDevice]
        stdout: StdioCollector {
            id: detailOut
            onStreamFinished: root.activeDetail = NetworkUtils.parseDeviceDetail(detailOut.text)
        }
    }

    // Tailscale state. nmcli reports the tun device but not the daemon's up/down,
    // so the daemon is the source of truth. Absent binary -> parseTailscale
    // returns unavailable and no row is shown.
    Process {
        id: tailscaleProc
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            id: tailscaleOut
            onStreamFinished: {
                const t = NetworkUtils.parseTailscale(tailscaleOut.text);
                root.tailscaleAvailable = t.available;
                root.tailscaleUp = t.up;
            }
        }
    }

    // Live NetworkManager events. Any line debounces a refresh.
    Process {
        id: monitorProc
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: root.scheduleRefresh()
        }
    }

    Timer {
        id: refreshTimer
        interval: 300
        onTriggered: root.refresh()
    }

    // Periodic rescan while a menu is open. Rescan feeds the monitor, which refreshes.
    Timer {
        id: rescanTimer
        interval: 12000
        repeat: true
        running: root._openMenus > 0
        onTriggered: root.rescan()
    }

    // ---- throughput ----
    readonly property real _throughputIntervalSec: 1.5
    Timer {
        id: throughputTimer
        interval: 1500
        repeat: true
        running: root._openMenus > 0 && root._activeDevice.length > 0
        onTriggered: throughputProc.running = true
    }
    Process {
        id: throughputProc
        command: ["cat", "/sys/class/net/" + root._activeDevice + "/statistics/rx_bytes", "/sys/class/net/" + root._activeDevice + "/statistics/tx_bytes"]
        stdout: StdioCollector {
            id: throughputOut
            onStreamFinished: {
                const parts = throughputOut.text.trim().split("\n");
                if (parts.length < 2)
                    return;
                const rx = parseFloat(parts[0]);
                const tx = parseFloat(parts[1]);
                if (root._lastRx >= 0) {
                    root.rxRate = Math.max(0, (rx - root._lastRx) / root._throughputIntervalSec);
                    root.txRate = Math.max(0, (tx - root._lastTx) / root._throughputIntervalSec);
                }
                root._lastRx = rx;
                root._lastTx = tx;
            }
        }
    }

    function formatRate(bytesPerSec) {
        if (bytesPerSec >= 1024 * 1024)
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s";
        if (bytesPerSec >= 1024)
            return Math.round(bytesPerSec / 1024) + " KB/s";
        return Math.round(bytesPerSec) + " B/s";
    }

    // ---- actions with feedback (single-flight) ----
    function _startAction(argv, key) {
        if (actionProc.running)
            return;
        root.busyKey = key;
        actionProc.resultSeen = false;
        actionProc.argv = argv;
        actionProc.running = true;
    }

    function connect(ssid, password, hidden) {
        _startAction(["connect", ssid, password || "", hidden ? "1" : "0"], "wifi:" + ssid);
    }
    function disconnect(target, ssid) {
        _startAction(["disconnect", target], "wifi:" + ssid);
    }
    function forget(uuid, ssid) {
        _startAction(["forget", uuid], "wifi:" + ssid);
    }
    function vpnUp(uuid) {
        _startAction(["vpn", "up", uuid], "vpn:" + uuid);
    }
    function vpnDown(uuid) {
        _startAction(["vpn", "down", uuid], "vpn:" + uuid);
    }
    // Tailscale toggles through the CLI, not nmcli. busyKey "vpn:tailscale"
    // matches the synthetic row's uuid.
    function setTailscale(on) {
        _startAction(["tailscale", on ? "up" : "down"], "vpn:tailscale");
    }

    function _statusForCode(code) {
        switch (code) {
        case "CONNECTING":
            return "Verbinde...";
        case "DISCONNECTING":
            return "Trenne...";
        case "VPN_UP":
            return "VPN wird aktiviert...";
        case "VPN_DOWN":
            return "VPN wird getrennt...";
        default:
            return code;
        }
    }
    function _statusForResult(result) {
        switch (result) {
        case "OK":
            return "";
        case "FAIL:AUTH":
            return "Falsches Passwort";
        case "FAIL:TIMEOUT":
            return "Zeitüberschreitung";
        case "FAIL:MISSING":
            return "nmcli nicht gefunden";
        default:
            return "Aktion fehlgeschlagen";
        }
    }

    Process {
        id: actionProc
        running: false
        property var argv: []
        property bool resultSeen: false
        command: ["python3", root.backendScriptPath].concat(argv)

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.indexOf("STATUS:") === 0) {
                    root.statusText = root._statusForCode(line.substring(7));
                    return;
                }
                if (line.indexOf("RESULT:") === 0) {
                    actionProc.resultSeen = true;
                    root.busyKey = "";
                    root.statusText = root._statusForResult(line.substring(7));
                    statusClearTimer.restart();
                    root.scheduleRefresh();
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("network_backend:", data)
        }
        onExited: {
            if (actionProc.resultSeen)
                return;
            root.busyKey = "";
            root.statusText = "Aktion fehlgeschlagen";
            statusClearTimer.restart();
            root.scheduleRefresh();
        }
    }

    Timer {
        id: statusClearTimer
        interval: 3000
        onTriggered: if (!root.busyKey.length) root.statusText = ""
    }

    // ---- fire-and-forget utility actions (FIFO queue) ----
    property var _utilQueue: []
    function _runUtil(argv) {
        const next = root._utilQueue.slice();
        next.push(argv);
        root._utilQueue = next;
        if (!utilProc.running)
            _dequeueUtil();
    }
    function _dequeueUtil() {
        if (!root._utilQueue.length)
            return;
        const q = root._utilQueue.slice();
        utilProc.argv = q.shift();
        root._utilQueue = q;
        utilProc.running = true;
    }

    function toggleWifi() {
        root.wifiEnabled = !root.wifiEnabled; // optimistic; monitor corrects
        _runUtil(["radio", "wifi", root.wifiEnabled ? "on" : "off"]);
    }
    function setAirplane(on) {
        root.airplaneMode = on;
        if (on)
            root.wifiEnabled = false;
        _runUtil(["airplane", on ? "on" : "off"]);
    }
    // Three-way header toggle. off/on set the wifi radio; airplane blocks all.
    // Leaving airplane unblocks (rfkill unblock all re-enables wifi) before the
    // radio step forces the requested wifi state. Queue is FIFO, so order holds.
    function setRadioMode(mode) {
        if (mode === root.radioMode)
            return;
        if (mode === "airplane") {
            setAirplane(true);
            return;
        }
        const leavingAirplane = root.airplaneMode;
        root.airplaneMode = false;              // optimistic; monitor corrects
        root.wifiEnabled = (mode === "on");
        if (leavingAirplane)
            _runUtil(["airplane", "off"]);
        _runUtil(["radio", "wifi", mode === "on" ? "on" : "off"]);
    }
    function rescan() {
        _runUtil(["rescan"]);
    }
    // Detached GUI launch; uses the session PATH, not the private wrapper PATH.
    function openEditor() {
        Quickshell.execDetached(["nm-connection-editor"]);
    }
    function setAutoconnect(uuid, enabled) {
        _runUtil(["modify", uuid, "connection.autoconnect", enabled ? "yes" : "no"]);
    }

    Process {
        id: utilProc
        running: false
        property var argv: []
        command: ["python3", root.backendScriptPath].concat(argv)
        stderr: SplitParser {
            onRead: data => console.warn("network_backend:", data)
        }
        onExited: {
            root.scheduleRefresh();
            root._dequeueUtil();
        }
    }

    // ---- QR of a saved network ----
    // Retrieve the stored PSK, then hand it to qrencode. Degrades to empty when
    // the secret is unreadable.
    function requestQr(uuid, ssid) {
        root.qrImagePath = "";
        pskProc.ssid = ssid;
        pskProc.uuid = uuid;
        pskProc.running = true;
    }
    function _qrEscape(s) {
        return (s || "").replace(/([\\;,:"])/g, "\\$1");
    }
    Process {
        id: pskProc
        running: false
        property string ssid: ""
        property string uuid: ""
        command: ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", uuid]
        stdout: StdioCollector {
            id: pskOut
            onStreamFinished: {
                const psk = pskOut.text.trim();
                const auth = psk.length ? "WPA" : "nopass";
                const payload = "WIFI:T:" + auth + ";S:" + root._qrEscape(pskProc.ssid) + ";P:" + root._qrEscape(psk) + ";;";
                // Unique filename per request: a file:// URL cannot cache-bust
                // with a query string, so the path itself must change.
                root._qrGen++;
                qrProc.outPath = "/tmp/qs-wifi-qr-" + root._qrGen + ".png";
                qrProc.payload = payload;
                qrProc.running = true;
            }
        }
    }
    Process {
        id: qrProc
        running: false
        property string outPath: ""
        property string payload: ""
        command: ["qrencode", "-m", "1", "-s", "8", "-o", outPath, payload]
        onExited: code => {
            if (code === 0)
                root.qrImagePath = "file://" + qrProc.outPath + "?g=" + root._qrGen;
        }
    }

    Component.onCompleted: root.refresh()
}
