import QtQuick
import Quickshell

Item {
    id: root

    implicitWidth: row.implicitWidth + 2 * contentPadding
    implicitHeight: row.implicitHeight + 2 * contentPadding

    readonly property int contentPadding: 16
    readonly property int buttonSize: 64
    readonly property int iconSize: 20

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
        radius: 12
        color: Colors.pillBackground
        border.width: 1
        border.color: Colors.pillBorder

        Row {
            id: row
            x: root.contentPadding
            y: root.contentPadding
            spacing: root.contentPadding

            Repeater {
                model: [
                    { action: "shutdown", icon: "\uf011", label: "Shutdown" },
                    { action: "reboot", icon: "\uf0e2", label: "Reboot" },
                    { action: "lock", icon: "\uf023", label: "Lock" },
                    { action: "hibernate", icon: "\uf2dc", label: "Hibernate" }
                ]

                Item {
                    width: root.buttonSize
                    height: root.buttonSize

                    Rectangle {
                        anchors.fill: parent
                        radius: Spacing.spacing8
                        color: buttonHoverHandler.hovered ? Colors.hoverItemHovered
                             : buttonTapHandler.pressed ? Colors.hoverItemPressed
                             : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }
                    }

                    HoverHandler {
                        id: buttonHoverHandler
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: buttonTapHandler
                        onTapped: root.triggerAction(modelData.action)
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: modelData.icon
                            font.family: Typography.iconFontFamily
                            font.pixelSize: root.iconSize
                            color: Colors.textColor
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: modelData.label
                            font.family: Typography.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: Typography.fontSize12
                            color: Colors.textColor
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }
}
