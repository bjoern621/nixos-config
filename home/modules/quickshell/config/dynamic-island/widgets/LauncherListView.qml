import QtQuick
import QtQuick.Controls as QQC
import ".."

// Reusable list for launchers. One selection at a time:
//  - mouse motion: selection follows the row under the cursor (keyboardNav=false)
//  - keyboard nav: parent sets keyboardNav=true; selection stays where keys put it
// Wheel scrolling and keep-selection-in-view are left to the built-in behaviour.
ListView {
    id: root
    clip: true
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0

    property bool keyboardNav: false

    // HoverHandler (not MouseArea) so per-delegate HoverHandlers (e.g. lock icon tooltip) still receive hover.
    HoverHandler {
        id: hoverArea
    }

    function syncHover() {
        if (!hoverArea.hovered)
            return;
        root.keyboardNav = false;
        const pos = hoverArea.point.position;
        // HoverHandler is parented to the scrolling content, so pos is already in content coordinates — no contentX/Y offset.
        const item = root.itemAt(pos.x, pos.y);
        if (item && item.index !== undefined)
            root.currentIndex = item.index;
    }

    // Mouse motion → selection follows. Bind to point.position so the change signal fires on every move.
    readonly property point hoverPos: hoverArea.point.position
    onHoverPosChanged: syncHover()

    // Only sync the selection to the mouse during mouse-driven scroll. Without this, a keyboard nav that scrolls the view would immediately reset the selection back to whatever's under the cursor.
    onContentYChanged: if (!keyboardNav) syncHover()

    QQC.ScrollBar.vertical: ThinScrollBar {}
}
