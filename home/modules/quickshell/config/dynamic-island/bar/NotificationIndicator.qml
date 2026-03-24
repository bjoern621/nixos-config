import QtQuick
import "../"

// Bell icon indicator for the bar. Read-only — panel opens via right-edge hover.
// Shows a count badge when there are tracked notifications.
Item {
    id: root

    implicitWidth: bellIcon.implicitWidth + Spacing.spacing12
    implicitHeight: 28
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    readonly property int count: {
        const srv = NotificationHost.server
        if (!srv || !srv.trackedNotifications) return 0
        return srv.trackedNotifications.count ?? 0
    }

    Icon {
        id: bellIcon
        text: "\uf0f3"
        anchors.centerIn: parent

        scale: 1.0
        transformOrigin: Item.Center

        SequentialAnimation {
            id: pulseAnim
            NumberAnimation { target: bellIcon; property: "scale"; to: 1.3; duration: 100; easing.type: Easing.OutBack }
            NumberAnimation { target: bellIcon; property: "scale"; to: 1.0; duration: 100; easing.type: Easing.InCubic }
        }
    }

    // Count badge
    Rectangle {
        visible: root.count > 0
        anchors.left: bellIcon.right
        anchors.leftMargin: -Spacing.spacing4
        anchors.top: bellIcon.top
        anchors.topMargin: -Spacing.spacing4
        width: Math.max(14, badgeLabel.implicitWidth + Spacing.spacing4)
        height: 14
        radius: height / 2
        color: Colors.batteryCritical

        Label {
            id: badgeLabel
            text: root.count > 99 ? "99+" : root.count.toString()
            font.pixelSize: 9
            font.weight: Font.Bold
            color: Colors.textColor
            anchors.centerIn: parent
        }
    }

    Connections {
        target: NotificationHost
        function onNewNotification() {
            pulseAnim.start()
        }
    }
}
