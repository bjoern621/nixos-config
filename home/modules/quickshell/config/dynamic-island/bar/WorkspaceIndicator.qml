import Quickshell.Hyprland
import QtQuick
import "../"
import "../base"

Row {
    id: root

    spacing: Spacing.spacing4
    anchors.verticalCenter: parent.verticalCenter

    property string monitorName: ""

    // Hyprland.monitors.values, monitor.name, monitor.activeWorkspace and
    // workspace.id each carry NOTIFY, so this binding re-runs on its own.
    // A Hyprland.rawEvent tick would re-run it on windowtitle too, which fires
    // continuously for a terminal running a build.
    // Workspace3Apps duplicates this. Dedupe needs a shared type in qmldir.
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

    TintedIcon {
        source: "../icons/icons8-desktop.svg"
        size: Typography.fontSize20
        anchors.verticalCenter: parent.verticalCenter
    }

    Label {
        text: root.activeWorkspaceId
        anchors.verticalCenter: parent.verticalCenter
    }
}
