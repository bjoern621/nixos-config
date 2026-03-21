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

        implicitWidth: powerMenuView.implicitWidth + Spacing.spacing24
        implicitHeight: powerMenuView.implicitHeight + Spacing.spacing24

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
            width: powerMenuWrapper.visible ? powerMenuView.implicitWidth + Spacing.spacing16 : Spacing.spacing8
            height: powerMenuWrapper.visible ? powerMenuView.implicitHeight + Spacing.spacing16 : Spacing.spacing8
        }

        Item {
            id: cornerTrigger
            width: Spacing.spacing8
            height: Spacing.spacing8
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
            anchors.topMargin: Spacing.spacing8
            anchors.rightMargin: Spacing.spacing8

            PowerMenu {
                id: powerMenuView
                width: implicitWidth
                height: implicitHeight
            }
        }
    }
}
