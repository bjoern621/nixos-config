import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../"
import "../base"

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

    // Track history
    // History rewind strategy:
    // The last element is always the current track.
    // Forward track changes (next, auto-advance) append.
    // Rewind detection is declarative: when onPostTrackChanged fires and the new track matches trackHistory[-2] (the entry before current), it's a rewind - pop the current track instead of appending. Clicking a recently-played or queue track uses the Spotify API to play that URI directly, which always counts as a forward advance (new play).
    property var trackHistory: []
    property int maxHistory: 8
    property bool queueExpanded: false
    property bool debugToolsEnabled: false
    property bool debugSkeletons: false
    // Spotify API data
    property var spotifyRecentlyPlayed: []
    property var spotifyQueue: []
    property bool spotifyDataLoading: false

    // +1 = forward (next), -1 = backward (prev), 0 = no directional slide
    property int _trackDirection: 0

    property var displayRecentlyPlayed: []
    readonly property var displayQueue: spotifyQueue.slice(0, 3)
    readonly property int recentSkeletonCount: debugSkeletons ? 3 : Math.max(0, 3 - displayRecentlyPlayed.length)
    readonly property int queueSkeletonCount: debugSkeletons ? 3 : Math.max(0, 3 - displayQueue.length)

    // Unified ListModel for animated track list (recent + current + queue)
    ListModel {
        id: trackListModel
    }

    // Batch rebuilds so history + queue updates in the same handler don't double-trigger
    Timer {
        id: unifiedRebuildTimer
        interval: 0
        onTriggered: root._buildUnifiedData()
    }

    function _rebuildTrackList() {
        unifiedRebuildTimer.restart();
    }

    onDisplayRecentlyPlayedChanged: _rebuildTrackList()
    onDisplayQueueChanged: _rebuildTrackList()
    onTrackTitleChanged: _rebuildTrackList()
    onTrackArtUrlChanged: _rebuildTrackList()

    // Builds the unified track list: [recent...] + [current] + [queue...]
    //
    // Queue dedup: the Spotify queue API may return stale data that still
    // includes the currently playing track (e.g. the fetch was in-flight when
    // the user pressed next). We skip any queue entry whose title+artist
    // matches the current track to avoid showing it twice.
    //
    // Known limitations of the dedup:
    // - Only compares against the current track. If the user spams previous
    //   rapidly, multiple optimistic unshifts pile up before the fetch returns.
    //   The stale API response may contain the current track at position > 0
    //   (e.g. index 2 or 3) — the dedup still catches it since it scans the
    //   full buffer, but earlier stale entries (tracks the user already skipped
    //   back past) won't be deduped and may briefly duplicate items in the
    //   recently-played section until the next fetch reconciles.
    // - Matches by title+artist only, not URI. Two different tracks with
    //   identical title+artist (e.g. remasters, live versions) would be
    //   incorrectly deduped, hiding a legitimate queue entry.
    // - Does not dedup recently-played. That list is built from local MPRIS
    //   history (which already excludes the current track via slice(0, -1)),
    //   so duplicates with the current track can't occur there. However,
    //   duplicates between recently-played and queue are not checked — if the
    //   same track appears in both (e.g. on repeat), it shows in both sections.
    function _buildUnifiedData() {
        const result = [];
        const currentKey = hasPlayer && trackTitle ? (trackTitle + "|" + trackArtist).toLowerCase() : "";

        for (let i = 0; i < displayRecentlyPlayed.length; i++) {
            const r = displayRecentlyPlayed[i];
            result.push({
                title: r.title || "",
                artist: r.artist || "",
                artUrl: r.artUrl || "",
                uri: r.uri || "",
                type: "recent"
            });
        }
        if (hasPlayer && trackTitle)
            result.push({
                title: trackTitle,
                artist: trackArtist,
                artUrl: trackArtUrl || "",
                uri: "",
                type: "current"
            });
        // Pull from full buffer, dedup against current, then take first 3
        let queueCount = 0;
        for (let i = 0; i < spotifyQueue.length && queueCount < 3; i++) {
            const q = spotifyQueue[i];
            if ((q.title + "|" + q.artist).toLowerCase() === currentKey)
                continue;
            result.push({
                title: q.title || "",
                artist: q.artist || "",
                artUrl: q.artUrl || "",
                uri: q.uri || "",
                type: "queue"
            });
            queueCount++;
        }
        _syncTrackListModel(trackListModel, result);
    }

    // Diff a JS array into a ListModel so ListView gets proper add/remove/move signals
    function _syncTrackListModel(model, newData) {
        const newKeys = [];
        for (let i = 0; i < newData.length; i++)
            newKeys.push((newData[i].title + "|" + newData[i].artist).toLowerCase());

        // Remove items not in new data (iterate backwards to keep indices stable)
        for (let i = model.count - 1; i >= 0; i--) {
            const item = model.get(i);
            const key = (item.title + "|" + item.artist).toLowerCase();
            if (newKeys.indexOf(key) === -1)
                model.remove(i);
        }

        // Insert, reorder, and update properties
        for (let i = 0; i < newData.length; i++) {
            const d = newData[i];
            const key = (d.title + "|" + d.artist).toLowerCase();

            let found = -1;
            for (let j = i; j < model.count; j++) {
                const item = model.get(j);
                if ((item.title + "|" + item.artist).toLowerCase() === key) {
                    found = j;
                    break;
                }
            }

            if (found === -1) {
                model.insert(i, d);
            } else {
                if (found !== i)
                    model.move(found, i, 1);
                // Update type/artUrl/uri (item may have moved between sections)
                model.set(i, {
                    type: d.type,
                    artUrl: d.artUrl,
                    uri: d.uri
                });
            }
        }
    }

    // Debug info from last merge
    property string debugMergeLog: ""

    function mergeRecentlyPlayed() {
        const now = new Date().toLocaleTimeString();
        let log = "=== MERGE @ " + now + " ===\n";

        // Local MPRIS history minus current track — already ordered old→new
        const local = trackHistory.slice(0, -1);
        log += "\n--- MPRIS trackHistory (" + trackHistory.length + " total, " + local.length + " without current) ---\n";
        for (let i = 0; i < trackHistory.length; i++) {
            const t = trackHistory[i];
            const isCurrent = (i === trackHistory.length - 1);
            log += "  [" + i + "] " + t.title + " - " + t.artist + (isCurrent ? " [CURRENT]" : "") + "\n";
        }

        log += "\n--- Spotify recently_played (" + spotifyRecentlyPlayed.length + ") ---\n";
        for (let i = 0; i < spotifyRecentlyPlayed.length; i++) {
            const s = spotifyRecentlyPlayed[i];
            log += "  [" + i + "] " + s.title + " - " + s.artist + " (uri: " + (s.uri || "none") + ")\n";
        }

        // Build a lookup from Spotify data for enrichment
        const spotifyLookup = {};
        for (let i = 0; i < spotifyRecentlyPlayed.length; i++) {
            const s = spotifyRecentlyPlayed[i];
            const key = (s.title + "|" + s.artist).toLowerCase().trim();
            spotifyLookup[key] = s;
        }

        // Enrich local tracks with Spotify metadata
        const seenKeys = new Set();
        const merged = [];
        log += "\n--- Enriching local tracks ---\n";
        for (let i = 0; i < local.length; i++) {
            const t = local[i];
            const key = (t.title + "|" + t.artist).toLowerCase().trim();
            seenKeys.add(key);
            const spot = spotifyLookup[key];
            const enriched = {
                title: t.title,
                artist: t.artist,
                artUrl: (spot && spot.artUrl) ? spot.artUrl : (t.artUrl || ""),
                uri: spot ? (spot.uri || "") : "",
                source: spot ? "mpris+spotify" : "mpris"
            };
            merged.push(enriched);
            log += "  [" + i + "] " + t.title + " - " + t.artist + " → " + enriched.source + (spot ? " (matched key: " + key + ")" : "") + "\n";
        }

        // Prepend Spotify-only tracks (older, from before Quickshell started)
        // Spotify API returns newest-first, so reverse for old→new order
        const backfill = [];
        log += "\n--- Spotify-only backfill ---\n";
        for (let i = spotifyRecentlyPlayed.length - 1; i >= 0; i--) {
            const s = spotifyRecentlyPlayed[i];
            const key = (s.title + "|" + s.artist).toLowerCase().trim();
            if (!seenKeys.has(key)) {
                seenKeys.add(key);
                backfill.push({
                    title: s.title,
                    artist: s.artist,
                    artUrl: s.artUrl || "",
                    uri: s.uri || "",
                    source: "spotify"
                });
                log += "  + " + s.title + " - " + s.artist + " (backfill)\n";
            } else {
                log += "  - " + s.title + " - " + s.artist + " (already in local, skipped)\n";
            }
        }

        // Backfill goes before local (they're older), then take last 3 for display
        const all = backfill.concat(merged);
        const result = all.slice(Math.max(0, all.length - 3));

        log += "\n--- Final merged list (from " + all.length + ", showing last 3) ---\n";
        for (let i = 0; i < result.length; i++) {
            const r = result[i];
            log += "  [" + i + "] " + r.title + " - " + r.artist + " (" + r.source + ")\n";
        }

        debugMergeLog = log;
        return result;
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
                    const result = JSON.parse(data);
                    if (spotifyProcess.currentCommand === "all") {
                        if (result.recently_played) {
                            root.spotifyRecentlyPlayed = result.recently_played;
                        }
                        if (result.queue) {
                            root.spotifyQueue = result.queue;
                        }
                        root.spotifyDataLoading = false;
                    }
                } catch (e) {
                    root.spotifyDataLoading = false;
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {}
        }

        onExited: (code, status) => {
            if (code !== 0) {
                root.spotifyDataLoading = false;
            }
        }
    }

    // Separate process for play commands — avoids blocking data fetches
    Process {
        id: spotifyPlayProcess
        running: false
    }

    function playSpotifyUri(uri) {
        if (!uri)
            return;
        const scriptPath = Qt.resolvedUrl("../spotify_api.py").toString().replace("file://", "");
        spotifyPlayProcess.command = ["python3", scriptPath, "play", uri];
        spotifyPlayProcess.running = true;
    }

    // Cooldown guard — debounces Spotify API calls (e.g. spam-clicking next)
    Timer {
        id: spotifyRefreshCooldown
        interval: 15000
        onTriggered: {
            if (spotifyRefreshCooldown._pending) {
                spotifyRefreshCooldown._pending = false;
                root._doRefreshSpotifyData();
            }
        }
        property bool _pending: false
    }

    // Fetches all Spotify data (queue + recently played).
    // A 15s cooldown prevents spamming; calls during cooldown are queued and data is fetched once after the cooldown expires.
    function refreshSpotifyData() {
        if (spotifyRefreshCooldown.running) {
            spotifyRefreshCooldown._pending = true;
            return;
        }
        _doRefreshSpotifyData();
    }

    function _doRefreshSpotifyData() {
        if (root.spotifyDataLoading)
            return;
        root.spotifyDataLoading = true;
        spotifyProcess.currentCommand = "all";
        const scriptPath = Qt.resolvedUrl("../spotify_api.py").toString().replace("file://", "");
        spotifyProcess.command = ["python3", scriptPath, "all"];
        spotifyProcess.running = true;
        spotifyRefreshCooldown.restart();
    }

    // Refresh Spotify data when queue is first expanded
    onQueueExpandedChanged: {
        if (queueExpanded && root.hasPlayer) {
            root.refreshSpotifyData();
        }
    }

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
            if (!root.hasPlayer)
                return;
            const title = root.player.trackTitle;
            const artist = root.player.trackArtist;
            const artUrl = root.player.trackArtUrl;

            if (!title) {
                return;
            }

            let h = root.trackHistory.slice();

            // Duplicate of current track (e.g. player restarted at 0:00) → skip
            if (h.length > 0) {
                const last = h[h.length - 1];
                if (last.title === title && last.artist === artist) {
                    return;
                }
            }

            // Declarative rewind detection: if new track matches the entry
            // before current, this is a "go back" — pop instead of append
            if (h.length >= 2) {
                const beforeCurrent = h[h.length - 2];
                if (beforeCurrent.title === title && beforeCurrent.artist === artist) {
                    root._trackDirection = -1;
                    // Capture the old current before popping — it goes back into the queue
                    const oldCurrent = h[h.length - 1];
                    h.pop();
                    root.trackHistory = h;

                    // Optimistic queue update: old current track goes back to front of queue
                    let q = root.spotifyQueue.slice();
                    q.unshift({
                        title: oldCurrent.title,
                        artist: oldCurrent.artist,
                        artUrl: oldCurrent.artUrl || ""
                    });
                    root.spotifyQueue = q;

                    root.refreshSpotifyData();
                    return;
                }
            }

            // Forward advance: append
            root._trackDirection = 1;
            h.push({
                title: title,
                artist: artist,
                artUrl: artUrl || ""
            });
            if (h.length > root.maxHistory + 1)
                h = h.slice(h.length - root.maxHistory - 1);
            root.trackHistory = h;

            // Optimistic queue update: the first queue item just became the current track
            if (root.spotifyQueue.length > 0) {
                root.spotifyQueue = root.spotifyQueue.slice(1);
            }

            // Also trigger a real fetch to reconcile
            root.refreshSpotifyData();
        }
    }

    Component.onCompleted: {
        if (root.hasPlayer && root.player.trackTitle) {
            root.trackHistory = [
                {
                    title: root.player.trackTitle,
                    artist: root.player.trackArtist,
                    artUrl: root.player.trackArtUrl || ""
                }
            ];
        }
        _buildUnifiedData();
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

                    // Squishy pulse on track change
                    scale: 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutBack
                        }
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

                    onMoved: newValue => {
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
                    width: 40
                    height: 40

                    property bool hovered: prevHover.hovered
                    property bool pressed: prevTap.pressed

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: prevBtn.pressed ? Colors.hoverItemPressed : prevBtn.hovered ? Colors.hoverItemHovered : "transparent"
                        border.color: prevBtn.hovered || prevBtn.pressed ? Colors.pillBorder : "transparent"
                    }

                    TintedIcon {
                        anchors.centerIn: parent
                        source: "../icons/icons8-skip-to-start-50.svg"
                        size: Typography.fontSize24
                        color: root.canGoPrevious ? Colors.textColor : Colors.textColorMuted
                    }

                    HoverHandler {
                        id: prevHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        id: prevTap
                        onTapped: {
                            if (root.hasPlayer)
                                root.player.previous();
                        }
                    }

                    scale: prevTap.pressed ? 0.82 : 1.0
                    SquishBehavior on scale {
                        bouncy: true
                        duration: 120
                    }
                }

                // Play/Pause
                Item {
                    id: playBtn
                    width: 40
                    height: 40

                    property bool hovered: playHover.hovered
                    property bool pressed: playTap.pressed

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: playBtn.pressed ? Colors.hoverItemPressed : playBtn.hovered ? Colors.hoverItemHovered : "transparent"
                        border.color: playBtn.hovered || playBtn.pressed ? Colors.pillBorder : "transparent"
                    }

                    ContentReplace {
                        id: playIconReplace
                        contentKey: root.isPlaying ? "../icons/icons8-pause-50.svg" : "../icons/icons8-play-50.svg"
                        anchors.centerIn: parent
                        width: Typography.fontSize24
                        height: Typography.fontSize24

                        Item {
                            width: Typography.fontSize24
                            height: Typography.fontSize24
                            x: 0
                            y: 0

                            TintedIcon {
                                anchors.centerIn: parent
                                source: playIconReplace.displayValue
                                size: Typography.fontSize24
                                color: Colors.textColor
                            }
                        }
                    }

                    HoverHandler {
                        id: playHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        id: playTap
                        onTapped: {
                            if (root.hasPlayer)
                                root.player.togglePlaying();
                        }
                    }

                    scale: playTap.pressed ? 0.82 : 1.0
                    SquishBehavior on scale {
                        bouncy: true
                        duration: 120
                    }
                }

                // Next
                Item {
                    id: nextBtn
                    width: 40
                    height: 40

                    property bool hovered: nextHover.hovered
                    property bool pressed: nextTap.pressed

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: nextBtn.pressed ? Colors.hoverItemPressed : nextBtn.hovered ? Colors.hoverItemHovered : "transparent"
                        border.color: nextBtn.hovered || nextBtn.pressed ? Colors.pillBorder : "transparent"
                    }

                    TintedIcon {
                        anchors.centerIn: parent
                        source: "../icons/icons8-end-50.svg"
                        size: Typography.fontSize24
                        color: root.canGoNext ? Colors.textColor : Colors.textColorMuted
                    }

                    HoverHandler {
                        id: nextHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        id: nextTap
                        onTapped: {
                            if (root.hasPlayer)
                                root.player.next();
                        }
                    }

                    scale: nextTap.pressed ? 0.82 : 1.0
                    SquishBehavior on scale {
                        bouncy: true
                        duration: 120
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
                        source: "../icons/icons8-list.svg"
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
                        collapsedRotation: 90
                        expandedRotation: -90
                        iconSize: Typography.fontSize16
                        iconColor: Colors.textColorMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler {
                    id: queueToggleHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (hovered && !root.queueExpanded) {
                            root.refreshSpotifyData();
                        }
                    }
                }
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
                visible: root.queueExpanded && root.debugToolsEnabled

                Item {
                    id: fetchBtn
                    width: (parent.width - 2 * Spacing.spacing4) / 3
                    height: 24

                    property bool hovered: fetchBtnHover.hovered
                    property bool pressed: fetchBtnTap.pressed

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: fetchBtn.pressed ? Colors.hoverItemPressed : fetchBtn.hovered ? Colors.hoverItemHovered : Colors.progressBackground
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

                    HoverHandler {
                        id: fetchBtnHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        id: fetchBtnTap
                        onTapped: root.refreshSpotifyData()
                    }

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
                        color: clearBtn.pressed ? Colors.hoverItemPressed : clearBtn.hovered ? Colors.hoverItemHovered : Colors.progressBackground
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

                    HoverHandler {
                        id: clearBtnHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        id: clearBtnTap
                        onTapped: {
                            root.spotifyRecentlyPlayed = [];
                            root.spotifyQueue = [];
                            root.trackHistory = root.hasPlayer && root.player.trackTitle ? [
                                {
                                    title: root.player.trackTitle,
                                    artist: root.player.trackArtist,
                                    artUrl: root.player.trackArtUrl || ""
                                }
                            ] : [];
                            root.debugMergeLog = "";
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
                        color: logBtn.pressed ? Colors.hoverItemPressed : logBtn.hovered ? Colors.hoverItemHovered : Colors.progressBackground
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

                    HoverHandler {
                        id: logBtnHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        id: logBtnTap
                        onTapped: {
                            if (root.debugMergeLog !== "") {
                                root.debugMergeLog = "";
                            } else {
                                root.mergeRecentlyPlayed();
                            }
                        }
                    }

                    scale: logBtnTap.pressed ? 0.96 : 1.0
                    SquishBehavior on scale {}
                }
            }

            // --- Fetch Status Indicator ---
            Row {
                width: parent.width
                spacing: Spacing.spacing8
                visible: root.queueExpanded && root.debugToolsEnabled

                // Cooldown countdown
                Rectangle {
                    width: cooldownLabel.implicitWidth + 12
                    height: 20
                    radius: height / 2
                    color: spotifyRefreshCooldown.running ? Colors.hoverItemHovered : Colors.progressBackground
                    border.color: Colors.pillBorder
                    border.width: 1

                    Label {
                        id: cooldownLabel
                        anchors.centerIn: parent
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColor
                        text: spotifyRefreshCooldown.running ? "CD " + Math.ceil(cooldownTick.remaining / 1000) + "s" : "CD —"
                    }

                    Timer {
                        id: cooldownTick
                        interval: 200
                        repeat: true
                        running: spotifyRefreshCooldown.running
                        property real remaining: 0
                        property real startTime: 0
                        onRunningChanged: {
                            if (running) {
                                startTime = Date.now();
                                remaining = spotifyRefreshCooldown.interval;
                            }
                        }
                        onTriggered: {
                            remaining = Math.max(0, spotifyRefreshCooldown.interval - (Date.now() - startTime));
                        }
                    }
                }

                // Pending indicator
                Rectangle {
                    width: pendingLabel.implicitWidth + 12
                    height: 20
                    radius: height / 2
                    color: spotifyRefreshCooldown._pending ? Colors.accentColor : Colors.progressBackground
                    border.color: Colors.pillBorder
                    border.width: 1

                    Label {
                        id: pendingLabel
                        anchors.centerIn: parent
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: spotifyRefreshCooldown._pending ? "#000" : Colors.textColorMuted
                        text: spotifyRefreshCooldown._pending ? "Pending" : "No Pending"
                    }
                }

                // Loading indicator
                Rectangle {
                    width: loadingLabel.implicitWidth + 12
                    height: 20
                    radius: height / 2
                    color: root.spotifyDataLoading ? Colors.accentColor : Colors.progressBackground
                    border.color: Colors.pillBorder
                    border.width: 1

                    Label {
                        id: loadingLabel
                        anchors.centerIn: parent
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: root.spotifyDataLoading ? "#000" : Colors.textColorMuted
                        text: root.spotifyDataLoading ? "Fetching..." : "Idle"
                    }
                }
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

                    // Shared pulse opacity for synchronized skeleton loading
                    QtObject {
                        id: skeletonPulse
                        property real pulseOpacity: 0.4
                        SequentialAnimation on pulseOpacity {
                            running: root.recentSkeletonCount > 0 || root.queueSkeletonCount > 0
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
                        model: root.recentSkeletonCount
                        Loader {
                            sourceComponent: skeletonRowComponent
                            width: trackListColumn.width
                        }
                    }

                    // Unified track list: Recently Played → Current → Queue
                    ListView {
                        id: trackListView
                        width: parent.width
                        height: contentHeight
                        interactive: false
                        clip: true
                        model: root.debugSkeletons ? 0 : trackListModel

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
                                            anchors.centerIn: parent
                                        }

                                        TintedIcon {
                                            visible: !root.isPlaying
                                            anchors.centerIn: parent
                                            source: "../icons/icons8-play-50.svg"
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
                                        root.playSpotifyUri(trackDelegate.uri);
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
                        model: root.queueSkeletonCount
                        Loader {
                            sourceComponent: skeletonRowComponent
                            width: trackListColumn.width
                        }
                    }
                }
            }
        }
    }

    // Debug overlay — shows merge log at top-left
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.left: parent.right
        width: 500
        height: debugText.implicitHeight + 16
        radius: 6
        color: "#ee1a1a2e"
        border.width: 1
        border.color: "#444"
        visible: root.debugToolsEnabled && root.debugMergeLog !== ""

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
