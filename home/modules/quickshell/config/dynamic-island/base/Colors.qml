pragma Singleton
import QtQuick

// Theme-aware color facade.
// Property names are stable; values resolve from the active token table so every
// `Colors.*` reference tracks Globals.designTheme with no per-call-site change.
QtObject {
    readonly property var _t: Globals.designTheme === "neo" ? NeoTokens : ClassicTokens

    // Text colors
    readonly property color textColor: _t.textColor
    readonly property color textColorMuted: _t.textColorMuted
    readonly property color placeholder: _t.placeholder

    // Background colors
    readonly property color pillBackground: _t.pillBackground
    readonly property color pillBorder: _t.pillBorder
    readonly property color separatorColor: _t.separatorColor
    readonly property color hoverItemHovered: _t.hoverItemHovered
    readonly property color hoverItemPressed: _t.hoverItemPressed
    readonly property color selectedBackground: _t.selectedBackground
    readonly property color selectedPressed: _t.selectedPressed

    // Accent / progress colors
    readonly property color calendarToday: _t.calendarToday
    readonly property color accentColor: _t.accentColor
    readonly property color progressBackground: _t.progressBackground
    readonly property color progressMuted: _t.progressMuted

    // Battery warning colors
    readonly property color batteryWarning: _t.batteryWarning
    readonly property color batteryCritical: _t.batteryCritical
}
