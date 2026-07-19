import QtQuick
import ".."

// Interaction behavior, no look.
// Wraps content, exposes hovered/pressed, emits clicked(), applies the squish
// press-scale. Callers provide the visual; both classic and neo buttons compose
// this so the click/press logic is written once.
// Size it explicitly; content fills it.
Item {
    id: root

    default property alias content: holder.data
    property bool enabled: true
    property real pressedScale: 0.96
    property bool bouncy: false
    property int squishDuration: 100
    property var cursorShape: Qt.PointingHandCursor

    readonly property bool hovered: hover.hovered
    readonly property bool pressed: tap.pressed

    signal clicked

    scale: root.enabled && tap.pressed ? root.pressedScale : 1.0
    SquishBehavior on scale {
        bouncy: root.bouncy
        duration: root.squishDuration
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    HoverHandler {
        id: hover
        cursorShape: root.enabled ? root.cursorShape : Qt.ArrowCursor
    }

    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
