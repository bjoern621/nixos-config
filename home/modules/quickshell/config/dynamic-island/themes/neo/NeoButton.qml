import QtQuick
import "../../"

// Neobrutalist block button: bordered, cream fill, hover shade, accent option.
// Interaction (hover/press/click/squish) comes from Pressable.
Pressable {
    id: root

    property string iconSource: ""
    property alias label: txt.text
    property bool accent: false
    property real radius: 5
    property int iconSize: Typography.fontSize20

    pressedScale: 0.96

    ButtonBg {
        active: root.accent
        hovered: root.hovered
        pressed: root.pressed

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            spacing: 10

            TintedIcon {
                visible: root.iconSource !== ""
                source: root.iconSource
                size: root.iconSize
                color: NeoTokens.ink
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: txt
                anchors.verticalCenter: parent.verticalCenter
                color: NeoTokens.ink
                font.family: Typography.fontFamily
                font.pixelSize: Typography.fontSize12
                font.weight: Font.ExtraBold
            }
        }
    }
}
