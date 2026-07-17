import QtQuick

// Re-emits wheel events (mouse + touchpad) over its area via `wheelReceived`.
// One source lets several consumers subscribe (TouchpadBoost inertia, keyboard-nav exit)
// without each stacking its own MouseArea over content, which would block hover delivery
// to delegate HoverHandlers.
//
// The raw WheelEvent is passed by reference: a consumer sets `event.accepted` to control
// propagation to the underlying Flickable.
// Acceptance ends as whatever consumers leave it when the signal returns.
//
// Fills its parent.
// Declared in a Flickable's data it lands in contentItem, sized contentWidth x contentHeight
// instead of the viewport, leaving the region below a short list uncovered.
// Set `parent: <flickableId>` to cover the viewport instead.
MouseArea {
    id: root

    signal wheelReceived(var event)

    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    hoverEnabled: false

    onWheel: wheel => root.wheelReceived(wheel)
}
