import QtQuick
import QtQuick.Controls as QQC
import "../base"

// Reusable ListView for launchers. Wires up:
//  - keyboardNav flag (mouse motion clears it; arrow keys set it)
//  - syncHover(): finds the delegate under the cursor via itemAt() and sets
//    currentIndex. Required because HoverHandler only fires on enter/leave;
//    after wheel-scroll the row under the static cursor changes without any
//    pointer event, and the highlight would otherwise lag.
//  - flush wheel scrolling (no bounce)
//  - styled vertical scrollbar
// Parent supplies model, delegate, and rowHeight (via height calculation).
ListView {
    id: root
    clip: true
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0

    property bool keyboardNav: false

    // Snap into view on selection change. ListView's built-in scroll-to-keep-current-visible animates contentY (~250ms) which is jarring with variable-height rows (e.g. 180px image vs 40px text in clipboard). positionViewAtIndex is synchronous and only scrolls the minimum needed.
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

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
