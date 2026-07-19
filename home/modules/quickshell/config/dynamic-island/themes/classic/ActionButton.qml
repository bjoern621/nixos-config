import QtQuick
import "../../"

// Classic pill button: transparent idle, accent tint on hover/press, icon + label.
// Interaction (hover/press/click/squish) comes from Pressable.
Pressable {
    id: root

    property string iconSource: ""
    property alias label: txt.text
    property int iconSize: Typography.fontSize20

    pressedScale: 0.96

    ButtonBg {
        hovered: root.hovered
        pressed: root.pressed

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: Spacing.spacing12
            spacing: Spacing.spacing8

            TintedIcon {
                visible: root.iconSource !== ""
                source: root.iconSource
                size: root.iconSize
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: txt
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.textColor
                font.family: Typography.fontFamily
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Bold
            }
        }
    }
}
