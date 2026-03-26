import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "../"

// Non-modal toast stack for incoming notifications (top-right, auto-dismiss).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: toastWindow
        visible: toastEntries.length > 0
        required property var modelData
        screen: modelData

        anchors {
            top: true
            right: true
        }

        exclusiveZone: 0
        focusable: false
        color: "transparent"

        implicitWidth: 360
        implicitHeight: toastColumn.implicitHeight + Spacing.spacing8

        mask: Region {
            item: toastInteraction
        }

        // Toast entries as a JS array of Notification objects.
        // Reassigning (not mutating) triggers binding updates.
        property var toastEntries: []

        Connections {
            target: NotificationHost
            function onNewNotification(notification) {
                toastWindow.toastEntries = toastWindow.toastEntries.concat([notification])
            }
        }

        function removeToast(notification) {
            toastWindow.toastEntries = toastWindow.toastEntries.filter(function(n) { return n !== notification })
        }

        // Only expand the interaction zone when there are toasts
        Item {
            id: toastInteraction
            anchors.top: parent.top
            anchors.right: parent.right
            width: toastWindow.toastEntries.length > 0 ? toastWindow.implicitWidth : 0
            height: toastWindow.toastEntries.length > 0 ? toastWindow.implicitHeight : 0
        }

        Column {
            id: toastColumn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 48
            anchors.rightMargin: Spacing.spacing12
            width: 340
            spacing: Spacing.spacing8

            Repeater {
                model: toastWindow.toastEntries.length

                Item {
                    id: toastItem
                    required property int index
                    width: parent ? parent.width : 340
                    height: toastReveal.implicitHeight
                    clip: true

                    readonly property var notif: toastWindow.toastEntries[index]

                    PopReveal {
                        id: toastReveal
                        width: parent.width
                        implicitHeight: card.implicitHeight
                        showDuration: 80
                        hideDuration: 60
                        transformOriginValue: Item.TopRight

                        Component.onCompleted: show()

                        onHidden: {
                            toastWindow.removeToast(toastItem.notif)
                        }

                        NotificationCard {
                            id: card
                            width: parent.width
                            notification: toastItem.notif
                            compact: true
                            onDismissed: {
                                dismissTimer.stop()
                                if (toastItem.notif) toastItem.notif.dismiss()
                                toastReveal.hide()
                            }
                        }
                    }

                    // Auto-dismiss timer
                    Timer {
                        id: dismissTimer
                        interval: toastItem.notif && toastItem.notif.urgency === NotificationUrgency.Critical ? 10000 : 5000
                        running: true
                        // Pause while hovered
                        property bool paused: cardHoverForTimer.hovered
                        onPausedChanged: paused ? stop() : restart()
                        onTriggered: toastReveal.hide()
                    }

                    HoverHandler {
                        id: cardHoverForTimer
                    }
                }
            }
        }
    }
}
