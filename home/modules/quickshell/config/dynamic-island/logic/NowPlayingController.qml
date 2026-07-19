import QtQuick
import Quickshell.Services.Mpris
import ".."

// Now-playing behavior: player passthrough, position polling, seek, queue state.
// View binds to this and holds no logic.
// Side-effecting global state (Spotify fetch, history) lives in NowPlayingModel.
QtObject {
    id: root

    // Set by view, forwarded from Bar.
    property var player: null
    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: hasPlayer && player.playbackState === MprisPlaybackState.Playing

    // Null-check player once here, not at every UI call site.
    readonly property string trackTitle: hasPlayer ? player.trackTitle : ""
    readonly property string trackArtist: hasPlayer ? player.trackArtist : ""
    readonly property string trackAlbum: hasPlayer ? player.trackAlbum : ""
    readonly property string trackArtUrl: hasPlayer ? player.trackArtUrl : ""
    readonly property real trackLength: hasPlayer ? player.length : 0
    readonly property bool canGoNext: hasPlayer && player.canGoNext
    readonly property bool canGoPrevious: hasPlayer && player.canGoPrevious

    property bool queueExpanded: false

    // Position: two writers, one reader.
    // _syncPolledPosition writes polledPosition, seek handlers write seekPosition.
    // currentPosition binds over both; nothing writes it imperatively.
    // Imperative write kills the binding for good, stranding the scrubber on the
    // previous track once paused.
    property real polledPosition: 0
    property real seekPosition: 0
    // Suppresses player-driven updates after a seek, else slider snaps back.
    property bool seekInProgress: false
    // View mirrors the slider press state here.
    property bool sliderPressed: false
    readonly property bool seekActive: sliderPressed || seekInProgress
    readonly property real currentPosition: seekActive ? seekPosition : polledPosition

    // MPRIS position poll-only, so every source of truth re-reads it.
    function _syncPolledPosition() {
        root.polledPosition = root.hasPlayer && root.player.positionSupported ? root.player.position : 0;
    }

    onPlayerChanged: _syncPolledPosition()
    Component.onCompleted: _syncPolledPosition()

    onQueueExpandedChanged: {
        if (queueExpanded && hasPlayer)
            NowPlayingModel.refreshSpotifyData();
    }

    function formatTime(seconds) {
        if (seconds <= 0 || !isFinite(seconds))
            return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Transport.
    function togglePlaying() {
        if (hasPlayer)
            player.togglePlaying();
    }
    function next() {
        if (hasPlayer)
            player.next();
    }
    function previous() {
        if (hasPlayer)
            player.previous();
    }

    // Seek: view drives fraction 0..1.
    // setSeekFraction tracks the drag, commitSeek writes player + guards snap-back.
    function setSeekFraction(fraction) {
        if (trackLength > 0)
            root.seekPosition = fraction * trackLength;
    }
    function commitSeek(fraction) {
        if (hasPlayer && player.canSeek && trackLength > 0) {
            root.player.position = fraction * trackLength;
            root.seekPosition = fraction * trackLength;
            root.seekInProgress = true;
            seekGuardTimer.restart();
        }
    }

    // Queue toggle + hover prefetch: fill before expand so open shows data, not skeletons.
    function toggleQueue() {
        root.queueExpanded = !root.queueExpanded;
    }
    function prefetchQueue() {
        if (!queueExpanded)
            NowPlayingModel.refreshSpotifyData();
    }
    function playUri(uri) {
        if (uri)
            NowPlayingModel.playSpotifyUri(uri);
    }

    // Player had time to apply seek. Re-read before handing slider back.
    property Timer _seekGuardTimer: Timer {
        id: seekGuardTimer
        interval: 500
        onTriggered: {
            root._syncPolledPosition();
            root.seekInProgress = false;
        }
    }

    property Timer _positionTimer: Timer {
        id: positionTimer
        interval: 250
        repeat: true
        running: root.isPlaying
        onTriggered: root._syncPolledPosition()
    }

    // postTrackChanged fires once properties update. Without it the scrubber keeps
    // the old track's position while paused, since positionTimer is stopped.
    property Connections _playerConn: Connections {
        target: root.player
        enabled: root.hasPlayer
        function onPostTrackChanged() {
            root._syncPolledPosition();
        }
    }
}
