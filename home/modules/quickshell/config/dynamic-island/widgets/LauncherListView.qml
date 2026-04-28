import QtQuick
import QtQuick.Controls as QQC
import "../base"

// Reusable ListView for launchers. Wires up:
//  - keyboardNav flag (set true by parent on arrow-key nav; delegates gate hover-driven currentIndex updates on it so keyboard selection isn't fought by a static cursor)
//  - synchronous positionViewAtIndex on currentIndex change (avoids the built-in animated scroll, jarring with variable-height rows)
//  - fast wheel scrolling via flick() with multiplied velocity (keeps Flickable's StopAtBounds + realization machinery in charge — no dead zones from manual contentHeight math)
//  - styled vertical scrollbar
// Hover sync (cursor moves, items moving under static cursor during scroll, initial show under cursor) is handled by per-delegate HoverHandlers in the parent's delegate definition. Parent supplies model, delegate, and height calculation.
ListView {
    id: root
    clip: true
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0

    property bool keyboardNav: false

    // Snap into view on selection change. ListView's built-in scroll-to-keep-current-visible animates contentY (~250ms) which is jarring with variable-height rows (e.g. 180px image vs 40px text in clipboard). positionViewAtIndex is synchronous and only scrolls the minimum needed.
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    // Speed up wheel scrolling by triggering Flickable's flick() with a multiplied velocity. Going through flick() (instead of writing contentY directly) keeps Flickable's StopAtBounds + animation/realization machinery in charge — no dead zones from our own bounds math against an estimated contentHeight.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real speed: 300
        onWheel: event => root.flick(0, event.angleDelta.y * speed)
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
