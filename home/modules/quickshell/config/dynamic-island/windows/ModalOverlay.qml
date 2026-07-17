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

        // Screen is picked before the surface maps.
        // Flipping hideComplete first maps the window on the old output.
        function onAboutToShow() {
            const s = modalScope.focusedScreen();
            if (s)
                modalWindow.screen = s;
            modalWindow.hideComplete = false;
        }

        // Layer surface takes keyboard focus on map, but the event still needs
        // an item holding focus to reach fullArea's Keys handler.
        function onVisibleChanged() {
            if (PopupHost.visible)
                fullArea.focus = true;
        }
    }

    // IPC: qs ipc call popup test
    IpcHandler {
        target: "popup"

        function test() {
            PopupHost.show("../icons/icons8-bell.svg", "Test", "Dies ist eine Testbenachrichtigung.", Colors.textColor);
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
            // Keys handlers below are dead without item focus: nothing else in
            // modalWindow takes it, so events stop at the window contentItem.
            focus: true

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

            // Covers the card too, and ModalCard's buttons take passive grabs
            // only, so a tap on the card reaches this handler as well.
            // Hit test excludes the card instead of an absorbing MouseArea:
            // dismissBtn sits in front of such a MouseArea and the press never
            // reaches it, leaving card-button taps dismissing through here.
            TapHandler {
                onTapped: function (eventPoint) {
                    if (!modalReveal.contains(modalReveal.mapFromItem(null, eventPoint.scenePosition)))
                        PopupHost.dismiss();
                }
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
