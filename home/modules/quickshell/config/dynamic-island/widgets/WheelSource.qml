import QtQuick

// Captures all wheel events (mouse + touchpad) over its area and re-emits them via `wheelReceived`. Multiple consumers (TouchpadBoost for inertia, selection state for keyboard-nav exit) can subscribe without each needing their own MouseArea on top of content (which would block hover delivery to delegate HoverHandlers).
//
// The raw WheelEvent is passed by reference: a consumer may set `event.accepted` to control propagation to the underlying Flickable. Default acceptance is whatever consumers leave it at when the signal returns.
MouseArea {
    id: root

    signal wheelReceived(var event)

    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    hoverEnabled: false

    onWheel: wheel => root.wheelReceived(wheel)
}
