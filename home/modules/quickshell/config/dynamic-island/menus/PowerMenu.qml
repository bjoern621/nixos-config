import QtQuick
import Quickshell
import "../"
import "../base"
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
                GracefulShutdown.start("Herunterfahren...", ["systemctl", "--no-wall", "poweroff"]);
                break;
            case "reboot":
                GracefulShutdown.start("Neustarten...", ["systemctl", "--no-wall", "reboot"]);
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
                        iconSource: "../icons/icons8-shutdown.svg",
                        label: "Shutdown"
                    },
                    {
                        action: "reboot",
                        iconSource: "../icons/icons8-restart.svg",
                        label: "Reboot"
                    },
                    {
                        action: "lock",
                        iconSource: "../icons/icons8-lock.svg",
                        label: "Lock"
                    },
                    {
                        action: "logout",
                        iconSource: "../icons/icons8-log-out.svg",
                        label: "Logout"
                    },
                    {
                        action: "hibernate",
                        iconSource: "../icons/icons8-sleep.svg",
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

                        TintedIcon {
                            source: modelData.iconSource
                            size: Typography.fontSize20
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
