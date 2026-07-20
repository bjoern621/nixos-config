pragma ComponentBehavior: Bound
import QtQuick
import "../"

Item {
    id: root

    // Center controller: history model + D-Bus passthroughs.
    property var controller
    readonly property int historyCount: controller ? controller.history.count : 0

    implicitHeight: root.historyCount === 0 ? emptyText.implicitHeight + Spacing.spacing8 : Math.min(340, notifFlick.contentHeight)

    clip: true

    Text {
        id: emptyText
        anchors.centerIn: parent
        text: "Keine Benachrichtigungen"
        font.family: Typography.fontFamily
        font.pixelSize: Typography.fontSize12
        font.weight: Font.Normal
        color: Colors.textColorMuted
        visible: root.historyCount === 0
    }

    Flickable {
        id: notifFlick
        anchors.fill: parent
        // Reserve a gutter for the scroll handle only while it shows.
        anchors.rightMargin: scrollable ? 14 : 0
        contentHeight: notifCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: root.historyCount > 0

        readonly property bool scrollable: contentHeight > height + 1

        // Shared wheel step, no inertia. Same behavior as the app launcher.
        StepWheel {
            target: notifFlick
            rowStride: 60
        }

        Column {
            id: notifCol
            width: notifFlick.width

            Repeater {
                model: root.controller ? root.controller.history : null

                delegate: Item {
                    id: histEntry
                    required property string uid
                    required property string appName
                    required property string summary
                    required property string body
                    required property int urgency
                    required property int index
                    required property var timestamp

                    width: notifCol.width
                    implicitHeight: entryContent.implicitHeight + Spacing.spacing12 * 2
                    height: implicitHeight

                    scale: entryTap.pressed ? 0.97 : 1.0
                    SquishBehavior on scale {}

                    // Launcher row bg: cream hover, ink border when lit, radius 5.
                    LauncherDelegateBg {
                        hovered: entryHover.hovered
                        pressed: entryTap.pressed
                    }

                    HoverHandler {
                        id: entryHover
                        cursorShape: root.controller.hasClickAction(histEntry.uid) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }

                    TapHandler {
                        id: entryTap
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.controller.invokeDefault(histEntry.uid)
                    }

                    NotificationContent {
                        id: entryContent
                        anchors {
                            top: parent.top
                            topMargin: Spacing.spacing12
                            left: parent.left
                            leftMargin: Spacing.spacing8
                            right: parent.right
                            // Keeps the text clear of the timestamp and delete button.
                            rightMargin: Spacing.spacing12 + Spacing.spacing24 * 2
                        }
                        appName: histEntry.appName
                        summary: histEntry.summary
                        body: histEntry.body
                        urgency: histEntry.urgency
                        actions: root.controller.actionsFor(histEntry.uid)
                        onActionInvoked: index => root.controller.invokeAction(histEntry.uid, index)
                    }

                    Text {
                        anchors {
                            right: deleteBtn.left
                            rightMargin: Spacing.spacing4
                            verticalCenter: deleteBtn.verticalCenter
                        }
                        text: Qt.formatTime(new Date(histEntry.timestamp), "hh:mm")
                        font.family: Typography.fontFamily
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                    }

                    Item {
                        id: deleteBtn
                        anchors {
                            right: parent.right
                            rightMargin: Spacing.spacing8
                            top: parent.top
                            topMargin: Spacing.spacing8
                        }
                        width: Spacing.spacing24
                        height: Spacing.spacing24
                        opacity: entryHover.hovered ? 1.0 : 0.0
                        // An item at zero opacity still takes input.
                        visible: deleteBtn.opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 80
                                easing.type: Easing.OutCubic
                            }
                        }

                        scale: deleteTap.pressed ? 0.85 : 1.0
                        SquishBehavior on scale {}

                        // Delete button bg. Classic round pill, neo cream hover + accent press.
                        ButtonBg {
                            hovered: deleteHover.hovered
                            pressed: deleteTap.pressed
                        }

                        HoverHandler {
                            id: deleteHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            id: deleteTap
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.controller.removeAt(histEntry.index)
                        }

                        TintedIcon {
                            anchors.centerIn: parent
                            size: Spacing.spacing12
                            source: "../icons/icons8-close.svg"
                            color: Colors.textColorMuted
                        }
                    }
                }
            }
        }
    }

    // Shared draggable handle, sibling of the flickable.
    ScrollHandle {
        target: notifFlick
        visible: notifFlick.visible && notifFlick.scrollable
        anchors.right: parent.right
        anchors.top: notifFlick.top
        anchors.bottom: notifFlick.bottom
    }
}
