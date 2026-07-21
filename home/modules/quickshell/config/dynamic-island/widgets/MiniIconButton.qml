import QtQuick
import "../"

// Compact ghost icon button: transparent at rest, hover pill + squishy press.
// In-row affordance for delete, close, expand.
// Set `source` for a centered muted icon, or nest content (e.g. ExpandArrow) and
// center it yourself.
// Row-hover reveal (opacity + visible) is the caller's job; set it on the instance.
Item {
    id: root

    property url source: ""
    property color iconColor: Colors.textColorMuted
    property real iconSize: Spacing.spacing12
    property real pressedScale: 0.85
    // Persistent toggle-on tint.
    property bool active: false

    default property alias content: holder.data

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed

    signal clicked

    implicitWidth: Spacing.spacing24
    implicitHeight: Spacing.spacing24

    scale: tapHandler.pressed ? root.pressedScale : 1.0
    SquishBehavior on scale {}

    ButtonBg {
        active: root.active
        hovered: root.hovered
        pressed: root.pressed
    }

    TintedIcon {
        anchors.centerIn: parent
        visible: root.source != ""
        source: root.source
        size: root.iconSize
        color: root.iconColor
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    // ReleaseWithinBounds takes the exclusive grab on press.
    // Enclosing row's select TapHandler never also fires.
    TapHandler {
        id: tapHandler
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }
}
