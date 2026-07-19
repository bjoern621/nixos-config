pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "../"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: notifCorner
        required property var modelData
        screen: modelData

        // Behavior only: history, DND, clear, D-Bus passthroughs.
        NotificationCenterController {
            id: controller
        }

        anchors.bottom: true
        anchors.right: true
        exclusiveZone: 0
        color: "transparent"

        implicitWidth: 320 + Spacing.spacing24
        implicitHeight: 560 + Spacing.spacing24

        mask: Region {
            item: interactionZone
        }

        readonly property bool shouldShow: cornerHover.hovered || panelHover.hovered

        Rectangle {
            id: interactionZone
            color: "transparent"
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: centerReveal.visible ? centerPanel.implicitWidth + Spacing.spacing16 : Spacing.spacing8
            height: centerReveal.visible ? centerPanel.implicitHeight + Spacing.spacing16 : Spacing.spacing8
        }

        Item {
            width: Spacing.spacing8
            height: Spacing.spacing8
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            HoverHandler {
                id: cornerHover
            }
        }

        PopReveal {
            id: centerReveal
            showing: notifCorner.shouldShow
            edge: Qt.BottomEdge | Qt.RightEdge
            transformOriginValue: Item.BottomRight
            showDuration: 80
            hideDuration: 80

            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.bottomMargin: Spacing.spacing8
            anchors.rightMargin: Spacing.spacing8

            width: centerPanel.implicitWidth
            height: centerPanel.implicitHeight

            HoverHandler {
                id: panelHover
            }

            // Theme-aware panel: classic glass, neo cream + ink + offset shadow.
            // Card draws the shadow inside, so the paper occupies width/height minus
            // shadowOffset; content lives on the paper.
            Card {
                id: centerPanel

                readonly property int contentWidth: 320
                readonly property real contentHeight: Spacing.spacing12 + headerRow.height + Spacing.spacing8 + separator.height + Spacing.spacing8 + (controller.hasHistory ? clearArea.height + Spacing.spacing8 : 0) + listArea.height + Spacing.spacing12

                implicitWidth: contentWidth + Shape.shadowOffset
                implicitHeight: contentHeight + Shape.shadowOffset
                width: implicitWidth
                height: implicitHeight

                Row {
                    id: headerRow
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: Spacing.spacing12
                        leftMargin: Spacing.spacing12
                        rightMargin: Spacing.spacing12
                    }
                    height: Math.max(titleText.implicitHeight, dndPill.implicitHeight)

                    Text {
                        id: titleText
                        text: "Benachrichtigungen"
                        font.family: Typography.fontFamily
                        font.pixelSize: Typography.fontSize14
                        font.weight: Font.Bold
                        color: Colors.textColor
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - dndPill.implicitWidth
                    }

                    Item {
                        id: dndPill
                        implicitWidth: dndRow.implicitWidth + Spacing.spacing12 * 2
                        implicitHeight: 26
                        width: implicitWidth
                        height: implicitHeight
                        anchors.verticalCenter: parent.verticalCenter

                        scale: dndTap.pressed ? 0.85 : 1.0
                        SquishBehavior on scale {}

                        // DND toggle bg. On-state (active) = blue accent, neo cream hover.
                        ButtonBg {
                            active: controller.dnd
                            hovered: dndHover.hovered
                            pressed: dndTap.pressed
                        }

                        HoverHandler {
                            id: dndHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            id: dndTap
                            onTapped: controller.toggleDnd()
                        }

                        Row {
                            id: dndRow
                            anchors.centerIn: parent
                            spacing: Spacing.spacing4

                            Label {
                                id: dndLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Nicht stören"
                                font.family: Typography.fontFamily
                                font.pixelSize: Typography.fontSize12
                                color: controller.dnd ? Colors.textColor : Colors.textColorMuted
                                font.bold: controller.dnd
                            }

                            ContentReplace {
                                id: dndIconReplace
                                contentKey: controller.dnd ? "../icons/icons8-do-not-disturb.svg" : "../icons/icons8-bell.svg"
                                anchors.verticalCenter: parent.verticalCenter
                                width: Typography.fontSize16
                                height: Typography.fontSize16

                                TintedIcon {
                                    anchors.centerIn: parent
                                    size: Typography.fontSize16
                                    source: dndIconReplace.displayValue
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: separator
                    anchors {
                        top: headerRow.bottom
                        left: parent.left
                        right: parent.right
                        topMargin: Spacing.spacing8
                        leftMargin: Spacing.spacing12
                        rightMargin: Spacing.spacing12
                    }
                    height: 1
                    color: Colors.separatorColor
                }

                Item {
                    id: clearArea
                    anchors {
                        top: separator.bottom
                        left: parent.left
                        right: parent.right
                        topMargin: Spacing.spacing8
                        leftMargin: Spacing.spacing12
                        rightMargin: Spacing.spacing12
                    }
                    height: clearBtn.implicitHeight
                    visible: controller.hasHistory

                    Item {
                        id: clearBtn
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        implicitHeight: 26

                        scale: clearTap.pressed ? 0.85 : 1.0
                        SquishBehavior on scale {}

                        // Clear button bg. Classic round pill, neo cream hover + accent press.
                        ButtonBg {
                            hovered: clearHover.hovered
                            pressed: clearTap.pressed
                        }

                        HoverHandler {
                            id: clearHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            id: clearTap
                            onTapped: controller.clearHistory()
                        }

                        Row {
                            anchors.centerIn: parent

                            TintedIcon {
                                size: Typography.fontSize16
                                source: "../icons/icons8-trash.svg"
                                color: Colors.textColorMuted
                            }

                            Text {
                                id: clearLabel
                                text: "Alle löschen"
                                font.family: Typography.fontFamily
                                font.pixelSize: Typography.fontSize12
                                font.weight: Font.Normal
                                color: Colors.textColorMuted
                            }
                        }
                    }
                }

                NotificationList {
                    id: listArea
                    controller: controller
                    anchors {
                        top: controller.hasHistory ? clearArea.bottom : separator.bottom
                        left: parent.left
                        right: parent.right
                        topMargin: Spacing.spacing8
                        leftMargin: Spacing.spacing12
                        rightMargin: Spacing.spacing12
                    }
                    height: implicitHeight
                }
            }
        }
    }
}
