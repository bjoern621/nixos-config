import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root
        required property var modelData
        screen: modelData

        anchors {
            top: true
            left: true
            right: true
        }

        exclusiveZone: 0
        color: "transparent"

        property bool isHovered: false

        implicitHeight: 1000

        mask: Region {
            item: interactionZone
        }

        readonly property bool shouldShowPill: zoneHover.hovered || volumeHoverItem.menuOpen || calendarHoverItem.menuOpen

        onShouldShowPillChanged: {
            if (shouldShowPill) {
                pillHideTimer.stop()
                if (!isHovered) {
                    isHovered = true
                    slideOut.stop()
                    slideIn.start()
                }
            } else {
                pillHideTimer.restart()
            }
        }

        Item {
            id: interactionZone
            width: Math.max(pill.implicitWidth + 24, calendarHoverItem.menuOpen ? calendarView.implicitWidth + 48 : 0)
            x: (root.width - width) / 2
            height: root.isHovered ? 44 + Math.max(volumeHoverItem.menuHeight, calendarHoverItem.menuHeight) + ((volumeHoverItem.menuOpen || calendarHoverItem.menuOpen) ? 8 : 0) : 8
            anchors.top: parent.top

            HoverHandler {
                id: zoneHover
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
                        WorkspaceIndicator {
                            monitorName: root.modelData.name
                        }
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
                        id: calendarHoverItem
                        menu: calendarMenu
                        DateTime {}
                    }

                    Rectangle {
                        width: 1
                        height: 16
                        color: Colors.separatorColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    HoverItem {
                        id: volumeHoverItem
                        menu: volumeMenu
                        onMenuOpenChanged: {
                            Globals.volumeSliderOpen = menuOpen
                        }
                        VolumeIcon {
                            id: volumeIcon
                        }
                        onClicked: {
                            const sink = Pipewire.defaultAudioSink;
                            if (sink) {
                                sink.audio.muted = !sink.audio.muted;
                            }
                        }
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

            Item {
                id: volumeAnchor
                width: 0; height: 0
                x: pill.x + (pill.implicitWidth - contentRow.implicitWidth) / 2 + volumeHoverItem.x + volumeHoverItem.width / 2
                y: pill.y + pill.implicitHeight
            }

            HoverMenu {
                id: volumeMenu
                width: 200
                anchors.top: volumeAnchor.top
                anchors.horizontalCenter: volumeAnchor.horizontalCenter
                contentInteracting: volumeSlider.sliderActive

                VolumeSliderMenu {
                    id: volumeSlider
                    width: parent ? parent.width : 0
                    height: implicitHeight
                }
            }

            Item {
                id: calendarAnchor
                width: 0; height: 0
                x: pill.x + (pill.implicitWidth - contentRow.implicitWidth) / 2 + calendarHoverItem.x + calendarHoverItem.width / 2
                y: pill.y + pill.implicitHeight
            }

            HoverMenu {
                id: calendarMenu
                width: calendarView.implicitWidth
                anchors.top: calendarAnchor.top
                anchors.horizontalCenter: calendarAnchor.horizontalCenter

                CalendarMenu {
                    id: calendarView
                    width: implicitWidth
                    height: implicitHeight
                }
            }
        }

        Timer {
            id: pillHideTimer
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
}
