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
                GracefulShutdown.start("Herunterfahren...", ["systemctl", "poweroff"]);
                break;
            case "reboot":
                GracefulShutdown.start("Neustarten...", ["systemctl", "reboot"]);
                break;
            case "lock":
                LoadingHost.show("Sperren...");
                Quickshell.execDetached(["loginctl", "lock-session"]);
                break;
            case "hibernate":
                LoadingHost.show("Hibernieren...");
                Quickshell.execDetached(["systemctl", "hibernate"]);
                break;
            case "logout":
                GracefulShutdown.start("Abmelden...", ["hyprctl", "dispatch", "exit"]);
                break;
            }
        });
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

            Repeater {
                model: [
                    {
                        action: "shutdown",
                        icon: "\uf011",
                        label: "Shutdown"
                    },
                    {
                        action: "reboot",
                        icon: "\uf0e2",
                        label: "Reboot"
                    },
                    {
                        action: "lock",
                        icon: "\uf023",
                        label: "Lock"
                    },
                    {
                        action: "logout",
                        icon: "\uf2f5",
                        label: "Logout"
                    },
                    {
                        action: "hibernate",
                        icon: "\uf2dc",
                        label: "Hibernate"
                    },
                ]

                Item {
                    width: root.buttonWidth
                    height: root.buttonHeight
                    scale: buttonTapHandler.pressed ? 0.96 : 1.0

                    SquishBehavior on scale {}

                    Rectangle {
                        anchors.fill: parent
                        radius: Spacing.spacing8
                        color: buttonTapHandler.pressed ? Colors.hoverItemPressed : buttonHoverHandler.hovered ? Colors.hoverItemHovered : "transparent"
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

                        Icon {
                            text: modelData.icon
                            font.pixelSize: Typography.fontSize16
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
