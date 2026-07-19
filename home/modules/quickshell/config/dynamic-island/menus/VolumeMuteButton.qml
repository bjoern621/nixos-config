pragma ComponentBehavior: Bound

import QtQuick
import "../"
import "../base"

Item {
    id: root

    property url iconSource
    property int iconSize: 18
    signal tapped

    implicitWidth: 32
    implicitHeight: 32

    scale: tapHandler.pressed ? 0.85 : 1.0
    SquishBehavior on scale {}

    // Button bg: cream hover, 2px ink border when lit, radius 5 (neo).
    // Squish scale carries press feedback.
    ButtonBg {
        hovered: hoverHandler.hovered
    }

    ContentReplace {
        id: iconReplace
        contentKey: root.iconSource
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize

        Item {
            width: root.iconSize
            height: root.iconSize
            x: 0
            y: 0

            TintedIcon {
                anchors.centerIn: parent
                size: root.iconSize
                source: iconReplace.displayValue
            }
        }
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: tapHandler
        onTapped: root.tapped()
    }
}
