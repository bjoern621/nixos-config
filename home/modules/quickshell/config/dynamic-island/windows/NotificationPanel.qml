import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Controls as QQC
import "../"

// Right-edge hover-triggered notification history panel.
// Same pattern as PowerCorner: Variants per screen, HoverMenu wraps content.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: panelWindow
        required property var modelData
        screen: modelData

        anchors {
            top: true
            right: true
            bottom: true
        }

        exclusiveZone: 0
        focusable: false
        color: "transparent"

        implicitWidth: 380

        mask: Region {
            item: panelInteraction
        }

        readonly property bool shouldShow: edgeHover.hovered || panelMenu.keepOpen

        onShouldShowChanged: {
            if (shouldShow) {
                panelMenu.show()
            } else {
                panelMenu.hide()
            }
        }

        // Interaction zone: expands when panel is visible
        Rectangle {
            id: panelInteraction
            color: Qt.rgba(0, 0, 1, 0.3) // DEBUG
            anchors.right: parent.right
            width: panelMenu.visible ? 380 : Spacing.spacing8
            height: panelMenu.visible ? panelWindow.height : modelData.height * 0.25
            y: panelMenu.visible ? 0 : (panelWindow.height - height) / 2
        }

        // Thin trigger strip on right edge, vertically centered
        Item {
            id: edgeTrigger
            width: Spacing.spacing8
            height: modelData.height * 0.25
            anchors.right: parent.right
            y: (panelWindow.height - height) / 2

            HoverHandler {
                id: edgeHover
            }
        }

        HoverMenu {
            id: panelMenu
            width: 360
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Spacing.spacing8
            transformOriginValue: Item.Right
            gapHeight: 0

            Rectangle {
                width: parent ? parent.width : 360
                height: panelContent.implicitHeight + 2 * Spacing.spacing12
                radius: Spacing.spacing12
                color: Colors.pillBackground
                border.width: 1
                border.color: Colors.pillBorder

                Column {
                    id: panelContent
                    anchors {
                        fill: parent
                        margins: Spacing.spacing12
                    }
                    spacing: Spacing.spacing8

                    // Header
                    Item {
                        width: parent.width
                        height: headerLabel.implicitHeight

                        Label {
                            id: headerLabel
                            text: "Benachrichtigungen"
                            font.pixelSize: Typography.fontSize16
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Clear all button
                        Rectangle {
                            id: clearBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: clearLabel.implicitWidth + 2 * Spacing.spacing12
                            height: 26
                            radius: height / 2
                            visible: NotificationHost.server && NotificationHost.server.trackedNotifications.count > 0
                            color: clearTap.pressed ? Colors.hoverItemPressed
                                 : clearHover.hovered ? Colors.hoverItemHovered
                                 : "transparent"
                            border.width: 1
                            border.color: clearHover.hovered || clearTap.pressed ? Colors.pillBorder : "transparent"

                            scale: clearTap.pressed ? 0.9 : 1.0
                            SquishBehavior on scale {}

                            Label {
                                id: clearLabel
                                text: "Alle löschen"
                                font.pixelSize: Typography.fontSize12
                                font.weight: Font.Bold
                                color: Colors.textColorMuted
                                anchors.centerIn: parent
                            }

                            HoverHandler {
                                id: clearHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                id: clearTap
                                onTapped: {
                                    if (!NotificationHost.server) return
                                    const model = NotificationHost.server.trackedNotifications
                                    // Dismiss all tracked notifications
                                    while (model.count > 0) {
                                        model.get(0).dismiss()
                                    }
                                }
                            }
                        }
                    }

                    // Separator
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Colors.separatorColor
                    }

                    // Notification list
                    QQC.ScrollView {
                        width: parent.width
                        height: Math.min(notifList.contentHeight, panelWindow.height - 200)
                        clip: true
                        visible: NotificationHost.server && NotificationHost.server.trackedNotifications.count > 0

                        ListView {
                            id: notifList
                            model: NotificationHost.server ? NotificationHost.server.trackedNotifications : null
                            spacing: Spacing.spacing4

                            delegate: NotificationCard {
                                required property var modelData
                                width: notifList.width
                                notification: modelData
                                compact: false
                                onDismissed: {
                                    if (modelData) modelData.dismiss()
                                }
                            }
                        }
                    }

                    // Empty state
                    Item {
                        width: parent.width
                        height: emptyLabel.implicitHeight + 2 * Spacing.spacing24
                        visible: !NotificationHost.server || NotificationHost.server.trackedNotifications.count === 0

                        Label {
                            id: emptyLabel
                            text: "Keine Benachrichtigungen"
                            font.pixelSize: Typography.fontSize14
                            font.weight: Font.Normal
                            color: Colors.textColorMuted
                            anchors.centerIn: parent
                        }
                    }
                }
            }
        }
    }
}
