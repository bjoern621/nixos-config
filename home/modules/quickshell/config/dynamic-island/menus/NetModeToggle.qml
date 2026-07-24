import QtQuick
import "../"
import "../base"
import "../animations"

// Neo three-position segment: off | on | airplane. Accent knob slides to the
// active cell; ink glyph on the active cell, muted on the others. Replaces the
// old wifi on/off NetToggle and folds airplane mode into the same control.
Item {
    id: root

    property string mode: "on"   // off | on | airplane
    signal selected(string mode)

    readonly property var _modes: ["off", "on", "airplane"]
    readonly property int _index: Math.max(0, _modes.indexOf(mode))
    // Cell under the cursor (-1 none). Drives per-cell hover feedback.
    property int _hoveredIndex: -1
    readonly property int _inset: Shape.thinBorderWidth
    readonly property real _segW: (width - 2 * _inset) / 3

    implicitWidth: 96
    implicitHeight: 26

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Shape.pill(height)
        color: Colors.progressBackground
        border.width: Shape.thinBorderWidth
        border.color: Colors.pillBorder
    }

    Rectangle {
        id: knob
        width: root._segW
        height: parent.height - 2 * root._inset
        y: root._inset
        x: root._inset + root._index * root._segW
        radius: Math.max(2, Shape.pill(height) - root._inset)
        // Darker accent while the active cell is hovered: distinct on-hover.
        color: root._hoveredIndex === root._index ? Colors.selectedPressed : Colors.selectedBackground
        border.width: Shape.thinBorderWidth
        border.color: Colors.pillBorder

        // Knob slide has no reusable equivalent; slide it directly (see NetToggle).
        Behavior on x {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: root._inset

        Repeater {
            model: root._modes
            Item {
                id: cell
                required property int index
                required property var modelData
                readonly property bool active: root._index === cell.index

                width: root._segW
                height: parent.height

                // Hover wash on inactive cells (matches button hover); active cell
                // darkens its knob instead, so it renders above the knob but hides there.
                Rectangle {
                    anchors.fill: parent
                    radius: knob.radius
                    visible: cellHover.hovered && !cell.active
                    color: Colors.hoverItemHovered
                    border.width: Shape.thinBorderWidth
                    border.color: Colors.pillBorder
                }

                RadioModeGlyph {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    mode: cell.modelData
                    color: cell.active ? Colors.textColor : Colors.textColorMuted
                    scale: tap.pressed ? 0.85 : 1.0
                    SquishBehavior on scale {}
                }

                HoverHandler {
                    id: cellHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: root._hoveredIndex = hovered ? cell.index
                        : (root._hoveredIndex === cell.index ? -1 : root._hoveredIndex)
                }
                TapHandler {
                    id: tap
                    onTapped: root.selected(cell.modelData)
                }
            }
        }
    }
}
