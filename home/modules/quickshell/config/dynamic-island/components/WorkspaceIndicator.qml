import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../"

Row {
    spacing: Spacing.spacing4
    anchors.verticalCenter: parent.verticalCenter

    Text {
        text: "\uf108"
        font.family: Typography.iconFontFamily
        font.pixelSize: Typography.fontSize14
        color: Colors.textColor
        anchors.verticalCenter: parent.verticalCenter
    }

    Label {
        text: {
            var monitor = Hyprland.focusedMonitor
            if (monitor && monitor.activeWorkspace) {
                return monitor.activeWorkspace.id
            }
            return 1
        }
        anchors.verticalCenter: parent.verticalCenter
    }
}
