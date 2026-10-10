import QtQuick

// Timer-stepped spinner rotation. A vsync RotationAnimation redraws the
// whole window at display rate for as long as it runs.
Timer {
    required property Item target
    property int turnMs: 900

    interval: 33
    repeat: true
    onTriggered: target.rotation = (target.rotation + 360 * interval / turnMs) % 360
}
