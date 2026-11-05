pragma Singleton
import QtQuick

// Color facade over NeoTokens.
QtObject {
    // Text colors
    readonly property color textColor: NeoTokens.textColor
    readonly property color textColorMuted: NeoTokens.textColorMuted
    readonly property color placeholder: NeoTokens.placeholder

    // Background colors
    readonly property color pillBackground: NeoTokens.pillBackground
    readonly property color pillBorder: NeoTokens.pillBorder
    readonly property color separatorColor: NeoTokens.separatorColor
    readonly property color hoverItemHovered: NeoTokens.hoverItemHovered
    readonly property color hoverItemPressed: NeoTokens.hoverItemPressed
    readonly property color selectedBackground: NeoTokens.selectedBackground
    readonly property color selectedPressed: NeoTokens.selectedPressed

    // Accent / progress colors
    readonly property color calendarSelected: NeoTokens.calendarSelected
    readonly property color calendarSelectedText: NeoTokens.calendarSelectedText
    readonly property color calendarSelectedHovered: NeoTokens.calendarSelectedHovered
    readonly property color accentColor: NeoTokens.accentColor
    readonly property color progressBackground: NeoTokens.progressBackground
    readonly property color progressMuted: NeoTokens.progressMuted

    // Battery warning colors
    readonly property color batteryWarning: NeoTokens.batteryWarning
    readonly property color batteryCritical: NeoTokens.batteryCritical

    // Weather timeline "now" tick
    readonly property color nowMarker: NeoTokens.nowMarker
}
