// WallpaperPersist - Handles saving and restoring the wallpaper path.
// On startup, reads ~/.local/share/quickshell/current-wallpaper and sets
// Globals.wallpaperPath. Call save(path) to persist a new wallpaper choice.

import QtQuick
import Quickshell.Io

Item {
    visible: false

    function save(path) {
        Globals.wallpaperPath = "file://" + path;
        saveProc.command = ["bash", "-c", "mkdir -p ~/.local/share/quickshell && echo '" + path + "' > ~/.local/share/quickshell/current-wallpaper"];
        saveProc.running = true;
    }

    Process {
        id: restoreProc
        command: ["bash", "-c", "cat ~/.local/share/quickshell/current-wallpaper 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.length > 0) {
                    console.log("[WallpaperPersist] restored: " + line);
                    Globals.wallpaperPath = "file://" + line;
                }
            }
        }
    }

    Process {
        id: saveProc
    }

    Component.onCompleted: restoreProc.running = true
}
