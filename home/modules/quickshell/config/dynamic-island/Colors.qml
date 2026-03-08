pragma Singleton
import QtQuick

QtObject {
    // Text colors
    readonly property color textColor: "#ffffff"
    readonly property color textColorMuted: "#aaaaaa"

    // Background colors
    readonly property color backgroundColor: "#111111"
    readonly property color pillBackground: Qt.rgba(0.3, 0.3, 0.3, 0.1)
    readonly property color pillBorder: Qt.rgba(1, 1, 1, 0.2)
    readonly property color separatorColor: Qt.rgba(1, 1, 1, 0.2)
    readonly property color hoverItemHovered: Qt.rgba(1, 1, 1, 0.08)
    readonly property color hoverItemPressed: Qt.rgba(1, 1, 1, 0.15)
    readonly property color osdPillBackground: Qt.rgba(0.12, 0.12, 0.12, 0.88)
    readonly property color osdPillBorder: Qt.rgba(1, 1, 1, 0.18)

    // Accent / progress colors
    readonly property color accentColor: "#45aaf2"
    readonly property color progressBackground: Qt.rgba(1, 1, 1, 0.12)
    readonly property color progressMuted: "#666666"
}
