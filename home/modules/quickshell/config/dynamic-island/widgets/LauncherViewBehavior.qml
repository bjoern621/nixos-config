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

    // Shared wheel step, no inertia. Same behavior as the app launcher.
    // Parented to the view, not left in its data: a Flickable reparents child items into contentItem,
    // sizing them contentWidth x contentHeight, which misses the empty viewport below a short list.
    StepWheel {
        parent: root.view
        target: root.view
        onScrolled: selection.keyboardNav = false
    }
}
