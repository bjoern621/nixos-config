pragma ComponentBehavior: Bound

import QtQuick
import "../"
import "../base"

Item {
    id: root

    property string iconSource: ""
    property int iconSize: 18
    signal tapped

    implicitWidth: 32
    implicitHeight: 32

    scale: tapHandler.pressed ? 0.85 : 1.0
    SquishBehavior on scale {}

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: tapHandler.pressed ? Colors.hoverItemPressed : hoverHandler.hovered ? Colors.hoverItemHovered : "transparent"
        border.color: hoverHandler.hovered || tapHandler.pressed ? Colors.pillBorder : "transparent"
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
