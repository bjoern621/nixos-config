import QtQuick
import QtQuick.Effects

// Soft color bloom. Blurs a rounded fill in place so the color radiates outward.
// Sits behind the now-playing card for the album-art cinema glow.
// Fill the glow to the whole padded area and inset the blurred source to the
// card's footprint (sourceInset), so the bloom bleeds out past the card edges.
Item {
    id: root

    // Bloom target. Alpha 0 fades the bloom out; a real color fades/crossfades in.
    property color glowColor: "transparent"
    property real sourceRadius: 12
    // Margin from the glow's edge to the blurred fill. Set to the card bleed so
    // the fill matches the card and the blur spreads into the surrounding ring.
    property real sourceInset: 0
    property int blurMax: 64
    // Peak opacity of the bloom.
    property real intensity: 0.6

    readonly property bool _active: glowColor.a > 0.004

    // Held color, updated only from real colors, so a fade-out keeps the last hue
    // instead of crossfading toward transparent black. Seeded at completion since
    // onGlowColorChanged does not fire for a binding-set initial value.
    // Tests glowColor.a directly, not _active: on a glowColor change QML may run
    // this handler before re-evaluating the _active binding, so _active can still
    // read its stale value here.
    property color _shown: "transparent"
    onGlowColorChanged: if (glowColor.a > 0.004)
        _shown = glowColor
    Component.onCompleted: if (glowColor.a > 0.004)
        _shown = glowColor

    // Alpha 0 collapses the bloom; a real color fades it in. Fade-out runs opacity,
    // not the color, so the hue never crossfades toward transparent black.
    opacity: _active ? intensity : 0
    Behavior on opacity {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    // Blurred in place via layer.effect: a plain Rectangle is only a texture
    // provider while its layer renders, so it stays visible and the effect draws it.
    Rectangle {
        id: src
        anchors.fill: parent
        anchors.margins: root.sourceInset
        radius: root.sourceRadius
        color: root._shown
        antialiasing: true

        Behavior on color {
            ColorAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: root.blurMax
            autoPaddingEnabled: true
        }
    }
}
