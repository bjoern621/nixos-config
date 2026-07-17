pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    signal notificationReceived(string uid, var notification)
    signal notificationClosed(string uid)

    readonly property int maxHistoryEntries: 50
    readonly property string historyFilePath: Quickshell.env("HOME") + "/.local/share/quickshell/notification-history.json"
    property string restoreBuffer: ""

    // Live server notifications get uids in the "n" namespace, rows restored from disk get "h".
    // Server restarts its ids at 1 every session.
    // Without the split, a recycled id resolves a restored row to an unrelated live notification.
    property int uidCounter: 0

    ListModel {
        id: _history
    }

    readonly property alias history: _history

    function _historyRows() {
        const rows = [];
        for (let i = 0; i < _history.count; i++) {
            const r = _history.get(i);
            rows.push({
                notifId: r.notifId,
                appName: r.appName,
                summary: r.summary,
                body: r.body,
                urgency: r.urgency,
                timestamp: r.timestamp,
                desktopEntry: r.desktopEntry
            });
        }
        return rows;
    }

    function _persistHistory() {
        saveProc.command = ["python3", "-c", "import os,sys; path=sys.argv[1]; data=sys.argv[2]; os.makedirs(os.path.dirname(path), exist_ok=True); open(path, 'w', encoding='utf-8').write(data)", historyFilePath, JSON.stringify(_historyRows())];
        saveProc.running = true;
    }

    function _rowIndex(uid) {
        for (let i = 0; i < _history.count; i++) {
            if (_history.get(i).uid === uid)
                return i;
        }
        return -1;
    }

    // Still-tracked notification behind a history row.
    // null once the client closed it, and for rows restored from a previous session.
    function _liveFor(uid) {
        if (!uid.startsWith("n"))
            return null;
        const idx = _rowIndex(uid);
        if (idx < 0)
            return null;
        const notifId = _history.get(idx).notifId;
        const tracked = server.trackedNotifications.values;
        for (let i = 0; i < tracked.length; i++) {
            if (tracked[i].id === notifId)
                return tracked[i];
        }
        return null;
    }

    function _uidForNotifId(notifId) {
        for (let i = 0; i < _history.count; i++) {
            const r = _history.get(i);
            if (r.notifId === notifId && r.uid.startsWith("n"))
                return r.uid;
        }
        return "";
    }

    function _entryFor(uid) {
        const idx = _rowIndex(uid);
        if (idx < 0)
            return null;
        const row = _history.get(idx);
        const entry = row.desktopEntry !== "" ? DesktopEntries.byId(row.desktopEntry) : null;
        if (entry)
            return entry;
        return row.appName !== "" ? DesktopEntries.heuristicLookup(row.appName) : null;
    }

    function _appendNotification(n) {
        while (_history.count >= maxHistoryEntries)
            _evictAt(_history.count - 1);

        const uid = "n" + (++uidCounter);
        _history.insert(0, {
            uid: uid,
            notifId: n.id,
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency ?? 1,
            timestamp: Date.now(),
            desktopEntry: n.desktopEntry || ""
        });
        _persistHistory();
        return uid;
    }

    // Dropping a row also closes its notification.
    // Else the client keeps waiting on a notification nothing can display.
    function _evictAt(index) {
        const n = _liveFor(_history.get(index).uid);
        if (n)
            n.dismiss();
        _history.remove(index);
    }

    function clearHistory() {
        while (_history.count > 0)
            _evictAt(_history.count - 1);
        _persistHistory();
    }

    function removeAt(index) {
        if (index < 0 || index >= _history.count)
            return;
        _evictAt(index);
        _persistHistory();
    }

    // Closes the notification client-side, keeps the row.
    // Dismissed toast stays readable in the notification center.
    function dismiss(uid) {
        const n = _liveFor(uid);
        if (n)
            n.dismiss();
    }

    // Action keyed "default" fires on a click of the notification body.
    // Never rendered as a button.
    function actionsFor(uid) {
        const n = _liveFor(uid);
        if (!n)
            return [];
        const out = [];
        for (let i = 0; i < n.actions.length; i++) {
            if (n.actions[i].identifier === "default")
                continue;
            out.push({
                index: i,
                text: n.actions[i].text
            });
        }
        return out;
    }

    function invokeAction(uid, index) {
        const n = _liveFor(uid);
        if (!n || index < 0 || index >= n.actions.length)
            return false;
        n.actions[index].invoke();
        return true;
    }

    // Clients without a default action still expect a click to raise them.
    // Desktop entry is launched instead.
    function invokeDefault(uid) {
        const n = _liveFor(uid);
        if (n) {
            for (let i = 0; i < n.actions.length; i++) {
                if (n.actions[i].identifier === "default") {
                    n.actions[i].invoke();
                    return true;
                }
            }
        }
        const entry = _entryFor(uid);
        if (!entry)
            return false;
        entry.execute();
        return true;
    }

    function hasClickAction(uid) {
        const n = _liveFor(uid);
        if (n) {
            for (let i = 0; i < n.actions.length; i++) {
                if (n.actions[i].identifier === "default")
                    return true;
            }
        }
        return _entryFor(uid) !== null;
    }

    // Notification can go away without this shell asking.
    // Client withdraws it, or an action destroys it.
    // Toasts for notifications that no longer exist have to stop being shown.
    Instantiator {
        model: server.trackedNotifications

        delegate: Connections {
            required property var modelData
            readonly property int notifId: modelData.id

            target: modelData

            function onClosed(reason) {
                const uid = root._uidForNotifId(notifId);
                if (uid !== "")
                    root.notificationClosed(uid);
            }
        }
    }

    Process {
        id: restoreProc
        command: ["python3", "-c", "import pathlib,sys; path=pathlib.Path(sys.argv[1]); print(path.read_text(encoding='utf-8') if path.exists() else '', end='')", root.historyFilePath]

        stdout: SplitParser {
            onRead: data => {
                root.restoreBuffer += data;
                const raw = root.restoreBuffer.trim();
                if (raw.length === 0)
                    return;
                try {
                    const restored = JSON.parse(raw);
                    if (!Array.isArray(restored))
                        return;
                    const limit = Math.min(restored.length, root.maxHistoryEntries);
                    for (let i = 0; i < limit; i++) {
                        const r = restored[i];
                        _history.append({
                            uid: "h" + i,
                            notifId: r.notifId ?? 0,
                            appName: r.appName ?? "",
                            summary: r.summary ?? "",
                            body: r.body ?? "",
                            urgency: r.urgency ?? 1,
                            timestamp: r.timestamp ?? 0,
                            desktopEntry: r.desktopEntry ?? ""
                        });
                    }
                    root.restoreBuffer = "";
                } catch (e) {
                    // Keep buffering until full JSON payload is available.
                }
            }
        }

        // Parser clears restoreBuffer only on a successful parse, so leftovers at exit
        // mean the file will never parse.
        // Without this, history stays silently empty for every future session.
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("[NotificationListener] history read failed (exit " + exitCode + "):", root.historyFilePath);
                return;
            }
            if (root.restoreBuffer.trim().length === 0)
                return;
            console.warn("[NotificationListener] history unparseable, resetting:", root.historyFilePath);
            root.restoreBuffer = "";
            root._persistHistory();
        }
    }

    Process {
        id: saveProc
        command: ["true"]
    }

    NotificationServer {
        id: server

        keepOnReload: false
        // Clients send actions only to a server that advertises them.
        // Clients keep a notification past its timeout only if the server advertises persistence.
        // Notification center needs both.
        actionsSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            root.notificationReceived(root._appendNotification(n), n);
        }
    }

    Component.onCompleted: restoreProc.running = true
}
