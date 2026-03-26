pragma Singleton
import QtQuick

// Singleton managing the loading screen state.
// Provides a clean API for showing/hiding the loading overlay
// without polluting the global namespace.

QtObject {
    id: host

    property bool active: false
    property string label: ""

    signal cancelled()

    function show(actionLabel) {
        label = actionLabel
        active = true
    }

    function hide() {
        active = false
        label = ""
    }
}
