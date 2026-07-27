import QtQuick

// Selection state shared by LauncherListView and LauncherGridView.
// Place inside a ListView or GridView and pass `view: <viewId>`.
//
// Last input wins. Keystrokes claim the selection through keyboardSelect(),
// cursor motion hands it to the item under the pointer. Hover-enter alone does
// not claim it: a list re-filtering or an overlay mapping under a stationary
// cursor would otherwise steal the keyboard's selection.
Item {
    id: selection

    // Untyped: currentIndex, count and itemAt() live on ListView/GridView,
    // not on their shared Flickable base.
    // A Flickable annotation lies to qmlsc and fails type checking.
    required property var view

    property bool keyboardNav: true
    property int hoveredIndex: -1
    readonly property int selectedIndex: keyboardNav ? view.currentIndex : (hoveredIndex >= 0 ? hoveredIndex : view.currentIndex)
    // Consumers index the model with this. Clamped: a model shrink strands both
    // currentIndex and hoveredIndex past the end. -1 on an empty view.
    readonly property int effectiveIndex: Math.min(selectedIndex, view.count - 1)

    // Hover-enter delivers one position sample when the view maps under a
    // stationary cursor. Swallowed, else opening an overlay claims mouse mode.
    property bool pointerSampled: false

    // Call on view open or model reload, else a stale hover or keyboard selection carries over.
    function reset() {
        view.currentIndex = 0;
        hoveredIndex = -1;
        keyboardNav = true;
        pointerSampled = false;
    }

    // Keystroke claims the selection. Hover is ignored until the cursor moves.
    function keyboardSelect(index) {
        keyboardNav = true;
        view.currentIndex = Math.max(0, Math.min(index, view.count - 1));
    }

    function syncHover() {
        // Hover-leave keeps hoveredIndex as a phantom selection,
        // pinning effectiveIndex to the last hovered item.
        if (!hoverArea.hovered)
            return;
        // scenePosition is window-relative and stable across scroll.
        // Mapping into the view's content coordinates makes itemAt work
        // wherever the handler's parent sits.
        const scenePos = hoverArea.point.scenePosition;
        const pos = view.contentItem.mapFromItem(null, scenePos.x, scenePos.y);
        const item = view.itemAt(pos.x, pos.y);
        // Miss = row spacing or the short last row of a grid. Last index stands,
        // else the selection flickers to currentIndex while crossing a gap.
        if (item && item.index !== undefined)
            hoveredIndex = item.index;
    }

    // Attaches to the view root, not to this Item.
    // As a child, the Flickable reparents this Item into contentItem alongside delegates,
    // where the wrapping Item's hover area swallows hover events
    // meant for delegate HoverHandlers.
    // Per-cell tooltips break.
    HoverHandler {
        id: hoverArea
        parent: selection.view
        // Fires on hover flip, including the view re-appearing under a static cursor.
        // Refreshes the index without claiming: motion alone switches to mouse.
        onHoveredChanged: selection.syncHover()
    }

    // scenePosition is window-relative, so this does not fire
    // when the view scrolls under a static cursor.
    readonly property point hoverScenePos: hoverArea.point.scenePosition
    onHoverScenePosChanged: {
        if (!hoverArea.hovered)
            return;
        if (pointerSampled)
            keyboardNav = false;
        pointerSampled = true;
        syncHover();
    }
}
