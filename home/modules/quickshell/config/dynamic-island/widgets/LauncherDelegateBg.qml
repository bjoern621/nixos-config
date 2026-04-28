import QtQuick
import "../base"

// Standard interactive background for launcher list/grid delegates.
// Place as a child Rectangle that anchors.fill: parent of the delegate.
Rectangle {
    property bool active: false
    property bool pressed: false

    anchors.fill: parent
    radius: Spacing.spacing8
    color: pressed ? Colors.hoverItemPressed : active ? Colors.hoverItemHovered : "transparent"
    border.color: active || pressed ? Colors.pillBorder : "transparent"
}
