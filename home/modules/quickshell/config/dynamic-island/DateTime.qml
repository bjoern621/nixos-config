import Quickshell
import QtQuick
import "../"

Row {
    id: root
    spacing: 4

    property string timeFormat: "ddd, dd MMM yyyy \u00B7 HH:mm"
    property int precision: SystemClock.Minutes


    Text {
        text: ""
        font.family: "Font Awesome 7 Free Solid"
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: Qt.formatDateTime(new Date(), root.timeFormat)
        font.family: Style.fontFamily
        font.weight: Font.Bold
    }

    SystemClock {
        id: clock
        precision: root.precision
    }
}
