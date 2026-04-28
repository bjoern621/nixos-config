pragma Singleton
import QtQuick

QtObject {
    // Backgrounds
    readonly property color background: "#000000"
    readonly property color pillBackground: Qt.rgba(1, 1, 1, 0.06)
    readonly property color pillBackgroundLoading: Qt.rgba(1, 1, 1, 0.10)
    readonly property color pillBorder: Qt.rgba(1, 1, 1, 0.2)
    readonly property color pillBorderFocus: Qt.rgba(1, 1, 1, 0.5)
    readonly property color hoverItemHovered: Qt.rgba(1, 1, 1, 0.08)
    readonly property color hoverItemPressed: Qt.rgba(1, 1, 1, 0.15)

    // Text
    readonly property color textColor: "#ffffff"
    readonly property color textColorMuted: Qt.rgba(1, 1, 1, 0.5)
    readonly property color textError: "#ff5e5e"
}
