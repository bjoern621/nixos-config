import QtQuick
import Quickshell.Services.Mpris

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

    // Update position every second while playing
    Timer {
        id: positionTimer
        interval: 1000
        repeat: true
        running: root.isPlaying
        onTriggered: {
            if (root.hasPlayer && root.player.positionSupported)
                positionSlider.externalValue = root.player.length > 0 ? root.player.position / root.player.length : 0
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
                    handleVerticalSize: Spacing.spacing12
                    externalValue: root.hasPlayer && root.player.length > 0 ? root.player.position / root.player.length : 0

                    onMoved: (newValue) => {
                        if (root.hasPlayer && root.player.canSeek && root.player.length > 0)
                            root.player.position = newValue * root.player.length;
                    }
                }

                Item {
                    width: parent.width
                    height: elapsedLabel.implicitHeight

                    Label {
                        id: elapsedLabel
                        text: root.hasPlayer ? root.formatTime(root.player.position) : "0:00"
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
                    width: 32; height: 32

                    property bool hovered: prevHover.hovered
                    property bool pressed: prevTap.pressed

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: prevBtn.pressed ? Colors.hoverItemPressed
                             : prevBtn.hovered ? Colors.hoverItemHovered
                             : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf048"
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize14
                        color: root.hasPlayer && root.player.canGoPrevious ? Colors.textColor : Colors.textColorMuted
                    }

                    HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: prevTap; onTapped: { if (root.hasPlayer) root.player.previous() } }

                    scale: prevTap.pressed ? 0.85 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
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
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                }

                // Next
                Item {
                    id: nextBtn
                    width: 32; height: 32

                    property bool hovered: nextHover.hovered
                    property bool pressed: nextTap.pressed

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: nextBtn.pressed ? Colors.hoverItemPressed
                             : nextBtn.hovered ? Colors.hoverItemHovered
                             : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf051"
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize14
                        color: root.hasPlayer && root.player.canGoNext ? Colors.textColor : Colors.textColorMuted
                    }

                    HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: nextTap; onTapped: { if (root.hasPlayer) root.player.next() } }

                    scale: nextTap.pressed ? 0.85 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                }
            }

            // --- Wiedergabeliste Toggle ---
            Item {
                id: queueToggle
                width: parent.width
                height: 28
                visible: root.trackHistory.length > 1

                property bool hovered: queueToggleHover.hovered
                property bool pressed: queueToggleTap.pressed

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: queueToggle.pressed ? Colors.hoverItemPressed
                         : queueToggle.hovered ? Colors.hoverItemHovered
                         : "transparent"
                    border.color: queueToggle.hovered || queueToggle.pressed ? Colors.pillBorder : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
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
                        text: root.queueExpanded ? "\uf077" : "\uf078"
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize12
                        color: Colors.textColorMuted
                        anchors.verticalCenter: parent.verticalCenter

                        // Rotate animation for the chevron
                        rotation: root.queueExpanded ? 0 : 0
                    }
                }

                HoverHandler { id: queueToggleHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: queueToggleTap
                    onTapped: root.queueExpanded = !root.queueExpanded
                }

                scale: queueToggleTap.pressed ? 0.96 : 1.0
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
            }

            // --- Expandable Track List ---
            Item {
                id: trackListWrapper
                width: parent.width
                height: root.queueExpanded ? trackListColumn.implicitHeight : 0
                clip: true
                visible: root.trackHistory.length > 1

                Behavior on height {
                    NumberAnimation {
                        duration: 250
                        easing.type: root.queueExpanded ? Easing.OutBack : Easing.InCubic
                    }
                }

                // Fade in/out content
                opacity: root.queueExpanded ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.queueExpanded ? 200 : 120
                        easing.type: root.queueExpanded ? Easing.OutCubic : Easing.InCubic
                    }
                }

                Column {
                    id: trackListColumn
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: root.trackHistory

                        delegate: Item {
                            id: trackDelegate
                            required property var modelData
                            required property int index

                            readonly property bool isCurrent: index === root.trackHistory.length - 1
                            property bool hovered: trackDelegateHover.hovered
                            property bool pressed: trackDelegateTap.pressed

                            width: trackListColumn.width
                            height: trackRow.implicitHeight + Spacing.spacing8

                            Rectangle {
                                anchors.fill: parent
                                radius: Spacing.spacing4
                                color: trackDelegate.pressed ? Colors.hoverItemPressed
                                     : trackDelegate.hovered ? Colors.hoverItemHovered
                                     : "transparent"
                                    }

                            Row {
                                id: trackRow
                                anchors.verticalCenter: parent.verticalCenter
                                x: Spacing.spacing4
                                width: parent.width - 2 * Spacing.spacing4
                                spacing: Spacing.spacing8

                                // Track album art thumbnail
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

                                    // Playing indicator overlay for current track
                                    Rectangle {
                                        visible: trackDelegate.isCurrent
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
                                        text: modelData.title || ""
                                        font.pixelSize: Typography.fontSize14
                                        font.weight: trackDelegate.isCurrent ? Font.Bold : Font.Normal
                                        color: trackDelegate.isCurrent ? Colors.textColor : Colors.textColorMuted
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Label {
                                        visible: (modelData.artist || "") !== ""
                                        text: modelData.artist || ""
                                        font.pixelSize: Typography.fontSize12
                                        font.weight: Font.Normal
                                        color: Colors.textColorMuted
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
                                    if (!root.hasPlayer) return;
                                    if (trackDelegate.isCurrent) {
                                        root.player.togglePlaying();
                                    } else {
                                        const stepsBack = root.trackHistory.length - 1 - trackDelegate.index;
                                        for (let i = 0; i < stepsBack; i++)
                                            root.player.previous();
                                    }
                                }
                            }

                            scale: trackDelegateTap.pressed ? 0.97 : 1.0
                            transformOrigin: Item.Center
                            Behavior on scale {
                                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }
    }
}
