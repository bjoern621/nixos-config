import QtQuick
import ".."

// Loads the theme-appropriate view of a feature.
// `feature` is the view basename shared by both theme folders (e.g. "PowerMenuView").
// The controller lives outside the loader, so its state survives a theme switch;
// the view is reloaded and re-bound on each Globals.designTheme change.
Loader {
    id: loader

    property string feature
    property var controller

    source: Qt.resolvedUrl("../themes/" + (Globals.designTheme === "neo" ? "neo/" : "classic/") + feature + ".qml")

    function _bind() {
        if (item && "controller" in item)
            item.controller = controller;
    }
    onLoaded: _bind()
    onControllerChanged: _bind()
}
