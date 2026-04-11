import QtQuick
import "../"
import "../base"

Row {
    id: datetime
    property var germanLocale: Qt.locale("de_DE")
    property var currentDate: new Date()

    anchors.verticalCenter: parent.verticalCenter
    spacing: Spacing.spacing8

    // Update on minute boundaries: calculate ms until next minute, fire, then recalculate to self-correct drift
    // Multiply by 1.011 to add 1.1% buffer, preventing short intervals that would trigger unnecessarily often due to QML timer precision variance
    Timer {
        id: updateTimer
        interval: (60000 - (new Date().getTime() % 60000)) * 1.011
        running: true
        repeat: false
        onTriggered: {
            datetime.currentDate = new Date();
            interval = (60000 - (new Date().getTime() % 60000)) * 1.011;
            // console.log("DateTime timer: next update in", interval, "ms");
            start();
        }
    }

    Row {
        spacing: Spacing.spacing4

        TintedIcon {
            source: "../icons/icons8-monday.svg"
            size: Typography.fontSize20
            anchors.verticalCenter: parent.verticalCenter
        }

        Label {
            text: germanLocale.dayName(datetime.currentDate.getDay(), Locale.LongFormat) + ", " + datetime.currentDate.toLocaleDateString(germanLocale, "dd. MMM")
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Label {
        text: "\u00b7"
    }

    Row {
        spacing: Spacing.spacing4

        TintedIcon {
            source: "../icons/icons8-time.svg"
            size: Typography.fontSize20
            anchors.verticalCenter: parent.verticalCenter
        }

        Label {
            text: Qt.formatDateTime(datetime.currentDate, "HH:mm")
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
