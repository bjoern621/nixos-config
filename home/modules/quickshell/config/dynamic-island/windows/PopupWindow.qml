import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"

// Displays dismissable popup notifications from the PopupHost singleton queue.
// Also provides an IPC handler for sending test popups.
Scope {
    id: popupScope

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor
        if (mon) {
            const screens = Quickshell.screens
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === mon.name)
                    return screens[i]
            }
        }
        return null
    }

    Connections {
        target: PopupHost
        function onVisibleChanged() {
            if (PopupHost.visible) {
                popupWindow.hideComplete = false
                const s = popupScope.focusedScreen()
                if (s) popupWindow.screen = s
            }
        }
    }

    // IPC: qs ipc call popup test
    IpcHandler {
        target: "popup"

        function test() {
            PopupHost.show(
                "\uf0a2",
                "Test",
                "Dies ist eine Testbenachrichtigung.",
                Colors.textColor
            )
        }
    }

    PanelWindow {
        id: popupWindow
        visible: PopupHost.visible || !hideComplete
        property bool hideComplete: true

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        exclusiveZone: 0
        focusable: true
        WlrLayershell.keyboardFocus: PopupHost.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        mask: Region {
            item: PopupHost.visible ? fullArea : emptyMask
        }

        Connections {
            target: popupReveal
            function onHidden() { popupWindow.hideComplete = true }
        }

        Item {
            id: emptyMask
            width: 0
            height: 0
        }

        Item {
            id: fullArea
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.3)
                opacity: PopupHost.visible ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }
            }

            TapHandler {
                onTapped: PopupHost.dismiss()
            }

            PopReveal {
                id: popupReveal
                width: 340
                height: notification.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                showing: PopupHost.visible
                slideOffset: 0
                showDuration: 100
                hideDuration: 80

                PopupNotification {
                    id: notification
                    anchors.fill: parent
                    icon: PopupHost.icon
                    title: PopupHost.title
                    message: PopupHost.message
                    accentColor: PopupHost.accentColor
                    onDismissed: PopupHost.dismiss()
                }
            }

            Keys.onEscapePressed: PopupHost.dismiss()
        }
    }
}
