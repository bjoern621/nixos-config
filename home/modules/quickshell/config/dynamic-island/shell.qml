import Quickshell
import QtQuick

ShellRoot {
    ScreenCorners {}

    PanelWindow {
        id: root

        anchors {
            top: true
            left: true
            right: true
        }

        exclusiveZone: 0
        color: "transparent"

        property bool isHovered: false
        property real menuHeight: 0

        implicitHeight: 44 + menuHeight

        mask: Region {
            item: interactionZone
        }

        Item {
            id: interactionZone
            width: pill.implicitWidth + 24
            x: (root.width - width) / 2
            height: root.isHovered ? 44 + root.menuHeight : 8
            anchors.top: parent.top

            HoverHandler {
                id: zoneHover
                onHoveredChanged: {
                    if (hovered) {
                        hideTimer.stop()
                        if (!root.isHovered) {
                            root.isHovered = true
                            slideOut.stop()
                            slideIn.start()
                        }
                    } else {
                        hideTimer.restart()
                    }
                }
            }

            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: -implicitHeight - 8

                implicitWidth: contentRow.implicitWidth + 24
                implicitHeight: 32

                radius: implicitHeight / 2
                color: Colors.pillBackground

                border.width: 1
                border.color: Colors.pillBorder

                Row {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: 8

                    HoverItem {
                        WorkspaceIndicator {}
                    }

                    Rectangle {
                        width: 1
                        height: 16
                        color: Colors.separatorColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    HoverItem {
                        SystemTray {}
                    }

                    Rectangle {
                        width: 1
                        height: 16
                        color: Colors.separatorColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    HoverItem {
                        DateTime {}
                    }

                    Rectangle {
                        width: 1
                        height: 16
                        color: Colors.separatorColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    HoverItem {
                        VolumeIcon {}
                    }

                    Rectangle {
                        width: 1
                        height: 16
                        color: Colors.separatorColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    HoverItem {
                        Battery {}
                    }

                }
            }
        }
        Timer {
            id: hideTimer
            interval: 100
            onTriggered: {
                root.isHovered = false
                slideIn.stop()
                slideOut.start()
            }
        }

        NumberAnimation {
            id: slideIn
            target: pill
            property: "y"
            to: 4
            duration: 200
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: slideOut
            target: pill
            property: "y"
            to: -pill.implicitHeight - 8
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    VolumeOsd {}
    BrightnessOsd {}
}
