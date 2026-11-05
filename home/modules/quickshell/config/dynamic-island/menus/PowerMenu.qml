import QtQuick
import "../"

// Thin shell: instantiate controller once, load the view,
// propagate its implicit size to the wrapper.
Item {
    id: root

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0

    PowerController {
        id: controller
    }

    ThemedLoader {
        id: loader
        anchors.fill: parent
        feature: "PowerMenuView"
        controller: controller
    }
}
