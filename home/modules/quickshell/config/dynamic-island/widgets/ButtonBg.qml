import QtQuick
import "../base"

// Shared button background: action triggers, icon buttons, toggles.
// Single source of truth for button look; callers set active/hovered/pressed only.
// Classic: round pill, subtle hover/press tint, 1px border while lit (the old look).
// Neo: sharp (radius 5), cream hover, blue accent for active/press, 2px ink border while lit.
//
// restColor: fill at rest. Transparent for pills over a surface; opaque paper for a
//   neo block face, since a transparent face reveals the ink shadow behind it as black.
// borderAlways: keep the outline even at rest. Neo blocks need their outline always;
//   pills draw it only while lit.
Rectangle {
    property bool active: false     // toggle-on / selected
    property bool hovered: false
    property bool pressed: false
    property color restColor: "transparent"
    property bool borderAlways: false
    readonly property bool lit: active || hovered || pressed

    // Corner radius, overridable per surface (classic power buttons want slight, not round).
    property real cornerRadius: Shape.usesBlur ? height / 2 : NeoTokens.pillRadius

    anchors.fill: parent
    radius: cornerRadius

    color: pressed ? Colors.selectedPressed : active ? Colors.selectedBackground : hovered ? Colors.hoverItemHovered : restColor

    border.width: (borderAlways || lit) ? Shape.thinBorderWidth : 0
    border.color: Colors.pillBorder
}
