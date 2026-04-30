import QtQuick
import QtQuick.Controls as QQC
import "../base"

// Reusable ListView for launchers. Wires up:
//  - keyboardNav flag (true while arrow keys drove the last selection change; cleared by mouse motion below)
//  - top-level hover MouseArea: any mouse motion sets keyboardNav=false and writes currentIndex to the row under the cursor → keyboard-vs-mouse stays a single source of truth (no "two selections")
//  - onContentYChanged: re-sync hover after wheel/kinetic scroll so the row gliding under the static cursor becomes selected
//  - styled vertical scrollbar
// Wheel scrolling is left to Flickable's built-in handler (kinetic deceleration, handles touchpad pixelDelta correctly).
// Keyboard selection stays in view via ListView's built-in current-item tracking (highlightMoveDuration: 0 makes it instant).
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

    onContentYChanged: hoverArea.syncHover()

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
