// Draws the chooser's selected wallpaper on each screen, crossfading between selections.
// hyprpaper replaces its surface per wallpaper, which flashes misc:background_color.
// Bottom layer: hyprpaper's rebuilt Background surface stays below, windows and the chooser above.
// The cover outlasts the chooser until hyprpaper shows the applied wallpaper.

import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: previewWindow

        required property var modelData

        component PreviewSlot: Image {
            anchors.fill: parent
            opacity: 0
            z: this === previewWindow.back ? 1 : 0
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(previewWindow.modelData.width * previewWindow.modelData.devicePixelRatio, previewWindow.modelData.height * previewWindow.modelData.devicePixelRatio)

            onStatusChanged: {
                if (status === Image.Ready && this === previewWindow.back)
                    previewWindow.crossfade();
            }
        }

        // Slot on screen.
        property Image front: slotA
        // Slot loading the next selection, fades in above front.
        property Image back: slotB

        readonly property string frontSource: front.source.toString()
        readonly property string wallpaper: Globals.wallpaperPath.toString()
        readonly property bool hyprpaperBehind: wallpaper !== Globals.wallpaperApplied.toString()
        // Empty lets hyprpaper through.
        readonly property string wanted: Globals.wallpaperPreviewing || (frontSource !== "" && hyprpaperBehind) ? wallpaper : ""

        onWantedChanged: advance()

        function advance() {
            if (fade.running)
                return;
            if (wanted === frontSource) {
                back.source = "";
            } else if (wanted === "") {
                fade.target = front;
                fade.to = 0;
                fade.start();
            } else {
                back.source = wanted;
                crossfade();
            }
        }

        function crossfade() {
            if (fade.running || back.status !== Image.Ready || back.source.toString() !== wanted)
                return;
            fade.target = back;
            fade.to = 1;
            fade.start();
        }

        function onFadeFinished() {
            if (fade.to === 0) {
                front.source = "";
            } else {
                const previous = front;
                front = back;
                back = previous;
                previous.source = "";
                previous.opacity = 0;
            }
            advance();
        }

        screen: modelData
        visible: frontSource !== "" || back.source.toString() !== ""

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell-noblur"
        color: "transparent"

        mask: Region {
            item: emptyMask
        }

        Item {
            id: emptyMask
            width: 0
            height: 0
        }

        PreviewSlot {
            id: slotA
        }

        PreviewSlot {
            id: slotB
        }

        NumberAnimation {
            id: fade
            property: "opacity"
            duration: 200
            easing.type: Easing.OutCubic
            onFinished: previewWindow.onFadeFinished()
        }
    }
}
