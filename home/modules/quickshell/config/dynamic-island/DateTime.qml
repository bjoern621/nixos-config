import Quickshell
import QtQuick

Row {
    id: root
    spacing: 6

    property string timeFormat: "ddd, dd MMM yyyy \u00B7 HH:mm"
    property int precision: SystemClock.Minutes

    Text {
        text: "AA"
        color: "#ffffff"
        font.pixelSize: 13
        font.family: "Font Awesome 7 Free Solid"
        font.weight: Font.Bold
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: Qt.formatDateTime(new Date(), root.timeFormat)
        color: "#ffffff"
        font.pixelSize: 13
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter
    }

    SystemClock {
        id: clock
        precision: root.precision
    }
}
