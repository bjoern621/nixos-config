pragma Singleton
import QtQuick

// Theme-aware structural tokens the flat classic palette never carried.
// borderWidth: main card/panel border. thinBorderWidth: inner tiles, scroll handles.
// shadowOffset: hard offset-shadow distance (0 = no shadow, classic).
// buttonShadowOffset: lighter shadow for buttons, so they sit shallower than their card.
// usesBlur: whether surfaces sit on a blurred layer.
QtObject {
    readonly property var _t: Globals.designTheme === "neo" ? NeoTokens : ClassicTokens

    readonly property bool usesBlur: _t.usesBlur
    readonly property int borderWidth: _t.borderWidth
    readonly property int thinBorderWidth: _t.thinBorderWidth
    readonly property int cardRadius: _t.cardRadius
    readonly property int shadowOffset: _t.shadowOffset
    readonly property int buttonShadowOffset: _t.buttonShadowOffset

    // Pill/button corner radius for a given element size.
    // Classic: dim/2 (fully rounded). Neo: small fixed radius (sharp neobrutalist).
    function pill(dim) {
        return _t.usesBlur ? dim / 2 : _t.pillRadius;
    }
}
