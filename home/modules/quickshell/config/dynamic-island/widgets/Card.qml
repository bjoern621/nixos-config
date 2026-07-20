import QtQuick
import ".."

// Theme-aware panel. Classic: glass fill + hairline border, no shadow.
// Neo: cream fill + ink border + hard offset shadow.
// Size the Card; the neo shadow is drawn inside the bottom-right, so the fill
// occupies width/height minus shadowOffset. Children fill the paper.
Item {
    id: root

    default property alias content: holder.data
    property real radius: Shape.cardRadius
    property color fill: Colors.pillBackground
    property color borderColor: Colors.pillBorder
    property int borderWidth: Shape.borderWidth
    // Clip content to the paper so a child bloom stays inside the card.
    property bool clipContent: false

    readonly property int _off: Shape.shadowOffset
    readonly property real paperWidth: width - _off
    readonly property real paperHeight: height - _off

    Rectangle {
        visible: root._off > 0
        x: root._off
        y: root._off
        width: root.paperWidth
        height: root.paperHeight
        radius: root.radius
        color: root.borderColor
    }

    Rectangle {
        x: 0
        y: 0
        width: root.paperWidth
        height: root.paperHeight
        radius: root.radius
        color: root.fill
        border.width: root.borderWidth
        border.color: root.borderColor
        clip: root.clipContent

        Item {
            id: holder
            anchors.fill: parent
        }
    }
}
