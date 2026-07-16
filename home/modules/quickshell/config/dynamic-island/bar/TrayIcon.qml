import QtQuick
import QtQuick.Effects
import "../"

// Renders a StatusNotifierItem or menu icon. Items supply their icon either as
// a freedesktop theme name (image://icon/<name>) or as a bitmap sent over D-Bus
// (image://qspixmap/…, image://qsimage/…); Quickshell resolves both into a
// single image url, so this only has to decide on colour.
//
// `mode` picks how:
//   "auto"  keep the icon's own colours, except symbolic ones (see below)
//   "color" never tint
//   "tint"  always flatten to `color`
//
// Symbolic icons are the reason "auto" is not simply "color". By freedesktop
// convention a `-symbolic` icon is a near-black monochrome glyph that whoever
// draws it is expected to recolour, so left alone it disappears against a dark
// bar. Only theme icons can be symbolic; a bitmap sent by an app never is.
Item {
    id: root

    property url source
    property int size: Typography.fontSize16
    property color color: Colors.textColor

    property string mode: "auto"

    readonly property bool symbolic: {
        const url = String(root.source);
        const scheme = "image://icon/";
        if (!url.startsWith(scheme))
            return false;
        return url.slice(scheme.length).split("?")[0].endsWith("-symbolic");
    }

    readonly property bool tinted: root.mode === "tint" || (root.mode === "auto" && root.symbolic)

    // Tray icons are small and often come from a much larger source bitmap, so
    // rasterize above the display size to keep the downscale sharp.
    property real sourceScale: 2.0

    width: size
    height: size

    Image {
        id: iconImage
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(Math.round(root.width * root.sourceScale), Math.round(root.height * root.sourceScale))
        fillMode: Image.PreserveAspectFit
        smooth: true
        antialiasing: true
        asynchronous: true

        // Hidden in tinted mode: MultiEffect draws it instead.
        visible: !root.tinted

        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    MultiEffect {
        anchors.fill: iconImage
        source: iconImage
        visible: root.tinted
        colorization: 1.0
        colorizationColor: root.color
    }
}
