import Quickshell.Services.Notifications
import QtQuick
import "../"
import "../base"

// Reusable notification card. Used in both toast (compact) and panel (full) modes.
// Properties: notification (Notification object), compact (bool).
Item {
    id: root

    required property var notification
    property bool compact: false

    signal dismissed

    implicitWidth: parent ? parent.width : 320
    implicitHeight: cardBackground.implicitHeight

    readonly property color urgencyColor: {
        if (!notification)
            return Colors.textColor;
        switch (notification.urgency) {
        case NotificationUrgency.Critical:
            return Colors.batteryCritical;
        case NotificationUrgency.Low:
            return Colors.textColorMuted;
        default:
            return Colors.textColor;
        }
    }

    readonly property color accentStripColor: {
        if (!notification)
            return "transparent";
        switch (notification.urgency) {
        case NotificationUrgency.Critical:
            return Colors.batteryCritical;
        case NotificationUrgency.Low:
            return "transparent";
        default:
            return Colors.pillBorder;
        }
    }

    scale: cardTap.pressed ? 0.97 : 1.0
    SquishBehavior on scale {}

    Rectangle {
        id: cardBackground
        anchors.fill: parent
        implicitHeight: cardContent.implicitHeight + 2 * Spacing.spacing12
        radius: Spacing.spacing8
        color: cardHover.hovered ? Colors.hoverItemHovered : Colors.pillBackground
        border.width: 1
        border.color: cardHover.hovered ? Colors.pillBorder : Qt.rgba(1, 1, 1, 0.1)

        // Left urgency accent strip
        Rectangle {
            width: 3
            height: parent.height - 2 * Spacing.spacing4
            anchors.left: parent.left
            anchors.leftMargin: Spacing.spacing4
            anchors.verticalCenter: parent.verticalCenter
            radius: width / 2
            color: root.accentStripColor
            visible: root.accentStripColor !== "transparent"
        }
    }

    HoverHandler {
        id: cardHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: cardTap
        onTapped: {
            if (root.notification && root.notification.actions.length > 0) {
                root.notification.actions[0].invoke();
            }
        }
    }

    Column {
        id: cardContent
        anchors {
            fill: parent
            margins: Spacing.spacing12
            leftMargin: Spacing.spacing16
        }
        spacing: Spacing.spacing4

        // Header: app name + dismiss button
        Item {
            width: parent.width
            height: appNameLabel.implicitHeight

            Row {
                spacing: Spacing.spacing4
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    id: appNameLabel
                    text: root.notification ? root.notification.appName : ""
                    font.pixelSize: Typography.fontSize12
                    font.weight: Font.Normal
                    color: Colors.textColorMuted
                }
            }

            // Dismiss X button
            Rectangle {
                id: dismissBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: width / 2
                color: dismissTap.pressed ? Colors.hoverItemPressed : dismissHover.hovered ? Colors.hoverItemHovered : "transparent"

                scale: dismissTap.pressed ? 0.85 : 1.0
                SquishBehavior on scale {}

                TintedIcon {
                    source: "../icons/icons8-cross.svg"
                    size: Typography.fontSize12
                    color: dismissHover.hovered ? Colors.textColor : Colors.textColorMuted
                    anchors.centerIn: parent
                }

                HoverHandler {
                    id: dismissHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: dismissTap
                    onTapped: root.dismissed()
                }
            }
        }

        // Summary
        Label {
            text: root.notification ? root.notification.summary : ""
            font.pixelSize: Typography.fontSize14
            font.weight: Font.Bold
            color: root.urgencyColor
            width: parent.width
            elide: Text.ElideRight
        }

        // Body
        Text {
            text: root.notification ? root.notification.body : ""
            font.family: Typography.fontFamily
            font.pixelSize: Typography.fontSize12
            font.weight: Font.Normal
            color: Colors.textColor
            width: parent.width
            wrapMode: Text.WordWrap
            maximumLineCount: root.compact ? 2 : 6
            elide: Text.ElideRight
            visible: text !== ""
        }

        // Notification image
        Image {
            source: root.notification && root.notification.image !== "" ? root.notification.image : ""
            width: parent.width
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            sourceSize.width: parent.width
            sourceSize.height: 180
        }

        // Action buttons
        Row {
            spacing: Spacing.spacing4
            visible: !root.compact && root.notification && root.notification.actions.length > 0

            Repeater {
                model: root.notification ? root.notification.actions : []

                Rectangle {
                    required property var modelData
                    width: actionLabel.implicitWidth + 2 * Spacing.spacing12
                    height: 28
                    radius: height / 2
                    color: actionTap.pressed ? Colors.hoverItemPressed : actionHover.hovered ? Colors.hoverItemHovered : "transparent"
                    border.width: 1
                    border.color: actionHover.hovered || actionTap.pressed ? Colors.pillBorder : Qt.rgba(1, 1, 1, 0.1)

                    scale: actionTap.pressed ? 0.9 : 1.0
                    SquishBehavior on scale {}

                    Label {
                        id: actionLabel
                        text: modelData.text
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Bold
                        color: Colors.textColor
                        anchors.centerIn: parent
                    }

                    HoverHandler {
                        id: actionHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: actionTap
                        onTapped: modelData.invoke()
                    }
                }
            }
        }
    }
}
