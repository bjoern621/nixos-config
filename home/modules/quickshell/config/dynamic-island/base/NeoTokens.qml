pragma Singleton
import QtQuick

// Neobrutalist token table: opaque cream paper, ink borders, hard offset shadow.
// Lifted from the launcher's inline `theme` object.
// Selection/accent pulls the wallpaper accent (Globals.accentColor); everything
// else is fixed cream/ink. Semantic battery colors stay shared with classic.
QtObject {
    readonly property color paper: "#fffdf5"
    readonly property color ink: "#111111"
    readonly property color hoverPaper: "#f0eede"

    // Color (mapped onto the classic token names the facade exposes)
    readonly property color textColor: ink
    readonly property color textColorMuted: "#3a382f"
    readonly property color pillBackground: paper
    readonly property color pillBorder: ink
    readonly property color separatorColor: ink
    // Hover feedback: faint accent wash over paper (parallels classic's accent tint).
    // Opaque result: Qt.tint composites over the opaque paper base, no alpha.
    readonly property color hoverItemHovered: Qt.tint(paper, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18))
    readonly property color hoverItemPressed: Qt.tint(paper, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.30))
    // Selected/active item background: solid accent, like the launcher selection.
    readonly property color selectedBackground: accentColor
    readonly property color selectedPressed: accentPressed
    readonly property color calendarToday: accentColor
    readonly property color accentColor: Globals.accentColor
    readonly property color progressBackground: "#e2e0cd"
    readonly property color progressMuted: "#7a7768"
    readonly property color batteryWarning: "#fed330"
    readonly property color batteryCritical: "#fc5c65"
    // "Now" tick on the weather timeline. Same red in both themes (semantic, like battery).
    readonly property color nowMarker: "#f01e2c"

    // Selection pills darken the accent on press.
    readonly property color accentPressed: Qt.darker(accentColor, 1.12)
    readonly property color placeholder: "#7a7768"

    // Shape
    readonly property bool usesBlur: false
    readonly property int borderWidth: 3
    readonly property int thinBorderWidth: 2
    readonly property int cardRadius: 6
    readonly property int shadowOffset: 7
    // Buttons carry a lighter shadow than their containing card, roughly half.
    readonly property int buttonShadowOffset: 4
    // Sharp neobrutalist pills/buttons, never fully rounded.
    readonly property int pillRadius: 5

    // Type weights
    readonly property int weightNormal: Font.DemiBold
    readonly property int weightBold: Font.ExtraBold
    readonly property int weightHeavy: Font.Black
}
