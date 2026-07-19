pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Notification-center behavior. Thin over NotificationListener: history, DND,
// clear, plus D-Bus passthroughs the list rows call. No visuals here.
QtObject {
    id: root

    readonly property var history: NotificationListener.history
    readonly property bool hasHistory: NotificationListener.history.count > 0

    readonly property bool dnd: Globals.doNotDisturb
    function toggleDnd() {
        Globals.doNotDisturb = !Globals.doNotDisturb;
    }

    function clearHistory() {
        NotificationListener.clearHistory();
    }
    function removeAt(index) {
        NotificationListener.removeAt(index);
    }

    // D-Bus passthroughs for the history rows.
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
}
