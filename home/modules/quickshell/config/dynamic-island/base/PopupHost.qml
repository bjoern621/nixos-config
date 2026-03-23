pragma Singleton
import QtQuick

// Singleton managing a queue of dismissable popup notifications.
// Usage: PopupHost.show("\uf071", "Title", "Message", "#e53935")
QtObject {
    id: root

    // Current popup state (bound by PopupWindow)
    property bool visible: false
    property string icon: ""
    property string title: ""
    property string message: ""
    property color color: "#ffffff"

    property var _queue: []

    function show(icon, title, message, color) {
        _queue.push({ icon: icon, title: title, message: message, color: color })
        _queueChanged()
        if (!visible) _showNext()
    }

    function dismiss() {
        visible = false
        _dismissTimer.restart()
    }

    property var _dismissTimer: Timer {
        interval: 120
        onTriggered: root._showNext()
    }

    function _showNext() {
        if (_queue.length === 0) {
            visible = false
            return
        }
        const item = _queue.shift()
        _queueChanged()
        icon = item.icon
        title = item.title
        message = item.message
        color = item.color
        visible = true
    }
}
