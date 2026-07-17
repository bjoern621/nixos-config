import QtQuick
import ".."

// Selection and scroll behavior shared by LauncherListView and LauncherGridView.
// Place inside a ListView or GridView and pass `view: <viewId>`.
Item {
    id: root

    // Untyped: currentIndex and itemAt() live on ListView/GridView,
    // not on their shared Flickable base.
    required property var view

    property alias keyboardNav: selection.keyboardNav
    property alias hoveredIndex: selection.hoveredIndex
    readonly property alias effectiveIndex: selection.effectiveIndex

    function reset() {
        selection.reset();
    }

    LauncherSelection {
        id: selection
        view: root.view
    }

    // Sync selection to the mouse only during mouse-driven scroll.
    // Else a keyboard nav that scrolls the view resets the selection to
    // whatever sits under the cursor.
    Connections {
        target: root.view
        function onContentYChanged() {
            if (!selection.keyboardNav)
                selection.syncHover();
        }
    }

    // Single wheel-event source shared by TouchpadBoost (inertia) and the selection-mode switch.
    // Parented to the view, not left in its data: a Flickable reparents child items into contentItem,
    // sizing them contentWidth x contentHeight, which misses the empty viewport below a short list.
    WheelSource {
        id: wheelSource
        parent: root.view
        onWheelReceived: selection.keyboardNav = false
    }

    TouchpadBoost {
        flickable: root.view
        wheelSource: wheelSource
    }
}
