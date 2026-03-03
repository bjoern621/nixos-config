import Quickshell
import QtQuick

Row {
    id: root
    spacing: 4

    property string timeFormat: "ddd, dd MMM yyyy \u00B7 HH:mm:ss"
    property int precision: SystemClock.Seconds

    Text {
        text: "\uf017"
        font.family: "Font Awesome 7 Free Solid"
        font.pixelSize: 13
        color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: Qt.formatDateTime(new Date(), root.timeFormat)
        font.family: "Inter"
        font.pixelSize: 13
        font.weight: Font.Bold
        color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
    }

    SystemClock {
        id: clock
        precision: root.precision
    }
}
