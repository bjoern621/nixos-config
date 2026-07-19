pragma ComponentBehavior: Bound
import QtQuick
import ".."

// On-screen toast behavior: live toast model + lifecycle over NotificationListener.
// New notifications append (skipped under DND); closed ones start hide animation.
// Views bind to `model` and call hide/remove; D-Bus goes through the passthroughs.
// No visuals here.
QtObject {
    id: root

    readonly property int maxVisibleToasts: 5

    // One row per on-screen toast: {uid, appName, summary, body, urgency, expireTimeout, active}.
    property ListModel model: ListModel {}

    property Connections _conn: Connections {
        target: NotificationListener
        function onNotificationReceived(uid, notification) {
            root._addEntry(uid, notification);
        }
        function onNotificationClosed(uid) {
            root.hideEntry(uid);
        }
    }

    function _addEntry(uid, n) {
        if (Globals.doNotDisturb)
            return;
        if (root.model.count >= root.maxVisibleToasts)
            root.model.remove(0);

        root.model.append({
            uid: uid,
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency ?? 1,
            expireTimeout: n.expireTimeout ?? -1,
            active: true
        });
    }

    function indexOf(uid) {
        for (let i = 0; i < root.model.count; i++) {
            if (root.model.get(i).uid === uid)
                return i;
        }
        return -1;
    }

    // Starts the hide animation. Delegate drops itself once it plays out.
    function hideEntry(uid) {
        const i = root.indexOf(uid);
        if (i >= 0)
            root.model.setProperty(i, "active", false);
    }

    // Removes the toast only. Notification stays tracked so the center keeps its
    // actions until dismissed there.
    function removeEntry(uid) {
        const i = root.indexOf(uid);
        if (i >= 0)
            root.model.remove(i);
    }

    // D-Bus passthroughs. View never touches NotificationListener directly.
    function actionsFor(uid) {
        return NotificationListener.actionsFor(uid);
    }
    function hasClickAction(uid) {
        return NotificationListener.hasClickAction(uid);
    }
    function invokeDefault(uid) {
        return NotificationListener.invokeDefault(uid);
    }
    function invokeAction(uid, index) {
        return NotificationListener.invokeAction(uid, index);
    }
    function dismiss(uid) {
        NotificationListener.dismiss(uid);
    }
}
