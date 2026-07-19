import QtQuick
import "../base"

// Shared interactive-item background, matching the neo app launcher rows.
// Use for any list row / grid cell / menu button in both themes.
// Neo: transparent by default, cream on hover, accent (theme blue) when selected,
// darker accent on press, 2px ink border only while lit. Radius 5.
// Classic: subtle accent-tinted hover/press, no item border, radius 8 (unchanged).
Rectangle {
    property bool active: false     // selected
    property bool hovered: false
    property bool pressed: false
    readonly property bool lit: active || hovered || pressed

    // Corner radius, overridable per surface (calendar days want round in classic).
    property real cornerRadius: Shape.usesBlur ? Spacing.spacing8 : NeoTokens.pillRadius
    // Active/selected fill, overridable per surface (calendar today wants vibrant).
    property color activeColor: Colors.selectedBackground

    anchors.fill: parent
    radius: cornerRadius

    color: Shape.usesBlur ? (pressed ? Colors.hoverItemPressed : active ? activeColor : hovered ? Colors.hoverItemHovered : "transparent") : (pressed ? Colors.selectedPressed : active ? activeColor : hovered ? Colors.hoverItemHovered : "transparent")

    border.width: lit ? Shape.thinBorderWidth : 0
    border.color: Colors.pillBorder
}
