pragma Singleton
import QtQuick

QtObject {
    readonly property int spacing2: 2
    readonly property int spacing4: 4
    readonly property int spacing6: 6
    readonly property int spacing8: 8
    readonly property int spacing12: 12
    readonly property int spacing16: 16
    readonly property int spacing24: 24
    readonly property int spacing40: 40

    // Width a scrolled view gives up on its right so rows clear the scroll bar.
    // Widest bar (neo, 8px) plus breathing room each side. ScrollView reserves it
    // automatically; ListView/GridView consumers subtract it while scrollable.
    readonly property int scrollGutter: 14
}
