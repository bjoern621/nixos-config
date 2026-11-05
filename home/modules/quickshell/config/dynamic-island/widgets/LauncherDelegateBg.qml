import QtQuick
import "../base"

// Shared interactive-item background, matching the neo app launcher rows.
// Use for any list row / grid cell / menu button in both themes.
// Transparent by default, cream on hover, accent (theme blue) when selected,
// darker accent on press, 2px ink border only while lit. Radius 5.
Rectangle {
    property bool active: false     // selected
    property bool hovered: false
    property bool pressed: false
    readonly property bool lit: active || hovered || pressed

    anchors.fill: parent
    radius: Shape.pillRadius

    color: pressed ? Colors.selectedPressed : active ? Colors.selectedBackground : hovered ? Colors.hoverItemHovered : "transparent"

    border.width: lit ? Shape.thinBorderWidth : 0
    border.color: Colors.pillBorder
}
