import QtQuick
import "../base"

// Read-only search bar for LauncherPanel.
// No TextInput/TextEdit: LauncherPanel's Keys handler captures keystrokes.
// 1:1 with the AppLauncherNeo header (drawn magnifier ring, Inter 15 ExtraBold,
// ink text over muted placeholder, steady block cursor). LauncherPanel
// places it flush and draws the full-bleed ink divider beneath it.
Item {
    id: root
    property string text: ""
    property string placeholder: "Suchen..."

    // Header font, matching AppLauncherNeo. 15 is not a Typography step.
    readonly property int headerFontSize: 15

    // Hand-drawn magnifier ring + handle, identical to AppLauncherNeo.
    Item {
        id: mag
        width: 16
        height: 16
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            id: magRing
            width: 11
            height: 11
            radius: 5.5
            color: "transparent"
            border.width: 2
            border.color: Colors.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }
        Rectangle {
            width: 5
            height: 2
            radius: 1
            color: Colors.textColor
            x: magRing.x + magRing.width - 1
            y: magRing.y + magRing.height - 1
            rotation: 45
            transformOrigin: Item.TopLeft
        }
    }

    // Placeholder when empty, else text + steady ink block cursor (no blink).
    Item {
        anchors.left: mag.right
        anchors.leftMargin: Spacing.spacing12
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        height: 24
        clip: true

        Text {
            visible: root.text === ""
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: Colors.placeholder
            font.family: Typography.fontFamily
            font.pixelSize: root.headerFontSize
            font.weight: Font.ExtraBold
        }

        Row {
            visible: root.text !== ""
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: Colors.textColor
                font.family: Typography.fontFamily
                font.pixelSize: root.headerFontSize
                font.weight: Font.ExtraBold
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 9
                height: 18
                color: Colors.textColor
            }
        }
    }
}
