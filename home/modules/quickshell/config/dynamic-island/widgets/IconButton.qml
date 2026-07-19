import QtQuick
import "../"

// Round icon button: hover pill, squishy press, icon swap on source change.
Item {
    id: root

    property string source: ""
    property color iconColor: Colors.textColor
    property real iconSize: Typography.fontSize24
    // Medium button (40px) defaults.
    // Small icon button (32px) takes 0.85 / bouncy false / 100.
    property real pressedScale: 0.82
    property bool bouncy: true
    property int squishDuration: 120

    signal clicked

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed

    implicitWidth: 40
    implicitHeight: 40

    scale: tapHandler.pressed ? root.pressedScale : 1.0
    SquishBehavior on scale {
        bouncy: root.bouncy
        duration: root.squishDuration
    }

    ButtonBg {
        hovered: root.hovered
        pressed: root.pressed
    }

    // Keyed on source: a button whose icon never changes seeds once, never animates.
    ContentReplace {
        id: iconReplace
        contentKey: root.source
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize

        Item {
            width: root.iconSize
            height: root.iconSize

            TintedIcon {
                anchors.centerIn: parent
                source: iconReplace.displayValue
                size: root.iconSize
                color: root.iconColor
            }
        }
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        onTapped: root.clicked()
    }
}
