import QtQuick
import Quickshell
import Quickshell.Widgets

ShellRoot {
    PanelWindow {
        anchors {
            left: true
            right: true
            top: true
        }

        height: 40
        color: "#1e1e2e"

        Text {
            anchors.centerIn: parent
            text: "Quickshell - Hello from NixOS"
            color: "#cdd6f4"
            font.pixelSize: 14
        }
    }
}
