import QtQuick
import QtQuick.Controls as QQC
import ".."

// List for launchers.
// Selection and scroll behavior live in LauncherViewBehavior.
ListView {
    id: root
    clip: true
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0

    property alias keyboardNav: behavior.keyboardNav
    property alias hoveredIndex: behavior.hoveredIndex
    readonly property alias effectiveIndex: behavior.effectiveIndex
    function reset() {
        behavior.reset();
    }

    LauncherViewBehavior {
        id: behavior
        view: root
    }

    QQC.ScrollBar.vertical: ThinScrollBar {}
}
