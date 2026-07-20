import QtQuick
import "../base"

// Read-only search bar for LauncherPanel.
// No TextInput/TextEdit: LauncherPanel's Keys handler captures keystrokes.
// Classic: rounded accent-bordered box.
// Neo: 1:1 with the AppLauncherNeo header (drawn magnifier ring, Inter 15
// ExtraBold, ink text over muted placeholder, steady block cursor). LauncherPanel
// places it flush and draws the full-bleed ink divider beneath it.
Rectangle {
    id: root
    property string text: ""
    property string placeholder: "Suchen..."
    property bool accent: true

    readonly property bool neo: !Shape.usesBlur

    // Header font, matching AppLauncherNeo. 15 is not a Typography step.
    readonly property int neoFontSize: 15

    radius: Spacing.spacing8
    color: root.neo ? "transparent" : Colors.hoverItemHovered
    border.width: root.neo ? 0 : 1
    border.color: root.accent ? Colors.accentColor : Colors.pillBorder

    // Classic: svg search icon.
    TintedIcon {
        visible: !root.neo
        id: searchIcon
        source: "../icons/icons8-search.svg"
        size: Typography.fontSize14
        color: Colors.textColorMuted
        anchors.left: parent.left
        anchors.leftMargin: Spacing.spacing12
        anchors.verticalCenter: parent.verticalCenter
    }

    // Neo: hand-drawn magnifier ring + handle, identical to AppLauncherNeo.
    Item {
        id: mag
        visible: root.neo
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

    // Classic: single label, text or placeholder.
    Label {
        visible: !root.neo
        anchors.left: searchIcon.right
        anchors.leftMargin: Spacing.spacing8
        anchors.right: parent.right
        anchors.rightMargin: Spacing.spacing12
        anchors.verticalCenter: parent.verticalCenter
        color: root.text ? Colors.textColor : Colors.textColorMuted
        clip: true
        font.weight: Font.Medium
        text: root.text || root.placeholder
        verticalAlignment: Text.AlignVCenter
    }

    // Neo: placeholder when empty, else text + steady ink block cursor (no blink).
    Item {
        visible: root.neo
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
            font.pixelSize: root.neoFontSize
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
                font.pixelSize: root.neoFontSize
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
