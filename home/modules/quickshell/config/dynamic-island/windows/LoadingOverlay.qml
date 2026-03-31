import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"
import "../menus"

// Fullscreen loading overlay that captures all input.
// Shows on all screens when LoadingHost.active or GracefulShutdown.active is true.
// Displays ShutdownScreen for shutdown/reboot, LoadingScreen for other actions.

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: loadingWindow

        readonly property bool isActive: LoadingHost.active || GracefulShutdown.active
        visible: isActive || !hideComplete
        property bool hideComplete: true
        required property var modelData
        screen: modelData

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        exclusiveZone: 0
        focusable: true
        WlrLayershell.keyboardFocus: loadingWindow.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        mask: Region {
            item: loadingWindow.isActive ? fullArea : emptyMask
        }

        Connections {
            target: LoadingHost
            function onActiveChanged() {
                if (LoadingHost.active)
                    loadingWindow.hideComplete = false;
            }
        }

        Connections {
            target: GracefulShutdown
            function onActiveChanged() {
                if (GracefulShutdown.active)
                    loadingWindow.hideComplete = false;
            }
        }

        Item {
            id: emptyMask
            width: 0
            height: 0
        }

        Item {
            id: fullArea
            anchors.fill: parent

            // Generic loading screen (lock, etc.)
            LoadingScreen {
                id: loadingScreen
                anchors.fill: parent
                showing: LoadingHost.active
                actionLabel: LoadingHost.label

                onCancelled: LoadingHost.hide()
                onHidden: if (!GracefulShutdown.active) loadingWindow.hideComplete = true
            }

            // Shutdown/reboot screen with app list
            ShutdownScreen {
                id: shutdownScreen
                anchors.fill: parent
                showing: GracefulShutdown.active

                onCancelled: loadingWindow.hideComplete = true
                onHidden: loadingWindow.hideComplete = true
            }
        }
    }
}
