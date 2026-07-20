import QtQuick
import "../../"

// Classic power menu: glass card, pill buttons. Behavior via controller.
Item {
    id: root

    property var controller

    readonly property int contentPadding: Spacing.spacing8
    readonly property int buttonWidth: 140
    readonly property int buttonHeight: 36

    implicitWidth: col.implicitWidth + 2 * contentPadding
    implicitHeight: col.implicitHeight + 2 * contentPadding

    Surface {
        anchors.fill: parent

        Column {
            id: col
            x: root.contentPadding
            y: root.contentPadding

            Repeater {
                model: root.controller ? root.controller.actions : []

                StaticButton {
                    required property var modelData
                    width: root.buttonWidth
                    height: root.buttonHeight
                    iconSource: modelData.iconSource
                    label: modelData.label
                    onClicked: root.controller.triggerAction(modelData.action)
                }
            }
        }
    }
}
