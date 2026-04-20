pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    signal notificationReceived(var notification)

    ListModel {
        id: _history
    }

    readonly property alias history: _history

    function clearHistory() {
        _history.clear();
    }

    function removeAt(index) {
        _history.remove(index);
    }

    NotificationServer {
        keepOnReload: false

        onNotification: n => {
            n.tracked = true;
            if (_history.count >= 50)
                _history.remove(_history.count - 1);
            _history.insert(0, {
                notifId: n.id,
                appName: n.appName || "",
                summary: n.summary || "",
                body: n.body || "",
                urgency: n.urgency ?? 1
            });
            root.notificationReceived(n);
        }
    }
}
