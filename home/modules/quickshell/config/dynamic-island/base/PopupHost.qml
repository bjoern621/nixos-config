pragma Singleton
import QtQuick

QtObject {
    id: root

    // Modal state, bound by ModalOverlay.
    property bool visible: false
    property url iconSource: ""
    property string title: ""
    property string message: ""
    property color accentColor: "#ffffff"

    property var _queue: []

    // Emitted while visible is still false, so ModalOverlay picks its output before the surface maps.
    // Assigning the screen after the map remaps it off the old one.
    signal aboutToShow

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
        // show() inside dismiss()'s 120ms window calls this directly.
        // Stale timer would fire it again against an empty queue, hiding the popup just shown.
        _dismissTimer.stop();
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
        aboutToShow();
        visible = true;
    }
}
