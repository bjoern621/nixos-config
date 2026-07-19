// Restores Globals.designTheme on startup from
// ~/.local/share/quickshell/current-theme.
// save(theme) persists a new choice.
// Mirrors WallpaperPersist.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Allowed themes. Unknown persisted value falls back to the default.
    readonly property var known: ["classic", "neo"]

    function save(theme) {
        if (known.indexOf(theme) < 0)
            return;
        Globals.designTheme = theme;
        // theme goes in argv, never interpolated.
        saveProc.command = ["bash", "-c", "mkdir -p ~/.local/share/quickshell && printf '%s\\n' \"$1\" > ~/.local/share/quickshell/current-theme", "bash", theme];
        saveProc.running = true;
    }

    Process {
        id: restoreProc
        command: ["bash", "-c", "cat ~/.local/share/quickshell/current-theme 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.length > 0 && Globals.designTheme !== undefined && ThemePersist.known.indexOf(line) >= 0)
                    Globals.designTheme = line;
            }
        }
    }

    Process {
        id: saveProc
    }

    Component.onCompleted: restoreProc.running = true
}
