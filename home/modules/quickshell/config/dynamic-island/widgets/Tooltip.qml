import QtQuick
import "../"

// Reusable tooltip bubble. Set `text` (and optionally `subtitle`) and toggle
// `showing`. Position the tooltip itself by setting its `x`/`y` (or by
// anchoring); the bubble centers on its own (x, y) origin and animates with
// the standard PopReveal pattern.
//
//   Tooltip {
//       text: hovered.name
//       subtitle: hovered.aliases
//       showing: hovered !== null
//       x: targetCenterX - width / 2
//       y: targetTop - height - Spacing.spacing4
//   }
PopReveal {
    id: root

    property string text: ""
    property string subtitle: ""
    property int maxContentWidth: 260

    showing: text !== ""
    edge: Qt.BottomEdge
    showDuration: 80
    hideDuration: 60

    implicitWidth: bubble.implicitWidth
    implicitHeight: bubble.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        id: bubble
        anchors.fill: parent
        implicitWidth: col.implicitWidth + Spacing.spacing12 * 2
        implicitHeight: col.implicitHeight + Spacing.spacing8 * 2
        radius: Spacing.spacing8
        color: Colors.pillBackground
        border.width: 1
        border.color: Colors.pillBorder

        Column {
            id: col
            anchors.centerIn: parent
            spacing: Spacing.spacing2
            width: Math.min(
                Math.max(titleLabel.implicitWidth, subLabel.implicitWidth),
                root.maxContentWidth)

            Label {
                id: titleLabel
                text: root.text
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Label {
                id: subLabel
                visible: root.subtitle !== ""
                text: root.subtitle
                font.weight: Font.Normal
                font.pixelSize: Typography.fontSize12
                color: Colors.textColorMuted
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
