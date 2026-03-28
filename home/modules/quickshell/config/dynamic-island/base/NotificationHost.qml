pragma Singleton
import QtQuick
import Quickshell.Services.Notifications

// Singleton owning the NotificationServer and bridging it to toast, panel,
// and indicator components.
QtObject {
    id: root

    readonly property var server: _server

    // Fires whenever a new notification arrives (toast/indicator listen to this).
    signal newNotification(var notification)

    property var _server: NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        onNotification: function (notification) {
            notification.tracked = !notification.transient;
            root.newNotification(notification);
        }
    }
}
