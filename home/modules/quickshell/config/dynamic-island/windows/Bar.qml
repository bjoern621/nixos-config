import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
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

        implicitHeight: !pillHidden ? 1000 : 0

        // Aggregate over direct children of contentRow; each child manages its own popup
        // (including any submenus nested inside that popup's outer Item).
        readonly property bool anyPopupOpen: {
            for (const c of contentRow.children) if (c.popupOpen) return true;
            return false;
        }
        readonly property real maxPopupWidth: {
            let m = 0;
            for (const c of contentRow.children)
                if (c.popupOpen && c.popupItem) m = Math.max(m, c.popupItem.width);
            return m;
        }
        readonly property real maxPopupHeight: {
            let m = 0;
            for (const c of contentRow.children)
                if (c.popupOpen && c.popupItem) m = Math.max(m, c.popupItem.height);
            return m;
        }

        // Input region = trigger strip / pill area + each visible popup's own region.
        // Each child's popupItem already absorbs its descendants (submenus, bridges) inside
        // its bounding box, so Bar references only direct children. Closed popups have
        // visible: false and contribute nothing.
        mask: Region {
            Region { item: interactionZone }
            Region { item: nowPlayingHoverItem.popupItem }
            Region { item: calendarHoverItem.popupItem }
            Region { item: systemTray.popupItem }
            Region { item: volumeHoverItem.popupItem }
            Region { item: batteryHoverItem.popupItem }
        }

        readonly property bool shouldShowPill: zoneHover.hovered || anyPopupOpen || Globals.launcherVisible

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

        // interactionZone is the trigger strip + pill hit area. Open popups are NOT
        // included in its bounds — they're added to the input mask as separate
        // Region entries, so the hitbox matches the visible shape.
        Item {
            id: interactionZone
            width: pill.implicitWidth
            x: (root.width - width) / 2
            height: root.isHovered ? 44 : Spacing.spacing8
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
                        pressedScale: 0.96
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

                    HoverItem {
                        id: calendarHoverItem
                        clickable: true
                        pressedScale: 0.96
                        menuOnClick: true
                        menu: calendarMenu
                        DateTime {}
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
                        id: volumeHoverItem
                        clickable: true
                        menu: volumeMenu
                        onPopupOpenChanged: {
                            Globals.volumeSliderOpen = popupOpen;
                        }
                        onClicked: {
                            if (Pipewire.defaultAudioSink?.audio)
                                Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
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
                onHidden: volumeSlider.outputExpanded = false

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
