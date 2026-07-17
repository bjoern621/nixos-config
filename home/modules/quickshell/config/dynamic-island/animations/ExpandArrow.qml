import QtQuick
// Root qmldir, not "../base".
// animations/qmldir declares only Colors, Typography and Spacing, so
// SquishBehavior and TintedIcon resolve from here.
import "../"

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
    SquishBehavior on rotation {
        duration: 200
    }
}
