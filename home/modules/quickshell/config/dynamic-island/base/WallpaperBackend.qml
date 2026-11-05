// WallpaperBackend - Interoperation layer between Globals.wallpaperPath and
// the wallpaper display backend (hyprpaper).
//
// Watches Globals.wallpaperPath and forwards every change to
// `hyprctl hyprpaper wallpaper`, except while Globals.wallpaperPreviewing.
// Swap this file to switch backends without touching any other Quickshell component.

import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    Connections {
        target: Globals
        function onWallpaperPathChanged() { root.applyWallpaper() }
        function onWallpaperPreviewingChanged() { root.applyWallpaper() }
    }

    function applyWallpaper() {
        if (Globals.wallpaperPreviewing || applyProc.running || firstFrameTimer.running)
            return;

        const url = Globals.wallpaperPath.toString();
        const path = url.replace("file://", "");
        if (path.length === 0 || url === Globals.wallpaperApplied.toString())
            return;

        applyProc.target = url;
        applyProc.command = ["hyprctl", "hyprpaper", "wallpaper", "," + path];
        applyProc.running = true;
    }

    Process {
        id: applyProc
        property string target: ""
        // Runs on a failed swap too: a cover waiting on wallpaperApplied would never leave.
        onExited: firstFrameTimer.start()
    }

    // hyprctl returns once hyprpaper opened its new surface, ahead of that surface's first frame.
    Timer {
        id: firstFrameTimer
        interval: 100
        onTriggered: {
            Globals.wallpaperApplied = applyProc.target;
            // Covers a change that arrived during the swap.
            root.applyWallpaper();
        }
    }

    Component.onCompleted: applyWallpaper()
}
