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
    // Playing track as the API reports it. null before the first fetch lands.
    property var spotifyCurrent: null
    // Shuffle, repeat and their availability on the active device:
    // {shuffle, smartShuffle, repeat, canToggleShuffle, canRepeatContext, canRepeatTrack}.
    // null before the first fetch, after a failed one and while no device is active.
    // Consumers read null as unknown and leave every control enabled.
    property var spotifyPlayback: null

    // Track duration in seconds from the API. 0 unless it names the track MPRIS
    // sits on, since a fetch can lag a skip.
    //
    // Spotify's own mpris:length reads 0 for a track carrying a Canvas video,
    // and the API is the only source that always carries the number.
    readonly property real spotifyCurrentLength: {
        const current = spotifyCurrent;
        if (!current || !current.title || !hasPlayer || trackTitle === "")
            return 0;
        if (_key(current) !== _key({ title: trackTitle, artist: trackArtist }))
            return 0;
        const ms = Number(current.durationMs);
        return isFinite(ms) && ms > 0 ? ms / 1000 : 0;
    }
    readonly property bool spotifyDataLoading: allFetch.loading

    readonly property var displayRecentlyPlayed: _mergeRecentlyPlayed(trackHistory, spotifyRecentlyPlayed)

    // Rendered row counts from the last build. Skeletons size to these, not to
    // the raw arrays: dedup can drop a row, and a raw count then shows rows and
    // skeletons for the same slots together.
    property int builtRecentCount: 0
    property int builtQueueCount: 0
    // Skeletons only while a fetch runs. A queue that is genuinely short
    // (end of playlist) gets no placeholder.
    readonly property int recentSkeletonCount: spotifyDataLoading ? Math.max(0, 3 - builtRecentCount) : 0
    readonly property int queueSkeletonCount: spotifyDataLoading ? Math.max(0, 3 - builtQueueCount) : 0

    // Identity key. title+artist, not uri: history entries carry no uri, and
    // remaster/live variants of one track differ in uri.
    function _key(t) {
        return (t.title + "|" + t.artist).toLowerCase().trim();
    }

    // Uri for a track present in a Spotify payload; "" when unseen.
    function _uriFor(title, artist) {
        const key = _key({ title: title, artist: artist });
        const pools = [spotifyQueue, spotifyRecentlyPlayed];
        for (let p = 0; p < pools.length; p++) {
            for (let i = 0; i < pools[p].length; i++) {
                const t = pools[p][i];
                if (_key(t) === key && t.uri)
                    return t.uri;
            }
        }
        return "";
    }

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
            spotifyLookup[_key(s)] = s;
        }

        const seenKeys = new Set();
        const merged = [];
        for (let i = 0; i < local.length; i++) {
            const t = local[i];
            const key = _key(t);
            seenKeys.add(key);
            const spot = spotifyLookup[key];
            merged.push({
                title: t.title,
                artist: t.artist,
                artUrl: (spot && spot.artUrl) ? spot.artUrl : (t.artUrl || ""),
                uri: (spot && spot.uri) ? spot.uri : (t.uri || "")
            });
        }

        // Spotify-only tracks predate shell start.
        // API returns newest-first, so reverse for old->new.
        const backfill = [];
        for (let i = spotify.length - 1; i >= 0; i--) {
            const s = spotify[i];
            const key = _key(s);
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
    onSpotifyQueueChanged: _rebuildTrackList()
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
        const currentKey = hasPlayer && trackTitle ? _key({ title: trackTitle, artist: trackArtist }) : "";

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
        // Scans the full buffer: a stale entry can sit past index 3.
        let queueCount = 0;
        for (let i = 0; i < spotifyQueue.length && queueCount < 3; i++) {
            const q = spotifyQueue[i];
            if (_key(q) === currentKey)
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
        builtRecentCount = displayRecentlyPlayed.length;
        builtQueueCount = queueCount;
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

        // Surplus copies of a duplicated key survive the remove phase (key still
        // present) and are never matched by the placement loop, so they collect
        // past the end with stale roles. Drop the tail.
        while (model.count > newData.length)
            model.remove(model.count - 1);
    }

    // spotify_api.py "all" emits {"recently_played", "queue", "current", "playback"}.
    SpotifyFetch {
        id: allFetch
        subcommand: "all"
        scriptPath: root.spotifyScriptPath
        cooldown: 5000
        onPayload: result => root._applyPayload(result)
    }

    // "playback" alone emits {"playback": {...}|null}.
    // The "all" cooldown is too slow for a menu that just opened
    // or a shuffle press whose smart flag only the API reports.
    SpotifyFetch {
        id: playbackFetch
        subcommand: "playback"
        scriptPath: root.spotifyScriptPath
        cooldown: 1500
        onPayload: result => root._applyPayload(result)
    }

    function _applyPayload(result) {
        if (result.recently_played)
            root.spotifyRecentlyPlayed = result.recently_played;
        if (result.queue)
            root.spotifyQueue = result.queue;
        // Assigned even when null: a payload without a playing track
        // has to clear the previous one.
        if (result.current !== undefined)
            root.spotifyCurrent = result.current;
        if (result.playback !== undefined)
            root.spotifyPlayback = result.playback;
    }

    function refreshSpotifyData() {
        allFetch.request();
    }

    function refreshPlaybackState() {
        playbackFetch.request();
    }

    // Playback refresh once the client has reported a change to Spotify's backend.
    // Follows a shuffle or repeat press, and the MPRIS signal for one.
    function schedulePlaybackRefresh() {
        playbackSettle.restart();
    }

    Timer {
        id: playbackSettle
        interval: 700
        onTriggered: playbackFetch.request()
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

        // Shuffle or repeat moved in the client.
        // The API snapshot behind the smart flag and the disallows lags the MPRIS signal.
        function onShuffleChanged() {
            root.schedulePlaybackRefresh();
        }
        function onLoopStateChanged() {
            root.schedulePlaybackRefresh();
        }

        function onPostTrackChanged() {
            if (!root.hasPlayer)
                return;
            const title = root.player.trackTitle;
            const artist = root.player.trackArtist;
            const artUrl = root.player.trackArtUrl;

            if (!title)
                return;

            const key = root._key({ title: title, artist: artist });
            let h = root.trackHistory.slice();

            // Duplicate of current track (e.g. player restarted at 0:00) -> skip
            if (h.length > 0 && root._key(h[h.length - 1]) === key)
                return;

            // Rewind: new track anywhere in history, any number of steps back
            // (previous spam, click on an older recent row). Nearest match wins,
            // so a track played twice rewinds to its latest occurrence.
            let idx = -1;
            for (let i = h.length - 2; i >= 0; i--) {
                if (root._key(h[i]) === key) {
                    idx = i;
                    break;
                }
            }
            if (idx >= 0) {
                // Everything after the target returns to the queue front in
                // play order; old current lands deepest.
                const returned = h.slice(idx + 1).map(t => ({
                    title: t.title,
                    artist: t.artist,
                    artUrl: t.artUrl || "",
                    uri: t.uri || root._uriFor(t.title, t.artist)
                }));
                root.trackHistory = h.slice(0, idx + 1);
                root.spotifyQueue = returned.concat(root.spotifyQueue);
                root.refreshSpotifyData();
                return;
            }

            // Forward: drop the played entry and everything jumped past from the
            // queue (click on the second-next row skips two, not one). Jumped-past
            // tracks never played, so they do not enter history. A track absent
            // from the queue (radio, other device) leaves it untouched; the
            // refetch reconciles.
            // Uri lookup precedes the slice: it drops the played entry from the pool.
            const uri = root._uriFor(title, artist);
            const q = root.spotifyQueue;
            for (let i = 0; i < q.length; i++) {
                if (root._key(q[i]) === key) {
                    root.spotifyQueue = q.slice(i + 1);
                    break;
                }
            }

            h.push({
                title: title,
                artist: artist,
                artUrl: artUrl || "",
                uri: uri
            });
            if (h.length > root.maxHistory + 1)
                h = h.slice(h.length - root.maxHistory - 1);
            root.trackHistory = h;

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
