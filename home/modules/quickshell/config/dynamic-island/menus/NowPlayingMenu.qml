import QtQuick
import Quickshell.Services.Mpris
import "../"

Item {
    id: root

    property var player: null
    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: hasPlayer && player.playbackState === MprisPlaybackState.Playing

    readonly property int contentPadding: Spacing.spacing12

    implicitWidth: 280
    implicitHeight: menuLayout.height + 2 * contentPadding

    // Track history (stores {title, artist, artUrl} objects)
    property var trackHistory: []
    property int maxHistory: 8
    property bool queueExpanded: false

    // Mock data for playlist sections (will be replaced with Spotify API)
    readonly property var mockRecentlyPlayed: [
        { title: "Midnight City", artist: "M83", artUrl: "https://i.scdn.co/image/ab67616d0000b273f9d4f05f1b5bb17b6faba046" },
        { title: "Blinding Lights", artist: "The Weeknd", artUrl: "https://i.scdn.co/image/ab67616d0000b273f9d4f05f1b5bb17b6faba046" },
        { title: "Take On Me", artist: "a-ha", artUrl: "https://i.scdn.co/image/ab67616d0000b273f9d4f05f1b5bb17b6faba046" }
    ]
    readonly property var mockQueue: [
        { title: "Stressed Out", artist: "Twenty One Pilots", artUrl: "https://i.scdn.co/image/ab67616d0000b273f9d4f05f1b5bb17b6faba046" },
        { title: "Electric Feel", artist: "MGMT", artUrl: "https://i.scdn.co/image/ab67616d0000b273f9d4f05f1b5bb17b6faba046" },
        { title: "Do I Wanna Know?", artist: "Arctic Monkeys", artUrl: "https://i.scdn.co/image/ab67616d0000b273f9d4f05f1b5bb17b6faba046" }
    ]

    // Local position cache, updated by timer
    property real currentPosition: root.hasPlayer ? root.player.position : 0

    // Suppresses externalValue updates briefly after seeking to prevent snap-back
    property bool seekInProgress: false
    Timer {
        id: seekGuardTimer
        interval: 500
        onTriggered: root.seekInProgress = false
    }

    // Update position while playing
    Timer {
        id: positionTimer
        interval: 250
        repeat: true
        running: root.isPlaying
        onTriggered: {
            if (root.hasPlayer && root.player.positionSupported) {
                if (!positionSlider.pressed) {
                    root.currentPosition = root.player.position;
                }
                if (!root.seekInProgress && !positionSlider.pressed) {
                    positionSlider.externalValue = root.player.length > 0 ? root.player.position / root.player.length : 0;
                }
            }
        }
    }

    // Track changes → push to history
    Connections {
        target: root.player
        enabled: root.hasPlayer

        function onTrackChanged() {
            if (!root.hasPlayer) return;
            const title = root.player.trackTitle;
            const artist = root.player.trackArtist;
            const artUrl = root.player.trackArtUrl;
            if (!title) return;

            const h = root.trackHistory;
            if (h.length > 0) {
                const last = h[h.length - 1];
                if (last.title === title && last.artist === artist) return;
            }

            let newHistory = h.slice();
            newHistory.push({ title: title, artist: artist, artUrl: artUrl || "" });
            if (newHistory.length > root.maxHistory + 1)
                newHistory = newHistory.slice(newHistory.length - root.maxHistory - 1);
            root.trackHistory = newHistory;
        }
    }

    Component.onCompleted: {
        if (root.hasPlayer && root.player.trackTitle) {
            root.trackHistory = [{
                title: root.player.trackTitle,
                artist: root.player.trackArtist,
                artUrl: root.player.trackArtUrl || ""
            }];
        }
    }

    function formatTime(seconds) {
        if (seconds <= 0 || !isFinite(seconds)) return "0:00";
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

                    Image {
                        id: albumArt
                        anchors.fill: parent
                        source: root.hasPlayer ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready

                        // Smooth fade-in when image loads
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                    }

                    // Fallback icon when no art
                    Text {
                        visible: albumArt.status !== Image.Ready
                        anchors.centerIn: parent
                        text: "\uf001"
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize20
                        color: Colors.textColorMuted
                    }

                    // Squishy pulse on track change
                    scale: 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                    }

                    Connections {
                        target: root.player
                        enabled: root.hasPlayer
                        function onTrackChanged() {
                            albumArtContainer.scale = 0.92;
                            artBounceTimer.restart();
                        }
                    }

                    Timer {
                        id: artBounceTimer
                        interval: 50
                        onTriggered: albumArtContainer.scale = 1.0
                    }
                }

                // Title + Artist
                Column {
                    width: parent.width - 56 - Spacing.spacing12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Spacing.spacing2

                    Label {
                        text: root.hasPlayer ? root.player.trackTitle : ""
                        font.pixelSize: Typography.fontSize16
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Label {
                        text: root.hasPlayer ? root.player.trackArtist : ""
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Label {
                        visible: root.hasPlayer && root.player.trackAlbum !== ""
                        text: root.hasPlayer ? root.player.trackAlbum : ""
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
                    externalValue: root.hasPlayer && root.player.length > 0 ? root.player.position / root.player.length : 0

                    onPressedChanged: {
                        if (pressed && root.hasPlayer && root.player.length > 0) {
                            root.currentPosition = value * root.player.length;
                        }
                    }

                    onValueChanged: {
                        if (pressed && root.hasPlayer && root.player.length > 0) {
                            root.currentPosition = value * root.player.length;
                        }
                    }

                    onMoved: (newValue) => {
                        if (root.hasPlayer && root.player.canSeek && root.player.length > 0) {
                            root.player.position = newValue * root.player.length;
                            root.currentPosition = newValue * root.player.length;
                            positionSlider.externalValue = newValue;
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
                        text: root.hasPlayer ? root.formatTime(root.currentPosition) : "0:00"
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        anchors.left: parent.left
                    }

                    Label {
                        text: root.hasPlayer ? root.formatTime(root.player.length) : "0:00"
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

                // Previous
                Item {
                    id: prevBtn
                    width: 40; height: 40

                    property bool hovered: prevHover.hovered
                    property bool pressed: prevTap.pressed

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: prevBtn.pressed ? Colors.hoverItemPressed
                             : prevBtn.hovered ? Colors.hoverItemHovered
                             : "transparent"
                        border.color: prevBtn.hovered || prevBtn.pressed ? Colors.pillBorder : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf048"
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize20
                        color: root.hasPlayer && root.player.canGoPrevious ? Colors.textColor : Colors.textColorMuted
                    }

                    HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: prevTap; onTapped: { if (root.hasPlayer) root.player.previous() } }

                    scale: prevTap.pressed ? 0.82 : 1.0
                    SquishBehavior on scale { bouncy: true; duration: 120 }
                }

                // Play/Pause
                Item {
                    id: playBtn
                    width: 40; height: 40

                    property bool hovered: playHover.hovered
                    property bool pressed: playTap.pressed

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: playBtn.pressed ? Colors.hoverItemPressed
                             : playBtn.hovered ? Colors.hoverItemHovered
                             : "transparent"
                        border.color: playBtn.hovered || playBtn.pressed ? Colors.pillBorder : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "\uf04c" : "\uf04b"
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize20
                        color: Colors.textColor
                    }

                    HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: playTap; onTapped: { if (root.hasPlayer) root.player.togglePlaying() } }

                    scale: playTap.pressed ? 0.82 : 1.0
                    SquishBehavior on scale { bouncy: true; duration: 120 }
                }

                // Next
                Item {
                    id: nextBtn
                    width: 40; height: 40

                    property bool hovered: nextHover.hovered
                    property bool pressed: nextTap.pressed

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: nextBtn.pressed ? Colors.hoverItemPressed
                             : nextBtn.hovered ? Colors.hoverItemHovered
                             : "transparent"
                        border.color: nextBtn.hovered || nextBtn.pressed ? Colors.pillBorder : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf051"
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize20
                        color: root.hasPlayer && root.player.canGoNext ? Colors.textColor : Colors.textColorMuted
                    }

                    HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: nextTap; onTapped: { if (root.hasPlayer) root.player.next() } }

                    scale: nextTap.pressed ? 0.82 : 1.0
                    SquishBehavior on scale { bouncy: true; duration: 120 }
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
                    color: queueToggle.pressed ? Colors.hoverItemPressed
                         : queueToggle.hovered ? Colors.hoverItemHovered
                         : "transparent"
                    border.color: queueToggle.hovered || queueToggle.pressed ? Colors.pillBorder : "transparent"
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Spacing.spacing4

                    Text {
                        text: "\uf0ca"
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize12
                        color: Colors.textColorMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                        text: "Wiedergabeliste"
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: chevronIcon
                        text: "\uf078"
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize12
                        color: Colors.textColorMuted
                        anchors.verticalCenter: parent.verticalCenter

                        rotation: root.queueExpanded ? 180 : 0
                        Behavior on rotation {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                }

                HoverHandler { id: queueToggleHover; cursorShape: Qt.PointingHandCursor }
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
                    spacing: Spacing.spacing8

                    // Section: Recently Played
                    Column {
                        width: parent.width
                        spacing: Spacing.spacing2

                        Label {
                            text: "Zuletzt gespielt"
                            font.pixelSize: Typography.fontSize12
                            font.weight: Font.Normal
                            color: Colors.textColorMuted
                            leftPadding: Spacing.spacing4
                        }

                        Repeater {
                            model: root.mockRecentlyPlayed

                            delegate: Item {
                                id: recentDelegate
                                required property var modelData
                                required property int index

                                property bool hovered: recentHover.hovered
                                property bool pressed: recentTap.pressed

                                width: trackListColumn.width
                                height: trackRowRecent.implicitHeight + Spacing.spacing8

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Spacing.spacing4
                                    color: recentDelegate.pressed ? Colors.hoverItemPressed
                                         : recentDelegate.hovered ? Colors.hoverItemHovered
                                         : "transparent"
                                    border.color: recentDelegate.hovered || recentDelegate.pressed ? Colors.pillBorder : "transparent"
                                    border.width: recentDelegate.hovered || recentDelegate.pressed ? 1 : 0
                                }

                                Row {
                                    id: trackRowRecent
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
                                            source: modelData.artUrl || ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }
                                    }

                                    Column {
                                        width: parent.width - 32 - Spacing.spacing8
                                        anchors.verticalCenter: parent.verticalCenter

                                        Label {
                                            text: modelData.title || ""
                                            font.pixelSize: Typography.fontSize14
                                            font.weight: Font.Normal
                                            color: Colors.textColorMuted
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        Label {
                                            visible: (modelData.artist || "") !== ""
                                            text: modelData.artist || ""
                                            font.pixelSize: Typography.fontSize12
                                            font.weight: Font.Normal
                                            color: Colors.textColorMuted
                                            opacity: 0.6
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }
                                }

                                HoverHandler {
                                    id: recentHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    id: recentTap
                                    onTapped: {
                                        // Placeholder - will integrate with Spotify API
                                        console.log("Play recent track:", modelData.title)
                                    }
                                }

                                scale: recentTap.pressed ? 0.97 : 1.0
                                transformOrigin: Item.Center
                                SquishBehavior on scale {}
                            }
                        }
                    }

                    // Section: Current Track
                    Column {
                        width: parent.width
                        spacing: Spacing.spacing2

                        Label {
                            text: "Aktuell"
                            font.pixelSize: Typography.fontSize12
                            font.weight: Font.Normal
                            color: Colors.textColorMuted
                            leftPadding: Spacing.spacing4
                        }

                        Item {
                            id: currentTrackDelegate
                            width: parent.width
                            height: trackRowCurrent.implicitHeight + Spacing.spacing8

                            property bool hovered: currentHover.hovered
                            property bool pressed: currentTap.pressed

                            Rectangle {
                                anchors.fill: parent
                                radius: Spacing.spacing4
                                color: Colors.hoverItemHovered
                                opacity: 0.3
                                border.color: Colors.accentColor
                                border.width: 1
                            }

                            Row {
                                id: trackRowCurrent
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
                                        source: root.hasPlayer ? root.player.trackArtUrl : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(0, 0, 0, 0.5)
                                        radius: Spacing.spacing4

                                        MusicBars {
                                            visible: root.isPlaying
                                            playing: root.isPlaying
                                            anchors.centerIn: parent
                                        }

                                        Text {
                                            visible: !root.isPlaying
                                            anchors.centerIn: parent
                                            text: "\uf04b"
                                            font.family: Typography.iconFontFamily
                                            font.pixelSize: Typography.fontSize12
                                            color: Colors.textColor
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width - 32 - Spacing.spacing8
                                    anchors.verticalCenter: parent.verticalCenter

                                    Label {
                                        text: root.hasPlayer ? root.player.trackTitle : ""
                                        font.pixelSize: Typography.fontSize14
                                        font.weight: Font.Bold
                                        color: Colors.textColor
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Label {
                                        visible: root.hasPlayer && (root.player.trackArtist || "") !== ""
                                        text: root.hasPlayer ? root.player.trackArtist : ""
                                        font.pixelSize: Typography.fontSize12
                                        font.weight: Font.Normal
                                        color: Colors.textColorMuted
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }
                            }

                            HoverHandler {
                                id: currentHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                id: currentTap
                                onTapped: {
                                    if (root.hasPlayer) root.player.togglePlaying()
                                }
                            }

                            scale: currentTap.pressed ? 0.97 : 1.0
                            transformOrigin: Item.Center
                            SquishBehavior on scale {}
                        }
                    }

                    // Section: Queue
                    Column {
                        width: parent.width
                        spacing: Spacing.spacing2

                        Label {
                            text: "Warteschlange"
                            font.pixelSize: Typography.fontSize12
                            font.weight: Font.Normal
                            color: Colors.textColorMuted
                            leftPadding: Spacing.spacing4
                        }

                        Repeater {
                            model: root.mockQueue

                            delegate: Item {
                                id: queueDelegate
                                required property var modelData
                                required property int index

                                property bool hovered: queueHover.hovered
                                property bool pressed: queueTap.pressed

                                width: trackListColumn.width
                                height: trackRowQueue.implicitHeight + Spacing.spacing8

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Spacing.spacing4
                                    color: queueDelegate.pressed ? Colors.hoverItemPressed
                                         : queueDelegate.hovered ? Colors.hoverItemHovered
                                         : "transparent"
                                    border.color: queueDelegate.hovered || queueDelegate.pressed ? Colors.pillBorder : "transparent"
                                    border.width: queueDelegate.hovered || queueDelegate.pressed ? 1 : 0
                                }

                                Row {
                                    id: trackRowQueue
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
                                            source: modelData.artUrl || ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }
                                    }

                                    Column {
                                        width: parent.width - 32 - Spacing.spacing8
                                        anchors.verticalCenter: parent.verticalCenter

                                        Label {
                                            text: modelData.title || ""
                                            font.pixelSize: Typography.fontSize14
                                            font.weight: Font.Normal
                                            color: Colors.textColorMuted
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        Label {
                                            visible: (modelData.artist || "") !== ""
                                            text: modelData.artist || ""
                                            font.pixelSize: Typography.fontSize12
                                            font.weight: Font.Normal
                                            color: Colors.textColorMuted
                                            opacity: 0.6
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }
                                }

                                HoverHandler {
                                    id: queueHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    id: queueTap
                                    onTapped: {
                                        // Placeholder - will integrate with Spotify API
                                        console.log("Play queued track:", modelData.title)
                                    }
                                }

                                scale: queueTap.pressed ? 0.97 : 1.0
                                transformOrigin: Item.Center
                                SquishBehavior on scale {}
                            }
                        }
                    }
                }
            }
        }
    }
}
