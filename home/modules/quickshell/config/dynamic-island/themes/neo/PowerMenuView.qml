import QtQuick
import "../../"

// Neo power menu: cream card with offset shadow, bordered block buttons.
// Behavior via controller.
Item {
    id: root

    property var controller

    readonly property int pad: 10
    readonly property int buttonWidth: 200
    readonly property int buttonHeight: 44
    readonly property int gap: 8

    implicitWidth: surface.implicitWidth
    implicitHeight: surface.implicitHeight

    NeoSurface {
        id: surface
        contentWidth: root.buttonWidth + 2 * root.pad
        contentHeight: col.implicitHeight + 2 * root.pad

        Column {
            id: col
            x: root.pad
            y: root.pad
            spacing: root.gap

            Repeater {
                model: root.controller ? root.controller.actions : []

                NeoButton {
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
