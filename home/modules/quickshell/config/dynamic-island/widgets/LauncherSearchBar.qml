import QtQuick
import "../base"

// Read-only search bar used inside LauncherWindow. Keystrokes are captured by
// the parent window (no TextInput/TextEdit). Just renders the current value.
Rectangle {
    id: root
    property string text: ""
    property string placeholder: "Suchen..."
    property bool accent: true

    radius: Spacing.spacing8
    color: Colors.hoverItemHovered
    border.width: 1
    border.color: accent ? Colors.accentColor : Colors.pillBorder

    TintedIcon {
        id: searchIcon
        source: "../icons/icons8-search.svg"
        size: Typography.fontSize14
        color: Colors.textColorMuted
        anchors.left: parent.left
        anchors.leftMargin: Spacing.spacing12
        anchors.verticalCenter: parent.verticalCenter
    }

    Label {
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
}
