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

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        propagateComposedEvents: true
        function syncHover() {
            root.keyboardNav = false;
            const item = root.itemAt(root.contentX + mouseX, root.contentY + mouseY);
            if (item && item.index !== undefined)
                root.currentIndex = item.index;
        }
        onPositionChanged: syncHover()
    }

    // Only sync the selection to the mouse during mouse-driven scroll. Without this, a keyboard nav that scrolls the view would immediately reset the selection back to whatever's under the cursor.
    onContentYChanged: if (!keyboardNav) hoverArea.syncHover()

    QQC.ScrollBar.vertical: ThinScrollBar {}
}
