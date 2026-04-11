pragma Singleton
import QtQuick
import "../"

QtObject {
    // Text colors
    readonly property color textColor: "#ffffff"
    readonly property color textColorMuted: "#aaaaaa"

    // Background colors
    readonly property color pillBackground: Qt.rgba(0, 0, 0, 0.5)
    readonly property color pillBorder: Qt.rgba(1, 1, 1, 0.2)
    readonly property color separatorColor: Qt.rgba(1, 1, 1, 0.2)
    readonly property color hoverItemHovered: Qt.rgba((1 - 0.55) + (accentColor.r * 0.55), (1 - 0.55) + (accentColor.g * 0.55), (1 - 0.55) + (accentColor.b * 0.55), 0.08)
    readonly property color hoverItemPressed: Qt.rgba((1 - 0.65) + (accentColor.r * 0.65), (1 - 0.65) + (accentColor.g * 0.65), (1 - 0.65) + (accentColor.b * 0.65), 0.15)

    // Accent / progress colors
    readonly property color calendarToday: "#d5071b"
    readonly property color accentColor: Globals.accentColor
    readonly property color progressBackground: Qt.rgba(1, 1, 1, 0.12)
    readonly property color progressMuted: "#666666"

    // Battery warning colors
    readonly property color batteryWarning: "#e3a600"
    readonly property color batteryCritical: "#c0392b"
}
