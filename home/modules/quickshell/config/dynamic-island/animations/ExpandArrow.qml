import QtQuick
import "../"
import "../base"

Item {
    id: root

    property bool expanded: false
    property int collapsedRotation: 180
    property int expandedRotation: 0
    property int iconSize: Typography.fontSize12
    property color iconColor: Colors.textColorMuted

    implicitWidth: icon.width
    implicitHeight: icon.height

    TintedIcon {
        id: icon
        anchors.centerIn: parent
        source: "../icons/icons8-arrow-down.svg"
        size: root.iconSize
        color: root.iconColor
    }

    rotation: expanded ? expandedRotation : collapsedRotation
    Behavior on rotation {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
}
