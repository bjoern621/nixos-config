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

    // Heavier than Font.* names suggest, across the board.
    readonly property int weightNormal: NeoTokens.weightNormal
    readonly property int weightBold: NeoTokens.weightBold
    readonly property int weightHeavy: NeoTokens.weightHeavy
}
