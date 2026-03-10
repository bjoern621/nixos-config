import Quickshell
import Quickshell.Services.Pipewire
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

        implicitHeight: 96

        property bool volumeMenuOpen: false
        property bool sliderShouldShow: volumeHoverItem.hovered || volumeSliderMenu.keepOpen

        onSliderShouldShowChanged: {
            if (sliderShouldShow) {
                sliderHideTimer.stop()
                if (!volumeMenuOpen) {
                    volumeMenuOpen = true
                    menuHeight = volumeSliderMenu.implicitHeight + 8
                    volumeSliderMenu.show()
                }
            } else {
                sliderHideTimer.restart()
            }
        }

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
                        id: volumeHoverItem
                        VolumeIcon {
                            id: volumeIcon
                        }
                        onClicked: {
                            console.log("Volume icon clicked");
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
                y: pill.y + pill.implicitHeight + 4
            }

            VolumeSliderMenu {
                id: volumeSliderMenu
                width: 200
                anchors.top: volumeAnchor.top
                anchors.horizontalCenter: volumeAnchor.horizontalCenter
            }
        }
        Timer {
            id: hideTimer
            interval: 100
            onTriggered: {
                if (root.volumeMenuOpen || volumeSliderMenu.sliderActive) return
                root.isHovered = false
                slideIn.stop()
                slideOut.start()
            }
        }

        Timer {
            id: sliderHideTimer
            interval: 200
            onTriggered: {
                root.volumeMenuOpen = false
                volumeSliderMenu.hide()
            }
        }

        Connections {
            target: volumeSliderMenu
            function onHidden() {
                root.menuHeight = 0
                if (!zoneHover.hovered)
                    hideTimer.restart()
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
