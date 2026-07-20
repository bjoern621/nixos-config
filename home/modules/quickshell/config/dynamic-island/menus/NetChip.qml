import QtQuick
import "../"
import "../base"
import "../animations"

// Small labeled press-button for row-detail actions and the menu footer.
// Neo: ink-bordered block, accent when active, danger for destructive actions.
Item {
    id: root

    property alias text: label.text
    property bool active: false
    property bool danger: false
    property url iconSource: ""
    signal clicked

    readonly property color _accent: root.danger ? Colors.batteryCritical : Colors.selectedBackground

    implicitHeight: 28
    implicitWidth: content.implicitWidth + Spacing.spacing12 * 2

    scale: tap.pressed ? 0.94 : 1.0
    SquishBehavior on scale {}

    Rectangle {
        anchors.fill: parent
        radius: Shape.pill(height)
        color: tap.pressed ? Qt.darker(root._accent, 1.12) : root.active ? root._accent : hover.hovered ? Colors.hoverItemHovered : Colors.pillBackground
        border.width: Shape.thinBorderWidth
        border.color: root.danger ? Colors.batteryCritical : Colors.pillBorder
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Spacing.spacing4

        TintedIcon {
            visible: root.iconSource != ""
            source: root.iconSource
            size: Typography.fontSize12
            color: root.danger ? Colors.batteryCritical : Colors.textColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Label {
            id: label
            font.pixelSize: Typography.fontSize12
            color: root.danger ? Colors.batteryCritical : Colors.textColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: tap
        onTapped: root.clicked()
    }
}
