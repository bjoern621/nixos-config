import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../"
import "../base"
import "../widgets"

// Launches the workspace-3 apps (Spotify + Discord) which are intentionally
// kept out of autostart. Only shown while workspace 3 is active and at least
// one of the two apps is still missing; clicking opens whichever is not yet
// running. Disappears once both are open.
HoverItem {
    id: root

    property string monitorName: ""

    clickable: true
    pressedScale: 0.85

    // Hyprland.monitors.values, monitor.name, monitor.activeWorkspace and
    // workspace.id each carry NOTIFY, so this binding re-runs on its own.
    // A Hyprland.rawEvent tick would re-run it on windowtitle too, which fires
    // continuously for a terminal running a build.
    // WorkspaceIndicator duplicates this. Dedupe needs a shared type in qmldir.
    readonly property int activeWorkspaceId: {
        const monitors = Hyprland.monitors.values;
        for (let i = 0; i < monitors.length; i++) {
            if (monitors[i].name === root.monitorName && monitors[i].activeWorkspace)
                return monitors[i].activeWorkspace.id;
        }
        const monitor = Hyprland.focusedMonitor;
        if (monitor && monitor.activeWorkspace)
            return monitor.activeWorkspace.id;
        return 1;
    }

    // Open-state comes from the Wayland toplevel list, which is reactive and
    // carries a reliable appId (Hyprland's lastIpcObject is not populated).
    function hasClient(appId) {
        var toplevels = ToplevelManager.toplevels.values;
        for (var i = 0; i < toplevels.length; i++) {
            if (toplevels[i].appId === appId)
                return true;
        }
        return false;
    }

    readonly property bool spotifyOpen: hasClient("spotify")
    readonly property bool discordOpen: hasClient("discord")

    visible: root.activeWorkspaceId === 3 && !(root.spotifyOpen && root.discordOpen)

    onClicked: {
        if (!root.spotifyOpen)
            Quickshell.execDetached(["uwsm", "app", "--", "spotify.desktop"]);
        if (!root.discordOpen)
            Quickshell.execDetached(["uwsm", "app", "--", "discord.desktop"]);
    }

    TintedIcon {
        source: "../icons/icons8-play.svg"
        size: Typography.fontSize20
        anchors.verticalCenter: parent.verticalCenter
    }
}
