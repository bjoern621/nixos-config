pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Global Now Playing state: player pick, track history, Spotify fetches, track list.
// Lives here, not in NowPlayingMenu: Bar is per-screen (Variants) and HoverMenu
// builds content eagerly, so a menu-owned copy fetched Spotify once per monitor.
Singleton {
    id: root

    // Prefer a playing player that carries real metadata, then any playing, then
    // paused. Bar picks the same way.
    // A browser media session (Spotify/YouTube web) crams "Title - Artist" into the
    // title and leaves artist + artUrl empty, so a non-empty artist marks the richer
    // source (desktop Spotify). Without this the web player wins the tie and the
    // menu shows a mashed title, no artist/album, and no cover.
    readonly property var player: {
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
    readonly property bool hasPlayer: player !== null
    readonly property string trackTitle: hasPlayer ? player.trackTitle : ""
    readonly property string trackArtist: hasPlayer ? player.trackArtist : ""
    readonly property string trackArtUrl: hasPlayer ? player.trackArtUrl : ""

    readonly property string spotifyScriptPath: Qt.resolvedUrl("../spotify_api.py").toString().replace("file://", "")

    // Last element always current track.
    // Forward change (next, auto-advance) appends.
    // New track matching trackHistory[-2] is a rewind: pop current, do not append.
    // Clicking a recent or queue track plays that URI, which counts as forward.
    property var trackHistory: []
    readonly property int maxHistory: 8

    property var spotifyRecentlyPlayed: []
    property var spotifyQueue: []
    // In-flight guard.
    // Every start reaches an exit, SIGTERM at worst, and every exit clears this.
    property bool spotifyDataLoading: false

    readonly property var displayRecentlyPlayed: _mergeRecentlyPlayed(trackHistory, spotifyRecentlyPlayed)
    readonly property var displayQueue: spotifyQueue.slice(0, 3)
    readonly property int recentSkeletonCount: Math.max(0, 3 - displayRecentlyPlayed.length)
    readonly property int queueSkeletonCount: Math.max(0, 3 - displayQueue.length)

    // Unified track list (recent + current + queue), shared by every screen's menu.
    ListModel {
        id: _trackList
    }

    readonly property alias trackList: _trackList

    // Enriches local MPRIS history with Spotify metadata, prepends tracks played
    // before shell start, returns last 3 old->new.
    // Pure: inputs are arguments, so the binding re-runs when either changes.
    function _mergeRecentlyPlayed(history, spotify) {
        // Local history minus current track, already old->new.
        const local = history.slice(0, -1);

        const spotifyLookup = {};
        for (let i = 0; i < spotify.length; i++) {
            const s = spotify[i];
            spotifyLookup[(s.title + "|" + s.artist).toLowerCase().trim()] = s;
        }

        const seenKeys = new Set();
        const merged = [];
        for (let i = 0; i < local.length; i++) {
            const t = local[i];
            const key = (t.title + "|" + t.artist).toLowerCase().trim();
            seenKeys.add(key);
            const spot = spotifyLookup[key];
            merged.push({
                title: t.title,
                artist: t.artist,
                artUrl: (spot && spot.artUrl) ? spot.artUrl : (t.artUrl || ""),
                uri: spot ? (spot.uri || "") : ""
            });
        }

        // Spotify-only tracks predate shell start.
        // API returns newest-first, so reverse for old->new.
        const backfill = [];
        for (let i = spotify.length - 1; i >= 0; i--) {
            const s = spotify[i];
            const key = (s.title + "|" + s.artist).toLowerCase().trim();
            if (seenKeys.has(key))
                continue;
            seenKeys.add(key);
            backfill.push({
                title: s.title,
                artist: s.artist,
                artUrl: s.artUrl || "",
                uri: s.uri || ""
            });
        }

        // Backfill is older than local history.
        const all = backfill.concat(merged);
        return all.slice(Math.max(0, all.length - 3));
    }

    // Batches rebuilds so history + queue updates in same handler don't double-trigger.
    Timer {
        id: trackListRebuild
        interval: 0
        onTriggered: root._buildTrackList()
    }

    function _rebuildTrackList() {
        trackListRebuild.restart();
    }

    onDisplayRecentlyPlayedChanged: _rebuildTrackList()
    onDisplayQueueChanged: _rebuildTrackList()
    onTrackTitleChanged: _rebuildTrackList()
    onTrackArtUrlChanged: _rebuildTrackList()

    // Builds [recent...] + [current] + [queue...].
    //
    // Spotify queue API returns stale data holding current track when fetch raced a skip.
    // Dedup drops queue entries matching current title+artist.
    // Matches title+artist, not URI: remasters and live versions dedup wrongly.
    // Recent list never needs it, slice(0, -1) already dropped current.
    // Recent and queue are not cross-checked, so a repeated track shows in both.
    function _buildTrackList() {
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
        // Scans full buffer, not displayQueue: a stale entry can sit past index 3.
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
        _syncTrackListModel(_trackList, result);
    }

    // Diffs a JS array into a ListModel so ListView gets proper add/remove/move signals
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

    // spotify_api.py "all" emits {"recently_played": [...], "queue": [...]}.
    Process {
        id: spotifyProcess

        stdout: SplitParser {
            onRead: data => {
                try {
                    const result = JSON.parse(data);
                    if (result.recently_played)
                        root.spotifyRecentlyPlayed = result.recently_played;
                    if (result.queue)
                        root.spotifyQueue = result.queue;
                } catch (e) {
                    // Non-JSON line. Next fetch reconciles.
                }
            }
        }

        // Swallows keyring and API errors. Without a parser they reach the shell log.
        stderr: SplitParser {
            onRead: data => {}
        }

        onExited: {
            spotifyWatchdog.stop();
            // Unconditional: exit 0 without parseable output would latch the flag
            // and kill every later fetch for the session.
            root.spotifyDataLoading = false;
            refreshFlush.restart();
        }
    }

    // keyring calls in spotify_api.py have no timeout; a locked keyring blocks forever.
    // SIGTERM lands in onExited, which does the bookkeeping.
    Timer {
        id: spotifyWatchdog
        interval: 30000
        onTriggered: spotifyProcess.signal(15)
    }

    // Debounces API calls (e.g. spam-clicking next).
    // Requests arriving during cooldown or during an in-flight fetch defer via _pending.
    Timer {
        id: spotifyRefreshCooldown
        interval: 15000
        property bool _pending: false
        onTriggered: root._flushPendingRefresh()
    }

    // Starting a fetch straight from onExited would hit a Process that has not
    // cleared running yet, and assigning command/running on a running Process is a no-op.
    Timer {
        id: refreshFlush
        interval: 0
        onTriggered: root._flushPendingRefresh()
    }

    function refreshSpotifyData() {
        if (spotifyRefreshCooldown.running || root.spotifyDataLoading) {
            spotifyRefreshCooldown._pending = true;
            return;
        }
        _startSpotifyFetch();
    }

    // Deferred refresh runs once cooldown and fetch are both idle. Cooldown expiry and
    // process exit both land here, so whichever comes last starts it.
    function _flushPendingRefresh() {
        if (!spotifyRefreshCooldown._pending || spotifyRefreshCooldown.running || root.spotifyDataLoading)
            return;
        spotifyRefreshCooldown._pending = false;
        _startSpotifyFetch();
    }

    function _startSpotifyFetch() {
        root.spotifyDataLoading = true;
        spotifyProcess.command = ["python3", root.spotifyScriptPath, "all"];
        spotifyProcess.running = true;
        spotifyWatchdog.restart();
        spotifyRefreshCooldown.restart();
    }

    // execDetached, not a Process: assigning command/running on a running Process is a
    // no-op, which drops a second tap while the first play is in flight.
    // Discards the {"success": bool} the script emits; nothing surfaces a failed play.
    function playSpotifyUri(uri) {
        if (!uri)
            return;
        Quickshell.execDetached(["python3", root.spotifyScriptPath, "play", uri]);
    }

    // Track changes push to history. postTrackChanged fires once properties are updated.
    Connections {
        target: root.player
        enabled: root.hasPlayer

        function onPostTrackChanged() {
            if (!root.hasPlayer)
                return;
            const title = root.player.trackTitle;
            const artist = root.player.trackArtist;
            const artUrl = root.player.trackArtUrl;

            if (!title)
                return;

            let h = root.trackHistory.slice();

            // Duplicate of current track (e.g. player restarted at 0:00) -> skip
            if (h.length > 0) {
                const last = h[h.length - 1];
                if (last.title === title && last.artist === artist)
                    return;
            }

            // Rewind: new track matches the entry before current, so pop instead of append
            if (h.length >= 2) {
                const beforeCurrent = h[h.length - 2];
                if (beforeCurrent.title === title && beforeCurrent.artist === artist) {
                    // Capture old current before popping. It goes back into the queue.
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
            h.push({
                title: title,
                artist: artist,
                artUrl: artUrl || ""
            });
            if (h.length > root.maxHistory + 1)
                h = h.slice(h.length - root.maxHistory - 1);
            root.trackHistory = h;

            // Optimistic queue update: the first queue item just became the current track
            if (root.spotifyQueue.length > 0)
                root.spotifyQueue = root.spotifyQueue.slice(1);

            // Real fetch reconciles the optimistic updates.
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
        _buildTrackList();
    }
}
