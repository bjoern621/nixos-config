import QtQuick
import "../"
import "../base"

// Reusable dismissable popup card. Parent controls visibility via show()/hide().
// Properties: icon, title, message, accentColor.
Item {
    id: root

    property url iconSource: ""
    property string title: ""
    property string message: ""
    property color accentColor: Colors.textColor

    signal dismissed

    implicitWidth: 340
    implicitHeight: panel.implicitHeight

    Rectangle {
        id: panel
        anchors.fill: parent
        implicitHeight: content.implicitHeight + 2 * Spacing.spacing16

        radius: Spacing.spacing12
        color: Colors.pillBackground
        border.width: 1
        border.color: Colors.pillBorder
    }

    Column {
        id: content
        anchors {
            fill: parent
            margins: Spacing.spacing16
        }
        spacing: Spacing.spacing12

        TintedIcon {
            source: root.iconSource
            size: 40
            color: root.accentColor
            anchors.horizontalCenter: parent.horizontalCenter
            visible: source !== ""
        }

        Text {
            text: root.title
            font.family: Typography.fontFamily
            font.pixelSize: Typography.fontSize16
            font.weight: Font.Bold
            color: root.accentColor
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
        }

        Text {
            text: root.message
            font.family: Typography.fontFamily
            font.pixelSize: Typography.fontSize14
            font.weight: Font.Normal
            color: Colors.textColor
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.WordWrap
            visible: text !== ""
        }

        Item {
            width: parent.width
            height: dismissBtn.height

            Rectangle {
                id: dismissBtn
                anchors.horizontalCenter: parent.horizontalCenter
                width: dismissLabel.implicitWidth + 2 * Spacing.spacing16
                height: 36
                radius: height / 2
                color: dismissTap.pressed ? Colors.hoverItemPressed : dismissHover.hovered ? Colors.hoverItemHovered : "transparent"
                border.width: 1
                border.color: Colors.pillBorder

                scale: dismissTap.pressed ? 0.96 : 1.0
                SquishBehavior on scale {}

                Text {
                    id: dismissLabel
                    text: "Verstanden"
                    font.family: Typography.fontFamily
                    font.pixelSize: Typography.fontSize14
                    font.weight: Font.Bold
                    color: Colors.textColor
                    anchors.centerIn: parent
                }

                HoverHandler {
                    id: dismissHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: dismissTap
                    onTapped: root.dismissed()
                }
            }
        }
    }
}
