import Quickshell
import Quickshell.Hyprland._GlobalShortcuts
import Quickshell.Io
import QtQuick
import "../"

// Brightness OSD.
// Brightness changes only from XF86MonBrightness keybinds
// (home/modules/hyprland/brightness-keys.nix), which run brightnessctl then notify this shell.
// Polling brightnessctl at 10 Hz instead spawns it ~864k times a day.
Scope {
    id: brightnessScope

    property int brightness: 0
    // Read requested while another was in flight.
    // See showOsd.
    property bool rereadPending: false

    // Seed at start, else the first keypress shows 0, not the real level.
    Component.onCompleted: brightnessProc.running = true

    // Shows first, reads after: the pill is up within a frame, and its bar animates
    // to the real level when brightnessctl lands, well inside the 120ms fill animation.
    function showOsd() {
        osd.showOsd();
        if (brightnessProc.running) {
            // Process ignores running=true while running.
            // In-flight read predates this keypress, so read again once it exits.
            brightnessScope.rereadPending = true;
            return;
        }
        brightnessProc.running = true;
    }

    Process {
        id: brightnessProc
        command: ["brightnessctl", "-m"]

        stdout: SplitParser {
            onRead: data => {
                // device,class,current,percentage%,max
                const parts = data.split(",");
                if (parts.length < 4)
                    return;
                const pct = parseInt(parts[3]);
                if (!isNaN(pct))
                    brightnessScope.brightness = Math.max(0, Math.min(100, pct));
            }
        }

        onExited: {
            if (brightnessScope.rereadPending)
                rereadTimer.start();
        }
    }

    // Re-arms the read outside brightnessProc's own exit handler.
    Timer {
        id: rereadTimer
        interval: 0
        onTriggered: {
            brightnessScope.rereadPending = false;
            brightnessProc.running = true;
        }
    }

    // Hyprland routes the keybind here through `hyprctl dispatch 'hl.dsp.global(...)'`,
    // reaching this running process.
    // `qs ipc call` cold-starts a Qt binary per keypress (~125ms),
    // which the OSD would sit behind.
    GlobalShortcut {
        appid: "quickshell"
        name: "brightness"
        description: "Show the brightness OSD"
        onPressed: brightnessScope.showOsd()
    }

    // IPC: qs ipc call brightness show
    IpcHandler {
        target: "brightness"
        function show() {
            brightnessScope.showOsd();
        }
    }

    OsdWindow {
        id: osd
        iconSource: "../icons/icons8-brightness.svg"
        label: "Helligkeit"
        value: brightnessScope.brightness
        valueLabel: brightnessScope.brightness + " %"
    }
}
