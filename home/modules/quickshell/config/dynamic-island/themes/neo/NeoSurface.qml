import QtQuick
import "../../"

// Neobrutalist card: opaque cream paper, ink border, hard offset shadow.
// Set contentWidth/contentHeight to the paper size; the shadow extends beyond by
// shadowOffset, so the total size is contentWidth/Height + shadowOffset.
// Children go into the paper.
Item {
    id: root

    default property alias content: holder.data
    property real contentWidth: 200
    property real contentHeight: 100
    property int shadowOffset: NeoTokens.shadowOffset
    property real radius: NeoTokens.cardRadius
    property color surfaceColor: NeoTokens.paper
    property color borderColor: NeoTokens.ink
    property int borderWidth: NeoTokens.borderWidth

    implicitWidth: contentWidth + shadowOffset
    implicitHeight: contentHeight + shadowOffset
    width: implicitWidth
    height: implicitHeight

    // Hard offset shadow: solid, no blur, down-right.
    Rectangle {
        visible: root.shadowOffset > 0
        x: root.shadowOffset
        y: root.shadowOffset
        width: root.contentWidth
        height: root.contentHeight
        radius: root.radius
        color: root.borderColor
    }

    Rectangle {
        id: paper
        x: 0
        y: 0
        width: root.contentWidth
        height: root.contentHeight
        radius: root.radius
        color: root.surfaceColor
        border.width: root.borderWidth
        border.color: root.borderColor

        Item {
            id: holder
            anchors.fill: parent
        }
    }
}
