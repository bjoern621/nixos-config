pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Graceful shutdown machine.
// Closes every Hyprland window, polls until gone, then runs optional post command.
//
// Logic lives here, not in ShutdownScreen: screen is per monitor
// (Variants over Quickshell.screens), so a view-owned machine dispatches closewindow
// and runs postCmd once per screen.
//
// Usage:
//   GracefulShutdown.start("Herunterfahren...", ["systemctl", "poweroff"])
//   GracefulShutdown.start("Apps schließen...")

Singleton {
    id: root

    // Overlay maps while true.
    property bool active: false
    property string label: ""
    property var postCmd: []

    // Waiting for windows to disappear.
    property bool closing: false

    // Gave up waiting.
    // View offers proceed() or cancel().
    // Never auto-proceeds: usual cause is an unsaved-changes dialog.
    property bool stalled: false

    readonly property int pollInterval: 500
    // 20s before giving up, at pollInterval 500.
    readonly property int maxPollAttempts: 40
    property int pollAttempts: 0

    // Roles: address, appClass, title, alive.
    // Role is appClass: class is a JS reserved word, unusable as a required property.
    // ListModel, not JS array: replacing an array recreates every delegate per poll.
    readonly property alias apps: _apps

    // postCmd is destructive (systemctl poweroff).
    // Fires at most once.
    property bool _postCmdFired: false

    ListModel {
        id: _apps
    }

    function start(actionLabel, cmd) {
        // Second start would re-close over a run already in flight.
        if (active)
            return;
        label = actionLabel;
        postCmd = cmd || [];
        _apps.clear();
        pollAttempts = 0;
        stalled = false;
        _postCmdFired = false;
        active = true;
        closing = true;
        fetchClients.running = true;
    }

    function cancel() {
        active = false;
        closing = false;
        stalled = false;
        label = "";
        postCmd = [];
        pollAttempts = 0;
        _apps.clear();
    }

    // Skips still-open windows, runs postCmd immediately.
    function proceed() {
        if (!active)
            return;
        closing = false;
        stalled = false;
        _runPostCmd();
    }

    function _runPostCmd() {
        if (_postCmdFired)
            return;
        _postCmdFired = true;
        if (postCmd.length > 0)
            Quickshell.execDetached(postCmd);
    }

    function _markAlive(remainingAddrs) {
        for (let i = 0; i < _apps.count; i++) {
            const alive = remainingAddrs.has(_apps.get(i).address);
            // setProperty signals dataChanged regardless of value.
            // Write only real changes.
            if (_apps.get(i).alive !== alive)
                _apps.setProperty(i, "alive", alive);
        }
    }

    Process {
        id: fetchClients
        command: ["hyprctl", "clients", "-j"]

        // StdioCollector, not SplitParser: hyprctl clients -j outgrows one pipe read,
        // and a partial chunk fails JSON.parse.
        stdout: StdioCollector {
            id: fetchOut
            onStreamFinished: {
                if (!root.active)
                    return;

                let clients;
                try {
                    clients = JSON.parse(fetchOut.text);
                } catch (e) {
                    // Non-JSON leaves nothing to close and nothing to poll for.
                    root.cancel();
                    return;
                }

                for (let i = 0; i < clients.length; i++) {
                    _apps.append({
                        address: clients[i].address,
                        appClass: clients[i].class || "unknown",
                        title: clients[i].title || "",
                        alive: true
                    });
                    // Lua config: dispatch takes Lua expression, old word syntax no-ops.
                    Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.window.close({ window = "address:' + clients[i].address + '" })']);
                }
            }
        }
    }

    // running is bound, never assigned.
    // Imperative stops leaked the 500ms hyprctl spawn loop on every path that forgot one.
    Timer {
        id: pollTimer
        interval: root.pollInterval
        repeat: true
        running: root.active && root.closing

        onTriggered: {
            root.pollAttempts++;
            if (root.pollAttempts > root.maxPollAttempts) {
                root.closing = false;
                root.stalled = true;
                return;
            }
            pollClients.running = true;
        }
    }

    Process {
        id: pollClients
        command: ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            id: pollOut
            onStreamFinished: {
                // Read can land after cancel() or after the all-gone check.
                if (!root.active || !root.closing)
                    return;

                let remaining;
                try {
                    remaining = JSON.parse(pollOut.text);
                } catch (e) {
                    // Non-JSON can never reach the all-gone check.
                    root.cancel();
                    return;
                }

                const addrs = new Set();
                for (let i = 0; i < remaining.length; i++)
                    addrs.add(remaining[i].address);
                root._markAlive(addrs);

                // Counts windows opened after start too, so a new window blocks postCmd.
                if (remaining.length === 0) {
                    root.closing = false;
                    root._runPostCmd();
                }
            }
        }
    }
}
