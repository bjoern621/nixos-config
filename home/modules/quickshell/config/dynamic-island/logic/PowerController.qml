import QtQuick
import Quickshell
import ".."

// Power menu behavior: the action list and what each action runs.
// Views render `actions` and call triggerAction(action.action); no logic in views.
// Icon paths resolve to absolute urls here so any view location can use them.
QtObject {
    id: root

    readonly property var actions: [
        {
            action: "shutdown",
            iconSource: Qt.resolvedUrl("../icons/icons8-shutdown.svg"),
            label: "Shutdown"
        },
        {
            action: "reboot",
            iconSource: Qt.resolvedUrl("../icons/icons8-restart.svg"),
            label: "Reboot"
        },
        {
            action: "lock",
            iconSource: Qt.resolvedUrl("../icons/icons8-lock.svg"),
            label: "Lock"
        },
        {
            action: "logout",
            iconSource: Qt.resolvedUrl("../icons/icons8-log-out.svg"),
            label: "Logout"
        },
        {
            action: "hibernate",
            iconSource: Qt.resolvedUrl("../icons/icons8-sleep.svg"),
            label: "Hibernate"
        }
    ]

    function triggerAction(action) {
        Qt.callLater(() => {
            switch (action) {
            case "shutdown":
                GracefulShutdown.start("Herunterfahren...", ["systemctl", "--no-wall", "poweroff"]);
                break;
            case "reboot":
                GracefulShutdown.start("Neustarten...", ["systemctl", "--no-wall", "reboot"]);
                break;
            case "lock":
                LoadingHost.show("Sperren...");
                Quickshell.execDetached(["loginctl", "lock-session"]);
                break;
            case "hibernate":
                // Direct hibernate, same as lid close. s2idle never reaches
                // hardware sleep on this machine (see modules/hibernate.nix),
                // so there is no suspend option.
                LoadingHost.show("Hibernieren...");
                Quickshell.execDetached(["systemctl", "hibernate"]);
                break;
            case "logout":
                GracefulShutdown.start("Abmelden...", ["hyprctl", "dispatch", "exit"]);
                break;
            }
        });
    }
}
