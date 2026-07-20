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
    readonly property int gap: 4

    implicitWidth: surface.implicitWidth
    implicitHeight: surface.implicitHeight

    // Each button footprint = face + its own offset shadow.
    readonly property int shadowOffset: NeoTokens.shadowOffset

    NeoSurface {
        id: surface
        contentWidth: root.buttonWidth + root.shadowOffset + 2 * root.pad
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
                    width: root.buttonWidth + root.shadowOffset
                    height: root.buttonHeight + root.shadowOffset
                    iconSource: modelData.iconSource
                    label: modelData.label
                    onClicked: root.controller.triggerAction(modelData.action)
                }
            }
        }
    }
}
