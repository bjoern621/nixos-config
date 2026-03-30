// WallpaperBackend - Interoperation layer between Globals.wallpaperPath and
// the wallpaper display backend (currently hyprpaper).
//
// Watches Globals.wallpaperPath and forwards every change to
// `hyprctl hyprpaper wallpaper`.  Swap this file to switch backends
// without touching any other Quickshell component.

import QtQuick
import Quickshell.Io
import "../"

Item {
    id: root
    visible: false

    Connections {
        target: Globals
        function onWallpaperPathChanged() { root.applyWallpaper() }
    }

    function applyWallpaper() {
        const url = Globals.wallpaperPath.toString();
        const path = url.replace("file://", "");
        if (path.length === 0)
            return;

        console.log("[WallpaperBackend] applying: " + path);
        applyProc.command = ["hyprctl", "hyprpaper", "wallpaper", "," + path];
        applyProc.running = true;
    }

    Process {
        id: applyProc
        stdout: SplitParser {
            onRead: data => console.log("[WallpaperBackend] " + data)
        }
    }

    Component.onCompleted: applyWallpaper()
}
