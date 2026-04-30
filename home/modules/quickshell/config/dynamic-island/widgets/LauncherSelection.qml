import QtQuick

// Selection state shared by LauncherListView and LauncherGridView. Owns:
//  - hoveredIndex (mouse), keyboardNav flag, effectiveIndex (whichever is currently active)
//  - syncHover() that reacts to mouse motion, mouse re-entering the view, and content scrolling under a static cursor
// Place inside a Flickable subclass and pass `view: <viewId>`.
Item {
    id: selection
    required property Flickable view

    property bool keyboardNav: false
    property int hoveredIndex: -1
    readonly property int effectiveIndex: keyboardNav ? view.currentIndex : (hoveredIndex >= 0 ? hoveredIndex : view.currentIndex)

    // Clears all selection state. Call when opening the view or reloading the model so a stale hover or keyboard selection from before doesn't carry over.
    function reset() {
        view.currentIndex = 0;
        hoveredIndex = -1;
        keyboardNav = false;
    }

    function syncHover() {
        if (!hoverArea.hovered) {
            hoveredIndex = -1;
            return;
        }
        keyboardNav = false;
        // Use scenePosition (window-relative, stable across scroll) and map into the view's content coordinates so itemAt works regardless of where the handler's parent currently sits.
        const scenePos = hoverArea.point.scenePosition;
        const pos = view.contentItem.mapFromItem(null, scenePos.x, scenePos.y);
        const item = view.itemAt(pos.x, pos.y);
        hoveredIndex = (item && item.index !== undefined) ? item.index : -1;
    }

    // HoverHandler attaches to the view root (not to this Item). If it were a child of this Item, the Flickable would reparent the Item into its contentItem alongside delegates, where the wrapping Item's hover-aware area swallows hover events meant for delegate HoverHandlers (per-cell tooltips break).
    HoverHandler {
        id: hoverArea
        parent: selection.view
        // Fires when hover state flips, including when the view re-appears under a static cursor (e.g. closing and re-opening the launcher without moving the mouse).
        onHoveredChanged: selection.syncHover()
    }

    // Re-runs syncHover on every mouse move. Uses scenePosition (window-relative) so it doesn't fire when the view scrolls under a static cursor.
    readonly property point hoverScenePos: hoverArea.point.scenePosition
    onHoverScenePosChanged: syncHover()
}
