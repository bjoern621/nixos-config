pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    NotificationServer {
        id: server

        keepOnReload: true

        onNotification: notification => {
            console.log("[Notification] id=" + notification.id
                + " app=" + notification.appName
                + " summary=" + notification.summary
                + " body=" + notification.body
                + " urgency=" + notification.urgency
                + " timeout=" + notification.expireTimeout);
        }
    }
}
