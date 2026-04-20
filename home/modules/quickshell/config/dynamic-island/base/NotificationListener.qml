pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    signal notificationReceived(var notification)

    readonly property int maxHistoryEntries: 50
    readonly property string historyFilePath: Quickshell.env("HOME") + "/.local/share/quickshell/notification-history.json"
    property string restoreBuffer: ""

    ListModel {
        id: _history
    }

    readonly property alias history: _history

    function _historyRows() {
        const rows = [];
        for (let i = 0; i < _history.count; i++)
            rows.push(_history.get(i));
        return rows;
    }

    function _persistHistory() {
        saveProc.command = ["python3", "-c", "import os,sys; path=sys.argv[1]; data=sys.argv[2]; os.makedirs(os.path.dirname(path), exist_ok=True); open(path, 'w', encoding='utf-8').write(data)", historyFilePath, JSON.stringify(_historyRows())];
        saveProc.running = true;
    }

    function _appendNotification(n) {
        if (_history.count >= maxHistoryEntries)
            _history.remove(_history.count - 1);
        _history.insert(0, {
            notifId: n.id,
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency ?? 1,
            timestamp: Date.now()
        });
        _persistHistory();
    }

    function clearHistory() {
        _history.clear();
        _persistHistory();
    }

    function removeAt(index) {
        _history.remove(index);
        _persistHistory();
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
                    for (let i = 0; i < limit; i++)
                        _history.append(restored[i]);
                    root.restoreBuffer = "";
                } catch (e) {
                    // Keep buffering until full JSON payload is available.
                }
            }
        }
    }

    Process {
        id: saveProc
        command: ["true"]
    }

    NotificationServer {
        keepOnReload: false

        onNotification: n => {
            n.tracked = true;
            root._appendNotification(n);
            root.notificationReceived(n);
        }
    }

    Component.onCompleted: restoreProc.running = true
}
