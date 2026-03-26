import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../"

Item {
    id: root

    property var player: null
    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: hasPlayer && player.playbackState === MprisPlaybackState.Playing

    // Convenience properties — null-check player once, use these everywhere in the UI
    readonly property string trackTitle: hasPlayer ? player.trackTitle : ""
    readonly property string trackArtist: hasPlayer ? player.trackArtist : ""
    readonly property string trackAlbum: hasPlayer ? player.trackAlbum : ""
    readonly property string trackArtUrl: hasPlayer ? player.trackArtUrl : ""
    readonly property real trackLength: hasPlayer ? player.length : 0
    readonly property bool canGoNext: hasPlayer && player.canGoNext
    readonly property bool canGoPrevious: hasPlayer && player.canGoPrevious

    readonly property int contentPadding: Spacing.spacing12

    implicitWidth: 280
    implicitHeight: menuLayout.height + 2 * contentPadding

    // Track history (stores {title, artist, artUrl} objects)
    property var trackHistory: []
    property int maxHistory: 8
    property bool queueExpanded: false
    property bool debugSkeletons: false
    // Spotify API data
    property var spotifyRecentlyPlayed: []
    property var spotifyQueue: []
    property bool spotifyDataLoading: false

    property var displayRecentlyPlayed: []
    readonly property var displayQueue: spotifyQueue
    readonly property int recentSkeletonCount: debugSkeletons ? 3 : Math.max(0, 3 - displayRecentlyPlayed.length)
    readonly property int queueSkeletonCount: debugSkeletons ? 3 : Math.max(0, 3 - displayQueue.length)

    // Debug info from last merge
    property string debugMergeLog: ""

    function mergeRecentlyPlayed() {
        const now = new Date().toLocaleTimeString()
        let log = "=== MERGE @ " + now + " ===\n"

        // Local MPRIS history minus current track — already ordered old→new
        const local = trackHistory.slice(0, -1)
        log += "\n--- MPRIS trackHistory (" + trackHistory.length + " total, " + local.length + " without current) ---\n"
        for (let i = 0; i < trackHistory.length; i++) {
            const t = trackHistory[i]
            const isCurrent = (i === trackHistory.length - 1)
            log += "  [" + i + "] " + t.title + " - " + t.artist + (isCurrent ? " [CURRENT]" : "") + "\n"
        }

        log += "\n--- Spotify recently_played (" + spotifyRecentlyPlayed.length + ") ---\n"
        for (let i = 0; i < spotifyRecentlyPlayed.length; i++) {
            const s = spotifyRecentlyPlayed[i]
            log += "  [" + i + "] " + s.title + " - " + s.artist + " (uri: " + (s.uri || "none") + ")\n"
        }

        // Build a lookup from Spotify data for enrichment
        const spotifyLookup = {}
        for (let i = 0; i < spotifyRecentlyPlayed.length; i++) {
            const s = spotifyRecentlyPlayed[i]
            const key = (s.title + "|" + s.artist).toLowerCase().trim()
            spotifyLookup[key] = s
        }

        // Enrich local tracks with Spotify metadata
        const seenKeys = new Set()
        const merged = []
        log += "\n--- Enriching local tracks ---\n"
        for (let i = 0; i < local.length; i++) {
            const t = local[i]
            const key = (t.title + "|" + t.artist).toLowerCase().trim()
            seenKeys.add(key)
            const spot = spotifyLookup[key]
            const enriched = {
                title: t.title,
                artist: t.artist,
                artUrl: (spot && spot.artUrl) ? spot.artUrl : (t.artUrl || ""),
                uri: spot ? (spot.uri || "") : "",
                source: spot ? "mpris+spotify" : "mpris"
            }
            merged.push(enriched)
            log += "  [" + i + "] " + t.title + " - " + t.artist + " → " + enriched.source + (spot ? " (matched key: " + key + ")" : "") + "\n"
        }

        // Prepend Spotify-only tracks (older, from before Quickshell started)
        // Spotify API returns newest-first, so reverse for old→new order
        const backfill = []
        log += "\n--- Spotify-only backfill ---\n"
        for (let i = spotifyRecentlyPlayed.length - 1; i >= 0; i--) {
            const s = spotifyRecentlyPlayed[i]
            const key = (s.title + "|" + s.artist).toLowerCase().trim()
            if (!seenKeys.has(key)) {
                seenKeys.add(key)
                backfill.push({
                    title: s.title,
                    artist: s.artist,
                    artUrl: s.artUrl || "",
                    uri: s.uri || "",
                    source: "spotify"
                })
                log += "  + " + s.title + " - " + s.artist + " (backfill)\n"
            } else {
                log += "  - " + s.title + " - " + s.artist + " (already in local, skipped)\n"
            }
        }

        // Backfill goes before local (they're older), then take last 3
        const all = backfill.concat(merged)
        const result = all.slice(Math.max(0, all.length - 3))

        log += "\n--- Final merged list (from " + all.length + ", showing last 3) ---\n"
        for (let i = 0; i < result.length; i++) {
            const r = result[i]
            log += "  [" + i + "] " + r.title + " - " + r.artist + " (" + r.source + ")\n"
        }

        debugMergeLog = log
        console.log(log)
        return result
    }

    onTrackHistoryChanged: displayRecentlyPlayed = mergeRecentlyPlayed()
    onSpotifyRecentlyPlayedChanged: displayRecentlyPlayed = mergeRecentlyPlayed()

    // Spotify API process
    Process {
        id: spotifyProcess
        running: false

        property string currentCommand: ""

        stdout: SplitParser {
            onRead: data => {
                try {
                    const result = JSON.parse(data)
                    if (spotifyProcess.currentCommand === "all") {
                        if (result.recently_played) {
                            root.spotifyRecentlyPlayed = result.recently_played
                        }
                        if (result.queue) {
                            root.spotifyQueue = result.queue
                        }
                        root.spotifyDataLoading = false
                    }
                } catch (e) {
                    console.log("Spotify API parse error:", e)
                    root.spotifyDataLoading = false
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
                console.log("Spotify API error:", data)
            }
        }

        onExited: (code, status) => {
            if (code !== 0) {
                console.log("Spotify API process exited with code", code)
                root.spotifyDataLoading = false
            }
        }
    }

    function refreshSpotifyData() {
        if (root.spotifyDataLoading) return
        root.spotifyDataLoading = true
        spotifyProcess.currentCommand = "all"
        const scriptPath = Qt.resolvedUrl("../spotify_api.py").toString().replace("file://", "")
        spotifyProcess.command = ["python3", scriptPath, "all"]
        spotifyProcess.running = true
    }

    // Auto-fetch disabled for debugging — use manual buttons instead
    // Timer {
    //     id: spotifyRefreshTimer
    //     interval: 60000
    //     repeat: true
    //     running: root.queueExpanded && root.hasPlayer
    //     onTriggered: root.refreshSpotifyData()
    // }
    // onQueueExpandedChanged: {
    //     if (queueExpanded && root.hasPlayer) {
    //         root.refreshSpotifyData()
    //     }
    // }

    // Local position cache, updated by timer
    property real currentPosition: hasPlayer ? player.position : 0

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
                    positionSlider.externalValue = root.trackLength > 0 ? root.player.position / root.trackLength : 0;
                }
            }
        }
    }

    // Track changes → push to history (use postTrackChanged so properties are already updated)
    Connections {
        target: root.player
        enabled: root.hasPlayer

        function onPostTrackChanged() {
            if (!root.hasPlayer) return;
            const title = root.player.trackTitle;
            const artist = root.player.trackArtist;
            const artUrl = root.player.trackArtUrl;
            console.log("[trackHistory] postTrackChanged fired — title:", title, "artist:", artist)

            if (!title) {
                console.log("[trackHistory] skipped: no title")
                return;
            }

            const h = root.trackHistory;
            if (h.length > 0) {
                const last = h[h.length - 1];
                if (last.title === title && last.artist === artist) {
                    console.log("[trackHistory] skipped: duplicate of last entry")
                    return;
                }
            }

            let newHistory = h.slice();
            newHistory.push({ title: title, artist: artist, artUrl: artUrl || "" });
            if (newHistory.length > root.maxHistory + 1)
                newHistory = newHistory.slice(newHistory.length - root.maxHistory - 1);
            root.trackHistory = newHistory;
            console.log("[trackHistory] added:", title, "- total:", newHistory.length)
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

    // Empty state when no player is available
    Rectangle {
        anchors.fill: parent
        radius: Spacing.spacing12
        color: Colors.pillBackground
        border.width: 1
        border.color: Colors.pillBorder
        visible: !root.hasPlayer

        Column {
            anchors.centerIn: parent
            spacing: Spacing.spacing8

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\uf001"
                font.pixelSize: Typography.fontSize20
                color: Colors.textColorMuted
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Keine Wiedergabe"
                font.pixelSize: Typography.fontSize14
                font.weight: Font.Normal
                color: Colors.textColorMuted
            }
        }
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
                    externalValue: root.trackLength > 0 ? root.player.position / root.trackLength : 0

                    onPressedChanged: {
                        if (pressed && root.trackLength > 0) {
                            root.currentPosition = value * root.trackLength;
                        }
                    }

                    onValueChanged: {
                        if (pressed && root.trackLength > 0) {
                            root.currentPosition = value * root.trackLength;
                        }
                    }

                    onMoved: (newValue) => {
                        if (root.hasPlayer && root.player.canSeek && root.trackLength > 0) {
                            root.player.position = newValue * root.trackLength;
                            root.currentPosition = newValue * root.trackLength;
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
                        color: root.canGoPrevious ? Colors.textColor : Colors.textColorMuted
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
                        color: root.canGoNext ? Colors.textColor : Colors.textColorMuted
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

                    ExpandArrow {
                        id: chevronIcon
                        expanded: root.queueExpanded
                        anchors.verticalCenter: parent.verticalCenter
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

            // --- Debug Buttons ---
            Row {
                width: parent.width
                spacing: Spacing.spacing4
                visible: root.queueExpanded

                Item {
                    id: fetchBtn
                    width: (parent.width - 2 * Spacing.spacing4) / 3
                    height: 24

                    property bool hovered: fetchBtnHover.hovered
                    property bool pressed: fetchBtnTap.pressed

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: fetchBtn.pressed ? Colors.hoverItemPressed
                             : fetchBtn.hovered ? Colors.hoverItemHovered
                             : Colors.progressBackground
                        border.color: Colors.pillBorder
                        border.width: 1
                    }

                    Label {
                        anchors.centerIn: parent
                        text: root.spotifyDataLoading ? "Loading..." : "Fetch"
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColor
                    }

                    HoverHandler { id: fetchBtnHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: fetchBtnTap; onTapped: root.refreshSpotifyData() }

                    scale: fetchBtnTap.pressed ? 0.96 : 1.0
                    SquishBehavior on scale {}
                }

                Item {
                    id: clearBtn
                    width: (parent.width - 2 * Spacing.spacing4) / 3
                    height: 24

                    property bool hovered: clearBtnHover.hovered
                    property bool pressed: clearBtnTap.pressed

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: clearBtn.pressed ? Colors.hoverItemPressed
                             : clearBtn.hovered ? Colors.hoverItemHovered
                             : Colors.progressBackground
                        border.color: Colors.pillBorder
                        border.width: 1
                    }

                    Label {
                        anchors.centerIn: parent
                        text: "Clear"
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColor
                    }

                    HoverHandler { id: clearBtnHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: clearBtnTap
                        onTapped: {
                            root.spotifyRecentlyPlayed = []
                            root.spotifyQueue = []
                            root.trackHistory = root.hasPlayer && root.player.trackTitle
                                ? [{ title: root.player.trackTitle, artist: root.player.trackArtist, artUrl: root.player.trackArtUrl || "" }]
                                : []
                            root.debugMergeLog = ""
                        }
                    }

                    scale: clearBtnTap.pressed ? 0.96 : 1.0
                    SquishBehavior on scale {}
                }

                Item {
                    id: logBtn
                    width: (parent.width - 2 * Spacing.spacing4) / 3
                    height: 24

                    property bool hovered: logBtnHover.hovered
                    property bool pressed: logBtnTap.pressed

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: logBtn.pressed ? Colors.hoverItemPressed
                             : logBtn.hovered ? Colors.hoverItemHovered
                             : Colors.progressBackground
                        border.color: Colors.pillBorder
                        border.width: 1
                    }

                    Label {
                        anchors.centerIn: parent
                        text: root.debugMergeLog !== "" ? "Hide Log" : "Show Log"
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColor
                    }

                    HoverHandler { id: logBtnHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: logBtnTap
                        onTapped: {
                            if (root.debugMergeLog !== "") {
                                root.debugMergeLog = ""
                            } else {
                                root.mergeRecentlyPlayed()
                            }
                        }
                    }

                    scale: logBtnTap.pressed ? 0.96 : 1.0
                    SquishBehavior on scale {}
                }
            }

            // --- Expandable Track List ---
            ExpandSection {
                id: trackListWrapper
                expanded: root.queueExpanded

                Column {
                    id: trackListColumn
                    width: parent.width
                    spacing: 0

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

                    // Shared pulse opacity for synchronized skeleton loading
                    QtObject {
                        id: skeletonPulse
                        property real pulseOpacity: 0.4
                        SequentialAnimation on pulseOpacity {
                            running: root.recentSkeletonCount > 0 || root.queueSkeletonCount > 0
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.4; to: 0.7; duration: 1200; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 0.7; to: 0.4; duration: 1200; easing.type: Easing.InOutQuad }
                        }
                    }

                    // Section: Recently Played
                    Column {
                        width: parent.width
                        spacing: Spacing.spacing2

                        // Skeleton placeholders to fill up to 3 items
                        Repeater {
                            model: root.recentSkeletonCount
                            Loader { sourceComponent: skeletonRowComponent; width: trackListColumn.width }
                        }

                        Repeater {
                            model: root.debugSkeletons ? [] : root.displayRecentlyPlayed

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
                                        if (modelData.uri) {
                                            // Play via Spotify URI
                                            console.log("Play Spotify URI:", modelData.uri)
                                        } else {
                                            console.log("Play recent track:", modelData.title)
                                        }
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
                                        source: root.trackArtUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    Rectangle {
                                        width: root.isPlaying ? 26 : 20
                                        height: root.isPlaying ? 18 : 20
                                        radius: root.isPlaying ? Spacing.spacing4 : height / 2
                                        color: Qt.rgba(0, 0, 0, 0.35)
                                        anchors.centerIn: parent

                                        Behavior on width {
                                            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                                        }
                                        Behavior on height {
                                            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                                        }

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
                                        text: root.trackTitle
                                        font.pixelSize: Typography.fontSize14
                                        font.weight: Font.Bold
                                        color: Colors.textColor
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Label {
                                        visible: root.trackArtist !== ""
                                        text: root.trackArtist
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


                        Repeater {
                            model: root.debugSkeletons ? [] : root.displayQueue

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
                                        if (modelData.uri) {
                                            // Play via Spotify URI
                                            console.log("Play Spotify URI:", modelData.uri)
                                        } else {
                                            console.log("Play queued track:", modelData.title)
                                        }
                                    }
                                }

                                scale: queueTap.pressed ? 0.97 : 1.0
                                transformOrigin: Item.Center
                                SquishBehavior on scale {}
                            }
                        }

                        // Skeleton placeholders to fill up to 3 items
                        Repeater {
                            model: root.queueSkeletonCount
                            Loader { sourceComponent: skeletonRowComponent; width: trackListColumn.width }
                        }
                    }
                }
            }
        }
    }

    // Debug overlay — shows merge log at top-left
    Rectangle {
        anchors.top: parent.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        width: 500
        height: debugText.implicitHeight + 16
        radius: 6
        color: "#ee1a1a2e"
        border.width: 1
        border.color: "#444"
        visible: root.debugMergeLog !== ""

        Text {
            id: debugText
            anchors.fill: parent
            anchors.margins: 8
            text: root.debugMergeLog
            font.family: "monospace"
            font.pixelSize: 11
            color: "#88ff88"
            wrapMode: Text.Wrap
        }
    }
}
