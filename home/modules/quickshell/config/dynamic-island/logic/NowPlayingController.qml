import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
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
    readonly property bool canGoNext: hasPlayer && player.canGoNext
    readonly property bool canGoPrevious: hasPlayer && player.canGoPrevious

    // Seconds. 0 while no source reports a length.
    //
    // Spotify publishes mpris:length 0 for a track carrying a Canvas video,
    // and quickshell reads 0 as a supported length,
    // so the scrubber freezes at the left edge,
    // and the total reads 0:00 while the elapsed time keeps counting.
    // The zero arrives with the track's first metadata signal and no later one
    // corrects it, so the latch below cannot fill on such a track.
    //
    // Spotify's embedded chromium session sometimes carries the real number,
    // and the API always does.
    readonly property real trackLength: {
        if (!hasPlayer)
            return 0;
        if (player.lengthSupported && player.length > 0)
            return player.length;
        if (siblingLength > 0)
            return siblingLength;
        if (NowPlayingModel.spotifyCurrentLength > 0)
            return NowPlayingModel.spotifyCurrentLength;
        return lastGoodLength;
    }

    // Length another player reports for what looks like the same track.
    // Sessions shape the title differently ("RESCUER" against "RESCUER - Alex Warren"),
    // so containment decides rather than equality.
    // Two artists that both exist and disagree veto the match,
    // which keeps a browser tab playing a same-named video out of it.
    // The embedded chromium session leaves xesam:artist empty,
    // so a missing artist cannot veto.
    readonly property real siblingLength: {
        if (!hasPlayer || trackTitle === "")
            return 0;
        const mine = trackTitle.toLowerCase();
        const myArtist = trackArtist.toLowerCase();
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            const other = players[i];
            if (other === player || !other.lengthSupported || other.length <= 0)
                continue;
            const title = (other.trackTitle ?? "").toLowerCase();
            if (title === "" || (title.indexOf(mine) < 0 && mine.indexOf(title) < 0))
                continue;
            const artist = (other.trackArtist ?? "").toLowerCase();
            if (myArtist !== "" && artist !== "" && artist !== myArtist)
                continue;
            return other.length;
        }
        return 0;
    }

    // Latched so a player dropping mpris:length mid-track keeps the scrubber alive.
    // Writing it back is loop-free:
    // a positive trackLength re-evaluates to the same value.
    property real lastGoodLength: 0
    onTrackLengthChanged: {
        if (trackLength > 0)
            lastGoodLength = trackLength;
    }
    onTrackTitleChanged: lastGoodLength = 0

    property bool queueExpanded: false

    // Spotify's Web API carries what MPRIS lacks:
    // smart shuffle, and whether the playing context allows shuffle and repeat.
    // null for other players and until the first fetch lands; null reads as unknown.
    readonly property bool isSpotify: hasPlayer && (player.dbusName ?? "").toString() === "org.mpris.MediaPlayer2.spotify"
    readonly property var playback: isSpotify ? NowPlayingModel.spotifyPlayback : null

    // Shuffle. Supported hides the button (player lacks the interface),
    // available greys it (context forbids it: radio, a lone track, a podcast).
    readonly property bool shuffleSupported: hasPlayer && player.shuffleSupported
    readonly property bool shuffleAvailable: shuffleSupported && (!playback || playback.canToggleShuffle)
    // Smart flag counts only while the API snapshot agrees with MPRIS on the plain bit.
    // MPRIS flips at once when shuffle moves in the client;
    // the snapshot lags until the next fetch,
    // and a stale smart flag would show Smart for a moment after it went off.
    readonly property bool shuffleSmart: shuffleAvailable && !!playback && playback.smartShuffle && playback.shuffle === player.shuffle
    readonly property bool shuffleOn: shuffleAvailable && (player.shuffle || shuffleSmart)

    // Off -> On -> Smart -> Off, the cycle of Spotify's own button.
    // MPRIS Shuffle is a bool and the API's shuffle endpoint takes a bool,
    // so Smart is reachable only through the client's control:
    // Ctrl+S delivered to its window cycles like a click on the button.
    // A context without smart shuffle cycles On -> Off on that press, as in Spotify.
    // Off -> On stays on MPRIS: instant, and it needs no window.
    function toggleShuffle() {
        if (!shuffleAvailable)
            return;
        if (shuffleOn && spotifyWindowReachable) {
            WindowFocus.sendShortcut(playerPid, playerWindowNames, "CTRL", "s");
            NowPlayingModel.schedulePlaybackRefresh();
            return;
        }
        player.shuffle = !player.shuffle;
    }

    // Spotify has a mapped window the chord can reach.
    // Closed to its tray the client keeps playing with no toplevel.
    readonly property bool spotifyWindowReachable: {
        if (!isSpotify)
            return false;
        const names = playerWindowNames.map(n => (n ?? "").toString().toLowerCase());
        const toplevels = ToplevelManager.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            if (names.indexOf((toplevels[i].appId ?? "").toLowerCase()) >= 0)
                return true;
        }
        return false;
    }

    // Repeat. Same split as shuffle, one availability flag per repeat state.
    readonly property bool loopSupported: hasPlayer && player.loopSupported
    readonly property bool loopContextAvailable: loopSupported && (!playback || playback.canRepeatContext)
    readonly property bool loopTrackAvailable: loopSupported && (!playback || playback.canRepeatTrack)
    readonly property bool loopAvailable: loopContextAvailable || loopTrackAvailable
    readonly property bool loopOn: loopAvailable && player.loopState !== MprisLoopState.None
    readonly property bool loopTrack: loopAvailable && player.loopState === MprisLoopState.Track

    // None -> Playlist -> Track -> None, skipping a state the context forbids.
    function cycleLoop() {
        if (!loopAvailable)
            return;
        if (!loopOn)
            player.loopState = loopContextAvailable ? MprisLoopState.Playlist : MprisLoopState.Track;
        else if (!loopTrack && loopTrackAvailable)
            player.loopState = MprisLoopState.Track;
        else
            player.loopState = MprisLoopState.None;
    }

    // Window can be brought forward:
    // player answers Raise, or its process owns a Hyprland window.
    readonly property bool canRaise: hasPlayer && (player.canRaise || playerPid > 0)

    // Pid of the app behind this player, read off its audio stream.
    // 0 while the app plays nothing.
    readonly property int playerPid: {
        const props = streamNode?.properties ?? null;
        if (!props)
            return 0;
        const pid = Number(props["application.process.id"]);
        return isFinite(pid) && pid > 0 ? pid : 0;
    }

    // Window-class candidates.
    // dbus tail is "spotify" in "org.mpris.MediaPlayer2.spotify".
    readonly property var playerWindowNames: {
        if (!hasPlayer)
            return [];
        return [player.desktopEntry, player.identity, (player.dbusName ?? "").toString().split(".").pop()];
    }

    // Raise alone loses on Wayland: the client asks the compositor to activate
    // it and Hyprland drops the tokenless request.
    // It still un-minimizes a player sitting in the tray, so both run.
    function raise() {
        if (hasPlayer && player.canRaise)
            player.raise();
        WindowFocus.focusApp(playerPid, playerWindowNames);
    }

    // Playback stream of this player, token-matched. null when app plays no audio.
    readonly property var streamNode: {
        if (!hasPlayer)
            return null;
        const nodes = Pipewire.nodes.values;
        if (!nodes)
            return null;
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n.isStream && n.audio && VolumeService.playerMatchesStream(player, n))
                return n;
        }
        return null;
    }
    readonly property var streamAudio: streamNode?.audio ?? null
    readonly property bool hasVolume: streamAudio !== null
    readonly property int volume: Math.round((streamAudio?.volume ?? 0) * 100)
    readonly property bool volumeMuted: streamAudio?.muted ?? false
    readonly property url volumeIconSource: VolumeService.iconFor(volume, volumeMuted)

    // Stream write gives instant feedback, player write persists.
    // Spotify re-asserts internal volume onto the stream every track,
    // stream-only set is transient. Same 0-1 scale so no compounding.
    function setVolume(v) {
        if (streamAudio)
            streamAudio.volume = v;
        if (hasPlayer && player.volumeSupported)
            player.volume = v;
    }
    // Keeps stream audio data current.
    property PwObjectTracker _streamTracker: PwObjectTracker {
        objects: root.streamNode ? [root.streamNode] : []
    }

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
