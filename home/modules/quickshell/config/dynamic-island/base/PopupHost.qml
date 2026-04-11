pragma Singleton
import QtQuick

// Singleton managing a queue of dismissable popup notifications.
// Usage: PopupHost.show("../icons/icons8-settings.svg", "Title", "Message", accentColor)
QtObject {
    id: root

    // Current popup state (bound by PopupWindow)
    property bool visible: false
    property url iconSource: ""
    property string title: ""
    property string message: ""
    property color accentColor: "#ffffff"

    property var _queue: []

    function show(iconSource, title, message, accentColor) {
        _queue.push({
            iconSource: iconSource,
            title: title,
            message: message,
            accentColor: accentColor
        });
        _queueChanged();
        if (!visible)
            _showNext();
    }

    function dismiss() {
        visible = false;
        _dismissTimer.restart();
    }

    property var _dismissTimer: Timer {
        interval: 120
        onTriggered: root._showNext()
    }

    function _showNext() {
        if (_queue.length === 0) {
            visible = false;
            return;
        }
        const item = _queue.shift();
        _queueChanged();
        iconSource = item.iconSource;
        title = item.title;
        message = item.message;
        accentColor = item.accentColor;
        visible = true;
    }
}
