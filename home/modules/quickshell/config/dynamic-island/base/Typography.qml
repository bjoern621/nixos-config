pragma Singleton
import QtQuick

QtObject {
    readonly property string fontFamily: "Inter"
    readonly property int fontSize12: 12
    readonly property int fontSize14: 14
    readonly property int fontSize16: 16
    readonly property int fontSize20: 20
    readonly property int fontSize24: 24
    readonly property int fontSize32: 32

    // Theme-aware weights: neo runs heavier than classic across the board.
    readonly property var _t: Globals.designTheme === "neo" ? NeoTokens : ClassicTokens
    readonly property int weightNormal: _t.weightNormal
    readonly property int weightBold: _t.weightBold
    readonly property int weightHeavy: _t.weightHeavy
}
