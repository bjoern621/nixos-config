import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import "../"

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
        property bool pillHidden: true

        // MPRIS player lookup: prefer playing, fall back to paused
        readonly property var mprisPlayer: {
            const players = Mpris.players.values;
            let paused = null;
            for (let i = 0; i < players.length; i++) {
                const p = players[i];
                if (p.playbackState === MprisPlaybackState.Playing)
                    return p;
                if (!paused && p.playbackState === MprisPlaybackState.Paused)
                    paused = p;
            }
            return paused;
        }
        readonly property bool hasMprisPlayer: mprisPlayer !== null

        implicitHeight: !pillHidden ? 1000 : Spacing.spacing8

        mask: Region {
            item: interactionZone
        }

        readonly property bool shouldShowPill: zoneHover.hovered || nowPlayingHoverItem.menuOpen || volumeHoverItem.menuOpen || calendarHoverItem.menuOpen || batteryHoverItem.menuOpen || systemTray.menuVisible || Globals.launcherVisible

        onShouldShowPillChanged: {
            if (shouldShowPill) {
                pillHideTimer.stop();
                pillHidden = false;
                if (!isHovered) {
                    isHovered = true;
                    slideOut.stop();
                    slideIn.start();
                }
            } else {
                pillHideTimer.restart();
            }
        }

        Item {
            id: interactionZone
            width: Math.max(pill.implicitWidth + Spacing.spacing24, nowPlayingHoverItem.menuOpen ? nowPlayingView.implicitWidth + 2 * Spacing.spacing24 : 0, volumeHoverItem.menuOpen ? volumeSlider.implicitWidth + 2 * Spacing.spacing24 : 0, calendarHoverItem.menuOpen ? calendarView.implicitWidth + 2 * Spacing.spacing24 : 0, systemTray.menuVisible ? systemTray.menuContentWidth + 2 * Spacing.spacing24 : 0)
            x: (root.width - width) / 2
            height: root.isHovered ? 44 + Math.max(nowPlayingHoverItem.menuHeight, volumeHoverItem.menuHeight, calendarHoverItem.menuHeight, batteryHoverItem.menuHeight, systemTray.menuVisible ? systemTray.menuContentHeight + Spacing.spacing12 : 0) + ((nowPlayingHoverItem.menuOpen || volumeHoverItem.menuOpen || calendarHoverItem.menuOpen || batteryHoverItem.menuOpen || systemTray.menuVisible) ? Spacing.spacing8 : 0) : Spacing.spacing8
            anchors.top: parent.top

            HoverHandler {
                id: zoneHover
            }

            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: -implicitHeight - Spacing.spacing8

                implicitWidth: contentRow.implicitWidth + Spacing.spacing24
                implicitHeight: 32

                radius: implicitHeight / 2
                color: Colors.pillBackground

                border.width: 1
                border.color: Colors.pillBorder

                Row {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: Spacing.spacing8

                    WorkspaceIndicator {
                        monitorName: root.modelData.name
                    }

                    Rectangle {
                        visible: root.hasMprisPlayer
                        width: 1
                        height: Spacing.spacing16
                        color: Colors.separatorColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    HoverItem {
                        id: nowPlayingHoverItem
                        visible: root.hasMprisPlayer
                        menu: nowPlayingMenu
                        onClicked: {
                            if (root.mprisPlayer)
                                root.mprisPlayer.togglePlaying();
                        }
                        NowPlaying {
                            id: nowPlaying
                            player: root.mprisPlayer
                        }
                    }

                    Rectangle {
                        width: 1
                        height: Spacing.spacing16
                        color: Colors.separatorColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    SystemTray {
                        id: systemTray
                        panelWindow: root
                        menuParent: interactionZone
                        menuTopY: pill.y + pill.implicitHeight + Spacing.spacing4
                    }

                    Rectangle {
                        width: 1
                        height: Spacing.spacing16
                        color: Colors.separatorColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    HoverItem {
                        id: calendarHoverItem
                        clickable: false
                        menu: calendarMenu
                        DateTime {}
                    }

                    Rectangle {
                        width: 1
                        height: Spacing.spacing16
                        color: Colors.separatorColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    HoverItem {
                        id: volumeHoverItem
                        clickable: false
                        menu: volumeMenu
                        onMenuOpenChanged: {
                            Globals.volumeSliderOpen = menuOpen;
                        }
                        VolumeIcon {
                            id: volumeIcon
                        }
                    }

                    Rectangle {
                        width: 1
                        height: Spacing.spacing16
                        color: Colors.separatorColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    HoverItem {
                        id: batteryHoverItem
                        clickable: false
                        menu: batteryMenu
                        Battery {}
                    }
                }
            }

            Item {
                id: nowPlayingAnchor
                width: 0
                height: 0
                x: pill.x + (pill.implicitWidth - contentRow.implicitWidth) / 2 + nowPlayingHoverItem.x + nowPlayingHoverItem.width / 2
                y: pill.y + pill.implicitHeight
            }

            HoverMenu {
                id: nowPlayingMenu
                width: nowPlayingView.implicitWidth
                anchors.top: nowPlayingAnchor.top
                anchors.horizontalCenter: nowPlayingAnchor.horizontalCenter

                NowPlayingMenu {
                    id: nowPlayingView
                    width: implicitWidth
                    height: implicitHeight
                    player: root.mprisPlayer
                }
            }

            Item {
                id: volumeAnchor
                width: 0
                height: 0
                x: pill.x + (pill.implicitWidth - contentRow.implicitWidth) / 2 + volumeHoverItem.x + volumeHoverItem.width / 2
                y: pill.y + pill.implicitHeight
            }

            HoverMenu {
                id: volumeMenu
                width: volumeSlider.implicitWidth
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
                width: 0
                height: 0
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

            Item {
                id: batteryAnchor
                width: 0
                height: 0
                x: pill.x + (pill.implicitWidth - contentRow.implicitWidth) / 2 + batteryHoverItem.x + batteryHoverItem.width / 2
                y: pill.y + pill.implicitHeight
            }

            HoverMenu {
                id: batteryMenu
                width: batteryView.implicitWidth
                anchors.top: batteryAnchor.top
                anchors.horizontalCenter: batteryAnchor.horizontalCenter

                BatteryMenu {
                    id: batteryView
                    width: implicitWidth
                    height: implicitHeight
                }
            }
        }

        Timer {
            id: pillHideTimer
            interval: 100
            onTriggered: {
                if (root.shouldShowPill)
                    return;
                root.isHovered = false;
                slideIn.stop();
                slideOut.start();
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
            onFinished: root.pillHidden = true
        }
    }
}
