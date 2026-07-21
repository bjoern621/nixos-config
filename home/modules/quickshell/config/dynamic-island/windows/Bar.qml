import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
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

        // Bar is hover-only. It grabs the keyboard solely while the network menu's
        // password field is up, then releases it. Per-screen: only the Bar whose
        // menu is prompting claims focus.
        WlrLayershell.keyboardFocus: (networkView.passwordActive || bluetoothView.renameActive) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property bool isHovered: false
        property bool pillHidden: true

        // MPRIS player lookup: prefer a playing player with real metadata, then
        // any playing, then paused. Mirrors NowPlayingModel.player.
        // A browser media session leaves artist empty (crams it into the title), so
        // a non-empty artist marks the richer desktop player.
        readonly property var mprisPlayer: {
            const players = Mpris.players.values;
            let playingRich = null, playingAny = null, paused = null;
            for (let i = 0; i < players.length; i++) {
                const p = players[i];
                if (p.playbackState === MprisPlaybackState.Playing) {
                    if (!playingAny)
                        playingAny = p;
                    if (!playingRich && p.trackArtist)
                        playingRich = p;
                } else if (!paused && p.playbackState === MprisPlaybackState.Paused) {
                    paused = p;
                }
            }
            return playingRich || playingAny || paused;
        }
        readonly property bool hasMprisPlayer: mprisPlayer !== null

        // Pill-only strip while out; grows to clear the shown popup while one is up.
        // Battery iGPU is bandwidth-bound: each near-fullscreen layer blend costs
        // double-digit fps, so the surface tracks the actual popup bottom rather than
        // a fixed near-fullscreen ceiling. Small menus keep a small surface; a menu
        // taller than the screen is clamped by the compositor, not this value.
        implicitHeight: pillHidden ? 0 : anyPopupShown ? Math.max(56, Math.ceil(popupBottom) + Spacing.spacing8) : 56

        // Bottom edge of the tallest shown popup, in root coords. Each popup is a
        // direct child of interactionZone (anchored to root top, y=0), so its bottom
        // is popupItem.y + popupItem.height. statusGroup wraps its own HoverItems.
        readonly property real popupBottom: {
            let maxB = 0;
            const scan = list => {
                for (const c of list) {
                    const p = c.popupItem;
                    if (p && p.visible && p.y + p.height > maxB)
                        maxB = p.y + p.height;
                }
            };
            scan(contentRow.children);
            scan(statusGroup.children);
            return maxB;
        }

        // Aggregate over popup-bearing children; each manages its own popup
        // (including any submenus nested inside that popup's outer Item).
        // statusGroup is a bare Row wrapper, so its HoverItems are scanned directly.
        readonly property bool anyPopupOpen: {
            for (const c of contentRow.children) if (c.popupOpen) return true;
            for (const c of statusGroup.children) if (c.popupOpen) return true;
            return false;
        }
        // Visibility test, not popupOpen: surface must stay tall through popup fade-out.
        readonly property bool anyPopupShown: {
            for (const c of contentRow.children) if (c.popupItem && c.popupItem.visible) return true;
            for (const c of statusGroup.children) if (c.popupItem && c.popupItem.visible) return true;
            return false;
        }
        // A Region follows its item's geometry but not its visibility, so a closed popup
        // still punches its full rectangle into the input region, where it reads as a
        // backdrop swallowing clicks meant for the window underneath. Passing null instead
        // leaves that Region at its empty default. The test is the popup's visibility
        // rather than its popupOpen flag, so a rect lasts exactly as long as the popup is
        // on screen, including while it animates away.
        function maskItem(item) {
            return item && item.visible ? item : null;
        }

        // Input region = trigger strip / pill area + each visible popup's own region.
        // Each child's popupItem already absorbs its descendants (submenus, bridges) inside
        // its bounding box, so Bar references only direct children.
        mask: Region {
            Region { item: interactionZone }
            Region { item: root.maskItem(nowPlayingHoverItem.popupItem) }
            Region { item: root.maskItem(calendarHoverItem.popupItem) }
            Region { item: root.maskItem(systemTray.popupItem) }
            Region { item: root.maskItem(networkHoverItem.popupItem) }
            Region { item: root.maskItem(bluetoothHoverItem.popupItem) }
            Region { item: root.maskItem(volumeHoverItem.popupItem) }
            Region { item: root.maskItem(batteryHoverItem.popupItem) }
        }

        // Launcher maps on one screen, so only that Bar slides out.
        // Without the name test every screen's surface grows.
        readonly property bool launcherOnThisScreen: Globals.launcherVisible && Globals.launcherScreenName === root.modelData.name

        readonly property bool shouldShowPill: zoneHover.hovered || anyPopupOpen || launcherOnThisScreen

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

        // The tray row expands for as long as the pill is on screen and no
        // longer, so the pill always slides back in at its resting width. The
        // collapse runs while the pill is off screen, where it costs nothing.
        onPillHiddenChanged: if (pillHidden) systemTray.expanded = false

        // interactionZone is the trigger strip + pill hit area. Open popups are NOT
        // included in its bounds. They're added to the input mask as separate
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

            // A tray menu is dismissed by clicking off it. A click that misses
            // the bar's input region clears the tray's focus grab instead, so
            // this only has to cover the pill. The handler takes a passive grab
            // and never accepts the point, leaving the click to the component it
            // landed on: pressing the volume icon both mutes and dismisses.
            TapHandler {
                enabled: systemTray.popupOpen
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onTapped: function (eventPoint) {
                    const pos = eventPoint.scenePosition;
                    // The tray row toggles and swaps its own menu, so taps on it
                    // are left alone. The menu's top edge reaches a few pixels
                    // into interactionZone and needs excluding too.
                    const onTray = systemTray.contains(systemTray.mapFromItem(null, pos));
                    const onMenu = systemTray.popupItem.contains(systemTray.popupItem.mapFromItem(null, pos));
                    if (!onTray && !onMenu)
                        systemTray.closeMenu();
                }
            }

            // Neo hard offset shadow behind the pill. No-op in classic (offset 0).
            Rectangle {
                visible: !Shape.usesBlur
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: Shape.shadowOffset
                y: pill.y + Shape.shadowOffset
                width: pill.implicitWidth
                height: pill.implicitHeight
                radius: pill.radius
                color: NeoTokens.ink
            }

            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: -implicitHeight - Spacing.spacing8

                implicitWidth: contentRow.implicitWidth + Spacing.spacing24
                implicitHeight: 32

                radius: Shape.pill(implicitHeight)
                color: Colors.pillBackground

                border.width: Shape.usesBlur ? 1 : Shape.thinBorderWidth
                border.color: Colors.pillBorder

                Row {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: Spacing.spacing8

                    Workspace3Apps {
                        id: workspace3Apps
                        monitorName: root.modelData.name
                    }

                    Rectangle {
                        visible: workspace3Apps.visible
                        width: 1
                        height: Spacing.spacing16
                        color: Colors.separatorColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

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
                            // Pill keeps visible: true while slid off-screen.
                            // Gate stops the visualiser animating an unseen surface.
                            barHidden: root.pillHidden
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
                        // Calendar open/close gates the weather fetch + scene animation.
                        onPopupOpenChanged: WeatherService.setMenuOpen(popupOpen)
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

                    // WLAN, bluetooth, audio, battery form one tight group; no inner separators.
                    Row {
                        id: statusGroup
                        spacing: Spacing.spacing4
                        anchors.verticalCenter: parent.verticalCenter

                        HoverItem {
                            id: networkHoverItem
                            clickable: false
                            menu: networkMenu
                            // Menu open/close drives the singleton's scan loop + throughput.
                            onPopupOpenChanged: {
                                if (popupOpen)
                                    NetworkService.openMenu();
                                else
                                    NetworkService.closeMenu();
                            }
                            NetworkIcon {}
                        }

                        HoverItem {
                            id: bluetoothHoverItem
                            visible: BluetoothService.hasAdapter
                            clickable: false
                            menu: bluetoothMenu
                            // Menu open/close refcounts discovery in the singleton.
                            onPopupOpenChanged: {
                                if (popupOpen)
                                    BluetoothService.openMenu();
                                else
                                    BluetoothService.closeMenu();
                            }
                            BluetoothIcon {}
                        }

                        HoverItem {
                            id: volumeHoverItem
                            clickable: true
                            menu: volumeMenu
                            // Claim keyed by screen: a plain bool is last-writer-wins across Bars.
                            onPopupOpenChanged: Globals.setVolumeSliderOpen(root.modelData.name, popupOpen)
                            onClicked: {
                                if (Pipewire.defaultAudioSink?.audio)
                                    Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
                            }
                            VolumeIcon {
                                id: volumeIcon
                            }
                        }

                        HoverItem {
                            id: batteryHoverItem
                            clickable: false
                            menu: batteryMenu
                            Battery {}
                        }
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
                x: pill.x + (pill.implicitWidth - contentRow.implicitWidth) / 2 + statusGroup.x + volumeHoverItem.x + volumeHoverItem.width / 2
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
                id: networkAnchor
                width: 0
                height: 0
                x: pill.x + (pill.implicitWidth - contentRow.implicitWidth) / 2 + statusGroup.x + networkHoverItem.x + networkHoverItem.width / 2
                y: pill.y + pill.implicitHeight
            }

            HoverMenu {
                id: networkMenu
                width: networkView.implicitWidth
                anchors.top: networkAnchor.top
                anchors.horizontalCenter: networkAnchor.horizontalCenter
                contentInteracting: networkView.interactionActive
                onHidden: networkView.resetState()

                NetworkMenu {
                    id: networkView
                    width: parent ? parent.width : 0
                    height: implicitHeight
                }
            }

            Item {
                id: bluetoothAnchor
                width: 0
                height: 0
                x: pill.x + (pill.implicitWidth - contentRow.implicitWidth) / 2 + statusGroup.x + bluetoothHoverItem.x + bluetoothHoverItem.width / 2
                y: pill.y + pill.implicitHeight
            }

            HoverMenu {
                id: bluetoothMenu
                width: bluetoothView.implicitWidth
                anchors.top: bluetoothAnchor.top
                anchors.horizontalCenter: bluetoothAnchor.horizontalCenter
                contentInteracting: bluetoothView.interactionActive
                onHidden: bluetoothView.resetState()

                BluetoothMenu {
                    id: bluetoothView
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
                    weatherActive: calendarHoverItem.popupOpen
                }
            }

            Item {
                id: batteryAnchor
                width: 0
                height: 0
                x: pill.x + (pill.implicitWidth - contentRow.implicitWidth) / 2 + statusGroup.x + batteryHoverItem.x + batteryHoverItem.width / 2
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
