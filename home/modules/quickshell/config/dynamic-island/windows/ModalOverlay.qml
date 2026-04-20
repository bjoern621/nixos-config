import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"

Scope {
    id: modalScope

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor;
        if (mon) {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === mon.name)
                    return screens[i];
            }
        }
        return null;
    }

    Connections {
        target: PopupHost
        function onVisibleChanged() {
            if (PopupHost.visible) {
                modalWindow.hideComplete = false;
                const s = modalScope.focusedScreen();
                if (s)
                    modalWindow.screen = s;
            }
        }
    }

    // IPC: qs ipc call popup test
    IpcHandler {
        target: "popup"

        function test() {
            PopupHost.show("../icons/icons8-settings.svg", "Test", "Dies ist eine Testbenachrichtigung.", Colors.textColor);
        }
    }

    PanelWindow {
        id: modalWindow
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
            target: modalReveal
            function onHidden() {
                modalWindow.hideComplete = true;
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

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.3)
                opacity: PopupHost.visible ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutCubic
                    }
                }
            }

            TapHandler {
                onTapped: PopupHost.dismiss()
            }

            PopReveal {
                id: modalReveal
                width: 340
                height: modalCard.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                showing: PopupHost.visible
                slideOffset: 0
                showDuration: 100
                hideDuration: 80

                ModalCard {
                    id: modalCard
                    anchors.fill: parent
                    iconSource: PopupHost.iconSource
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
