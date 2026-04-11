import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../"
import "../base"

Row {
    spacing: Spacing.spacing4
    anchors.verticalCenter: parent.verticalCenter

    property string monitorName: ""

    TintedIcon {
        source: "../icons/icons8-desktop.svg"
        size: Typography.fontSize20
        anchors.verticalCenter: parent.verticalCenter
    }

    Label {
        text: {
            var monitors = Hyprland.monitors.values;
            for (var i = 0; i < monitors.length; i++) {
                if (monitors[i].name === monitorName && monitors[i].activeWorkspace) {
                    return monitors[i].activeWorkspace.id;
                }
            }
            // Fallback to focused monitor
            var monitor = Hyprland.focusedMonitor;
            if (monitor && monitor.activeWorkspace) {
                return monitor.activeWorkspace.id;
            }
            return 1;
        }
        anchors.verticalCenter: parent.verticalCenter
    }
}
