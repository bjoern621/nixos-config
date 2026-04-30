pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import "../"

Item {
    implicitHeight: NotificationListener.history.count === 0
        ? emptyText.implicitHeight + Spacing.spacing8
        : Math.min(340, notifFlick.contentHeight)

    clip: true

    Text {
        id: emptyText
        anchors.centerIn: parent
        text: "Keine Benachrichtigungen"
        font.family: Typography.fontFamily
        font.pixelSize: Typography.fontSize12
        font.weight: Font.Normal
        color: Colors.textColorMuted
        visible: NotificationListener.history.count === 0
    }

    Flickable {
        id: notifFlick
        anchors.fill: parent
        contentHeight: notifCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: NotificationListener.history.count > 0

        QQC.ScrollBar.vertical: ThinScrollBar {}

        Column {
            id: notifCol
            width: notifFlick.width

            Repeater {
                model: NotificationListener.history

                delegate: Rectangle {
                    id: histEntry
                    required property string appName
                    required property string summary
                    required property string body
                    required property int urgency
                    required property int index
                    required property var timestamp

                    width: notifCol.width
                    implicitHeight: entryContent.implicitHeight + Spacing.spacing12 * 2
                    height: implicitHeight
                    color: entryHover.hovered ? Colors.hoverItemHovered : "transparent"
                    border.color: entryHover.hovered ? Colors.pillBorder : "transparent"
                    radius: Spacing.spacing8

                    HoverHandler {
                        id: entryHover
                    }

                    NotificationContent {
                        id: entryContent
                        anchors {
                            top: parent.top
                            topMargin: Spacing.spacing12
                            left: parent.left
                            leftMargin: Spacing.spacing8
                            right: parent.right
                            rightMargin: Spacing.spacing12
                        }
                        appName: histEntry.appName
                        summary: histEntry.summary
                        body: histEntry.body
                        urgency: histEntry.urgency
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

                    Rectangle {
                        id: deleteBtn
                        anchors {
                            right: parent.right
                            rightMargin: Spacing.spacing8
                            top: parent.top
                            topMargin: Spacing.spacing8
                        }
                        width: Spacing.spacing24
                        height: Spacing.spacing24
                        radius: height / 2
                        color: deleteTap.pressed ? Colors.hoverItemPressed : deleteHover.hovered ? Colors.hoverItemHovered : "transparent"
                        border.color: deleteHover.hovered ? Colors.pillBorder : "transparent"
                        opacity: entryHover.hovered ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 80
                                easing.type: Easing.OutCubic
                            }
                        }

                        scale: deleteTap.pressed ? 0.85 : 1.0
                        SquishBehavior on scale {}

                        HoverHandler {
                            id: deleteHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            id: deleteTap
                            onTapped: NotificationListener.removeAt(histEntry.index)
                        }

                        TintedIcon {
                            anchors.centerIn: parent
                            size: Spacing.spacing12
                            source: "../icons/icons8-cross.svg"
                            color: Colors.textColorMuted
                        }
                    }
                }
            }
        }
    }
}
