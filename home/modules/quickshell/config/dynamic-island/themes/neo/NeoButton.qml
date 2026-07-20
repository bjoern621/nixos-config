import QtQuick
import "../../"

// Neobrutalist block button: bordered cream face over a hard ink offset shadow.
// width/height = total footprint; the face is inset by shadowOffset.
// Rest: face top-left, full shadow bottom-right. Hover: face nudges toward the
// shadow. Press: face slides fully onto the shadow, covering it (the "pressed in"
// look). Translate replaces Pressable's squish-scale, so pressedScale is 1.
Pressable {
    id: root

    property string iconSource: ""
    property alias label: txt.text
    property bool accent: false
    property int iconSize: Typography.fontSize20

    readonly property int shadowOffset: NeoTokens.shadowOffset
    readonly property real faceWidth: width - shadowOffset
    readonly property real faceHeight: height - shadowOffset

    pressedScale: 1.0

    // Face travel toward the shadow: 0 at rest, a nudge on hover, full on press.
    property real faceOffset: pressed ? shadowOffset
        : hovered ? Math.round(shadowOffset * 0.4)
        : 0
    SquishBehavior on faceOffset { duration: 90 }

    Rectangle {
        x: root.shadowOffset
        y: root.shadowOffset
        width: root.faceWidth
        height: root.faceHeight
        radius: NeoTokens.pillRadius
        color: NeoTokens.ink
    }

    ButtonBg {
        anchors.fill: undefined
        x: root.faceOffset
        y: root.faceOffset
        width: root.faceWidth
        height: root.faceHeight

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
