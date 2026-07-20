import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"
import "../base"

// FPS bisection harness, toggled by the launcher shortcut while the real
// AppLauncher is disabled in shell.qml.
// STEP 3: BLURRED namespace but a SMALL surface (not fullscreen), to prove the
// blur cost scales with surface area. Anchored top+left with an explicit size.
Scope {
    PanelWindow {
        id: w
        visible: Globals.launcherVisible
        // STEP 4: same small window, but on the notification center's namespace
        // (known 90) instead of quickshell-launcher. Isolates the launcher rule.
        WlrLayershell.namespace: "quickshell"

        anchors {
            top: true
            left: true
        }
        margins {
            top: 200
            left: 400
        }
        implicitWidth: 520
        implicitHeight: 620

        exclusiveZone: 0
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.5)
        }
    }
}
