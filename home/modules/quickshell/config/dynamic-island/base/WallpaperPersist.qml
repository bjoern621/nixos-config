// Restores Globals.wallpaperPath on startup from
// ~/.local/share/quickshell/current-wallpaper.
// save(path) persists a new choice.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    function save(path) {
        Globals.wallpaperPath = "file://" + path;
        // path goes in argv, never interpolated: a filename can hold a quote.
        saveProc.command = ["bash", "-c", "mkdir -p ~/.local/share/quickshell && printf '%s\\n' \"$1\" > ~/.local/share/quickshell/current-wallpaper", "bash", path];
        saveProc.running = true;
    }

    Process {
        id: restoreProc
        command: ["bash", "-c", "cat ~/.local/share/quickshell/current-wallpaper 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.length > 0)
                    Globals.wallpaperPath = "file://" + line;
            }
        }
    }

    Process {
        id: saveProc
    }

    Component.onCompleted: restoreProc.running = true
}
