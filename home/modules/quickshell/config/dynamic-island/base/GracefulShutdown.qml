pragma Singleton
import QtQuick

// State holder for graceful shutdown. Closes all Hyprland windows,
// polls until they're gone, then runs an optional post command.
//
// Usage:
//   GracefulShutdown.start("Shutting down...", ["systemctl", "poweroff"])
//   GracefulShutdown.start("Closing all apps...")  // no post command

QtObject {
    id: root

    property bool active: false
    property string label: ""
    property var postCmd: []

    // [{address, class, title, alive}] — updated by ShutdownScreen's polling
    property var apps: []

    signal finished

    function start(actionLabel, cmd) {
        label = actionLabel;
        postCmd = cmd || [];
        apps = [];
        active = true;
    }

    function cancel() {
        active = false;
        label = "";
        postCmd = [];
        apps = [];
    }
}
