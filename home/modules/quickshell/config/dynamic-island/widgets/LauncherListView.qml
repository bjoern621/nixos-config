import QtQuick
import QtQuick.Controls as QQC
import ".."

// Reusable list for launchers. One selection at a time:
//  - mouse motion: selection follows the row under the cursor
//  - keyboard nav: parent sets keyboardNav=true; selection stays where keys put it
ListView {
    id: root
    clip: true
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0

    property bool keyboardNav: false

    HoverHandler {
        id: hoverArea
    }

    function syncHover() {
        if (!hoverArea.hovered)
            return;
        root.keyboardNav = false;
        const pos = hoverArea.point.position;
        const item = root.itemAt(pos.x, pos.y);
        if (item && item.index !== undefined)
            root.currentIndex = item.index;
    }

    // Re-runs syncHover on every mouse move.
    readonly property point hoverPos: hoverArea.point.position
    onHoverPosChanged: syncHover()

    // Only sync the selection to the mouse during mouse-driven scroll. Without this, a keyboard nav that scrolls the view would immediately reset the selection back to whatever's under the cursor.
    onContentYChanged: if (!keyboardNav) syncHover()

    QQC.ScrollBar.vertical: ThinScrollBar {}
}
