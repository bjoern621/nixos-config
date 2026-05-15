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

        onShouldShowChanged: shouldShow ? centerReveal.show() : centerReveal.hide()

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

            Rectangle {
                id: centerPanel
                implicitWidth: 320
                implicitHeight: Spacing.spacing12 + headerRow.height + Spacing.spacing8 + separator.height + Spacing.spacing8 + (NotificationListener.history.count > 0 ? clearArea.height + Spacing.spacing8 : 0) + listArea.height + Spacing.spacing12

                width: implicitWidth
                height: implicitHeight
                color: Colors.pillBackground
                border.color: Colors.pillBorder
                border.width: 1
                radius: Spacing.spacing12
                clip: true

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

                    Rectangle {
                        id: dndPill
                        implicitWidth: dndRow.implicitWidth + Spacing.spacing12 * 2
                        implicitHeight: 26
                        width: implicitWidth
                        height: implicitHeight
                        radius: height / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: dndTap.pressed ? Colors.hoverItemPressed : dndHover.hovered ? Colors.hoverItemHovered : Globals.doNotDisturb ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        border.color: (dndHover.hovered || Globals.doNotDisturb) ? Colors.pillBorder : "transparent"

                        scale: dndTap.pressed ? 0.85 : 1.0
                        SquishBehavior on scale {}

                        HoverHandler {
                            id: dndHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            id: dndTap
                            onTapped: Globals.doNotDisturb = !Globals.doNotDisturb
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
                                color: Globals.doNotDisturb ? Colors.textColor : Colors.textColorMuted
                                font.bold: Globals.doNotDisturb
                            }

                            ContentReplace {
                                id: dndIconReplace
                                contentKey: Globals.doNotDisturb ? "../icons/icons8-do-not-disturb.svg" : "../icons/icons8-bell.svg"

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
                    visible: NotificationListener.history.count > 0

                    Rectangle {
                        id: clearBtn
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        implicitHeight: 26
                        radius: height / 2
                        color: clearTap.pressed ? Colors.hoverItemPressed : clearHover.hovered ? Colors.hoverItemHovered : "transparent"
                        border.color: clearHover.hovered ? Colors.pillBorder : "transparent"

                        scale: clearTap.pressed ? 0.85 : 1.0
                        SquishBehavior on scale {}

                        HoverHandler {
                            id: clearHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            id: clearTap
                            onTapped: NotificationListener.clearHistory()
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
                    anchors {
                        top: NotificationListener.history.count > 0 ? clearArea.bottom : separator.bottom
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
