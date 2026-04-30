import QtQuick

// Adds inertia and adjustable speed to touchpad scrolling. Pure logic component (not a MouseArea); subscribes to a WheelSource for wheel events. Mouse wheel (NoScrollPhase) is left for Flickable's built-in handling; touchpad phases drive flickable.contentY directly with a flick on ScrollEnd.
QtObject {
    id: root

    required property Flickable flickable
    required property WheelSource wheelSource
    property real touchpadMultiplier: 4.0

    property real _velocity: 0
    property double _lastTs: 0

    property Connections _conn: Connections {
        target: root.wheelSource
        function onWheelReceived(wheel) {
            // Mouse wheel: hand off to Flickable.
            if (wheel.phase === Qt.NoScrollPhase) {
                wheel.accepted = false;
                return;
            }
            if (wheel.phase === Qt.ScrollBegin) {
                root._lastTs = 0;
                root._velocity = 0;
                wheel.accepted = true;
                return;
            }
            if (wheel.phase === Qt.ScrollEnd) {
                // Begin/End fire twice; only flick once when we still have velocity.
                if (root._velocity !== 0) {
                    root.flickable.flick(0, root._velocity);
                    root._velocity = 0;
                }
                root._lastTs = 0;
                wheel.accepted = true;
                return;
            }
            // ScrollUpdate
            const now = Date.now();
            const delta = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y;
            if (root._lastTs > 0) {
                const dt = (now - root._lastTs) / 1000;
                if (dt > 0)
                    root._velocity = (delta / dt) * root.touchpadMultiplier;
            }
            root._lastTs = now;
            const max = Math.max(0, root.flickable.contentHeight - root.flickable.height);
            root.flickable.contentY = Math.max(0, Math.min(max, root.flickable.contentY - delta * root.touchpadMultiplier));
            wheel.accepted = true;
        }
    }
}
