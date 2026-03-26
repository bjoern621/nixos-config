import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"
import "../menus"

// Fullscreen loading overlay that captures all input.
// Shows on all screens when LoadingHost.active is true.

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: loadingWindow
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
        WlrLayershell.keyboardFocus: LoadingHost.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        mask: Region {
            item: LoadingHost.active ? fullArea : emptyMask
        }

        Item {
            id: emptyMask
            width: 0
            height: 0
        }

        Item {
            id: fullArea
            anchors.fill: parent

            LoadingScreen {
                id: loadingScreen
                anchors.fill: parent
                showing: LoadingHost.active
                actionLabel: LoadingHost.label

                onCancelled: LoadingHost.hide()
            }
        }
    }
}
