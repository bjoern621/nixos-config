// Keeps Globals.accentColor on the accent of the wallpaper in Globals.wallpaperPath.

import QtQuick

Item {
    id: root
    visible: false

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

    function resolve() {
        // resolver ignores a mid-flight resolve.
        // Re-arm instead.
        if (resolver.busy) {
            resolveTimer.restart();
            return;
        }
        resolver.resolve(root.wallpaper.toString().replace("file://", ""));
    }

    WallpaperAccentResolver {
        id: resolver
        onFinished: (path, color) => {
            if (color.length > 0)
                Globals.accentColor = color;
        }
    }
}
