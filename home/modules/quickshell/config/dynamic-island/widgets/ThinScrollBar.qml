import QtQuick
import QtQuick.Controls as QQC
import "../base"

// Thin styled scrollbar. Attach with `QQC.ScrollBar.vertical: ThinScrollBar {}` on a Flickable / ListView / GridView.
QQC.ScrollBar {
    id: bar
    policy: parent && parent.contentHeight > parent.height ? QQC.ScrollBar.AsNeeded : QQC.ScrollBar.AlwaysOff
    contentItem: Rectangle {
        implicitWidth: 4
        radius: width / 2
        color: Colors.textColorMuted
        opacity: bar.active ? 0.6 : 0.3
    }
}
