import QtQuick
import QtQuick.Controls as QQC
import "../base"

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

    QQC.ScrollBar.vertical: QQC.ScrollBar {
        policy: root.contentHeight > root.height ? QQC.ScrollBar.AsNeeded : QQC.ScrollBar.AlwaysOff
        contentItem: Rectangle {
            implicitWidth: 4
            radius: width / 2
            color: Colors.textColorMuted
            opacity: parent.active ? 0.6 : 0.3
        }
    }
}
