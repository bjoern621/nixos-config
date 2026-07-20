pragma Singleton
import QtQuick

// Classic (translucent glass) token table.
// Full set of color + shape + type tokens the Colors/Shape/Typography facades read.
// Only accentColor is dynamic (wallpaper-derived via Globals).
QtObject {
    // Color
    readonly property color textColor: "#ffffff"
    readonly property color textColorMuted: "#aaaaaa"
    readonly property color placeholder: "#aaaaaa"
    readonly property color pillBackground: Qt.rgba(0, 0, 0, 0.5)
    readonly property color pillBorder: Qt.rgba(1, 1, 1, 0.2)
    readonly property color separatorColor: Qt.rgba(1, 1, 1, 0.2)
    readonly property color hoverItemHovered: Qt.rgba((1 - 0.75) + (accentColor.r * 0.75), (1 - 0.75) + (accentColor.g * 0.75), (1 - 0.75) + (accentColor.b * 0.75), 0.12)
    readonly property color hoverItemPressed: Qt.rgba((1 - 0.75) + (accentColor.r * 0.75), (1 - 0.75) + (accentColor.g * 0.75), (1 - 0.75) + (accentColor.b * 0.75), 0.19)
    // Selected/active item background (classic: accent tint; neo: solid accent).
    readonly property color selectedBackground: hoverItemPressed
    readonly property color selectedPressed: hoverItemPressed
    readonly property color calendarToday: "#d5071b"
    readonly property color accentColor: Globals.accentColor
    readonly property color progressBackground: Qt.rgba(1, 1, 1, 0.12)
    readonly property color progressMuted: "#666666"
    readonly property color batteryWarning: "#fed330"
    readonly property color batteryCritical: "#fc5c65"

    // Shape
    readonly property bool usesBlur: true
    readonly property int borderWidth: 1
    readonly property int thinBorderWidth: 1
    readonly property int cardRadius: 12
    readonly property int shadowOffset: 0
    readonly property int buttonShadowOffset: 0
    // Large so Shape.pill(dim) clamps to dim/2 (fully rounded pills).
    readonly property int pillRadius: 9999

    // Type weights
    readonly property int weightNormal: Font.Normal
    readonly property int weightBold: Font.Bold
    readonly property int weightHeavy: Font.Bold
}
