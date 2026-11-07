import Quickshell.Hyprland
import QtQuick

// On a workspace move between monitors, Hyprland sends no workspacev2.
// Its focusedmon still names the target monitor's previous workspace.
// Quickshell's moveworkspacev2 handler updates the workspace alone.
// Both monitors keep a stale activeWorkspace until j/monitors gets read again.
Connections {
    target: Hyprland

    function onRawEvent(event) {
        if (event.name === "moveworkspacev2")
            Hyprland.refreshMonitors();
    }
}
