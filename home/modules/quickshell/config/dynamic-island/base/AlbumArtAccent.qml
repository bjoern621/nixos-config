pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Dominant accent color of the current track's cover art.
// Singleton: one extraction per track, not once per screen's now-playing menu.
// Feeds only the menu's ambient glow; never writes Globals.accentColor, so the
// rest of the shell keeps its wallpaper accent.
//
// Cover URLs are remote (Spotify i.scdn.co) and magick here has no https
// delegate, so remote art downloads via curl first. Local file:// art extracts
// directly. Accents cache under $HOME/.cache/quickshell/cover-accents/.
Singleton {
    id: root

    // Bloom color. transparent until resolved, and whenever there is no art.
    readonly property color accentColor: _accent
    property color _accent: "transparent"

    readonly property string artUrl: NowPlayingModel.trackArtUrl

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/cover-accents"
    // Single-flight guards below serialize resolves, so one scratch path is safe.
    readonly property string tmpFile: cacheDir + "/.download"

    // Cache path carried per run: a slow extraction must cache under its own cover,
    // not a track that started playing meanwhile. Cache never self-corrects.
    property string _runCachePath: ""

    onArtUrlChanged: resolveTimer.restart()
    Component.onCompleted: resolve()

    Timer {
        id: resolveTimer
        interval: 150
        onTriggered: root.resolve()
    }

    function shellEscape(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    // Last path segment, sans query. Spotify art URLs end in a content hash, so
    // this keys the cache by cover identity. Sanitized for use as a filename.
    function cacheKey(url) {
        let s = url.split("?")[0];
        s = s.substring(s.lastIndexOf("/") + 1);
        return s.replace(/[^A-Za-z0-9._-]/g, "_");
    }

    function cachePath(url) {
        return cacheDir + "/" + cacheKey(url);
    }

    function saveToCache(value, path) {
        cacheSaveProc.command = ["bash", "-c", "mkdir -p " + shellEscape(cacheDir) + " && echo " + shellEscape(value) + " > " + shellEscape(path)];
        cacheSaveProc.running = true;
    }

    // "NONE" caches a cover that yielded no saturated color, so it does not
    // re-extract every open.
    function applyCached(value) {
        root._accent = (value === "NONE" || value === "") ? "transparent" : value;
    }

    function resolve() {
        const url = root.artUrl;
        if (!url) {
            root._accent = "transparent";
            return;
        }
        if (cacheCheckProc.running || downloadProc.running || extractor.busy) {
            resolveTimer.restart();
            return;
        }
        cacheCheckProc.url = url;
        cacheCheckProc.cachePath = root.cachePath(url);
        cacheCheckProc.command = ["bash", "-c", "cat " + shellEscape(cacheCheckProc.cachePath) + " 2>/dev/null || echo 'MISS'"];
        cacheCheckProc.running = true;
    }

    Process {
        id: cacheCheckProc

        property string url: ""
        property string cachePath: ""

        stdout: SplitParser {
            onRead: data => {
                if (data !== "MISS") {
                    root.applyCached(data.trim());
                    return;
                }
                root._runCachePath = cacheCheckProc.cachePath;
                if (cacheCheckProc.url.indexOf("file://") === 0) {
                    extractor.extract(cacheCheckProc.url.replace("file://", ""));
                } else {
                    downloadProc.command = ["bash", "-c", "mkdir -p " + root.shellEscape(root.cacheDir) + " && curl -sfL --max-time 10 " + root.shellEscape(cacheCheckProc.url) + " -o " + root.shellEscape(root.tmpFile)];
                    downloadProc.running = true;
                }
            }
        }
    }

    Process {
        id: downloadProc

        onExited: exitCode => {
            if (exitCode === 0)
                extractor.extract(root.tmpFile);
            // curl failure: leave the glow on its previous color, cache nothing.
            // Next track retries.
        }
    }

    AccentExtractor {
        id: extractor

        onResolved: hex => {
            root.applyCached(hex);
            root.saveToCache(hex === "" ? "NONE" : hex, root._runCachePath);
        }
        // magick failure: hold the previous color, cache nothing.
        onFailed: {}
    }

    Process {
        id: cacheSaveProc
    }
}
