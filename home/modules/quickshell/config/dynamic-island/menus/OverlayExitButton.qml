import QtQuick
import "../"
import "../base"
import "../animations"

// Close button for fullscreen overlays.
// Invisible until hovered.

Rectangle {
    id: root

    signal tapped

    width: 40
    height: 40
    radius: Shape.pill(height)
    opacity: exitHover.hovered ? 1 : 0
    color: exitTap.pressed ? Colors.hoverItemPressed : exitHover.hovered ? Colors.hoverItemHovered : "transparent"
    border.color: exitHover.hovered || exitTap.pressed ? Colors.pillBorder : "transparent"

    Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    scale: exitTap.pressed ? 0.85 : 1.0
    SquishBehavior on scale {}

    TintedIcon {
        anchors.centerIn: parent
        source: "../icons/icons8-close.svg"
        size: Typography.fontSize16
        color: Colors.textColor
    }

    HoverHandler {
        id: exitHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: exitTap
        onTapped: root.tapped()
    }
}
