import Quickshell
import QtQuick

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: powerCorner
        required property var modelData
        screen: modelData

        anchors {
            top: true
            right: true
        }

        exclusiveZone: 0
        color: "transparent"

        implicitWidth: powerMenuView.implicitWidth + 24
        implicitHeight: powerMenuView.implicitHeight + 24

        mask: Region {
            item: powerInteractionZone
        }

        readonly property bool shouldShowMenu: cornerHover.hovered || powerMenuWrapper.keepOpen

        onShouldShowMenuChanged: {
            console.log("shouldShowMenu changed:", shouldShowMenu)
            if (shouldShowMenu) {
                powerMenuWrapper.show()
            } else {
                powerMenuWrapper.hide()
            }
        }

        Item {
            id: powerInteractionZone
            anchors.top: parent.top
            anchors.right: parent.right
            width: powerMenuWrapper.visible ? powerMenuView.implicitWidth + 16 : 8
            height: powerMenuWrapper.visible ? powerMenuView.implicitHeight + 16 : 8
        }

        Item {
            id: cornerTrigger
            width: 8
            height: 8
            anchors.top: parent.top
            anchors.right: parent.right

            HoverHandler {
                id: cornerHover
            }
        }

        HoverMenu {
            id: powerMenuWrapper
            width: powerMenuView.implicitWidth
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 8

            PowerMenu {
                id: powerMenuView
                width: implicitWidth
                height: implicitHeight
            }
        }
    }
}
