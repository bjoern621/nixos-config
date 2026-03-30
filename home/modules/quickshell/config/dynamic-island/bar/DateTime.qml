import QtQuick
import "../"

Row {
    id: datetime
    property var germanLocale: Qt.locale("de_DE")
    property var currentDate: new Date()

    anchors.verticalCenter: parent.verticalCenter
    spacing: Spacing.spacing8

    Row {
        spacing: Spacing.spacing4

        Icon {
            text: "\uf133"
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

        Icon {
            text: "\uf017"
            anchors.verticalCenter: parent.verticalCenter
        }

        Label {
            text: Qt.formatDateTime(datetime.currentDate, "HH:mm")
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
