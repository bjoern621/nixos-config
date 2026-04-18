pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    signal notificationReceived(var notification)

    NotificationServer {
        keepOnReload: false

        onNotification: n => {
            n.tracked = true;
            // console.log("[Notification] id=" + n.id + " app=" + n.appName + " summary=" + n.summary + " body=" + n.body + " urgency=" + n.urgency + " timeout=" + n.expireTimeout);
            root.notificationReceived(n);
        }
    }
}
