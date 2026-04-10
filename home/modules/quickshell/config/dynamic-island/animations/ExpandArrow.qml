import QtQuick

Text {
    id: root

    property bool expanded: false
    property alias iconSize: root.font.pixelSize
    property alias iconColor: root.color
    property alias iconWeight: root.font.weight

    text: "\uf078"
    font.family: Typography.iconFontFamily
    font.pixelSize: Typography.fontSize12
    font.weight: Font.Normal
    color: Colors.textColorMuted

    rotation: expanded ? 180 : 0
    Behavior on rotation {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
}
