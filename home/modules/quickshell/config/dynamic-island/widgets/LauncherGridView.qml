import QtQuick
import QtQuick.Controls as QQC
import "../base"

// Reusable GridView for launchers (e.g. EmojiPicker). Same syncHover pattern
// as LauncherListView so mouse hover keeps tracking the cell under the cursor
// after wheel scrolls.
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
        onWheel: wheel => {
            const max = Math.max(0, root.contentHeight - root.height);
            root.contentY = Math.max(0, Math.min(max, root.contentY - wheel.angleDelta.y * 2));
            syncHover();
        }
    }

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
