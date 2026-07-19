import QtQuick
import "../"
import "../base"

// Popup card: icon, title, message, dismiss button.
// Content only: emits dismissed(), the parent owns visibility and every reaction to it.
// ModalOverlay wraps this in a PopReveal.
Item {
    id: root

    property url iconSource: ""
    property string title: ""
    property string message: ""
    property color accentColor: Colors.textColor
    property string dismissText: "Verstanden"

    signal dismissed

    implicitWidth: 340
    implicitHeight: panel.implicitHeight

    // Neo hard offset shadow behind the panel. No-op in classic (offset 0).
    Rectangle {
        visible: !Shape.usesBlur
        x: Shape.shadowOffset
        y: Shape.shadowOffset
        width: panel.width
        height: panel.height
        radius: panel.radius
        color: NeoTokens.ink
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        implicitHeight: content.implicitHeight + 2 * Spacing.spacing16

        radius: Shape.cardRadius
        color: Colors.pillBackground
        border.width: Shape.usesBlur ? 1 : Shape.borderWidth
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
                radius: Shape.pill(height)
                color: dismissTap.pressed ? Colors.hoverItemPressed : dismissHover.hovered ? Colors.hoverItemHovered : "transparent"
                border.width: Shape.usesBlur ? 1 : Shape.thinBorderWidth
                border.color: Colors.pillBorder

                scale: dismissTap.pressed ? 0.96 : 1.0
                SquishBehavior on scale {}

                Text {
                    id: dismissLabel
                    text: root.dismissText
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
