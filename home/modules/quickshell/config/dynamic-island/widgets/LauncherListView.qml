import QtQuick
import QtQuick.Controls as QQC
import ".."

// Reusable list for launchers. One selection at a time:
//  - mouse motion: hoveredIndex follows the row under the cursor (no auto-scroll)
//  - keyboard nav: parent sets keyboardNav=true and writes currentIndex (auto-scrolls into view)
// effectiveIndex = which one is currently "selected" (for Enter etc.).
ListView {
    id: root
    clip: true
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0

    property bool keyboardNav: false
    property int hoveredIndex: -1
    readonly property int effectiveIndex: keyboardNav ? currentIndex : (hoveredIndex >= 0 ? hoveredIndex : currentIndex)

    // Clears all selection state. Call when opening the view or reloading the model so a stale hover or keyboard selection from before doesn't carry over.
    function reset() {
        currentIndex = 0;
        hoveredIndex = -1;
        keyboardNav = false;
    }

    HoverHandler {
        id: hoverArea
        // Fires when hover state flips, including when the view re-appears under a static cursor (e.g. closing and re-opening the launcher without moving the mouse).
        onHoveredChanged: root.syncHover()
    }

    function syncHover() {
        if (!hoverArea.hovered) {
            root.hoveredIndex = -1;
            return;
        }
        root.keyboardNav = false;
        const pos = hoverArea.point.position;
        const item = root.itemAt(pos.x, pos.y);
        root.hoveredIndex = (item && item.index !== undefined) ? item.index : -1;
    }

    // Re-runs syncHover on every mouse move. Uses scenePosition (window-relative) so it doesn't fire when the view scrolls under a static cursor.
    readonly property point hoverScenePos: hoverArea.point.scenePosition
    onHoverScenePosChanged: syncHover()

    // Only sync the selection to the mouse during mouse-driven scroll. Without this, a keyboard nav that scrolls the view would immediately reset the selection back to whatever's under the cursor.
    onContentYChanged: if (!keyboardNav)
        syncHover()

    TouchpadBoost {
        flickable: root
    }

    QQC.ScrollBar.vertical: ThinScrollBar {}
}
