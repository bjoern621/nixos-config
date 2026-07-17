import QtQuick

// Selection state shared by LauncherListView and LauncherGridView.
// Place inside a ListView or GridView and pass `view: <viewId>`.
Item {
    id: selection

    // Untyped: currentIndex and itemAt() live on ListView/GridView,
    // not on their shared Flickable base.
    // A Flickable annotation lies to qmlsc and fails type checking.
    required property var view

    property bool keyboardNav: false
    property int hoveredIndex: -1
    readonly property int effectiveIndex: keyboardNav ? view.currentIndex : (hoveredIndex >= 0 ? hoveredIndex : view.currentIndex)

    // Call on view open or model reload, else a stale hover or keyboard selection carries over.
    function reset() {
        view.currentIndex = 0;
        hoveredIndex = -1;
        keyboardNav = false;
    }

    function syncHover() {
        // Hover-leave keeps hoveredIndex as a phantom selection,
        // pinning effectiveIndex to the last hovered item.
        if (!hoverArea.hovered)
            return;
        keyboardNav = false;
        // scenePosition is window-relative and stable across scroll.
        // Mapping into the view's content coordinates makes itemAt work
        // wherever the handler's parent sits.
        const scenePos = hoverArea.point.scenePosition;
        const pos = view.contentItem.mapFromItem(null, scenePos.x, scenePos.y);
        const item = view.itemAt(pos.x, pos.y);
        hoveredIndex = (item && item.index !== undefined) ? item.index : -1;
    }

    // Attaches to the view root, not to this Item.
    // As a child, the Flickable reparents this Item into contentItem alongside delegates,
    // where the wrapping Item's hover area swallows hover events
    // meant for delegate HoverHandlers.
    // Per-cell tooltips break.
    HoverHandler {
        id: hoverArea
        parent: selection.view
        // Fires on hover flip, including the view re-appearing under a static cursor
        // (launcher closed and re-opened without mouse motion).
        onHoveredChanged: selection.syncHover()
    }

    // scenePosition is window-relative, so this does not fire
    // when the view scrolls under a static cursor.
    readonly property point hoverScenePos: hoverArea.point.scenePosition
    onHoverScenePosChanged: syncHover()
}
