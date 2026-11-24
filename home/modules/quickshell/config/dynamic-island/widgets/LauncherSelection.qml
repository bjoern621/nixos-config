import QtQuick

// Selection state shared by LauncherListView and LauncherGridView.
// Place inside a ListView or GridView and pass `view: <viewId>`.
//
// Last input wins. Keystrokes claim the selection through keyboardSelect(),
// cursor motion hands it to the item under the pointer.
// Opening under a resting cursor selects the item under it.
// Hover-enter after a keystroke does not claim: a list re-filtering under a
// stationary cursor would otherwise steal the keyboard's selection.
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

    // Set by reset(), cleared by the first claim from either side.
    // While set, hover-enter claims: the view mapping under a resting cursor
    // hands the selection to the item under it.
    property bool pointerArmed: false

    // Call on view open or model reload, else a stale hover or keyboard selection carries over.
    // Call after any keyboardSelect() of the same open, which disarms the pointer.
    function reset() {
        view.currentIndex = 0;
        hoveredIndex = -1;
        keyboardNav = true;
        pointerArmed = true;
    }

    // Keystroke claims the selection. Hover is ignored until the cursor moves.
    function keyboardSelect(index) {
        keyboardNav = true;
        pointerArmed = false;
        view.currentIndex = Math.max(0, Math.min(index, view.count - 1));
    }

    function pointerSelect() {
        keyboardNav = false;
        pointerArmed = false;
        syncHover();
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
        // Claims only while armed. Otherwise refreshes the index: motion alone switches to mouse.
        onHoveredChanged: {
            if (hovered && selection.pointerArmed)
                selection.pointerSelect();
            else
                selection.syncHover();
        }
    }

    // scenePosition is window-relative, so this does not fire
    // when the view scrolls under a static cursor.
    readonly property point hoverScenePos: hoverArea.point.scenePosition
    onHoverScenePosChanged: {
        if (hoverArea.hovered)
            pointerSelect();
    }
}
