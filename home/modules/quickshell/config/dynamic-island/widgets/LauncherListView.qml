import QtQuick
import QtQuick.Controls as QQC
import ".."

// Reusable list for launchers. Selection state lives in LauncherSelection (mouse hover vs keyboard nav, with auto-scroll only on keyboard).
ListView {
    id: root
    clip: true
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0

    property alias keyboardNav: selection.keyboardNav
    property alias hoveredIndex: selection.hoveredIndex
    readonly property alias effectiveIndex: selection.effectiveIndex
    function reset() {
        selection.reset();
    }

    LauncherSelection {
        id: selection
        view: root
    }

    // Only sync the selection to the mouse during mouse-driven scroll. Without this, a keyboard nav that scrolls the view would immediately reset the selection back to whatever's under the cursor.
    onContentYChanged: if (!keyboardNav)
        selection.syncHover()

    TouchpadBoost {
        flickable: root
    }

    QQC.ScrollBar.vertical: ThinScrollBar {}
}
