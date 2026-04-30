import QtQuick
import QtQuick.Controls as QQC
import "../base"

// Thin styled scrollbar. Attach with `QQC.ScrollBar.vertical: ThinScrollBar {}` on a Flickable / ListView / GridView.
QQC.ScrollBar {
    id: bar
    policy: parent && parent.contentHeight > parent.height ? QQC.ScrollBar.AsNeeded : QQC.ScrollBar.AlwaysOff

    property bool _scrolling: false
    Timer {
        id: scrollIdleTimer
        interval: 250
        onTriggered: bar._scrolling = false
    }
    Connections {
        target: bar.parent
        function onContentYChanged() {
            bar._scrolling = true;
            scrollIdleTimer.restart();
        }
    }

    contentItem: Rectangle {
        implicitWidth: 4
        radius: width / 2
        color: Colors.textColorMuted
        opacity: (bar.pressed || bar._scrolling) ? 0.6 : 0.3
    }
}
