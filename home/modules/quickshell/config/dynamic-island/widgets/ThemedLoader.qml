import QtQuick
import ".."

// Loads a feature's view from the folder of Globals.designTheme.
// `feature` is the view basename (e.g. "PowerMenuView").
// Controller lives outside loader, so its state survives a view reload.
Loader {
    id: loader

    property string feature
    property var controller

    source: Qt.resolvedUrl("../themes/" + Globals.designTheme + "/" + feature + ".qml")

    function _bind() {
        if (item && "controller" in item)
            item.controller = controller;
    }
    onLoaded: _bind()
    onControllerChanged: _bind()
}
