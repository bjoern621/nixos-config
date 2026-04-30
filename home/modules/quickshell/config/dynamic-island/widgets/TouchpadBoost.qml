import QtQuick

// Intercepts touchpad wheel events to add inertia and adjustable speed.
// hoverEnabled: false so per-delegate HoverHandlers (tooltips, hover state) still receive hover.
// Mouse wheel events (NoScrollPhase) are declined so Flickable's built-in handles them.
MouseArea {
    required property Flickable flickable
    property real touchpadMultiplier: 4.0

    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    hoverEnabled: false
    propagateComposedEvents: true

    property real _velocity: 0
    property double _lastTs: 0

    onWheel: wheel => {
        // Mouse wheel: hand off to Flickable.
        if (wheel.phase === Qt.NoScrollPhase) {
            wheel.accepted = false;
            return;
        }
        if (wheel.phase === Qt.ScrollBegin) {
            _lastTs = 0;
            _velocity = 0;
            wheel.accepted = true;
            return;
        }
        if (wheel.phase === Qt.ScrollEnd) {
            // Begin/End fire twice; only flick once when we still have velocity.
            if (_velocity !== 0) {
                flickable.flick(0, _velocity);
                _velocity = 0;
            }
            _lastTs = 0;
            wheel.accepted = true;
            return;
        }
        // ScrollUpdate
        const now = Date.now();
        const delta = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y;
        if (_lastTs > 0) {
            const dt = (now - _lastTs) / 1000;
            if (dt > 0)
                _velocity = (delta / dt) * touchpadMultiplier;
        }
        _lastTs = now;
        const max = Math.max(0, flickable.contentHeight - flickable.height);
        flickable.contentY = Math.max(0, Math.min(max, flickable.contentY - delta * touchpadMultiplier));
        wheel.accepted = true;
    }
}
