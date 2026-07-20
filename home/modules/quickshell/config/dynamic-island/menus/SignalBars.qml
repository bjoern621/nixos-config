import QtQuick
import "../base"

// Four-bar wifi signal strength. level 0-3 lights index 0..level.
// Two-tone (lit ink, dim wash) so strength reads at a glance, which a single
// colorized SVG cannot show.
Row {
    id: root

    property int level: 0
    property color litColor: Colors.textColor
    property color dimColor: Qt.rgba(Colors.textColor.r, Colors.textColor.g, Colors.textColor.b, 0.22)
    property int barHeight: 16

    spacing: 2
    height: barHeight

    Repeater {
        model: 4
        Rectangle {
            required property int index
            width: 3
            radius: 1
            height: root.barHeight * (0.35 + index * 0.2167)
            // Bottom-align via y: a Repeater delegate's `parent` is transiently
            // null, so `anchors.bottom: parent.bottom` throws during creation.
            y: root.barHeight - height
            color: index <= root.level ? root.litColor : root.dimColor
        }
    }
}
