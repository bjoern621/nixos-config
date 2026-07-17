pragma Singleton
import QtQuick

QtObject {
    // Text colors
    readonly property color textColor: "#ffffff"
    readonly property color textColorMuted: "#aaaaaa"

    // Background colors
    readonly property color pillBackground: Qt.rgba(0, 0, 0, 0.5)
    readonly property color pillBorder: Qt.rgba(1, 1, 1, 0.2)
    readonly property color separatorColor: Qt.rgba(1, 1, 1, 0.2)
    readonly property color hoverItemHovered: Qt.rgba((1 - 0.75) + (accentColor.r * 0.75), (1 - 0.75) + (accentColor.g * 0.75), (1 - 0.75) + (accentColor.b * 0.75), 0.12)
    readonly property color hoverItemPressed: Qt.rgba((1 - 0.75) + (accentColor.r * 0.75), (1 - 0.75) + (accentColor.g * 0.75), (1 - 0.75) + (accentColor.b * 0.75), 0.19)

    // Accent / progress colors
    readonly property color calendarToday: "#d5071b"
    readonly property color accentColor: Globals.accentColor
    readonly property color progressBackground: Qt.rgba(1, 1, 1, 0.12)
    readonly property color progressMuted: "#666666"

    // Battery warning colors
    readonly property color batteryWarning: "#fed330"
    readonly property color batteryCritical: "#fc5c65"
}
