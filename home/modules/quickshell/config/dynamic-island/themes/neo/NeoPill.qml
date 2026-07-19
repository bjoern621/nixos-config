import QtQuick
import "../../"

// Small accent keycap with a hard offset shadow (the launcher's ↵ / Esc pills).
Item {
    id: root

    property alias text: key.text
    property color fill: NeoTokens.accentColor
    property int offset: 2

    implicitWidth: pill.implicitWidth + offset
    implicitHeight: pill.implicitHeight + offset

    Rectangle {
        x: root.offset
        y: root.offset
        width: pill.implicitWidth
        height: pill.implicitHeight
        radius: 3
        color: NeoTokens.ink
    }

    Rectangle {
        id: pill
        radius: 3
        color: root.fill
        border.width: NeoTokens.thinBorderWidth
        border.color: NeoTokens.ink
        implicitWidth: Math.max(22, key.implicitWidth + 14)
        implicitHeight: 22

        Text {
            id: key
            anchors.centerIn: parent
            color: NeoTokens.ink
            font.family: Typography.fontFamily
            font.pixelSize: Typography.fontSize12
            font.weight: Font.Black
        }
    }
}
