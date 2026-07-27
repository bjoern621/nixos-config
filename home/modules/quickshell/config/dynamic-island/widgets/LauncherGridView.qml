import QtQuick
import ".."

// Grid for launchers.
// Selection and wheel/inertia behavior live in LauncherViewBehavior.
// The visible scrollbar is a shared ScrollHandle placed by the consumer as a
// sibling (a Flickable reparents its own children into contentItem).
GridView {
    id: root
    clip: true
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0

    // True while content overflows the viewport (consumer reserves a gutter).
    readonly property bool scrollable: contentHeight > height + 1

    property alias keyboardNav: behavior.keyboardNav
    property alias hoveredIndex: behavior.hoveredIndex
    readonly property alias effectiveIndex: behavior.effectiveIndex
    property alias rowStride: behavior.rowStride
    function reset() {
        behavior.reset();
    }
    function keyboardSelect(index) {
        behavior.keyboardSelect(index);
    }

    LauncherViewBehavior {
        id: behavior
        view: root
    }
}
