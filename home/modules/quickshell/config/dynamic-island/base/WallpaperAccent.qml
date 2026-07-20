// Extracts an accent color from the wallpaper via AccentExtractor.
// Caches per wallpaper under $HOME/.cache/quickshell/wallpaper-accents/,
// so later loads skip magick. Writes the shell-wide Globals.accentColor.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/wallpaper-accents"

    // Arrow-key nav in the chooser reassigns Globals.wallpaperPath per keypress.
    // Each resolve costs a cache read plus a magick histogram run.
    onWallpaperChanged: resolveTimer.restart()

    Component.onCompleted: resolve()

    Timer {
        id: resolveTimer
        interval: 150
        onTriggered: root.resolve()
    }

    // Local property, not Globals.wallpaperPath directly: onWallpaperChanged needs one here.
    readonly property url wallpaper: Globals.wallpaperPath

    function wallpaperFile() {
        return root.wallpaper.toString().replace("file://", "");
    }

    function cacheFile() {
        const path = wallpaperFile();
        const name = path.substring(path.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "");
        return cacheDir + "/" + name;
    }

    function shellEscape(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    function saveToCache(value, path) {
        cacheSaveProc.command = ["bash", "-c", "mkdir -p " + shellEscape(cacheDir) + " && echo " + shellEscape(value) + " > " + shellEscape(path)];
        cacheSaveProc.running = true;
    }

    // Cache path carried through the async extraction so a slower run caches under
    // its own wallpaper, not a newer selection. Cache never self-corrects.
    property string _runCachePath: ""

    function resolve() {
        // Process.running ignores a write of true while running, so a mid-flight resolve is dropped.
        // Re-arm instead.
        if (cacheCheckProc.running || extractor.busy) {
            resolveTimer.restart();
            return;
        }
        // Target captured per run, carried through extraction.
        cacheCheckProc.target = wallpaperFile();
        cacheCheckProc.cachePath = cacheFile();
        cacheCheckProc.command = ["bash", "-c", "cat " + shellEscape(cacheCheckProc.cachePath) + " 2>/dev/null || echo 'MISS'"];
        cacheCheckProc.running = true;
    }

    Process {
        id: cacheCheckProc

        property string target: ""
        property string cachePath: ""

        stdout: SplitParser {
            onRead: data => {
                if (data === "MISS") {
                    root._runCachePath = cacheCheckProc.cachePath;
                    extractor.extract(cacheCheckProc.target);
                } else {
                    Globals.accentColor = data.trim();
                }
            }
        }
    }

    AccentExtractor {
        id: extractor

        // No saturated color survives: fall back to white, matching a bare shell.
        onResolved: hex => {
            const color = hex === "" ? Globals.defaultAccentColor.toString() : hex;
            Globals.accentColor = color;
            root.saveToCache(color, root._runCachePath);
        }
        onFailed: console.warn("[WallpaperAccent] magick failed")
    }

    Process {
        id: cacheSaveProc
    }
}
