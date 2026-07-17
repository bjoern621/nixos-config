pragma Singleton
import QtQuick

// State for the generic loading overlay: blocking actions with nothing to wait on
// (lock, hibernate). Graceful shutdown uses GracefulShutdown instead.

QtObject {
    id: host

    property bool active: false
    property string label: ""

    function show(actionLabel) {
        label = actionLabel;
        active = true;
    }

    function hide() {
        active = false;
        label = "";
    }
}
