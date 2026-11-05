pragma Singleton
import QtQuick

// Structural tokens.
// borderWidth: main card/panel border. thinBorderWidth: inner tiles, scroll handles.
// shadowOffset: hard offset-shadow distance.
// buttonShadowOffset: lighter shadow for buttons, so they sit shallower than their card.
// pillRadius: sharp pill/button corner, never fully rounded.
QtObject {
    readonly property int borderWidth: NeoTokens.borderWidth
    readonly property int thinBorderWidth: NeoTokens.thinBorderWidth
    readonly property int cardRadius: NeoTokens.cardRadius
    readonly property int shadowOffset: NeoTokens.shadowOffset
    readonly property int buttonShadowOffset: NeoTokens.buttonShadowOffset
    readonly property int pillRadius: NeoTokens.pillRadius
}
