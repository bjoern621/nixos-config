import QtQuick
import "../"

Text {
    id: root

    property bool expanded: false

    text: "\uf078"
    font.family: Typography.iconFontFamily
    font.pixelSize: Typography.fontSize12
    color: Colors.textColorMuted

    rotation: expanded ? 180 : 0
    Behavior on rotation {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
}
