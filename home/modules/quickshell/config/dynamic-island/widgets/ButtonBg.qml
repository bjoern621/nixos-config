import QtQuick
import "../base"

// Shared button background: action triggers, icon buttons, toggles.
// Single source of truth for button look; callers set active/hovered/pressed only.
// Classic: round pill, subtle hover/press tint, 1px border while lit (the old look).
// Neo: sharp (radius 5), cream hover, blue accent for active/press, 2px ink border while lit.
Rectangle {
    property bool active: false     // toggle-on / selected
    property bool hovered: false
    property bool pressed: false
    readonly property bool lit: active || hovered || pressed

    anchors.fill: parent
    radius: Shape.usesBlur ? height / 2 : NeoTokens.pillRadius

    color: pressed ? Colors.selectedPressed : active ? Colors.selectedBackground : hovered ? Colors.hoverItemHovered : "transparent"

    border.width: lit ? Shape.thinBorderWidth : 0
    border.color: Colors.pillBorder
}
