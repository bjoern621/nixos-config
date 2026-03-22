import QtQuick
import Quickshell
import "../"
import "../animations"

Item {
    id: root

    implicitWidth: col.implicitWidth + 2 * contentPadding
    implicitHeight: col.implicitHeight + 2 * contentPadding

    readonly property int contentPadding: Spacing.spacing8
    readonly property int buttonWidth: 140
    readonly property int buttonHeight: 36
    function triggerAction(action) {
        Qt.callLater(() => {
            switch (action) {
                case "shutdown":
                    Quickshell.execDetached(["systemctl", "poweroff"])
                    break
                case "reboot":
                    Quickshell.execDetached(["systemctl", "reboot"])
                    break
                case "lock":
                    Quickshell.execDetached(["loginctl", "lock-session"])
                    break
                case "hibernate":
                    Quickshell.execDetached(["systemctl", "hibernate"])
                    break
            }
        })
    }

    Rectangle {
        anchors.fill: parent
        radius: Spacing.spacing12
        color: Colors.pillBackground
        border.width: 1
        border.color: Colors.pillBorder

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: root.contentPadding
            spacing: Spacing.spacing4

            Repeater {
                model: [
                    { action: "shutdown", icon: "\uf011", label: "Shutdown" },
                    { action: "reboot", icon: "\uf0e2", label: "Reboot" },
                    { action: "lock", icon: "\uf023", label: "Lock" },
                    { action: "hibernate", icon: "\uf2dc", label: "Hibernate" }
                ]

                Item {
                    width: root.buttonWidth
                    height: root.buttonHeight
                    scale: buttonTapHandler.pressed ? 0.96 : 1.0

                    SquishBehavior on scale {}

                    Rectangle {
                        anchors.fill: parent
                        radius: Spacing.spacing8
                        color: buttonTapHandler.pressed ? Colors.hoverItemPressed
                             : buttonHoverHandler.hovered ? Colors.hoverItemHovered
                             : "transparent"
                        border.color: buttonHoverHandler.hovered || buttonTapHandler.pressed ? Colors.pillBorder : "transparent"
                    }

                    HoverHandler {
                        id: buttonHoverHandler
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: buttonTapHandler
                        onTapped: root.triggerAction(modelData.action)
                    }

                    Row {
                        id: rowLayout
                        anchors.verticalCenter: parent.verticalCenter
                        x: Spacing.spacing12
                        spacing: Spacing.spacing8

                        Text {
                            text: modelData.icon
                            font.family: Typography.iconFontFamily
                            font.pixelSize: Typography.fontSize16
                            color: Colors.textColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: modelData.label
                            font.family: Typography.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: Typography.fontSize12
                            color: Colors.textColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
