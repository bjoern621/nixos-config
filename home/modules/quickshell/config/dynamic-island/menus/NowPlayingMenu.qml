import QtQuick
import "../"
import "../base"

// Theme-aware view over NowPlayingController + NowPlayingModel.
// Bar is per-screen, so side effects (Spotify, history, cooldown) live in the
// singleton; per-instance behavior (position poll, seek, queue) in the controller.
Item {
    id: root

    // Set by Bar. Public interface.
    property var player: null

    readonly property int contentPadding: Spacing.spacing12

    // Content + neo shadow gutter (shadowOffset 0 in classic).
    implicitWidth: 280 + Shape.shadowOffset
    implicitHeight: menuLayout.height + 2 * contentPadding + Shape.shadowOffset

    NowPlayingController {
        id: controller
        player: root.player
        // seekActive needs the live slider press state.
        sliderPressed: positionSlider.pressed
    }

    // Neo card: cream fill + ink border + offset shadow. Classic: glass + hairline.
    Card {
        anchors.fill: parent
        visible: controller.hasPlayer
        // Keep the album-art glow contained inside the card.
        clipContent: true

        Column {
            id: menuLayout
            x: root.contentPadding
            y: root.contentPadding
            width: parent.width - 2 * root.contentPadding
            spacing: Spacing.spacing8

            // --- Album Art + Track Info ---
            Row {
                width: parent.width
                spacing: Spacing.spacing12

                // Album art, with the cover accent blooming around the thumbnail.
                Item {
                    id: artSlot
                    width: 56
                    height: 56

                    // Cover glow: the accent blooms around the image, tinting the
                    // card near it. Sits behind the opaque thumbnail, so only the
                    // ring around the image shows. Scoped here, not Globals accent.
                    AmbientGlow {
                        anchors.centerIn: parent
                        width: parent.width + 2 * Spacing.spacing24
                        height: parent.height + 2 * Spacing.spacing24
                        // Source overspills the thumbnail so real color shows in the
                        // ring; the opaque thumbnail only masks the center.
                        sourceInset: Spacing.spacing4
                        sourceRadius: Spacing.spacing8
                        blurMax: 28
                        glowColor: AlbumArtAccent.accentColor
                        intensity: 0.9
                    }

                    Rectangle {
                        id: albumArtContainer
                        anchors.fill: parent
                        radius: Spacing.spacing8
                        color: Colors.progressBackground
                        clip: true

                        // Squishy pulse on track change
                        property bool pulsing: false

                        scale: pulsing ? 0.92 : 1.0
                        SquishBehavior on scale {
                            bouncy: true
                            duration: 200
                        }

                        Image {
                            id: albumArt
                            anchors.fill: parent
                            source: controller.trackArtUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready

                            // Smooth fade-in when image loads
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        // Fallback icon when no art
                        TintedIcon {
                            visible: albumArt.status !== Image.Ready
                            anchors.centerIn: parent
                            source: "../icons/icons8-audio.svg"
                            size: Typography.fontSize20
                            color: Colors.textColorMuted
                        }

                        Connections {
                            target: root.player
                            enabled: controller.hasPlayer
                            function onTrackChanged() {
                                albumArtContainer.pulsing = true;
                                artBounceTimer.restart();
                            }
                        }

                        Timer {
                            id: artBounceTimer
                            interval: 50
                            onTriggered: albumArtContainer.pulsing = false
                        }
                    }
                }

                // Title + Artist
                Column {
                    width: parent.width - albumArtContainer.width - Spacing.spacing12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Spacing.spacing2

                    Label {
                        text: controller.trackTitle
                        font.pixelSize: Typography.fontSize16
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Label {
                        text: controller.trackArtist
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Label {
                        visible: controller.trackAlbum !== ""
                        text: controller.trackAlbum
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        elide: Text.ElideRight
                        width: parent.width
                        opacity: 0.6
                    }
                }
            }

            // --- Timeline ---
            Column {
                width: parent.width
                spacing: Spacing.spacing2

                StepSlider {
                    id: positionSlider
                    width: parent.width
                    height: Spacing.spacing8
                    stepSize: 0.005
                    liveUpdate: false
                    handleVerticalSize: Spacing.spacing12
                    // StepSlider ignores externalValue while pressed, and currentPosition
                    // follows the drag, so this stays a plain binding.
                    externalValue: controller.trackLength > 0 ? controller.currentPosition / controller.trackLength : 0

                    // Guards live in the controller.
                    onPressedChanged: {
                        if (pressed)
                            controller.setSeekFraction(value);
                    }
                    onValueChanged: {
                        if (pressed)
                            controller.setSeekFraction(value);
                    }
                    onMoved: newValue => controller.commitSeek(newValue)
                }

                Item {
                    width: parent.width
                    height: elapsedLabel.implicitHeight

                    Label {
                        id: elapsedLabel
                        text: controller.formatTime(controller.currentPosition)
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        anchors.left: parent.left
                    }

                    Label {
                        text: controller.formatTime(controller.trackLength)
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        anchors.right: parent.right
                    }
                }
            }

            // --- Playback Controls ---
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Spacing.spacing16

                StaticButton {
                    width: 40 + Shape.buttonShadowOffset
                    height: 40 + Shape.buttonShadowOffset
                    centered: true
                    iconSize: Typography.fontSize24
                    iconSource: "../icons/icons8-skip-to-start.svg"
                    iconColor: controller.canGoPrevious ? Colors.textColor : Colors.textColorMuted
                    onClicked: controller.previous()
                }

                StaticButton {
                    width: 40 + Shape.buttonShadowOffset
                    height: 40 + Shape.buttonShadowOffset
                    centered: true
                    iconSize: Typography.fontSize24
                    iconSource: controller.isPlaying ? "../icons/icons8-pause.svg" : "../icons/icons8-play.svg"
                    onClicked: controller.togglePlaying()
                }

                StaticButton {
                    width: 40 + Shape.buttonShadowOffset
                    height: 40 + Shape.buttonShadowOffset
                    centered: true
                    iconSize: Typography.fontSize24
                    iconSource: "../icons/icons8-end.svg"
                    iconColor: controller.canGoNext ? Colors.textColor : Colors.textColorMuted
                    onClicked: controller.next()
                }
            }

            // --- Wiedergabeliste Toggle ---
            Pressable {
                id: queueToggle
                width: parent.width
                height: 28
                pressedScale: 0.96
                onClicked: controller.toggleQueue()
                // Prefetch on hover so open shows data, not skeletons.
                onHoveredChanged: {
                    if (hovered)
                        controller.prefetchQueue();
                }

                // Queue-toggle button bg. Classic round pill, neo cream hover + accent press.
                ButtonBg {
                    hovered: queueToggle.hovered
                    pressed: queueToggle.pressed
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Spacing.spacing4

                    TintedIcon {
                        source: "../icons/icons8-playlist.svg"
                        size: Typography.fontSize16
                        color: Colors.textColorMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                        text: "Wiedergabeliste"
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1
                    }

                    ExpandArrow {
                        id: chevronIcon
                        expanded: controller.queueExpanded
                        collapsedRotation: 0
                        expandedRotation: 180
                        iconSize: Typography.fontSize16
                        iconColor: Colors.textColorMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // --- Expandable Track List ---
            ExpandSection {
                id: trackListWrapper
                expanded: controller.queueExpanded

                Column {
                    id: trackListColumn
                    width: parent.width

                    // Skeleton row component
                    Component {
                        id: skeletonRowComponent

                        Item {
                            width: trackListColumn.width
                            height: 32 + Spacing.spacing8

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Spacing.spacing4
                                width: parent.width - 2 * Spacing.spacing4
                                spacing: Spacing.spacing8

                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: Spacing.spacing4
                                    color: Colors.progressBackground
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: skeletonPulse.pulseOpacity
                                }

                                Column {
                                    width: parent.width - 32 - Spacing.spacing8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Spacing.spacing4

                                    Rectangle {
                                        width: parent.width * 0.65
                                        height: Typography.fontSize14
                                        radius: Shape.pill(height)
                                        color: Colors.progressBackground
                                        opacity: skeletonPulse.pulseOpacity
                                    }

                                    Rectangle {
                                        width: parent.width * 0.4
                                        height: Typography.fontSize12
                                        radius: Shape.pill(height)
                                        color: Colors.progressBackground
                                        opacity: skeletonPulse.pulseOpacity
                                    }
                                }
                            }
                        }
                    }

                    // Shared pulse opacity for synchronized skeleton loading.
                    // Gated on queueExpanded: the skeletons live inside a collapsed
                    // ExpandSection until then, and recentlyPlayed only fills on hover,
                    // so an ungated pulse loops from shell start on every screen forever.
                    QtObject {
                        id: skeletonPulse
                        property real pulseOpacity: 0.4
                        SequentialAnimation on pulseOpacity {
                            running: controller.queueExpanded && (NowPlayingModel.recentSkeletonCount > 0 || NowPlayingModel.queueSkeletonCount > 0)
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: 0.4
                                to: 0.7
                                duration: 1200
                                easing.type: Easing.InOutQuad
                            }
                            NumberAnimation {
                                from: 0.7
                                to: 0.4
                                duration: 1200
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    // Skeleton placeholders for recently played (top)
                    Repeater {
                        model: NowPlayingModel.recentSkeletonCount
                        Loader {
                            sourceComponent: skeletonRowComponent
                            width: trackListColumn.width
                        }
                    }

                    // Unified track list: Recently Played -> Current -> Queue
                    ListView {
                        id: trackListView
                        width: parent.width
                        height: contentHeight
                        interactive: false
                        clip: true
                        model: NowPlayingModel.trackList

                        Behavior on height {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }

                        add: Transition {
                            ParallelAnimation {
                                NumberAnimation {
                                    property: "opacity"
                                    from: 0
                                    to: 1
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    property: "scale"
                                    from: 0.96
                                    to: 1.0
                                    duration: 250
                                    easing.type: Easing.OutBack
                                }
                            }
                        }

                        remove: Transition {
                            ParallelAnimation {
                                NumberAnimation {
                                    property: "opacity"
                                    to: 0
                                    duration: 150
                                    easing.type: Easing.InCubic
                                }
                                NumberAnimation {
                                    property: "scale"
                                    to: 0.96
                                    duration: 150
                                    easing.type: Easing.InCubic
                                }
                            }
                        }

                        displaced: Transition {
                            NumberAnimation {
                                properties: "y"
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }

                        delegate: Pressable {
                            id: trackDelegate
                            required property string title
                            required property string artist
                            required property string artUrl
                            required property string uri
                            required property string type
                            required property int index

                            property bool isCurrent: type === "current"

                            width: trackListView.width
                            height: trackDelegateRow.implicitHeight + Spacing.spacing8
                            pressedScale: 0.97

                            onClicked: {
                                if (isCurrent)
                                    controller.togglePlaying();
                                else
                                    controller.playUri(uri);
                            }

                            // Launcher row bg: current track = accent selection, 2px ink border.
                            LauncherDelegateBg {
                                active: trackDelegate.isCurrent
                                hovered: trackDelegate.hovered
                                pressed: trackDelegate.pressed
                            }

                            Row {
                                id: trackDelegateRow
                                anchors.verticalCenter: parent.verticalCenter
                                x: Spacing.spacing4
                                width: parent.width - 2 * Spacing.spacing4
                                spacing: Spacing.spacing8

                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: Spacing.spacing4
                                    color: Colors.progressBackground
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter

                                    Image {
                                        anchors.fill: parent
                                        source: trackDelegate.artUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    // Play/pause indicator for current track
                                    Rectangle {
                                        visible: trackDelegate.isCurrent
                                        width: controller.isPlaying ? 26 : 20
                                        height: controller.isPlaying ? 18 : 20
                                        radius: controller.isPlaying ? Spacing.spacing4 : Shape.pill(height)
                                        color: Qt.rgba(0, 0, 0, 0.35)
                                        anchors.centerIn: parent

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: 80
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                        Behavior on height {
                                            NumberAnimation {
                                                duration: 80
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        MusicBars {
                                            visible: controller.isPlaying
                                            playing: controller.isPlaying
                                            // Collapsed ExpandSection still animates its children.
                                            barHidden: !controller.queueExpanded
                                            anchors.centerIn: parent
                                        }

                                        TintedIcon {
                                            visible: !controller.isPlaying
                                            anchors.centerIn: parent
                                            source: "../icons/icons8-play.svg"
                                            size: Typography.fontSize12
                                            color: Colors.textColor
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width - 32 - Spacing.spacing8
                                    anchors.verticalCenter: parent.verticalCenter

                                    Label {
                                        text: trackDelegate.title
                                        font.pixelSize: Typography.fontSize14
                                        font.weight: trackDelegate.isCurrent ? Font.Bold : Font.Normal
                                        color: trackDelegate.isCurrent ? Colors.textColor : Colors.textColorMuted
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Label {
                                        visible: trackDelegate.artist !== ""
                                        text: trackDelegate.artist
                                        font.pixelSize: Typography.fontSize12
                                        font.weight: Font.Normal
                                        color: Colors.textColorMuted
                                        opacity: trackDelegate.isCurrent ? 1 : 0.6
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }
                            }
                        }
                    }

                    // Skeleton placeholders for queue (bottom)
                    Repeater {
                        model: NowPlayingModel.queueSkeletonCount
                        Loader {
                            sourceComponent: skeletonRowComponent
                            width: trackListColumn.width
                        }
                    }
                }
            }
        }
    }
}
