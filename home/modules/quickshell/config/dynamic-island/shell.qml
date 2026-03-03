import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick

ShellRoot {
    PanelWindow {
        id: root

        anchors {
            top: true
            left: true
            right: true
        }

        exclusiveZone: 0
        color: "transparent"

        implicitHeight: 48

        property bool isHovered: false

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: {
                if (containsMouse) {
                    root.isHovered = true
                    slideIn.start()
                } else {
                    root.isHovered = false
                    slideOut.start()
                }
            }
        }

        NumberAnimation {
            id: slideIn
            target: pill
            property: "y"
            from: -pill.implicitHeight - 8
            to: 4
            duration: 200
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: slideOut
            target: pill
            property: "y"
            from: 4
            to: -pill.implicitHeight - 8
            duration: 200
            easing.type: Easing.OutCubic
        }

        Rectangle {
            id: pill
            x: (root.width - implicitWidth) / 2
            y: -implicitHeight - 8

            implicitWidth: contentRow.implicitWidth + 24
            implicitHeight: 32

            radius: implicitHeight / 2
            color: Qt.rgba(0.07, 0.07, 0.07, 0.7)

            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: 12

                // Workspace indicator
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "\uf108"
                        font.family: "Font Awesome 7 Free Solid"
                        font.pixelSize: 13
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: {
                            var monitor = Hyprland.focusedMonitor
                            if (monitor && monitor.activeWorkspace) {
                                return monitor.activeWorkspace.id
                            }
                            return 1
                        }
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Separator
                Rectangle {
                    width: 1
                    height: 16
                    color: Qt.rgba(1, 1, 1, 0.2)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Tray icons - SystemTray is a singleton, access via SystemTray.items
                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: SystemTray.items

                        Rectangle {
                            width: 20
                            height: 20
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                source: modelData.icon
                                width: 16
                                height: 16
                                anchors.centerIn: parent
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        modelData.activate()
                                    } else {
                                        modelData.showMenu()
                                    }
                                }
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    width: 1
                    height: 16
                    color: Qt.rgba(1, 1, 1, 0.2)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "\uf017"
                    font.family: "Font Awesome 7 Free Solid"
                    font.pixelSize: 13
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // DateTime inline
                Text {
                    id: clock
                    text: Qt.formatDateTime(new Date(), "ddd MMM d  hh:mm AP")
                    font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter

                    Timer {
                        interval: 1000
                        repeat: true
                        running: true
                        onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd MMM d  hh:mm AP")
                    }
                }
            }
        }
    }
}
