pragma Singleton
import QtQuick

QtObject {
    // Font families
    readonly property string fontFamily: "Inter"
    readonly property string iconFontFamily: "Font Awesome 7 Free Solid"

    // Font sizes
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeNormal: 13
    readonly property int fontSizeLarge: 16

    // Colors
    readonly property color textColor: "#ffffff"
    readonly property color backgroundColor: "#111111"
}
