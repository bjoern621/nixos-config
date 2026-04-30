import QtQuick
import QtQuick.Controls as QQC
import ".."

// Reusable grid for launchers. Same selection model as LauncherListView: one
// selection at a time, mouse motion or keyboard nav owns it.
GridView {
    id: root
    clip: true
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0

    property bool keyboardNav: false

    // HoverHandler (not MouseArea) so per-cell HoverHandlers (e.g. emoji tooltip) still receive hover.
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
