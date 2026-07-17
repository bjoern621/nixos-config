import QtQuick
import Quickshell.Services.Mpris
import "../"
import "../base"

// View over NowPlayingModel. Bar is per-screen, so everything with a side effect
// (Spotify process, track history, cooldown) lives in the singleton, not here.
Item {
    id: root

    property var player: null
    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: hasPlayer && player.playbackState === MprisPlaybackState.Playing

    // Null-check player once, here, not at every UI call site.
    readonly property string trackTitle: hasPlayer ? player.trackTitle : ""
    readonly property string trackArtist: hasPlayer ? player.trackArtist : ""
    readonly property string trackAlbum: hasPlayer ? player.trackAlbum : ""
    readonly property string trackArtUrl: hasPlayer ? player.trackArtUrl : ""
    readonly property real trackLength: hasPlayer ? player.length : 0
    readonly property bool canGoNext: hasPlayer && player.canGoNext
    readonly property bool canGoPrevious: hasPlayer && player.canGoPrevious

    readonly property int contentPadding: Spacing.spacing12

    property bool queueExpanded: false

    implicitWidth: 280
    implicitHeight: menuLayout.height + 2 * contentPadding

    // Position has two sources and one reader.
    // _syncPolledPosition writes polledPosition, slider handlers write seekPosition.
    // currentPosition binds over both, so nothing writes it imperatively.
    // An imperative write kills a binding for good, stranding the scrubber on the
    // previous track once paused.
    property real polledPosition: 0
    property real seekPosition: 0
    // Suppresses player-driven updates after a seek, else the slider snaps back.
    property bool seekInProgress: false
    readonly property bool seekActive: positionSlider.pressed || seekInProgress
    readonly property real currentPosition: seekActive ? seekPosition : polledPosition

    // MPRIS position is poll-only, so every source of truth has to re-read it.
    function _syncPolledPosition() {
        root.polledPosition = root.hasPlayer && root.player.positionSupported ? root.player.position : 0;
    }

    onPlayerChanged: _syncPolledPosition()
    Component.onCompleted: _syncPolledPosition()

    Timer {
        id: seekGuardTimer
        interval: 500
        onTriggered: {
            // Player had time to apply the seek. Re-read before handing the slider back.
            root._syncPolledPosition();
            root.seekInProgress = false;
        }
    }

    Timer {
        id: positionTimer
        interval: 250
        repeat: true
        running: root.isPlaying
        onTriggered: root._syncPolledPosition()
    }

    Connections {
        target: root.player
        enabled: root.hasPlayer

        // postTrackChanged fires once properties are updated. Without this the scrubber
        // keeps the old track's position while paused, since positionTimer is stopped.
        function onPostTrackChanged() {
            root._syncPolledPosition();
        }
    }

    onQueueExpandedChanged: {
        if (queueExpanded && root.hasPlayer)
            NowPlayingModel.refreshSpotifyData();
    }

    function formatTime(seconds) {
        if (seconds <= 0 || !isFinite(seconds))
            return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Rectangle {
        anchors.fill: parent
        radius: Spacing.spacing12
        color: Colors.pillBackground
        border.width: 1
        border.color: Colors.pillBorder
        visible: root.hasPlayer

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

                // Album art
                Rectangle {
                    id: albumArtContainer
                    width: 56
                    height: 56
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
                        source: root.trackArtUrl
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
                        enabled: root.hasPlayer
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

                // Title + Artist
                Column {
                    width: parent.width - albumArtContainer.width - Spacing.spacing12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Spacing.spacing2

                    Label {
                        text: root.trackTitle
                        font.pixelSize: Typography.fontSize16
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Label {
                        text: root.trackArtist
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Label {
                        visible: root.trackAlbum !== ""
                        text: root.trackAlbum
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
                    externalValue: root.trackLength > 0 ? root.currentPosition / root.trackLength : 0

                    onPressedChanged: {
                        if (pressed && root.trackLength > 0)
                            root.seekPosition = value * root.trackLength;
                    }

                    onValueChanged: {
                        if (pressed && root.trackLength > 0)
                            root.seekPosition = value * root.trackLength;
                    }

                    onMoved: newValue => {
                        if (root.hasPlayer && root.player.canSeek && root.trackLength > 0) {
                            root.player.position = newValue * root.trackLength;
                            root.seekPosition = newValue * root.trackLength;
                            root.seekInProgress = true;
                            seekGuardTimer.restart();
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: elapsedLabel.implicitHeight

                    Label {
                        id: elapsedLabel
                        text: root.formatTime(root.currentPosition)
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        anchors.left: parent.left
                    }

                    Label {
                        text: root.formatTime(root.trackLength)
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

                IconButton {
                    source: "../icons/icons8-skip-to-start.svg"
                    iconColor: root.canGoPrevious ? Colors.textColor : Colors.textColorMuted
                    onClicked: {
                        if (root.hasPlayer)
                            root.player.previous();
                    }
                }

                IconButton {
                    source: root.isPlaying ? "../icons/icons8-pause.svg" : "../icons/icons8-play.svg"
                    onClicked: {
                        if (root.hasPlayer)
                            root.player.togglePlaying();
                    }
                }

                IconButton {
                    source: "../icons/icons8-end.svg"
                    iconColor: root.canGoNext ? Colors.textColor : Colors.textColorMuted
                    onClicked: {
                        if (root.hasPlayer)
                            root.player.next();
                    }
                }
            }

            // --- Wiedergabeliste Toggle ---
            Item {
                id: queueToggle
                width: parent.width
                height: 28

                property bool hovered: queueToggleHover.hovered
                property bool pressed: queueToggleTap.pressed

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: queueToggle.pressed ? Colors.hoverItemPressed : queueToggle.hovered ? Colors.hoverItemHovered : "transparent"
                    border.color: queueToggle.hovered || queueToggle.pressed ? Colors.pillBorder : "transparent"
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
                        expanded: root.queueExpanded
                        collapsedRotation: 0
                        expandedRotation: 180
                        iconSize: Typography.fontSize16
                        iconColor: Colors.textColorMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler {
                    id: queueToggleHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (hovered && !root.queueExpanded)
                            NowPlayingModel.refreshSpotifyData();
                    }
                }
                TapHandler {
                    id: queueToggleTap
                    onTapped: root.queueExpanded = !root.queueExpanded
                }

                scale: queueToggleTap.pressed ? 0.96 : 1.0
                SquishBehavior on scale {}
            }

            // --- Expandable Track List ---
            ExpandSection {
                id: trackListWrapper
                expanded: root.queueExpanded

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
                                        radius: height / 2
                                        color: Colors.progressBackground
                                        opacity: skeletonPulse.pulseOpacity
                                    }

                                    Rectangle {
                                        width: parent.width * 0.4
                                        height: Typography.fontSize12
                                        radius: height / 2
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
                            running: root.queueExpanded && (NowPlayingModel.recentSkeletonCount > 0 || NowPlayingModel.queueSkeletonCount > 0)
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

                        delegate: Item {
                            id: trackDelegate
                            required property string title
                            required property string artist
                            required property string artUrl
                            required property string uri
                            required property string type
                            required property int index

                            property bool isCurrent: type === "current"
                            property bool hovered: trackDelegateHover.hovered
                            property bool pressed: trackDelegateTap.pressed

                            width: trackListView.width
                            height: trackDelegateRow.implicitHeight + Spacing.spacing8

                            Rectangle {
                                anchors.fill: parent
                                radius: Spacing.spacing4
                                color: trackDelegate.isCurrent ? Colors.hoverItemHovered : trackDelegate.pressed ? Colors.hoverItemPressed : trackDelegate.hovered ? Colors.hoverItemHovered : "transparent"
                                opacity: trackDelegate.isCurrent ? 0.3 : 1
                                border.color: trackDelegate.isCurrent ? Colors.accentColor : (trackDelegate.hovered || trackDelegate.pressed) ? Colors.pillBorder : "transparent"
                                border.width: trackDelegate.isCurrent || trackDelegate.hovered || trackDelegate.pressed ? 1 : 0
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
                                        width: root.isPlaying ? 26 : 20
                                        height: root.isPlaying ? 18 : 20
                                        radius: root.isPlaying ? Spacing.spacing4 : height / 2
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
                                            visible: root.isPlaying
                                            playing: root.isPlaying
                                            // Collapsed ExpandSection still animates its children.
                                            barHidden: !root.queueExpanded
                                            anchors.centerIn: parent
                                        }

                                        TintedIcon {
                                            visible: !root.isPlaying
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

                            HoverHandler {
                                id: trackDelegateHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                id: trackDelegateTap
                                onTapped: {
                                    if (trackDelegate.isCurrent) {
                                        if (root.hasPlayer)
                                            root.player.togglePlaying();
                                    } else if (trackDelegate.uri) {
                                        NowPlayingModel.playSpotifyUri(trackDelegate.uri);
                                    }
                                }
                            }

                            scale: trackDelegateTap.pressed ? 0.97 : 1.0
                            transformOrigin: Item.Center
                            SquishBehavior on scale {}
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
